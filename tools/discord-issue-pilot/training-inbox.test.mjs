import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { openTrainingInbox } from './training-inbox.mjs';

test('an issue retains its capture, publication link, feedback, and explicit approval across restarts', t => {
  const directory = mkdtempSync(join(tmpdir(), 'houseboat-training-test-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const path = join(directory, 'examples.sqlite');
  const input = { request: { messages: [{ role: 'system', content: 'Write a brief.' }, {
    role: 'user', content: JSON.stringify({ currentRequest: { note: 'The wheel turns slowly.' },
      verifiedProjectFacts: [], untrustedRetrievedEvidence: [] }),
  }] } };
  const first = openTrainingInbox(path);
  try {
    first.capture(42, input, 'Original brief');
    first.capture(42, input, 'Original brief');
    first.link(42, 'Original brief', 'https://github.com/example/issuecomment-1');
  } finally { first.close(); }
  const inbox = openTrainingInbox(path);
  try {
    const { captures, history } = inbox.read(42);
    assert.equal(captures.length, 1);
    assert.deepEqual(captures[0].input, input);
    assert.equal(history.length, 0);
    assert.ok(captures[0].published);
    inbox.addReview(42, { status: 'feedback', summary: 'We compared a short and long turn.' });
    const target = Object.fromEntries(['objective', 'observations', 'tasks', 'verification', 'acceptance', 'unknowns']
      .map(key => [key, ['Check steering.']]));
    const review = { status: 'approved', summary: 'Reviewed', reviewer: 'Peter', captureId: captures[0].id, target };
    assert.throws(() => inbox.addReview(42, { ...review, target: { ...target, tasks: ['Read [S999].'] } }), /Target export rejected/);
    inbox.addReview(42, review);
    assert.deepEqual(inbox.read(42).history.map(row => row.status), ['feedback', 'approved']);
  } finally { inbox.close(); }
});
