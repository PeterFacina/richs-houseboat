import { mkdirSync } from 'node:fs';
import { homedir } from 'node:os';
import { join, resolve } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { setTimeout as delay } from 'node:timers/promises';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { createOllama, isLocalModel } from '../game_prompt_studio/lib/model.mjs';
import { pages, processGpuIssue, queuedReport } from './gpu-queue.mjs';
import { sourceKnowledge } from './source-knowledge.mjs';
import { workerGeneration } from './worker-generation.mjs';
import { repository } from './workflow.mjs';
import { openTrainingInbox } from './training-inbox.mjs';
import { retrievalConfig } from './production-retrieval.mjs';
import { workerStatus } from './worker-status.mjs';

const token = process.env.GITHUB_TOKEN;
const model = process.env.STUDIO_MODEL ?? 'qwen3:14b';
const retrieval = retrievalConfig(process.env.HOUSEBOAT_RETRIEVAL_MODE, process.env.HOUSEBOAT_RETRIEVAL_CANARY_ISSUES);
if (!token) throw new Error('Set GITHUB_TOKEN in the worker’s local .worker.env file.');
if (!isLocalModel(model)) throw new Error('STUDIO_MODEL must name a tagged local model.');
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

const local = process.env.LOCALAPPDATA || homedir();
const storage = resolve(process.env.HOUSEBOAT_KNOWLEDGE_DIR || join(local, 'HouseboatGpuKnowledge'));
const lockDir = join(local, 'HouseboatPromptTraining');
mkdirSync(lockDir, { recursive: true });
const lock = new DatabaseSync(join(lockDir, 'worker-lock.sqlite'));
let db;
let generation;
let inbox;
let status;
try {
  try { lock.exec('BEGIN EXCLUSIVE'); } catch (error) {
    if (error.errcode !== 5) throw error;
    throw new Error('Another GPU worker already holds the local queue lock.');
  }
  const installed = await createOllama(11434).status();
  if (!installed.models.some(entry => entry.name === model)) throw new Error('Ollama is missing ' + model + '.');
  db = openDb(storage);
  if (process.env.HOUSEBOAT_DASHBOARD_STATUS === '1') status = workerStatus(storage, { model, retrieval });
  const source = sourceKnowledge({ db, storage, remote: 'https://github.com/' + repository + '.git',
    python: process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python' });
  const knowledge = status ? { ...source, async refresh() {
    try {
      const state = await source.refresh();
      status.knowledge(state);
      return state;
    } catch (error) {
      status.knowledge(null);
      throw error;
    }
  } } : source;
  inbox = openTrainingInbox();
  try {
    const state = await knowledge.refresh();
    console.log('Worker knowledge revision ' + state.commit + (state.stale ? ' (stale).' : '.'));
  } catch (error) {
    console.error(error.message);
  }
  generation = await workerGeneration({ storage, model, knowledge, github, inbox, retrieval });
  console.log(`Worker retrieval mode ${retrieval.mode}${retrieval.issue ? ' for canary issue #' + retrieval.issue : ''}.`);
  console.log('Houseboat GPU worker is watching GitHub for queued reports.');
  while (!stop.signal.aborted) {
    try {
      status?.phase('watching');
      await poll(status ? async (...args) => {
        status.phase('generating');
        try { return await generation.generate(...args); }
        finally { status.phase('watching'); }
      } : generation.generate, inbox.link);
    } catch (error) {
      if (!stop.signal.aborted) {
        status?.phase('degraded');
        console.error(error.message);
      }
    }
    await delay(30_000, undefined, { signal: stop.signal }).catch(error => {
      if (error.name !== 'AbortError') throw error;
    });
  }
} finally {
  await status?.close();
  await generation?.close();
  db?.close();
  inbox?.close();
  lock.close();
}
