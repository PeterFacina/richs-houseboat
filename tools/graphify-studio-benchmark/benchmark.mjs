import { execFileSync } from 'node:child_process';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createStudio } from '../game_prompt_studio/server.mjs';
import { createOllama } from '../game_prompt_studio/lib/model.mjs';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { scan } from '../game_prompt_studio/lib/index.mjs';
import { studioClient } from '../discord-issue-pilot/studio.mjs';

const [python, snapshot, ...flags] = process.argv.slice(2);
if (!python || !snapshot || flags.some(flag => flag !== '--retrieval-only')) {
  throw new Error('Usage: node benchmark.mjs <python> <snapshot> [--retrieval-only]');
}
const retrievalOnly = flags.includes('--retrieval-only');
const project = fileURLToPath(new URL('../../', import.meta.url));
const query = fileURLToPath(new URL('./query.py', import.meta.url));
const options = { port: 8765, ollamaPort: 11434, model: 'qwen3:14b', context: 8192,
  keepAliveMinutes: 2, tier: 'detailed', privateOrigin: '', exclude: [] };
const reports = [
  { name: 'Zero Turn', keywords: 'zero turn mower steering hands',
    note: 'When I make a sharp left turn on the Zero Turn, the driver’s steering hands jerk out of place. I haven’t checked whether a guest can see it.' },
  { name: 'Fishing rod', keywords: 'remote fishing rod visibility',
    note: 'My fishing rod flickers or disappears for a guest when I equip it. The host still sees it.' },
  { name: 'Shoreline', keywords: 'Ottawa map shoreline terrain',
    note: 'The Ottawa River shoreline terrain has a visible gap near the marina when I approach by boat.' },
];

async function run(report, mode, focus) {
  const storage = mkdtempSync(join(tmpdir(), 'houseboat-graphify-benchmark-'));
  const result = { report: report.name, note: report.note, keywords: report.keywords, mode, focus };
  const ollama = createOllama(options.ollamaPort);
  let server;
  try {
    const db = openDb(storage);
    try { scan(db, project, options.exclude); } finally { db.close(); }
    server = createStudio({ project, storage, options, provider: {
      async generate(request) {
        result.sources = request.evidence.filter(item => item.kind === 'source');
        if (retrievalOnly) return { payload: {
          objective: ['Investigate the report.'], observations: ['The behavior is reported.'],
          tasks: ['Inspect relevant code.'], verification: ['Reproduce the behavior.'],
          acceptance: ['Verify the expected behavior.'], unknowns: ['The cause has not been verified.'],
        }, metrics: {} };
        const response = await ollama.generate(request);
        result.metrics = response.metrics;
        return response;
      },
    } });
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    const generate = studioClient('http://127.0.0.1:' + server.address().port);
    const start = performance.now();
    try {
      const brief = await generate(report.note, focus);
      if (!retrievalOnly) result.brief = brief;
      result.export = 'passed';
    } finally {
      result.seconds = Number(((performance.now() - start) / 1000).toFixed(1));
    }
  } catch (error) {
    result.error = error.message;
  } finally {
    if (server?.listening) {
      const closed = once(server, 'close');
      server.close();
      server.closeAllConnections();
      await closed;
    }
    rmSync(storage, { recursive: true, force: true });
  }
  return result;
}

const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: project, encoding: 'utf8' }).trim();
const results = [];
for (const report of reports) {
  const shortlist = execFileSync(python, [query, report.keywords, '--snapshot', snapshot, '--limit', '2'],
    { encoding: 'utf8' });
  const focus = [...shortlist.matchAll(/^FILE (.+) \(/gm)].map(match => 'godot-cove/' + match[1]);
  if (!focus.length) throw new Error('Graphify returned no files for ' + report.name);
  results.push(await run(report, 'Studio alone', []));
  results.push(await run(report, 'Studio with Graphify hints', focus));
}
console.log(JSON.stringify({ commit, retrievalOnly, model: options.model, context: options.context, results }, null, 2));
if (results.some(result => result.error)) process.exitCode = 1;
