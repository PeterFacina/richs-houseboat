import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { openTrainingInbox } from './training-inbox.mjs';
import { processGpuJob } from './process-gpu-job.mjs';
import { reportHash, jobMarker, findGpuJob, jobMessage } from './generation-jobs.mjs';
import { reportHeader, reportKinds, gpuBriefMarker } from './workflow.mjs';

function fixture(t) {
  const dir = mkdtempSync(join(tmpdir(), 'houseboat-generation-jobs-'));
  let clock = 1000;
  const path = join(dir, 'examples.sqlite');
  let inbox = openTrainingInbox(path, { now: () => clock });
  t.after(() => { inbox.close(); rmSync(dir, { recursive: true, force: true }); });
  const issues = new Map(), comments = new Map();
  let id = 1;
  const github = async (route, method = 'GET', payload) => {
    const update = /^\/issues\/comments\/(\d+)$/.exec(route);
    if (update) {
      const comment = [...comments.values()].flat().find(row => row.id === Number(update[1]));
      Object.assign(comment, payload); return comment;
    }
    const n = Number(/^\/issues\/(\d+)/.exec(route)?.[1]);
    if (!route.includes('/comments')) return issues.get(n);
    if (method === 'POST') {
      const comment = { ...payload, id: id++, author_association: 'OWNER', user: { login: 'PeterFacina', type: 'User' },
        html_url: `https://github.com/PeterFacina/richs-houseboat/issues/${n}#issuecomment-${id}` };
      comments.get(n).push(comment); return comment;
    }
    return comments.get(n);
  };
  return {
    get inbox() { return inbox; }, comments, github,
    advance() { clock += 120_001; },
    restart() { inbox.close(); inbox = openTrainingInbox(path, { now: () => clock }); },
    issue(n) {
      const note = 'Notes-only bounded generation test.';
      const issue = { number: n, state: 'open', html_url: 'https://github.com/PeterFacina/richs-houseboat/issues/' + n,
        body: reportHeader('notes') + note + '\n\nDiscord report: https://discord.com/channels/111/222/333\n\n## Done when\n\n'
          + reportKinds.notes.done + '\n\n<!-- houseboat-gpu-pending:v1 -->\n<!-- discord-pilot:333 -->' };
      issues.set(n, issue); comments.set(n, []); return issue;
    },
  };
}

test('timeouts, malformed JSON and output limits stop after three attempts across restarts; later jobs and dedup work', async t => {
  const f = fixture(t), issue = f.issue(123), next = f.issue(124);
  let attempts = 0;
  const messages = ['Ollama took too long', 'The model did not return valid structured JSON', 'The model reached the output limit'];
  const generate = async () => { throw new Error(messages[attempts++] + ' PRIVATE_SECRET'); };
  for (let n = 0; n < 3; n++) {
    await processGpuJob(issue, f.github, generate, f.inbox);
    f.restart(); f.advance();
  }
  for (let n = 0; n < 10; n++) { await processGpuJob(issue, f.github, generate, f.inbox); f.advance(); }
  assert.equal(attempts, 3);
  const job = f.inbox.jobs.get(123, reportHash('Notes-only bounded generation test.'));
  assert.equal(job.state, 'failed'); assert.equal(job.reason, 'output_limit');
  assert.equal(findGpuJob(f.comments.get(123)).state, 'failed');
  assert.doesNotMatch(JSON.stringify(f.comments.get(123)), /PRIVATE_SECRET/);
  let laterCalls = 0;
  const success = async () => { laterCalls++; return 'Guarded notes-only brief.'; };
  assert.equal((await processGpuJob(next, f.github, success, f.inbox)).status, 'posted');
  f.restart();
  assert.equal((await processGpuJob(next, f.github, success, f.inbox)).status, 'already posted');
  assert.equal(laterCalls, 1);
  assert.equal(f.comments.get(124).filter(row => row.body.startsWith(gpuBriefMarker)).length, 1);
});

test('only named human GitHub operators can grant one replay-proof retry of an unchanged guard-held report', async t => {
  const f = fixture(t), issue = f.issue(123), original = issue.body;
  let calls = 0;
  const blocked = async (_note, _issue, options) => {
    calls++;
    if (calls > 1) assert.equal(options.authorizedRetry, true);
    throw Object.assign(new Error('Private guard details'), { code: 'GUARD_REVIEW_REQUIRED' });
  };
  await processGpuJob(issue, f.github, blocked, f.inbox);
  const job = f.inbox.jobs.get(123, reportHash('Notes-only bounded generation test.'));
  const comment = { id: 55, body: '/gpu-retry ' + job.id, author_association: 'OWNER',
    user: { login: 'PeterFacina', type: 'User' }, html_url: issue.html_url + '#issuecomment-55' };
  for (const candidate of [
    { ...comment, user: { login: 'UnlistedCollaborator', type: 'User' } },
    { ...comment, author_association: 'NONE' }, { ...comment, user: { login: 'PeterFacina', type: 'Bot' } },
  ]) assert.equal(f.inbox.jobs.retry(job, candidate), false);
  f.comments.get(123).push(comment);
  await processGpuJob(issue, f.github, blocked, f.inbox);
  f.restart(); f.advance();
  await processGpuJob(issue, f.github, blocked, f.inbox);
  assert.equal(calls, 2); assert.equal(issue.body, original);
  const after = f.inbox.jobs.get(123, job.reportHash);
  assert.notEqual(after.id, job.id); assert.equal(after.limit, 2); assert.equal(after.state, 'held');
});

test('crash reservations consume the finite budget and cannot reset on restart', t => {
  const f = fixture(t); let job = f.inbox.jobs.ensure(123, 'Same report');
  for (let n = 0; n < 3; n++) {
    assert.ok(f.inbox.jobs.reserve(job)); f.restart(); f.advance();
    job = f.inbox.jobs.ensure(123, 'Same report');
  }
  assert.equal(f.inbox.jobs.reserve(job), null);
  assert.equal(f.inbox.jobs.get(123, job.reportHash).state, 'failed');
  assert.equal(f.inbox.jobs.get(123, job.reportHash).attempts, 3);
});

test('unconfirmed publication reuses a saved guarded capture without a second generation', async t => {
  const f = fixture(t), issue = f.issue(123); let calls = 0, failPost = true;
  const github = async (route, method, body) => {
    if (method === 'POST' && body.body.startsWith(gpuBriefMarker) && failPost) { failPost = false; throw new Error('GitHub timeout'); }
    return f.github(route, method, body);
  };
  const generate = async note => {
    calls++;
    const brief = 'A guarded brief.';
    const captureId = f.inbox.capture(123, { report: note, exportPassed: true, retrievedContext: [],
      request: { messages: [{ role: 'user', content: JSON.stringify({ verifiedProjectFacts: [] }) }] } }, brief);
    return { brief, captureId };
  };
  assert.equal((await processGpuJob(issue, github, generate, f.inbox)).status, 'publication_pending');
  f.restart();
  assert.equal((await processGpuJob(issue, github, generate, f.inbox)).status, 'posted');
  assert.equal(calls, 1); assert.equal(f.inbox.read(123).captures.length, 1);
  assert.ok(f.inbox.read(123).captures[0].published);
});

test('job notifications reject untrusted metadata and expose only fixed actionable reasons', () => {
  const job = { id: 'aaaaaaaa-aaaa-4aaa-8aaa-aaaaaaaaaaaa', state: 'held', attempts: 1, limit: 3, reason: 'guard' };
  assert.match(jobMessage(job), /private findings/);
  assert.doesNotMatch(jobMessage({ ...job, reason: 'secret-token-value' }), /secret-token-value/);
  assert.equal(findGpuJob([{ body: jobMarker + '\n' + JSON.stringify(job), author_association: 'NONE' }]), null);
});

test('a lost status-comment response is reconciled without duplicate comments or a new generation', async t => {
  const f = fixture(t), issue = f.issue(123); let calls = 0, loseResponse = true;
  const github = async (route, method, body) => {
    const result = await f.github(route, method, body);
    if (method === 'POST' && body.body.startsWith(jobMarker) && loseResponse) {
      loseResponse = false; throw new Error('Lost notification response');
    }
    return result;
  };
  const generate = async () => { calls++; throw new Error('Generation timed out'); };
  await processGpuJob(issue, github, generate, f.inbox);
  f.restart();
  await processGpuJob(issue, github, generate, f.inbox);
  assert.equal(calls, 1);
  assert.equal(f.comments.get(123).filter(comment => comment.body.startsWith(jobMarker)).length, 1);
});

test('a successful brief POST with a lost response reconciles the job to published after restart', async t => {
  const f = fixture(t), issue = f.issue(123); let calls = 0, loseResponse = true;
  const github = async (route, method, body) => {
    const result = await f.github(route, method, body);
    if (method === 'POST' && body.body.startsWith(gpuBriefMarker) && loseResponse) {
      loseResponse = false; throw new Error('Lost brief POST response');
    }
    return result;
  };
  const generate = async () => { calls++; return 'Guarded notes-only brief.'; };
  assert.equal((await processGpuJob(issue, github, generate, f.inbox)).status, 'publication_pending');
  f.restart();
  assert.equal((await processGpuJob(issue, github, generate, f.inbox)).status, 'already posted');
  assert.equal(calls, 1);
  assert.equal(f.inbox.jobs.get(123, reportHash('Notes-only bounded generation test.')).state, 'published');
  assert.equal(findGpuJob(f.comments.get(123)).state, 'published');
  assert.equal(f.comments.get(123).filter(comment => comment.body.startsWith(gpuBriefMarker)).length, 1);
});
