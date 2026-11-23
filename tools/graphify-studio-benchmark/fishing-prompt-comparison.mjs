import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { findEvidence, projectProfile, scan } from '../game_prompt_studio/lib/index.mjs';
import { buildDraft, checkExport, createOllama } from '../game_prompt_studio/lib/model.mjs';

const dryRun = process.argv.includes('--dry-run');
const project = fileURLToPath(new URL('../../', import.meta.url));
const note = 'My fishing rod flickers or disappears for a guest when I equip it. The host still sees it.';
const title = 'Fishing rod visibility for guests';
const settings = { model: 'qwen3:14b', context: 8192, keepAliveMinutes: 2 };
const traceInstructions = [
  'When the retrieved code shows state moving between components, trace that state in the brief.',
  'Name the exact state value, where it is produced or received, and the conditions that consume it. Cite the source ID next to each observation.',
  'Propose a diagnostic that compares the value and relevant conditions at both ends of the path during reproduction. Specify host and guest roles for multiplayer.',
  'If any link in the path is missing from the excerpts, label it unverified and tell Codex what to inspect. Do not propose a fix unsupported by the excerpt.',
].join('\n');

const storage = mkdtempSync(join(tmpdir(), 'houseboat-prompt-comparison-'));
const db = openDb(storage);
let evidence;
let facts;
try {
  scan(db, project);
  evidence = findEvidence(db, note, [], 5800);
  facts = projectProfile(db);
} finally {
  db.close();
  rmSync(storage, { recursive: true, force: true });
}

assert.ok(evidence.some(item => item.path === 'godot-cove/river_crew.gd'
  && /for key in \["rod", "line"/.test(item.excerpt)), 'The retrieved excerpts must include the multiplayer rod flag.');
assert.ok(evidence.some(item => item.path === 'godot-cove/crew_avatar.gd'
  && /rod\.visible = show_rod/.test(item.excerpt)), 'The retrieved excerpts must include the avatar visibility rule.');

const requests = [];
const results = [];
for (const mode of ['baseline', 'trace instructions']) {
  const ollama = createOllama(11434, async (url, options) => {
    if (new URL(url).pathname === '/api/chat') {
      const body = JSON.parse(options.body);
      if (mode !== 'baseline') body.messages[0].content += '\n' + traceInstructions;
      requests.push(structuredClone(body));
      options = { ...options, body: JSON.stringify(body) };
    }
    if (!dryRun) return fetch(url, options);
    if (new URL(url).pathname === '/api/tags') {
      return Response.json({ models: [{ name: settings.model }] });
    }
    const sample = Object.fromEntries(
      ['objective', 'observations', 'tasks', 'verification', 'acceptance', 'unknowns']
        .map(field => [field, ['Simulated response for request verification.']])
    );
    return Response.json({ message: { content: JSON.stringify(sample) } });
  });
  const start = performance.now();
  try {
    const { payload, metrics } = await ollama.generate({
      input: { note, tier: 'detailed', priority: 'Normal', tags: '' },
      facts, evidence, settings, signal: AbortSignal.timeout(240_000),
    });
    const brief = buildDraft(payload, title, facts, evidence, note);
    const findings = checkExport(brief, evidence, facts);
    results.push({ mode, seconds: Number(((performance.now() - start) / 1000).toFixed(1)),
      export: findings.length ? 'blocked' : 'passed', findings, metrics,
      ...(!dryRun && !findings.length ? { brief } : {}) });
  } catch (error) {
    results.push({ mode, error: error.message });
  }
}

let sameModelInputs = false;
if (requests.length === 2) {
  const [baseline, revised] = requests;
  assert.equal(revised.messages[0].content, baseline.messages[0].content + '\n' + traceInstructions);
  revised.messages[0].content = baseline.messages[0].content;
  assert.deepEqual(revised, baseline);
  sameModelInputs = true;
}

const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: project, encoding: 'utf8' }).trim();
console.log(JSON.stringify({ commit, dryRun, model: settings.model, note, sameModelInputs,
  sources: evidence.filter(item => item.kind === 'source'), results }, null, 2));
if (!sameModelInputs || results.some(result => result.export !== 'passed')) process.exitCode = 1;
