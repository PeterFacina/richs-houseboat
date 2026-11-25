import { timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { apiInput, configuration, isEntryPoint, json, loopback, privateHeaders, readReviewBody, reviewerRoutes, roles, urlPath } from './contract.mjs';
import { createGitHubIssues } from './github-issues.mjs';
import { createTrainingReview, reviewIdentity } from './review.mjs';
import { createReader } from './reader.mjs';

export function createAdapter({ token, reader, review }) {
  const expected = Buffer.from('Bearer ' + token);
  return createServer({ requestTimeout: 5000, headersTimeout: 5000, maxHeaderSize: 4096 }, async (req, res) => {
    privateHeaders(res);
    const supplied = Buffer.from(req.headers.authorization ?? '');
    if (req.socket.remoteAddress !== loopback || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
      return json(res, 403, { error: 'Adapter access denied.' });
    }
    const role = req.headers['x-dashboard-role'];
    if (!roles.includes(role)) return json(res, 403, { error: 'Adapter access denied.' });
    const url = urlPath(req);
    const write = req.method === 'POST' && url?.pathname === '/v1/review' && review;
    if (req.method !== 'GET' && !write) {
      res.setHeader('Allow', 'GET');
      return json(res, 405, { error: 'The adapter is read-only.' });
    }
    const path = url?.pathname.replace(/^\/v1(?=\/)/, '');
    const input = url?.pathname.startsWith('/v1/') && apiInput(path, url.searchParams);
    if (!input) return json(res, 404, { error: 'Unknown adapter request.' });
    if (reviewerRoutes.has(path) && role !== 'reviewer') return json(res, 403, { error: 'Reviewer access required.' });
    if (path === '/review') {
      if (!review) return json(res, 404, { error: 'Remote review is disabled.' });
      if (write) {
        const actor = reviewIdentity(req.headers['x-review-actor']);
        if (!actor) return json(res, 403, { error: 'Reviewer identity required.' });
        try { return json(res, 200, review.record(input.issue, await readReviewBody(req), actor)); }
        catch (error) { return json(res, 400, { error: error.code?.startsWith('ERR_SQLITE') ? 'Review store unavailable.' : error.message }); }
      }
    }
    try {
      const result = await {
        '/overview': () => reader.overview(role),
        '/knowledge': () => reader.knowledge(input),
        '/issues': () => reader.issues(input.page),
        '/briefs': () => reader.briefs(input.page),
        '/retrieval': () => reader.retrieval(input.issue, role),
        '/review': () => review.get(input),
        '/learning': () => reader.learning(input.page),
      }[path]();
      if (result === null) return json(res, 503, { error: 'The authoritative store is unavailable.' });
      if (path === '/retrieval' && !result.result) return json(res, 404, { error: 'No published brief for that issue.' });
      return json(res, 200, result);
    } catch {
      return json(res, 503, { error: 'The authoritative store is unavailable.' });
    }
  });
}

if (isEntryPoint(import.meta.url)) {
  try {
    const { data, path, port, token } = configuration(process.argv[2]);
    const reader = createReader({ storage: path('workerStorage'), inbox: path('trainingInbox'),
      githubIssues: data.githubIssues === true ? createGitHubIssues({ git: data.githubGit ? path('githubGit') : 'git' }) : undefined });
    const listenPort = port('port');
    createAdapter({ token, reader, review: data.remoteReview === true ?
      createTrainingReview({ storage: path('workerStorage'), inbox: path('trainingInbox'),
        holdout: data.reviewHoldout ? path('reviewHoldout') : undefined }) : undefined }).listen(listenPort, loopback, () => console.log('Dashboard adapter listening on loopback.'));
  } catch {
    console.error('The dashboard adapter could not start. Check the local config and token file.');
    process.exitCode = 1;
  }
}
