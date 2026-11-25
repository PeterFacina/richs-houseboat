import assert from 'node:assert/strict';
import { mkdtempSync, readFileSync, readdirSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { test } from 'node:test';
import { workerStatus } from './worker-status.mjs';

test('optional dashboard heartbeat keeps only safe runtime fields and commits the latest status', async t => {
  const path = mkdtempSync(join(tmpdir(), 'houseboat-heartbeat-'));
  t.after(() => rmSync(path, { recursive: true, force: true }));
  const release = 'a'.repeat(40);
  const commit = 'b'.repeat(40);
  const status = workerStatus(path, { model: 'qwen3:14b', retrieval: { mode: 'deterministic-v1', issue: 97 }, release,
    token: 'sensitive' });
  status.phase('watching');
  status.knowledge({ commit, target: commit, stale: false, step: 'sensitive' });
  status.phase('generating');
  await status.close();
  const raw = readFileSync(join(path, 'worker-status.json'), 'utf8');
  const value = JSON.parse(raw);
  assert.deepEqual(readdirSync(path), ['worker-status.json']);
  assert.equal(value.schema, 1);
  assert.equal(value.release, release);
  assert.equal(value.configuredMode, 'deterministic-v1');
  assert.equal(value.phase, 'stopped');
  assert.equal(value.canary, true);
  assert.equal(value.knowledge.indexedRevision, commit);
  assert.ok(!raw.includes('sensitive'));
  assert.ok(!raw.includes('"issue"'));
});

test('a missing heartbeat directory is reported without breaking the caller', async t => {
  const path = mkdtempSync(join(tmpdir(), 'houseboat-heartbeat-fail-'));
  t.after(() => rmSync(path, { recursive: true, force: true }));
  const warnings = [];
  const status = workerStatus(join(path, 'missing'), { model: 'qwen3:14b', retrieval: { mode: 'original' },
    release: null, log: { warn: message => warnings.push(message) } });
  status.phase('watching');
  await status.close();
  assert.deepEqual(warnings, ['Could not publish the dashboard heartbeat.']);
});
