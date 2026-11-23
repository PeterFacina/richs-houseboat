export const repository = 'PeterFacina/richs-houseboat';
export const remote = `https://github.com/${repository}.git`;

export function pilotBrief(issue) {
  return [
    `Work on Rich's Houseboat issue ${issue}.`,
    'Read AGENTS.md and the issue. Check the owner and overlapping issues and PRs.',
    'Use the team task workflow and a separate branch from current main.',
    'Implement the notes-only pilot task described in the issue and verify the diff.',
    'If the issue includes a Game Prompt Studio brief, use it as supporting context and validate its citations against the checkout.',
    'Open a draft PR into main. Put the following on its own line in the PR body:',
    `Fixes #${issue.split('/').at(-1)}`,
    'Report what was checked and leave the PR for human review.',
  ].join('\n');
}

export function codexLink(issue) {
  return `codex://threads/new?${new URLSearchParams({
    originUrl: remote,
    prompt: pilotBrief(issue),
  })}`;
}

export function pullStatus(pulls, issueNumber) {
  const marker = new RegExp(`^Fixes #${issueNumber}\\s*$`, 'im');
  const linked = pulls.filter(pull => pull.base.ref === 'main' && marker.test(pull.body ?? ''));
  const pull = linked.find(pull => pull.merged_at)
    ?? linked.find(pull => pull.state === 'open')
    ?? linked[0];
  if (!pull) return null;
  const status = pull.merged_at ? 'Merged into `main`'
    : pull.state === 'closed' ? 'PR closed without merge'
    : pull.draft ? 'Draft PR open' : 'Ready for review';
  return `**${status}** · [PR #${pull.number}](${pull.html_url})`;
}
