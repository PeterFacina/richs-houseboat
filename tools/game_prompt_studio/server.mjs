import { spawn } from 'node:child_process';
import { createServer } from 'node:http';
import { readFileSync } from 'node:fs';
import { join, resolve } from 'node:path';
import { randomUUID } from 'node:crypto';
import { fileURLToPath } from 'node:url';
import { appDir, config, dataDir, getSettings, modelSettings, projectDir } from './lib/config.mjs';
import { audit, getRecord, importBatch, importPreview, now, openDb, recordList, removeBatch, saveEdit, saveNew, snapshot, states } from './lib/db.mjs';
import { sanitizePng } from './lib/images.mjs';
import { createAuth } from './lib/auth.mjs';
import { discovered, findEvidence, projectProfile, recentScan, scan } from './lib/index.mjs';
import { buildDraft, checkExport, createOllama, exportName, tiers } from './lib/model.mjs';

class HttpError extends Error {
  constructor(status, message, findings) {
    super(message);
    this.status = status;
    this.findings = findings;
  }
}

function json(res, status, value, headers = {}) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8', ...headers });
  res.end(JSON.stringify(value));
}

async function body(req, limit = 100_000) {
  if (req.headers['content-type']?.split(';')[0].trim() !== 'application/json') throw new HttpError(415, 'Use JSON for this request.');
  if (Number(req.headers['content-length']) > limit) throw new HttpError(413, 'Request is too large.');
  const parts = [];
  let size = 0;
  for await (const part of req.iterator({ destroyOnReturn: false })) {
    size += part.length;
    if (size > limit) {
      req.resume();
      throw new HttpError(413, 'Request is too large.');
    }
    parts.push(part);
  }
  try {
    const value = JSON.parse(new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(parts)));
    if (!value || Array.isArray(value) || typeof value !== 'object') throw new Error();
    return value;
  } catch { throw new HttpError(400, 'Request must contain a valid JSON object.'); }
}

function text(value, label, limit, required = false) {
  if (value == null && !required) return '';
  if (typeof value !== 'string' || value.length > limit || value.includes('\0') || (required && !value.trim())) {
    throw new HttpError(400, label + ' must contain ' + (required ? '1–' : 'at most ') + limit + ' characters.');
  }
  return value;
}

function cleanInput(value, settings, db) {
  const note = text(value.note, 'Notes', 6500, true);
  const title = text(value.title, 'Title', 120).trim().replace(/[\r\n\t]+/g, ' ') ||
    note.trim().split(/\r?\n/)[0].slice(0, 78);
  const tier = value.tier ?? settings.tier;
  if (!Object.hasOwn(tiers, tier)) throw new HttpError(400, 'Choose a valid detail level.');
  const focus = value.focus ?? [];
  if (!Array.isArray(focus) || focus.length > 4 ||
      focus.some(path => typeof path !== 'string' || !db.prepare('SELECT path FROM files WHERE path=?').get(path))) {
    throw new HttpError(400, 'Select up to four indexed files.');
  }
  const parentId = value.parentId == null ? null : Number(value.parentId);
  if (parentId !== null && (!Number.isSafeInteger(parentId) || !getRecord(db, parentId))) throw new HttpError(400, 'The prior record could not be found.');
  const priority = value.priority ?? 'Normal';
  if (!['Low', 'Normal', 'High'].includes(priority)) throw new HttpError(400, 'Choose a valid priority.');
  return { note, title, tier, focus, parentId, priority, author: text(value.author, 'Author', 80).trim(),
    tags: text(value.tags, 'Tags', 160).trim() };
}

function importFiles(value) {
  if (!Array.isArray(value) || !value.length || value.length > 16) throw new HttpError(400, 'Select one to sixteen history files.');
  return value.map(item => {
    const name = text(item?.name, 'Filename', 180, true);
    if (!/^[^\\/:<>"|?*\p{Cc}]+\.(?:txt|md)$/iu.test(name)) throw new HttpError(400, 'Import named UTF-8 .txt or .md files.');
    return { name, body: text(item.body, 'File contents', 60_000, true) };
  });
}

const staticFiles = new Map([
  ['/', ['index.html', 'text/html; charset=utf-8']],
  ['/app.css', ['app.css', 'text/css; charset=utf-8']],
  ['/app.js', ['app.js', 'text/javascript; charset=utf-8']]
]);

export function createStudio({ options = config(), storage = dataDir, project = projectDir, provider } = {}) {
  const db = openDb(storage);
  const privateMode = Boolean(options.privateOrigin);
  const tailscaleMode = privateMode && options.tailscaleUsers != null;
  const passwordMode = privateMode && !tailscaleMode;
  if (passwordMode && !db.prepare("SELECT name FROM users WHERE role='admin' LIMIT 1").get()) {
    db.close();
    throw new Error('Create a team admin with team_windows.ps1 before enabling private mode.');
  }
  const auth = createAuth(db, privateMode, tailscaleMode ? options.tailscaleUsers : null);
  const ollama = provider ?? createOllama(options.ollamaPort);
  const jobs = new Map();
  let active = null;
  let scheduledScan;

  function get(id) {
    const record = getRecord(db, id);
    if (!record) throw new HttpError(404, 'Prompt not found.');
    return record;
  }

  function validateExport(prompt, evidence, facts) {
    if (!prompt.trim()) throw new HttpError(422, 'Enter prompt text before exporting.');
    const findings = checkExport(prompt, evidence, facts);
    if (findings.length) throw new HttpError(422, 'Resolve the export checks before copying or downloading.', findings);
  }

  function startJob(input, user, settings) {
    if (active) throw new HttpError(409, 'The local model is busy. Wait for the current generation to finish.');
    for (const [id, entry] of jobs) if (entry.finished && Date.now() - entry.finished > 900_000) jobs.delete(id);
    if (jobs.size >= 100) jobs.delete(jobs.keys().next().value);
    const controller = new AbortController();
    const job = { id: randomUUID(), owner: user.name, status: 'working', controller };
    jobs.set(job.id, job);
    active = job;
    const facts = projectProfile(db);
    const evidence = findEvidence(db, input.note, input.focus, settings.context === 4096 ? 3400 : 5800);
    if (input.parentId) {
      const attachments = db.prepare("SELECT id,name,description,origin,actor,created_at FROM attachments WHERE record_id=? AND description<>'' ORDER BY id LIMIT 4").all(input.parentId);
      for (const image of attachments) {
        evidence.push({ id: 'S' + (evidence.length + 1), kind: 'attachment', title: image.name,
          excerpt: image.description.slice(0, 500), ref: String(image.id), reason: 'Human screenshot description',
          provenance: { author: image.actor, label: image.origin, created_at: image.created_at } });
      }
    }
    const author = privateMode ? user.name : input.author || user.name;
    void (async () => {
      try {
        const { payload, metrics } = await ollama.generate({ input, facts, evidence, settings, signal: controller.signal });
        if (controller.signal.aborted) return;
        const prompt = buildDraft(payload, input.title, facts, evidence, input.note);
        const findings = checkExport(prompt, evidence, facts);
        const record = saveNew(db, { ...input, author, prompt, model: settings.model, evidence,
          generation: { ...metrics, facts }, status: findings.length ? 'needs revision' : 'generated' });
        job.status = 'complete';
        job.recordId = record.id;
        job.findings = findings;
        audit(db, user.name, 'generated prompt ' + record.id);
      } catch (error) {
        if (!controller.signal.aborted) {
          job.status = 'failed';
          job.error = error.message || 'Generation failed.';
        }
      } finally {
        if (controller.signal.aborted) job.status = 'canceled';
        job.finished = Date.now();
        active = null;
      }
    })();
    return job.id;
  }

  const server = createServer({ requestTimeout: 30_000, headersTimeout: 10_000, maxHeaderSize: 16_384 }, async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('X-Frame-Options', 'DENY');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; img-src 'self' blob:; base-uri 'none'; form-action 'self'; frame-ancestors 'none'");
    if (privateMode) res.setHeader('Strict-Transport-Security', 'max-age=86400');
    try {
      const origin = options.privateOrigin || 'http://127.0.0.1:' + (server.address()?.port ?? options.port);
      const expectedHost = new URL(origin).host;
      const host = req.headers.host;
      if (host !== expectedHost && (privateMode || host !== expectedHost.replace('127.0.0.1', 'localhost'))) {
        throw new HttpError(403, 'This browser address is not configured.');
      }
      const allowedOrigin = privateMode ? origin : 'http://' + host;
      const url = new URL(req.url, origin);
      if (!req.url.startsWith('/') || url.origin !== origin) throw new HttpError(400, 'Invalid request path.');
      const path = url.pathname;
      const method = req.method;
      if (req.headers['sec-fetch-site'] === 'cross-site') throw new HttpError(403, 'Cross-site requests are blocked.');
      if (method !== 'GET' && (req.headers.origin !== allowedOrigin || req.headers['x-studio-request'] !== '1')) {
        throw new HttpError(403, 'Request origin could not be verified.');
      }
      if (method === 'GET' && staticFiles.has(path)) {
        const [file, mime] = staticFiles.get(path);
        res.writeHead(200, { 'Content-Type': mime });
        return res.end(readFileSync(join(appDir, 'public', file)));
      }
      const user = auth.viewer(req);
      if (method === 'GET' && path === '/api/session') {
        return json(res, 200, { privateMode, tailscaleMode, user: user ? { name: user.name, role: user.role, csrf: user.csrf } : null });
      }
      if (method === 'POST' && path === '/api/login' && passwordMode) {
        const input = await body(req, 4096);
        const result = await auth.login(input.name, input.password);
        if (result.status !== 200) throw new HttpError(result.status, result.status === 429 ? 'Too many sign-in attempts. Wait five minutes.' : 'Invalid account or password.');
        return json(res, 200, { name: result.name, role: result.role, csrf: result.csrf }, { 'Set-Cookie': result.cookie });
      }
      if (!user) throw new HttpError(401, tailscaleMode ? 'This Tailscale account does not have Studio access.' : 'Sign in to use this studio.');
      if (method !== 'GET' && req.headers['x-studio-csrf'] !== user.csrf) throw new HttpError(403, 'Your session changed. Reload and try again.');
      const admin = () => { if (user.role !== 'admin') throw new HttpError(403, 'This action requires a studio administrator.'); };
      const settings = () => getSettings(db, options);
      if (method === 'POST' && path === '/api/logout' && passwordMode) {
        return json(res, 200, { ok: true }, { 'Set-Cookie': auth.logout(user) });
      }
      if (method === 'GET' && path === '/api/overview') {
        return json(res, 200, { index: recentScan(db), settings: settings(), busy: Boolean(active),
          records: db.prepare('SELECT count(*) AS n FROM records').get().n });
      }
      if (method === 'GET' && path === '/api/model') {
        let status;
        try { status = await ollama.status(); } catch (error) { status = { online: false, error: error.message }; }
        return json(res, 200, status);
      }
      if (method === 'POST' && path === '/api/settings') {
        admin();
        let next;
        try { next = modelSettings(await body(req)); } catch (error) { throw new HttpError(400, error.message); }
        db.prepare("INSERT OR REPLACE INTO settings VALUES('model',?)").run(JSON.stringify(next));
        audit(db, user.name, 'updated model settings');
        return json(res, 200, next);
      }
      if (method === 'GET' && path === '/api/knowledge') {
        return json(res, 200, { index: recentScan(db), facts: projectProfile(db),
          files: db.prepare('SELECT path,size,indexed_at FROM files ORDER BY path').all(),
          reports: db.prepare('SELECT * FROM reports ORDER BY id').all(), exclusions: options.exclude });
      }
      if (method === 'POST' && path === '/api/scan') {
        admin();
        const input = await body(req);
        const result = scan(db, project, options.exclude, input.full === true);
        audit(db, user.name, input.full === true ? 'rebuilt index' : 'rescanned project');
        return json(res, 200, result);
      }
      if (method === 'GET' && path === '/api/library') {
        const list = recordList(db, url.searchParams);
        return json(res, 200, { records: list.slice(0, 100), more: list.length > 100, states });
      }
      if (method === 'POST' && path === '/api/drafts') {
        const input = cleanInput(await body(req), settings(), db);
        const author = privateMode ? user.name : input.author || user.name;
        return json(res, 201, saveNew(db, { ...input, author, prompt: '', model: '', evidence: [], generation: {}, status: 'draft' }));
      }
      if (method === 'POST' && path === '/api/generate') {
        const input = cleanInput(await body(req), settings(), db);
        return json(res, 202, { id: startJob(input, user, settings()) });
      }
      const jobMatch = /^\/api\/jobs\/([a-f0-9-]{36})(\/cancel)?$/.exec(path);
      if (jobMatch) {
        const job = jobs.get(jobMatch[1]);
        if (!job || job.owner !== user.name) throw new HttpError(404, 'Generation job not found.');
        if (method === 'POST' && jobMatch[2]) {
          if (job.status === 'working') {
            job.status = 'canceling';
            job.controller.abort();
          }
          return json(res, 200, { status: job.status });
        }
        if (method === 'GET' && !jobMatch[2]) {
          return json(res, 200, { status: job.status, error: job.error, recordId: job.recordId, findings: job.findings });
        }
      }
      const rec = /^\/api\/prompts\/([1-9][0-9]{0,12})(?:\/(download|revisions|check))?$/.exec(path);
      if (rec) {
        const record = get(Number(rec[1]));
        const facts = record.generation.facts ?? projectProfile(db);
        if (method === 'GET' && rec[2] === 'download') {
          validateExport(record.prompt, record.evidence, facts);
          res.writeHead(200, { 'Content-Type': 'text/plain; charset=utf-8', 'Content-Disposition': 'attachment; filename="' + exportName(record) + '"' });
          return res.end(record.prompt, 'utf8');
        }
        if (method === 'GET' && rec[2] === 'revisions') {
          return json(res, 200, db.prepare('SELECT revision,status,changed_by,created_at FROM revisions WHERE record_id=? ORDER BY revision DESC LIMIT 100').all(record.id));
        }
        if (method === 'POST' && rec[2] === 'check') {
          const prompt = text((await body(req)).prompt, 'Prompt', 30_000, true);
          validateExport(prompt, record.evidence, facts);
          return json(res, 200, { ok: true });
        }
        if (method === 'GET' && !rec[2]) return json(res, 200, { ...record, findings: checkExport(record.prompt, record.evidence, facts) });
        if (method === 'PATCH' && !rec[2]) {
          const edit = await body(req);
          const current = get(record.id);
          if (edit.revision !== current.revision) throw new HttpError(409, 'Someone saved a newer revision. Reopen the record before editing.');
          if (!states.includes(edit.status)) throw new HttpError(400, 'Choose a valid status.');
          const prompt = text(edit.prompt, 'Prompt', 30_000);
          const outcome = text(edit.outcome, 'Outcome', 3500);
          const saved = saveEdit(db, current, { prompt, status: edit.status, outcome }, user.name);
          audit(db, user.name, 'edited prompt ' + record.id);
          return json(res, 200, { ...saved, findings: checkExport(prompt, saved.evidence, facts) });
        }
      }
      const images = /^\/api\/prompts\/([1-9][0-9]{0,12})\/attachments(?:\/([1-9][0-9]{0,12}))?$/.exec(path);
      if (images) {
        const record = get(Number(images[1]));
        if (method === 'GET' && !images[2]) {
          return json(res, 200, db.prepare('SELECT id,name,description,origin,actor,width,height,created_at FROM attachments WHERE record_id=? ORDER BY id').all(record.id));
        }
        if (method === 'POST' && !images[2]) {
          const data = await body(req, 5_650_000);
          const name = text(data.name, 'Image name', 180, true);
          if (/[\\/:<>"|?*\p{Cc}]/u.test(name)) throw new HttpError(400, 'Choose a valid image name.');
          const description = text(data.description, 'Image description', 600).trim();
          const source = text(data.origin, 'Image origin', 160, true).trim();
          if (db.prepare('SELECT count(*) AS n FROM attachments WHERE record_id=?').get(record.id).n >= 4) {
            throw new HttpError(400, 'A prompt can have up to four screenshots.');
          }
          let image;
          try { image = sanitizePng(data.png); } catch (error) { throw new HttpError(400, error.message); }
          const added = db.prepare('INSERT INTO attachments(record_id,name,description,origin,actor,width,height,bytes,created_at) VALUES(?,?,?,?,?,?,?,?,?)')
            .run(record.id, name, description, source, user.name, image.width, image.height, image.bytes, now());
          audit(db, user.name, 'attached screenshot to prompt ' + record.id);
          return json(res, 201, { id: Number(added.lastInsertRowid) });
        }
        if (images[2] && method === 'GET') {
          const image = db.prepare('SELECT bytes FROM attachments WHERE id=? AND record_id=?').get(Number(images[2]), record.id);
          if (!image) throw new HttpError(404, 'Screenshot not found.');
          res.writeHead(200, { 'Content-Type': 'image/png', 'Content-Disposition': 'inline' });
          return res.end(image.bytes);
        }
        if (images[2] && method === 'DELETE') {
          const image = db.prepare('SELECT actor FROM attachments WHERE id=? AND record_id=?').get(Number(images[2]), record.id);
          if (!image) throw new HttpError(404, 'Screenshot not found.');
          if (user.role !== 'admin' && user.name !== image.actor) throw new HttpError(403, 'Only its uploader or an administrator can remove this screenshot.');
          db.prepare('DELETE FROM attachments WHERE id=? AND record_id=?').run(Number(images[2]), record.id);
          audit(db, user.name, 'removed screenshot from prompt ' + record.id);
          return json(res, 200, { ok: true });
        }
      }
      if (method === 'GET' && path === '/api/imports') {
        return json(res, 200, {
          discovered: discovered(project, options.exclude).map(file => file.name),
          batches: db.prepare('SELECT b.*,count(i.id) AS count FROM batches b LEFT JOIN imports i ON b.id=i.batch_id GROUP BY b.id ORDER BY b.id DESC LIMIT 100').all()
        });
      }
      if (method === 'GET' && path === '/api/imports/discovered') return json(res, 200, discovered(project, options.exclude));
      const batchMatch = /^\/api\/imports\/([1-9][0-9]{0,12})$/.exec(path);
      if (method === 'GET' && batchMatch) {
        const entries = db.prepare('SELECT name,body,hash,created_at FROM imports WHERE batch_id=? ORDER BY id').all(Number(batchMatch[1]));
        if (!entries.length) throw new HttpError(404, 'Import batch not found.');
        return json(res, 200, entries);
      }
      if (method === 'DELETE' && batchMatch) {
        admin();
        if (!removeBatch(db, Number(batchMatch[1]))) throw new HttpError(404, 'Import batch not found.');
        audit(db, user.name, 'removed import batch ' + batchMatch[1]);
        return json(res, 200, { ok: true });
      }
      if (method === 'POST' && ['/api/imports/preview', '/api/imports'].includes(path)) {
        const input = await body(req, 1_700_000);
        const files = importFiles(input.files);
        if (path.endsWith('/preview')) {
          return json(res, 200, importPreview(db, files).map(file => ({
            name: file.name, duplicate: file.duplicate, preview: file.body.slice(0, 450), characters: file.body.length
          })));
        }
        const result = importBatch(db, { files, author: text(input.author, 'Original author', 80).trim() || 'Unknown',
          label: text(input.label, 'Source', 120).trim() || 'Selected files', uploader: user.name });
        audit(db, user.name, 'imported ' + result.imported + ' history documents');
        return json(res, 201, result);
      }
      if (method === 'POST' && path === '/api/backup') {
        admin();
        return json(res, 201, await snapshot(db, storage));
      }
      throw new HttpError(404, 'Page not found.');
    } catch (error) {
      if (!(error instanceof HttpError)) console.error('Studio request failed:', error.code ?? error.name);
      if (!res.headersSent && !res.destroyed) json(res, error.status ?? 500, {
        error: error.status ? error.message : 'Studio encountered an error. Check the host console.', findings: error.findings
      });
    }
  });
  server.once('listening', () => {
    if (!recentScan(db)) scheduledScan = setTimeout(() => {
      try { scan(db, project, options.exclude); } catch (error) { console.error('Initial index failed:', error.code ?? error.name); }
    }, 10);
  });
  server.once('close', () => {
    clearTimeout(scheduledScan);
    active?.controller.abort();
    db.close();
  });
  return server;
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const settings = config();
  const server = createStudio({ options: settings });
  server.on('error', error => {
    console.error(error.code === 'EADDRINUSE' ? 'Studio port is already in use. Stop the existing instance or change config.json.' : error.message);
    process.exitCode = 1;
  });
  server.listen(settings.port, '127.0.0.1', () => {
    console.log('Game Prompt Studio at ' + (settings.privateOrigin || 'http://127.0.0.1:' + settings.port));
    console.log('Data: ' + dataDir);
    if (process.platform === 'win32' && process.argv.includes('--open-browser') && !settings.privateOrigin) {
      const address = 'http://127.0.0.1:' + settings.port;
      const opener = spawn(join(process.env.SystemRoot || 'C:\\Windows', 'System32', 'rundll32.exe'),
        ['url.dll,FileProtocolHandler', address], { stdio: 'ignore', detached: true, windowsHide: true });
      opener.on('error', () => console.error('Open ' + address + ' in your browser.'));
      opener.unref();
    }
  });
}
