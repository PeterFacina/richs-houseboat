const byId = id => document.getElementById(id);
const views = [...document.querySelectorAll('.view')];
const tabs = [...document.querySelectorAll('[data-view]')];
const formIds = { title: 'task-title', note: 'task-note', tier: 'task-tier', priority: 'task-priority', tags: 'task-tags', author: 'task-author' };
const statusValues = ['draft', 'generated', 'submitted', 'implemented', 'verified', 'rejected', 'superseded', 'needs revision', 'archived'];
const date = value => new Date(value).toLocaleString([], { dateStyle: 'medium', timeStyle: 'short' });
const size = bytes => (bytes / 1024 ** 3).toFixed(2) + ' GiB';
const sleep = ms => new Promise(resolve => setTimeout(resolve, ms));
const draftKey = 'game-prompt-studio-brief-v1';
let user;
let privateMode = false;
let tailscaleMode = false;
let currentView;
let currentRecord;
let settings;
let job;
let offset = 0;
let fileOptionsLoaded = false;
let staged = [];

function elem(tag, value, className) {
  const element = document.createElement(tag);
  if (value !== undefined) element.textContent = value;
  if (className) element.className = className;
  return element;
}
function appendMessage(box, value) {
  box.append(elem('p', value, 'muted'));
}
function setNotice(value, error = false) {
  const box = byId('notice');
  box.textContent = value;
  box.hidden = !value;
  box.classList.toggle('error', error);
}
function showFailure(error) {
  if (error.findings?.length) showFindings(error.findings);
  setNotice(error.message, true);
}
function showFindings(findings) {
  const box = byId('findings');
  box.hidden = !findings.length;
  box.replaceChildren();
  if (!findings.length) return;
  box.append(elem('strong', 'Review required before export'));
  const list = elem('ul');
  for (const finding of findings) list.append(elem('li', finding));
  box.append(list);
}

async function api(path, method = 'GET', payload) {
  const headers = {};
  if (method !== 'GET') {
    headers['Content-Type'] = 'application/json';
    headers['X-Studio-Request'] = '1';
    if (user) headers['X-Studio-CSRF'] = user.csrf;
  }
  const response = await fetch(path, { method, headers, body: payload === undefined ? undefined : JSON.stringify(payload) });
  const value = await response.json();
  if (!response.ok) {
    if (response.status === 401 && path !== '/api/login') renderSession(null);
    const error = new Error(value.error || 'Request failed.');
    error.findings = value.findings;
    throw error;
  }
  return value;
}

function on(id, event, action) {
  byId(id).addEventListener(event, async e => {
    if (event === 'submit') e.preventDefault();
    try { await action(e); } catch (error) { showFailure(error); }
  });
}

function renderSession(account) {
  user = account;
  byId('nav').hidden = !user;
  byId('login').hidden = tailscaleMode || Boolean(user);
  byId('tailscale-access').hidden = !tailscaleMode || Boolean(user);
  byId('logout').hidden = !privateMode || tailscaleMode || !user;
  byId('author-field').hidden = privateMode;
  for (const control of document.querySelectorAll('.admin-only')) control.hidden = user?.role !== 'admin';
  for (const input of byId('settings-form').querySelectorAll('input,select')) input.disabled = user?.role !== 'admin';
  if (!user) {
    for (const view of views) view.hidden = true;
    currentRecord = null;
    currentView = null;
    fileOptionsLoaded = false;
    byId('compose-form').reset();
    byId('prompt-text').value = '';
    byId('record-outcome').value = '';
    byId('evidence-list').replaceChildren();
    byId('editor').hidden = true;
    byId('empty-output').hidden = false;
    staged = [];
    byId('connection').textContent = 'Private access';
    byId('connection').className = 'badge quiet';
  }
}

async function view(name, focus = true) {
  if (!user) return;
  currentView = name;
  for (const tab of tabs) {
    if (tab.dataset.view === name) tab.setAttribute('aria-current', 'page');
    else tab.removeAttribute('aria-current');
  }
  for (const panel of views) panel.hidden = panel.id !== name;
  if (focus) {
    const heading = byId(name).querySelector('h1');
    heading.tabIndex = -1;
    heading.focus({ preventScroll: true });
    window.scrollTo(0, 0);
  }
  if (name === 'compose') {
    await refreshOverview();
    if (!fileOptionsLoaded) await refreshKnowledge();
  }
  if (name === 'library') await loadLibrary();
  if (name === 'knowledge') await refreshKnowledge();
  if (name === 'imports') await loadImports();
  if (name === 'settings') await showSettings();
}

function readTask() {
  return { ...Object.fromEntries(Object.entries(formIds).map(([key, id]) => [key, byId(id).value])),
    focus: [...byId('task-focus').selectedOptions].map(option => option.value),
    parentId: currentRecord?.id ?? null };
}
function draftState() {
  if (privateMode) return;
  try { sessionStorage.setItem(draftKey, JSON.stringify(readTask())); } catch { /* Storage may be disabled. */ }
}
function restoreDraft() {
  if (privateMode) return;
  try {
    const saved = JSON.parse(sessionStorage.getItem(draftKey));
    if (saved) {
      for (const [key, id] of Object.entries(formIds)) if (typeof saved[key] === 'string') byId(id).value = saved[key];
      for (const option of byId('task-focus').options) option.selected = saved.focus?.includes(option.value);
    }
  } catch { /* An invalid browser draft is safe to ignore. */ }
}
function clearTask() {
  if (job) return;
  if (hasEdits() && !window.confirm('Discard the unsaved prompt edits?')) return;
  currentRecord = null;
  byId('compose-form').reset();
  byId('task-tier').value = settings?.tier ?? 'detailed';
  byId('editor').hidden = true;
  byId('prompt-status').hidden = true;
  byId('empty-output').hidden = false;
  byId('prompt-meta').textContent = 'Your generated brief will appear here.';
  byId('evidence-list').replaceChildren();
  appendMessage(byId('evidence-list'), 'Generate or open a saved prompt to inspect its context.');
  setNotice('');
  draftState();
  byId('task-note').focus();
}

function populateOptions(element, values, makeLabel = value => value) {
  element.replaceChildren(...values.map(value => new Option(makeLabel(value), value)));
}
function row(title, description) {
  const node = elem('div', undefined, 'row');
  node.append(elem('strong', title));
  if (description) node.append(elem('p', description));
  return node;
}
function sourceCard(source) {
  const node = elem('details', undefined, 'source-card');
  const label = source.kind === 'source' ? source.path + ':' + source.line : source.title;
  const kind = { source: 'Indexed source', reported: 'Historical player report · unverified',
    imported: 'Imported history · unverified', history: 'Studio history · user-reported', attachment: 'Screenshot description · user-reported' }[source.kind];
  node.append(elem('summary', source.id + ' · ' + label), elem('p', [kind, source.reason, source.provenance?.author, source.provenance?.label].filter(Boolean).join(' · '), 'muted'), elem('pre', source.excerpt));
  return node;
}
async function loadRecord(id, showTask = true) {
  const record = await api('/api/prompts/' + id);
  currentRecord = record;
  if (showTask) {
    for (const [key, field] of Object.entries(formIds)) byId(field).value = record[key] ?? '';
    const focus = new Set(record.evidence.filter(item => item.reason === 'Selected file').map(item => item.path));
    for (const option of byId('task-focus').options) option.selected = focus.has(option.value);
  }
  byId('prompt-text').value = record.prompt;
  byId('record-status').value = record.status;
  byId('record-outcome').value = record.outcome;
  byId('prompt-status').textContent = record.status;
  byId('prompt-status').className = 'badge ' + (record.findings.length ? 'warn' : 'quiet');
  byId('prompt-status').hidden = false;
  const rate = record.generation.tokensPerSecond;
  const seconds = record.generation.durationMs ? (record.generation.durationMs / 1000).toFixed(1) + ' s' : '';
  byId('prompt-meta').textContent = [record.model || 'Saved note', 'Revision ' + record.revision, seconds,
    rate ? rate + ' tokens/s' : ''].filter(Boolean).join(' · ');
  byId('editor').hidden = false;
  byId('empty-output').hidden = true;
  showFindings(record.findings);
  const evidence = byId('evidence-list');
  evidence.replaceChildren(...record.evidence.map(sourceCard));
  if (!record.evidence.length) appendMessage(evidence, 'No relevant source excerpts were retrieved for this record.');
  byId('download').disabled = !record.prompt.trim();
  byId('copy').disabled = !record.prompt.trim();
  await loadAttachments(id);
  const revisionList = await api('/api/prompts/' + id + '/revisions');
  byId('revision-list').textContent = revisionList.slice(0, 4)
    .map(entry => 'Revision ' + entry.revision + ' · ' + entry.changed_by + ' · ' + date(entry.created_at)).join('  /  ');
}

async function loadAttachments(id) {
  const path = '/api/prompts/' + id + '/attachments';
  const entries = await api(path);
  if (currentRecord?.id !== id) return;
  const list = byId('attachment-list');
  list.replaceChildren();
  for (const entry of entries) {
    const item = elem('figure', undefined, 'attachment');
    const image = elem('img');
    image.src = path + '/' + entry.id;
    image.alt = entry.description || entry.name;
    image.loading = 'lazy';
    const caption = elem('figcaption', entry.name + ' · ' + entry.origin);
    item.append(image, caption);
    if (entry.description) caption.append(elem('p', entry.description));
    if (user.role === 'admin' || entry.actor === user.name) {
      const remove = elem('button', 'Remove screenshot', 'subtle');
      remove.type = 'button';
      remove.addEventListener('click', async () => {
        if (!window.confirm('Remove this screenshot from the saved record?')) return;
        try { await api(path + '/' + entry.id, 'DELETE'); await loadAttachments(id); }
        catch (error) { showFailure(error); }
      });
      item.append(remove);
    }
    list.append(item);
  }
  byId('attachment-form').hidden = entries.length >= 4;
  if (!entries.length) appendMessage(list, 'No screenshots attached.');
}
async function imageForUpload(file) {
  if (!file || file.size > 10 * 1024 * 1024 || !/\.(png|jpe?g|webp)$/i.test(file.name)) {
    throw new Error('Choose a PNG, JPEG, or WebP file up to 10 MiB.');
  }
  let bitmap;
  try { bitmap = await createImageBitmap(file); }
  catch { throw new Error('The browser could not decode this image.'); }
  try {
    const scale = Math.min(1, 1920 / bitmap.width, 1200 / bitmap.height);
    const canvas = elem('canvas');
    canvas.width = Math.max(1, Math.round(bitmap.width * scale));
    canvas.height = Math.max(1, Math.round(bitmap.height * scale));
    canvas.getContext('2d').drawImage(bitmap, 0, 0, canvas.width, canvas.height);
    return canvas.toDataURL('image/png').split(',')[1];
  } finally { bitmap.close(); }
}
async function refreshOverview() {
  const data = await api('/api/overview');
  settings = data.settings;
  byId('record-count').textContent = data.records;
  byId('file-count').textContent = data.index?.indexed ?? '—';
}
async function refreshModel() {
  const data = await api('/api/model');
  byId('connection').textContent = data.online ? 'Ollama online' : 'Ollama offline';
  byId('connection').className = data.online ? 'badge' : 'badge warn';
  const box = byId('model-details');
  box.replaceChildren();
  if (!data.online) return appendMessage(box, data.error);
  populateOptions(byId('model-options'), data.models.map(item => item.name));
  box.append(row('Ollama ' + data.version, 'Inference endpoint runs on the host. ' + data.models.length + ' local model(s) found.'));
  for (const model of data.models) {
    const loaded = data.loaded.find(item => item.name === model.name);
    const gpu = loaded?.vram != null && loaded?.size ? Math.round(100 * loaded.vram / loaded.size) + '% GPU · ' + size(loaded.vram) + ' VRAM' : '';
    box.append(row(model.name, [model.quantization, model.bytes ? size(model.bytes) + ' on disk' : '',
      loaded ? [gpu, loaded.context ? loaded.context + ' context tokens' : ''].filter(Boolean).join(' · ') || 'Loaded' : 'Idle'].filter(Boolean).join(' · ')));
  }
  if (!data.models.length) appendMessage(box, 'Pull qwen3:14b on the host or install another tagged local model.');
}
async function refreshKnowledge() {
  const data = await api('/api/knowledge');
  const previous = [...byId('task-focus').selectedOptions].map(option => option.value);
  populateOptions(byId('task-focus'), data.files.map(file => file.path));
  for (const option of byId('task-focus').options) option.selected = previous.includes(option.value);
  fileOptionsLoaded = true;
  byId('facts-list').replaceChildren(...data.facts.map(item => row(item.fact, item.path + ':' + item.line)));
  if (!data.facts.length) appendMessage(byId('facts-list'), 'No profile facts have been confirmed in the current index.');
  byId('reports-list').replaceChildren(...data.reports.map(report => row(report.title, report.body + '\nHistorical report · master brief · imported ' + date(report.created_at))));
  byId('indexed-list').replaceChildren(...data.files.map(file => row(file.path, Math.ceil(file.size / 1024) + ' KB')));
  byId('ignored-list').replaceChildren(...(data.index?.ignored ?? []).map(item => row(item.path, item.reason)));
  byId('index-details').textContent = data.index ? data.index.indexed + ' files · ' + data.index.changed + ' updated last scan · ' +
    data.index.ignoredCount + ' skipped entries · ' + date(data.index.at) : 'The first scan is pending.';
  byId('file-count').textContent = data.index?.indexed ?? '—';
}
function hasEdits() {
  return currentRecord && (currentRecord.prompt !== byId('prompt-text').value ||
    currentRecord.status !== byId('record-status').value || currentRecord.outcome !== byId('record-outcome').value);
}
async function saveCurrent() {
  if (!currentRecord) return;
  const edit = { prompt: byId('prompt-text').value, status: byId('record-status').value,
    outcome: byId('record-outcome').value, revision: currentRecord.revision };
  currentRecord = await api('/api/prompts/' + currentRecord.id, 'PATCH', edit);
  await loadRecord(currentRecord.id, false);
  setNotice('Saved revision ' + currentRecord.revision + '.');
}
async function loadLibrary() {
  const params = new URLSearchParams(new FormData(byId('search-form')));
  params.set('offset', offset);
  const { records, more } = await api('/api/library?' + params);
  const list = byId('library-list');
  list.replaceChildren();
  for (const entry of records) {
    const card = elem('div', undefined, 'row');
    const button = elem('button', entry.title, 'list-open');
    button.type = 'button';
    button.addEventListener('click', async () => {
      if (job) return setNotice('Wait for the current generation to finish.', true);
      if (hasEdits() && !window.confirm('Discard the unsaved prompt edits?')) return;
      try { await view('compose'); await loadRecord(entry.id); } catch (error) { showFailure(error); }
    });
    card.append(button, elem('p', [entry.status, entry.author, entry.tags, date(entry.updated_at)].filter(Boolean).join(' · ')));
    list.append(card);
  }
  if (!records.length) appendMessage(list, 'No prompts match this search.');
  byId('library-prev').hidden = offset === 0;
  byId('library-more').hidden = !more;
}
async function previewImports(files, label) {
  staged = [];
  byId('import-submit').disabled = true;
  const preview = await api('/api/imports/preview', 'POST', { files });
  staged = files;
  if (label) byId('import-label').value = label;
  byId('import-results').replaceChildren(...preview.map(file => row(file.name + (file.duplicate ? ' · Duplicate' : ''),
    file.characters + ' characters\n' + file.preview)));
  byId('import-submit').disabled = preview.every(file => file.duplicate);
}
async function loadImports() {
  const data = await api('/api/imports');
  byId('import-project').hidden = !data.discovered.length;
  const batches = byId('batches');
  batches.replaceChildren();
  for (const batch of data.batches) {
    const card = row(batch.label, batch.author + ' · ' + batch.count + ' files · ' + date(batch.created_at) + ' · imported by ' + batch.uploaded_by);
    const details = elem('details', undefined, 'extras');
    details.append(elem('summary', 'View originals'));
    details.addEventListener('toggle', async () => {
      if (!details.open || details.dataset.loaded) return;
      try {
        const items = await api('/api/imports/' + batch.id);
        details.dataset.loaded = '1';
        for (const item of items) {
          details.append(elem('h3', item.name), elem('pre', item.body));
        }
      } catch (error) { showFailure(error); }
    });
    card.append(details);
    if (user.role === 'admin') {
      const remove = elem('button', 'Remove batch', 'subtle');
      remove.type = 'button';
      remove.addEventListener('click', async () => {
        if (!window.confirm('Remove this imported batch and its search entries? Saved prompts keep their source snapshots.')) return;
        try { await api('/api/imports/' + batch.id, 'DELETE'); await loadImports(); } catch (error) { showFailure(error); }
      });
      card.append(remove);
    }
    batches.append(card);
  }
  if (!data.batches.length) appendMessage(batches, 'No prompt history has been imported.');
}

async function showSettings() {
  await refreshOverview();
  byId('model-name').value = settings.model;
  byId('model-context').value = settings.context;
  byId('model-keepalive').value = settings.keepAliveMinutes;
  byId('model-tier').value = settings.tier;
  await refreshModel();
}
function setWorking(working) {
  byId('generate').disabled = working;
  byId('cancel').hidden = !working;
  byId('cancel').disabled = false;
  byId('save-draft').disabled = working;
  byId('new-task').disabled = working;
}

for (const tab of tabs) tab.addEventListener('click', () => { setNotice(''); view(tab.dataset.view).catch(showFailure); });
for (const status of statusValues) byId('filter-status').add(new Option(status, status));
populateOptions(byId('record-status'), statusValues);
on('compose-form', 'input', draftState);
on('new-task', 'click', clearTask);
on('compose-form', 'submit', async () => {
  if (job) return;
  if (hasEdits() && !window.confirm('Generate a new prompt before saving these edits?')) return;
  setNotice('');
  const input = readTask();
  setWorking(true);
  const started = Date.now();
  byId('activity').textContent = 'Retrieving project context and starting Ollama…';
  try {
    job = (await api('/api/generate', 'POST', input)).id;
    while (job) {
      const result = await api('/api/jobs/' + job);
      if (result.status === 'complete') {
        if (currentView === 'compose') await loadRecord(result.recordId, false);
        await refreshOverview();
        setNotice(result.findings?.length ? 'Draft saved. Review the export findings.' : 'Prompt generated and saved.');
        void refreshModel().catch(showFailure);
        break;
      }
      if (result.status === 'failed') throw new Error(result.error || 'Generation failed.');
      if (result.status === 'canceled') { setNotice('Generation canceled. Your notes are still available.'); break; }
      byId('activity').textContent = (result.status === 'canceling' ? 'Canceling' : 'Ollama is generating') +
        ' · ' + Math.round((Date.now() - started) / 1000) + ' s';
      await sleep(750);
    }
  } finally {
    job = null;
    setWorking(false);
    byId('activity').textContent = '';
  }
});
on('cancel', 'click', async () => {
  if (!job) return;
  byId('cancel').disabled = true;
  await api('/api/jobs/' + job + '/cancel', 'POST');
});
on('save-draft', 'click', async () => {
  if (!byId('compose-form').reportValidity()) return;
  if (hasEdits() && !window.confirm('Save these notes as a new record before saving the prompt edits?')) return;
  const record = await api('/api/drafts', 'POST', readTask());
  await loadRecord(record.id, false);
  await refreshOverview();
  setNotice('Note saved to your library.');
});
on('prompt-text', 'input', () => {
  byId('download').disabled = !byId('prompt-text').value.trim();
  byId('copy').disabled = byId('download').disabled;
});
on('save', 'click', saveCurrent);
on('copy', 'click', async () => {
  const prompt = byId('prompt-text').value;
  await api('/api/prompts/' + currentRecord.id + '/check', 'POST', { prompt });
  showFindings([]);
  await navigator.clipboard.writeText(prompt);
  setNotice('Prompt copied.');
});
on('download', 'click', async () => {
  if (hasEdits()) await saveCurrent();
  await api('/api/prompts/' + currentRecord.id + '/check', 'POST', { prompt: currentRecord.prompt });
  const link = elem('a');
  link.href = '/api/prompts/' + currentRecord.id + '/download';
  link.download = '';
  document.body.append(link);
  link.click();
  link.remove();
});
on('attachment-form', 'submit', async ({ target }) => {
  if (!currentRecord) return;
  const id = currentRecord.id;
  const file = byId('attachment-file').files[0];
  const submit = target.querySelector('button');
  submit.disabled = true;
  try {
    const png = await imageForUpload(file);
    await api('/api/prompts/' + id + '/attachments', 'POST', {
      png, name: file.name, origin: byId('attachment-origin').value, description: byId('attachment-description').value
    });
    target.reset();
    await loadAttachments(id);
    setNotice('Screenshot attached.');
  } finally { submit.disabled = false; }
});
on('search-form', 'submit', async () => { offset = 0; await loadLibrary(); });
on('library-prev', 'click', async () => { offset = Math.max(offset - 100, 0); await loadLibrary(); });
on('library-more', 'click', async () => { offset += 100; await loadLibrary(); });
for (const [id, full] of [['scan', false], ['rebuild', true]]) {
  on(id, 'click', async () => {
    byId(id).disabled = true;
    try {
      const result = await api('/api/scan', 'POST', { full });
      await refreshKnowledge();
      setNotice('Indexed ' + result.indexed + ' files. Updated ' + result.changed + '.');
    } finally { byId(id).disabled = false; }
  });
}
on('import-files', 'change', () => {
  staged = [];
  byId('import-results').replaceChildren();
  byId('import-submit').disabled = true;
});
on('import-preview', 'click', async () => {
  const files = [...byId('import-files').files];
  if (!files.length || files.length > 16 || files.some(file => file.size > 240_000)) throw new Error('Select one to sixteen text files within the displayed limit.');
  const decoder = new TextDecoder('utf-8', { fatal: true });
  const entries = [];
  for (const file of files) {
    let body;
    try { body = decoder.decode(await file.arrayBuffer()); } catch { throw new Error(file.name + ' is not UTF-8 text.'); }
    entries.push({ name: file.name, body });
  }
  await previewImports(entries);
});
on('import-project', 'click', async () => {
  await previewImports(await api('/api/imports/discovered'), 'Rich’s Houseboat project notes');
});
on('import-form', 'submit', async () => {
  const result = await api('/api/imports', 'POST', { files: staged, author: byId('import-author').value, label: byId('import-label').value });
  staged = [];
  byId('import-form').reset();
  byId('import-submit').disabled = true;
  byId('import-results').replaceChildren();
  await loadImports();
  setNotice(result.imported + ' imported · ' + result.duplicates + ' duplicate(s).');
});
on('settings-form', 'submit', async () => {
  settings = await api('/api/settings', 'POST', { model: byId('model-name').value.trim(), context: Number(byId('model-context').value),
    keepAliveMinutes: Number(byId('model-keepalive').value), tier: byId('model-tier').value });
  setNotice('Model settings saved.');
});
on('refresh-model', 'click', refreshModel);
on('backup', 'click', async () => {
  const result = await api('/api/backup', 'POST');
  setNotice('Backup saved on the host: ' + result.name);
});
on('login-form', 'submit', async e => {
  const form = new FormData(e.target);
  const account = await api('/api/login', 'POST', { name: form.get('username').trim().toLowerCase(), password: form.get('password') });
  e.target.reset();
  setNotice('');
  renderSession(account);
  await view('compose');
  byId('task-tier').value = settings.tier;
  await refreshModel();
});
on('logout', 'click', async () => {
  await api('/api/logout', 'POST');
  setNotice('');
  renderSession(null);
});

async function start() {
  const session = await api('/api/session');
  privateMode = session.privateMode;
  tailscaleMode = session.tailscaleMode;
  renderSession(session.user);
  if (!user) return;
  await view('compose', false);
  byId('task-tier').value = settings.tier;
  restoreDraft();
  await refreshModel();
}
start().catch(showFailure);
