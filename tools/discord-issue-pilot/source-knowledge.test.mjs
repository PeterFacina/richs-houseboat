import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, renameSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import { pathToFileURL } from 'node:url';
import test from 'node:test';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { findEvidence, indexedKnowledge, recentScan } from '../game_prompt_studio/lib/index.mjs';
import { processGpuIssue } from './gpu-queue.mjs';
import { sourceKnowledge } from './source-knowledge.mjs';
import { openTrainingInbox } from './training-inbox.mjs';
import { workerGeneration } from './worker-generation.mjs';
import { candidateBrief, candidateRetrieval, originalRetrieval, retrievalConfig, verificationGuidance } from './production-retrieval.mjs';
import { gpuBriefMarker, gpuPendingMarker, reportHeader, reportKinds } from './workflow.mjs';

const note = 'Why does passive water velocity drift affect the houseboat?';
const model = 'qwen3:14b';

test('pinned refresh, persistent fallback, and queued brief provenance', async t => {
  const root = mkdtempSync(join(tmpdir(), 'houseboat-knowledge-test-'));
  const game = join(root, 'game');
  const upstream = join(root, 'upstream.git');
  const remote = pathToFileURL(upstream).href;
  const storage = join(root, 'cache');
  const options = { storage, remote, python: process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python',
    log: { info() {}, warn() {} } };
  const git = (cwd, ...args) => execFileSync('git', args, { cwd, encoding: 'utf8', stdio: ['ignore', 'pipe', 'pipe'] }).trim();
  const put = (path, content) => {
    const file = join(game, path);
    mkdirSync(dirname(file), { recursive: true });
    writeFileSync(file, content);
  };
  const commit = () => {
    git(game, 'add', '--all');
    git(game, 'commit', '-m', 'Update fixture');
    git(game, 'push', remote, 'main');
    return git(game, 'rev-parse', 'HEAD');
  };
  let db;
  let generation;
  let inbox;
  try {
    mkdirSync(game);
    git(game, 'init', '-b', 'main');
    git(game, 'config', 'user.name', 'Test');
    git(game, 'config', 'user.email', 'test@example.invalid');
    git(root, 'init', '--bare', upstream);
    git(upstream, 'config', 'uploadpack.allowFilter', 'true');
    put('godot-cove/project.godot', 'run/main_scene="res://title.tscn"\n');
    put('godot-cove/title.tscn', '[gd_scene]\n');
    put('godot-cove/boat.gd', '# houseboat\nfunc passive_water_velocity():\n  return preload("res://drift.gd")\n');
    put('godot-cove/deleted.gd', 'func formerly_here():\n  pass\n');
    put('docs/ARCHITECTURE.md', '# Architecture\n');
    put('docs/systems/BOAT-WATER.md', 'Passive velocity and houseboat drift [Boat](../../godot-cove/boat.gd)\n');
    put('docs/systems/PROGRESSION.md', 'Experience points and the progression ledger.\n');
    put('godot-cove/ottawa/generated.gd', 'func generated_terrain():\n  pass\n');
    const first = commit();
    db = openDb(storage);
    let knowledge = sourceKnowledge({ ...options, db });
    const concurrent = knowledge.refresh();
    assert.equal(knowledge.refresh(), concurrent);
    assert.equal((await concurrent).commit, first);
    assert.equal(indexedKnowledge(db).files['godot-cove/ottawa/generated.gd'], undefined);
    assert.equal(findEvidence(db, note, [], 4000, { manifest: indexedKnowledge(db),
      selection: await knowledge.select(note, []) })[0].title, 'passive_water_velocity');
    assert.equal(recentScan(db).revision, first);
    assert.equal((await knowledge.refresh()).stale, false);

    put('godot-cove/drift.gd', '# passive water velocity drift adjustment\n');
    put('godot-cove/nested/current.gd', '# tracked nested source\n');
    rmSync(join(game, 'godot-cove/deleted.gd'));
    const second = commit();
    const failing = sourceKnowledge({ ...options, db, python: 'missing-test-python-command' });
    assert.deepEqual(await failing.refresh(), { commit: first, target: second, stale: true, step: 'index pinned source' });
    assert.ok(indexedKnowledge(db).files['godot-cove/deleted.gd']);
    db.close();
    db = openDb(storage);
    knowledge = sourceKnowledge({ ...options, db });
    renameSync(upstream, upstream + '.offline');
    assert.equal((await knowledge.refresh()).commit, first);
    assert.equal((await knowledge.refresh()).stale, true);
    renameSync(upstream + '.offline', upstream);
    const started = performance.now();
    assert.equal((await knowledge.refresh()).commit, second);
    t.diagnostic('Synthetic incremental refresh after offline restart: ' + Math.round(performance.now() - started) + ' ms');
    assert.equal(recentScan(db).changed, 2);
    assert.equal(recentScan(db).removed, 1);
    const manifest = indexedKnowledge(db);
    assert.equal(manifest.files['godot-cove/deleted.gd'], undefined);
    assert.ok(manifest.files['godot-cove/nested/current.gd']);
    assert.deepEqual(manifest.files['godot-cove/boat.gd'].references, ['godot-cove/drift.gd']);

    const issue = { number: 110, state: 'open', html_url: 'https://example.invalid/issues/110', body:
      reportHeader('gameplay') + note + '\n\nDiscord report: https://discord.com/channels/11/22/33\n\n## Done when\n\n' +
      reportKinds.gameplay.done + '\n\n' + gpuPendingMarker + '\n<!-- discord-pilot:33 -->' };
    const canaryIssue = { ...issue, number: 115, html_url: 'https://example.invalid/issues/115',
      body: issue.body.replace(reportHeader('gameplay'), reportHeader('notes')).replace(reportKinds.gameplay.done, reportKinds.notes.done) };
    const comments = [];
    const canaryComments = [];
    const github = async (path, method, payload) => {
      if (path === '/issues/110') return issue;
      if (path === '/issues/115') return canaryIssue;
      if (path.startsWith('/issues?')) return [{ number: 111, title: 'Houseboat drift telemetry' }];
      if (path.startsWith('/pulls?')) return [{ number: 112, draft: true, title: 'Passive water velocity review' }];
      assert.match(path, /^\/issues\/(110|115)\/comments/);
      const isCanary = path.startsWith('/issues/115/');
      const posts = isCanary ? canaryComments : comments;
      if (method !== 'POST') return posts;
      assert.match(payload.body, new RegExp('^' + gpuBriefMarker + '\\n\\nGame knowledge revision ' + (isCanary ? third : second)));
      const comment = { ...payload, author_association: 'COLLABORATOR', html_url: (isCanary ? canaryIssue : issue).html_url + '#comment' };
      posts.push(comment);
      return comment;
    };
    inbox = openTrainingInbox(join(root, 'training.sqlite'));
    let enterModel;
    let releaseModel;
    const modelEntered = new Promise(resolve => { enterModel = resolve; });
    const modelReleased = new Promise(resolve => { releaseModel = resolve; });
    let request;
    const section = ['Check houseboat drift using [S1].'];
    let unsafe = false;
    generation = await workerGeneration({ storage, model, knowledge, github, inbox,
      retrieval: retrievalConfig(candidateRetrieval, '115'), async fetchOllama(url, init) {
      if (url.endsWith('/api/tags')) return Response.json({ models: [{ name: model, digest: 'model-fixture' }] });
      assert.ok(url.endsWith('/api/chat'));
      request = JSON.parse(init.body);
      enterModel();
      await modelReleased;
      return Response.json({ prompt_eval_count: 520, eval_count: 83, message: { content: JSON.stringify({
        objective: section, observations: ['How does drift change?'], tasks: unsafe ? ['Inspect nonexistent.gd.'] : section,
        verification: section, acceptance: section, unknowns: section,
      }) } });
    } });
    const processing = processGpuIssue(issue, github, generation.generate, inbox.link);
    // Propagate a generation failure even if it occurs before the provider hook.
    await Promise.race([modelEntered, processing]);
    put('godot-cove/boat.gd', 'func follow_new_current():\n  pass\n');
    const third = commit();
    try {
      await assert.rejects(generation.generate(note, issue), /already processing/);
      assert.equal(indexedKnowledge(db).revision, second);
    } finally {
      releaseModel();
    }
    assert.equal((await processing).status, 'posted');
    assert.equal((await processGpuIssue(issue, github, generation.generate, inbox.link)).status, 'already posted');
    assert.equal(comments.length, 1);
    const capture = inbox.read(issue.number).captures[0];
    assert.equal(capture.published, comments[0].html_url);
    assert.equal(capture.input.report, note);
    assert.equal(capture.input.commit, second);
    assert.equal(capture.input.model, model);
    assert.equal(capture.input.modelDigest, 'model-fixture');
    assert.deepEqual(capture.input.request, request);
    assert.ok(!request.messages[0].content.includes(verificationGuidance));
    assert.equal(capture.input.metrics.promptTokens, 520);
    const evidence = capture.input.retrievedContext;
    assert.ok(evidence.some(item => item.path === 'docs/systems/BOAT-WATER.md'));
    assert.ok(evidence.some(item => item.path === 'godot-cove/drift.gd'));
    assert.ok(evidence.some(item => item.title === 'Draft PR #112'));
    assert.ok(evidence.some(item => item.title === 'Open issue #111'));
    assert.ok(!evidence.some(item => item.path === 'docs/systems/PROGRESSION.md'));
    unsafe = true;
    await assert.rejects(generation.generate(note, { ...issue, number: 113 }), /blocked export/);
    const rejected = inbox.read(113).captures[0];
    assert.equal(rejected.input.commit, third);
    assert.equal(rejected.input.exportPassed, false);
    assert.equal(rejected.published, null);
    unsafe = false;
    renameSync(upstream, upstream + '.offline');
    const stale = await generation.generate(note, { ...issue, number: 114 });
    assert.match(stale.brief, /\(stale, main refresh failed\)/);
    assert.equal(inbox.read(114).captures[0].input.commit, third);
    assert.equal((await processGpuIssue(canaryIssue, github, generation.generate, inbox.link)).status, 'posted');
    assert.equal((await processGpuIssue(canaryIssue, github, generation.generate, inbox.link)).status, 'already posted');
    assert.equal(canaryComments.length, 1);
    const [candidateCapture] = inbox.read(115).captures;
    assert.equal(candidateCapture.published, canaryComments[0].html_url);
    const candidate = candidateCapture.input;
    assert.equal(candidate.knowledge.retrieval.effective, candidateRetrieval);
    assert.equal(candidate.knowledge.retrieval.briefVersion, candidateBrief);
    assert.ok(candidate.request.messages[0].content.includes(verificationGuidance));
    assert.equal(candidate.knowledge.stale, true);
    assert.ok(candidate.retrievedContext.some(item => item.path === 'godot-cove/drift.gd'));
    writeFileSync(join(storage, 'source', 'godot-cove', 'boat.gd'), 'func dirty_unverified_text():\n  pass\n');
    await generation.generate(note, { ...issue, number: 115 });
    const fallback = inbox.read(115).captures.at(-1).input;
    assert.equal(fallback.knowledge.retrieval.requested, candidateRetrieval);
    assert.equal(fallback.knowledge.retrieval.effective, originalRetrieval);
    assert.equal(fallback.knowledge.retrievalFallback, true);
    assert.ok(!fallback.request.messages[0].content.includes(verificationGuidance));
    assert.ok(!JSON.stringify(fallback.retrievedContext).includes('dirty_unverified_text'));
  } finally {
    await generation?.close();
    inbox?.close();
    db?.close();
    rmSync(root, { recursive: true, force: true });
  }
});
