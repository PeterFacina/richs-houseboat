import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
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

test('completed outcomes append to the legacy inbox without approving or changing its captures', t => {
  const directory = mkdtempSync(join(tmpdir(), 'houseboat-outcomes-test-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const path = join(directory, 'examples.sqlite');
  const old = new DatabaseSync(path);
  old.exec(`CREATE TABLE captures (issue INTEGER NOT NULL, id TEXT NOT NULL, input TEXT NOT NULL,
    brief TEXT NOT NULL, recorded TEXT NOT NULL, published TEXT, PRIMARY KEY(issue,id));
    CREATE TABLE reviews (issue INTEGER NOT NULL, at TEXT NOT NULL, data TEXT NOT NULL)`);
  const capture = { knowledge: { retrieval: { effective: 'deterministic-v1', briefVersion: 'verification-v1' } } };
  old.prepare('INSERT INTO captures VALUES (?,?,?,?,?,?)').run(42, 'linked', JSON.stringify(capture), 'Private brief', 'then', 'comment');
  old.prepare('INSERT INTO reviews VALUES (?,?,?)').run(42, 'then', JSON.stringify({ status: 'feedback', summary: 'Private feedback' }));
  old.close();
  const inbox = openTrainingInbox(path);
  try {
    const before = inbox.read(42);
    const outcome = { status: 'outcome', reviewer: 'Peter', captureId: 'linked', summary: 'Private review',
      prUrl: 'https://github.com/PeterFacina/richs-houseboat/pull/42', firstAttempt: 'failed', verification: 'passed',
      inputTokens: 120, cachedInputTokens: 85, humanCorrections: 1 };
    assert.throws(() => inbox.addReview(42, { ...outcome, captureId: 'missing' }), /published capture/);
    assert.throws(() => inbox.addReview(42, { ...outcome, cachedInputTokens: 121 }), /Cached input/);
    assert.throws(() => inbox.addReview(42, { ...outcome, firstAttempt: 'passed' }), /without corrections/);
    inbox.addReview(42, outcome);
    inbox.addReview(42, { ...outcome, developmentSeconds: 34.5, retrieval: 'untrusted input' });
    const after = inbox.read(42);
    assert.deepEqual(after.captures, before.captures);
    assert.deepEqual(after.history.map(row => row.status), ['feedback', 'outcome', 'outcome']);
    assert.deepEqual(inbox.outcomes(), [{ issue: 42, retrieval: 'deterministic-v1', briefVersion: 'verification-v1',
      firstAttempt: 'failed', verification: 'passed', developmentSeconds: 34.5, inputTokens: 120, cachedInputTokens: 85,
      humanCorrections: 1 }]);
  } finally { inbox.close(); }
  const rollback = new DatabaseSync(path, { readOnly: true });
  try {
    assert.equal(rollback.prepare('SELECT brief FROM captures WHERE issue=42').get().brief, 'Private brief');
    assert.equal(rollback.prepare("SELECT count(*) AS approved FROM reviews WHERE json_extract(data, '$.status')='approved'").get().approved, 0);
  } finally { rollback.close(); }
});
