import { pages, processGpuIssue, queuedReport } from './gpu-queue.mjs';
import { findGpuBrief } from './workflow.mjs';
import { jobMarker, jobMessage, publicJob, reportHash } from './generation-jobs.mjs';
import { checkExport } from '../game_prompt_studio/lib/model.mjs';

export async function processGpuJob(issue, github, generate, inbox, { reviewers = ['PeterFacina'] } = {}) {
  const note = queuedReport(issue);
  if (!note) return { status: 'not queued' };
  const comments = [];
  for await (const batch of pages(github, '/issues/' + issue.number + '/comments')) comments.push(...batch);
  // Publication wins over failed historical attempts, including after restart.
  const published = findGpuBrief(comments);
  let job = inbox.jobs.get(issue.number, reportHash(note));
  if (published && !job) return processGpuIssue(issue, github, generate, inbox.link);
  job ??= inbox.jobs.ensure(issue.number, note, inbox.read(issue.number).captures);
  for (const comment of published ? [] : comments) {
    const retried = inbox.jobs.retry(job, comment, reviewers);
    if (retried) { job = retried; break; }
  }
  async function notify() {
    job = inbox.jobs.get(job.issue, job.reportHash);
    const safe = publicJob(job);
    const signature = JSON.stringify(safe);
    if (signature === job.noticeSignature) return;
    if (!job.noticeId) {
      const existing = comments.find(comment => ['OWNER', 'MEMBER', 'COLLABORATOR'].includes(comment.author_association) &&
        comment.body?.startsWith(jobMarker + '\n') && comment.body.split('\n')[1] === signature);
      if (existing) { inbox.jobs.update(job, { noticeId: existing.id, noticeSignature: signature }, 'status-reconciled'); return; }
    }
    const payload = { body: jobMarker + '\n' + signature + '\n\n' + jobMessage(safe) };
    const result = job.noticeId ? await github('/issues/comments/' + job.noticeId, 'PATCH', payload)
      : await github('/issues/' + issue.number + '/comments', 'POST', payload);
    inbox.jobs.update(job, { noticeId: result.id, noticeSignature: signature }, 'status-published');
  }
  if (published) {
    const result = await processGpuIssue(issue, github, generate, inbox.link);
    if (job.state !== 'published') job = inbox.jobs.update(job, { state: 'published', reason: null }, 'publication-reconciled');
    await notify().catch(() => {});
    return result;
  }
  const guardedGenerate = async () => {
    // Reuse a captured guarded draft after GitHub publication trouble, never run
    // the model again solely because a POST response was lost.
    const reusable = inbox.read(issue.number).captures.findLast(row => row.input.report === note && row.input.exportPassed === true);
    if (reusable) {
      const facts = JSON.parse(reusable.input.request.messages.find(message => message.role === 'user').content).verifiedProjectFacts;
      if (checkExport(reusable.brief, reusable.input.exportEvidence ?? reusable.input.retrievedContext, facts).length) {
        job = inbox.jobs.fail(job, Object.assign(new Error('Guard revalidation failed'), { code: 'GUARD_REVIEW_REQUIRED' }));
      } else return { brief: reusable.brief, captureId: reusable.id };
    }
    const reserved = inbox.jobs.reserve(job);
    if (!reserved) throw Object.assign(new Error('Generation is held or awaiting its bounded retry.'), { code: 'JOB_DEFERRED' });
    job = reserved;
    try {
      const result = await generate(note, issue, { authorizedRetry: Boolean(job.retryComment) });
      job = inbox.jobs.update(job, { state: 'generated', reason: null }, 'generation-complete');
      return result;
    } catch (error) { job = inbox.jobs.fail(job, error); throw error; }
  };
  let result;
  try {
    result = await processGpuIssue(issue, github, guardedGenerate, inbox.link);
    if (['posted', 'already posted'].includes(result.status)) job = inbox.jobs.update(job, { state: 'published', reason: null }, 'brief-published');
  } catch (error) {
    job = inbox.jobs.get(job.issue, job.reportHash);
    if (job.state === 'generated') job = inbox.jobs.update(job, { state: 'publication_pending', reason: 'publication' }, 'publication-unconfirmed');
    result = { status: job.state, reason: publicJob(job)?.reason ?? null };
  }
  // Notification errors cannot spend model attempts or hide the persisted state.
  await notify().catch(() => {});
  return result;
}
