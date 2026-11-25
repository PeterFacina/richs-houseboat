import { pages } from './gpu-queue.mjs';
import { linkedPull } from './workflow.mjs';

async function all(github, route) {
  const items = [];
  for await (const batch of pages(github, route)) items.push(...batch);
  return items;
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
    if (previous?.pull === pull.number && previous.updatedAt === pull.updated_at && age >= 0 && age < 86_400_000) continue;
    const route = '/pulls/' + pull.number;
    const [files, reviews, corrections, checks] = await Promise.all([
      all(github, route + '/files'), all(github, route + '/reviews'), all(github, route + '/comments'),
      github('/commits/' + pull.head.sha + '/check-runs?filter=latest&per_page=100'),
    ]);
    inbox.saveGitHubOutcome(issue, {
      pull: pull.number, url: pull.html_url, head: pull.head.sha, merge: pull.merge_commit_sha,
      mergedAt: pull.merged_at, updatedAt: pull.updated_at, checkedAt: new Date().toISOString(),
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
