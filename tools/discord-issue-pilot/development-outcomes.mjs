import { createHash } from 'node:crypto';
import { pages } from './gpu-queue.mjs';
import { linkedPull } from './workflow.mjs';

async function all(github, route) {
  const items = [];
  for await (const batch of pages(github, route)) items.push(...batch);
  return items;
}

function feedbackHistory(previous, pull, conversation, reviews, inline, observedAt) {
  const history = new Map((previous?.feedback ?? []).map(entry => [entry.key, entry]));
  for (const [kind, items] of [['description', [pull]], ['conversation', conversation],
    ['review', reviews], ['inline', inline]]) {
    for (const item of items) {
      const key = [pull.number, kind, item.id ?? item.html_url].join('/');
      const version = {
        body: item.body ?? '', url: item.html_url, createdAt: item.submitted_at ?? item.created_at,
        updatedAt: kind === 'description' ? undefined : item.updated_at,
        revision: item.commit_id ?? (kind === 'description' ? pull.head.sha : undefined),
        author: item.user && { id: item.user.id, login: item.user.login, type: item.user.type },
        association: item.author_association, app: item.performed_via_github_app?.slug, state: kind === 'review' ? item.state : undefined,
        path: item.path, line: item.line ?? item.original_line,
      };
      const hash = createHash('sha256').update(JSON.stringify(version)).digest('hex');
      const entry = history.get(key) ?? { key, kind, versions: [] };
      if (entry.versions.at(-1)?.hash !== hash) entry.versions.push({ ...version, hash, observedAt, sourceUpdatedAt: item.updated_at });
      history.set(key, entry);
    }
  }
  return [...history.values()];
}

export async function collectDevelopmentOutcomes(github, inbox) {
  const issues = inbox.publishedIssues();
  if (!issues.length) return 0;
  const pulls = await all(github, '/pulls?state=all&sort=updated&direction=desc');
  const existing = new Map(inbox.githubOutcomes().map(row => [row.issue, row]));
  let updated = 0;
  for (const issue of issues) {
    const pull = linkedPull(pulls, issue);
    if (!pull?.merged_at || !/^[0-9a-f]{40}$/.test(pull.head?.sha ?? '')) continue;
    const previous = existing.get(issue);
    const age = Date.now() - Date.parse(previous?.checkedAt ?? '');
    if (previous?.feedback && previous.pull === pull.number && previous.updatedAt === pull.updated_at && age >= 0 && age < 600_000) continue;
    const route = '/pulls/' + pull.number;
    const [files, reviews, corrections, conversation, checks] = await Promise.all([
      all(github, route + '/files'), all(github, route + '/reviews'), all(github, route + '/comments'),
      all(github, '/issues/' + pull.number + '/comments'),
      github('/commits/' + pull.head.sha + '/check-runs?filter=latest&per_page=100'),
    ]);
    const checkedAt = new Date().toISOString();
    inbox.saveGitHubOutcome(issue, {
      feedback: feedbackHistory(previous, pull, conversation, reviews, corrections, checkedAt),
      pull: pull.number, url: pull.html_url, head: pull.head.sha, merge: pull.merge_commit_sha,
      mergedAt: pull.merged_at, updatedAt: pull.updated_at, checkedAt,
      files: files.map(({ filename, status, additions, deletions }) => ({ path: filename, status, additions, deletions })),
      reviews: reviews.map(({ state, submitted_at, html_url, body }) =>
        ({ state, recordedAt: submitted_at, url: html_url, note: body?.slice(0, 1200) })),
      corrections: corrections.map(({ path, line, html_url, body }) => ({ path, line, url: html_url, note: body?.slice(0, 1200) })),
      checks: (checks.check_runs ?? []).map(({ name, status, conclusion, html_url }) => ({ name, status, conclusion, url: html_url })),
      checksComplete: (checks.total_count ?? 0) <= (checks.check_runs?.length ?? 0),
    });
    updated += 1;
  }
  return updated;
}
