import assert from 'node:assert/strict';
import { existsSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { request } from 'node:http';
import { once } from 'node:events';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { test } from 'node:test';
import { createAdapter } from '../adapter.mjs';
import { createGitHubIssues } from '../github-issues.mjs';
import { randomUUID } from 'node:crypto';
import { createTrainingReview } from '../review.mjs';
import { openTrainingInbox } from '../../discord-issue-pilot/training-inbox.mjs';
import { createReader } from '../reader.mjs';
import { createDashboard } from '../server.mjs';
import { gpuBriefMarker } from '../../discord-issue-pilot/workflow.mjs';
import { current, older, raw, fixture, issueUrl } from './fixture.mjs';

const token = 'b'.repeat(64);
const origin = 'https://houseboat.example.ts.net';
const host = new URL(origin).host;
const users = { 'viewer@example.invalid': 'viewer', 'reviewer@example.invalid': 'reviewer' };
const reviewer = { 'Tailscale-User-Login': 'reviewer@example.invalid' };
const viewer = { 'Tailscale-User-Login': 'viewer@example.invalid' };

async function listening(server, t) {
  const ready = once(server, 'listening');
  server.listen(0, '127.0.0.1');
  await ready;
  t.after(() => new Promise(resolve => { server.close(resolve); server.closeAllConnections(); }));
  return server.address().port;
}

function get(port, path, headers = {}, method = 'GET', data) {
  return new Promise((resolve, reject) => {
    const req = request({ hostname: '127.0.0.1', port, path, method, headers: { Host: host, ...headers } }, res => {
      let body = '';
      res.setEncoding('utf8');
      res.on('data', chunk => { body += chunk; });
      res.on('end', () => resolve({ status: res.statusCode, headers: res.headers, body }));
    });
    req.on('error', reject);
    req.end(data);
  });
}

test('dashboard projects published evidence and recorded-only metrics without changing either SQLite store', async t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  const before = [readFileSync(f.inbox), readFileSync(join(f.root, 'studio.sqlite'))];
  const reader = createReader({ storage: f.root, inbox: f.inbox, lessons: f.lessons });
  const adapter = await listening(createAdapter({ token, reader }), t);
  const dashboard = await listening(createDashboard({ origin, users, adapterPort: adapter, token }), t);
  const call = async (path, identity = reviewer) => {
    const result = await get(dashboard, '/api' + path, identity);
    assert.equal(result.status, 200, result.body);
    assert.equal(result.headers['cache-control'], 'no-store');
    for (const secret of [raw, 'capture-id-', token, '../.worker.env']) assert.ok(!result.body.includes(secret));
    return JSON.parse(result.body);
  };

  const overview = await call('/overview');
  assert.equal(overview.role, 'reviewer');
  assert.equal(overview.knowledge.revision, current);
  assert.equal(overview.knowledge.files, 4);
  assert.equal(overview.knowledge.functions, 1);
  assert.ok(overview.knowledge.facts.some(item => item.fact.includes('res://title_screen.tscn')));
  assert.equal(overview.worker, null);
  assert.deepEqual(overview.briefs.published, { briefs: 2, issues: 2 });
  assert.equal(overview.briefs.collected, 3);
  assert.deepEqual(overview.briefs.metrics.inputTokens, { total: 200, recorded: 3 });
  assert.deepEqual(overview.briefs.metrics.outputTokens, { total: 80, recorded: 2 });
  assert.deepEqual(overview.briefs.modes.map(({ mode, blocked }) => [mode, blocked]), [['deterministic-v1', 0], ['unrecorded', 1]]);
  assert.deepEqual(overview.briefs.metrics.retrievalMs, { total: 25, recorded: 1 });
  assert.equal(overview.learning.feedback, 2);
  assert.equal(overview.learning.approved, 1);
  assert.equal(overview.learning.completed, 1);
  assert.equal(overview.learning.lessonsUsed, 1);
  assert.deepEqual(overview.learning.metrics.humanCorrections, { total: 2, recorded: 1 });
  assert.deepEqual(overview.learning.metrics.correctionSeconds, { total: null, recorded: 0 });
  assert.deepEqual(overview.learning.metrics.inputTokens, { total: 120, recorded: 1 });
  assert.deepEqual(overview.learning.metrics.reasoningTokens, { total: 7, recorded: 1 });

  const browse = await call('/knowledge?kind=functions&q=waterfront+railing', viewer);
  assert.deepEqual(browse.rows, [{ path: f.sourcePath, name: 'build_railing', line: 3 }]);
  assert.deepEqual((await call('/briefs', viewer)).briefs.map(item => item.issue), [12, 11]);
  const legacy = (await call('/retrieval?issue=11', viewer)).result;
  assert.equal(legacy.revision, older);
  assert.equal(legacy.mode, 'unrecorded');
  assert.equal(legacy.url, issueUrl(11));
  assert.equal(legacy.lessonRendered, false);
  assert.equal(legacy.stale, true);
  assert.equal('metrics' in legacy, false);
  assert.equal('review' in legacy, false);
  const modern = (await call('/retrieval?issue=12')).result;
  assert.equal(modern.sources.length, 1);
  assert.equal(modern.metrics.inputTokens, 110);
  assert.equal(modern.lessonRendered, true);
  assert.deepEqual(modern.review, { approved: true, feedback: 1 });
  assert.equal((await get(dashboard, '/api/retrieval?issue=13', reviewer)).status, 404);

  const { catalogue, development } = await call('/learning');
  assert.equal(catalogue.items[0].state, 'verified');
  assert.equal(development.outcomes[0].corrections, 2);
  assert.equal(development.outcomes[0].mode, 'deterministic-v1');
  assert.deepEqual([readFileSync(f.inbox), readFileSync(join(f.root, 'studio.sqlite'))], before);
  writeFileSync(join(f.root, 'source', f.sourcePath), 'func changed():\n\tpass\n');
  assert.equal((await call('/learning')).catalogue.items[0].state, 'revalidation-needed');
});

test('the HTTP boundary denies writes, unlisted identities, forged roles and adapter bypass', async t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  const adapter = await listening(createAdapter({ token, reader: createReader({ storage: f.root, inbox: f.inbox }) }), t);
  const dashboard = await listening(createDashboard({ origin, users, adapterPort: adapter, token }), t);

  assert.equal((await get(dashboard, '/')).status, 403);
  assert.equal((await get(dashboard, '/api/overview', { 'Tailscale-User-Login': 'unknown@example.invalid' })).status, 403);
  assert.equal((await get(dashboard, '/api/overview', { ...reviewer, Host: 'different.example.ts.net' })).status, 403);
  assert.equal((await get(dashboard, '/api/overview', reviewer, 'POST')).status, 405);
  assert.equal((await get(dashboard, '/api/generate', reviewer)).status, 404);
  assert.equal((await get(dashboard, '/api/knowledge?q=x&q=y', viewer)).status, 404);
  assert.equal((await get(dashboard, '/api/retrieval?issue=12&raw=true', reviewer)).status, 404);
  const forged = { ...viewer, 'X-Dashboard-Role': 'reviewer' };
  assert.equal((await get(dashboard, '/api/learning', forged)).status, 403);
  const viewerData = JSON.parse((await get(dashboard, '/api/overview', forged)).body);
  assert.equal(viewerData.role, 'viewer');
  assert.deepEqual(viewerData.briefs, { published: { briefs: 2, issues: 2 } });
  assert.equal('learning' in viewerData, false);
  assert.equal((await get(adapter, '/v1/overview', { ...reviewer, 'X-Dashboard-Role': 'reviewer' })).status, 403);
  assert.equal((await get(adapter, '/v1/learning', { 'X-Dashboard-Role': 'viewer', Authorization: 'Bearer ' + token })).status, 403);
  assert.equal((await get(adapter, '/v1/briefs', { 'X-Dashboard-Role': 'reviewer', Authorization: 'Bearer ' + token }, 'PUT')).status, 405);
  const asset = await get(dashboard, '/', reviewer);
  assert.equal(asset.status, 200);
  assert.match(asset.headers['content-security-policy'], /default-src 'none'/);
  assert.match(asset.body, /GPU Dashboard/);
});

test('a dedicated Tailscale HTTPS port still requires the exact host and a named viewer', async t => {
  const origin = 'https://houseboat.example.ts.net:8443';
  const dashboard = await listening(createDashboard({ origin, users }), t);
  const Host = new URL(origin).host;

  assert.equal((await get(dashboard, '/', { ...viewer, Host })).status, 200);
  assert.equal((await get(dashboard, '/', viewer)).status, 403);
  assert.equal((await get(dashboard, '/', { ...viewer, Host: 'houseboat.example.ts.net:8444' })).status, 403);
  assert.equal((await get(dashboard, '/', { Host })).status, 403);
});

test('reviewers can distinguish GitHub-only briefs and captured evidence without exposing private fields', async t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  const remote = 'https://api.github.com/repos/PeterFacina/richs-houseboat/issues/';
  const comment = issue => ({ body: gpuBriefMarker + '\n' + raw, author_association: 'COLLABORATOR',
    issue_url: remote + issue, html_url: issueUrl(issue) });
  let now = Date.parse('2026-01-02T16:00:00.000Z');
  let unavailable = false;
  let reads = 0;
  const githubIssues = createGitHubIssues({ now: () => now, open: async () => async path => {
    reads += 1;
    if (unavailable) throw new Error(raw);
    if (path.startsWith('/issues/comments')) return [comment(12), comment(16), { ...comment(13), author_association: 'NONE' }];
    if (path.startsWith('/pulls?')) return [{ number: 30, body: 'Fixes #12', state: 'closed',
      base: { ref: 'main' }, merged_at: '2026-01-02T15:00:00Z' }];
    return [{ number: 12, state: 'closed', title: 'Captured', body: raw },
      { number: 16, state: 'open', title: 'GitHub only', body: raw, assignees: [{}] },
      { number: 13, state: 'open', title: 'Awaiting review', body: raw },
      { number: 23, state: 'open', pull_request: {}, body: raw }];
  } });
  const reader = createReader({ storage: f.root, inbox: f.inbox, lessons: f.lessons, githubIssues });
  const adapter = await listening(createAdapter({ token, reader }), t);
  const dashboard = await listening(createDashboard({ origin, users, adapterPort: adapter, token }), t);
  assert.equal((await get(dashboard, '/api/issues', viewer)).status, 403);
  assert.equal((await get(adapter, '/v1/issues', { Authorization: 'Bearer ' + token, 'X-Dashboard-Role': 'viewer' })).status, 403);
  assert.equal(reads, 0);
  const response = await get(dashboard, '/api/issues', reviewer);
  assert.equal(response.status, 200);
  assert.ok(!response.body.includes(raw));
  const { rows, total, open, stale } = JSON.parse(response.body);
  assert.equal(total, 3);
  assert.equal(open, 2);
  assert.equal(stale, false);
  assert.deepEqual(rows.map(row => [row.issue, row.brief, row.localCapture]),
    [[16, issueUrl(16), false], [13, null, null], [12, issueUrl(12), true]]);
  assert.equal(rows[2].pull.state, 'merged');
  assert.equal(rows[2].outcome.verification, 'passed');
  assert.equal(JSON.parse((await get(dashboard, '/api/issues?page=1', reviewer)).body).rows.length, 0);
  assert.equal(reads, 3);
  unavailable = true;
  now += 121_000;
  assert.equal(JSON.parse((await get(dashboard, '/api/issues', reviewer)).body).stale, true);
});

test('reviewers see the training gate from a Python status record with microseconds', t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  writeFileSync(join(f.root, 'training-status.json'), JSON.stringify({ schema: 1, phase: 'waiting-for-approved-examples',
    observedAt: '2026-01-02T16:00:00.123456Z', examples: 0, required: 24, privatePath: raw }));
  const reader = createReader({ storage: f.root, inbox: f.inbox, lessons: f.lessons });
  const result = reader.overview('reviewer').training;
  assert.equal(result.observedAt, '2026-01-02T16:00:00.123Z');
  assert.equal(result.examples, 0);
  assert.equal(result.required, 24);
  assert.ok(!JSON.stringify(result).includes(raw));
  assert.equal(reader.overview('viewer').training, undefined);
});

test('an unavailable inbox is never created and heartbeat state expires independently of the index', t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  const missing = join(f.root, 'missing.sqlite');
  const observedAt = '2026-01-02T16:00:00.000Z';
  let now = Date.parse(observedAt);
  writeFileSync(join(f.root, 'worker-status.json'), JSON.stringify({
    schema: 1, phase: 'watching', observedAt, release: current, model: 'qwen3:14b', configuredMode: 'original', canary: false,
    knowledge: { indexedRevision: current, target: current, stale: false, observedAt }, environment: raw,
  }));
  const reader = createReader({ storage: f.root, inbox: missing, now: () => now });
  assert.equal(reader.overview('reviewer').worker.phase, 'watching');
  assert.equal(reader.overview('reviewer').briefs, null);
  assert.equal(reader.overview('viewer').knowledgeCheck.via, 'heartbeat');
  assert.ok(!JSON.stringify(reader.overview('reviewer')).includes(raw));
  assert.equal(reader.briefs(0), null);
  assert.equal(existsSync(missing), false);
  now += 121_000;
  assert.equal(reader.overview('reviewer').worker.phase, 'heartbeat-stale');
  assert.equal(reader.overview('reviewer').knowledge.revision, current);
});

test('a concurrent worker-style WAL write exposes only committed capture totals', t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  const writer = new DatabaseSync(f.inbox);
  const insert = writer.prepare('INSERT INTO captures VALUES (?,?,?,?,?,?)');
  const reader = () => createReader({ storage: f.root, inbox: f.inbox });
  try {
    writer.exec('BEGIN IMMEDIATE');
    insert.run(14, 'test-in-flight', '{}', raw, '2026-01-03T02:00:00.000Z', null);
    assert.equal(reader().overview('reviewer').briefs.collected, 3);
    writer.exec('COMMIT');
    assert.equal(reader().overview('reviewer').briefs.collected, 4);
    assert.deepEqual(reader().briefs(0).briefs.map(row => row.issue), [12, 11]);
  } finally { writer.close(); }
});

test('remote review rejects viewer, unlisted writer and cross-origin writes and persists audited decisions', async t => {
  const f = fixture();
  t.after(() => rmSync(f.root, { recursive: true, force: true }));
  const inbox = openTrainingInbox(f.inbox);
  const issue = 30;
  const report = 'Synthetic review report';
  const messages = [{ role: 'system', content: 'Build a brief.' }, { role: 'user',
    content: JSON.stringify({ currentRequest: { note: report }, verifiedProjectFacts: [], untrustedRetrievedEvidence: [] }) }];
  const id = inbox.capture(issue, { report, exportPassed: true, request: { messages } }, 'Synthetic brief');
  inbox.link(issue, 'Synthetic brief', issueUrl(issue));
  inbox.saveGitHubOutcome(issue, { pull: 31, url: 'https://github.com/PeterFacina/richs-houseboat/pull/31',
    merge: current, mergedAt: '2026-01-01T12:00:00Z' });
  inbox.close();
  writeFileSync(join(f.root, 'holdout.json'), JSON.stringify([{ issue: 6 }, { issue: 7 }, { issue: 8 }]));
  const realReviewer = process.env.HOUSEBOAT_TEST_REVIEWER || reviewer['Tailscale-User-Login'];
  const allowed = { ...users, [realReviewer]: 'reviewer', 'other@example.invalid': 'reviewer' };
  const adapter = await listening(createAdapter({ token, reader: createReader({ storage: f.root, inbox: f.inbox }),
    review: createTrainingReview({ storage: f.root, inbox: f.inbox }) }), t);
  const port = await listening(createDashboard({ origin, users: allowed, token, adapterPort: adapter,
    remoteReview: true, reviewWriters: [realReviewer] }), t);
  const route = '/api/review?issue=' + issue;
  const authenticated = { 'Tailscale-User-Login': realReviewer };
  const target = Object.fromEntries(['objective', 'observations', 'tasks', 'verification', 'acceptance', 'unknowns']
    .map(field => [field, ['Check the control.']]));
  const send = (payload, headers = authenticated, source = origin) => {
    const data = JSON.stringify({ captureId: id, actionId: randomUUID(), summary: 'Documented review', ...payload });
    return get(port, route, { ...headers, Origin: source, 'Content-Type': 'application/json',
      'Content-Length': Buffer.byteLength(data), 'X-Review-Actor': 'forged@example.invalid' }, 'POST', data);
  };
  assert.equal((await get(port, route, viewer)).status, 403);
  assert.equal((await get(port, route, authenticated)).status, 200);
  assert.equal((await get(adapter, '/v1/review?issue=' + issue, authenticated)).status, 403);
  assert.equal((await send({ status: 'feedback' }, viewer)).status, 403);
  assert.equal((await send({ status: 'feedback' }, { 'Tailscale-User-Login': 'other@example.invalid' })).status, 403);
  assert.equal((await send({ status: 'feedback' }, authenticated, 'https://unrelated.example')).status, 403);
  const actionId = randomUUID();
  assert.equal((await send({ status: 'feedback', actionId })).status, 200);
  assert.equal((await send({ status: 'feedback', actionId })).status, 200);
  assert.equal((await send({ status: 'feedback', supersedes: actionId })).status, 200);
  assert.equal((await send({ status: 'outcome', firstAttempt: 'failed', verification: 'partial' })).status, 200);
  assert.equal((await send({ status: 'approved', target, confirm: true })).status, 400);
  assert.equal((await send({ status: 'outcome', firstAttempt: 'failed', verification: 'passed' })).status, 200);
  assert.equal((await send({ status: 'approved', target })).status, 400);
  assert.equal((await send({ status: 'approved', confirm: true, target: { ...target, tasks: ['Inspect [S999].'] } })).status, 400);
  assert.equal((await send({ status: 'approved', target, confirm: true })).status, 200);
  assert.equal((await send({ status: 'lesson', confirm: true, failure: 'Wrong source', success: 'Use the railing function',
    feedback: 'Verify the source first', verification: 'Read the function', scope: ['railing', 'fence', 'waterfront'],
    anchors: [{ path: f.sourcePath, name: 'build_railing' }] })).status, 200);
  let detail = JSON.parse((await get(port, route, authenticated)).body);
  assert.equal(detail.captures[0].eligible, true);
  assert.equal(detail.history.filter(row => row.status === 'feedback').length, 2);
  assert.equal(detail.history.at(-1).lesson.review.by, realReviewer);
  assert.ok(detail.history.every(row => row.reviewer === realReviewer));
  assert.equal((await send({ status: 'rejected' })).status, 200);
  detail = JSON.parse((await get(port, route, authenticated)).body);
  assert.equal(detail.captures[0].eligible, false);
  assert.equal(detail.captures[0].decision, 'rejected');
  assert.equal(detail.history.filter(row => row.status === 'approved').length, 1);
});
