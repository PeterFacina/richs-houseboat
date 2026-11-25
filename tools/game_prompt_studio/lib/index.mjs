import { lstatSync, readdirSync, readFileSync, realpathSync } from 'node:fs';
import { dirname, join, relative, sep } from 'node:path';
import { now, sha, transaction } from './db.mjs';
import { routedSourcePassages } from './source-passages.mjs';

const allowed = new Set(['gd', 'tscn', 'tres', 'godot', 'gdshader', 'gdshaderinc', 'md', 'txt']);
const rootDocs = ['AGENTS.md', 'GAME GUIDE AND ASSET CREDITS.md', 'START HERE.txt', 'Play Ottawa River.cmd'];
const guide = /^docs\/(?:ARCHITECTURE|systems\/[\w-]+)\.md$/;
const historic = ['Ethan House Boat and UI Update.txt', 'Richs Houseboat - Feature List for Peter.txt'];
const maxBytes = 500_000;
const privateName = /(?:^|[/_.-])(?:\.git|\.godot|node_modules|\.venv|ottawa|build|cache|exports?|secrets?|credentials?|tokens?|passwords?|private|keys?|env)(?:[/_.-]|$)/i;
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

export function candidateFiles(project, exclusions = [], tracked = null) {
  const root = realpathSync(project);
  const files = [];
  const ignored = [];
  const skip = (path, reason) => ignored.push({ path, reason });
  function visit(path, depth) {
    if (!tracked && ignored.length >= 3000) return;
    if (depth > 8 || files.length >= 650) return skip(path, 'scan limit');
    if (exclusions.some(rule => path.toLowerCase() === rule.toLowerCase() ||
        path.toLowerCase().startsWith(rule.toLowerCase() + '/'))) return skip(path, 'configured exclusion');
    if (path !== 'godot-cove/project.godot' && privateName.test(path)) return skip(path, 'generated, private or cache path');
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
    } catch (error) {
      if (tracked) throw error;
      skip(path, 'unreadable');
    }
  }
  const paths = tracked ? tracked.filter(path => rootDocs.includes(path) || guide.test(path) ||
    (path.startsWith('godot-cove/') && allowed.has(path.split('.').at(-1).toLowerCase()))) :
    [...rootDocs, 'docs/ARCHITECTURE.md', 'docs/systems', 'godot-cove'];
  for (const path of paths) visit(path, 0);
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

export function indexedKnowledge(db) {
  const row = db.prepare("SELECT value FROM settings WHERE name='source-knowledge'").get();
  return row ? JSON.parse(row.value) : null;
}

export function scan(db, project, exclusions = [], full = false, knowledge = null) {
  const { root, files, ignored } = candidateFiles(project, exclusions, knowledge?.tracked);
  return transaction(db, () => {
    const old = new Map(db.prepare('SELECT * FROM files').all().map(file => [file.path, file]));
    const kept = new Set();
    const at = now();
    let changed = 0;
    let total = 0;
    for (const file of files) {
      let data;
      try { data = readSource(root, file.path); } catch (error) {
        if (knowledge && !(error instanceof TypeError)) throw error;
        data = null;
      }
      if (!data) {
        ignored.push({ path: file.path, reason: 'unreadable, binary, or credential-like text' });
        continue;
      }
      const source = knowledge?.manifest.files[file.path];
      if (source && data.digest !== source.sha256) throw new Error('Source changed during indexing.');
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
    let removed = 0;
    for (const path of old.keys()) {
      if (kept.has(path)) continue;
      db.prepare('DELETE FROM chunks WHERE path=?').run(path);
      db.prepare('DELETE FROM files WHERE path=?').run(path);
      removed++;
    }
    if (knowledge && (!kept.has('godot-cove/project.godot') || !kept.has('docs/ARCHITECTURE.md'))) {
      throw new Error('The source index is missing required project files.');
    }
    if (knowledge) db.prepare("INSERT OR REPLACE INTO settings VALUES('source-knowledge',?)")
      .run(JSON.stringify(knowledge.manifest));
    else db.prepare("DELETE FROM settings WHERE name='source-knowledge'").run();
    const stats = { at, indexed: kept.size, changed, removed, revision: knowledge?.manifest.revision,
      ignoredCount: ignored.length, ignored: ignored.slice(0, 200) };
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
  const mainScene = db.prepare("SELECT excerpt FROM chunks WHERE path='godot-cove/project.godot' ORDER BY line").all()
    .map(row => /^run\/main_scene="res:\/\/([\w/.\-]+\.tscn)"/m.exec(row.excerpt)).find(Boolean)?.[1];
  if (mainScene && db.prepare('SELECT 1 FROM files WHERE path=?').get('godot-cove/' + mainScene)) {
    find('godot-cove/project.godot', /run\/main_scene="res:\/\//, 'The configured main scene is res://' + mainScene + '.', 'godot-cove/' + mainScene);
  }
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

const terms = text => [...new Set(text.replace(/([a-z])([A-Z])/g, '$1 $2').toLowerCase()
  .split(/[\W_]+/u).filter(word => word.length > 2 && !stop.has(word)))];
const genericSymbols = new Set(['at', 'text', 'layout', 'label', 'update', 'setup', 'show', 'hide']);

export function findEvidence(db, note, focus, budget, { manifest, selection = {}, rankedSources = [], original = false } = {}) {
  const tokens = terms(note + ' ' + focus.join(' ')).slice(0, 32);
  const query = tokens.map(word => '"' + word + '"*').join(' OR ');
  const rows = query ? db.prepare(
    'SELECT path,line,excerpt,bm25(chunks,3,0,1) AS score FROM chunks WHERE chunks MATCH ? ORDER BY score,path,line LIMIT 80'
  ).all(query) : [];
  const result = [];
  let used = 0;
  function add(item, limit) {
    const excerpt = item.excerpt.slice(0, Math.min(limit, budget - used)).trimEnd();
    if (excerpt.length < 24) return;
    result.push({ ...item, id: 'S' + (result.length + 1), excerpt });
    used += excerpt.length;
  }
  for (const path of focus.slice(0, 4)) {
    const row = rows.find(match => match.path === path) ||
      db.prepare('SELECT path,line,excerpt FROM chunks WHERE path=? ORDER BY line LIMIT 1').get(path);
    if (row) add({ ...row, kind: guide.test(path) ? 'guide' : 'source', reason: 'Selected file' }, 850);
  }
  const sourceCount = () => result.filter(item => item.kind === 'source').length;
  const routed = original ? null : rankedSources.length ? { passages: rankedSources, guides: selection.guides ?? [] } :
    routedSourcePassages(db, manifest, note);
  const bestChunk = path => (query && db.prepare(
    'SELECT path,line,excerpt,bm25(chunks,3,0,1) AS score FROM chunks WHERE chunks MATCH ? AND path=? ORDER BY score,line LIMIT 1'
  ).get(query, path)) || db.prepare('SELECT path,line,excerpt FROM chunks WHERE path=? ORDER BY line LIMIT 1').get(path);

  const atLine = db.prepare('SELECT path,line,excerpt FROM chunks WHERE path=? AND line<=? ORDER BY line DESC LIMIT 1');
  const explicitSymbols = new Set(note.toLowerCase().match(/\b[a-z][a-z0-9]*(?:_[a-z0-9]+)+\b/g) ?? []);
  for (const { path, symbols } of selection.matches ?? []) {
    if (sourceCount() >= (routed ? 2 : 3)) break;
    const symbol = original ? symbols[0] : symbols.find(item => routed ? explicitSymbols.has(item.name.toLowerCase()) :
      !genericSymbols.has(item.name.toLowerCase()));
    if (!symbol || result.some(item => item.path === path)) continue;
    const row = atLine.get(path, symbol.line);
    const lines = row?.excerpt.split('\n').slice(symbol.line - row.line);
    if (!lines?.length) continue;
    add({ path, line: symbol.line, title: symbol.name, excerpt: lines.join('\n'), kind: 'source',
      reason: 'Matching ' + symbol.kind + ' declaration' }, 720);
  }

  for (const passage of routed?.passages ?? []) {
    if (sourceCount() >= 7) break;
    if (result.some(item => item.path === passage.path && (item.line === passage.line || item.title === passage.title)
        && Math.abs(item.line - passage.line) < 12)) continue;
    add({ ...passage, kind: 'source', reason: 'Source for a requested behavior' }, 590);
  }

  for (const { number, title, label } of selection.tasks ?? []) {
    add({ kind: 'github', title: label + ' #' + number, excerpt: title, ref: String(number),
      reason: 'Related current GitHub task' }, 200);
  }
  const selected = result.filter(item => item.kind === 'source').map(item => item.path);
  const guides = db.prepare("SELECT path FROM files WHERE path LIKE 'docs/systems/%' ORDER BY path").all().map(row => row.path);
  const proposedGuides = routed ? routed.guides : [...(selection.guides ?? []), ...guides];
  for (const path of new Set(proposedGuides.filter(path => guides.includes(path)))) {
    if (result.filter(item => item.kind === 'guide').length >= 2) break;
    if (result.some(item => item.path === path)) continue;
    const chunks = db.prepare('SELECT path,line,excerpt FROM chunks WHERE path=? ORDER BY line').all(path);
    const linked = chunks.find(row => selected.some(source => row.excerpt.includes('../../' + source + ')')));
    const match = rows.find(row => row.path === path);
    const row = match ?? linked ?? ((routed || selection.guides?.includes(path)) && bestChunk(path));
    if (row) add({ ...row, kind: 'guide', reason: 'Relevant subsystem guide' }, 540);
  }

  if (routed) return result;

  if (manifest) {
    const references = selected.flatMap(path => manifest.files[path]?.references ?? []);
    const matching = references.find(path => rows.some(row => row.path === path) && !result.some(item => item.path === path));
    if (matching && sourceCount() < 5) {
      add({ ...bestChunk(matching), kind: 'source', reason: 'Direct resource reference from a matched file' }, 600);
    }
  }
  const areas = [
    [/\b(?:fish(?:ing)?|rods?|reel|lure|bobber)\b/i, ['fishing_rig.gd', 'fishing.gd']],
    [/\b(?:hands?|grips?|avatar|held|props?)\b/i, ['crew_avatar.gd', 'crew_play.gd']],
    [/\b(?:multiplayer|host|guest|remote|replicat\w*|friends)\b/i, ['river_crew.gd', 'crew_avatar.gd']],
    [original ? /\b(?:rich|face|limb|neck|topology)\b/i : /\b(?:face|limb|neck|topology)\b/i, ['rich_model.gd', 'rich_npc.gd']],
    [/\b(?:cooler|bong|drink|vape|cabin)\b/i, ['cabin_props.gd', 'cabin_life.gd']]
  ];
  for (const [pattern, names] of areas) {
    if (!pattern.test(note)) continue;
    for (const name of names) {
      const path = 'godot-cove/' + name;
      if (sourceCount() >= 5 || result.some(item => item.path === path)) continue;
      const row = bestChunk(path);
      if (row) add({ ...row, kind: 'source', reason: 'Relevant game system' }, 830);
    }
  }
  for (const row of rows) {
    if (sourceCount() >= 5) break;
    if (result.some(item => item.path === row.path) || dirname(row.path) === '.' || guide.test(row.path)) continue;
    add({ ...row, kind: 'source', reason: 'Keyword match' }, 730);
  }
  if (query) {
    for (const row of db.prepare('SELECT title,body,kind,ref,bm25(memory) AS score FROM memory WHERE memory MATCH ? ORDER BY score LIMIT 12').all(query)) {
      const excerpt = row.body.slice(0, 500).trimEnd();
      if (result.some(item => item.kind === row.kind && item.excerpt === excerpt)) continue;
      if (result.filter(item => ['reported', 'imported', 'history'].includes(item.kind)).length >= 3) break;
      const provenance = row.kind === 'imported' ? db.prepare('SELECT b.author,b.label,i.created_at FROM imports i JOIN batches b ON b.id=i.batch_id WHERE i.id=?').get(row.ref) :
        row.kind === 'history' ? db.prepare('SELECT author,status,created_at FROM records WHERE id=?').get(row.ref) :
        db.prepare("SELECT 'Human-provided master brief' AS label,created_at FROM reports WHERE id=?").get(row.ref);
      add({ title: row.title, excerpt: row.body, kind: row.kind, ref: row.ref, score: row.score, provenance, reason: 'Related project memory' }, 500);
    }
  }
  return result;
}
