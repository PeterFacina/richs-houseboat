import assert from 'node:assert/strict';
import test from 'node:test';
import { mkdtempSync, rmSync } from 'node:fs';
import { join } from 'node:path';
import { tmpdir } from 'node:os';
import { openTrainingInbox } from './training-inbox.mjs';
import { requireGenerationReview } from './worker-generation.mjs';

test('guard hold survives restart and source changes while preserving captures and pending reports', t => {
  const dir = mkdtempSync(join(tmpdir(), 'houseboat-guard-hold-'));
  t.after(() => rmSync(dir, { recursive: true, force: true }));
  const path = join(dir, 'examples.sqlite');
  let inbox = openTrainingInbox(path);
  inbox.capture(123, { report: 'Original report', exportPassed: false, commit: 'old' }, 'Blocked draft');
  inbox.close();
  inbox = openTrainingInbox(path);
  try {
    for (let i = 0; i < 10; i++) assert.throws(() =>
      requireGenerationReview(inbox, 'Original report', { number: 123, commit: 'new' }),
    error => error.code === 'GUARD_REVIEW_REQUIRED');
    assert.equal(inbox.read(123).captures.length, 1);
    assert.equal(inbox.read(123).captures[0].published, null);
    assert.doesNotThrow(() => requireGenerationReview(inbox, 'Explicitly corrected report', { number: 123 }));
    assert.doesNotThrow(() => requireGenerationReview(inbox, 'Original report', { number: 124 }));
  } finally { inbox.close(); }
});
