import { DatabaseSync, backup } from 'node:sqlite';
import { mkdirSync } from 'node:fs';
import { join } from 'node:path';
import { createHash } from 'node:crypto';

export const now = () => new Date().toISOString();
export const sha = value => createHash('sha256').update(value).digest('hex');
export const states = ['draft', 'generated', 'submitted', 'implemented', 'verified', 'rejected', 'superseded', 'needs revision', 'archived'];

const seeds = [
  ['Multiplayer hand visibility', 'Players reported missing remote hand meshes or motion when using a bong, drinking, using a pen or vape, fishing, or using a cooler. Check first-person and remote observer views, grips and attachments. Root cause and current status are unknown.'],
  ['Fishing rod appearance', 'Players reported an unrealistic fishing rod and flickering or stuttering colors. They want the rod to look convincing and be visible to other players. Cause and current status are unknown.'],
  ['Rich character model', 'A player asked for more convincing face topology, limb meshing, and neck and skin-tone continuity. Prior visual references were mentioned. Their availability and current status are unknown.'],
  ['Gameplay validation expectations', 'The team asks for targeted diagnosis, actual in-engine visual verification when feasible, and observations from host and guest when changing multiplayer behavior.']
];

export function openDb(dataDir) {
  mkdirSync(dataDir, { recursive: true });
  const db = new DatabaseSync(join(dataDir, 'studio.sqlite'));
  db.exec('PRAGMA journal_mode=WAL; PRAGMA foreign_keys=ON; PRAGMA busy_timeout=5000;');
  const version = db.prepare('PRAGMA user_version').get().user_version;
  if (version > 2) throw new Error('Update Game Prompt Studio before opening this database.');
  if (version === 0) transaction(db, () => {
    db.exec([
      'CREATE TABLE files (path TEXT PRIMARY KEY, size INTEGER, mtime REAL, hash TEXT, indexed_at TEXT)',
      'CREATE VIRTUAL TABLE chunks USING fts5(path, line UNINDEXED, excerpt, tokenize="unicode61 remove_diacritics 2")',
      'CREATE VIRTUAL TABLE memory USING fts5(title, body, kind UNINDEXED, ref UNINDEXED, tokenize="unicode61 remove_diacritics 2")',
      'CREATE TABLE reports (id INTEGER PRIMARY KEY, title TEXT, body TEXT, created_at TEXT)',
      'CREATE TABLE scans (id INTEGER PRIMARY KEY, created_at TEXT, stats TEXT)',
      "CREATE TABLE records (id INTEGER PRIMARY KEY AUTOINCREMENT, title TEXT, note TEXT, prompt TEXT, model TEXT, tier TEXT, status TEXT, author TEXT, tags TEXT, priority TEXT, outcome TEXT NOT NULL DEFAULT '', evidence TEXT, generation TEXT, created_at TEXT, updated_at TEXT, revision INTEGER DEFAULT 1, parent_id INTEGER REFERENCES records(id))",
      'CREATE TABLE revisions (record_id INTEGER REFERENCES records(id), revision INTEGER, prompt TEXT, status TEXT, outcome TEXT, changed_by TEXT, created_at TEXT, PRIMARY KEY(record_id,revision))',
      'CREATE TABLE batches (id INTEGER PRIMARY KEY AUTOINCREMENT, author TEXT, label TEXT, uploaded_by TEXT, created_at TEXT)',
      'CREATE TABLE imports (id INTEGER PRIMARY KEY AUTOINCREMENT, batch_id INTEGER REFERENCES batches(id), name TEXT, body TEXT, hash TEXT, normalized_hash TEXT UNIQUE, created_at TEXT)',
      'CREATE TABLE users (name TEXT PRIMARY KEY, salt TEXT, digest TEXT, role TEXT)',
      'CREATE TABLE sessions (token_hash TEXT PRIMARY KEY, username TEXT REFERENCES users(name) ON DELETE CASCADE, csrf TEXT, expires INTEGER)',
      'CREATE TABLE settings (name TEXT PRIMARY KEY, value TEXT)',
      'CREATE TABLE audit (id INTEGER PRIMARY KEY, username TEXT, event TEXT, created_at TEXT)'
    ].join(';'));
    for (const [title, body] of seeds) {
      const { lastInsertRowid } = db.prepare('INSERT INTO reports(title,body,created_at) VALUES(?,?,?)').run(title, body, now());
      db.prepare('INSERT INTO memory(title,body,kind,ref) VALUES(?,?,?,?)').run(title, body, 'reported', String(lastInsertRowid));
    }
    db.exec('PRAGMA user_version=1');
  });
  if (version < 2) transaction(db, () => {
    db.exec("CREATE TABLE IF NOT EXISTS attachments (id INTEGER PRIMARY KEY AUTOINCREMENT, record_id INTEGER NOT NULL REFERENCES records(id), name TEXT NOT NULL, description TEXT NOT NULL, origin TEXT NOT NULL, actor TEXT NOT NULL, width INTEGER NOT NULL, height INTEGER NOT NULL, bytes BLOB NOT NULL, created_at TEXT NOT NULL); PRAGMA user_version=2");
  });
  return db;
}

export function transaction(db, action) {
  db.exec('BEGIN IMMEDIATE');
  try {
    const result = action();
    db.exec('COMMIT');
    return result;
  } catch (error) {
    db.exec('ROLLBACK');
    throw error;
  }
}

export function getRecord(db, id) {
  const row = db.prepare('SELECT * FROM records WHERE id=?').get(id);
  return row ? { ...row, evidence: JSON.parse(row.evidence), generation: JSON.parse(row.generation) } : null;
}

export function saveNew(db, data) {
  return transaction(db, () => {
    const time = now();
    const { lastInsertRowid } = db.prepare(
      'INSERT INTO records(title,note,prompt,model,tier,status,author,tags,priority,evidence,generation,created_at,updated_at,parent_id) VALUES (?,?,?,?,?,?,?,?,?,?,?,?,?,?)'
    ).run(data.title, data.note, data.prompt, data.model, data.tier, data.status, data.author,
      data.tags, data.priority, JSON.stringify(data.evidence), JSON.stringify(data.generation), time, time, data.parentId);
    const id = Number(lastInsertRowid);
    db.prepare('INSERT INTO revisions VALUES (?,?,?,?,?,?,?)').run(id, 1, data.prompt, data.status, '', data.author, time);
    refreshMemory(db, id);
    return getRecord(db, id);
  });
}

export function saveEdit(db, before, update, author) {
  return transaction(db, () => {
    const time = now();
    db.prepare('UPDATE records SET prompt=?,status=?,outcome=?,updated_at=?,revision=revision+1 WHERE id=?')
      .run(update.prompt, update.status, update.outcome, time, before.id);
    db.prepare('INSERT INTO revisions VALUES(?,?,?,?,?,?,?)')
      .run(before.id, before.revision + 1, update.prompt, update.status, update.outcome, author, time);
    refreshMemory(db, before.id);
    return getRecord(db, before.id);
  });
}

function refreshMemory(db, id) {
  const { title, note, outcome, status } = getRecord(db, id);
  db.prepare("DELETE FROM memory WHERE kind='history' AND ref=?").run(String(id));
  if (!['archived', 'rejected', 'superseded'].includes(status)) {
    db.prepare('INSERT INTO memory(title,body,kind,ref) VALUES(?,?,?,?)')
      .run(title, 'Request (' + status + '): ' + note + (outcome ? '\nReported outcome: ' + outcome : ''), 'history', String(id));
  }
}

export function recordList(db, filters) {
  const params = [];
  const where = [];
  for (const key of ['status', 'author', 'tags']) {
    const value = filters.get(key)?.slice(0, 150).trim();
    if (!value) continue;
    where.push(key === 'tags' ? 'instr(lower(tags),lower(?))' : key + ' = ?');
    params.push(value);
  }
  const query = filters.get('q')?.slice(0, 200).trim();
  if (query) {
    where.push('instr(lower(title || char(10) || note || char(10) || prompt || char(10) || outcome),lower(?))');
    params.push(query);
  }
  for (const [key, operator] of [['from', '>='], ['to', '<=']]) {
    const date = filters.get(key);
    if (/^\d{4}-\d{2}-\d{2}$/.test(date ?? '')) {
      where.push('substr(created_at,1,10)' + operator + '?');
      params.push(date);
    }
  }
  const offset = Math.max(0, Math.min(100000, Number.parseInt(filters.get('offset'), 10) || 0));
  return db.prepare('SELECT id,title,model,status,author,tags,priority,created_at,updated_at FROM records ' +
    (where.length ? 'WHERE ' + where.join(' AND ') : '') + ' ORDER BY updated_at DESC,id DESC LIMIT 101 OFFSET ?').all(...params, offset);
}

export function importPreview(db, files) {
  const seen = new Set();
  return files.map(({ name, body }) => {
    const normalized = sha(body.normalize('NFKC').trim().replace(/\s+/gu, ' '));
    const duplicate = seen.has(normalized) || Boolean(db.prepare('SELECT id FROM imports WHERE normalized_hash=?').get(normalized));
    seen.add(normalized);
    return { name, body, normalized, duplicate };
  });
}

export function importBatch(db, { files, author, label, uploader }) {
  return transaction(db, () => {
    const accepted = importPreview(db, files).filter(file => !file.duplicate);
    if (!accepted.length) return { id: null, imported: 0, duplicates: files.length };
    const at = now();
    const id = Number(db.prepare('INSERT INTO batches(author,label,uploaded_by,created_at) VALUES(?,?,?,?)')
      .run(author, label, uploader, at).lastInsertRowid);
    for (const file of accepted) {
      const entry = db.prepare('INSERT INTO imports(batch_id,name,body,hash,normalized_hash,created_at) VALUES(?,?,?,?,?,?)')
        .run(id, file.name, file.body, sha(file.body), file.normalized, at);
      db.prepare('INSERT INTO memory(title,body,kind,ref) VALUES(?,?,?,?)')
        .run(file.name, file.body, 'imported', String(entry.lastInsertRowid));
    }
    return { id, imported: accepted.length, duplicates: files.length - accepted.length };
  });
}

export function removeBatch(db, id) {
  return transaction(db, () => {
    db.prepare("DELETE FROM memory WHERE kind='imported' AND ref IN (SELECT CAST(id AS TEXT) FROM imports WHERE batch_id=?)").run(id);
    db.prepare('DELETE FROM imports WHERE batch_id=?').run(id);
    return db.prepare('DELETE FROM batches WHERE id=?').run(id).changes;
  });
}

export function audit(db, user, event) {
  db.prepare('INSERT INTO audit(username,event,created_at) VALUES(?,?,?)').run(user, event, now());
}

export async function snapshot(db, dataDir) {
  const destination = join(dataDir, 'backups');
  mkdirSync(destination, { recursive: true });
  const name = 'studio-' + now().replace(/[^0-9]/g, '') + '.sqlite';
  await backup(db, join(destination, name));
  return { name };
}
