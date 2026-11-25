import { readFileSync } from 'node:fs';
import { localSource } from './local-source.mjs';
import { buildCodeIndex } from '../multistage/code-index.mjs';
import { approvalFingerprint, approvedTrainingLessons, lessonStatus, pinLesson } from './lessons.mjs';

const [action, checkout, file] = process.argv.slice(2);
if (!checkout || !file || !['pin', 'status'].includes(action)) throw new Error('Use pin|status CHECKOUT RECORD_JSON');
const { root, manifest, tracked } = localSource(checkout);
const index = buildCodeIndex(root, manifest, tracked);
const snapshot = JSON.parse(readFileSync(file, 'utf8'));
if (action === 'pin') {
  const lessons = snapshot.lessons.map(record => pinLesson(record, index, manifest.revision));
  console.log(JSON.stringify({ lessons }, null, 2));
} else {
  const status = lessonStatus(snapshot, index);
  console.log(JSON.stringify({ revision: manifest.revision, approved: approvedTrainingLessons(status),
    lessons: status.map(({ item, current }) => ({ id: item.id, current, fingerprint: approvalFingerprint(item) })) }, null, 2));
}
