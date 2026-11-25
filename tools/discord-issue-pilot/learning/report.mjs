import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const [first, ...files] = process.argv.slice(2);
assert.ok(first, 'Supply benchmark and optional matching audit JSONL files');
const rows = [first, ...files].flatMap(path => readFileSync(path, 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line)));
const key = row => [row.case, row.variant, row.trial].join('/');
const groups = new Map();
const rowBy = phase => {
  const entries = rows.filter(row => row.phase === phase);
  const index = new Map(entries.map(row => [key(row), row]));
  assert.equal(entries.length, index.size, `Duplicate ${phase} identity`);
  return index;
};
const setups = rows.filter(row => row.phase === 'setup');
assert.ok(setups.length);
assert.equal(new Set(setups.map(row => row.revision)).size, 1, 'Mixed game revisions');
assert.ok(new Set(setups.map(row => row.digest).filter(Boolean)).size <= 1, 'Mixed model digests');
const drafts = rowBy('generation');
const audits = rowBy('audit');
const sum = (items, value) => items.reduce((total, item) => total + value(item), 0);
const median = numbers => {
  const sorted = numbers.sort((a, b) => a - b);
  const middle = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[middle] : (sorted[middle - 1] + sorted[middle]) / 2;
};
const ratio = (first, second) => [first, second];
for (const row of rowBy('retrieval').values()) {
  const sets = row.set === 'history-probe' ? [row.set] : [row.set, 'pooled'];
  for (const set of sets) {
    const id = [row.trial, set, row.variant].join('/');
    if (!groups.has(id)) groups.set(id, []);
    groups.get(id).push(row);
  }
}

const results = Object.fromEntries([...groups].sort(([a], [b]) => a.localeCompare(b)).map(([id, retrievals]) => {
  const generations = retrievals.map(row => drafts.get(key(row))).filter(Boolean);
  const grades = retrievals.map(row => audits.get(key(row))).filter(row => row && !row.error);
  return [id, {
    cases: retrievals.length,
    functions: ratio(sum(retrievals, row => row.covered.length), sum(retrievals, row => row.expected)),
    relevance: ratio(sum(retrievals, row => row.relevantIds.length), sum(retrievals, row => row.returned)),
    exactEvidence: ratio(retrievals.filter(row => row.exact).length, retrievals.length),
    audited: ratio(grades.length, retrievals.length),
    requirements: ratio(sum(grades, row => row.covered.length), sum(grades, row => row.requirements)),
    unsupported: sum(grades, row => row.unsupported.length),
    lessonRetrieved: retrievals.filter(row => row.lessonIds?.length).map(row => row.case),
    citedLesson: grades.filter(row => row.historyCitation).length,
    guard: ratio(generations.filter(row => row.exportPassed).length, generations.length),
    medianInputTokens: median(generations.map(row => row.promptTokens)) ?? null,
    medianOutputTokens: median(generations.map(row => row.outputTokens)) ?? null,
    medianWallMs: median(generations.map(row => row.wallMs)) ?? null,
    totalWallMs: sum(generations, row => row.wallMs),
    medianRetrievalMs: median(retrievals.map(row => row.wallMs)),
    plannerRounds: sum(retrievals, row => row.planning?.rounds ?? 0),
    plannerAdds: sum(retrievals, row => row.planning?.retrieved ?? 0),
    plannerRejects: sum(retrievals, row => row.planning?.rejected ?? 0),
    plannerFailures: sum(retrievals, row => row.planning?.errors.length ?? 0),
  }];
}));
console.log(JSON.stringify({ setups, results, errors: rows.filter(row => row.error) }, null, 2));
