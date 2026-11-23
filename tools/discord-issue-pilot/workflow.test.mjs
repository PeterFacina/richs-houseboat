import assert from 'node:assert/strict';
import test from 'node:test';
import { codexLink, findGpuBrief, gpuBriefMarker, pullStatus, remote } from './workflow.mjs';

test('the GPU handoff opens Codex with a marked collaborator brief', () => {
  const issue = 'https://github.com/PeterFacina/richs-houseboat/issues/31';
  const brief = { html_url: issue + '#issuecomment-42', body: gpuBriefMarker + '\n\nGuarded brief',
    author_association: 'COLLABORATOR' };
  assert.equal(findGpuBrief([{ ...brief, author_association: 'NONE' }]), undefined);
  assert.equal(findGpuBrief([{ ...brief, body: 'Example\n' + brief.body }]), undefined);
  assert.equal(findGpuBrief([{ ...brief, body: gpuBriefMarker + '\n' }]), undefined);
  assert.equal(findGpuBrief([brief]), brief);
  const link = new URL(codexLink(issue, brief.html_url));
  assert.ok(link.searchParams.get('prompt').includes(brief.html_url));
});

test('Codex opens a workspace matched by remote and receives the issue and PR instructions', () => {
  const issue = 'https://github.com/PeterFacina/richs-houseboat/issues/17';
  const link = new URL(codexLink(issue));
  assert.equal(link.protocol, 'codex:');
  assert.equal(link.searchParams.get('originUrl'), remote);
  assert.ok(link.searchParams.get('prompt').includes(issue));
  assert.match(link.searchParams.get('prompt'), /^Fixes #17$/m);
});

test('Discord follows the linked draft through review and a merge into main', () => {
  const draft = {
    base: { ref: 'main' }, body: 'Notes update\n\nFixes #17', state: 'open',
    draft: true, number: 18, html_url: 'https://github.com/PeterFacina/richs-houseboat/pull/18',
  };
  assert.match(pullStatus([draft], 17), /Draft PR open/);
  assert.match(pullStatus([{ ...draft, draft: false }], 17), /Ready for review/);
  assert.match(pullStatus([{ ...draft, state: 'closed' }], 17), /closed without merge/);
  assert.match(pullStatus([{ ...draft, state: 'closed', merged_at: '2026-11-22' }], 17), /Merged into/);
  assert.equal(pullStatus([draft], 1), null);
  assert.equal(pullStatus([{ ...draft, base: { ref: 'other' } }], 17), null);
});
