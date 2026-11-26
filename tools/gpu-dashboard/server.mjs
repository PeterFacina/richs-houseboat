import { readFileSync } from 'node:fs';
import { createServer } from 'node:http';
import { apiInput, configuration, isEntryPoint, json, loopback, privateHeaders, readReviewBody, reviewerRoutes, roles, urlPath } from './contract.mjs';

const assets = new Map([['/', ['index.html', 'text/html']], ['/dashboard.css', ['dashboard.css', 'text/css']],
  ['/dashboard.mjs', ['dashboard.mjs', 'text/javascript']]]);
const loginName = value => typeof value === 'string' && /^[\w.+-]{1,100}@[\w.-]{1,120}$/.test(value) ? value.toLowerCase() : null;

function policy(origin, users, alternateOrigin) {
  const hosts = [origin, ...(alternateOrigin ? [alternateOrigin] : [])].map(value => {
    const fixed = new URL(value);
    if (fixed.origin !== value || fixed.protocol !== 'https:' || !fixed.hostname.endsWith('.ts.net')) {
      throw new Error('Set the exact Tailscale HTTPS origin.');
    }
    return fixed.host;
  });
  if (!users || typeof users !== 'object' || Array.isArray(users)) throw new Error('Configure a named dashboard allowlist.');
  const allowed = new Map();
  for (const [name, role] of Object.entries(users)) {
    const login = loginName(name);
    if (!login || !roles.includes(role) || allowed.has(login)) throw new Error('Invalid dashboard allowlist entry.');
    allowed.set(login, role);
  }
  if (!allowed.size) throw new Error('The dashboard allowlist is empty.');
  return req => req.socket.remoteAddress === loopback && hosts.includes(req.headers.host) ?
    allowed.get(loginName(req.headers['tailscale-user-login'])) : null;
}

export function createDashboard({ origin, alternateOrigin, users, adapterPort, token, remoteReview = false, reviewWriters = [] }) {
  const access = policy(origin, users, alternateOrigin);
  if (!Array.isArray(reviewWriters) || reviewWriters.some(name => !loginName(name))) throw new Error('Invalid review writer allowlist.');
  const writers = new Set(reviewWriters.map(loginName));
  const files = new Map([...assets].map(([route, [file, type]]) => [
    route, { data: readFileSync(new URL('public/' + file, import.meta.url)), type },
  ]));
  return createServer({ requestTimeout: 5000, headersTimeout: 5000, maxHeaderSize: 4096 }, async (req, res) => {
    privateHeaders(res);
    res.setHeader('Cross-Origin-Resource-Policy', 'same-origin');
    const role = access(req);
    if (!role) return json(res, 403, { error: 'This Tailscale account does not have dashboard access.' });
    const url = urlPath(req);
    const write = req.method === 'POST' && url?.pathname === '/api/review' && remoteReview;
    if (req.method !== 'GET' && !write) {
      res.setHeader('Allow', 'GET');
      return json(res, 405, { error: 'The dashboard is read-only.' });
    }
    if (files.has(url?.pathname) && !url.search) {
      const { data, type } = files.get(url.pathname);
      res.writeHead(200, { 'Content-Type': type + '; charset=utf-8' });
      return res.end(data);
    }
    const path = url?.pathname.slice('/api'.length);
    if (!url?.pathname.startsWith('/api/') || !apiInput(path, url.searchParams)) {
      return json(res, 404, { error: 'Unknown dashboard request.' });
    }
    const actor = loginName(req.headers['tailscale-user-login']);
    const mayWrite = role === 'reviewer' && writers.has(actor);
    if (path === '/review' && !remoteReview) return json(res, 404, { error: 'Remote review is disabled.' });
    if (write && (!mayWrite || req.headers.origin !== 'https://' + req.headers.host ||
        (req.headers['sec-fetch-site'] && req.headers['sec-fetch-site'] !== 'same-origin'))) {
      return json(res, 403, { error: 'Same-origin authorized reviewer required.' });
    }
    if (reviewerRoutes.has(path) && role !== 'reviewer') return json(res, 403, { error: 'Reviewer access required.' });
    let body;
    if (write) {
      try { body = JSON.stringify(await readReviewBody(req)); }
      catch (error) { return json(res, 400, { error: error.message }); }
    }
    try {
      const result = await fetch(`http://${loopback}:${adapterPort}/v1${path}${url.searchParams.size ? '?' + url.searchParams : ''}`, {
        method: req.method, body,
        headers: { Authorization: 'Bearer ' + token, 'X-Dashboard-Role': role,
          ...(write && { 'Content-Type': 'application/json', 'X-Review-Actor': actor }) },
        redirect: 'error', signal: AbortSignal.timeout(path === '/issues' ? 14_000 : 2500),
      });
      if (path === '/review' && [400, 403, 404].includes(result.status)) return json(res, result.status, await result.json());
      if (result.status === 404) return json(res, 404, { error: 'No published brief for that issue.' });
      if (!result.ok) return json(res, 503, { error: 'Worker data is temporarily unavailable.' });
      return json(res, 200, { ...await result.json(), ...(path === '/overview' ? { role, remoteReview: remoteReview && role === 'reviewer', mayWrite } : {}) });
    } catch {
      return json(res, 503, { error: 'Worker data is temporarily unavailable.' });
    }
  });
}

if (isEntryPoint(import.meta.url)) {
  try {
    const { data, port, token } = configuration(process.argv[2]);
    createDashboard({ origin: data.origin, alternateOrigin: data.alternateOrigin, users: data.users, remoteReview: data.remoteReview === true, reviewWriters: data.reviewWriters, adapterPort: port('adapterPort'), token })
      .listen(port('port'), loopback, () => console.log('Read-only GPU dashboard listening on loopback.'));
  } catch {
    console.error('The dashboard could not start. Check the local HTTPS origin, allowlist, ports and token file.');
    process.exitCode = 1;
  }
}
