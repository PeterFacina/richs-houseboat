import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { openDb } from '../../game_prompt_studio/lib/db.mjs';
import { scan } from '../../game_prompt_studio/lib/index.mjs';
import { openTrainingInbox } from '../../discord-issue-pilot/training-inbox.mjs';

export const current = 'a'.repeat(40);
export const older = 'b'.repeat(40);
export const raw = 'PRIVATE_CAPTURE_TEST_SENTINEL';
export const issueUrl = issue => 'https://github.com/PeterFacina/richs-houseboat/issues/' + issue + '#issuecomment-100' + issue;
const at = '2026-01-02T16:00:00.000Z';
const hash = value => createHash('sha256').update(value).digest('hex');

export function fixture() {
  const root = mkdtempSync(join(tmpdir(), 'houseboat-dashboard-'));
  const source = join(root, 'source');
  const files = {};
  const tracked = [];
  const put = (path, content, symbols = []) => {
    const file = join(source, path);
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, content);
    tracked.push(path);
    files[path] = { sha256: hash(content), symbols, references: [] };
  };
  const sourcePath = 'godot-cove/waterfront.gd';
  const body = 'func build_railing() -> void:\n\tpass';
  put('godot-cove/project.godot', 'config/name="Rich\'s Houseboat"\nrun/main_scene="res://title_screen.tscn"\n');
  put('godot-cove/title_screen.tscn', '[gd_scene]\n');
  put(sourcePath, 'extends Node\n\n' + body + '\n', [{ kind: 'func', name: 'build_railing', line: 3 }]);
  put('docs/ARCHITECTURE.md', '# Architecture\n');
  const manifest = { schema: 1, revision: current, files };
  const studio = openDb(root);
  scan(studio, source, [], false, { manifest, tracked });
  studio.close();

  const inbox = join(root, 'examples.sqlite');
  openTrainingInbox(inbox).close();
  const training = new DatabaseSync(inbox);
  const save = training.prepare('INSERT INTO captures VALUES (?,?,?,?,?,?)');
  const record = training.prepare('INSERT INTO reviews VALUES (?,?,?)');
  const citation = { kind: 'source', path: sourcePath, line: 3, excerpt: raw };
  const protectedFields = { report: raw, request: { secret: raw }, modelDigest: raw, issueUrl: raw };
  save.run(11, 'capture-id-11', JSON.stringify({
    ...protectedFields, commit: older, knowledge: { target: older, stale: true }, model: 'qwen3:14b', exportPassed: true,
    retrievedContext: [citation, { kind: 'history', excerpt: raw }], metrics: { promptTokens: 90, outputTokens: 30, durationMs: 2000 },
  }), raw, '2026-01-01T16:00:00.000Z', issueUrl(11));
  save.run(12, 'capture-id-12', JSON.stringify({
    ...protectedFields, commit: current, knowledge: { target: current, stale: false,
      retrieval: { effective: 'deterministic-v1', elapsedMs: 25, briefVersion: 'verification-v1' } },
    model: 'qwen3:14b', contextBytes: 1400, exportPassed: true,
    retrievedContext: [citation, { kind: 'verified-lesson', excerpt: raw }, { kind: 'source', path: '../.worker.env', line: 1 }],
    metrics: { promptTokens: 110, outputTokens: 50, durationMs: 1000 },
  }), raw + '\n\nVERIFIED LESSON FROM A COMPLETED TASK\n' + raw, at, issueUrl(12));
  save.run(13, 'capture-id-13', JSON.stringify({
    ...protectedFields, commit: current, exportPassed: false,
    retrievedContext: [{ kind: 'source', path: raw, line: 1 }],
    metrics: { promptTokens: 0, outputTokens: '800' },
  }), raw, at, null);
  record.run(11, at, JSON.stringify({ status: 'feedback', summary: raw }));
  record.run(12, at, JSON.stringify({ status: 'feedback', summary: raw }));
  for (const [issue, id] of [[12, 'capture-id-12'], [12, 'capture-id-12'], [13, 'capture-id-13']]) {
    record.run(issue, at, JSON.stringify({ status: 'approved', reviewer: raw, captureId: id, target: { summary: raw } }));
  }
  const outcome = { status: 'outcome', reviewer: raw, captureId: 'capture-id-12',
    prUrl: 'https://github.com/PeterFacina/richs-houseboat/pull/30', summary: raw, firstAttempt: 'failed', verification: 'passed' };
  record.run(12, at, JSON.stringify({ ...outcome, humanCorrections: 10, inputTokens: 9999 }));
  record.run(12, at, JSON.stringify({ ...outcome, humanCorrections: 2, inputTokens: 120, cachedInputTokens: 80, outputTokens: 20,
    reasoningTokens: 7, developmentSeconds: 33.5, reviewSeconds: 11 }));
  training.close();
  const lessons = { lessons: [{ id: 'verified-test-lesson', report: { number: 5, title: 'Railing verification' },
    implementation: { pull: 6, revision: older }, provenance: [{ source: 'code review' }],
    failure: 'Checked appearance without collision.', success: 'Verified the existing collision path.',
    feedback: 'Measure spacing and test access.', verification: 'Check collision from both sides.',
    anchors: [{ path: sourcePath, name: 'build_railing', sha256: hash(body) }] }] };

  return { root, inbox, sourcePath, lessons };
}
