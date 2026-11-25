import { execFile } from 'node:child_process';
import { existsSync, lstatSync, mkdirSync, readdirSync, writeFileSync } from 'node:fs';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { promisify } from 'node:util';
import { indexedKnowledge, scan } from '../game_prompt_studio/lib/index.mjs';

const run = promisify(execFile);
const indexer = fileURLToPath(new URL('../knowledge/index.py', import.meta.url));
const selector = fileURLToPath(new URL('../knowledge/studio_context.py', import.meta.url));
const revisionPattern = /^[a-f0-9]{40}$/;
const sparsePaths = [
  '/AGENTS.md', '/GAME GUIDE AND ASSET CREDITS.md', '/START HERE.txt', '/Play Ottawa River.cmd',
  '/docs/ARCHITECTURE.md', '/docs/systems/*.md',
  ...['gd', 'tscn', 'tres', 'gdshader', 'gdshaderinc', 'godot', 'cs', 'md', 'txt']
    .map(ext => '/godot-cove/**/*.' + ext),
  '!/godot-cove/ottawa/**'
];

export function sourceKnowledge({ db, storage, remote, python = 'python', log = console }) {
  const source = join(storage, 'source');
  const { GITHUB_TOKEN, GH_TOKEN, ...env } = process.env;
  Object.assign(env, { GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'never', PYTHONUTF8: '1' });
  let pending;

  async function command(program, args, timeout, input) {
    try {
      const running = run(program, args, { cwd: storage, env, timeout, windowsHide: true,
        maxBuffer: 24 * 1024 * 1024 });
      if (input !== undefined) {
        running.child.stdin.on('error', () => {});
        running.child.stdin.end(input);
      }
      const { stdout } = await running;
      return stdout;
    } catch (error) {
      const status = error.killed ? 'timeout' : error.code;
      throw new Error(program === 'git' ? 'Git failed (' + status + ').' : 'Knowledge indexer failed (' + status + ').');
    }
  }
  const git = (...args) => command('git', ['-C', source, '-c', 'credential.interactive=never', ...args], 120_000);

  async function prepareCheckout() {
    mkdirSync(source, { recursive: true });
    if (lstatSync(source).isSymbolicLink()) throw new Error('Source cache path is linked.');
    if (existsSync(join(source, '.git'))) {
      if ((await git('config', '--local', '--get', 'houseboat.knowledgeCache')).trim() !== '1' ||
          (await git('config', '--local', '--get', 'remote.origin.url')).trim() !== remote) {
        throw new Error('Source cache is owned by another checkout.');
      }
    } else {
      if (readdirSync(source).length) throw new Error('Source cache directory is already in use.');
      await git('init', '--initial-branch=houseboat-source-cache');
      await git('remote', 'add', 'origin', remote);
      await git('config', 'core.autocrlf', 'false');
      await git('config', 'core.longpaths', 'true');
      await git('config', 'remote.origin.promisor', 'true');
      await git('config', 'remote.origin.partialclonefilter', 'blob:none');
      await git('sparse-checkout', 'set', '--no-cone', '--', ...sparsePaths);
      await git('config', 'houseboat.knowledgeCache', '1');
    }
  }

  async function refresh() {
    const previous = indexedKnowledge(db);
    let target = null;
    let step = 'prepare checkout';
    try {
      await prepareCheckout();
      step = 'read GitHub main';
      target = (await git('ls-remote', '--exit-code', 'origin', 'refs/heads/main')).split(/\s+/)[0];
      if (!revisionPattern.test(target)) throw new Error('Invalid main revision.');
      if (target === previous?.revision) return { commit: target, target, stale: false };

      step = 'verify clean cache';
      if ((await git('status', '--porcelain', '--untracked-files=all')).trim()) throw new Error('Source cache has local changes.');
      step = 'fetch and check out main';
      await git('fetch', '--no-tags', '--depth=1', '--filter=blob:none', 'origin', 'refs/heads/main');
      target = (await git('rev-parse', 'FETCH_HEAD')).trim();
      if (!revisionPattern.test(target)) throw new Error('Invalid fetched revision.');
      await git('checkout', '--detach', target);
      step = 'index pinned source';
      const start = performance.now();
      const args = [indexer, '--root', source];
      if (previous) {
        const previousPath = join(storage, 'previous-index.json');
        writeFileSync(previousPath, JSON.stringify(previous), { mode: 0o600 });
        args.push('--previous', previousPath);
      }
      const manifest = JSON.parse(await command(python, args, 60_000));
      if (manifest.dirty || manifest.schema !== 1 || manifest.revision !== target ||
          !manifest.files['godot-cove/project.godot']) throw new Error('Source index does not match the pinned checkout.');
      const tracked = (await git('ls-files', '-z')).split('\0').filter(Boolean);
      if ((await git('status', '--porcelain', '--untracked-files=all')).trim()) throw new Error('Pinned checkout has local changes.');
      const stats = scan(db, source, [], false, { manifest, tracked });
      log.info(`Knowledge ${target} indexed in ${Math.round(performance.now() - start)} ms ` +
        `(${stats.indexed} files, ${stats.changed} changed, ${stats.removed} removed).`);
      return { commit: target, target, stale: false };
    } catch (error) {
      if (!previous) throw new Error('No verified source index. Failed to ' + step + ': ' + error.message);
      log.warn('Stale knowledge ' + previous.revision + ': could not ' + step + '.');
      return { commit: previous.revision, target: revisionPattern.test(target) ? target : null, stale: true, step };
    }
  }

  return {
    refresh() {
      pending ??= refresh().finally(() => { pending = undefined; });
      return pending;
    },
    async select(note, tasks) {
      const catalog = indexedKnowledge(db);
      const input = JSON.stringify({ catalog, note, tasks });
      return JSON.parse(await command(python, [selector], 10_000, input));
    },
    async withVerifiedCheckout(commit, use) {
      const manifest = indexedKnowledge(db);
      if (manifest?.revision !== commit || (await git('rev-parse', 'HEAD')).trim() !== commit ||
          (await git('status', '--porcelain', '--untracked-files=all')).trim()) {
        throw new Error('The source checkout does not match the indexed revision.');
      }
      const tracked = (await git('ls-files', '-z')).split('\0').filter(Boolean);
      return use(source, manifest, tracked);
    },
  };
}

export async function liveKnowledge(github, currentIssue) {
  const routes = ['/issues?state=open&per_page=100', '/pulls?state=open&per_page=100'];
  const results = await Promise.allSettled(routes.map(route => github(route)));
  const tasks = results.flatMap((result, index) => result.status === 'fulfilled' ? result.value.flatMap(item => {
    if (item.number === currentIssue || item.pull_request || !Number.isSafeInteger(item.number) || typeof item.title !== 'string') return [];
    const title = item.title.replace(/^\s*(?:Game report|Workflow pilot):\s*/i, '')
      .replace(/https?:\/\/\S+|\b(?:gh[pousr]_|github_pat_)[a-z0-9_]+/gi, '[redacted]')
      .replace(/[\p{Cc}\p{Cf}]/gu, ' ').trim().slice(0, 200);
    return title ? [{ number: item.number, title, label: index === 0 ? 'Open issue' : item.draft ? 'Draft PR' : 'Open PR' }] : [];
  }) : []);
  return { tasks, githubContextComplete: results.every(result =>
    result.status === 'fulfilled' && result.value.length < 100) };
}
