const repository = 'https://github.com/PeterFacina/richs-houseboat';
const page = document.querySelector('#page');
const loaded = document.querySelector('#loaded');
const refresh = document.querySelector('#refresh');
const nav = [...document.querySelectorAll('#nav a')];
const reviewerViews = new Set(['issues', 'learning']);
const integer = new Intl.NumberFormat('en-CA', { maximumFractionDigits: 0 });
const decimal = new Intl.NumberFormat('en-CA', { maximumFractionDigits: 1 });
const clock = new Intl.DateTimeFormat('en-CA', { month: 'short', day: 'numeric', hour: 'numeric', minute: '2-digit',
  timeZone: 'America/Halifax', timeZoneName: 'short' });
const labels = { original: 'Original', 'deterministic-v1': 'Deterministic v1', unrecorded: 'Unrecorded',
  starting: 'Starting', watching: 'Watching Discord queue', generating: 'Generating', degraded: 'Queue check degraded',
  stopped: 'Stopped', 'heartbeat-stale': 'Heartbeat is stale', passed: 'Passed', failed: 'Failed',
  partial: 'Partial', unverified: 'Unverified', source: 'Source', guide: 'Guide', github: 'GitHub', history: 'Studio history',
  reported: 'Reports', imported: 'Imported', attachment: 'Attachment', 'verified-lesson': 'Verified lesson', other: 'Other' };

const trainingLabels = { 'waiting-for-approved-examples': 'Waiting for approved examples',
  'waiting-for-holdout': 'Waiting for independent evaluation cases', 'waiting-for-worker': 'Waiting for the worker',
  'waiting-for-gpu': 'Waiting for idle GPU', training: 'Training', evaluating: 'Evaluating',
  'awaiting-promotion': 'Awaiting human approval', 'evaluation-did-not-improve': 'Evaluation did not improve', failed: 'Run failed' };

let serial = 0;
let lastOverview;
const search = { q: '', kind: 'files', page: 0 };
let briefPage = 0;
let issuePage = 0;
let outcomePage = 0;

function el(tag, content, className) {
  const node = document.createElement(tag);
  if (className) node.className = className;
  node.append(...[content].flat().filter(item => item != null));
  return node;
}

const fmt = value => Number.isFinite(value) ? integer.format(value) : '—';
const fmtTime = value => value ? clock.format(new Date(value)) : 'Unrecorded';
const fmtSeconds = value => Number.isFinite(value) ? decimal.format(value) + ' s' : '—';
const fmtMillis = value => !Number.isFinite(value) ? '—' : value < 1000 ? fmt(value) + ' ms' : fmtSeconds(value / 1000);
const counted = (value, noun) => fmt(value) + ' ' + noun + (value === 1 ? '' : 's');
const label = key => labels[key] ?? 'Unrecorded';
const short = value => value ? value.slice(0, 8) : 'Unrecorded';
const muted = value => el('p', value, 'muted');
const notice = (value, problem = false) => el('p', value, 'notice' + (problem ? ' problem' : ''));
const chip = (value, style = '') => el('span', value, 'chip ' + style);

function anchor(value, url, external = true) {
  const link = el('a', value);
  link.href = url;
  if (external) {
    link.target = '_blank';
    link.rel = 'noopener noreferrer';
  }
  return link;
}

function commit(value) {
  return /^[0-9a-f]{40}$/.test(value ?? '') ? anchor(el('code', short(value)), repository + '/commit/' + value) : short(value);
}

function codeLink(hash, path, line, title = path) {
  if (!/^[0-9a-f]{40}$/.test(hash ?? '')) return el('code', title);
  const target = repository + '/blob/' + hash + '/' + path.split('/').map(encodeURIComponent).join('/') + (line ? '#L' + line : '');
  return anchor(el('code', title), target);
}

function heading(title, subtitle) {
  return [el('h1', title), el('p', subtitle, 'subtitle')];
}

function panel(title, subtitle, content, action = null) {
  return el('section', [el('header', [el('div', [el('h2', title), subtitle ? muted(subtitle) : null]), action]), ...content], 'panel');
}

function pairs(values) {
  return el('dl', values.map(([name, value]) => el('div', [el('dt', name), el('dd', value)])), 'pairs');
}

function table(headers, rows) {
  const head = el('tr', headers.map(value => {
    const cell = el('th', value);
    cell.scope = 'col';
    return cell;
  }));
  return el('div', el('table', [el('thead', head), el('tbody', rows.map(row =>
    el('tr', row.map((item, i) => el('td', item, i === 0 ? 'file' : '')))))]), 'table-wrap');
}

function metric(name, value, note) {
  return el('div', [el('p', name, 'kicker'), el('p', fmt(value), 'value'), el('p', note, 'muted note')], 'metric');
}

function measured(metric) {
  return metric?.recorded ? [fmt(metric.total), el('span', fmt(metric.recorded) + ' recorded', 'muted')] : ['—'];
}

function measurementCell(value) {
  return el('span', measured(value), 'count');
}

function action(value, change, disabled = false) {
  const button = el('button', value, 'button secondary');
  button.type = 'button';
  button.disabled = disabled;
  button.addEventListener('click', change);
  return button;
}

function pager(current, more, change) {
  if (!current && !more) return null;
  return el('div', [muted('Page ' + (current + 1)), action('Previous', () => change(current - 1), !current),
    action('Next', () => change(current + 1), !more)], 'pager');
}

async function api(path, params = {}) {
  const query = new URLSearchParams(params);
  const response = await fetch('/api/' + path + (query.size ? '?' + query : ''), { cache: 'no-store' });
  if (!response.ok) {
    const value = await response.json().catch(() => ({}));
    throw new Error(value.error ?? 'Worker data is unavailable.');
  }
  return response.json();
}

function factList(knowledge) {
  return knowledge?.facts?.length ? el('ul', knowledge.facts.map(({ fact, path, line }) =>
    el('li', [el('span', fact), codeLink(knowledge.revision, path, line, 'source')])), 'fact-list') :
    notice('Project facts are unavailable.');
}

function statusCards({ worker, knowledge, knowledgeCheck }, recent) {
  const confirmed = knowledge?.revision && knowledgeCheck?.target === knowledge.revision && knowledgeCheck.stale === false;
  const stale = knowledgeCheck?.stale === true || (knowledge?.revision && knowledgeCheck?.target && knowledgeCheck.target !== knowledge.revision);
  const knowledgeState = confirmed ? 'Matches last main check' : stale ? 'Behind last main check' : 'Freshness unrecorded';
  const source = el('article', [
    el('div', [el('h2', 'Indexed game'), chip(knowledgeState, stale ? 'caution' : confirmed ? 'good' : '')], 'heading'),
    el('p', commit(knowledge?.revision), 'large'),
    muted(knowledge ? counted(knowledge.files, 'file') + ' · ' + counted(knowledge.functions, 'browsable function') : 'Worker index unavailable'),
    pairs([
      ['Index refreshed', fmtTime(knowledge?.indexedAt)],
      ...(knowledge && knowledge.manifestFunctions !== knowledge.functions ? [
        ['Functions in source manifest', fmt(knowledge.manifestFunctions)],
      ] : []),
      ['Last observed main', commit(knowledgeCheck?.target)],
      ['Indexed dependency references', fmt(knowledge?.dependencies)],
      [knowledgeCheck?.via === 'brief' ? 'Brief recorded' : 'Main checked', fmtTime(knowledgeCheck?.observedAt)],
    ]),
  ], 'status-card primary');
  const workerState = worker ? label(worker.phase) : 'Runtime unreported';
  const service = el('article', [
    el('div', [el('h2', 'GPU worker'), chip(workerState, worker?.phase === 'watching' ? 'good' : 'caution')], 'heading'),
    el('p', worker?.model ?? recent?.model ?? 'Model unrecorded', 'large'),
    muted(worker?.model ? 'Model from the worker heartbeat' : 'Model from the last published brief, when recorded'),
    pairs([
      ['Deployed revision', commit(worker?.release)],
      ['Configured retrieval', label(worker?.configuredMode)],
      ['Model digest', worker?.modelDigest?.slice(0, 12) ?? 'Unrecorded'],
      ['Single-issue canary', worker?.canary == null ? 'Unrecorded' : worker.canary ? 'Configured' : 'Off'],
      ...(worker?.issue ? [['Processing', anchor('#' + worker.issue, repository + '/issues/' + worker.issue)]] : []),
      ...(worker?.gpu ? [['GPU utilization', fmt(worker.gpu.utilization) + '%'],
        ['VRAM', fmt(worker.gpu.usedMiB) + ' / ' + fmt(worker.gpu.totalMiB) + ' MiB']] : []),
      ...(worker?.warning ? [['Warning', worker.warning === 'github-queue' ? 'GitHub queue check failed' : 'GitHub outcome collection failed']] : []),
      ['Heartbeat', fmtTime(worker?.observedAt)],
    ]),
  ], 'status-card');
  return el('div', [source, service], 'status-grid');
}

function overviewMetrics(data) {
  const { briefs, learning } = data;
  if (data.role !== 'reviewer') return el('div', [
    metric('Published briefs', briefs?.published.briefs, 'Guarded GitHub handoffs'),
    metric('Issues with a brief', briefs?.published.issues, 'Unique published issues'),
    metric('Indexed files', data.knowledge?.files, 'Authoritative worker store'),
    metric('Functions', data.knowledge?.functions, 'Browsable declarations'),
  ], 'metrics');
  const corrections = learning?.metrics.humanCorrections;
  return el('div', [
    metric('Generated briefs', briefs?.collected, fmt(briefs?.published.briefs) + ' published'),
    metric('Completed tasks', learning?.completed, 'Recorded outcomes'),
    metric('Human corrections', corrections?.total,
      corrections?.recorded ? counted(corrections.recorded, 'outcome') + ' measured' : 'No measurement recorded'),
    metric('Approved examples', learning?.approved, 'Published captures with approval'),
  ], 'metrics');
}

function recentBriefs(value, limit = value.briefs.length) {
  return value.briefs.length ? table(['Issue', 'Game revision', 'Retrieval', 'Model', 'Recorded'],
    value.briefs.slice(0, limit).map(row => [
      anchor('#' + row.issue, '#retrieval?issue=' + row.issue, false),
      commit(row.revision), label(row.mode), row.model ?? 'Unrecorded', fmtTime(row.recordedAt),
    ])) : notice('No published briefs on this page.');
}

function generationUsage(briefs) {
  const metrics = briefs?.metrics;
  return metrics ? pairs([
    ['Input tokens', measurementCell(metrics.inputTokens)],
    ['Output tokens', measurementCell(metrics.outputTokens)],
  ]) : notice('Generation usage is unavailable.');
}

function modeStats(briefs) {
  if (!briefs?.modes.length) return notice('No brief measurements are available.');
  const average = item => item.recorded ? fmtMillis(item.total / item.recorded) : '—';
  return table(['Mode', 'Briefs', 'Published', 'Guard blocked', 'Retrieval avg', 'Model avg'],
    briefs.modes.map(row => [label(row.mode), fmt(row.briefs), fmt(row.published),
      row.guardRecorded ? fmt(row.blocked) + ' / ' + fmt(row.guardRecorded) : '—',
      average(row.metrics.retrievalMs), average(row.metrics.generationMs)]));
}

async function viewOverview(data) {
  const recent = await api('briefs').catch(() => null);
  const extra = data.role === 'reviewer' ? [
    el('div', [
      panel('Project facts', 'From files in the indexed revision.', [factList(data.knowledge)]),
      panel('GPU token usage', 'Totals across captures with recorded Ollama usage.', [generationUsage(data.briefs)]),
    ], 'two-cols'),
    panel('Retrieval performance', 'Average timings use captures that recorded that stage.', [modeStats(data.briefs)]),
  ] : [panel('Project facts', 'From files in the indexed revision.', [factList(data.knowledge)])];
  return [...heading('Worker overview', 'Source freshness, brief generation and development outcomes.'),
    statusCards(data, recent?.briefs[0]), overviewMetrics(data), ...extra,
    panel('Recent briefs', 'Published handoffs linked to their pinned game revision.',
      [recent ? recentBriefs(recent, 6) : notice('Published brief data is temporarily unavailable.')],
      anchor('Browse retrieval', '#retrieval', false))];
}

function searchField(labelText, field, grow = false) {
  return el('label', [labelText, field], 'field' + (grow ? ' grow' : ''));
}

async function viewKnowledge(data) {
  const results = await api('knowledge', search);
  const box = el('input');
  box.type = 'search';
  box.value = search.q;
  box.maxLength = 80;
  box.placeholder = 'e.g. riverbank park, build_railing';
  const kind = el('select', ['files', 'functions'].map(key => {
    const option = el('option', key === 'files' ? 'Files' : 'Functions');
    option.value = key;
    return option;
  }));
  kind.value = search.kind;
  const submit = el('button', 'Search', 'button');
  const form = el('form', [searchField('Browse', kind), searchField('Path or symbol', box, true), submit], 'controls');
  form.addEventListener('submit', event => {
    event.preventDefault();
    Object.assign(search, { q: box.value.trim(), kind: kind.value, page: 0 });
    render();
  });
  const rows = results.rows.map(item => results.kind === 'files' ? [
    codeLink(results.revision, item.path), fmt(item.functions), fmt(item.size) + ' bytes',
  ] : [codeLink(results.revision, item.path, item.line, item.name), el('code', item.path), fmt(item.line)]);
  return [...heading('Game knowledge', 'Browse the canonical GitHub-pinned index.'),
    panel('Source lookup', null, [form, muted(fmt(results.total) + ' matches'),
      rows.length ? table(results.kind === 'files' ? ['File', 'Functions', 'Size'] : ['Function', 'File', 'Line'], rows) :
        notice('No indexed results match this search.'),
      pager(results.page, (results.page + 1) * 24 < results.total, next => { search.page = next; render(); })],
    commit(results.revision)),
    panel('Project facts', 'From the latest committed source index.', [factList(data.knowledge)])];
}

function retrievalDetail(result, reviewer) {
  const { briefVersion, counts, sources, revision, mode, exportPassed, stale } = result;
  const citation = sources.length ? table(['Cited source', 'Symbol', 'Role', 'Line', 'Relevance'], sources.map(row => [
    codeLink(revision, row.path, row.line), row.symbol ?? '—', label(row.kind), fmt(row.line),
    row.score == null ? '—' : decimal.format(row.score),
  ])) : notice('No pinned source citations were recorded for this brief.');
  const info = pairs([
    ['Game revision', commit(revision)], ['Retrieval mode', label(mode)], ['Brief version', briefVersion ?? 'Unrecorded'],
    ['Source refresh', stale === null ? 'Unrecorded' : stale ? 'Stale at generation' : 'Fresh at generation'],
    ['Export check', exportPassed === null ? 'Unrecorded' : exportPassed ? 'Passed' : 'Blocked'],
    ['Verified lesson section', result.lessonRendered ? 'Included' : 'Not recorded'],
    ...(reviewer && result.review ? [['Human feedback entries', fmt(result.review.feedback)],
      ['Training target approval', result.review.approved ? 'Approved' : 'Not recorded']] : []),
  ]);
  return [
    panel('Issue #' + result.issue, fmtTime(result.recordedAt), [info,
      el('div', Object.entries(counts).map(([key, count]) => chip(label(key) + ' · ' + count)), 'tags')],
    anchor('Published GitHub brief', result.url)),
    ...(reviewer ? [panel('Recorded brief usage', result.model ?? 'Model unrecorded', [pairs([
      ['Input tokens', fmt(result.metrics?.inputTokens)], ['Output tokens', fmt(result.metrics?.outputTokens)],
      ['Model time', fmtMillis(result.metrics?.generationMs)],
      ['Retrieval time', fmtMillis(result.metrics?.retrievalMs)],
    ])])] : []),
    panel('Citations at generation', 'Links use the captured revision. Excerpts and private history stay in the local inbox.', [citation]),
  ];
}

function issueBrief(row) {
  if (!row.brief) {
    if (row.queued) return 'Waiting for a brief';
    return row.state === 'open' ? 'Outside worker queue' : 'No published brief';
  }
  const github = anchor('GitHub brief', row.brief);
  if (row.localCapture === null) return [github, ' · Local capture unavailable'];
  if (!row.localCapture) return [github, ' only'];
  return [github, ' · ', anchor('Inspect saved evidence', '#retrieval?issue=' + row.issue, false)];
}

async function viewIssues() {
  const issues = await api('issues', { page: issuePage }).catch(() => null);
  const tracker = anchor('Open GitHub tracker', repository + '/issues');
  const title = heading('GitHub issues', 'GitHub issue status and GPU brief coverage.');
  if (!issues) return [...title, panel('Issue list', null,
    [notice('GitHub issue data is temporarily unavailable.', true)], tracker)];
  const pullStages = { draft: 'Draft', review: 'Open for review', closed: 'Closed without merge', merged: 'Merged into main' };
  const rows = issues.rows.map(row => [
    anchor('#' + row.issue + (row.title ? ' ' + row.title : ''), repository + '/issues/' + row.issue),
    [row.state === 'open' ? 'Open' : 'Closed', row.discord ? [' · ', anchor('Discord report', row.discord)] : null,
      row.assigned ? ' · Assigned on GitHub' : null].flat(), issueBrief(row),
    row.pull ? [anchor('PR #' + row.pull.number, repository + '/pull/' + row.pull.number), ' · ' + pullStages[row.pull.state]] : '—',
    [row.outcome?.pull ? anchor(label(row.outcome.verification), row.outcome.pull) : 'Playtest unrecorded',
      row.githubOutcome ? el('div', [counted(row.githubOutcome.files, 'changed file'), ' · ',
        fmt(row.githubOutcome.passed) + '/' + fmt(row.githubOutcome.checks) + ' checks passed · ' +
        counted(row.githubOutcome.corrections, 'inline comment')], 'muted') : null],
  ]);
  return [...title, panel('Issue list', counted(issues.total, 'issue') + ' · ' + fmt(issues.open) + ' open · Checked ' + fmtTime(issues.checkedAt), [
    issues.stale ? notice('Showing the last successful GitHub check.', true) : null,
    rows.length ? table(['Issue', 'Intake and assignment', 'GPU brief and evidence', 'Implementation PR', 'Recorded verification'], rows)
      : notice('No issues on this page.'),
    pager(issues.page, issues.more, next => { issuePage = next; render(); }),
  ], tracker)];
}

async function viewRetrieval(data, params) {
  const issue = params.get('issue') ?? '';
  const input = el('input');
  input.type = 'number';
  input.min = '1';
  input.step = '1';
  input.required = true;
  input.value = issue;
  const form = el('form', [searchField('GitHub issue number', input), el('button', 'Inspect brief', 'button')], 'controls');
  form.addEventListener('submit', event => {
    event.preventDefault();
    const address = '#retrieval?issue=' + input.value;
    if (location.hash === address) render();
    else location.hash = address;
  });
  let detail = [];
  if (issue) {
    try { detail = retrievalDetail((await api('retrieval', { issue })).result, data.role === 'reviewer'); }
    catch (error) { detail = [notice(error.message, true)]; }
  }
  const recent = await api('briefs', { page: briefPage });
  return [...heading('Retrieval', 'Inspect the evidence selected for a published brief.'),
    panel('Find a brief', null, [form], data.role === 'reviewer' ? anchor('GitHub issue coverage', '#issues', false)
      : anchor('Open GitHub tracker', repository + '/issues')), ...detail,
    panel('Published briefs', null, [recentBriefs(recent),
      pager(recent.page, recent.more, next => { briefPage = next; render(); })])];
}

function lessonCard(item) {
  const published = [anchor('Issue #' + item.issue, repository + '/issues/' + item.issue), ' · ', anchor('PR #' + item.pull, repository + '/pull/' + item.pull)];
  const descriptions = [['Earlier approach', item.failedApproach], ['Merged solution', item.successfulApproach],
    ['Review feedback', item.review], ['Verification', item.verification]];
  return el('article', [
    el('h3', item.title ?? 'Historical lesson'),
    el('div', [chip(item.state === 'verified' ? 'Source verified' : 'Revalidation needed', item.state === 'verified' ? 'good' : 'caution'), ...published], 'tags'),
    el('dl', descriptions.filter(([, value]) => value).flatMap(([key, value]) => [el('dt', key), el('dd', value)])),
  ], 'lesson');
}

async function viewLearning(data) {
  const { catalogue, development } = await api('learning', { page: outcomePage });
  const { briefs, learning } = data;
  const rates = learning?.modes.length ? table(['Mode', 'Completed', 'First pass', 'First fail', 'Unverified'],
    learning.modes.map(row => [label(row.mode), fmt(row.completed), fmt(row.passed), fmt(row.failed), fmt(row.completed - row.passed - row.failed)])) :
    null;
  const outcomes = development?.outcomes.length ? table(['Task', 'Mode', 'First attempt', 'Verification', 'Corrections', 'Development', 'Review'],
    development.outcomes.map(row => [anchor('#' + row.issue, row.prUrl), label(row.mode), label(row.firstAttempt), label(row.verification),
      fmt(row.corrections), fmtSeconds(row.developmentSeconds), fmtSeconds(row.reviewSeconds)])) :
    notice(development ? 'No outcome entries on this page.' : 'Development outcomes are unavailable.');
  const tokens = learning?.metrics;
  return [...heading('Learning', 'Training captures, verified lessons and reviewed development outcomes.'),
    el('div', [
      metric('Collected examples', briefs?.collected, 'Saved generation captures'),
      metric('Approved examples', learning?.approved, 'Explicit human approvals'),
      metric('Feedback entries', learning?.feedback, 'Recorded review notes'),
      metric('Completed tasks', learning?.completed, 'Latest outcome per issue'),
    ], 'metrics'),
    el('div', [
      panel('Verified historical lessons', catalogue ? 'Checked against ' + short(catalogue.revision) + '.' : 'Source verification unavailable.', [
        ...(learning ? [muted(counted(learning.lessonsUsed, 'published brief') + (learning.lessonsUsed === 1 ? ' includes' : ' include') + ' a verified lesson.')] : []),
        ...(catalogue?.items.length ? catalogue.items.map(lessonCard) : [notice('No curated lessons are available.')]),
      ]),
      panel('Model fine-tuning', data.training ? fmtTime(data.training.observedAt) : null, data.training ? [
        chip(trainingLabels[data.training.phase] ?? 'Unrecorded'), pairs([
          ['Eligible dataset', data.training.required == null ? fmt(data.training.examples) :
            fmt(data.training.examples) + ' / ' + fmt(data.training.required)],
          ['Progress', data.training.steps ? fmt(data.training.step) + ' / ' + fmt(data.training.steps) : '—'],
          ['Candidate model', data.training.candidate ?? '—'], ['Evaluation cases', fmt(data.training.cases)],
          ...(data.training.baselineScore == null ? [] : [['Baseline score', fmt(data.training.baselineScore) + '%'],
            ['Candidate score', fmt(data.training.candidateScore) + '%']]),
        ]),
      ] : [notice('No fine-tuning status recorded.')]),
    ], 'two-cols'),
    panel('Development outcomes', 'Reviewers enter outcomes after completing a task.', [rates, outcomes,
      development ? pager(development.page, development.more, next => { outcomePage = next; render(); }) : null]),
    panel('Coding-agent token usage', 'Totals use latest outcomes with recorded measurements.', tokens ? [pairs([
      ['Input tokens', measurementCell(tokens.inputTokens)], ['Cached input tokens', measurementCell(tokens.cachedInputTokens)],
      ['Output tokens', measurementCell(tokens.outputTokens)], ['Reasoning tokens', measurementCell(tokens.reasoningTokens)],
    ])] : [notice('Development usage is unavailable.')])];
}

function route() {
  const [view, query] = location.hash.slice(1).split('?', 2);
  return { view: ['knowledge', 'issues', 'retrieval', 'learning'].includes(view) ? view : 'overview', params: new URLSearchParams(query) };
}

async function render(force = false) {
  const id = ++serial;
  const { view, params } = route();
  page.setAttribute('aria-busy', 'true');
  refresh.disabled = true;
  try {
    const overview = force || !lastOverview || view === 'overview' ? await api('overview') : lastOverview;
    if (id !== serial) return;
    lastOverview = overview;
    document.querySelector('#role').textContent = overview.role === 'reviewer' ? 'Reviewer access' : 'Viewer access';
    for (const link of nav) {
      link.hidden = reviewerViews.has(link.dataset.page) && overview.role !== 'reviewer';
      if (link.dataset.page === view) link.setAttribute('aria-current', 'page');
      else link.removeAttribute('aria-current');
    }
    const content = reviewerViews.has(view) && overview.role !== 'reviewer'
      ? heading(view === 'issues' ? 'GitHub issues' : 'Learning', 'Reviewer access required.')
      : view === 'knowledge' ? await viewKnowledge(overview)
      : view === 'issues' ? await viewIssues()
      : view === 'retrieval' ? await viewRetrieval(overview, params)
      : view === 'learning' ? await viewLearning(overview)
      : await viewOverview(overview);
    if (id !== serial) return;
    page.replaceChildren(...content);
    loaded.textContent = 'Worker data loaded ' + fmtTime(new Date().toISOString());
  } catch (error) {
    if (id !== serial) return;
    page.replaceChildren(...heading('GPU dashboard', 'The requested view could not be loaded.'), notice(error.message, true));
    loaded.textContent = 'Latest request failed';
  } finally {
    if (id === serial) {
      page.setAttribute('aria-busy', 'false');
      refresh.disabled = false;
    }
  }
}

refresh.addEventListener('click', () => render(true));
window.addEventListener('hashchange', () => { if (location.hash !== '#page') render(); });
setInterval(() => {
  if (!document.hidden && ['overview', 'issues', 'learning'].includes(route().view) && !refresh.disabled) render(true);
}, 30_000);
render();
