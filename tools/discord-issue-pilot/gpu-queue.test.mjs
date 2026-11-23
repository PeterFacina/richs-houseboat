import assert from 'node:assert/strict';
import test from 'node:test';
import { processGpuIssue, queuedReport } from './gpu-queue.mjs';
import { gpuBriefMarker, reportHeader, reportKinds } from './workflow.mjs';

const note = 'Add one sentence to the team notes.';
const issue = { number: 32, state: 'open', body: [
  '## Goal', '', 'Run a notes-only workflow pilot.', '', '## Original report', '', note, '',
  'Discord report: https://discord.com/channels/111/222/333', '', '## Done when', '',
  'The requested notes change is in a linked draft PR, ready for human review.', '',
  '<!-- houseboat-gpu-pending:v1 -->', '<!-- discord-pilot:333 -->',
].join('\n') };

test('the worker extracts only a valid queued Discord report', () => {
  assert.equal(queuedReport(issue), note);
  assert.equal(queuedReport({ ...issue, state: 'closed' }), null);
  assert.equal(queuedReport({ ...issue, pull_request: {} }), null);
  assert.equal(queuedReport({ ...issue, body: issue.body.replace('discord-pilot:333', 'discord-pilot:444') }), null);
  assert.equal(queuedReport({ ...issue, body: issue.body.replaceAll('\n', '\r\n') }), note);
  const gameplay = issue.body.replace(reportHeader('notes'), reportHeader('gameplay'))
    .replace(reportKinds.notes.done, reportKinds.gameplay.done);
  assert.equal(queuedReport({ ...issue, body: gameplay }), note);
  assert.equal(queuedReport({ ...issue, body: gameplay.replace(reportKinds.gameplay.done, reportKinds.notes.done) }), null);
});

test('the worker publishes one guarded brief and skips it on retry', async () => {
  const comments = [];
  let generations = 0;
  const github = async (route, method, payload) => {
    if (route === '/issues/32') return issue;
    assert.match(route, /^\/issues\/32\/comments/);
    if (method === 'POST') {
      assert.equal(payload.body, gpuBriefMarker + '\n\nChecked brief.');
      const comment = { ...payload, author_association: 'COLLABORATOR', html_url: 'https://github.example/brief' };
      comments.push(comment);
      return comment;
    }
    return comments;
  };
  const generate = async value => {
    assert.equal(value, note);
    generations++;
    return 'Checked brief.';
  };
  assert.equal((await processGpuIssue(issue, github, generate)).status, 'posted');
  assert.equal((await processGpuIssue(issue, github, generate)).status, 'already posted');
  assert.equal(generations, 1);
  assert.equal(comments.length, 1);
});

test('an edited report or failed export does not publish a brief', async () => {
  const github = async (route, method) => {
    assert.notEqual(method, 'POST');
    return route === '/issues/32' ? { ...issue, body: issue.body.replace(note, 'Revised report.') } : [];
  };
  assert.equal((await processGpuIssue(issue, github, async () => 'Checked brief.')).status,
    'issue changed during generation');
  await assert.rejects(processGpuIssue(issue, github, async () => { throw new Error('Export blocked'); }), /Export blocked/);
});
