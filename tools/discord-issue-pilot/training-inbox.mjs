import { createHash } from 'node:crypto';
import { mkdirSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { homedir } from 'node:os';
import { DatabaseSync } from 'node:sqlite';
import { buildDraft, checkExport } from '../game_prompt_studio/lib/model.mjs';

export const trainingPath = () => join(process.env.LOCALAPPDATA || homedir(),
  'HouseboatPromptTraining', 'examples.sqlite');
const digest = value => createHash('sha256').update(value).digest('hex');

export function openTrainingInbox(path = trainingPath()) {
  mkdirSync(dirname(path), { recursive: true });
  const db = new DatabaseSync(path);
  db.exec('PRAGMA journal_mode = WAL; PRAGMA busy_timeout = 5000;');
  db.exec('CREATE TABLE IF NOT EXISTS captures (issue INTEGER NOT NULL, id TEXT NOT NULL,'
    + ' input TEXT NOT NULL, brief TEXT NOT NULL, recorded TEXT NOT NULL, published TEXT, PRIMARY KEY(issue,id));'
    + ' CREATE TABLE IF NOT EXISTS reviews (issue INTEGER NOT NULL, at TEXT NOT NULL, data TEXT NOT NULL);');
  return {
    capture(issue, input, brief) {
      const serialized = JSON.stringify(input);
      const id = digest(serialized + '\n' + brief);
      db.prepare('INSERT OR IGNORE INTO captures (issue,id,input,brief,recorded) VALUES (?,?,?,?,?)')
        .run(issue, id, serialized, brief, new Date().toISOString());
    },
    link(issue, brief, url) {
      db.prepare('UPDATE captures SET published=? WHERE issue=? AND brief=? AND published IS NULL')
        .run(url, issue, brief);
    },
    read(issue) {
      return {
        issue,
        captures: db.prepare('SELECT id,input,brief,recorded,published FROM captures WHERE issue=? ORDER BY rowid')
          .all(issue).map(row => ({ ...row, input: JSON.parse(row.input) })),
        history: db.prepare('SELECT at,data FROM reviews WHERE issue=? ORDER BY rowid').all(issue)
          .map(row => ({ at: row.at, ...JSON.parse(row.data) })),
      };
    },
    addReview(issue, review) {
      const record = this.read(issue);
      if (!record.captures.length) throw new Error('No original model input captured for this issue.');
      if (typeof review.summary !== 'string' || !review.summary.trim()) throw new Error('Add a short review summary.');
      if (review.status === 'approved') {
        const capture = record.captures.find(row => row.id === review.captureId && row.published);
        if (!capture) throw new Error('Approval needs the ID of a published capture.');
        if (typeof review.reviewer !== 'string' || !review.reviewer.trim()) throw new Error('Name the reviewer.');
        const original = JSON.parse(capture.input.request.messages.find(message => message.role === 'user').content);
        const brief = buildDraft(review.target, 'Reviewed brief', original.verifiedProjectFacts,
          original.untrustedRetrievedEvidence, original.currentRequest.note);
        const findings = checkExport(brief, original.untrustedRetrievedEvidence, original.verifiedProjectFacts);
        if (findings.length) throw new Error('Target export rejected: ' + findings.join(', '));
      } else if (review.status !== 'feedback') {
        throw new Error('Use status feedback or approved.');
      }
      db.prepare('INSERT INTO reviews VALUES (?,?,?)').run(issue, new Date().toISOString(), JSON.stringify(review));
    },
    close() { db.close(); },
  };
}
