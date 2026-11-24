import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { parseArgs } from 'node:util';
import { pathToFileURL } from 'node:url';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { findEvidence, projectProfile, scan } from '../game_prompt_studio/lib/index.mjs';
import { buildDraft, checkExport, createOllama } from '../game_prompt_studio/lib/model.mjs';

const sourceRevision = '688da719026b5096740f6f610490b7fa70b07422';
const pr28Revision = 'e3918ec24a692c930106c3218bfa9b4aae7af8c0';
const cases = [
  {
    issue: 66,
    note: 'Trace the multiplayer houseboat helm controls. Map the source functions and relevant documentation, and identify overlapping work. Keep this a notes-only investigation.',
    gold: [
      ['interaction', 'fishing.gd', 'campaign.helm()'],
      ['request', 'river_campaign.gd', 'crew.order.rpc_id(1, action, value)'],
      ['ownership', 'river_campaign.gd', 'captain = peer'],
      ['steering', 'river_crew.gd', 'command_received.emit(clampf(throttle'],
      ['throttle override', 'fishing.gd', 'vessel.hold_throttle('],
      ['host/guest step', 'river_campaign.gd', 'remote_throttle if remote_age'],
    ],
    supporting: [
      ['helm entry', 'river_campaign.gd', 'request("helm", null)'],
      ['helm anchor', 'houseboat.gd', 'func helm_anchor()'],
      ['base throttle', 'cove.gd', 'func update_helm_throttle('],
    ],
  },
  {
    issue: 69,
    note: 'HUD layout and performance text can overflow on the right. Check FPS and graphics presets at different resolutions. Move the existing date and time to the upper right and collapse the gap when FPS is off. Preserve the toggle. Hide location labels including Rich’s Houseboat and Deep River. Place the dynamic objective or action hint at the upper left while keeping its existing updates and styling.',
    gold: [
      ['FPS bounds', 'cove.gd', 'fps.offset_left'],
      ['FPS and graphics text', 'fishing.gd', 'fps.text ='],
      ['FPS toggle', 'cove.gd', 'KEY_F3'],
      ['calendar position', 'shannon_job.gd', 'calendar.offset_top'],
      ['region label', 'river_regions.gd', 'region_label.set_anchors'],
      ['dynamic action hint', 'fishing.gd', 'campaign.action_hint()'],
    ],
    supporting: [
      ['graphics presets', 'river_graphics.gd', 'const NAMES :='],
      ['objective location write', 'fishing.gd', 'objective.text = location'],
      ['clock content', 'shannon_job.gd', 'calendar.text ='],
      ['region content', 'river_regions.gd', 'region_label.text ='],
      ['action hint producer', 'river_campaign.gd', 'func action_hint()'],
    ],
  },
];
const liveTasks = [
  { number: 56, title: 'Houseboat drift starts after entering the helm', label: 'Open issue' },
  { number: 57, title: 'Enable idle houseboat drift before helm use', label: 'Draft PR' },
  { number: 70, title: 'Adjust HUD layout and dynamic indicators', label: 'Draft PR' },
];
const { values } = parseArgs({ options: {
  baseline: { type: 'string' }, pr28: { type: 'string' },
  runs: { type: 'string', default: '0' }, details: { type: 'boolean' },
} });
const runs = Number(values.runs);
if (!values.baseline || !values.pr28 || !Number.isInteger(runs) || runs < 0 || runs > 10) {
  throw new Error('Usage: node tools/discord-issue-pilot/retrieval-benchmark.mjs --baseline PATH --pr28 PATH [--runs 0–10] [--details]');
}
const baseline = resolve(values.baseline);
const pr28 = resolve(values.pr28);
const python = process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python';
const execution = { encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } };
const git = (root, ...args) => execFileSync('git', ['-C', root, ...args], execution);
const script = (relative, input) => JSON.parse(execFileSync(python, [join(baseline, 'tools/knowledge', relative)], { ...execution, input }));
const importIndex = root => import(pathToFileURL(join(root, 'tools/game_prompt_studio/lib/index.mjs')).href);
assert.equal(git(baseline, 'rev-parse', 'HEAD').trim(), sourceRevision, 'Wrong baseline revision');
assert.equal(git(pr28, 'rev-parse', 'HEAD').trim(), pr28Revision, 'Wrong PR #28 revision');
assert.equal(git(baseline, 'status', '--porcelain').trim(), '', 'The baseline checkout must be clean.');
assert.equal(git(pr28, 'status', '--porcelain').trim(), '', 'The PR #28 checkout must be clean.');
const catalog = JSON.parse(execFileSync(python, [join(baseline, 'tools/knowledge/index.py'), '--root', baseline], execution));
assert.equal(catalog.revision, sourceRevision);
assert.equal(catalog.dirty, false);
assert.ok(catalog.files['godot-cove/fishing.gd'], 'The baseline needs the pinned Godot text checkout.');
const original = await importIndex(baseline);
const experimental = await importIndex(pr28);
const variants = [['main', original.findEvidence], ['pr28', experimental.findEvidence], ['candidate', findEvidence]];

function assessEvidence(evidence, { gold, supporting }) {
  const sources = evidence.filter(e => e.kind === 'source');
  const support = (e, entries) => entries.filter(([, file, cue]) => e.path === 'godot-cove/' + file && e.excerpt.includes(cue));
  const exact = e => readFileSync(join(baseline, e.path), 'utf8').replace(/^\uFEFF/, '').split(/\r?\n/)
    .slice(e.line - 1).map(line => line.slice(0, 350)).join('\n').startsWith(e.excerpt.trimEnd());
  const matches = sources.flatMap(e => support(e, gold).map(([name]) => name));
  const relevant = new Set(sources.filter(e => support(e, [...gold, ...supporting]).length).map(e => e.id));
  return { relevant, scores: { sources: sources.length, relevant: relevant.size, pinnedRanges: sources.filter(exact).length,
    coverage: new Set(matches).size, expected: gold.length,
    selected: sources.map(({ id, path, line, title }) => ({ id, path, line, ...(title ? { title } : {}) })),
    covered: [...new Set(matches)], guides: evidence.filter(e => e.kind === 'guide').length } };
}

function assessCitations(payload, evidence, relevant) {
  const renderedFields = { ...payload, observations: payload.observations.filter(value => value.trim().endsWith('?')) };
  const refs = Object.values(renderedFields).flat().flatMap(value => [...value.matchAll(/\[(S\d+)\]/gi)]
    .map(match => match[1].toUpperCase()));
  const lookup = new Map(evidence.map(e => [e.id, e.kind]));
  const sourceRefs = refs.filter(ref => lookup.get(ref) === 'source');
  return { sourceCitations: sourceRefs.length, relevantSourceCitations: sourceRefs.filter(ref => relevant.has(ref)).length,
    invalidReferences: refs.filter(ref => !lookup.has(ref)).length };
}

const temp = mkdtempSync(join(tmpdir(), 'houseboat-retrieval-benchmark-'));
const db = openDb(temp);
try {
  const tracked = git(baseline, 'ls-files', '-z').split('\0').filter(Boolean);
  scan(db, baseline, [], false, { manifest: catalog, tracked });
  const samples = cases.map(example => {
    const selection = script('studio_context.py', JSON.stringify({ catalog, note: example.note, tasks: liveTasks }));
    return variants.map(([variant, retrieve]) => {
      const start = performance.now();
      const evidence = retrieve(db, example.note, [], 5800, { manifest: catalog, selection });
      const searchMs = Math.round((performance.now() - start) * 10) / 10;
      const { relevant, scores } = assessEvidence(evidence, example);
      console.log(JSON.stringify({ phase: 'retrieval', revision: sourceRevision, issue: example.issue, variant, searchMs,
        contextBytes: Buffer.byteLength(JSON.stringify(evidence.map(({ id, kind, path, line, title, excerpt }) =>
          ({ id, kind, path, line, title, excerpt })))), ...scores }));
      return { example, variant, evidence, relevant };
    });
  });
  if (runs) {
    const provider = createOllama(11434);
    const settings = { model: 'qwen3:14b', context: 8192, keepAliveMinutes: 2 };
    const facts = projectProfile(db);
    for (let round = 0; round < runs; round++) {
      for (const pool of samples) {
        for (const { example, variant, evidence, relevant } of [...pool.slice(round % pool.length), ...pool.slice(0, round % pool.length)]) {
          const start = performance.now();
          try {
            const { payload, metrics } = await provider.generate({ input: { note: example.note, tier: 'detailed', priority: '', tags: '' },
              facts, evidence, settings, signal: AbortSignal.timeout(120_000) });
            const rendered = buildDraft(payload, 'Retrieval benchmark', facts, evidence, example.note);
            const findings = checkExport(rendered, evidence, facts);
            console.log(JSON.stringify({ phase: 'generation', issue: example.issue, variant, round: round + 1,
              generationMs: Math.round(performance.now() - start), modelMs: metrics.durationMs, loadMs: metrics.loadMs,
              promptTokens: metrics.promptTokens, outputTokens: metrics.outputTokens, exportPassed: findings.length === 0,
              ...assessCitations(payload, evidence, relevant), ...(values.details ? { payload, findings } : {}) }));
          } catch (error) {
            console.log(JSON.stringify({ phase: 'generation', issue: example.issue, variant, round: round + 1,
              generationMs: Math.round(performance.now() - start), error: error.message }));
            process.exitCode = 1;
          }
        }
      }
    }
  }
} finally {
  db.close();
  rmSync(temp, { recursive: true, force: true });
}
