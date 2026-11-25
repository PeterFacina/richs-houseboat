import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { sourceKnowledge } from './source-knowledge.mjs';
import { openTrainingInbox } from './training-inbox.mjs';
import { workerGeneration } from './worker-generation.mjs';
import { retrievalConfig } from './production-retrieval.mjs';
import { remote, repository } from './workflow.mjs';

const note = 'When the houseboat spawns at the marina, it does not drift until I take the helm. ' +
  'Trace passive_water_velocity and check host and guest views.';
const model = process.env.STUDIO_MODEL || 'qwen3:14b';
const retrieval = retrievalConfig(process.env.HOUSEBOAT_RETRIEVAL_MODE);
const storage = mkdtempSync(join(tmpdir(), 'houseboat-knowledge-smoke-'));
const db = openDb(storage);
const inbox = openTrainingInbox(join(storage, 'training.sqlite'));
const knowledge = sourceKnowledge({ db, storage, remote, python: process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python' });
const github = async path => {
  const token = process.env.GITHUB_TOKEN;
  const response = await fetch('https://api.github.com/repos/' + repository + path, {
    headers: { Accept: 'application/vnd.github+json', ...(token ? { Authorization: 'Bearer ' + token } : {}) },
    redirect: 'error', signal: AbortSignal.timeout(15_000),
  });
  if (!response.ok) throw new Error('GitHub returned HTTP ' + response.status);
  return response.json();
};

let worker;
try {
  const start = performance.now();
  const initial = await knowledge.refresh();
  const coldMs = Math.round(performance.now() - start);
  const beforeGeneration = performance.now();
  worker = await workerGeneration({ storage, model, knowledge, github, inbox, retrieval });
  let failure;
  try { await worker.generate(note, { number: 0, html_url: null }); } catch (error) { failure = error; }
  const capture = inbox.read(0).captures.at(-1);
  if (!capture) throw failure ?? new Error('No training capture.');
  const input = capture.input;
  if (input.knowledge.retrieval.effective !== retrieval.mode) throw new Error('Smoke test fell back to another retrieval mode.');
  console.log(JSON.stringify({ indexedCommit: input.commit, initialCommit: initial.commit, coldMs,
    elapsedMs: Math.round(performance.now() - beforeGeneration), exportPassed: input.exportPassed,
    stale: input.knowledge.stale, githubContextComplete: input.knowledge.githubContextComplete, retrieval: input.knowledge.retrieval,
    contextBytes: input.contextBytes, model: input.model, promptTokens: input.metrics.promptTokens,
    outputTokens: input.metrics.outputTokens, durationMs: input.metrics.durationMs,
    guides: input.retrievedContext.filter(item => item.kind === 'guide').map(item => item.path),
    sourceCount: input.retrievedContext.filter(item => item.kind === 'source').length,
    taskCount: input.retrievedContext.filter(item => item.kind === 'github').length }));
  if (failure) throw failure;
} finally {
  await worker?.close();
  inbox.close();
  db.close();
  rmSync(storage, { recursive: true, force: true });
}
