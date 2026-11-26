// Explicit operator-only canary. This is never imported by the worker/scheduler.
import { existsSync, mkdirSync, writeFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { DatabaseSync, backup } from 'node:sqlite';
import { execFileSync } from 'node:child_process';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { sourceKnowledge } from './source-knowledge.mjs';
import { workerGeneration } from './worker-generation.mjs';
import { openTrainingInbox } from './training-inbox.mjs';
import { processGpuJob } from './process-gpu-job.mjs';
import { retrievalConfig } from './production-retrieval.mjs';
import { gpuWorkLock } from './gpu-work-lock.mjs';
import { gpuBriefMarker } from './workflow.mjs';

const [authorization, issueArg, directory] = process.argv.slice(2);
if (authorization !== '--authorize-one-generation' || !/^[1-9]\d*$/.test(issueArg ?? '') || !directory || !process.env.GITHUB_TOKEN) {
  throw new Error('Supply --authorize-one-generation ISSUE NEW_PRIVATE_DIRECTORY and the existing GitHub credential.');
}
const root = resolve(directory), issueNumber = Number(issueArg);
if (existsSync(root)) throw new Error('Use a new private directory; refusing to overwrite or repeat a canary.');
const local = process.env.LOCALAPPDATA;
if (!local || !process.env.HOUSEBOAT_KNOWLEDGE_PYTHON) throw new Error('Use the GPU host and its existing knowledge Python.');
// Verify both the scheduler AND actual child processes; stopping cmd.exe alone
// does not necessarily terminate its Node child on Windows.
const containmentCheck = String.raw`$t=Get-ScheduledTask -TaskName 'Houseboat GPU Production Worker'; if($t.Settings.Enabled -or $t.State -eq 'Running'){exit 1};
  $p=@(Get-CimInstance Win32_Process|Where-Object {$_.Name -match '^node' -and $_.CommandLine -match '[\\/]gpu-worker[.]mjs"?(\s|$)'}); if($p.Count){exit 2}`;
execFileSync('powershell.exe', ['-NoProfile', '-Command', containmentCheck],
{ windowsHide: true, stdio: 'pipe' });
mkdirSync(root, { recursive: true });
const storage = join(root, 'storage'), inboxPath = join(root, 'examples.sqlite');
mkdirSync(storage);
for (const [from, to] of [
  [join(local, 'HouseboatPromptTraining', 'examples.sqlite'), join(root, 'production-before.sqlite')],
]) {
  const db = new DatabaseSync(from, { readOnly: true });
  try { await backup(db, to); } finally { db.close(); }
}
const github = async (path, method = 'GET', body) => {
  const response = await fetch('https://api.github.com/repos/PeterFacina/richs-houseboat' + path, {
    method, redirect: 'error', signal: AbortSignal.timeout(15_000),
    headers: { Authorization: 'Bearer ' + process.env.GITHUB_TOKEN, Accept: 'application/vnd.github+json', 'Content-Type': 'application/json' },
    body: body === undefined ? undefined : JSON.stringify(body),
  });
  if (!response.ok) throw new Error('GitHub returned HTTP ' + response.status);
  return response.json();
};
let db, inbox, generation, gate, requests = 0, tokens = null;
try {
  const issue = await github('/issues/' + issueNumber);
  if (!issue.title.startsWith('Infrastructure canary: PR 134')) throw new Error('Use a clearly labeled synthetic infrastructure canary.');
  db = openDb(storage); inbox = openTrainingInbox(inboxPath);
  const knowledge = sourceKnowledge({ db, storage, remote: 'https://github.com/PeterFacina/richs-houseboat.git',
    python: process.env.HOUSEBOAT_KNOWLEDGE_PYTHON });
  const source = await knowledge.refresh();
  if (source.stale) throw new Error('Canary requires a fresh source checkout.');
  await knowledge.withVerifiedCheckout(source.commit, () => true);
  generation = await workerGeneration({ storage, model: 'qwen3:14b', knowledge, github, inbox,
    retrieval: retrievalConfig('deterministic-v1', 'all'), fetchOllama: async (url, init) => {
      if (new URL(url).pathname === '/api/chat') {
        if (requests >= 1) throw new Error('Canary hard cap: one model request.');
        requests++;
      }
      const response = await fetch(url, init);
      if (new URL(url).pathname === '/api/chat') {
        const result = await response.clone().json();
        tokens = { input: result.prompt_eval_count, output: result.eval_count, doneReason: result.done_reason };
      }
      return response;
    } });
  gate = gpuWorkLock(join(local, 'HouseboatPromptTraining'));
  const first = await gate.run(() => processGpuJob(issue, github, generation.generate, inbox));
  if (first.status !== 'posted') throw new Error('Canary did not publish: ' + JSON.stringify(first));
  for (let n = 0; n < 3; n++) {
    if ((await processGpuJob(issue, github, generation.generate, inbox)).status !== 'already posted') throw new Error('Poll deduplication failed.');
  }
  await generation.close(); generation = null; inbox.close(); inbox = openTrainingInbox(inboxPath);
  const afterRestart = await processGpuJob(issue, github, () => { throw new Error('Unexpected restart generation.'); }, inbox);
  const comments = await github('/issues/' + issueNumber + '/comments?per_page=100');
  const publications = comments.filter(comment => comment.body.startsWith(gpuBriefMarker + '\n'));
  const captures = inbox.read(issueNumber).captures;
  if (captures[0]?.input.knowledge.retrieval.effective !== 'deterministic-v1') throw new Error('Canary did not exercise deterministic retrieval.');
  if (requests !== 1 || publications.length !== 1 || captures.length !== 1 || !captures[0].published || afterRestart.status !== 'already posted') {
    throw new Error('Live count verification failed.');
  }
  const result = { issue: issueNumber, model: 'qwen3:14b', generationRequests: requests, tokens,
    totalTokens: tokens.input + tokens.output, captures: captures.length, publications: publications.length,
    publication: publications[0].html_url, guardPassed: captures[0].input.exportPassed, repeatedPolls: 3,
    afterRestart: afterRestart.status, sourceRevision: captures[0].input.commit, retrieval: captures[0].input.knowledge.retrieval,
    productionWorker: 'disabled; no child worker', productionTrainingWrites: 0 };
  writeFileSync(join(root, 'live-result.json'), JSON.stringify(result, null, 2));
  console.log(JSON.stringify(result));
} catch (error) {
  writeFileSync(join(root, 'live-failure.json'), JSON.stringify({ generationRequests: requests, tokens, error: error.message }));
  throw error;
} finally { await generation?.close(); inbox?.close(); db?.close(); gate?.close(); }
