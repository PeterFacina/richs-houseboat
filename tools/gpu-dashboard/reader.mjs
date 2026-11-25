import { readFileSync, statSync } from 'node:fs';
import { join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { indexedKnowledge, projectProfile, recentScan } from '../game_prompt_studio/lib/index.mjs';
import { pinnedFunctions } from '../discord-issue-pilot/multistage/code-index.mjs';
import { lessonStatus } from '../discord-issue-pilot/learning/lessons.mjs';
import { date, flag, model, number, oneOf, pageSize, positive, retrievalModes, revision, sourcePath, text } from './contract.mjs';
import { briefStats, latestKnowledgeCheck, learningStats, outcomePage, publishedBriefs, retrievalResult } from './training-read.mjs';

const phases = ['starting', 'watching', 'generating', 'degraded', 'stopped'];
const lessonFile = new URL('../discord-issue-pilot/learning-lessons.json', import.meta.url);

function readStore(path, read) {
  let db;
  try {
    db = new DatabaseSync(path, { readOnly: true });
    db.exec('PRAGMA query_only=ON; PRAGMA busy_timeout=250; BEGIN');
    return read(db);
  } catch {
    return null;
  } finally {
    db?.close();
  }
}

function statusAt(path, now) {
  try {
    if (statSync(path).size > 4096) return null;
    const value = JSON.parse(readFileSync(path, 'utf8'));
    const observedAt = date(value.observedAt);
    if (value.schema !== 1 || !observedAt || !phases.includes(value.phase)) return null;
    const age = now - Date.parse(observedAt);
    const knowledge = value.knowledge;
    return { phase: age > 120_000 || age < -10_000 ? 'heartbeat-stale' : value.phase, observedAt,
      release: revision(value.release), model: model(value.model),
      configuredMode: oneOf(retrievalModes, value.configuredMode), canary: flag(value.canary),
      knowledge: knowledge && date(knowledge.observedAt) ? {
        indexedRevision: revision(knowledge.indexedRevision), target: revision(knowledge.target),
        stale: flag(knowledge.stale), observedAt: date(knowledge.observedAt), via: 'heartbeat',
      } : null,
    };
  } catch { return null; }
}

function inventory(db) {
  const manifest = indexedKnowledge(db);
  const scan = recentScan(db);
  if (manifest?.schema !== 1 || !revision(manifest.revision) || scan?.revision !== manifest.revision || !manifest.files) return null;
  const files = db.prepare('SELECT path, size FROM files ORDER BY path').all()
    .filter(row => sourcePath(row.path)).map(row => {
      const symbols = manifest.files[row.path]?.symbols ?? [];
      const functions = symbols.filter(item => item.kind === 'func' && text(item.name, 128) && positive(item.line))
        .map(item => ({ name: item.name, line: item.line }));
      return { path: row.path, size: number(row.size), functions };
    });
  return { manifest, scan, files };
}

function knowledgeOverview(db) {
  const data = inventory(db);
  if (!data) return null;
  return { revision: data.manifest.revision, indexedAt: date(data.scan.at), files: data.files.length,
    functions: data.files.reduce((sum, item) => sum + item.functions.length, 0),
    manifestFunctions: Object.values(data.manifest.files).reduce((sum, item) =>
      sum + (item.symbols ?? []).filter(symbol => symbol.kind === 'func').length, 0),
    facts: projectProfile(db).filter(item => sourcePath(item.path) && text(item.fact, 240) && positive(item.line))
      .map(({ fact, path, line }) => ({ fact, path, line })),
  };
}

function knowledgePage(db, { kind, q, page }) {
  const data = inventory(db);
  if (!data) return null;
  const terms = q.toLowerCase().split(/\s+/).filter(Boolean);
  const matches = value => terms.every(term => value.toLowerCase().includes(term));
  const rows = kind === 'files' ? data.files.filter(item => matches(item.path)).map(item => ({
    path: item.path, size: item.size, functions: item.functions.length,
  })) : data.files.flatMap(file => file.functions.filter(item => matches(file.path + ' ' + item.name))
    .map(item => ({ path: file.path, name: item.name, line: item.line })));
  return { revision: data.manifest.revision, kind, page, total: rows.length, rows: rows.slice(page * pageSize, (page + 1) * pageSize) };
}

function curatedLessons(root, db, snapshot) {
  const manifest = indexedKnowledge(db);
  const items = (snapshot.lessons ?? []).slice(0, 100)
    .filter(item => positive(item.report?.number) && positive(item.implementation?.pull));
  if (!manifest || !revision(manifest.revision)) return null;
  const anchors = items.flatMap(item => (item.anchors ?? []).filter(anchor => sourcePath(anchor.path)));
  let index;
  try { index = pinnedFunctions(root, manifest, anchors); }
  catch { index = { files: new Map() }; }
  const lessons = lessonStatus({ lessons: items }, index);
  return { revision: manifest.revision, items: lessons.map(({ item, current }) => ({
    issue: item.report.number, pull: item.implementation.pull,
    title: text(item.report.title), state: current ? 'verified' : 'revalidation-needed',
    failedApproach: text(item.failure), successfulApproach: text(item.success),
    review: text(item.feedback), verification: text(item.verification),
  })) };
}

export function createReader({ storage, inbox, lessons = JSON.parse(readFileSync(lessonFile, 'utf8')), now = Date.now }) {
  const source = read => readStore(join(storage, 'studio.sqlite'), read);
  const training = read => readStore(inbox, read);
  const cache = new Map();
  return {
    overview(role) {
      const cached = cache.get(role);
      const time = now();
      if (cached && time - cached.at >= 0 && time - cached.at < 15_000) return cached.value;
      const worker = statusAt(join(storage, 'worker-status.json'), time);
      const trainingData = training(db => ({
        briefs: briefStats(db, role === 'reviewer'),
        knowledgeCheck: latestKnowledgeCheck(db),
        ...(role === 'reviewer' ? { learning: learningStats(db) } : {}),
      }));
      const value = { knowledge: source(knowledgeOverview), worker,
        knowledgeCheck: worker?.knowledge ?? trainingData?.knowledgeCheck ?? null,
        briefs: trainingData?.briefs ?? null,
        ...(role === 'reviewer' ? { learning: trainingData?.learning ?? null } : {}),
      };
      cache.set(role, { at: time, value });
      return value;
    },
    knowledge(params) { return source(db => knowledgePage(db, params)); },
    briefs(page) { return training(db => publishedBriefs(db, page)); },
    retrieval(issue, role) { return training(db => ({ result: retrievalResult(db, issue, role === 'reviewer') })); },
    learning(page) {
      const development = training(db => outcomePage(db, page));
      return { catalogue: source(db => curatedLessons(join(storage, 'source'), db, lessons)), development };
    },
  };
}
