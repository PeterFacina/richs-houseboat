import assert from 'node:assert/strict';
import { readFileSync } from 'node:fs';

const [auditFile, ...logs] = process.argv.slice(2);
if (!auditFile || !logs.length) throw new Error('Supply the adjudication JSON and one or more completed benchmark JSONL files.');
const audit = JSON.parse(readFileSync(auditFile, 'utf8'));
const rows = logs.flatMap(path => readFileSync(path, 'utf8').trim().split(/\r?\n/).map(line => JSON.parse(line)));
const setups = rows.filter(row => row.phase === 'setup');
const [first] = setups;
assert.ok(first?.digest, 'Expected real Ollama runs');
for (const setup of setups) {
  assert.equal(setup.revision, first.revision);
  assert.equal(setup.digest, first.digest);
  assert.deepEqual(setup.settings, first.settings);
}
assert.equal(rows.filter(row => row.phase === 'error').length, 0, 'A benchmark variant had an execution error');
const key = row => `${row.case}/${row.variant}`;
const pairs = new Map(rows.filter(row => row.phase === 'retrieval').map(row => [key(row), row]));
assert.equal(pairs.size, 40, 'Expected four variants on each of ten cases');
const seen = new Set();
const cases = rows.filter(row => row.phase === 'generation').map(row => {
  const id = key(row);
  assert.ok(!seen.has(id), `Duplicate generation ${id}`);
  seen.add(id);
  const retrieval = pairs.get(id);
  assert.ok(retrieval?.exact, `Missing exact verified evidence for ${id}`);
  const decision = audit.cases[row.case]?.[row.variant];
  assert.ok(decision, `Missing review decision for ${id}`);
  const requirementCount = audit.cases[row.case].requirementCount;
  assert.ok(decision.missed.every(n => Number.isInteger(n) && n > 0 && n <= requirementCount));
  assert.equal(new Set(decision.missed).size, decision.missed.length);
  return { case: row.case, set: row.set, variant: row.variant, covered: retrieval.covered, expected: retrieval.expected,
    relevant: retrieval.relevantIds.length, returned: retrieval.returned, requirementCount,
    requirementsCovered: requirementCount - decision.missed.length, unsupported: decision.unsupported.length,
    inputTokens: row.promptTokens, outputTokens: row.outputTokens, draftInputTokens: row.draftPromptTokens,
    draftOutputTokens: row.draftOutputTokens, totalMs: row.wallMs, retrievalMs: retrieval.wallMs,
    modelLoadMs: row.loadMs, exportPassed: row.exportPassed, guard: row.guard,
    history: retrieval.selected.filter(item => item.kind === 'github').length,
    ...(retrieval.planning ? { planning: retrieval.planning } : {}) };
});
assert.equal(cases.length, pairs.size, 'Missing generation results');

const variants = ['production', 'pr71', 'catalog', 'multistage'];
const totals = [];
function median(values) {
  const sorted = [...values].sort((a, b) => a - b);
  const mid = Math.floor(sorted.length / 2);
  return sorted.length % 2 ? sorted[mid] : (sorted[mid - 1] + sorted[mid]) / 2;
}
for (const set of ['regression', 'independent', 'all']) for (const variant of variants) {
  const subset = cases.filter(row => row.variant === variant && (row.set === set || set === 'all'));
  const sum = field => subset.reduce((total, row) => total + row[field], 0);
  totals.push({ set, variant, cases: subset.length, covered: subset.reduce((total, row) => total + row.covered.length, 0),
    expected: sum('expected'), relevant: sum('relevant'), returned: sum('returned'),
    requirementsCovered: sum('requirementsCovered'), requirements: sum('requirementCount'),
    unsupported: sum('unsupported'), exportPassed: subset.filter(row => row.exportPassed).length,
    medianInput: median(subset.map(row => row.inputTokens)), medianOutput: median(subset.map(row => row.outputTokens)),
    medianDraftInput: median(subset.map(row => row.draftInputTokens)), medianDraftOutput: median(subset.map(row => row.draftOutputTokens)),
    medianRetrievalMs: median(subset.map(row => row.retrievalMs)), medianTotalMs: median(subset.map(row => row.totalMs)) });
}
console.log(JSON.stringify({ revision: first.revision, pr71: first.pr71, pr72: first.pr72, model: first.model,
  digest: first.digest, settings: first.settings, index: setups.find(item => item.index)?.index,
  setupMs: setups.map(({ selected, setupMs }) => ({ selected, setupMs })), totals, cases }, null, 2));
