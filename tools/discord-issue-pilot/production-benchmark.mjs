import assert from 'node:assert/strict';
import { execFileSync } from 'node:child_process';
import { mkdirSync, mkdtempSync, readFileSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { parseArgs } from 'node:util';
import { fileURLToPath } from 'node:url';
import { openDb } from '../game_prompt_studio/lib/db.mjs';
import { scan } from '../game_prompt_studio/lib/index.mjs';
import { localSource } from './learning/local-source.mjs';
import { candidateRetrieval, originalRetrieval, retrievalConfig } from './production-retrieval.mjs';
import { openTrainingInbox } from './training-inbox.mjs';
import { workerGeneration } from './worker-generation.mjs';

const { values } = parseArgs({ options: { source: { type: 'string' }, out: { type: 'string' } } });
assert.ok(values.source && values.out, 'Supply --source CLEAN_CHECKOUT and --out NEW_DIRECTORY.');
const fixtures = JSON.parse(readFileSync(new URL('./production-cases.json', import.meta.url), 'utf8'));
const pinned = localSource(values.source);
assert.equal(pinned.manifest.revision, fixtures.source);
const model = 'qwen3:14b';
const python = process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python';
const selector = new URL('../knowledge/studio_context.py', import.meta.url);
mkdirSync(values.out);
const results = [];
const storage = mkdtempSync(join(tmpdir(), 'houseboat-production-preview-'));
const db = openDb(storage);
const inbox = openTrainingInbox(join(storage, 'preview-only.sqlite'));
try {
  const { root, manifest, tracked } = pinned;
  scan(db, root, [], false, { manifest, tracked });
  const knowledge = {
    async refresh() { return { commit: manifest.revision, target: manifest.revision, stale: false }; },
    async select(note, tasks) {
      return JSON.parse(execFileSync(python, [fileURLToPath(selector)], {
        input: JSON.stringify({ catalog: manifest, note, tasks }), encoding: 'utf8', timeout: 10000,
        env: { ...process.env, PYTHONUTF8: '1' }, maxBuffer: 24 * 1024 * 1024,
      }));
    },
    withVerifiedCheckout(commit, use) {
      assert.equal(localSource(root).manifest.revision, commit);
      return use(root, manifest, tracked);
    },
  };
  for (const [i, example] of fixtures.cases.entries()) {
    const modes = [originalRetrieval, candidateRetrieval];
    if (i % 2) modes.reverse();
    for (const [j, mode] of modes.entries()) {
      const seed = 4801 + i;
      const issue = { number: 9000 + i * 2 + j };
      const worker = await workerGeneration({ storage, model, knowledge, inbox, retrieval: retrievalConfig(mode),
        async github(route) {
          assert.match(route, /^\/(issues|pulls)\?/);
          return [];
        },
        fetchOllama(url, init) {
          if (!url.endsWith('/api/chat')) return fetch(url, init);
          const request = JSON.parse(init.body);
          request.options.seed = seed;
          return fetch(url, { ...init, body: JSON.stringify(request) });
        },
      });
      const start = performance.now();
      try {
        const { brief } = await worker.generate(example.note, issue);
        const [{ input }] = inbox.read(issue.number).captures;
        assert.equal(input.knowledge.retrieval.effective, mode, 'Unexpected retrieval fallback during comparison');
        assert.ok(input.exportPassed);
        const result = { case: example.id, mode, commit: input.commit, model, digest: input.modelDigest, seed,
          inputTokens: input.metrics.promptTokens, outputTokens: input.metrics.outputTokens, wallMs: Math.round(performance.now() - start),
          retrievalMs: input.knowledge.retrieval.elapsedMs, exportPassed: input.exportPassed,
          lessonRendered: brief.includes('VERIFIED LESSON FROM A COMPLETED TASK') };
        writeFileSync(join(values.out, example.id + '.' + mode + '.txt'), brief + '\n', { flag: 'wx' });
        results.push(result);
        console.log(JSON.stringify(result));
      } finally { await worker.close(); }
    }
  }
  assert.equal(new Set(results.map(item => item.digest)).size, 1, 'Generation model changed mid-trial');
  writeFileSync(join(values.out, 'generation.json'), JSON.stringify(results, null, 2) + '\n', { flag: 'wx' });
} finally {
  inbox.close();
  db.close();
  rmSync(storage, { recursive: true, force: true });
}
