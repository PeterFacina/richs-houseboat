import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { setTimeout as delay } from 'node:timers/promises';
import { fileURLToPath } from 'node:url';
import { createStudio } from '../game_prompt_studio/server.mjs';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { scan } from '../game_prompt_studio/lib/index.mjs';
import { createOllama, isLocalModel } from '../game_prompt_studio/lib/model.mjs';
import { pages, processGpuIssue, queuedReport } from './gpu-queue.mjs';
import { studioClient } from './studio.mjs';
import { repository } from './workflow.mjs';

const token = process.env.GITHUB_TOKEN;
const model = process.env.STUDIO_MODEL ?? 'qwen3:14b';
if (!token) throw new Error('Set GITHUB_TOKEN in the worker’s local .worker.env file.');
if (!isLocalModel(model)) throw new Error('STUDIO_MODEL must name a tagged local model.');
const project = fileURLToPath(new URL('../../', import.meta.url));
const stop = new AbortController();
for (const event of ['SIGINT', 'SIGTERM']) process.once(event, () => stop.abort());

async function github(path, method = 'GET', body) {
  const response = await fetch('https://api.github.com/repos/' + repository + path, {
    method,
    redirect: 'error',
    headers: { Authorization: 'Bearer ' + token, Accept: 'application/vnd.github+json',
      'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
    signal: AbortSignal.any([stop.signal, AbortSignal.timeout(15000)]),
  });
  if (!response.ok) throw new Error('GitHub ' + method + ' ' + path + ' returned HTTP ' + response.status);
  return response.json();
}

const retryAt = new Map();
async function poll(generate) {
  const waiting = [];
  for await (const batch of pages(github, '/issues?state=open&sort=created&direction=asc')) {
    waiting.push(...batch.filter(issue => queuedReport(issue)));
  }
  const open = new Set(waiting.map(issue => issue.number));
  for (const number of retryAt.keys()) if (!open.has(number)) retryAt.delete(number);
  for (const issue of waiting) {
    if (stop.signal.aborted) break;
    if ((retryAt.get(issue.number) ?? 0) > Date.now()) continue;
    try {
      const result = await processGpuIssue(issue, github, generate);
      if (result.status !== 'already posted') console.log('Issue #' + issue.number + ': ' + result.status);
      retryAt.delete(issue.number);
    } catch (error) {
      if (!stop.signal.aborted) {
        retryAt.set(issue.number, Date.now() + 120_000);
        console.error('Issue #' + issue.number + ': ' + error.message);
      }
    }
  }
}

const storage = mkdtempSync(join(tmpdir(), 'houseboat-gpu-worker-'));
let server;
try {
  const options = { port: 8765, ollamaPort: 11434, model, context: 8192, keepAliveMinutes: 2,
    tier: 'detailed', privateOrigin: '', exclude: [] };
  const installed = await createOllama(options.ollamaPort).status();
  if (!installed.models.some(entry => entry.name === model)) throw new Error('Ollama is missing ' + model + '.');
  const db = openDb(storage);
  try { scan(db, project, options.exclude); } finally { db.close(); }
  server = createStudio({ project, storage, options });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const generate = studioClient('http://127.0.0.1:' + server.address().port);
  console.log('Houseboat GPU worker is watching GitHub for queued reports.');
  while (!stop.signal.aborted) {
    try { await poll(generate); } catch (error) {
      if (!stop.signal.aborted) console.error(error.message);
    }
    await delay(30_000, undefined, { signal: stop.signal }).catch(error => {
      if (error.name !== 'AbortError') throw error;
    });
  }
} finally {
  if (server?.listening) {
    const closed = once(server, 'close');
    server.close();
    server.closeAllConnections();
    await closed;
  }
  rmSync(storage, { recursive: true, force: true });
}
