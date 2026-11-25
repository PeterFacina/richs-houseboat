import { readFileSync } from 'node:fs';
import { buildCodeIndex } from './multistage/code-index.mjs';
import { collectGameEvidence } from './multistage/game-route-evidence.mjs';
import { lessonStatus, relevantLesson } from './learning/lessons.mjs';

export const originalRetrieval = 'original';
export const candidateRetrieval = 'deterministic-v1';
export const candidateBrief = 'verification-v1';
export const verificationGuidance = [
  'State each requested behavior and preservation constraint as a separate observable check.',
  'For each changed state or transition, name the setup, action, expected observation, and when it must hold. A required behavior during a blocked or paused state must be checked in that state, not just after resume.',
  'When the request says a displayed value must stay live, change its input in a controlled fixture and compare before and after while the specified state is held.',
  'For diagnosis or documentation, acceptance is recording what happened, including a failed observation. Do not turn it into a behavior change or require a result that the report leaves open.',
  'Keep tests in the requested roles and modes. For a shared behavior change, use the authoritative side, affected client, and an unaffected observer where relevant. Prefer the existing focused regression test.',
  'Keep uncertain implementation details as inspection questions. Never turn a reported symptom into a confirmed cause or substitute a broader smoke test for a missing acceptance check.',
].join(' ');
const defaultLessons = new URL('./learning-lessons.json', import.meta.url);

export function retrievalConfig(mode = originalRetrieval, canary = '') {
  if (![originalRetrieval, candidateRetrieval].includes(mode)) throw new Error('Unknown HOUSEBOAT_RETRIEVAL_MODE.');
  const issue = Number(canary);
  if (mode === candidateRetrieval ? !/^[1-9]\d*$/.test(canary) || !Number.isSafeInteger(issue) : canary !== '') {
    throw new Error('Set HOUSEBOAT_RETRIEVAL_CANARY_ISSUES to exactly one issue in deterministic-v1 mode, or leave it unset in original mode.');
  }
  return { mode, issue: issue || null, forIssue: number => number === issue ? mode : originalRetrieval };
}

function verifiedEvidence(lesson) {
  const { failure: failed, success: succeeded, feedback, verification } = lesson;
  if (![failed, succeeded, feedback, verification].every(text => typeof text === 'string' && text.trim() &&
      text.length <= 240 && !/[\p{Cc}\p{Cf}]/u.test(text))) return null;
  return { kind: 'verified-lesson', title: 'Source-verified lesson from issue #' + lesson.report.number,
    issue: lesson.report.number, pull: lesson.implementation.pull, failed, succeeded, feedback, verification,
    excerpt: ['Prior task only.', failed, succeeded, feedback, verification].join(' ') };
}

export function deterministicRetriever(knowledge, { lessons = defaultLessons } = {}) {
  let cached;
  const snapshot = JSON.parse(readFileSync(lessons, 'utf8'));
  return (commit, note, issue, selection) => knowledge.withVerifiedCheckout(commit, (root, manifest, tracked) => {
    if (cached?.commit !== commit) {
      const index = buildCodeIndex(root, manifest, tracked);
      cached = { commit, index, lessons: lessonStatus(snapshot, index) };
    }
    const { index } = cached;
    const extra = (selection?.tasks ?? []).slice(0, 3).map(({ number, title, label }) =>
      ({ kind: 'github', title: label + ' #' + number, excerpt: title.slice(0, 200) }));
    const lesson = relevantLesson(cached.lessons, note, [], new Set(['issue/' + issue]));
    const item = lesson && verifiedEvidence(lesson);
    if (item) {
      index.verify(lesson.anchors);
      extra.push(item);
    }
    const evidence = collectGameEvidence(index, note, extra);
    if (!evidence.some(entry => entry.kind === 'source')) throw new Error('No verified deterministic source passages.');
    return evidence;
  });
}
