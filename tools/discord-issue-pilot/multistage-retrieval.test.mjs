import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { test } from 'node:test';
import { buildCodeIndex } from './multistage/code-index.mjs';
import { collectEvidence, createPlanner } from './multistage/retrieval.mjs';

function fixture(t) {
  const root = mkdtempSync(join(tmpdir(), 'houseboat-retrieval-test-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const tracked = [];
  const files = {};
  const write = (path, text) => {
    const target = join(root, path);
    mkdirSync(dirname(target), { recursive: true });
    writeFileSync(target, text);
    if (!tracked.includes(path)) tracked.push(path);
    if (!path.startsWith('godot-cove/')) return;
    const symbols = text.split('\n').flatMap((line, i) => {
      const declaration = /^(?:static )?func (\w+)/.exec(line);
      return declaration ? [{ kind: 'func', name: declaration[1], line: i + 1 }] : [];
    });
    files[path] = { symbols, sha256: createHash('sha256').update(text).digest('hex'),
      references: [...text.matchAll(/"res:\/\/([^"\n]+)"/g)].map(match => 'godot-cove/' + match[1]) };
  };
  write('godot-cove/gate.gd', `const Sensor = preload("res://sensor.gd")
func drive_gate():
\topen_gate()
\tSensor.clear_path()
\t# fictitious()
\tprint("fictitious()")
func open_gate():
\tvar gate_motor = "running"
func close_gate():
\tvar gate_motor = "stopped"
func fictitious():
\tpass
`);
  write('godot-cove/sensor.gd', 'static func clear_path():\n\treturn true\n');
  const extra = 'func relay_signal():\n\tvar subscriber = "alarm"\n';
  write('godot-cove/extra.gd', extra.replaceAll('\n', '\r\n'));
  write('godot-cove/later.gd', 'func backup_state():\n\tvar snapshot = {}\n');
  write('godot-cove/dock.tscn', '[ext_resource type="Script" path="res://gate.gd" id="1"]\n[node name="Dock" type="Node"]\nscript = ExtResource("1")\n');
  write('docs/systems/GATE.md', '# Gate\n\nThe gate is a barrier. See [script](../../godot-cove/gate.gd).\n');
  write('tools/godot-lookup/links.json', JSON.stringify({
    hashes: { 'gate.gd': files['godot-cove/gate.gd'].sha256, 'extra.gd': createHash('sha256').update(extra).digest('hex'), 'later.gd': 'stale' },
    links: [{ from: 'gate.gd', to: 'extra.gd', relation: 'imports_from' },
      { from: 'gate.gd', to: 'later.gd', relation: 'imports_from' }],
  }));
  return { root, tracked, files, write, build: options => buildCodeIndex(root, { files }, tracked, options) };
}

test('index links verified scenes, guides and lexical calls and ignores stale Graphify endpoints', t => {
  const f = fixture(t);
  const index = f.build();
  const named = name => index.entries.find(item => item.name === name);
  assert.equal(named('drive_gate').links.get(named('open_gate').id), 'lexical call');
  assert.equal(named('drive_gate').links.get(named('clear_path').id), 'lexical call');
  assert.equal(named('drive_gate').links.has(named('fictitious').id), false);
  assert.equal(index.files.get('godot-cove/dock.tscn').links.get('godot-cove/gate.gd'), 'scene resource');
  assert.equal(index.files.get('docs/systems/GATE.md').links.get('godot-cove/gate.gd'), 'documented source');
  assert.deepEqual(index.stats.graphify, { matching: 1, added: 1, skipped: 1 });
  assert.equal(f.build({ useGraphify: false }).files.get('godot-cove/gate.gd').links.has('godot-cove/extra.gd'), false);
  f.write('godot-cove/new.gd', 'func synchronize_lighthouse():\n\treturn "beacon"\n');
  const updated = f.build();
  assert.equal(updated.rank(updated.query('synchronize lighthouse'))[0].item.name, 'synchronize_lighthouse');
});

test('bounded planner requests resolve only to pinned source and history is optional background', async t => {
  const f = fixture(t);
  const history = { through: '2026-11-24T00:00:00Z', records: [
    { type: 'issue', number: 5, title: 'Align gate motor', completed: '2026-11-01T00:00:00Z' },
    { type: 'pull', number: 6, title: 'Repair gate motor', issues: [5], completed: '2026-11-01T00:00:00Z' },
    { type: 'pull', number: 7, title: 'Inspect gate motor', completed: '2026-11-01T00:00:00Z' },
  ] };
  const index = f.build({ history });
  let rounds = 0;
  const planner = async () => {
    const requests = rounds++ === 0 ? [{ kind: 'file', target: '../../private.txt' },
      { kind: 'function', target: 'relay_signal' }, { kind: 'function', target: 'does_not_exist' }] :
      [{ kind: 'function', target: 'backup_state' }, { kind: 'search', target: 'https://invalid.example/' }];
    return { plan: { systems: ['gate'], requests, more: true }, promptTokens: 10, outputTokens: 5 };
  };
  const { evidence, planning } = await collectEvidence(index, 'Verify the gate motor.', { planner, excludeHistory: new Set(['issue/5']) });
  assert.equal(rounds, 2);
  assert.equal(planning.promptTokens, 20);
  assert.equal(planning.retrieved, 2);
  assert.equal(planning.rejected, 3);
  assert.ok(evidence.some(item => item.title === 'relay_signal'));
  assert.ok(evidence.some(item => item.title === 'backup_state'));
  assert.deepEqual(evidence.filter(item => item.kind === 'github').map(item => item.title), ['Completed PR #7']);
  assert.ok(evidence.reduce((sum, item) => sum + item.excerpt.length, 0) <= 5800);
  assert.ok(!JSON.stringify(evidence).includes('private.txt'));
  assert.throws(() => index.verify([{ path: '../../private.txt' }]), /outside the index/);
  f.write('godot-cove/gate.gd', 'func changed():\n\tpass\n');
  assert.throws(() => index.verify(evidence), /Evidence changed/);
});

test('planner uses a loopback endpoint with structured, limited responses and records token use', async () => {
  let request;
  const planner = createPlanner({ port: 11434, settings: { model: 'qwen3:14b', context: 8192, keepAliveMinutes: 2 }, seed: 19,
    fetcher: async (url, options) => {
      request = { url, body: JSON.parse(options.body) };
      return { ok: true, json: async () => ({ done_reason: 'stop', prompt_eval_count: 18, eval_count: 7,
        message: { content: '{"systems":[],"requests":[],"more":false}' } }) };
    } });
  const result = await planner({ note: 'sample' }, new AbortController().signal);
  assert.equal(request.url, 'http://127.0.0.1:11434/api/chat');
  assert.equal(request.body.options.num_ctx, 8192);
  assert.equal(request.body.format.properties.requests.maxItems, 5);
  assert.equal(result.promptTokens, 18);
  assert.equal(result.outputTokens, 7);
  assert.equal(result.plan.more, false);
});
