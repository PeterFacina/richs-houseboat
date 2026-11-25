import { reportCharacterLimit } from './workflow.mjs';

const maxAttachmentBytes = reportCharacterLimit * 4;
const discordAttachmentHosts = new Set(['cdn.discordapp.com', 'media.discordapp.net']);

export class ReportInputError extends Error {}

function invalid(message) {
  return new ReportInputError(message);
}

async function downloadText(attachment, fetchFile) {
  if (!/\.txt$/i.test(attachment.name ?? '')) {
    throw invalid('Attach one UTF-8 .txt file with your report.');
  }
  const mediaType = (attachment.contentType ?? '').split(';', 1)[0].trim().toLowerCase();
  if (mediaType && !['text/plain', 'application/octet-stream'].includes(mediaType)) {
    throw invalid('The attached .txt file must be plain text.');
  }
  if (Number.isFinite(attachment.size) && (attachment.size <= 0 || attachment.size > maxAttachmentBytes)) {
    throw invalid('The attached .txt file exceeds the prompt size limit.');
  }

  let url;
  try { url = new URL(attachment.url); }
  catch { throw invalid('Discord did not provide a valid .txt download URL.'); }
  if (url.protocol !== 'https:' || !discordAttachmentHosts.has(url.hostname)
      || url.username || url.password) {
    throw invalid('The attached file must come from Discord.');
  }

  let response;
  try {
    response = await fetchFile(url, { redirect: 'error', signal: AbortSignal.timeout(15_000) });
  } catch {
    throw invalid('Could not download the attached .txt file from Discord. Please retry.');
  }
  if (!response.ok) throw invalid('Could not download the attached .txt file from Discord. Please retry.');

  const length = Number(response.headers.get('content-length'));
  if (Number.isFinite(length) && length > maxAttachmentBytes) {
    throw invalid('The attached .txt file exceeds the prompt size limit.');
  }
  if (!response.body) throw invalid('The attached .txt file was empty.');
  const reader = response.body.getReader();
  const chunks = [];
  let bytes = 0;
  try {
    for (;;) {
      const { done, value } = await reader.read();
      if (done) break;
      bytes += value.byteLength;
      if (bytes > maxAttachmentBytes) {
        await reader.cancel();
        throw invalid('The attached .txt file exceeds the prompt size limit.');
      }
      chunks.push(Buffer.from(value));
    }
  } catch (error) {
    if (error instanceof ReportInputError) throw error;
    throw invalid('Could not finish downloading the attached .txt file. Please retry.');
  }
  if (!bytes) throw invalid('The attached .txt file was empty.');

  let text;
  try { text = new TextDecoder('utf-8', { fatal: true }).decode(Buffer.concat(chunks)); }
  catch { throw invalid('The attached .txt file must use UTF-8 encoding.'); }
  text = text.replace(/^\uFEFF/, '');
  if (text.includes('\0') || !text.trim()) throw invalid('The attached .txt file must contain readable text.');
  return text;
}

export async function reportInput(message, fetchFile = globalThis.fetch) {
  const text = typeof message.content === 'string' ? message.content : '';
  const attachments = [...(message.attachments?.values?.() ?? [])];
  const textFiles = attachments.filter(file => /\.txt$/i.test(file.name ?? ''));
  if (textFiles.length > 1) throw invalid('Attach one .txt file per report.');

  let report = text;
  if (textFiles.length) {
    const fileText = await downloadText(textFiles[0], fetchFile);
    report = report.trim() ? `${report}\n\n## Attached prompt text\n\n${fileText}` : fileText;
  }
  if (!report.trim()) throw invalid('Choose a teammate’s text report or attach a .txt file.');
  if (report.length > reportCharacterLimit) {
    throw invalid(`Report text and attachment must total at most ${reportCharacterLimit} characters.`);
  }
  return report;
}
