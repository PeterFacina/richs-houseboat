import { createHash } from 'node:crypto';
import { resolve } from 'node:path';
import { pathToFileURL } from 'node:url';
import { DatabaseSync } from 'node:sqlite';
import { buildDraft, checkExport } from '../../game_prompt_studio/lib/model.mjs';
import { trainingPath } from '../training-inbox.mjs';
import { repository } from '../workflow.mjs';

export function approvedDataset(path = trainingPath(), { includeCaptureIds = false } = {}) {
  const db = new DatabaseSync(path, { readOnly: true });
  try {
    db.exec('PRAGMA query_only=ON; PRAGMA busy_timeout=500; BEGIN');
    const table = db.prepare("SELECT 1 FROM sqlite_schema WHERE type='table' AND name='github_outcomes'").get();
    const rows = db.prepare(`SELECT r.issue, r.data, c.input, c.published FROM reviews r JOIN captures c
      ON c.issue=r.issue AND c.id=json_extract(CASE WHEN json_valid(r.data) THEN r.data ELSE '{}' END, '$.captureId')
      WHERE json_extract(CASE WHEN json_valid(r.data) THEN r.data ELSE '{}' END, '$.status') IN ('approved','rejected','outcome')
      AND c.published IS NOT NULL ORDER BY r.rowid DESC`).all();
    const merged = new Map(table ? db.prepare('SELECT issue,data FROM github_outcomes').all()
      .map(row => [row.issue, JSON.parse(row.data)]) : []);
    const key = (row, review) => `${row.issue}/${review.captureId}`;
    const outcomes = new Map();
    for (const row of rows) {
      const review = JSON.parse(row.data);
      if (review.status === 'outcome' && !outcomes.has(key(row, review))) outcomes.set(key(row, review), review);
    }
    const decisions = new Set();
    const issues = new Set();
    const reports = new Set();
    const examples = [];
    for (const row of rows) {
      const review = JSON.parse(row.data);
      if (review.status === 'outcome' || decisions.has(key(row, review))) continue;
      decisions.add(key(row, review));
      if (review.status !== 'approved' || !review.reviewer?.trim() || issues.has(row.issue)) continue;
      const outcome = outcomes.get(key(row, review));
      const pull = merged.get(row.issue);
      if (!pull?.mergedAt || !pull.merge || outcome?.verification !== 'passed' ||
          outcome.prUrl?.split('#')[0] !== `https://github.com/${repository}/pull/${pull.pull}`) continue;
      try {
        const capture = JSON.parse(row.input);
        const messages = capture.request.messages;
        if (capture.exportPassed !== true || messages.length !== 2 || messages[0].role !== 'system' || messages[1].role !== 'user') continue;
        const input = JSON.parse(messages[1].content);
        const note = input.currentRequest.note.trim();
        if (note !== capture.report.trim()) continue;
        const fingerprint = createHash('sha256').update(note.normalize('NFKC').toLowerCase().replace(/\s+/g, ' ')).digest('hex');
        if (reports.has(fingerprint)) continue;
        const evidence = capture.exportEvidence ?? input.untrustedRetrievedEvidence;
        const text = buildDraft(review.target, 'Reviewed brief', input.verifiedProjectFacts, evidence, note);
        if (checkExport(text, evidence, input.verifiedProjectFacts).length) continue;
        const target = Object.fromEntries(['objective', 'observations', 'tasks', 'verification', 'acceptance', 'unknowns']
          .map(field => [field, review.target[field]]));
        issues.add(row.issue);
        reports.add(fingerprint);
        examples.push({ issue: row.issue, ...(includeCaptureIds && { captureId: review.captureId }), messages: [...messages.map(({ role, content }) => ({ role, content })),
          { role: 'assistant', content: JSON.stringify(target) }] });
      } catch { /* An old or incomplete approval does not become training data. */ }
    }
    return examples.sort((a, b) => a.issue - b.issue);
  } finally { db.close(); }
}

if (process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === import.meta.url) {
  process.stdout.write(JSON.stringify(approvedDataset(process.argv[2])));
}
