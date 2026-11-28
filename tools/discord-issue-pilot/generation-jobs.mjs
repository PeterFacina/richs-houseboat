import { createHash, randomUUID } from 'node:crypto';

export const jobMarker = '<!-- houseboat-gpu-job:v1 -->';
export const jobReasons = Object.freeze({
  guard: 'Export guard rejected the brief. Review its private findings before authorizing one retry.',
  timeout: 'Generation timed out. Check local model health and context size before retrying.',
  malformed: 'Model output was not valid structured JSON. Inspect the model response privately.',
  output_limit: 'Model output reached its limit. Review the prompt and output budget.',
  interrupted: 'The worker stopped during an attempt. That attempt remains counted.',
  unavailable: 'Generation or its dependencies were unavailable. Check the private operator log.',
  publication: 'A guarded brief is saved, but publication was not confirmed. Recheck GitHub; do not regenerate.',
});
export const reportHash = note => createHash('sha256').update(note).digest('hex');
export function failureReason(error) {
  if (error.code === 'GUARD_REVIEW_REQUIRED') return 'guard';
  if (/timeout|timed out|too long|canceled|aborted/i.test(error.message)) return 'timeout';
  if (/output limit|reached.*limit/i.test(error.message)) return 'output_limit';
  if (/json|structured|incomplete draft/i.test(error.message)) return 'malformed';
  return 'unavailable';
}

// This ledger lives in the existing inbox. Reserve before model work so crashes
// and invalid responses consume an attempt even when no capture can be written.
export function generationJobs(db, { readOnly = false, now = Date.now } = {}) {
  if (!readOnly) db.exec(`CREATE TABLE IF NOT EXISTS generation_jobs (
    issue INTEGER NOT NULL, report_hash TEXT NOT NULL, data TEXT NOT NULL, PRIMARY KEY(issue,report_hash));
    CREATE TABLE IF NOT EXISTS generation_job_events (at TEXT NOT NULL, issue INTEGER NOT NULL, data TEXT NOT NULL);`);
  const read = (issue, hash) => JSON.parse(db.prepare('SELECT data FROM generation_jobs WHERE issue=? AND report_hash=?').get(issue, hash)?.data ?? 'null');
  const write = (job, event, actor = 'worker') => {
    job.updatedAt = new Date(now()).toISOString();
    db.prepare('INSERT INTO generation_jobs VALUES (?,?,?) ON CONFLICT(issue,report_hash) DO UPDATE SET data=excluded.data')
      .run(job.issue, job.reportHash, JSON.stringify(job));
    db.prepare('INSERT INTO generation_job_events VALUES (?,?,?)').run(job.updatedAt, job.issue, JSON.stringify({ event, actor, ...job }));
    return job;
  };
  function atomic(action) {
    db.exec('BEGIN IMMEDIATE');
    try { const result = action(); db.exec('COMMIT'); return result; }
    catch (error) { db.exec('ROLLBACK'); throw error; }
  }
  return {
    ensure(issue, note, captures = []) {
      return atomic(() => {
        const hash = reportHash(note);
        const existing = read(issue, hash);
        if (existing) return existing;
        const old = captures.filter(row => row.input.report === note);
        const rejected = old.some(row => row.input.exportPassed === false);
        return write({ issue, reportHash: hash, id: randomUUID(), attempts: old.length, limit: 3,
          state: rejected ? 'held' : old.length >= 3 ? 'failed' : 'ready', reason: rejected ? 'guard' : null,
          nextAt: 0, noticeId: null, noticeSignature: null }, 'created');
      });
    },
    get(issue, hash) { return read(issue, hash); },
    reserve(job) {
      return atomic(() => {
        const current = read(job.issue, job.reportHash);
        if (['held', 'failed', 'published', 'generated', 'publication_pending'].includes(current.state)) return null;
        if (current.attempts >= current.limit) { write({ ...current, state: 'failed', reason: current.reason || 'interrupted' }, 'budget-exhausted'); return null; }
        if (current.nextAt > now()) return null;
        return write({ ...current, attempts: current.attempts + 1, state: 'running', reason: 'interrupted', nextAt: now() + 120_000 }, 'attempt-reserved');
      });
    },
    fail(job, error) {
      const current = read(job.issue, job.reportHash);
      const reason = failureReason(error);
      return write({ ...current, state: reason === 'guard' ? 'held' : current.attempts >= current.limit ? 'failed' : 'retry_wait',
        reason, nextAt: now() + 120_000 }, 'attempt-failed');
    },
    update(job, changes, event) { return write({ ...read(job.issue, job.reportHash), ...changes }, event); },
    retry(job, comment, reviewers = ['PeterFacina']) {
      return atomic(() => {
        const current = read(job.issue, job.reportHash);
        if (!['held', 'failed'].includes(current.state) || comment.body?.trim() !== '/gpu-retry ' + current.id ||
          !['OWNER', 'MEMBER', 'COLLABORATOR'].includes(comment.author_association) || comment.user?.type !== 'User' ||
          !reviewers.some(login => login.toLowerCase() === comment.user?.login?.toLowerCase()) ||
          !Number.isSafeInteger(comment.id) || comment.id <= 0 || comment.html_url !== 'https://github.com/PeterFacina/richs-houseboat/issues/' + current.issue + '#issuecomment-' + comment.id) return false;
        // Rotating the ID makes an old comment unusable even after another failure.
        return write({ ...current, id: randomUUID(), limit: current.attempts + 1, state: 'ready', reason: null, nextAt: 0,
          retryComment: comment.id, retryUrl: comment.html_url, retryBy: comment.user.login,
          retryCreatedAt: comment.created_at ?? null }, 'one-retry-authorized', comment.user.login);
      });
    },
  };
}

export function publicJob(job) {
  if (!job || !['ready', 'running', 'retry_wait', 'held', 'failed', 'generated', 'publication_pending', 'published'].includes(job.state) ||
      !Number.isSafeInteger(job.attempts) || job.attempts < 0 || !Number.isSafeInteger(job.limit) || job.limit < 1 ||
      !/^[a-f0-9-]{36}$/.test(job.id ?? '')) return null;
  return { id: job.id, state: job.state, attempts: job.attempts, limit: job.limit,
    reason: Object.hasOwn(jobReasons, job.reason) ? job.reason : null };
}
export function jobMessage(job) {
  const safe = publicJob(job);
  return safe ? `GPU job: ${safe.state} (${safe.attempts}/${safe.limit} attempts).` +
    (safe.reason ? ' ' + jobReasons[safe.reason] : '') +
    (['held', 'failed'].includes(safe.state) ? ` Authorized operator: comment /gpu-retry ${safe.id} on this issue to grant exactly one attempt.` : '') : '';
}
export function findGpuJob(comments) {
  for (const comment of [...comments].reverse()) {
    if (!['OWNER', 'MEMBER', 'COLLABORATOR'].includes(comment.author_association) || !comment.body?.startsWith(jobMarker + '\n')) continue;
    try { const job = publicJob(JSON.parse(comment.body.split('\n')[1])); if (job) return job; } catch {}
  }
  return null;
}
