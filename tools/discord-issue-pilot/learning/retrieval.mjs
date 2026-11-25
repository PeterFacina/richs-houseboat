import { createHash } from 'node:crypto';
import { buildCodeIndex, terms } from '../multistage/code-index.mjs';
import { historical, leads, windows } from '../multistage/retrieval.mjs';
import { enrichRelationships, symbolKey } from './relationships.mjs';
import { lessonEvidence, lessonStatus, relevantLesson } from './lessons.mjs';

const SOURCE_COUNT = 11;
const CORE_COUNT = 8;
const TOTAL = 5800;
const evidenceKinds = new Set(['search', 'function', 'file', 'dependencies']);
export const noteKey = note => createHash('sha256').update(note).digest('hex');

export function buildLearningIndex(root, manifest, tracked, { history, lessons, graph, embeddings } = {}) {
  const index = buildCodeIndex(root, manifest, tracked, { history });
  const byId = new Map([...index.byId].map(([id, item]) => [id, { ...item, links: new Map(item.links) }]));
  const baseline = { ...index, byId, rank: (query, items) => index.rank(query, items)
    .map(hit => ({ ...hit, item: byId.get(hit.item.id) })) };
  const relationships = enrichRelationships(index, graph);
  const statuses = lessonStatus(lessons, index);
  const cache = embeddings && embeddings.revision === manifest.revision ? embeddings : undefined;
  return { ...index, baseline, statuses, embeddings: cache,
    stats: { ...index.stats, ...relationships, currentLessons: statuses.filter(item => item.current).length,
      staleLessons: statuses.filter(item => !item.current).length,
      embeddingModel: cache?.model ?? null } };
}

function edgeWeight(relation) {
  if (/typed call|resolved dispatch|Graphify call/.test(relation)) return 1.0;
  if (/lexical call/.test(relation)) return .82;
  if (/shared field/.test(relation)) return .24;
  return .38;
}

function similarity(a, b) {
  if (!Array.isArray(a) || !Array.isArray(b) || a.length !== b.length || a.length < 1 || a.length > 1024) return 0;
  const sum = a.reduce((total, value, i) => total + value * b[i], 0);
  return Number.isFinite(sum) ? sum : 0;
}

export function rankedFunctions(index, note) {
  const query = index.query(note);
  const functions = index.entries.filter(item => item.symbolKind === 'func');
  const all = index.rank(query, functions);
  const normalizer = Math.max(all[0]?.score ?? 0, 1);
  const totals = new Map(all.map(({ item, score }) => [item.id, .68 * score / normalizer]));
  const variations = note.split(/[.!?;]+\s+|,\s+|\band\s+(?=\w+)/i).filter(value => new Set(terms(value)).size >= 3).slice(0, 10);
  const facets = variations.map(value => {
    const ranked = index.rank(index.query(value), functions).slice(0, 20);
    const scale = Math.max(ranked[0]?.score ?? 0, 1);
    return new Map(ranked.map(({ item, score }) => [item.id, score / scale]));
  });
  for (const facet of facets) for (const [id, score] of facet) {
    totals.set(id, (totals.get(id) ?? 0) + .25 * score / Math.sqrt(Math.max(1, facets.length)));
  }
  const baseline = leads(index, note, query).filter(item => item.symbolKind === 'func');
  for (const [position, item] of baseline.slice(0, 12).entries()) totals.set(item.id, (totals.get(item.id) ?? 0) + .09 / (1 + position / 6));
  const seeds = [...totals.entries()].sort((a, b) => b[1] - a[1]).slice(0, 18);
  const graph = new Map();
  for (const [id, value] of seeds) {
    const item = index.byId.get(id);
    const linked = [...item.links].sort((a, b) => edgeWeight(b[1]) - edgeWeight(a[1])).slice(0, 28);
    for (const [target, relation] of linked) {
      if (index.byId.get(target)?.symbolKind !== 'func') continue;
      // A graph neighbor needs score support from the report before the edge boosts it.
      if ((totals.get(target) ?? 0) < .10) continue;
      const add = .28 * value * edgeWeight(relation) / Math.sqrt(1 + linked.length / 10);
      graph.set(target, Math.max(graph.get(target) ?? 0, add));
    }
  }
  for (const [id, score] of graph) totals.set(id, (totals.get(id) ?? 0) + score);
  const queryVector = index.embeddings?.queries?.[noteKey(note)];
  if (queryVector) for (const [id, score] of totals) {
    const embedding = index.embeddings.documents?.[symbolKey(index.byId.get(id))];
    if (embedding) totals.set(id, score + .35 * Math.max(0, similarity(queryVector, embedding) - .18));
  }
  const ordered = [...totals].sort((a, b) => b[1] - a[1] || Number(a[0].slice(1)) - Number(b[0].slice(1)));
  const slate = ordered.slice(0, 80).map(([id]) => index.byId.get(id));
  const result = [];
  const represented = new Set();
  const fileCount = new Map();
  while (slate.length) {
    let best = 0, bestScore = -Infinity;
    for (const [i, item] of slate.entries()) {
      const facetGain = facets.reduce((sum, facet, j) => sum + Number(!represented.has(j) && (facet.get(item.id) ?? 0) >= .72), 0);
      const score = totals.get(item.id) + .11 * facetGain - .035 * (fileCount.get(item.path) ?? 0);
      if (score > bestScore) { bestScore = score; best = i; }
    }
    const [item] = slate.splice(best, 1);
    result.push(item);
    fileCount.set(item.path, (fileCount.get(item.path) ?? 0) + 1);
    facets.forEach((facet, j) => { if ((facet.get(item.id) ?? 0) >= .72) represented.add(j); });
  }
  return { query, result };
}

export async function retrieve(index, note, { planner, signal = AbortSignal.timeout(120_000), excludeHistory = new Set() } = {}) {
  note = note.slice(0, 6500);
  const { query, result } = rankedFunctions(index, note);
  const established = leads(index.baseline, note, query).slice(0, CORE_COUNT);
  const coreIds = [...new Set([...established, ...result].map(item => item.id))].slice(0, CORE_COUNT);
  const core = coreIds.map(id => index.byId.get(id));
  const selected = new Map(core.map(item => [item.id, item]));
  const planning = { rounds: 0, promptTokens: 0, outputTokens: 0, requested: 0, retrieved: 0, rejected: 0, errors: [] };
  const requested = new Set();
  let systems = [];
  const pool = index.entries.filter(item => item.symbolKind === 'func');

  for (let round = 0; planner && round < 2 && selected.size < SOURCE_COUNT; round++) {
    signal.throwIfAborted();
    const candidates = [...result.slice(0, 39)].filter(item => !selected.has(item.id))
      .map(item => ({ handle: item.id, file: item.path, symbol: item.name, line: item.line }));
    const observed = [...selected.values()].map(item => ({ handle: item.id, ...windows(item, query, 285),
      links: [...item.links].slice(0, 3).map(([id, relation]) => `${id} ${index.byId.get(id).name} (${relation})`) }));
    const input = { note, round: round + 1, systems, observed, candidates };
    while (candidates.length > 0 && Buffer.byteLength(JSON.stringify(input)) > 9400) candidates.pop();
    if (Buffer.byteLength(JSON.stringify(input)) > 9400) break;
    planning.rounds++;
    let response;
    try { response = await planner(input, signal); }
    catch { planning.errors.push('Planner request failed or timed out'); break; }
    planning.promptTokens += response.promptTokens ?? 0;
    planning.outputTokens += response.outputTokens ?? 0;
    const plan = response.plan;
    if (!Array.isArray(plan?.requests) || typeof plan.more !== 'boolean') {
      planning.errors.push(response.failure ?? 'Malformed planner response');
      break;
    }
    systems = Array.isArray(plan.systems) ? plan.systems.filter(item => typeof item === 'string').slice(0, 4).map(item => item.slice(0, 65)) : [];
    const before = selected.size;
    const roundLimit = Math.min(SOURCE_COUNT, before + (round === 0 && plan.more ? 2 : 3));
    for (const action of plan.requests.slice(0, 4)) {
      if (selected.size >= roundLimit) break;
      planning.requested++;
      const target = typeof action?.target === 'string' ? action.target.trim() : '';
      const kind = action?.kind;
      const key = `${kind}:${target}`;
      if (!evidenceKinds.has(kind) || target.length < 1 || target.length > 120 || requested.has(key)) { planning.rejected++; continue; }
      requested.add(key);
      const anchor = index.byId.get(target);
      let options = [];
      if (kind === 'function') options = anchor ? [anchor] : result.filter(item => item.name === target);
      if (kind === 'file') options = index.files.get(anchor?.path ?? target)?.entries ?? [];
      if (kind === 'dependencies' && anchor) options = [...anchor.links.keys()].map(id => index.byId.get(id));
      if (kind === 'search' && /^[\p{L}\p{N}_ ,.-]+$/u.test(target)) {
        options = index.rank(index.query(target), pool).slice(0, 15).map(hit => hit.item);
      }
      const option = index.rank(query, options.filter(item => item.symbolKind === 'func' && !selected.has(item.id)))[0]?.item;
      // Requests must add a function with a report signal or a strong connection to the reserved core.
      const connected = option && core.some(item => edgeWeight(item.links.get(option.id) ?? '') >= .82);
      if (!option || (!result.slice(0, 58).includes(option) && !connected)) { planning.rejected++; continue; }
      selected.set(option.id, option);
    }
    planning.retrieved += selected.size - before;
    if (!plan.more || selected.size === before) break;
  }
  signal.throwIfAborted();
  for (const item of result) {
    if (selected.size >= SOURCE_COUNT) break;
    if (!selected.has(item.id)) selected.set(item.id, item);
  }
  const picked = [...selected.values()];
  const lesson = relevantLesson(index.statuses, note, core, excludeHistory);
  const guide = index.rank(query, index.docs)[0]?.item;
  const extras = [guide && windows(guide, query, 350), lesson && lessonEvidence(lesson)].filter(Boolean);
  if (!lesson) extras.push(...historical(index, query, excludeHistory).slice(0, 1));
  const remaining = TOTAL - extras.reduce((sum, item) => sum + item.excerpt.length, 0);
  const excerptLimit = Math.floor(remaining / SOURCE_COUNT);
  const evidence = [...picked.map(item => windows(item, query, excerptLimit)).filter(Boolean), ...extras]
    .map((item, i) => ({ ...item, id: `S${i + 1}` }));
  if (evidence.reduce((sum, item) => sum + item.excerpt.length, 0) > TOTAL) throw new Error('Evidence exceeds the common excerpt budget');
  index.verify(evidence);
  return { evidence, planning, lessonIds: lesson ? [lesson.id] : [], reserved: core.map(symbolKey) };
}
