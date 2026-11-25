import { readFileSync, renameSync, writeFileSync } from 'node:fs';
import { randomUUID } from 'node:crypto';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { indexedKnowledge } from '../../game_prompt_studio/lib/index.mjs';
import { openTrainingInbox, trainingPath } from '../training-inbox.mjs';
import { pinnedFunctions } from '../multistage/code-index.mjs';
import { pinLesson } from './lessons.mjs';

const [action, rawIssue, file] = process.argv.slice(2);
const issue = Number(rawIssue);
if (!Number.isSafeInteger(issue) || issue < 1 || !['proposal', 'approve'].includes(action) || (action === 'approve') !== Boolean(file)) {
  throw new Error('Use review-lesson.mjs proposal ISSUE or approve ISSUE REVIEW.json. Keep output on the GPU host.');
}
const home = dirname(trainingPath());
const inbox = openTrainingInbox();
let task;
try { task = inbox.read(issue); } finally { inbox.close(); }
const outcome = task.githubOutcome;
if (!outcome) throw new Error('No automatically collected merged PR outcome exists for this issue.');
const provenance = [{ source: 'merged GitHub PR', url: outcome.url }];
if (action === 'proposal') {
  const capture = task.captures.findLast(item => item.published);
  const changed = new Set(outcome.files.map(item => item.path));
  const anchors = (capture?.input.retrievedContext ?? []).filter(item => changed.has(item.path) && /^[\w]+$/.test(item.title ?? ''))
    .map(({ path, title }) => ({ path, name: title }));
  console.log(JSON.stringify({ issue, pull: outcome.pull, mergeCommit: outcome.merge, provenance, anchors,
    files: outcome.files, checks: outcome.checks, corrections: outcome.corrections, scope: [], failure: '', success: '',
    feedback: '', verification: '', reviewer: '' }, null, 2));
} else {
  const review = JSON.parse(readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  const fields = [review.reviewer, review.failure, review.success, review.feedback, review.verification];
  if (fields.some(value => typeof value !== 'string' || !value.trim() || value.length > 240 || /[\p{Cc}\p{Cf}]/u.test(value)) ||
      !Array.isArray(review.scope) || review.scope.length < 3 || !review.scope.every(value => typeof value === 'string') ||
      !Array.isArray(review.anchors) || !review.anchors.length) throw new Error('Complete the human review and supply current source anchors.');
  const storage = process.env.HOUSEBOAT_KNOWLEDGE_DIR || join(dirname(home), 'HouseboatGpuKnowledge');
  const db = new DatabaseSync(join(storage, 'studio.sqlite'), { readOnly: true });
  let manifest;
  try { manifest = indexedKnowledge(db); } finally { db.close(); }
  const index = pinnedFunctions(join(storage, 'source'), manifest, review.anchors);
  const lesson = pinLesson({ id: `reviewed-issue-${issue}`, report: { number: issue, title: `Reviewed issue #${issue}` },
    implementation: { pull: outcome.pull, revision: manifest.revision, mergeCommit: outcome.merge }, provenance,
    anchors: review.anchors, scope: review.scope, failure: review.failure, success: review.success, feedback: review.feedback,
    verification: review.verification, review: { by: review.reviewer, at: new Date().toISOString() } }, index, manifest.revision);
  const path = join(home, 'reviewed-lessons.json');
  let earlier = [];
  try { earlier = JSON.parse(readFileSync(path, 'utf8')).lessons; }
  catch (error) { if (error.code !== 'ENOENT') throw error; }
  const pending = path + '.' + randomUUID() + '.tmp';
  writeFileSync(pending, JSON.stringify({ lessons: [lesson, ...earlier.filter(item => item.id !== lesson.id)] }), { flag: 'wx' });
  renameSync(pending, path);
  console.log(`Approved lesson for issue #${issue}. Future retrieval rechecks its source fingerprints.`);
}
