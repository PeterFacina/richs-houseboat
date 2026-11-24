import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join, resolve } from 'node:path';
import { fileURLToPath, pathToFileURL } from 'node:url';
import { parseArgs } from 'node:util';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { findEvidence, projectProfile, scan } from '../game_prompt_studio/lib/index.mjs';
import { catalogPassages } from '../game_prompt_studio/lib/catalog-passages.mjs';
import { buildDraft, checkExport, createOllama } from '../game_prompt_studio/lib/model.mjs';
import { reviewBrief } from './brief-review-experiment.mjs';

const { values } = parseArgs({ options: {
  main: { type: 'string' }, pr71: { type: 'string' }, generate: { type: 'boolean' }, details: { type: 'boolean' },
} });
if (!values.main || !values.pr71) throw new Error('Supply --main PATH and --pr71 PATH. Add --generate for the local Ollama passes.');
const main = resolve(values.main);
const pr71 = resolve(values.pr71);
const fixture = JSON.parse(readFileSync(fileURLToPath(new URL('./heldout-cases.json', import.meta.url)), 'utf8'));
const python = process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python';
const execOptions = { encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } };
const git = (root, ...args) => execFileSync('git', ['-C', root, ...args], execOptions);
for (const [root, expected] of [[main, fixture.main], [pr71, fixture.pr71]]) {
  assert.equal(git(root, 'rev-parse', 'HEAD').trim(), expected);
  assert.equal(git(root, 'status', '--porcelain').trim(), '', 'Comparison checkout must be clean');
}
const index = root => import(pathToFileURL(join(root, 'tools/game_prompt_studio/lib/index.mjs')).href);
const variants = [['main', (await index(main)).findEvidence], ['pr71', (await index(pr71)).findEvidence], ['catalog', findEvidence]];
const usePython = (script, args, input) => JSON.parse(execFileSync(python, [join(main, 'tools/knowledge', script), ...args], { ...execOptions, input }));
const manifest = usePython('index.py', ['--root', main]);
assert.equal(manifest.revision, fixture.main);
assert.equal(manifest.dirty, false);
const print = record => console.log(JSON.stringify(record));
const sourcePath = file => 'godot-cove/' + file;
function locations(items) {
  return items.map(([file, name]) => {
    const path = sourcePath(file);
    const declarations = manifest.files[path]?.symbols ?? [];
    const index = declarations.findIndex(item => item.kind === 'func' && item.name === name);
    assert.notEqual(index, -1, 'Missing frozen source expectation ' + path + ':' + name);
    return { path, name, start: declarations[index].line, end: declarations[index + 1]?.line ?? Infinity };
  });
}
const frozen = fixture.cases.map(item => ({ ...item, locations: locations(item.required), related: locations(item.supporting) }));
assert.ok(new Set(frozen.map(item => item.system)).size >= 5, 'Expect five distinct systems');

function gradeEvidence(items, example) {
  const src = items.filter(item => item.kind === 'source');
  const overlap = (a, b) => a.path === b.path && a.line + a.excerpt.split('\n').length > b.start + 1 && a.line < b.end - 1;
  const coverage = example.locations.filter(location => src.some(item => overlap(item, location)));
  const good = src.filter(item => [...example.locations, ...example.related].some(location => overlap(item, location)));
  const exact = src.filter(item => new TextDecoder().decode(readFileSync(join(main, item.path))).split(/\r?\n/)
    .slice(item.line - 1).map(line => line.slice(0, 350)).join('\n').startsWith(item.excerpt));
  return { returned: src.length, relevantIds: good.map(item => item.id), exact: exact.length,
    expected: example.locations.length, covered: coverage.map(item => item.name) };
}

const wireEvidence = items => items.map(({ id, kind, path, line, title, excerpt }) => ({ id, kind, path, line, title, excerpt }));
const model = 'qwen3:14b';
const temp = mkdtempSync(join(tmpdir(), 'houseboat-heldout-'));
const db = openDb(temp);
try {
  scan(db, main, [], false, { manifest, tracked: git(main, 'ls-files', '-z').split('\0').filter(Boolean) });
  const settings = { model, context: 8192, keepAliveMinutes: 2 };
  const facts = projectProfile(db);
  async function modelDigest() {
    const response = await fetch('http://127.0.0.1:11434/api/tags', { signal: AbortSignal.timeout(5000) });
    assert.ok(response.ok);
    const found = (await response.json()).models.find(item => item.name === model)?.digest;
    assert.ok(found, 'Pinned model is unavailable');
    return found;
  }
  const digest = values.generate ? await modelDigest() : null;
  print({ phase: 'setup', gameRevision: manifest.revision, pr71: fixture.pr71, model, digest, settings });
  for (const [caseIndex, example] of frozen.entries()) {
    const seed = 1703 + caseIndex;
    const selector = usePython('studio_context.py', [], JSON.stringify({ catalog: manifest, note: example.note, tasks: [] }));
    const options = { manifest, selection: selector };
    const provider = createOllama(11434, (url, init) => {
      if (!url.endsWith('/api/chat')) return fetch(url, init);
      const request = JSON.parse(init.body);
      request.options.seed = seed;
      return fetch(url, { ...init, body: JSON.stringify(request) });
    });
    const order = [...variants.slice(caseIndex % 3), ...variants.slice(0, caseIndex % 3)];
    let reviewInput;
    for (const [variant, retrieve] of order) {
      const begin = performance.now();
      const input = variant === 'catalog' ? { ...options, rankedSources: catalogPassages(db, manifest, example.note) } : options;
      const evidence = wireEvidence(retrieve(db, example.note, [], 5800, input));
      print({ phase: 'retrieval', case: example.id, variant, wallMs: Math.round(performance.now() - begin),
        bytes: Buffer.byteLength(JSON.stringify(evidence)), ...gradeEvidence(evidence, example),
        selected: evidence.map(({ id, path, title, line, kind }) => ({ id, path, title, line, kind })),
        ...(values.details ? { evidence } : {}) });
      if (!values.generate) continue;
      const started = performance.now();
      try {
        const { payload, metrics } = await provider.generate({ input: { note: example.note, tier: 'detailed', priority: '', tags: '' },
          facts, evidence, settings, signal: AbortSignal.timeout(120_000) });
        const brief = buildDraft(payload, 'Evaluation brief', facts, evidence, example.note);
        const guard = checkExport(brief, evidence, facts);
        print({ phase: 'generation', case: example.id, variant, seed, wallMs: Math.round(performance.now() - started),
          promptTokens: metrics.promptTokens, outputTokens: metrics.outputTokens, modelMs: metrics.durationMs,
          loadMs: metrics.loadMs, exportPassed: !guard.length, ...(values.details ? { payload, guard } : {}) });
        if (variant === 'pr71') reviewInput = { model, seed, note: example.note, evidence, facts, draft: payload };
      } catch (error) {
        print({ phase: 'generation', case: example.id, variant, error: error.message });
        process.exitCode = 1;
      }
    }
    if (!reviewInput) continue;
    const started = performance.now();
    try {
      const { findings, revised, ...metrics } = await reviewBrief(reviewInput);
      const brief = buildDraft(revised, 'Evaluation brief', facts, reviewInput.evidence, example.note);
      const guard = checkExport(brief, reviewInput.evidence, facts);
      print({ phase: 'review', case: example.id, variant: 'pr71-reviewed', seed, wallMs: Math.round(performance.now() - started),
        ...metrics, counts: Object.fromEntries([...new Set(findings.map(item => item.kind))]
          .map(kind => [kind, findings.filter(item => item.kind === kind).length])),
        exportPassed: !guard.length, ...(values.details ? { revised, findings, guard } : {}) });
    } catch (error) {
      print({ phase: 'review', case: example.id, variant: 'pr71-reviewed', error: error.message });
      process.exitCode = 1;
    }
  }
  if (values.generate) assert.equal(await modelDigest(), digest, 'The Ollama tag changed during evaluation');
} finally {
  db.close();
  rmSync(temp, { recursive: true, force: true });
}
