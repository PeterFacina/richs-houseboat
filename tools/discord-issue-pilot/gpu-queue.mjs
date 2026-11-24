import { gpuBriefMarker, gpuPendingMarker, findGpuBrief, reportHeader, reportKinds } from './workflow.mjs';

const footer = /\n\nDiscord report: https:\/\/discord\.com\/channels\/\d+\/\d+\/(\d+)\n\n## Done when\n\n([^\n]+)\n\n<!-- houseboat-gpu-pending:v1 -->\n<!-- discord-pilot:(\d+) -->$/;

export function queuedReport(issue) {
  if (issue.state !== 'open' || issue.pull_request) return null;
  const body = issue.body?.replaceAll('\r\n', '\n').trimEnd() ?? '';
  const kind = Object.keys(reportKinds).find(key => body.startsWith(reportHeader(key)));
  if (!kind || !body.includes(gpuPendingMarker)) return null;
  const match = footer.exec(body);
  if (!match || match[1] !== match[3] || match[2] !== reportKinds[kind].done) return null;
  const note = body.slice(reportHeader(kind).length, match.index).trim();
  return note && note.length <= 6500 ? note : null;
}

export async function* pages(github, route) {
  const separator = route.includes('?') ? '&' : '?';
  for (let page = 1; ; page++) {
    const items = await github(route + separator + 'per_page=100&page=' + page);
    yield items;
    if (items.length < 100) return;
  }
}

async function existingBrief(github, route) {
  for await (const comments of pages(github, route)) {
    const found = findGpuBrief(comments);
    if (found) return found;
  }
  return null;
}

export async function processGpuIssue(issue, github, generate, linkBrief = () => {}) {
  const note = queuedReport(issue);
  if (!note) return { status: 'not queued' };
  const path = '/issues/' + issue.number;
  const comments = path + '/comments';
  const existing = await existingBrief(github, comments);
  if (existing) {
    linkBrief(issue.number, existing.body.slice(gpuBriefMarker.length).trim(), existing.html_url);
    return { status: 'already posted', url: existing.html_url };
  }

  const generated = await generate(note, issue);
  const brief = (typeof generated === 'string' ? generated : generated.brief).trim();
  if (!brief) throw new Error('Studio returned an empty brief.');
  const current = await github(path);
  if (!queuedReport(current) || current.body !== issue.body) {
    return { status: 'issue changed during generation' };
  }
  const concurrent = await existingBrief(github, comments);
  if (concurrent) {
    linkBrief(issue.number, concurrent.body.slice(gpuBriefMarker.length).trim(), concurrent.html_url);
    return { status: 'already posted', url: concurrent.html_url };
  }
  const posted = await github(comments, 'POST', { body: gpuBriefMarker + '\n\n' + brief });
  linkBrief(issue.number, brief, posted.html_url, generated.captureId);
  return { status: 'posted', url: posted.html_url };
}
