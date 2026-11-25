import { readFileSync, writeFileSync } from 'node:fs';
import { parseArgs } from 'node:util';
import { localSource } from './local-source.mjs';
import { buildLearningIndex, noteKey, rankedFunctions } from './retrieval.mjs';
import { symbolKey } from './relationships.mjs';

const { values } = parseArgs({ options: {
  source: { type: 'string' }, port: { type: 'string' }, out: { type: 'string' }, report: { type: 'string', multiple: true },
} });
const port = Number(values.port);
if (!values.source || !values.out || !Number.isInteger(port) || port < 1024 || port > 65535 || port === 11434) {
  throw new Error('Supply --source, --out and a separate local embedding --port');
}
const { root, manifest, tracked } = localSource(values.source);
const read = name => JSON.parse(readFileSync(new URL(`../${name}`, import.meta.url), 'utf8'));
const reports = values.report?.map(path => readFileSync(path, 'utf8').trim())
  ?? ['heldout-cases.json', 'multistage-cases.json', 'learning-cases.json'].flatMap(name => read(name).cases.map(item => item.note));
if (reports.length > 20 || reports.some(note => !note || note.length > 6500)) {
  throw new Error('Supply up to 20 reports containing 1–6500 characters each');
}
const index = buildLearningIndex(root, manifest, tracked);
const candidates = new Map();
for (const note of reports) for (const item of rankedFunctions(index, note).result.slice(0, 45)) candidates.set(symbolKey(item), item);

const url = `http://127.0.0.1:${port}`;
const model = 'qwen3-embedding:0.6b';
const tags = await fetch(`${url}/api/tags`, { redirect: 'error', signal: AbortSignal.timeout(5000) });
if (!tags.ok) throw new Error(`Embedding model list returned ${tags.status}`);
const digest = (await tags.json()).models.find(item => item.name === model)?.digest;
if (!digest) throw new Error(`Missing isolated model ${model}`);
let tokens = 0;
const start = performance.now();
const embed = async input => {
  const response = await fetch(`${url}/api/embed`, { method: 'POST', redirect: 'error', signal: AbortSignal.timeout(90_000),
    headers: { 'Content-Type': 'application/json' },
    body: JSON.stringify({ model, input, dimensions: 256, truncate: true, keep_alive: '30s' }) });
  if (!response.ok) throw new Error(`Embedding request returned ${response.status}`);
  const result = await response.json();
  if (!Array.isArray(result.embeddings) || result.embeddings.length !== input.length ||
      result.embeddings.some(vector => vector.length !== 256 || vector.some(value => !Number.isFinite(value)))) {
    throw new Error('Unexpected embeddings response');
  }
  tokens += result.prompt_eval_count ?? 0;
  return result.embeddings;
};
const queryVectors = await embed(reports.map(note => 'Instruct: Given a gameplay report, retrieve source functions that implement the reported behavior.\nQuery: ' + note));
const queries = Object.fromEntries(reports.map((note, i) => [noteKey(note), queryVectors[i]]));
const documents = {};
const records = [...candidates];
for (let first = 0; first < records.length; first += 24) {
  const batch = records.slice(first, first + 24);
  const results = await embed(batch.map(([key, item]) => key + '\n' + item.lines.join('\n').slice(0, 850)));
  for (const [i, [key]] of batch.entries()) documents[key] = results[i];
}
const loaded = await fetch(`${url}/api/ps`, { redirect: 'error', signal: AbortSignal.timeout(5000) });
const vram = loaded.ok ? (await loaded.json()).models.find(item => item.name === model)?.size_vram : null;
const summary = { revision: manifest.revision, model, digest, dimensions: 256, reportCount: reports.length,
  functionCount: candidates.size, tokens, milliseconds: Math.round(performance.now() - start), vram };
writeFileSync(values.out, JSON.stringify({ ...summary, queries, documents }), { flag: 'wx' });
console.log(JSON.stringify(summary));
