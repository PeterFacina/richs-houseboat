import { execFileSync } from 'node:child_process';
import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { parseArgs } from 'node:util';
import { buildDraft, checkExport, createOllama } from '../../game_prompt_studio/lib/model.mjs';
import { buildCodeIndex } from './code-index.mjs';
import { collectEvidence, createPlanner } from './retrieval.mjs';
import { buildLearningIndex, retrieve } from '../learning/retrieval.mjs';
import { sourceGuidance } from '../learning/prompt.mjs';

const { values } = parseArgs({ options: {
  source: { type: 'string' }, report: { type: 'string' }, history: { type: 'string' },
  generate: { type: 'boolean' }, details: { type: 'boolean' }, port: { type: 'string', default: '11434' },
  learning: { type: 'boolean' }, planner: { type: 'boolean' },
  lessons: { type: 'string' }, graph: { type: 'string' }, embeddings: { type: 'string' },
} });
if (!values.source || !values.report) throw new Error('Supply a clean --source checkout and explicit --report text file.');
if (!values.learning && (values.planner || values.lessons || values.graph || values.embeddings)) {
  throw new Error('Candidate settings require --learning.');
}
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
const optionalJson = path => path ? JSON.parse(readFileSync(path, 'utf8')) : undefined;
const index = values.learning ? buildLearningIndex(root, manifest, tracked, { history,
  lessons: optionalJson(values.lessons), graph: optionalJson(values.graph), embeddings: optionalJson(values.embeddings) })
  : buildCodeIndex(root, manifest, tracked, { history });
const settings = { model: 'qwen3:14b', context: 8192, keepAliveMinutes: 2 };
const signal = AbortSignal.timeout(120_000);
const planner = (values.learning ? values.planner : values.generate) ? createPlanner({ port, settings, seed: 1703 }) : undefined;
const collect = values.learning ? retrieve : collectEvidence;
const { evidence, planning, lessonIds } = await collect(index, note, { planner, signal });
const result = { revision: manifest.revision, index: index.stats, planning, lessonIds,
  sources: evidence.map(({ id, kind, path, line, title }) => ({ id, kind, path, line, title })),
  ...(values.details ? { evidence } : {}) };
if (values.generate) {
  const fetcher = (url, init) => {
    if (!values.learning || !url.endsWith('/api/chat')) return fetch(url, init);
    const request = JSON.parse(init.body);
    request.messages[0].content += '\n' + sourceGuidance;
    request.options.seed = 1703;
    return fetch(url, { ...init, body: JSON.stringify(request) });
  };
  const { payload, metrics } = await createOllama(port, fetcher).generate({ input: { note, tier: 'detailed', priority: '', tags: '' },
    facts: [], evidence, settings, signal });
  const draft = buildDraft(payload, 'Experimental implementation brief', [], evidence, note);
  const findings = checkExport(draft, evidence, []);
  Object.assign(result, { generation: metrics, findings, ...(findings.length ? {} : { draft }) });
  if (findings.length) process.exitCode = 1;
}
console.log(JSON.stringify(result, null, 2));
