import { bestFunctionWindow } from './source-passages.mjs';

const stop = new Set(('about across after again also and are before being could does during each from game ' +
  'have into investigate keep make need only player preserve report scene should show some still test than ' +
  'that the their them then there these they this trace use using verify want was when where which while with would').split(' '));
const words = value => value.replace(/([a-z0-9])([A-Z])/g, '$1 $2').toLowerCase().match(/[a-z0-9]+/g) ?? [];
const stem = word => word.length < 5 ? word : word.replace(/(?:ing|ed|s)$/, '');

// Experimental ranker. It depends only on the report, pinned index and code
// excerpts. It never uses the evaluation fixtures or their expected functions.
export function catalogPassages(db, manifest, note) {
  const files = manifest?.files ?? {};
  const report = [...new Set(words(note).filter(word => word.length >= 2 && !stop.has(word) && /[a-z]/.test(word)).map(stem))].slice(0, 60);
  const frequency = db.prepare("SELECT count(DISTINCT path) AS count FROM chunks WHERE chunks MATCH ? AND path GLOB 'godot-cove/*.gd'");
  const weights = new Map(report.map(term => [term, frequency.get('"' + term + '"*').count])
    .filter(([, count]) => count > 0).map(([term, count]) => [term, 1 + 3 / Math.sqrt(count)])
    .sort((a, b) => b[1] - a[1]).slice(0, 20));
  if (!weights.size) return [];

  const lexical = value => [...new Set(words(value).map(stem))].reduce((sum, term) => sum + (weights.get(term) ?? 0), 0);
  const query = [...weights.keys()].map(term => '"' + term + '"*').join(' OR ');
  const hits = db.prepare("SELECT path,line FROM chunks WHERE chunks MATCH ? AND path GLOB 'godot-cove/*.gd' " +
    'ORDER BY bm25(chunks,1,0,2),path,line LIMIT 100').all(query);
  const keys = new Set();
  const nominees = [];
  function nominate(path, name) {
    const key = path + ':' + name;
    if (keys.has(key)) return;
    keys.add(key);
    nominees.push({ path, name });
  }
  for (const identifier of note.toLowerCase().match(/\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b/g) ?? []) {
    for (const [path, file] of Object.entries(files)) {
      if (file.symbols.some(symbol => symbol.kind === 'func' && symbol.name.toLowerCase() === identifier)) {
        nominate(path, identifier);
      }
    }
  }
  for (const hit of hits) {
    const functions = files[hit.path]?.symbols.filter(symbol => symbol.kind === 'func') ?? [];
    for (const [index, fn] of functions.entries()) {
      if (fn.line <= hit.line + 27 && (functions[index + 1]?.line ?? Infinity) > hit.line) nominate(hit.path, fn.name);
    }
    if (nominees.length >= 45) break;
  }
  const candidates = nominees.slice(0, 45).flatMap(({ path, name }) => {
    const window = bestFunctionWindow(db, manifest, path, name, lexical);
    if (!window) return [];
    return [{ ...window, score: window.score + 1.5 * lexical(name) + lexical(path),
      kind: 'source', reason: 'Indexed function matches the report' }];
  });

  candidates.sort((a, b) => b.score - a.score || a.path.localeCompare(b.path) || a.line - b.line);
  const owner = candidates[0];
  const direct = new Set(files[owner?.path]?.references ?? []);
  // This only promotes already matching functions in a direct resource dependency.
  candidates.sort((a, b) => (b.score + 2 * Number(direct.has(b.path))) - (a.score + 2 * Number(direct.has(a.path))));
  const selected = [];
  for (const item of candidates) {
    if (selected.filter(previous => previous.path === item.path).length >= 2) continue;
    selected.push(item);
    if (selected.length === 5) break;
  }
  return selected;
}
