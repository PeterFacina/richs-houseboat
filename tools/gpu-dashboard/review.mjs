import { createHash } from 'node:crypto';
import { DatabaseSync } from 'node:sqlite';
import { readFileSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { openTrainingInbox } from '../discord-issue-pilot/training-inbox.mjs';
import { approvedDataset } from '../discord-issue-pilot/learning/training-dataset.mjs';
import { pinLesson } from '../discord-issue-pilot/learning/lessons.mjs';
import { pinnedFunctions } from '../discord-issue-pilot/multistage/code-index.mjs';
import { indexedKnowledge } from '../game_prompt_studio/lib/index.mjs';
import { pageSize, positive, publication, sourcePath } from './contract.mjs';

const categories = ['general', 'playtest', 'retrieval', 'investigation', 'correction', 'acceptance', 'verification'];
const fields = ['objective', 'observations', 'tasks', 'verification', 'acceptance', 'unknowns'];
const validText = (value, max) => typeof value === 'string' && value.trim() && value.length <= max;
const captureId = value => typeof value === 'string' && /^[a-f0-9]{64}$/.test(value);
const actionId = value => typeof value === 'string' && /^[a-f0-9-]{36}$/.test(value);
export const reviewIdentity = value => typeof value === 'string' && /^[\w.+-]{1,100}@[\w.-]{1,120}$/.test(value) ? value.toLowerCase() : null;

function current(task, capture) {
  const rows = task.history.filter(row => row.captureId === capture.id);
  const decision = rows.findLast(row => ['approved', 'rejected'].includes(row.status));
  const outcome = rows.findLast(row => row.status === 'outcome');
  const reasons = [];
  if (!capture.published || capture.input.exportPassed !== true) reasons.push('The capture needs a published, export-checked brief.');
  if (!task.githubOutcome?.merge || !task.githubOutcome?.mergedAt) reasons.push('The linked PR must be merged and collected.');
  if (outcome?.verification !== 'passed' || outcome.prUrl?.split('#')[0] !== task.githubOutcome?.url) {
    reasons.push('Record passed human verification for this capture and merged PR.');
  }
  return { decision, outcome, reasons };
}

function buildLesson(storage, issue, task, body, actor) {
  if (!task.githubOutcome?.merge) throw new Error('A collected merged PR is required.');
  const { failure, success, feedback, verification, scope, anchors } = body;
  if (![failure, success, feedback, verification].every(text => validText(text, 240) && !/[\p{Cc}\p{Cf}]/u.test(text)) ||
      !Array.isArray(scope) || scope.length < 3 || scope.length > 20 || !scope.every(text => validText(text, 80)) ||
      !Array.isArray(anchors) || !anchors.length || anchors.length > 10 ||
      !anchors.every(item => item && sourcePath(item.path) && /^godot-cove\/.*\.gd$/.test(item.path) && /^[\w]{1,128}$/.test(item.name))) {
    throw new Error('Supply the lesson, verification, scope keywords and current Godot function anchors.');
  }
  const db = new DatabaseSync(join(storage, 'studio.sqlite'), { readOnly: true });
  let manifest;
  try { manifest = indexedKnowledge(db); } finally { db.close(); }
  if (!manifest?.revision) throw new Error('The worker source index is unavailable.');
  const index = pinnedFunctions(join(storage, 'source'), manifest, anchors);
  return pinLesson({ id: 'reviewed-issue-' + issue, report: { number: issue, title: 'Reviewed issue #' + issue },
    implementation: { pull: task.githubOutcome.pull, revision: manifest.revision, mergeCommit: task.githubOutcome.merge },
    provenance: [{ source: 'merged GitHub PR', url: task.githubOutcome.url }],
    anchors, scope, failure, success, feedback, verification, review: { by: actor, at: new Date().toISOString() } }, index, manifest.revision);
}

function heldOutIssues(path) {
  try {
    const cases = JSON.parse(readFileSync(path, 'utf8').replace(/^\uFEFF/, ''));
    if (!Array.isArray(cases) || cases.length < 3 || !cases.every(row => positive(row?.issue))) return null;
    const ids = new Set(cases.map(row => row.issue));
    return ids.size === cases.length ? ids : null;
  } catch { return null; }
}

export function createTrainingReview({ inbox: path, storage, holdout = join(dirname(path), 'holdout.json') }) {
  return {
    get({ issue, page }) {
      const inbox = openTrainingInbox(path, { readOnly: true });
      try {
        const heldOut = heldOutIssues(holdout);
        const eligible = new Set(heldOut ? approvedDataset(path, { includeCaptureIds: true })
          .filter(row => !heldOut.has(row.issue)).map(row => row.captureId) : []);
        if (issue) {
          const task = inbox.read(issue);
          const captures = task.captures.filter(row => publication(issue, row.published)).map(({ id, input, brief, published, recorded }) => {
            const state = current(task, { id, input, published });
            const blockers = [...state.reasons];
            if (!heldOut) blockers.push('The independent evaluation set is unavailable.');
            else if (heldOut.has(issue)) blockers.push('This issue is reserved for independent evaluation.');
            const reasons = [...blockers];
            if (state.decision?.status === 'rejected') reasons.push('This capture was rejected by a reviewer.');
            else if (state.decision?.status !== 'approved') reasons.push('Explicit corrected-brief approval is still required.');
            const isEligible = eligible.has(id) && state.decision?.status === 'approved' && !reasons.length;
            if (!isEligible && !reasons.length) reasons.push('The dataset gate excluded this capture or a duplicate report.');
            return { id, brief, published, recorded, report: input.report, revision: input.commit,
              evidence: (input.retrievedContext ?? []).map(({ id, title, path, line, kind, excerpt }) => ({ id, title, path, line, kind, excerpt })), decision: state.decision?.status ?? 'awaiting review',
              outcome: state.outcome, eligible: isEligible, reasons, blockers, target: state.decision?.target };
          });
          return { captures, history: task.history.map(({ actionHash, ...row }) => row), githubOutcome: task.githubOutcome };
        }
        const db = new DatabaseSync(path, { readOnly: true });
        try {
          const rows = db.prepare("SELECT issue,id,published FROM captures ORDER BY rowid DESC").all();
          const reviews = db.prepare("SELECT issue,data FROM reviews ORDER BY rowid").all().map(row => ({ issue: row.issue, ...JSON.parse(row.data) }));
          const latest = new Map();
          for (const row of reviews) if (['approved', 'rejected'].includes(row.status)) latest.set(row.issue + '/' + row.captureId, row.status);
          const published = rows.filter(row => publication(row.issue, row.published));
          const issues = [...new Set(published.map(row => row.issue))];
          return { issues: issues.slice(page * pageSize, (page + 1) * pageSize), more: (page + 1) * pageSize < issues.length,
            counts: { captures: rows.length, outcomes: db.prepare('SELECT count(*) AS n FROM github_outcomes').get().n,
              awaiting: published.filter(row => !latest.has(row.issue + '/' + row.id)).length,
              feedback: reviews.filter(row => row.status === 'feedback').length, reviewed: inbox.outcomes().length,
              approved: published.filter(row => latest.get(row.issue + '/' + row.id) === 'approved').length,
              eligible: eligible.size } };
        } finally { db.close(); }
      } finally { inbox.close(); }
    },
    record(issue, body, actor) {
      if (!positive(issue) || !reviewIdentity(actor) || !body || !captureId(body.captureId) || !actionId(body.actionId) ||
          !validText(body.summary, 4000) || !['feedback', 'outcome', 'approved', 'rejected', 'lesson'].includes(body.status)) {
        throw new Error('Supply a capture, action and review summary.');
      }
      const inbox = openTrainingInbox(path);
      try {
        return inbox.transaction(() => {
          const task = inbox.read(issue);
          const capture = task.captures.find(row => row.id === body.captureId && publication(issue, row.published));
          if (!capture) throw new Error('No matching published capture.');
          const actionHash = createHash('sha256').update(JSON.stringify(body)).digest('hex');
          const prior = task.history.find(row => row.actionId === body.actionId);
          if (prior) {
            if (prior.reviewer !== actor || prior.captureId !== capture.id || prior.status !== body.status || prior.actionHash !== actionHash) throw new Error('Review action ID is already in use.');
            return { recorded: true };
          }
          const review = { status: body.status, summary: body.summary, captureId: capture.id, reviewer: actor,
            actionId: body.actionId, actionHash, prUrl: task.githubOutcome?.url };
          if (body.status === 'feedback') {
            const category = body.category ?? 'general';
            if (!categories.includes(category)) throw new Error('Choose a feedback category.');
            review.category = category;
          }
          if (body.supersedes) {
            if (body.status !== 'feedback' || !task.history.some(row => row.status === 'feedback' &&
                row.actionId === body.supersedes && row.captureId === capture.id) ||
                task.history.some(row => row.supersedes === body.supersedes)) throw new Error('Select the latest feedback entry to correct.');
            review.supersedes = body.supersedes;
          }
          if (body.status === 'outcome') {
            if (!task.githubOutcome?.merge) throw new Error('A collected merged PR is required.');
            Object.assign(review, { firstAttempt: body.firstAttempt, verification: body.verification });
          }
          if (body.status === 'approved') {
            const { reasons } = current(task, capture);
            const heldOut = heldOutIssues(holdout);
            if (!heldOut || heldOut.has(issue)) throw new Error('A configured evaluation set that excludes this issue is required.');
            if (body.confirm !== true || reasons.length) throw new Error(reasons.join(' ') || 'Explicit human confirmation is required.');
            if (!body.target || !fields.some(field => body.target[field]?.length) || !fields.every(field => Array.isArray(body.target[field]) && body.target[field].length <= 24 &&
                body.target[field].every(text => validText(text, 1200)))) throw new Error('Supply the six corrected response fields.');
            review.target = Object.fromEntries(fields.map(field => [field, body.target[field]]));
          }
          if (body.status === 'lesson') {
            if (body.confirm !== true) throw new Error('Explicit human confirmation is required.');
            review.lesson = buildLesson(storage, issue, task, body, actor);
          }
          inbox.addReview(issue, review);
          return { recorded: true };
        });
      } finally { inbox.close(); }
    },
  };
}
