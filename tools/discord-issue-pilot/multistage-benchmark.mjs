import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { findEvidence, projectProfile, scan } from '../game_prompt_studio/lib/index.mjs';
import { catalogPassages } from '../game_prompt_studio/lib/catalog-passages.mjs';
import { buildDraft, checkExport, createOllama } from '../game_prompt_studio/lib/model.mjs';

const { values } = parseArgs({ options: {
  main: { type: 'string' }, pr71: { type: 'string' }, generate: { type: 'boolean' }, details: { type: 'boolean' },
  cases: { type: 'string' }, variants: { type: 'string' }, port: { type: 'string', default: '11434' },
  history: { type: 'string' }, 'no-graphify': { type: 'boolean' },
} });
assert.ok(values.main && values.pr71, 'Supply --main PATH and --pr71 PATH. Add --generate for Ollama.');
const readFixture = name => JSON.parse(readFileSync(new URL(name, import.meta.url), 'utf8'));
const frozen = readFixture('./multistage-cases.json');
const previous = readFixture('./heldout-cases.json');
const allCases = [...previous.cases.map(item => ({ ...item, requirements: frozen.regressionRequirements[item.id], set: 'regression' })),
  ...frozen.cases.map(item => ({ ...item, set: 'independent' }))];
const excludedHistory = new Set(allCases.flatMap(example => {
  const match = /\/(issues|pull)\/(\d+)$/.exec(example.report ?? '');
  return match ? [`${match[1] === 'issues' ? 'issue' : 'pull'}/${match[2]}`] : [];
}));
const caseFilter = values.cases?.split(',');
const cases = allCases.filter(example => !caseFilter || caseFilter.includes(example.id) || caseFilter.includes(example.set));
const order = ['production', 'pr71', 'catalog', 'multistage'];
const selected = values.variants?.split(',') ?? order;
assert.ok(cases.length && selected.length && selected.every(variant => order.includes(variant)), 'Unknown cases or variants');
const main = resolve(values.main);
const pr71 = resolve(values.pr71);
const port = Number(values.port);
assert.ok(Number.isInteger(port) && port > 0 && port <= 65535);
const python = process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python';
const execOptions = { encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } };
const git = (root, ...args) => execFileSync('git', ['-C', root, ...args], execOptions);
const py = (script, args = [], input) => JSON.parse(execFileSync(python, [join(main, 'tools/knowledge', script), ...args], { ...execOptions, input }));
for (const [root, revision] of [[main, frozen.source], [pr71, frozen.pr71]]) {
  assert.equal(git(root, 'rev-parse', 'HEAD').trim(), revision);
  assert.equal(git(root, 'status', '--porcelain').trim(), '', 'Comparison checkout must be clean');
}
const indexModule = root => import(pathToFileURL(join(root, 'tools/game_prompt_studio/lib/index.mjs')).href);
const production = (await indexModule(main)).findEvidence;
const routed = (await indexModule(pr71)).findEvidence;
const manifest = py('index.py', ['--root', main]);
assert.equal(manifest.revision, frozen.source);
assert.equal(manifest.dirty, false);
const tracked = git(main, 'ls-files', '-z').split('\0').filter(Boolean);
const model = 'qwen3:14b';
const settings = { model, context: 8192, keepAliveMinutes: 2 };
const print = value => console.log(JSON.stringify(value));
const wire = ({ id, kind, path, line, title, excerpt }) => ({ id, kind, path, line, title, excerpt });

function locations(pairs) {
  return pairs.map(([file, name]) => {
    const path = 'godot-cove/' + file;
    const symbols = manifest.files[path]?.symbols ?? [];
    const index = symbols.findIndex(symbol => symbol.kind === 'func' && symbol.name === name);
    assert.notEqual(index, -1, `Missing frozen expectation ${path}:${name}`);
    return { path, name, start: symbols[index].line, end: symbols[index + 1]?.line ?? Infinity };
  });
}

function grade(items, example) {
  const source = items.filter(item => item.kind === 'source');
  const overlap = (a, b) => a.path === b.path && a.line + a.excerpt.split('\n').length > b.start + 1 && a.line < b.end - 1;
  const required = locations(example.required);
  const related = [...required, ...locations(example.supporting)];
  return {
    returned: source.length,
    relevantIds: source.filter(item => related.some(location => overlap(item, location))).map(item => item.id),
    expected: required.length,
    covered: required.filter(location => source.some(item => overlap(item, location))).map(item => item.name),
    exact: items.filter(item => item.kind === 'source' || item.kind === 'guide').every(item =>
      readFileSync(join(main, item.path), 'utf8').split(/\r?\n/).slice(item.line - 1)
        .map(line => line.slice(0, 350)).join('\n').startsWith(item.excerpt)),
  };
}

async function modelDigest() {
  const response = await fetch(`http://127.0.0.1:${port}/api/tags`, { signal: AbortSignal.timeout(5000) });
  assert.ok(response.ok);
  const digest = (await response.json()).models.find(item => item.name === model)?.digest;
  assert.ok(digest, 'Benchmark model unavailable');
  return digest;
}

const temp = mkdtempSync(join(tmpdir(), 'houseboat-multistage-'));
const db = openDb(temp);
try {
  const setup = performance.now();
  scan(db, main, [], false, { manifest, tracked });
  const facts = projectProfile(db);
  const history = values.history ? JSON.parse(readFileSync(values.history, 'utf8')) : readFixture('./multistage-history.json');
  let collectEvidence, createPlanner, codeIndex;
  if (selected.includes('multistage')) {
    ({ collectEvidence, createPlanner } = await import('./multistage/retrieval.mjs'));
    const { buildCodeIndex } = await import('./multistage/code-index.mjs');
    codeIndex = buildCodeIndex(main, manifest, tracked, { history, useGraphify: !values['no-graphify'] });
  }
  const digest = values.generate ? await modelDigest() : null;
  print({ phase: 'setup', revision: manifest.revision, pr71: frozen.pr71, pr72: frozen.pr72, model, digest, settings,
    selected, setupMs: Math.round(performance.now() - setup), index: codeIndex?.stats, historyCount: history.records.length });
  for (const example of cases) {
    const offset = allCases.indexOf(example);
    const seed = 1703 + offset;
    const provider = createOllama(port, (url, init) => {
      if (!url.endsWith('/api/chat')) return fetch(url, init);
      const request = JSON.parse(init.body);
      request.options.seed = seed;
      return fetch(url, { ...init, body: JSON.stringify(request) });
    });
    const rotated = [...order.slice(offset % order.length), ...order.slice(0, offset % order.length)];
    for (const variant of rotated.filter(item => selected.includes(item))) {
      const start = performance.now();
      const signal = AbortSignal.timeout(120_000);
      const identity = { case: example.id, set: example.set, variant, seed };
      try {
        let evidence, planning;
        if (variant === 'multistage') {
          const planner = values.generate ? createPlanner({ port, settings, seed }) : undefined;
          const collected = await collectEvidence(codeIndex, example.note, { planner, signal, excludeHistory: excludedHistory });
          evidence = collected.evidence.map(wire);
          planning = collected.planning;
        } else {
          const selection = py('studio_context.py', [], JSON.stringify({ catalog: manifest, note: example.note, tasks: [] }));
          const retrieve = { production, pr71: routed, catalog: findEvidence }[variant];
          const options = { manifest, selection };
          if (variant === 'catalog') options.rankedSources = catalogPassages(db, manifest, example.note);
          evidence = retrieve(db, example.note, [], 5800, options).map(wire);
        }
        const scores = grade(evidence, example);
        assert.ok(scores.exact, 'Evidence failed pinned source verification');
        print({ phase: 'retrieval', ...identity, ...scores, bytes: Buffer.byteLength(JSON.stringify(evidence)),
          wallMs: Math.round(performance.now() - start), planning,
          selected: evidence.map(({ id, kind, path, line, title }) => ({ id, kind, path, line, title })),
          ...(values.details ? { evidence } : {}) });
        if (!values.generate) continue;
        const { payload, metrics } = await provider.generate({ input: { note: example.note, tier: 'detailed', priority: '', tags: '' },
          facts, evidence, settings, signal });
        const draft = buildDraft(payload, 'Evaluation brief', facts, evidence, example.note);
        const guard = checkExport(draft, evidence, facts);
        print({ phase: 'generation', ...identity, wallMs: Math.round(performance.now() - start),
          promptTokens: metrics.promptTokens + (planning?.promptTokens ?? 0),
          outputTokens: metrics.outputTokens + (planning?.outputTokens ?? 0),
          draftPromptTokens: metrics.promptTokens, draftOutputTokens: metrics.outputTokens,
          modelMs: metrics.durationMs, loadMs: metrics.loadMs, exportPassed: !guard.length, guard,
          ...(values.details ? { payload } : {}) });
      } catch (error) {
        print({ phase: 'error', ...identity, wallMs: Math.round(performance.now() - start), error: error.message });
        process.exitCode = 1;
      }
    }
  }
  if (values.generate) assert.equal(await modelDigest(), digest, 'Model tag changed during evaluation');
} finally {
  db.close();
  rmSync(temp, { recursive: true, force: true });
}
