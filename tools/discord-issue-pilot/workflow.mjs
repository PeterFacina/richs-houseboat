export const repository = 'PeterFacina/richs-houseboat';
export const reportCharacterLimit = 6500;
export const remote = `https://github.com/${repository}.git`;

export const gpuBriefMarker = '<!-- houseboat-gpu-brief:v1 -->';
export const gpuPendingMarker = '<!-- houseboat-gpu-pending:v1 -->';
export const reportKinds = {
  notes: {
    command: 'Create pilot issue',
    titlePrefix: 'Workflow pilot: ',
    goal: 'Run a notes-only workflow pilot.',
    done: 'The requested notes change is in a linked draft PR, ready for human review.',
  },
  gameplay: {
    command: 'Create game issue',
    titlePrefix: 'Game report: ',
    goal: 'Investigate the reported gameplay issue.',
    done: 'The reported behavior and verification results are documented in a linked draft PR for human review.',
  },
};

export function reportHeader(kind) {
  return '## Goal\n\n' + reportKinds[kind].goal + '\n\n## Original report\n\n';
}

export function findGpuBrief(comments) {
  return comments.find(comment => ['OWNER', 'MEMBER', 'COLLABORATOR'].includes(comment.author_association)
    && comment.body?.startsWith(gpuBriefMarker + '\n')
    && comment.body.slice(gpuBriefMarker.length).trim());
}

export function pilotBrief(issue, gpuBriefUrl, kind = 'notes') {
  return [
    `Work on Rich's Houseboat issue ${issue}.`,
    'Read AGENTS.md and the issue. Use docs/GAME-IDENTITY.md for terminology and check source for implemented features. Check the owner and overlapping issues and PRs.',
    'Fetch current origin/main and create a separate task worktree with tools/Start-GameTask.ps1 before investigating or editing gameplay. Reopen the existing task worktree when resuming.',
    kind === 'gameplay'
      ? 'Investigate the reported gameplay behavior. Reproduce it where possible, verify the cause before making a focused fix, and record any checks that could not be run.'
      : 'Implement the notes-only pilot task described in the issue and verify the diff.',
    'If the issue includes a Game Prompt Studio brief, use it as supporting context and validate its citations against the checkout.',
    ...(gpuBriefUrl ? ['Read the guarded GPU brief on the issue: ' + gpuBriefUrl] : []),
    'Open a draft PR into main. Put the following on its own line in the PR body:',
    `Fixes #${issue.split('/').at(-1)}`,
    'Report what was checked and leave the PR for human review.',
  ].join('\n');
}

export function codexLink(issue, gpuBriefUrl, kind = 'notes') {
  return `codex://threads/new?${new URLSearchParams({
    originUrl: remote,
    prompt: pilotBrief(issue, gpuBriefUrl, kind),
  })}`;
}

export function linkedPull(pulls, issueNumber) {
  const marker = new RegExp(`^Fixes #${issueNumber}\\s*$`, 'im');
  const linked = pulls.filter(pull => pull.base?.ref === 'main' && marker.test(pull.body ?? ''));
  return linked.find(pull => pull.merged_at)
    ?? linked.find(pull => pull.state === 'open')
    ?? linked[0];
}

export function pullStatus(pulls, issueNumber) {
  const pull = linkedPull(pulls, issueNumber);
  if (!pull) return null;
  const status = pull.merged_at ? 'Merged into `main`'
    : pull.state === 'closed' ? 'PR closed without merge'
    : pull.draft ? 'Draft PR open' : 'Ready for review';
  return `**${status}** · [PR #${pull.number}](${pull.html_url})`;
}
