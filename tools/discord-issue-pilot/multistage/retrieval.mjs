import { terms } from './code-index.mjs';

function weight(line, query) {
  return [...new Set(terms(line))].reduce((total, term) =>
    total + (query.weights.get(term) ?? 0) + .4 * (query.semantic.get(term) ?? 0) + (query.focus.has(term) ? 8 : 0), 0);
}

export function windows(item, query, limit) {
  const complete = item.lines.join('\n');
  if (complete && complete.length <= limit) return { excerpt: complete, line: item.line };
  const weights = item.lines.map(line => weight(line, query));
  let best;
  for (let start = 0; start < item.lines.length; start++) {
    if (!item.lines[start].trim()) continue;
    let bytes = 0;
    let score = start === 0 ? 1.1 : 0;
    for (let end = start; end < item.lines.length; end++) {
      const line = item.lines[end];
      bytes += line.length + (end === start ? 0 : 1);
      if (bytes > limit) break;
      score += weights[end];
      if (!line.trim()) continue;
      const boundary = end === item.lines.length - 1 || !item.lines[end + 1].trim() ||
        item.lines[end + 1].search(/\S/) <= item.lines[start].search(/\S/);
      const quality = score / Math.sqrt(4 + end - start) + (boundary ? .8 : 0);
      if (!best || quality > best.quality) best = { start, end, quality };
    }
  }
  if (!best) return null;
  return { excerpt: item.lines.slice(best.start, best.end + 1).join('\n'), line: item.line + best.start };
}

function leads(index, query) {
  const ranked = index.rank(query).filter(hit => hit.item.kind === 'source' && hit.lexical > 0);
  const focused = ranked.filter(hit => [...query.focus].some(term => hit.item.body.has(term) || hit.item.nameTerms.has(term)));
  const hits = focused.length ? focused : ranked;
  if (!hits.length) return [];
  const roots = hits.filter(hit => hit.score >= hits[0].score * .52).slice(0, 6);
  const slate = new Map(roots.map(hit => [hit.item.id, hit]));
  for (const root of roots.slice(0, 3)) {
    const neighbors = [...root.item.links].flatMap(([id, relation]) => relation.startsWith('lexical ')
      ? [{ item: index.byId.get(id), relation }] : []);
    for (const hit of index.rank(query, neighbors.map(neighbor => neighbor.item)).slice(0, 4)) {
      if (slate.has(hit.item.id) || !hit.lexical || hit.score < roots[0].score * .23) continue;
      const relation = neighbors.find(neighbor => neighbor.item === hit.item).relation;
      const implementation = root === roots[0] && relation === 'lexical call' &&
        [...query.focus].some(term => hit.item.nameTerms.has(term));
      slate.set(hit.item.id, { ...hit, relation, anchor: root.item.name, implementation });
    }
  }
  return [roots[0], ...[...slate.values()].filter(hit => hit !== roots[0])
    .sort((a, b) => Number(Boolean(b.implementation)) - Number(Boolean(a.implementation)) || b.score - a.score)];
}

export function collectEvidence(index, note, extra = []) {
  const query = index.query(note.slice(0, 6500));
  const picked = leads(index, query);
  const guide = index.rank(query, index.docs).find(hit => hit.lexical > 0 &&
    (!query.focus.size || [...query.focus].filter(term => hit.item.features.has(term)).length >= 2))?.item;
  const passage = guide && windows(guide, query, 340);
  const context = passage ? [{ ...passage, title: guide.name, kind: guide.kind, path: guide.path }, ...extra] : extra;
  let remaining = 5800 - context.reduce((sum, item) => sum + item.excerpt.length, 0);
  const source = [];
  for (const hit of picked) {
    if (remaining < 180) break;
    const { item, score, anchor, relation } = hit;
    const excerpt = windows(item, query, Math.min(remaining, source.length < 3 ? 1550 : 800));
    if (!excerpt) continue;
    const matched = [...query.weights.keys()].filter(term => item.features.has(term)).slice(0, 5);
    const reason = relation ? `${relation} of ${anchor}` : `Matches ${matched.join(', ')}`;
    remaining -= excerpt.excerpt.length;
    source.push({ ...excerpt, title: item.name, kind: item.kind, path: item.path, reason,
      score: Math.round(score * 100) / 100 });
  }
  const evidence = [...source, ...context].map((item, i) => ({ ...item, id: 'S' + (i + 1) }));
  index.verify(evidence);
  return evidence;
}
