import assert from 'node:assert/strict';
import { setTimeout as pause } from 'node:timers/promises';
import { config } from '../lib/config.mjs';

const origin = 'http://127.0.0.1:' + config().port;
let csrf;
async function request(path, method = 'GET', payload) {
  const response = await fetch(origin + path, {
    method, headers: method === 'GET' ? {} : {
      'Content-Type': 'application/json', Origin: origin, 'X-Studio-Request': '1', 'X-Studio-CSRF': csrf
    }, body: payload === undefined ? undefined : JSON.stringify(payload)
  });
  const raw = await response.text();
  if (!response.ok) throw new Error(response.status + ' ' + raw);
  return response.headers.get('content-type').includes('json') ? JSON.parse(raw) : raw;
}
csrf = (await request('/api/session')).user.csrf;
if (process.argv[2] === '--verify-restart') {
  const id = Number(process.argv[3]);
  assert.ok(Number.isSafeInteger(id));
  const saved = await request('/api/prompts/' + id);
  assert.ok(saved.note.includes('third-person'));
  assert.ok(saved.prompt.includes('Confirm a guest can see the cooler interaction.'));
  assert.equal(await request('/api/prompts/' + id + '/download'), saved.prompt);
  console.log('Reopened record ' + id + ' after server restart and verified the exact downloaded text.');
} else {
  const status = await request('/api/model');
  if (!status.online) throw new Error(status.error);
  const index = await request('/api/knowledge');
  assert.ok(index.index.indexed > 0);
  const available = new Set(index.files.map(row => row.path));
  const task = {
    title: 'Multiplayer hands and held props',
    note: 'My friends can’t see my hands when I fish, open the cooler, drink, take a bong toke or hit my pen. My grips look goofy. Check everybody’s third-person view from both host and guest and make sure the first-person grips still line up.',
    tier: 'detailed', priority: 'High', tags: 'multiplayer, props', author: 'Studio validation',
    focus: ['godot-cove/crew_avatar.gd', 'godot-cove/multiplayer_session.gd', 'godot-cove/fishing_rig.gd'].filter(path => available.has(path))
  };
  const { id } = await request('/api/generate', 'POST', task);
  let job;
  for (let step = 0; step < 250; step++) {
    job = await request('/api/jobs/' + id);
    if (job.status !== 'working') break;
    await pause(1000);
  }
  assert.equal(job.status, 'complete', job.error);
  const record = await request('/api/prompts/' + job.recordId);
  assert.equal(record.note, task.note);
  assert.ok(record.evidence.some(item => item.kind === 'source'));
  assert.ok(record.prompt.length > 500);
  console.log(JSON.stringify({ id: record.id, model: record.model, index: index.index.indexed, metrics: record.generation,
    findings: record.findings, evidence: record.evidence.map(({ id, path, kind }) => ({ id, path, kind })), draft: record.prompt }, null, 2));
  assert.deepEqual(record.findings, []);
  const prompt = record.prompt + '\nConfirm a guest can see the cooler interaction.\n';
  const saved = await request('/api/prompts/' + record.id, 'PATCH', { prompt, status: 'generated', outcome: '', revision: record.revision });
  assert.equal(saved.prompt, prompt);
  assert.equal(await request('/api/prompts/' + record.id + '/download'), prompt);
  const current = await request('/api/model');
  console.log(JSON.stringify({ loaded: current.loaded, available: current.models }, null, 2));
}
