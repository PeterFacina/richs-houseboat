import assert from 'node:assert/strict';
import { test } from 'node:test';
import { collectDevelopmentOutcomes } from './development-outcomes.mjs';

test('backfills conversation and preserves observed edits without duplicating revisions', async () => {
  const pull = { id: 4, number: 104, body: 'Fixes #103', html_url: 'https://github.com/PeterFacina/richs-houseboat/pull/104',
    head: { sha: 'a'.repeat(40) }, merged_at: '2026-01-01T00:00:00Z', updated_at: '2026-01-01T00:00:00Z',
    state: 'closed', base: { ref: 'main' }, user: { login: 'maintainer', type: 'User', id: 3 } };
  const message = { id: 2, body: 'Startup is too quiet.', html_url: pull.html_url + '#issuecomment-2', user: pull.user };
  const formal = { id: 5, body: 'Review recorded', state: 'COMMENTED', user: pull.user };
  const inline = { id: 6, body: 'Wrong retrieval source', user: pull.user };
  let current = { pull: 104, checkedAt: new Date().toISOString(), updatedAt: pull.updated_at };
  const inbox = { publishedIssues: () => [103], githubOutcomes: () => [{ issue: 103, ...current }],
    saveGitHubOutcome: (_, data) => { current = data; } };
  const github = async route => {
    if (route.startsWith('/pulls?')) return [pull];
    if (route.startsWith('/issues/104/comments')) return [message];
    if (route.startsWith('/pulls/104/reviews')) return [formal];
    if (route.startsWith('/pulls/104/comments')) return [inline];
    if (route.includes('/check-runs')) return { total_count: 0, check_runs: [] };
    return [];
  };
  assert.equal(await collectDevelopmentOutcomes(github, inbox), 1);
  assert.equal(current.feedback.length, 4);
  assert.equal(await collectDevelopmentOutcomes(github, inbox), 0);
  message.body = 'Startup corrected after listening.';
  pull.body += '\nFinal solo acceptance; multiplayer pending.';
  current.checkedAt = '2026-01-01T00:00:00Z';
  await collectDevelopmentOutcomes(github, inbox);
  current.checkedAt = '2026-01-01T00:00:00Z';
  await collectDevelopmentOutcomes(github, inbox);
  assert.equal(current.feedback.length, 4);
  assert.deepEqual(current.feedback.find(row => row.kind === 'conversation').versions.map(row => row.body),
    ['Startup is too quiet.', 'Startup corrected after listening.']);
  assert.equal(current.feedback.find(row => row.kind === 'description').versions.length, 2);
  assert.equal(current.feedback[0].versions[0].author.login, 'maintainer');
});
