import { execFileSync } from 'node:child_process';
import { randomUUID } from 'node:crypto';
import { rename, rm, writeFile } from 'node:fs/promises';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';

function workerRevision() {
  const { GITHUB_TOKEN, GH_TOKEN, ...env } = process.env;
  try {
    const head = execFileSync('git', ['rev-parse', 'HEAD'], { encoding: 'utf8', timeout: 1500, env, windowsHide: true,
      cwd: fileURLToPath(new URL('.', import.meta.url)), stdio: ['ignore', 'pipe', 'ignore'] }).trim();
    return /^[a-f0-9]{40}$/.test(head) ? head : null;
  } catch { return null; }
}

// Opt-in telemetry is separate from SQLite and coalesces updates without blocking a queued issue.
export function workerStatus(storage, { model, retrieval, log = console, release = workerRevision() }) {
  const path = join(storage, 'worker-status.json');
  const prefix = { schema: 1, model, release, configuredMode: retrieval.mode, canary: Boolean(retrieval.issue) };
  let status = { phase: 'starting', knowledge: null };
  let pending;
  let queued = false;
  let warned = false;

  async function write() {
    while (queued) {
      queued = false;
      const temporary = path + '.' + randomUUID() + '.tmp';
      try {
        await writeFile(temporary, JSON.stringify({ ...prefix, ...status, observedAt: new Date().toISOString() }),
          { mode: 0o600, flag: 'wx' });
        await rename(temporary, path);
        warned = false;
      } catch {
        if (!warned) log.warn('Could not publish the dashboard heartbeat.');
        warned = true;
        await rm(temporary, { force: true }).catch(() => {});
      }
    }
  }

  function publish() {
    queued = true;
    pending ??= write().finally(() => {
      pending = undefined;
      if (queued) publish();
    });
  }

  const heartbeat = setInterval(publish, 30_000);
  heartbeat.unref();
  publish();
  return {
    phase(phase) { status = { ...status, phase }; publish(); },
    knowledge(state) {
      status = { ...status, knowledge: state ? {
        indexedRevision: state.commit, target: state.target, stale: state.stale, observedAt: new Date().toISOString(),
      } : null };
      publish();
    },
    async close() {
      clearInterval(heartbeat);
      status = { ...status, phase: 'stopped' };
      publish();
      while (pending) await pending;
    },
  };
}
