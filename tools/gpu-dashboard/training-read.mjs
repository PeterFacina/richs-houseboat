import { date, evidenceKinds, model, number, oneOf, pageSize, positive, publication, pullLink, retrievalModes, revision, sourcePath } from './contract.mjs';

const cleanJson = column => `CASE WHEN json_valid(${column}) THEN ${column} ELSE '{}' END`;
const mode = column => `CASE json_extract(${column}, '$.knowledge.retrieval.effective')
  WHEN 'original' THEN 'original' WHEN 'deterministic-v1' THEN 'deterministic-v1' ELSE 'unrecorded' END`;
const captured = `SELECT rowid, issue, id, recorded, published, ${cleanJson('input')} AS doc FROM captures`;
const reviews = `SELECT rowid, issue, at, ${cleanJson('data')} AS doc FROM reviews`;
const latestOutcomes = `
  SELECT r.*, ${mode('c.doc')} AS mode FROM (${reviews}) r
  JOIN (${captured}) c ON c.issue=r.issue AND c.id=json_extract(r.doc, '$.captureId') AND c.published IS NOT NULL
  WHERE json_extract(r.doc, '$.status')='outcome'
  AND r.rowid IN (SELECT MAX(r2.rowid) FROM (${reviews}) r2
    JOIN captures c2 ON c2.issue=r2.issue AND c2.id=json_extract(r2.doc, '$.captureId') AND c2.published IS NOT NULL
    WHERE json_extract(r2.doc, '$.status')='outcome' GROUP BY r2.issue)`;

const briefMetrics = {
  inputTokens: '$.metrics.promptTokens', outputTokens: '$.metrics.outputTokens',
  generationMs: '$.metrics.durationMs', retrievalMs: '$.knowledge.retrieval.elapsedMs',
};
const developmentMetrics = Object.fromEntries(['developmentSeconds', 'reviewSeconds', 'correctionSeconds', 'inputTokens',
  'cachedInputTokens', 'outputTokens', 'reasoningTokens', 'incorrectAssumptions', 'unnecessarySourceSteps', 'humanCorrections']
  .map(key => [key, '$.' + key]));

function measured(column, path) {
  const value = `json_extract(${column}, '${path}')`;
  return `CASE WHEN json_type(${column}, '${path}') IN ('integer','real') AND ${value} BETWEEN 0 AND 9007199254740991 THEN ${value} END`;
}

function sums(metrics) {
  return Object.entries(metrics).map(([key, path]) => {
    const value = measured('doc', path);
    return `SUM(${value}) AS ${key}, COUNT(${value}) AS ${key}Count`;
  }).join(', ');
}

function totals(rows, metrics) {
  return Object.fromEntries(Object.keys(metrics).map(key => {
    const recorded = rows.reduce((sum, row) => sum + row[key + 'Count'], 0);
    return [key, { recorded, total: recorded ? rows.reduce((sum, row) => sum + (row[key] ?? 0), 0) : null }];
  }));
}

const hasReviews = db => Boolean(db.prepare("SELECT 1 FROM sqlite_schema WHERE type='table' AND name='reviews'").get());

export function briefStats(db, reviewer) {
  const published = db.prepare(`SELECT COUNT(*) AS briefs, COUNT(DISTINCT issue) AS issues FROM captures WHERE published IS NOT NULL`).get();
  if (!reviewer) return { published };
  const rows = db.prepare(`SELECT ${mode('doc')} AS mode, COUNT(*) AS briefs, COUNT(published) AS published,
    COUNT(CASE WHEN json_type(doc, '$.exportPassed')='false' THEN 1 END) AS blocked,
    COUNT(CASE WHEN json_type(doc, '$.exportPassed') IN ('true','false') THEN 1 END) AS guardRecorded,
    ${sums(briefMetrics)} FROM (${captured}) GROUP BY mode ORDER BY mode`).all();
  return {
    published,
    collected: rows.reduce((sum, row) => sum + row.briefs, 0),
    metrics: totals(rows, briefMetrics),
    modes: rows.map(row => ({
      mode: row.mode, briefs: row.briefs, published: row.published, blocked: row.blocked, guardRecorded: row.guardRecorded,
      metrics: totals([row], briefMetrics),
    })),
  };
}

export function learningStats(db) {
  if (!hasReviews(db)) return null;
  const { feedback } = db.prepare(`SELECT COUNT(*) AS feedback FROM (${reviews}) WHERE json_extract(doc, '$.status')='feedback'`).get();
  const { approved } = db.prepare(`SELECT COUNT(DISTINCT c.rowid) AS approved FROM captures c
    JOIN (${reviews}) r ON r.issue=c.issue AND json_extract(r.doc, '$.captureId')=c.id
    WHERE c.published IS NOT NULL AND json_extract(r.doc, '$.status')='approved'
      AND json_type(r.doc, '$.target')='object' AND json_type(r.doc, '$.reviewer')='text'`).get();
  const { lessonsUsed } = db.prepare(`SELECT COUNT(*) AS lessonsUsed FROM (
    SELECT published, brief, ${cleanJson('input')} AS doc FROM captures)
    WHERE published IS NOT NULL AND instr(brief, char(10)||'VERIFIED LESSON FROM A COMPLETED TASK'||char(10))>0
    AND EXISTS (SELECT 1 FROM json_each(doc,'$.retrievedContext') e
      WHERE json_extract(CASE WHEN e.type='object' THEN e.value ELSE '{}' END,'$.kind')='verified-lesson')`).get();
  const rows = db.prepare(`SELECT mode, COUNT(*) AS completed,
    COUNT(CASE WHEN json_extract(doc, '$.firstAttempt')='passed' THEN 1 END) AS passed,
    COUNT(CASE WHEN json_extract(doc, '$.firstAttempt')='failed' THEN 1 END) AS failed,
    ${sums(developmentMetrics)} FROM (${latestOutcomes}) GROUP BY mode ORDER BY mode`).all();
  const completed = rows.reduce((sum, row) => sum + row.completed, 0);
  return { feedback, approved, completed, lessonsUsed, metrics: totals(rows, developmentMetrics),
    modes: rows.map(({ mode, completed, passed, failed }) => ({ mode, completed, passed, failed })) };
}

const publishedFields = `issue, rowid, published, recorded, ${mode('doc')} AS mode,
  json_extract(doc, '$.commit') AS revision, json_extract(doc, '$.model') AS model`;
const latestPublished = `FROM (${captured}) WHERE rowid IN (
  SELECT MAX(rowid) FROM captures WHERE published IS NOT NULL GROUP BY issue)`;

function publishedBrief(row) {
  const link = row && publication(row.issue, row.published);
  return link ? { issue: row.issue, url: link, recordedAt: date(row.recorded),
    revision: revision(row.revision), model: model(row.model), mode: row.mode } : null;
}

export function publishedBriefs(db, page) {
  const rows = db.prepare(`SELECT ${publishedFields} ${latestPublished} ORDER BY rowid DESC LIMIT ? OFFSET ?`)
    .all(pageSize + 1, page * pageSize);
  return { page, more: rows.length > pageSize, briefs: rows.slice(0, pageSize).map(publishedBrief).filter(Boolean) };
}

export function publishedLinks(db) {
  return new Set(db.prepare('SELECT issue, published FROM captures WHERE published IS NOT NULL').all()
    .map(({ issue, published }) => publication(issue, published)).filter(Boolean));
}

export function reviewedIssueOutcomes(db) {
  if (!hasReviews(db)) return new Map();
  const rows = db.prepare(`SELECT issue, json_extract(doc, '$.prUrl') AS pull,
    json_extract(doc, '$.verification') AS verification FROM (${latestOutcomes})`).all();
  return new Map(rows.map(row => [row.issue, { pull: pullLink(row.pull),
    verification: oneOf(['passed', 'failed', 'partial', 'unverified'], row.verification) }]));
}

export function gitHubOutcomeCounts(db) {
  if (!db.prepare("SELECT 1 FROM sqlite_schema WHERE type='table' AND name='github_outcomes'").get()) return new Map();
  const rows = db.prepare(`SELECT issue, json_extract(doc,'$.pull') AS pull,
    json_array_length(doc,'$.files') AS files, json_array_length(doc,'$.corrections') AS corrections,
    json_array_length(doc,'$.checks') AS checks,
    (SELECT COUNT(*) FROM json_each(doc,'$.checks') item WHERE json_extract(item.value,'$.conclusion')='success') AS passed
    FROM (SELECT issue, ${cleanJson('data')} AS doc FROM github_outcomes)`).all();
  return new Map(rows.map(({ issue, pull, files, corrections, checks, passed }) => [issue,
    { pull: positive(pull), files: number(files), corrections: number(corrections), checks: number(checks), passed: number(passed) }]));
}

export function latestKnowledgeCheck(db) {
  const row = db.prepare(`SELECT recorded, json_extract(doc,'$.commit') AS commitSha,
    json_extract(doc,'$.knowledge.target') AS target, json_type(doc,'$.knowledge.stale') AS stale
    FROM (${captured}) WHERE json_type(doc,'$.knowledge.target')='text'
      OR json_type(doc,'$.knowledge.stale') IN ('true', 'false')
    ORDER BY rowid DESC LIMIT 1`).get();
  return row ? { indexedRevision: revision(row.commitSha), target: revision(row.target), observedAt: date(row.recorded),
    stale: ({ true: true, false: false })[row.stale] ?? null, via: 'brief' } : null;
}

export function retrievalResult(db, issue, reviewer) {
  const row = db.prepare(`SELECT ${publishedFields},
    json_extract(doc,'$.knowledge.retrieval.briefVersion') AS briefVersion,
    json_type(doc,'$.knowledge.stale') AS stale, json_type(doc,'$.exportPassed') AS guard,
    json_extract(doc,'$.contextBytes') AS contextBytes,
    instr(brief, char(10)||'VERIFIED LESSON FROM A COMPLETED TASK'||char(10))>0 AS section
    FROM (SELECT rowid, issue, recorded, published, brief, ${cleanJson('input')} AS doc FROM captures)
    WHERE issue=? AND published IS NOT NULL ORDER BY rowid DESC LIMIT 1`).get(issue);
  const brief = publishedBrief(row);
  if (!brief) return null;
  const evidence = db.prepare(`SELECT json_extract(e.item,'$.kind') AS kind,
    json_extract(e.item,'$.path') AS path, json_extract(e.item,'$.line') AS line,
    json_extract(e.item,'$.title') AS title, json_extract(e.item,'$.score') AS score
    FROM (SELECT CASE WHEN e.type='object' THEN e.value ELSE '{}' END AS item
      FROM (${captured}) c, json_each(c.doc,'$.retrievedContext') e WHERE c.rowid=? ORDER BY e.key LIMIT 80) e`).all(row.rowid);
  const counts = {};
  const sources = [];
  for (const item of evidence) {
    const kind = oneOf(evidenceKinds, item.kind) ?? 'other';
    counts[kind] = (counts[kind] ?? 0) + 1;
    const path = sourcePath(item.path);
    const line = positive(item.line);
    if (['source', 'guide'].includes(kind) && path && line && brief.revision) {
      const score = number(item.score);
      const symbol = typeof item.title === 'string' && /^[\w]{1,128}$/.test(item.title) ? item.title : null;
      sources.push({ path, line, kind, ...(score === null ? {} : { score, symbol }) });
    }
  }
  const detail = {
    ...brief, sources, counts,
    briefVersion: oneOf(['original', 'verification-v1'], row.briefVersion),
    stale: ({ true: true, false: false })[row.stale] ?? null,
    exportPassed: ({ true: true, false: false })[row.guard] ?? null,
    lessonRendered: Boolean(row.section && counts['verified-lesson']),
  };
  if (reviewer) {
    detail.metrics = db.prepare(`SELECT ${Object.entries(briefMetrics).map(([key, path]) =>
      `${measured('doc', path)} AS ${key}`).join(', ')} FROM (${captured}) WHERE rowid=?`).get(row.rowid);
    detail.contextBytes = number(row.contextBytes);
  }
  if (reviewer && hasReviews(db)) {
    const review = db.prepare(`SELECT COUNT(CASE WHEN json_extract(r.doc, '$.status')='feedback' THEN 1 END) AS feedback,
      COUNT(CASE WHEN json_extract(r.doc, '$.status')='approved' AND json_extract(r.doc, '$.captureId')=c.id
        AND json_type(r.doc, '$.target')='object' AND json_type(r.doc, '$.reviewer')='text' THEN 1 END)>0 AS approved
      FROM (${reviews}) r JOIN captures c ON c.issue=r.issue AND c.rowid=?`).get(row.rowid);
    detail.review = { feedback: review.feedback, approved: Boolean(review.approved) };
  }
  return detail;
}

export function outcomePage(db, page) {
  if (!hasReviews(db)) return null;
  const rows = db.prepare(`SELECT issue, at, mode, json_extract(doc,'$.prUrl') AS prUrl,
    json_extract(doc,'$.firstAttempt') AS firstAttempt, json_extract(doc,'$.verification') AS verification,
    ${measured('doc', '$.humanCorrections')} AS corrections,
    ${measured('doc', '$.developmentSeconds')} AS developmentSeconds,
    ${measured('doc', '$.reviewSeconds')} AS reviewSeconds
    FROM (${latestOutcomes}) ORDER BY rowid DESC LIMIT ? OFFSET ?`).all(pageSize + 1, page * pageSize);
  return { page, more: rows.length > pageSize, outcomes: rows.slice(0, pageSize).map(row => ({
    issue: positive(row.issue), prUrl: pullLink(row.prUrl), recordedAt: date(row.at),
    mode: oneOf(retrievalModes, row.mode) ?? 'unrecorded', corrections: row.corrections,
    developmentSeconds: row.developmentSeconds, reviewSeconds: row.reviewSeconds,
    firstAttempt: oneOf(['passed', 'failed', 'unverified'], row.firstAttempt),
    verification: oneOf(['passed', 'failed', 'partial', 'unverified'], row.verification),
  })).filter(row => row.issue && row.prUrl) };
}
