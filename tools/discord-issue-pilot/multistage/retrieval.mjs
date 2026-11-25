import { terms } from './code-index.mjs';

export function windows(item, query, limit) {
  let best = { score: -Infinity };
  for (let start = 0; start < item.lines.length; start++) {
    let excerpt = '';
    for (const line of item.lines.slice(start, start + 15)) {
      const next = excerpt ? excerpt + '\n' + line.slice(0, 350) : line.slice(0, 350);
      if (next.length > limit) { excerpt = next.slice(0, limit); break; }
      excerpt = next;
    }
    excerpt = excerpt.trimEnd();
    if (!excerpt || !item.lines[start].trim()) continue;
    const words = new Set(terms(excerpt));
    const direct = [...words].reduce((score, term) => score + (query.weights.get(term) ?? 0), 0);
    const related = [...words].reduce((score, term) => score + (query.semantic.get(term) ?? 0), 0);
    const score = direct + .55 * related + (start === 0 ? 1.1 : 0);
    if (score > best.score) best = { score, excerpt, line: item.line + start };
  }
  return best.excerpt ? { title: item.name, kind: item.kind, path: item.path, line: best.line, excerpt: best.excerpt } : null;
}

export function leads(index, note, query) {
  const full = index.rank(query).filter(hit => hit.item.symbolKind === 'func' || hit.item.kind === 'source');
  const slate = new Map();
  const add = (hit, boost = 0) => {
    if (!hit || hit.item.kind !== 'source') return;
    const total = hit.score + boost;
    if ((slate.get(hit.item.id)?.score ?? 0) < total) slate.set(hit.item.id, { item: hit.item, score: total });
  };
  full.slice(0, 18).forEach(hit => add(hit));
  for (const clause of note.split(/[.!?;]+\s+|\n+/).filter(text => terms(text).length >= 3).slice(0, 8)) {
    const relevant = index.rank(index.query(clause)).filter(hit => hit.item.kind === 'source').slice(0, 4);
    for (const [i, hit] of relevant.entries()) add(hit, 5 - i);
  }
  for (const { item, score } of full.slice(0, 9)) {
    const neighbors = [...item.links].map(([id, relation]) => ({ item: index.byId.get(id), relation }));
    for (const other of neighbors.slice(0, 24)) {
      const [hit] = index.rank(query, [other.item]);
      if (hit) add(hit, Math.min(score * .23, other.relation.includes('hint') ? 3 : 7));
    }
    for (const path of [...index.files.get(item.path).links.keys()].slice(0, 24)) {
      const related = index.rank(query, index.files.get(path).entries).filter(hit => hit.item.kind === 'source');
      add(related[0], Math.min(score * .1, 3));
    }
  }
  return [...slate.values()].sort((a, b) => b.score - a.score).map(hit => hit.item);
}

export function collectEvidence(index, note, extra = []) {
  note = note.slice(0, 6500);
  const query = index.query(note);
  const picked = leads(index, note, query).slice(0, 11);
  const guide = index.rank(query, index.docs)[0]?.item;
  const passage = guide && windows(guide, query, 300);
  const context = passage ? [passage, ...extra] : extra;
  const contextLength = context.reduce((sum, item) => sum + item.excerpt.length, 0);
  const limit = Math.min(760, Math.floor((5800 - contextLength) / Math.max(1, picked.length)));
  if (limit < 100) throw new Error('Source excerpt budget exhausted.');
  const source = picked.map(item => windows(item, query, limit)).filter(Boolean);
  const evidence = [...source, ...context].map((item, i) => ({ ...item, id: 'S' + (i + 1) }));
  index.verify(evidence);
  return evidence;
}
