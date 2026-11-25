import { execFile } from 'node:child_process';
import { pages, queuedReport } from '../discord-issue-pilot/gpu-queue.mjs';
import { findGpuBrief, linkedPull } from '../discord-issue-pilot/workflow.mjs';
import { date, oneOf, positive, publication, repository, text } from './contract.mjs';

const githubApi = 'https://api.github.com/repos' + new URL(repository).pathname;
const cacheMs = 120_000;

function credential(git) {
  return new Promise((resolve, reject) => {
    const child = execFile(git, ['-c', 'credential.interactive=false', 'credential', 'fill'], {
      windowsHide: true, timeout: 3000, maxBuffer: 16_384,
      env: { ...process.env, GIT_TERMINAL_PROMPT: '0', GCM_INTERACTIVE: 'Never' },
    }, (error, stdout) => {
      const token = !error && /^password=(\S+)\r?$/m.exec(stdout)?.[1];
      if (token) resolve(token);
      else reject(new Error('GitHub read credential unavailable.'));
    });
    child.stdin?.on('error', () => {});
    child.stdin?.end('protocol=https\nhost=github.com\n\n');
  });
}

async function connect(git) {
  const token = await credential(git);
  const signal = AbortSignal.timeout(9000);
  return async path => {
    const response = await fetch(githubApi + path, {
      headers: { Authorization: 'Bearer ' + token, Accept: 'application/vnd.github+json' },
      redirect: 'error', signal,
    });
    if (!response.ok) throw new Error('GitHub issue data unavailable.');
    const items = await response.json();
    if (!Array.isArray(items)) throw new Error('GitHub returned an invalid issue list.');
    return items;
  };
}

async function list(get, route, select) {
  for await (const batch of pages(get, route)) {
    for (const item of batch) select(item);
  }
}

async function loadIssues(get) {
  const rows = new Map();
  const briefs = new Map();
  const pulls = [];
  await Promise.all([
    list(get, '/issues?state=all&sort=created&direction=desc', item => {
      const issue = positive(item?.number);
      const state = oneOf(['open', 'closed'], item?.state);
      if (!issue || !state || item.pull_request) return;
      const report = queuedReport({ ...item, state: 'open' });
      const discord = report && /^Discord report: (https:\/\/discord\.com\/channels\/\d+\/\d+\/\d+)$/m.exec(item.body)?.[1];
      rows.set(issue, { issue, state, title: text(item.title, 256), discord: discord || null,
        assigned: Boolean(item.assignees?.length), queued: state === 'open' && Boolean(report) });
    }),
    list(get, '/issues/comments', item => {
      if (!findGpuBrief([item])) return;
      const issue = Number(item.issue_url?.slice((githubApi + '/issues/').length));
      if (item.issue_url !== githubApi + '/issues/' + issue || briefs.has(issue)) return;
      const url = publication(issue, item.html_url);
      if (url) briefs.set(issue, url);
    }),
    list(get, '/pulls?state=all&sort=updated&direction=desc', pull => pulls.push(pull)),
  ]);
  return [...rows.values()].sort((a, b) => Number(b.state === 'open') - Number(a.state === 'open') || b.issue - a.issue)
    .map(row => {
      const linked = linkedPull(pulls, row.issue);
      const number = positive(linked?.number);
      const pull = number ? { number, mergedAt: date(linked.merged_at),
        state: linked.merged_at ? 'merged' : linked.state === 'closed' ? 'closed' : linked.draft ? 'draft' : 'review' } : null;
      return { ...row, brief: briefs.get(row.issue) ?? null, pull };
    });
}

export function createGitHubIssues({ git = 'git', open = () => connect(git), now = Date.now } = {}) {
  let snapshot;
  let pending;
  return async function githubIssues() {
    if (snapshot && now() - Date.parse(snapshot.checkedAt) < cacheMs) return snapshot;
    pending ??= open().then(loadIssues).then(rows => {
      snapshot = { checkedAt: new Date(now()).toISOString(), rows };
      return snapshot;
    }).finally(() => { pending = undefined; });
    try { return await pending; }
    catch (error) {
      if (!snapshot) throw error;
      return { ...snapshot, stale: true };
    }
  };
}
