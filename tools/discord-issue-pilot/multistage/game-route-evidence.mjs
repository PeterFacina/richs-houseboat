import { resolveGameRoutes } from '../../knowledge/game-routes.mjs';
import { collectEvidence, windows } from './retrieval.mjs';

function pinnedPassage(index, path, query, limit) {
  const entries = index.files.get(path)?.entries;
  if (!entries?.length) return null;
  const functions = entries.filter(entry => entry.symbolKind === 'func');
  const candidates = functions.length ? functions : entries;
  const item = index.rank(query, candidates)[0]?.item ?? candidates[0];
  const passage = windows(item, query, limit);
  return passage && { ...passage, kind: item.kind, title: item.name, path };
}

export function collectGameEvidence(index, note, extra = []) {
  const { lookup, filenames, paths, primaryPaths, guides } = resolveGameRoutes(note.slice(0, 6500));
  const query = index.query(lookup);
  const requested = [...new Set([...filenames, ...primaryPaths, ...paths])];
  const sources = requested.filter(name => index.files.has('godot-cove/' + name)).slice(0, 5)
    .map(name => pinnedPassage(index, 'godot-cove/' + name, query, 375)).filter(Boolean);
  const identity = 'docs/GAME-IDENTITY.md';
  const architecture = 'docs/ARCHITECTURE.md';
  const guideOrder = new Set([identity, ...guides.filter(path => path !== architecture), architecture]);
  const selectedGuides = [...guideOrder].filter(path => guides.includes(path) && index.files.has(path)).slice(0, 2)
    .map(path => pinnedPassage(index, path, query, 300)).filter(Boolean);
  const routed = [...sources, ...selectedGuides];
  const ranked = { ...index, docs: index.docs.filter(item => item.path !== identity) };
  if (!routed.length) return collectEvidence(ranked, lookup, extra);

  const evidence = collectEvidence(ranked, lookup, [...routed, ...extra]);
  const key = item => `${item.path}:${item.line}`;
  const seen = new Set(routed.map(key));
  const remaining = evidence.filter(item => !item.path || !seen.has(key(item)));
  return [...routed, ...remaining].map((item, i) => ({ ...item, id: `S${i + 1}` }));
}
