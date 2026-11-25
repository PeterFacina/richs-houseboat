import { createHash } from 'node:crypto';
import { terms } from '../multistage/code-index.mjs';

export const functionFingerprint = item => createHash('sha256').update(item.lines.join('\n')).digest('hex');

export function pinLesson(record, index, revision) {
  if (record.implementation?.revision !== revision) throw new Error('Pin the lesson at the verified implementation revision');
  const anchors = record.anchors.map(({ path, name }) => {
    const matches = index.files.get(path)?.entries.filter(item => item.symbolKind === 'func' && item.name === name) ?? [];
    if (matches.length !== 1) throw new Error(`Expected an unambiguous source anchor ${path}:${name}`);
    return { path, name, sha256: functionFingerprint(matches[0]) };
  });
  const pinned = { ...record, anchors, trainingApproval: null };
  if (!verified(pinned, index)) throw new Error('Missing lesson provenance or verification');
  return pinned;
}

function verified(item, index) {
  if (!item?.id || !item.report?.number || !item.implementation?.pull || !item.implementation?.revision ||
      !item.success || !item.failure || !item.verification || !item.provenance?.length || !item.anchors?.length) return false;
  return item.anchors.every(anchor => {
    const entry = index.files.get(anchor.path)?.entries.find(fn => fn.symbolKind === 'func' && fn.name === anchor.name);
    return entry && functionFingerprint(entry) === anchor.sha256;
  });
}

export function lessonStatus(snapshot, index) {
  const lessons = Array.isArray(snapshot?.lessons) ? snapshot.lessons.slice(0, 100) : [];
  return lessons.map(item => ({ item, current: verified(item, index) }));
}

export function approvalFingerprint(item) {
  const { trainingApproval, ...content } = item;
  return createHash('sha256').update(JSON.stringify(content)).digest('hex');
}

// This gate lists eligible local records. It never trains, writes, or approves anything.
export function approvedTrainingLessons(statuses) {
  return statuses.filter(({ item, current }) => current && item.trainingApproval?.decision === 'approved' &&
    typeof item.trainingApproval.reviewer === 'string' && item.trainingApproval.reviewer.trim() &&
    item.trainingApproval.fingerprint === approvalFingerprint(item)).map(({ item }) => item.id);
}

export function relevantLesson(statuses, note, selected, excluded = new Set()) {
  const keywords = new Set(terms(note));
  return statuses.filter(({ item, current }) => current && !excluded.has(`issue/${item.report.number}`) &&
      !excluded.has(`pull/${item.implementation.pull}`))
    .map(({ item }) => {
      const shared = [...new Set(terms((item.scope ?? []).join(' ')))].filter(term => keywords.has(term)).length;
      const supported = selected.some(candidate => item.anchors.some(anchor => anchor.path === candidate.path && anchor.name === candidate.name));
      return { item, score: shared >= 3 ? shared + (supported ? 2 : 0) : 0 };
    }).sort((a, b) => b.score - a.score).find(hit => hit.score)?.item;
}

export function lessonEvidence(item) {
  return { kind: 'github', title: `Source-verified historical lesson from issue #${item.report.number} and merged PR #${item.implementation.pull}`,
    excerpt: `History only. Failed approach: ${item.failure} Merged correction: ${item.success} Verification: ${item.verification}`.slice(0, 440) };
}
