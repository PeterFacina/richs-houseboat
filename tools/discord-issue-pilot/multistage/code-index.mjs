import { createHash } from 'node:crypto';
import { readFileSync, lstatSync, realpathSync } from 'node:fs';
import { isAbsolute, join, relative, sep } from 'node:path';

const stop = new Set(('a about after all also an and any are as at be before between both but by can check code could do does ' +
  'for from func game get had has have how i if in is it its keep let make may must new no not of on one only or our out ' +
  'pass player report return see should so some still test than that the their them then there these they this to true try ' +
  'use using verify want was we were when where whether which while who will with would you your var void self').split(' '));
const word = /[a-z][a-z0-9]*/g;
const sourcePath = /^godot-cove\/(?:[\w .-]+\/)*[\w .-]+\.(?:gd|tscn|tres|gdshader|gdshaderinc|godot|cs)$/i;
const guidePath = /^docs\/(?:ARCHITECTURE\.md|systems\/[\w-]+\.md)$/i;
const digest = bytes => createHash('sha256').update(bytes).digest('hex');
const concepts = [['fence', 'rail', 'railing', 'handrail', 'barrier', 'picket'],
  ['helm', 'steering', 'steer', 'wheel'], ['glitch', 'flicker', 'jitter'], ['attach', 'mount', 'bind']];

export function terms(text) {
  return (text.replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase().match(word) ?? [])
    .filter(term => term.length >= 2 && !stop.has(term))
    .map(term => term.length > 4 ? term.replace(/(?:ing|ed|(?<!s)s)$/, '') : term);
}

function pinnedRead(root, path) {
  const absolute = join(root, path);
  if (!lstatSync(absolute).isFile()) throw new Error(`Expected a regular indexed file: ${path}`);
  const resolved = realpathSync(absolute);
  const inside = relative(root, resolved);
  if (isAbsolute(inside) || inside === '..' || inside.startsWith('..' + sep)) throw new Error(`Indexed path escapes its root: ${path}`);
  const bytes = readFileSync(resolved);
  if (bytes.length > 500_000) throw new Error(`Indexed file exceeds size limit: ${path}`);
  return { hash: digest(bytes), lines: new TextDecoder('utf-8', { fatal: true }).decode(bytes).split(/\r?\n/) };
}

function markers(lines, symbols, path) {
  const declarations = symbols.filter(item => item.kind === 'func' || item.kind === 'signal' || item.kind.startsWith('class'));
  const known = new Set(declarations.map(item => item.line));
  for (const [index, line] of lines.entries()) {
    const named = /^(?:static )?(const|var|enum)\s+(\w+)|^\[(node|ext_resource|sub_resource)[^\]]*\b(?:name|id)="([^"\r\n]+)"/.exec(line);
    if (named && !known.has(index + 1)) declarations.push({ kind: named[1] ?? named[3], name: named[2] ?? named[4], line: index + 1 });
  }
  if (!declarations.length) return [{ kind: 'file', name: path.split('/').pop(), line: 1 }];
  return declarations.sort((a, b) => a.line - b.line);
}

function sourceEnd(lines, declarations, i) {
  const marker = declarations[i];
  const boundary = declarations[i + 1]?.line ?? lines.length + 1;
  if (marker.kind === 'func') {
    // An annotation or another top-level statement belongs to the next declaration.
    for (let n = marker.line; n < boundary - 1; n++) {
      if (/^(?:@|const\b|var\b|static\b|func\b|signal\b|class\b)/.test(lines[n])) return n + 1;
    }
  }
  return boundary;
}

function excerptLines(lines, start, end) {
  const excerpt = lines.slice(start - 1, end - 1);
  while (excerpt.length && !excerpt.at(-1).trim()) excerpt.pop();
  return excerpt;
}

// Resolve only the curated lesson anchors. Dashboard reads do not build a second retrieval index.
export function pinnedFunctions(root, manifest, anchors) {
  root = realpathSync(root);
  const files = new Map();
  for (const path of new Set(anchors.map(item => item.path))) {
    const entry = manifest.files[path];
    if (!entry || !sourcePath.test(path)) continue;
    let file;
    try { file = pinnedRead(root, path); } catch { continue; }
    if (file.hash !== entry.sha256) continue;
    const names = new Set(anchors.filter(item => item.path === path).map(item => item.name));
    const declarations = markers(file.lines, entry.symbols, path);
    const entries = declarations.flatMap((marker, i) => marker.kind === 'func' && names.has(marker.name) ? [
      { name: marker.name, symbolKind: 'func', lines: excerptLines(file.lines, marker.line, sourceEnd(file.lines, declarations, i)) },
    ] : []);
    files.set(path, { entries });
  }
  return { files };
}

function lexicalCode(text) {
  return text.replace(/"(?:[^"\\]|\\.)*"|'(?:[^'\\]|\\.)*'|#[^\n]*/g, ' ');
}

export function buildCodeIndex(root, manifest, tracked) {
  root = realpathSync(root);
  const files = new Map();
  const entries = [];
  const byName = new Map();
  const docs = [];
  const add = (file, marker, end, kind) => {
    const lines = excerptLines(file.lines, marker.line, end);
    const item = { ...marker, symbolKind: marker.kind, id: `F${entries.length + 1}`, path: file.path, kind, lines, links: new Map() };
    item.nameTerms = new Set(terms(item.name));
    item.pathTerms = new Set(terms(item.path.replace(/^(?:godot-cove|docs)\//, '').replace(/\.[^.]+$/, '')));
    item.body = new Map();
    for (const term of terms(lines.join('\n'))) item.body.set(term, (item.body.get(term) ?? 0) + 1);
    item.features = new Set([...item.nameTerms, ...item.pathTerms, ...item.body.keys()]);
    entries.push(item);
    file.entries.push(item);
    if (kind === 'source') {
      if (!byName.has(item.name)) byName.set(item.name, []);
      byName.get(item.name).push(item);
    } else docs.push(item);
    return item;
  };

  for (const [path, entry] of Object.entries(manifest.files)) {
    if (!sourcePath.test(path)) continue;
    const file = { ...pinnedRead(root, path), path, entries: [], links: new Map() };
    if (file.hash !== entry.sha256) throw new Error(`Source hash changed after indexing: ${path}`);
    files.set(path, file);
    const declarations = markers(file.lines, entry.symbols, path);
    for (const [i, marker] of declarations.entries()) {
      add(file, marker, sourceEnd(file.lines, declarations, i), 'source');
    }
  }

  for (const path of tracked.filter(path => guidePath.test(path))) {
    const file = { ...pinnedRead(root, path), path, entries: [], links: new Map() };
    files.set(path, file);
    const headings = file.lines.flatMap((text, i) => text.startsWith('#') ? [{ name: text.replace(/^#+\s*/, ''), line: i + 1 }] : []);
    headings.forEach((heading, i) => add(file, heading, headings[i + 1]?.line ?? file.lines.length + 1, 'guide'));
  }

  const pairFiles = (from, to, relation) => {
    if (from === to || !files.has(from) || !files.has(to)) return false;
    const alreadyLinked = files.get(from).links.has(to);
    if (!alreadyLinked) files.get(from).links.set(to, relation);
    if (!files.get(to).links.has(from)) files.get(to).links.set(from, `reverse ${relation}`);
    return !alreadyLinked;
  };
  for (const [path, file] of Object.entries(manifest.files)) {
    for (const target of file.references) pairFiles(path, target, /\.(tscn|tres)$/.test(path) ? 'scene resource' : 'literal resource');
  }
  for (const item of docs) {
    for (const match of item.lines.join('\n').matchAll(/(?:\.\.\/)+(godot-cove\/[\w/.-]+)/g)) pairFiles(item.path, match[1], 'documented source');
  }

  let calls = 0;
  for (const [path, file] of files) {
    if (!path.endsWith('.gd')) continue;
    const aliases = new Map([...file.lines.join('\n').matchAll(/^const\s+(\w+)\s*:?=\s*preload\(["']res:\/\/([^"']+)/gm)]
      .map(match => [match[1], 'godot-cove/' + match[2]]));
    for (const item of file.entries.filter(entry => entry.symbolKind === 'func')) {
      for (const [, receiver, name] of lexicalCode(item.lines.slice(1).join('\n')).matchAll(/\b(?:(\w+)\s*\.\s*)?(\w+)\s*\(/g)) {
        const targets = byName.get(name)?.filter(candidate => candidate.symbolKind === 'func') ?? [];
        const explicitPath = receiver && receiver !== 'self' ? aliases.get(receiver) : path;
        const direct = explicitPath && targets.find(target => target.path === explicitPath);
        const target = direct || (receiver && targets.length === 1 ? targets[0] : null);
        if (!target || target === item || item.links.has(target.id)) continue;
        item.links.set(target.id, direct ? 'lexical call' : 'unique-name call hint');
        if (!target.links.has(item.id)) target.links.set(item.id, direct ? 'lexical caller' : 'unique-name caller hint');
        calls++;
      }
    }
  }

  const byId = new Map(entries.map(item => [item.id, item]));
  const postings = new Map();
  for (const item of entries) for (const term of item.features) {
    if (!postings.has(term)) postings.set(term, []);
    postings.get(term).push(item);
  }
  const idf = term => Math.log1p((entries.length + .5) / ((postings.get(term)?.length ?? entries.length) + .5));

  function query(text) {
    const tokens = [...new Set(terms(text))].slice(0, 80);
    const weights = new Map(tokens.filter(term => postings.has(term)).map(term => [term, idf(term)]));
    const associated = new Map();
    for (const [term, weight] of weights) {
      const context = postings.get(term);
      if (context.length < 2 || context.length > 140) continue;
      const counts = new Map();
      for (const entry of context) for (const neighbor of new Set([...entry.nameTerms, ...entry.pathTerms])) {
        if (!weights.has(neighbor)) counts.set(neighbor, (counts.get(neighbor) ?? 0) + 1);
      }
      for (const [name, count] of counts) {
        if (count < 2) continue;
        const similarity = count / Math.sqrt(context.length * postings.get(name).length);
        if (similarity >= .18) associated.set(name, (associated.get(name) ?? 0) + similarity * Math.sqrt(weight));
      }
    }
    const semantic = new Map([...associated].sort((a, b) => b[1] - a[1]).slice(0, 12)
      .map(([name, weight]) => [name, Math.min(1.4, weight)]));
    const focus = new Set();
    const subject = new Set(terms(text.trim().split('\n', 1)[0]));
    for (const concept of concepts.map(group => terms(group.join(' ')))) {
      if (!concept.some(term => tokens.includes(term))) continue;
      for (const term of concept) {
        if (!weights.has(term) && postings.has(term)) weights.set(term, Math.min(idf(term) * .58, 2.4));
        if (concept.some(part => subject.has(part))) focus.add(term);
      }
    }
    return { tokens, weights, semantic, focus };
  }

  function rank(q, items = entries) {
    const sum = (weights, predicate) => [...weights].reduce((total, [term, weight]) => total + (predicate(term) ? weight : 0), 0);
    return items.map(item => {
      const name = sum(q.weights, term => item.nameTerms.has(term));
      const path = sum(q.weights, term => item.pathTerms.has(term));
      const body = sum(q.weights, term => item.body.has(term));
      const semantic = sum(q.semantic, term => item.nameTerms.has(term) || item.pathTerms.has(term) || item.body.has(term));
      const diversity = Math.max(1, Math.log2(2 + item.body.size) / 4.6);
      const symbol = item.kind === 'guide' || item.symbolKind === 'func';
      const verification = /(?:^|\/)(?:test_|verify_)/.test(item.path);
      const score = (1.05 * name + .7 * path + 1.32 * body / diversity + 1.3 * semantic) *
        (symbol ? 1 : .7) * (verification ? .55 : 1);
      return { item, score, lexical: name + path + body };
    }).filter(hit => hit.score > 0).sort((a, b) => b.score - a.score || a.item.id.localeCompare(b.item.id, 'en', { numeric: true }));
  }

  function verify(evidence) {
    const verified = new Set();
    for (const entry of evidence) {
      if (!entry.path || verified.has(entry.path)) continue;
      const pinned = files.get(entry.path);
      if (!pinned) throw new Error(`Evidence path is outside the index: ${entry.path}`);
      if (pinnedRead(root, entry.path).hash !== pinned.hash) throw new Error(`Evidence changed during retrieval: ${entry.path}`);
      verified.add(entry.path);
    }
  }

  const stats = { files: files.size, symbols: entries.length - docs.length, guides: docs.length, calls,
    fileLinks: [...files.values()].reduce((n, file) => n + file.links.size, 0) / 2 };
  return { files, entries, docs, byId, query, rank, verify, stats };
}
