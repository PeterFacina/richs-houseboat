import { readFileSync, statSync } from 'node:fs';
import { dirname, join } from 'node:path';
import { DatabaseSync } from 'node:sqlite';
import { indexedKnowledge, projectProfile, recentScan } from '../game_prompt_studio/lib/index.mjs';
import { pinnedFunctions } from '../discord-issue-pilot/multistage/code-index.mjs';
import { inboxLessons, lessonStatus } from '../discord-issue-pilot/learning/lessons.mjs';
import { publicJob } from '../discord-issue-pilot/generation-jobs.mjs';
import { date, flag, model, number, oneOf, pageSize, positive, retrievalModes, revision, sourcePath, text } from './contract.mjs';
import { briefStats, gitHubOutcomeCounts, latestKnowledgeCheck, learningStats, outcomePage, publishedBriefs, publishedLinks, retrievalResult,
  reviewedIssueOutcomes } from './training-read.mjs';

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
    const phase = age > 120_000 || age < -10_000 ? 'heartbeat-stale' : value.phase;
    const knowledge = value.knowledge;
    const gpu = value.gpu;
    return { phase, observedAt,
      release: revision(value.release), model: model(value.model),
      modelDigest: typeof value.modelDigest === 'string' && /^[0-9a-f]{64}$/.test(value.modelDigest) ? value.modelDigest : null,
      issue: phase === 'generating' ? positive(value.issue) : null,
      warning: oneOf(['github-queue', 'github-outcomes'], value.warning),
      gpu: gpu && [gpu.utilization, gpu.usedMiB, gpu.totalMiB].every(value => number(value) !== null) &&
        gpu.utilization <= 100 && gpu.totalMiB > 0 && gpu.usedMiB <= gpu.totalMiB ?
        { utilization: gpu.utilization, usedMiB: gpu.usedMiB, totalMiB: gpu.totalMiB } : null,
      configuredMode: oneOf(retrievalModes, value.configuredMode), canary: flag(value.canary),
      knowledge: knowledge && date(knowledge.observedAt) ? {
        indexedRevision: revision(knowledge.indexedRevision), target: revision(knowledge.target),
        stale: flag(knowledge.stale), observedAt: date(knowledge.observedAt), via: 'heartbeat',
      } : null,
    };
  } catch { return null; }
}

function trainingStatus(path) {
  try {
    if (statSync(path).size > 4096) return null;
    const state = JSON.parse(readFileSync(path, 'utf8'));
    const phase = oneOf(['waiting-for-approved-examples', 'waiting-for-holdout', 'awaiting-training-authorization', 'waiting-for-worker', 'waiting-for-gpu',
      'training', 'evaluating', 'awaiting-promotion', 'evaluation-did-not-improve', 'failed'], state.phase);
    const time = typeof state.observedAt === 'string' && /Z$/.test(state.observedAt) ? Date.parse(state.observedAt) : NaN;
    if (state.schema !== 1 || !phase || !Number.isFinite(time)) return null;
    return { phase, observedAt: new Date(time).toISOString(), candidate: model(state.model), examples: number(state.examples),
      required: number(state.required), step: number(state.step), steps: number(state.steps), cases: number(state.cases),
      baselineScore: number(state.baselineScore), candidateScore: number(state.candidateScore) };
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
    dependencies: data.files.reduce((sum, file) => sum + (data.manifest.files[file.path]?.references?.length ?? 0), 0),
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

function jobStatuses(db) {
  if (!db.prepare("SELECT name FROM sqlite_master WHERE type='table' AND name='generation_jobs'").get()) return new Map();
  return new Map(db.prepare('SELECT issue,data FROM generation_jobs ORDER BY rowid').all()
    .flatMap(row => { try { const job = publicJob(JSON.parse(row.data)); return job ? [[row.issue, job]] : []; } catch { return []; } }));
}

export function createReader({ storage, inbox, githubIssues, lessons = JSON.parse(readFileSync(lessonFile, 'utf8')), now = Date.now }) {
  const source = read => readStore(join(storage, 'studio.sqlite'), read);
  const training = read => readStore(inbox, read);
  const cache = new Map();
  return {
    overview(role) {
      const cached = cache.get(role);
      const time = now();
      if (cached && time - cached.at >= 0 && time - cached.at < 15_000) return cached.value;
      const status = statusAt(join(storage, 'worker-status.json'), time);
      const worker = status && role === 'viewer' ? { ...status, issue: null } : status;
      const trainingData = training(db => ({
        briefs: briefStats(db, role === 'reviewer'),
        knowledgeCheck: latestKnowledgeCheck(db),
        ...(role === 'reviewer' ? { learning: learningStats(db), jobs: [...jobStatuses(db)].map(([issue, job]) => ({ issue, ...job })) } : {}),
      }));
      const value = { knowledge: source(knowledgeOverview), worker,
        knowledgeCheck: worker?.knowledge ?? trainingData?.knowledgeCheck ?? null,
        briefs: trainingData?.briefs ?? null,
        ...(role === 'reviewer' ? { learning: trainingData?.learning ?? null, jobs: trainingData?.jobs ?? [],
          training: trainingStatus(join(dirname(inbox), 'training-status.json')) } : {}),
      };
      cache.set(role, { at: time, value });
      return value;
    },
    knowledge(params) { return source(db => knowledgePage(db, params)); },
    async issues(page) {
      if (!githubIssues) return null;
      const snapshot = await githubIssues();
      const local = training(db => ({ links: publishedLinks(db), outcomes: reviewedIssueOutcomes(db),
        github: gitHubOutcomeCounts(db), jobs: jobStatuses(db) }));
      const rows = snapshot.rows.slice(page * pageSize, (page + 1) * pageSize)
        .map(row => ({ ...row, job: local?.jobs.get(row.issue) ?? row.job ?? null, localCapture: row.brief && local ? local.links.has(row.brief) : null,
          outcome: local?.outcomes.get(row.issue) ?? null, githubOutcome: local?.github.get(row.issue) ?? null }));
      return { checkedAt: snapshot.checkedAt, stale: snapshot.stale ?? false, rows, page,
        more: snapshot.rows.length > (page + 1) * pageSize, total: snapshot.rows.length,
        open: snapshot.rows.filter(row => row.state === 'open').length };
    },
    briefs(page) { return training(db => publishedBriefs(db, page)); },
    retrieval(issue, role) { return training(db => ({ result: retrievalResult(db, issue, role === 'reviewer') })); },
    learning(page) {
      const development = training(db => outcomePage(db, page));
      const remote = inboxLessons(inbox);
      const ids = new Set(remote.map(lesson => lesson.report.number));
      const snapshot = { lessons: [...remote, ...(lessons.lessons ?? []).filter(lesson => !ids.has(lesson.report.number))] };
      return { catalogue: source(db => curatedLessons(join(storage, 'source'), db, snapshot)), development };
    },
  };
}
