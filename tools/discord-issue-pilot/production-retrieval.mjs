import { readFileSync } from 'node:fs';
import { buildCodeIndex } from './multistage/code-index.mjs';
import { collectEvidence } from './multistage/retrieval.mjs';
import { lessonStatus, relevantLesson } from './learning/lessons.mjs';

export const originalRetrieval = 'original';
export const candidateRetrieval = 'deterministic-v1';
const defaultLessons = new URL('./learning-lessons.json', import.meta.url);

export function retrievalConfig(mode = originalRetrieval, canary = '') {
  if (![originalRetrieval, candidateRetrieval].includes(mode)) throw new Error('Unknown HOUSEBOAT_RETRIEVAL_MODE.');
  const numbers = canary ? canary.split(',').map(value => value.trim()) : [];
  if (numbers.length > 25 || numbers.some(value => !/^[1-9]\d*$/.test(value) || !Number.isSafeInteger(Number(value))) ||
      (mode === originalRetrieval && numbers.length)) throw new Error('Invalid HOUSEBOAT_RETRIEVAL_CANARY_ISSUES.');
  const issues = new Set(numbers.map(Number));
  return { mode, issues, forIssue: issue => issues.size && !issues.has(issue) ? originalRetrieval : mode };
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
  return (commit, note, issue, selection) => knowledge.withVerifiedCheckout(commit, async (root, manifest, tracked) => {
    if (cached?.commit !== commit) {
      const index = buildCodeIndex(root, manifest, tracked, { useGraphify: false });
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
    const { evidence } = await collectEvidence(index, note, { extra });
    if (!evidence.some(entry => entry.kind === 'source')) throw new Error('No verified deterministic source passages.');
    return evidence;
  });
}
