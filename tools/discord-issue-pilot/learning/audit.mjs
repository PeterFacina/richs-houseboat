import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { readFileSync } from 'node:fs';

const [reviewPath, ...paths] = process.argv.slice(2);
assert.ok(reviewPath && paths.length, 'Supply a review JSON file and the matching detailed benchmark JSONL files.');
const read = path => JSON.parse(readFileSync(new URL(path, import.meta.url), 'utf8'));
const old = read('../heldout-cases.json');
const stage = read('../multistage-cases.json');
const learning = read('../learning-cases.json');
const fixtures = new Map([...old.cases.map(example => ({ ...example, requirements: stage.regressionRequirements[example.id] })),
  ...stage.cases, ...learning.cases].map(example => [example.id, example]));
const key = row => [row.case, row.variant, row.trial].join('/');
const logs = paths.flatMap(path => readFileSync(path, 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line)));
const setups = logs.filter(row => row.phase === 'setup');
assert.ok(setups.length && setups.every(row => row.revision === learning.source && row.digest === setups[0].digest));
assert.ok(setups[0].digest, 'Pinned generator digest required');
const index = phase => {
  const rows = logs.filter(row => row.phase === phase);
  const result = new Map(rows.map(row => [key(row), row]));
  assert.equal(result.size, rows.length, `Duplicate ${phase} rows`);
  return result;
};
const retrievals = index('retrieval');
const drafts = index('generation');
const review = JSON.parse(readFileSync(reviewPath, 'utf8'));
assert.equal(new Set(review.map(key)).size, review.length, 'Duplicate review entries');

for (const row of review) {
  const id = key(row);
  const draft = drafts.get(id);
  const evidence = retrievals.get(id)?.evidence;
  assert.ok(draft?.payload && evidence, `Detailed draft and evidence required for ${id}`);
  const fingerprint = createHash('sha256').update(JSON.stringify(draft.payload)).digest('hex');
  assert.equal(fingerprint, row.payloadSha256, `Review belongs to a different draft for ${id}`);
  const requirements = fixtures.get(row.case).requirements.length;
  assert.ok(row.covered.every(value => Number.isInteger(value) && value >= 1 && value <= requirements), id);
  const bullets = Object.entries(draft.payload).flatMap(([field, lines]) =>
    field === 'observations' ? lines.filter(line => line.trim().endsWith('?')) : lines);
  for (const { quote, reason } of row.unsupported) {
    assert.ok(quote && reason && bullets.some(bullet => bullet.includes(quote)), `Review quote differs from draft in ${id}: ${quote}`);
  }
  const history = evidence.find(item => item.kind === 'github' && item.title.startsWith('Source-verified historical lesson'));
  console.log(JSON.stringify({ phase: 'audit', case: row.case, set: draft.set, variant: row.variant, trial: row.trial,
    requirements, covered: [...new Set(row.covered)], unsupported: row.unsupported,
    historyCitation: Boolean(history && bullets.some(bullet => bullet.includes(`[${history.id}]`))),
  }));
}
