import { createHash } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { DatabaseSync } from 'node:sqlite';
import { buildDraft, checkExport } from '../game_prompt_studio/lib/model.mjs';

export const trainingPath = () => join(process.env.LOCALAPPDATA || homedir(),
  'HouseboatPromptTraining', 'examples.sqlite');
const digest = value => createHash('sha256').update(value).digest('hex');
const outcomeMetrics = ['developmentSeconds', 'reviewSeconds', 'correctionSeconds', 'inputTokens',
  'cachedInputTokens', 'outputTokens', 'reasoningTokens', 'incorrectAssumptions', 'unnecessarySourceSteps', 'humanCorrections'];

function completedOutcome(review, capture) {
  if (!capture?.published) throw new Error('Outcome needs the ID of a published capture.');
  if (typeof review.reviewer !== 'string' || !review.reviewer.trim()) throw new Error('Name the outcome reviewer.');
  if (!/^https:\/\/github\.com\/PeterFacina\/richs-houseboat\/pull\/[1-9]\d*(?:#[-\w]+)?$/.test(review.prUrl ?? '')) {
    throw new Error('Link the completed Houseboat PR.');
  }
  const { firstAttempt, verification } = review;
  if (!['passed', 'failed', 'unverified'].includes(firstAttempt) ||
      !['passed', 'failed', 'partial', 'unverified'].includes(verification)) {
    throw new Error('Record firstAttempt and verification with explicit results.');
  }
  const metrics = Object.fromEntries(outcomeMetrics.flatMap(key => {
    const value = review[key];
    if (value == null) return [];
    if (!Number.isFinite(value) || value < 0 || (!key.endsWith('Seconds') && !Number.isSafeInteger(value))) {
      throw new Error('Invalid outcome metric ' + key + '.');
    }
    return [[key, value]];
  }));
  if (metrics.cachedInputTokens > metrics.inputTokens) throw new Error('Cached input cannot exceed total input.');
  if (firstAttempt === 'passed' && (verification !== 'passed' || metrics.humanCorrections > 0)) {
    throw new Error('First-attempt success requires passed verification without corrections.');
  }
  const { status, reviewer, prUrl, summary, captureId } = review;
  return { status, reviewer, prUrl, summary, captureId, firstAttempt, verification, ...metrics,
    retrieval: capture.input.knowledge?.retrieval?.effective ?? 'unrecorded',
    briefVersion: capture.input.knowledge?.retrieval?.briefVersion ?? 'unrecorded',
  };
}

export function openTrainingInbox(path = trainingPath(), { readOnly = false } = {}) {
  if (!readOnly) mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path, { readOnly });
  if (!readOnly) db.exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;');
  if (!readOnly) db.exec('CREATE TABLE IF NOT EXISTS captures (issue INTEGER NOT NULL, id TEXT NOT NULL,'
    + ' input TEXT NOT NULL, brief TEXT NOT NULL, recorded TEXT NOT NULL, published TEXT, PRIMARY KEY(issue,id));'
    + ' CREATE TABLE IF NOT EXISTS reviews (issue INTEGER NOT NULL, at TEXT NOT NULL, data TEXT NOT NULL);'
    + ' CREATE TABLE IF NOT EXISTS github_outcomes (issue INTEGER PRIMARY KEY, data TEXT NOT NULL);');
  return {
    capture(issue, input, brief) {
      const serialized = JSON.stringify(input);
      const id = digest(serialized + '\n' + brief);
      db.prepare('INSERT OR IGNORE INTO captures (issue,id,input,brief,recorded) VALUES (?,?,?,?,?)')
        .run(issue, id, serialized, brief, new Date().toISOString());
      return id;
    },
    link(issue, brief, url, id = null) {
      db.prepare(`UPDATE captures SET published=? WHERE issue=? AND id=(
        SELECT id FROM captures WHERE issue=? AND brief=? AND (? IS NULL OR id=?)
        AND COALESCE(json_extract(input, '$.exportPassed'), 1)=1
        ORDER BY published DESC, rowid DESC LIMIT 1) AND published IS NULL`)
        .run(url, issue, issue, brief, id, id);
    },
    read(issue) {
      return {
        issue,
        captures: db.prepare('SELECT id,input,brief,recorded,published FROM captures WHERE issue=? ORDER BY rowid')
          .all(issue).map(row => ({ ...row, input: JSON.parse(row.input) })),
        history: db.prepare('SELECT at,data FROM reviews WHERE issue=? ORDER BY rowid').all(issue)
          .map(row => ({ at: row.at, ...JSON.parse(row.data) })),
        githubOutcome: JSON.parse(db.prepare('SELECT data FROM github_outcomes WHERE issue=?').get(issue)?.data ?? 'null'),
      };
    },
    publishedIssues() {
      return db.prepare('SELECT DISTINCT issue FROM captures WHERE published IS NOT NULL ORDER BY issue').all().map(row => row.issue);
    },
    githubOutcomes() {
      return db.prepare('SELECT issue, data FROM github_outcomes').all().map(row => ({ ...JSON.parse(row.data), issue: row.issue }));
    },
    saveGitHubOutcome(issue, data) {
      db.prepare('INSERT INTO github_outcomes VALUES (?,?) ON CONFLICT(issue) DO UPDATE SET data=excluded.data')
        .run(issue, JSON.stringify(data));
    },
    transaction(write) {
      db.exec('BEGIN IMMEDIATE');
      try { const result = write(); db.exec('COMMIT'); return result; }
      catch (error) { db.exec('ROLLBACK'); throw error; }
    },
    addReview(issue, review) {
      const record = this.read(issue);
      if (!record.captures.length) throw new Error('No original model input captured for this issue.');
      if (typeof review.summary !== 'string' || !review.summary.trim()) throw new Error('Add a short review summary.');
      if (review.status === 'outcome') {
        review = { ...completedOutcome(review, record.captures.find(row => row.id === review.captureId)),
          ...(review.actionId && { actionId: review.actionId, actionHash: review.actionHash, supersedes: review.supersedes }) };
      }
      if (['lesson', 'rejected'].includes(review.status) &&
          (!record.captures.some(row => row.id === review.captureId && row.published) ||
           typeof review.reviewer !== 'string' || !review.reviewer.trim())) {
        throw new Error('A published capture and named reviewer are required.');
      }
      if (review.status === 'lesson' && (!review.lesson?.anchors?.length || review.lesson.review?.by !== review.reviewer)) {
        throw new Error('A verified source lesson and reviewer are required.');
      }
      if (review.status === 'approved') {
        const capture = record.captures.find(row => row.id === review.captureId && row.published);
        if (!capture) throw new Error('Approval needs the ID of a published capture.');
        if (typeof review.reviewer !== 'string' || !review.reviewer.trim()) throw new Error('Name the reviewer.');
        const original = JSON.parse(capture.input.request.messages.find(message => message.role === 'user').content);
        const evidence = capture.input.exportEvidence ?? original.untrustedRetrievedEvidence;
        const brief = buildDraft(review.target, 'Reviewed brief', original.verifiedProjectFacts,
          evidence, original.currentRequest.note);
        const findings = checkExport(brief, evidence, original.verifiedProjectFacts);
        if (findings.length) throw new Error('Target export rejected: ' + findings.join(', '));
      } else if (!['feedback', 'outcome', 'rejected', 'lesson'].includes(review.status)) {
        throw new Error('Unknown review action.');
      }
      db.prepare('INSERT INTO reviews VALUES (?,?,?)').run(issue, new Date().toISOString(), JSON.stringify(review));
    },
    outcomes() {
      const rows = db.prepare(`SELECT issue, data FROM reviews WHERE rowid IN (
        SELECT MAX(rowid) FROM reviews WHERE json_extract(data, '$.status')='outcome' GROUP BY issue
      ) ORDER BY issue`).all();
      return rows.map(({ issue, data }) => {
        const review = JSON.parse(data);
        const { retrieval, briefVersion, firstAttempt, verification } = review;
        return { issue, retrieval, briefVersion, firstAttempt, verification,
          ...Object.fromEntries(outcomeMetrics.filter(key => review[key] != null).map(key => [key, review[key]])) };
      });
    },
    close() { db.close(); },
  };
}
