import { once } from 'node:events';
import { execFileSync } from 'node:child_process';
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
import { openTrainingInbox } from './training-inbox.mjs';

const token = process.env.GITHUB_TOKEN;
const model = process.env.STUDIO_MODEL ?? 'qwen3:14b';
if (!token) throw new Error('Set GITHUB_TOKEN in the worker’s local .worker.env file.');
if (!isLocalModel(model)) throw new Error('STUDIO_MODEL must name a tagged local model.');
const project = fileURLToPath(new URL('../../', import.meta.url));
const commit = execFileSync('git', ['rev-parse', 'HEAD'], { cwd: project, encoding: 'utf8' }).trim();
if (execFileSync('git', ['status', '--porcelain', '--untracked-files=all', '--', 'godot-cove'],
  { cwd: project, encoding: 'utf8' }).trim()) throw new Error('Use a clean game checkout to capture source provenance.');
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
async function poll(generate, linkBrief) {
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
      const result = await processGpuIssue(issue, github, generate, linkBrief);
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
let inbox;
try {
  const options = { port: 8765, ollamaPort: 11434, model, context: 8192, keepAliveMinutes: 2,
    tier: 'detailed', privateOrigin: '', exclude: [] };
  const installed = await createOllama(options.ollamaPort).status();
  if (!installed.models.some(entry => entry.name === model)) throw new Error('Ollama is missing ' + model + '.');
  const db = openDb(storage);
  try { scan(db, project, options.exclude); } finally { db.close(); }
  inbox = openTrainingInbox();
  let request;
  const provider = createOllama(options.ollamaPort, async (url, init) => {
    if (new URL(url).pathname === '/api/chat') request = JSON.parse(init.body);
    return fetch(url, init);
  });
  server = createStudio({ project, storage, options, provider });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const generateBrief = studioClient('http://127.0.0.1:' + server.address().port);
  async function generate(note, issue) {
    request = null;
    const brief = (await generateBrief(note)).trim();
    if (!request || JSON.parse(request.messages[1].content).currentRequest.note !== note) {
      throw new Error('Could not match the model request to the report.');
    }
    inbox.capture(issue.number, { repository, issueUrl: issue.html_url, report: note, commit, request }, brief);
    return brief;
  }
  console.log('Houseboat GPU worker is watching GitHub for queued reports.');
  while (!stop.signal.aborted) {
    try { await poll(generate, inbox.link); } catch (error) {
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
  inbox?.close();
}
