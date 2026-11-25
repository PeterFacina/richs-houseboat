import { timingSafeEqual } from 'node:crypto';
import { createServer } from 'node:http';
import { apiInput, configuration, isEntryPoint, json, loopback, privateHeaders, roles, urlPath } from './contract.mjs';
import { createReader } from './reader.mjs';

export function createAdapter({ token, reader }) {
  const expected = Buffer.from('Bearer ' + token);
  return createServer({ requestTimeout: 5000, headersTimeout: 5000, maxHeaderSize: 4096 }, (req, res) => {
    privateHeaders(res);
    const supplied = Buffer.from(req.headers.authorization ?? '');
    if (req.socket.remoteAddress !== loopback || supplied.length !== expected.length || !timingSafeEqual(supplied, expected)) {
      return json(res, 403, { error: 'Adapter access denied.' });
    }
    const role = req.headers['x-dashboard-role'];
    if (!roles.includes(role)) return json(res, 403, { error: 'Adapter access denied.' });
    if (req.method !== 'GET') {
      res.setHeader('Allow', 'GET');
      return json(res, 405, { error: 'The adapter is read-only.' });
    }
    const url = urlPath(req);
    const path = url?.pathname.replace(/^\/v1(?=\/)/, '');
    const input = url?.pathname.startsWith('/v1/') && apiInput(path, url.searchParams);
    if (!input) return json(res, 404, { error: 'Unknown adapter request.' });
    if (path === '/learning' && role !== 'reviewer') return json(res, 403, { error: 'Reviewer access required.' });
    try {
      const result = {
        '/overview': () => reader.overview(role),
        '/knowledge': () => reader.knowledge(input),
        '/briefs': () => reader.briefs(input.page),
        '/retrieval': () => reader.retrieval(input.issue, role),
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
    const { path, port, token } = configuration(process.argv[2]);
    const reader = createReader({ storage: path('workerStorage'), inbox: path('trainingInbox') });
    const listenPort = port('port');
    createAdapter({ token, reader }).listen(listenPort, loopback, () => console.log('Dashboard adapter listening on loopback.'));
  } catch {
    console.error('The dashboard adapter could not start. Check the local config and token file.');
    process.exitCode = 1;
  }
}
