import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { buildDraft, checkExport, createOllama } from '../../game_prompt_studio/lib/model.mjs';
import { buildCodeIndex } from './code-index.mjs';
import { collectEvidence, createPlanner } from './retrieval.mjs';

const { values } = parseArgs({ options: {
  source: { type: 'string' }, report: { type: 'string' }, history: { type: 'string' },
  generate: { type: 'boolean' }, details: { type: 'boolean' }, port: { type: 'string', default: '11434' },
} });
if (!values.source || !values.report) throw new Error('Supply a clean --source checkout and explicit --report text file.');
const root = resolve(values.source);
const note = readFileSync(values.report, 'utf8').trim();
if (!note || note.length > 6500) throw new Error('Report must contain 1–6500 characters.');
const port = Number(values.port);
if (!Number.isInteger(port) || port < 1 || port > 65535) throw new Error('Invalid local Ollama port.');
const options = { encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } };
const git = (...args) => execFileSync('git', ['-C', root, ...args], options);
const indexScript = resolve(dirname(fileURLToPath(import.meta.url)), '../../knowledge/index.py');
const raw = execFileSync(process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python', [indexScript, '--root', root], options);
const manifest = JSON.parse(raw);
if (manifest.dirty || git('status', '--porcelain', '--', 'docs', 'tools/godot-lookup').trim()) {
  throw new Error('Commit or isolate source and guide changes before retrieving pinned evidence.');
}
const tracked = git('ls-files', '-z').split('\0').filter(Boolean);
const history = values.history ? JSON.parse(readFileSync(values.history, 'utf8')) : undefined;
const index = buildCodeIndex(root, manifest, tracked, { history });
const settings = { model: 'qwen3:14b', context: 8192, keepAliveMinutes: 2 };
const signal = AbortSignal.timeout(120_000);
const planner = values.generate ? createPlanner({ port, settings, seed: 1703 }) : undefined;
const { evidence, planning } = await collectEvidence(index, note, { planner, signal });
const result = { revision: manifest.revision, index: index.stats, planning,
  sources: evidence.map(({ id, kind, path, line, title }) => ({ id, kind, path, line, title })),
  ...(values.details ? { evidence } : {}) };
if (values.generate) {
  const { payload, metrics } = await createOllama(port).generate({ input: { note, tier: 'detailed', priority: '', tags: '' },
    facts: [], evidence, settings, signal });
  const draft = buildDraft(payload, 'Experimental implementation brief', [], evidence, note);
  const findings = checkExport(draft, evidence, []);
  Object.assign(result, { generation: metrics, findings, ...(findings.length ? {} : { draft }) });
  if (findings.length) process.exitCode = 1;
}
console.log(JSON.stringify(result, null, 2));
