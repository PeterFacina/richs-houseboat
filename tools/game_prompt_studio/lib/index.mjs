import { lstatSync, readdirSync, readFileSync, realpathSync } from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';
import { now, sha, transaction } from './db.mjs';

const allowed = new Set(['gd', 'tscn', 'tres', 'godot', 'gdshader', 'gdshaderinc', 'md', 'txt']);
const rootDocs = ['AGENTS.md', 'GAME GUIDE AND ASSET CREDITS.md', 'START HERE.txt', 'Play Ottawa River.cmd'];
const historic = ['Ethan House Boat and UI Update.txt', 'Richs Houseboat - Feature List for Peter.txt'];
const maxBytes = 500_000;
const privateName = /(?:^|[/_.-])(?:\.git|\.godot|node_modules|\.venv|build|cache|exports?|secrets?|credentials?|tokens?|passwords?|private|keys?|env)(?:[/_.-]|$)/i;
const sensitive = /-----BEGIN [^\n]{0,40}PRIVATE KEY-----|(?:^|\n)\s*(?:export\s+)?(?:[A-Z0-9_]*(?:PASSWORD|API_KEY|ACCESS_TOKEN|SECRET_KEY)|SECRET)\s*[:=]\s*["']?[A-Za-z0-9_+/=-]{8,}/i;
const stop = new Set('a an and are as at be but by can do for from get had has have how i in is it its me my of on or our so than that the their them then there these they this to use was we were what when where which who will with would you your fix make want need game should must'.split(' '));

function safeStat(root, path) {
  const absolute = join(root, path);
  let status;
  try { status = lstatSync(absolute); } catch (error) {
    if (error.code === 'ENOENT') return null;
    throw error;
  }
  if (status.isSymbolicLink()) return null;
  const rel = relative(root, realpathSync(absolute));
  return rel === '..' || rel.startsWith('..' + sep) ? null : status;
}

export function candidateFiles(project, exclusions = []) {
  const root = realpathSync(project);
  const files = [];
  const ignored = [];
  const skip = (path, reason) => ignored.push({ path, reason });
  function visit(path, depth) {
    if (ignored.length >= 3000) return;
    if (depth > 8 || files.length >= 650) return skip(path, 'scan limit');
    if (exclusions.some(rule => path.toLowerCase() === rule.toLowerCase() ||
        path.toLowerCase().startsWith(rule.toLowerCase() + '/'))) return skip(path, 'configured exclusion');
    if (path.toLowerCase() === 'godot-cove/ottawa' ||
        (path !== 'godot-cove/project.godot' && privateName.test(path))) return skip(path, 'generated, private or cache path');
    try {
      const status = safeStat(root, path);
      if (!status) return skip(path, 'missing or linked path');
      if (status.isDirectory()) {
        for (const entry of readdirSync(join(root, path)).sort()) visit(path + '/' + entry, depth + 1);
        return;
      }
      if (!status.isFile()) return skip(path, 'special file');
      if (!rootDocs.includes(path) && !allowed.has(path.split('.').at(-1).toLowerCase())) return skip(path, 'file type');
      if (status.size > maxBytes) return skip(path, 'larger than 500 KB');
      files.push({ path, size: status.size, mtime: status.mtimeMs });
    } catch {
      skip(path, 'unreadable');
    }
  }
  for (const path of [...rootDocs, 'godot-cove']) visit(path, 0);
  return { root, files, ignored };
}

function readSource(root, path) {
  const status = safeStat(root, path);
  if (!status?.isFile() || status.size > maxBytes) return null;
  const bytes = readFileSync(join(root, path));
  if (bytes.length > maxBytes || bytes.includes(0)) return null;
  const text = new TextDecoder('utf-8', { fatal: true }).decode(bytes);
  if (sensitive.test(text)) return null;
  return { text, digest: sha(bytes) };
}

function storeChunks(db, path, text) {
  const rows = text.split(/\r?\n/);
  const insert = db.prepare('INSERT INTO chunks(path,line,excerpt) VALUES(?,?,?)');
  for (let line = 0; line < rows.length; line += 22) {
    const excerpt = rows.slice(line, line + 28).map(value => value.slice(0, 350)).join('\n').slice(0, 2900);
    if (excerpt.trim()) insert.run(path, line + 1, excerpt);
  }
}

export function scan(db, project, exclusions = [], full = false) {
  const { root, files, ignored } = candidateFiles(project, exclusions);
  return transaction(db, () => {
    const old = new Map(db.prepare('SELECT * FROM files').all().map(file => [file.path, file]));
    const kept = new Set();
    const at = now();
    let changed = 0;
    let total = 0;
    for (const file of files) {
      let data;
      try { data = readSource(root, file.path); } catch { data = null; }
      if (!data) {
        ignored.push({ path: file.path, reason: 'unreadable, binary, or credential-like text' });
        continue;
      }
      total += file.size;
      if (total > 18_000_000) {
        ignored.push({ path: file.path, reason: 'scan byte budget' });
        continue;
      }
      kept.add(file.path);
      if (!full && old.get(file.path)?.hash === data.digest) {
        db.prepare('UPDATE files SET size=?,mtime=? WHERE path=?').run(file.size, file.mtime, file.path);
        continue;
      }
      db.prepare('DELETE FROM chunks WHERE path=?').run(file.path);
      db.prepare('INSERT OR REPLACE INTO files VALUES(?,?,?,?,?)').run(file.path, file.size, file.mtime, data.digest, at);
      storeChunks(db, file.path, data.text);
      changed++;
    }
    for (const path of old.keys()) {
      if (kept.has(path)) continue;
      db.prepare('DELETE FROM chunks WHERE path=?').run(path);
      db.prepare('DELETE FROM files WHERE path=?').run(path);
    }
    const stats = { at, indexed: kept.size, changed, ignoredCount: ignored.length, ignored: ignored.slice(0, 200) };
    db.prepare('INSERT INTO scans(created_at,stats) VALUES(?,?)').run(at, JSON.stringify(stats));
    db.exec('DELETE FROM scans WHERE id NOT IN (SELECT id FROM scans ORDER BY id DESC LIMIT 12)');
    return stats;
  });
}

export function recentScan(db) {
  const row = db.prepare('SELECT stats FROM scans ORDER BY id DESC LIMIT 1').get();
  return row ? JSON.parse(row.stats) : null;
}

export function projectProfile(db) {
  const facts = [];
  const find = (path, pattern, fact, referencedPath) => {
    for (const row of db.prepare('SELECT line,excerpt FROM chunks WHERE path=? ORDER BY line').all(path)) {
      const match = pattern.exec(row.excerpt);
      if (!match) continue;
      const line = Number(row.line) + row.excerpt.slice(0, match.index).split('\n').length - 1;
      const indexedReference = referencedPath && db.prepare("SELECT path FROM files WHERE path=?").get(referencedPath);
      facts.push({ fact, path, line, ...(indexedReference ? { referencedPath } : {}) });
      break;
    }
  };
  find('godot-cove/project.godot', /config\/name="Rich.s Houseboat/, 'The Godot project identifies itself as Rich’s Houseboat — Ottawa River.');
  find('godot-cove/project.godot', /run\/main_scene="res:\/\/fishing\.tscn"/, 'The configured main scene is res://fishing.tscn.', 'godot-cove/fishing.tscn');
  find('godot-cove/project.godot', /renderer\/rendering_method="gl_compatibility"/, 'The project config selects the Compatibility renderer.');
  find('Play Ottawa River.cmd', /Godot_v4\.7\.2-stable_win64\.exe/, 'The launcher specifies the bundled Godot 4.7.2 executable.');
  return facts;
}

export function discovered(project, exclusions = []) {
  const root = realpathSync(project);
  return historic.flatMap(name => {
    if (exclusions.some(rule => name.toLowerCase() === rule.toLowerCase())) return [];
    try {
      const data = readSource(root, name);
      return data ? [{ name, body: data.text }] : [];
    } catch { return []; }
  });
}

function searchTerms(text) {
  return [...new Set(text.toLowerCase()
    .split(/[\W_]+/u).filter(word => word.length > 2 && !stop.has(word)))].slice(0, 24);
}

function searchQuery(terms) {
  return terms.map(word => '"' + word + '"*').join(' OR ');
}

function focusExcerpt(row, terms, limit) {
  const lines = row.excerpt.split('\n');
  const matches = lines.map(line => {
    const words = line.toLowerCase().split(/[\W_]+/u);
    return terms.filter(term => words.some(word => word.startsWith(term)));
  });
  let best = { excerpt: '', distinct: -1, hits: -1, line: row.line };
  for (let start = 0; start < lines.length; start++) {
    let excerpt = '';
    const distinct = new Set();
    let hits = 0;
    for (let end = start; end < lines.length; end++) {
      if (excerpt.length + lines[end].length + 1 > limit) break;
      excerpt += lines[end] + '\n';
      for (const term of matches[end]) distinct.add(term);
      hits += matches[end].length;
    }
    if (distinct.size > best.distinct || (distinct.size === best.distinct && hits > best.hits)) {
      best = { excerpt, distinct: distinct.size, hits, line: row.line + start };
    }
  }
  return { ...row, line: best.line, excerpt: best.excerpt };
}

export function findEvidence(db, note, focus, budget) {
  const query = searchQuery(searchTerms(note + ' ' + focus.join(' ')));
  const reportTerms = searchTerms(note);
  const reportQuery = searchQuery(reportTerms);
  const rows = query ? db.prepare(
    'SELECT path,line,excerpt,bm25(chunks,3,0,1) AS score FROM chunks WHERE chunks MATCH ? ORDER BY score,path,line LIMIT 80'
  ).all(query) : [];
  const result = [];
  let used = 0;
  function add(item, limit) {
    const excerpt = item.excerpt.slice(0, limit).trimEnd();
    if (!excerpt.trim() || used + excerpt.length > budget) return;
    result.push({ ...item, id: 'S' + (result.length + 1), excerpt });
    used += excerpt.length;
  }
  for (const path of focus.slice(0, 4)) {
    const match = reportQuery && db.prepare(
      'SELECT path,line,excerpt FROM chunks WHERE chunks MATCH ? AND path=? ORDER BY bm25(chunks,0,0,1),line LIMIT 1'
    ).get(reportQuery, path);
    const row = match ||
      db.prepare('SELECT path,line,excerpt FROM chunks WHERE path=? ORDER BY line LIMIT 1').get(path);
    if (row) add({ ...focusExcerpt(row, reportTerms, 900), kind: 'source', reason: 'Selected file' }, 900);
  }
  const sourceCount = () => result.filter(item => item.kind === 'source').length;
  const areas = [
    [/\b(?:fish(?:ing)?|rods?|reel|lure|bobber)\b/i, ['fishing_rig.gd', 'fishing.gd']],
    [/\b(?:hands?|grips?|avatar|held|props?)\b/i, ['crew_avatar.gd', 'crew_play.gd']],
    [/\b(?:multiplayer|host|guest|remote|replicat\w*|friends)\b/i, ['river_crew.gd', 'crew_avatar.gd']],
    [/\b(?:rich|face|limb|neck|topology)\b/i, ['rich_model.gd', 'rich_npc.gd']],
    [/\b(?:cooler|bong|drink|vape|cabin)\b/i, ['cabin_props.gd', 'cabin_life.gd']]
  ];
  for (const [pattern, names] of areas) {
    if (!pattern.test(note)) continue;
    for (const name of names) {
      const path = 'godot-cove/' + name;
      if (sourceCount() >= 5 || result.some(item => item.path === path)) continue;
      const match = query && db.prepare(
        'SELECT path,line,excerpt,bm25(chunks,3,0,1) AS score FROM chunks WHERE chunks MATCH ? AND path=? ORDER BY score,line LIMIT 1'
      ).get(query, path);
      const row = match || db.prepare('SELECT path,line,excerpt FROM chunks WHERE path=? ORDER BY line LIMIT 1').get(path);
      if (row) add({ ...row, kind: 'source', reason: 'Relevant game system' }, 830);
    }
  }
  for (const row of rows) {
    if (sourceCount() >= 5) break;
    if (result.some(item => item.path === row.path) || dirname(row.path) === '.') continue;
    add({ ...row, kind: 'source', reason: 'Keyword match' }, 730);
  }
  if (query) {
    for (const row of db.prepare('SELECT title,body,kind,ref,bm25(memory) AS score FROM memory WHERE memory MATCH ? ORDER BY score LIMIT 12').all(query)) {
      const excerpt = row.body.slice(0, 500).trimEnd();
      if (result.some(item => item.kind === row.kind && item.excerpt === excerpt)) continue;
      if (result.filter(item => item.kind !== 'source').length >= 4) break;
      const provenance = row.kind === 'imported' ? db.prepare('SELECT b.author,b.label,i.created_at FROM imports i JOIN batches b ON b.id=i.batch_id WHERE i.id=?').get(row.ref) :
        row.kind === 'history' ? db.prepare('SELECT author,status,created_at FROM records WHERE id=?').get(row.ref) :
        db.prepare("SELECT 'Human-provided master brief' AS label,created_at FROM reports WHERE id=?").get(row.ref);
      add({ title: row.title, excerpt: row.body, kind: row.kind, ref: row.ref, score: row.score, provenance, reason: 'Related project memory' }, 500);
    }
  }
  return result;
}
