import { mkdirSync, readFileSync } from 'node:fs';
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
import { collectDevelopmentOutcomes } from './development-outcomes.mjs';
import { gpuWorkLock } from './gpu-work-lock.mjs';

const token = process.env.GITHUB_TOKEN;
const local = process.env.LOCALAPPDATA || homedir();
const lockDir = join(local, 'HouseboatPromptTraining');
function selectedModel() {
  let selection;
  try { selection = JSON.parse(readFileSync(join(lockDir, 'production-model.json'), 'utf8')); }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const chosen = selection?.model ?? process.env.STUDIO_MODEL ?? 'qwen3:14b';
  if (!isLocalModel(chosen)) throw new Error('Select a tagged local model.');
  return chosen;
}
let model = selectedModel();
const retrieval = retrievalConfig(process.env.HOUSEBOAT_RETRIEVAL_MODE, process.env.HOUSEBOAT_RETRIEVAL_CANARY_ISSUES);
if (!token) throw new Error('Set GITHUB_TOKEN in the worker’s local .worker.env file.');
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
const guardHolds = new Map();
async function poll(generate, linkBrief) {
  const waiting = [];
  for await (const batch of pages(github, '/issues?state=open&sort=created&direction=asc')) {
    waiting.push(...batch.filter(issue => queuedReport(issue)));
  }
  const open = new Set(waiting.map(issue => issue.number));
  for (const number of retryAt.keys()) if (!open.has(number)) retryAt.delete(number);
  for (const number of guardHolds.keys()) if (!open.has(number)) guardHolds.delete(number);
  for (const issue of waiting) {
    if (stop.signal.aborted) break;
    if (guardHolds.get(issue.number) === queuedReport(issue)) continue;
    if ((retryAt.get(issue.number) ?? 0) > Date.now()) continue;
    try {
      const result = await processGpuIssue(issue, github, generate, linkBrief);
      if (result.status !== 'already posted') console.log('Issue #' + issue.number + ': ' + result.status);
      retryAt.delete(issue.number);
    } catch (error) {
      if (!stop.signal.aborted) {
        if (error.code === 'GUARD_REVIEW_REQUIRED') {
          guardHolds.set(issue.number, queuedReport(issue));
          console.error('Issue #' + issue.number + ': ' + error.message);
          continue;
        }
        retryAt.set(issue.number, Date.now() + 120_000);
        console.error('Issue #' + issue.number + ': ' + error.message);
      }
    }
  }
}

const storage = resolve(process.env.HOUSEBOAT_KNOWLEDGE_DIR || join(local, 'HouseboatGpuKnowledge'));
mkdirSync(lockDir, { recursive: true });
const lock = new DatabaseSync(join(lockDir, 'worker-lock.sqlite'));
let db;
let generation;
let inbox;
let status;
let gpu;
try {
  try { lock.exec('BEGIN EXCLUSIVE'); } catch (error) {
    if (error.errcode !== 5) throw error;
    throw new Error('Another GPU worker already holds the local queue lock.');
  }
  const installed = await createOllama(11434).status();
  const modelInfo = installed.models.find(entry => entry.name === model);
  if (!modelInfo) throw new Error('Ollama is missing ' + model + '.');
  db = openDb(storage);
  if (process.env.HOUSEBOAT_DASHBOARD_STATUS === '1') status = workerStatus(storage, { model, modelDigest: modelInfo.digest, retrieval });
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
  gpu = gpuWorkLock(lockDir);
  try {
    const state = await knowledge.refresh();
    console.log('Worker knowledge revision ' + state.commit + (state.stale ? ' (stale).' : '.'));
  } catch (error) {
    console.error(error.message);
  }
  generation = await workerGeneration({ storage, model, knowledge, github, inbox, retrieval });
  console.log(`Worker retrieval mode ${retrieval.mode}${retrieval.issue ? ' for canary issue #' + retrieval.issue : ''}.`);
  console.log('Houseboat GPU worker is watching GitHub for queued reports.');
  let nextSync = Date.now() + 300_000;
  let nextOutcomes = Date.now();
  while (!stop.signal.aborted) {
    try {
      const chosen = selectedModel();
      if (chosen !== model) {
        const installed = await createOllama(11434).status();
        const info = installed.models.find(entry => entry.name === chosen);
        if (!info) throw new Error('The approved model is unavailable.');
        const next = await workerGeneration({ storage, model: chosen, knowledge, github, inbox, retrieval });
        await generation.close();
        generation = next;
        model = chosen;
        status?.model(chosen, info.digest);
      }
      status?.phase('watching');
      await poll((...args) => gpu.run(async () => {
        status?.phase('generating', args[1].number);
        try { return await generation.generate(...args); }
        finally { status?.phase('watching'); }
      }), inbox.link);
      status?.warning(null);
    } catch (error) {
      if (!stop.signal.aborted) {
        status?.phase('degraded');
        status?.warning('github-queue');
        console.error(error.message);
      }
    }
    if (!stop.signal.aborted && Date.now() >= nextSync) {
      nextSync = Date.now() + 300_000;
      await knowledge.refresh().catch(() => console.warn('Could not refresh game knowledge.'));
    }
    if (!stop.signal.aborted && Date.now() >= nextOutcomes) {
      nextOutcomes = Date.now() + 600_000;
      try {
        const updated = await collectDevelopmentOutcomes(github, inbox);
        if (updated) console.log('Updated GitHub development outcomes: ' + updated);
      } catch {
        status?.warning('github-outcomes');
        console.warn('Could not collect GitHub development outcomes.');
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
  gpu?.close();
  lock.close();
}
