import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { queuedReport, processGpuIssue } from './gpu-queue.mjs';
import { reportInput, ReportInputError } from './report-input.mjs';
import { openTrainingInbox } from './training-inbox.mjs';
import { gpuBriefMarker, gpuPendingMarker, reportCharacterLimit, reportHeader, reportKinds } from './workflow.mjs';

function discordMessage(content, attachments = []) {
  return { content, attachments: new Map(attachments.map((item, index) => [String(index), item])) };
}

function textAttachment(text, overrides = {}) {
  const bytes = Buffer.from(text, 'utf8');
  return { name: 'prompt.txt', contentType: 'text/plain; charset=utf-8',
    size: bytes.length, url: 'https://cdn.discordapp.com/attachments/1/2/prompt.txt', bytes, ...overrides };
}

function fetchAttachment(attachment) {
  return async (url, options) => {
    assert.equal(url.hostname, 'cdn.discordapp.com');
    assert.equal(options.redirect, 'error');
    return new Response(attachment.bytes, { headers: { 'content-type': 'text/plain' } });
  };
}

function queuedIssue(report, { number = 321, messageId = '321', kind = 'notes' } = {}) {
  return { number, state: 'open', body: reportHeader(kind) + report
    + `\n\nDiscord report: https://discord.com/channels/111/222/${messageId}\n\n## Done when\n\n`
    + reportKinds[kind].done + `\n\n${gpuPendingMarker}\n<!-- discord-pilot:${messageId} -->` };
}

test('normal Discord message text and existing non-text attachments remain unchanged', async () => {
  const message = discordMessage('  Keep the original message text.\n', [
    { name: 'screenshot.png', contentType: 'image/png' },
    { name: 'notes.pdf', contentType: 'application/pdf' },
  ]);
  assert.equal(await reportInput(message), message.content);
});

test('a UTF-8 TXT file works by itself and with message text', async () => {
  const fileText = 'Inspect the steering report.\r\nCheck the host and guest views.';
  const onlyFile = textAttachment(fileText);
  assert.equal(await reportInput(discordMessage('', [onlyFile]), fetchAttachment(onlyFile)), fileText);

  const both = textAttachment(fileText);
  const combined = await reportInput(discordMessage('Please use this full prompt:', [both]), fetchAttachment(both));
  assert.equal(combined, 'Please use this full prompt:\n\n## Attached prompt text\n\n' + fileText);

  const upperCase = textAttachment('Uppercase extension is accepted.', { name: 'PROMPT.TXT' });
  assert.equal(await reportInput(discordMessage('', [upperCase]), fetchAttachment(upperCase)),
    'Uppercase extension is accepted.');
});

test('the complete TXT report reaches the existing GPU issue parser and generation callback', async t => {
  const text = 'Find the steering function, preserve this final sentence, and check both players.';
  const attachment = textAttachment(text);
  const report = await reportInput(discordMessage('Investigate this request:', [attachment]), fetchAttachment(attachment));
  const issue = queuedIssue(report);
  assert.ok(issue.body.includes(text));
  assert.equal(queuedReport(issue), report);

  const stored = [];
  const github = async (route, method, payload) => {
    if (route === '/issues/321') return issue;
    if (route.startsWith('/issues/321/comments')) {
      if (method === 'POST') {
        stored.push(payload.body);
        return { html_url: 'https://github.com/PeterFacina/richs-houseboat/issues/321#issuecomment-1' };
      }
      return [];
    }
    throw new Error('Unexpected GitHub request: ' + route);
  };
  let generatedInput;
  const result = await processGpuIssue(issue, github, async note => {
    generatedInput = note;
    return 'Guarded brief.';
  });
  assert.equal(result.status, 'posted');
  assert.equal(generatedInput, report);
  assert.ok(stored[0].startsWith(gpuBriefMarker));

  const directory = mkdtempSync(join(tmpdir(), 'discord-txt-capture-test-'));
  t.after(() => rmSync(directory, { recursive: true, force: true }));
  const inbox = openTrainingInbox(join(directory, 'examples.sqlite'));
  try {
    const input = { report: generatedInput, request: { messages: [{ role: 'user', content: JSON.stringify({
      currentRequest: { note: generatedInput },
    }) }] } };
    const first = inbox.capture(issue.number, input, 'Guarded brief.');
    const retry = inbox.capture(issue.number, input, 'Guarded brief.');
    assert.equal(retry, first);
    const capture = inbox.read(issue.number).captures;
    assert.equal(capture.length, 1);
    assert.equal(capture[0].input.report, report);
    assert.equal(JSON.parse(capture[0].input.request.messages[0].content).currentRequest.note, report);
  } finally { inbox.close(); }
});

test('the report limit accepts 6,500 characters and rejects larger combined inputs', async () => {
  const maximum = textAttachment('x'.repeat(reportCharacterLimit));
  const accepted = await reportInput(discordMessage('', [maximum]), fetchAttachment(maximum));
  assert.equal(accepted.length, reportCharacterLimit);
  assert.equal(queuedReport(queuedIssue(accepted)).length, reportCharacterLimit);

  const tooLarge = textAttachment('x'.repeat(reportCharacterLimit + 1));
  await assert.rejects(reportInput(discordMessage('', [tooLarge]), fetchAttachment(tooLarge)),
    error => error instanceof ReportInputError && /at most 6500 characters/.test(error.message));
  const combinedOverflow = textAttachment('y'.repeat(6480));
  await assert.rejects(reportInput(discordMessage('Add context.', [combinedOverflow]), fetchAttachment(combinedOverflow)),
    error => error instanceof ReportInputError && /at most 6500 characters/.test(error.message));
});

test('empty, duplicate, invalid, unsafe, and byte-oversized TXT attachments fail clearly', async () => {
  const empty = textAttachment('');
  await assert.rejects(reportInput(discordMessage('', [empty]), fetchAttachment(empty)), ReportInputError);

  const one = textAttachment('one');
  const two = textAttachment('two', { name: 'second.txt' });
  await assert.rejects(reportInput(discordMessage('', [one, two]), fetchAttachment(one)), /one \.txt file/);

  const invalid = textAttachment('invalid');
  invalid.bytes = Buffer.from([0xff, 0xfe, 0xfd]);
  invalid.size = invalid.bytes.length;
  await assert.rejects(reportInput(discordMessage('', [invalid]), fetchAttachment(invalid)), /UTF-8 encoding/);

  const wrongType = textAttachment('not plain text', { contentType: 'application/pdf' });
  await assert.rejects(reportInput(discordMessage('', [wrongType]), fetchAttachment(wrongType)), /plain text/);

  const unsafe = textAttachment('unsafe URL', { url: 'https://example.com/prompt.txt' });
  await assert.rejects(reportInput(discordMessage('', [unsafe]), fetchAttachment(unsafe)), /must come from Discord/);

  const tooManyBytes = textAttachment('large');
  tooManyBytes.size = reportCharacterLimit * 4 + 1;
  await assert.rejects(reportInput(discordMessage('', [tooManyBytes]), fetchAttachment(tooManyBytes)), /size limit/);

  await assert.rejects(reportInput(discordMessage('   ')), /attach a \.txt file/);
});
