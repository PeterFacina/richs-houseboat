import { readFileSync } from 'node:fs';
import { dirname, resolve } from 'node:path';
import { pathToFileURL } from 'node:url';

export const repository = 'https://github.com/PeterFacina/richs-houseboat';
export const loopback = '127.0.0.1';
export const pageSize = 24;
export const roles = ['viewer', 'reviewer'];
export const retrievalModes = ['original', 'deterministic-v1'];
export const evidenceKinds = ['source', 'guide', 'github', 'history', 'reported', 'imported', 'attachment', 'verified-lesson', 'other'];
const rootSources = new Set(['AGENTS.md', 'GAME GUIDE AND ASSET CREDITS.md', 'START HERE.txt', 'Play Ottawa River.cmd']);
const privatePaths = /(?:^|[/_.-])(?:\.git|\.godot|node_modules|\.venv|ottawa|build|cache|exports?|secrets?|credentials?|tokens?|passwords?|private|keys?|env)(?:[/_.-]|$)/i;

export const revision = value => typeof value === 'string' && /^[0-9a-f]{40}$/.test(value) ? value : null;
export const number = value => typeof value === 'number' && Number.isFinite(value) && value >= 0 ? value : null;
export const positive = value => Number.isSafeInteger(value) && value > 0 ? value : null;
export const oneOf = (values, value) => values.includes(value) ? value : null;
export const text = (value, maximum = 240) => typeof value === 'string' && value.length > 0 &&
  value.length <= maximum && !/[\p{Cc}\p{Cf}]/u.test(value) ? value : null;
export const date = value => typeof value === 'string' && /^\d{4}-\d{2}-\d{2}T\d{2}:\d{2}:\d{2}(?:\.\d{3})?Z$/.test(value) &&
  Number.isFinite(Date.parse(value)) ? value : null;
export const model = value => typeof value === 'string' && /^[\w.-]{1,64}:[\w.-]{1,64}$/.test(value) ? value : null;
export const flag = value => typeof value === 'boolean' ? value : null;

export function sourcePath(value) {
  if (typeof value !== 'string' || value.length > 240 || privatePaths.test(value) ||
      value.split('/').some(part => !part || part === '.' || part === '..')) return null;
  if (rootSources.has(value) || /^docs\/(?:ARCHITECTURE|systems\/[\w-]+)\.md$/.test(value) ||
      /^godot-cove\/(?:[\w .-]+\/)*[\w .-]+\.(?:gd|tscn|tres|godot|gdshader|gdshaderinc|cs|md|txt)$/i.test(value)) return value;
  return null;
}

export function publication(issue, value) {
  const prefix = repository + '/issues/' + issue + '#issuecomment-';
  return positive(issue) && typeof value === 'string' && value.startsWith(prefix) &&
    /^[1-9]\d*$/.test(value.slice(prefix.length)) ? value : null;
}

export function pullLink(value) {
  const prefix = repository + '/pull/';
  const suffix = typeof value === 'string' && value.startsWith(prefix) ? value.slice(prefix.length) : '';
  return /^[1-9]\d*(?:#[\w-]+)?$/.test(suffix) ? prefix + suffix : null;
}

export function urlPath(req) {
  if (!req.url?.startsWith('/') || req.url.startsWith('//') || req.url.includes('\\') || req.url.length > 512) return null;
  try { return new URL(req.url, 'http://localhost'); } catch { return null; }
}

const decimal = /^(?:0|[1-9]\d*)$/;
const apiRoutes = new Map([['/overview', []], ['/knowledge', ['kind', 'q', 'page']],
  ['/briefs', ['page']], ['/retrieval', ['issue']], ['/learning', ['page']]]);

export function apiInput(path, query) {
  const allowed = apiRoutes.get(path);
  if (!allowed) return null;
  const entries = [...query];
  if (entries.some(([key]) => !allowed.includes(key)) || new Set(entries.map(([key]) => key)).size !== entries.length) return null;
  const page = query.get('page') ?? '0';
  if (!decimal.test(page) || Number(page) > 1000) return null;
  const q = query.get('q')?.trim() ?? '';
  const kind = query.get('kind') ?? 'files';
  const issue = query.get('issue');
  if (q.length > 80 || /[\p{Cc}\p{Cf}]/u.test(q) || !['files', 'functions'].includes(kind) ||
      (path === '/retrieval' && (!decimal.test(issue ?? '') || !positive(Number(issue))))) return null;
  return { page: Number(page), q, kind, issue: Number(issue) };
}

export function json(res, status, value) {
  res.writeHead(status, { 'Content-Type': 'application/json; charset=utf-8' });
  res.end(JSON.stringify(value));
}

export function privateHeaders(res) {
  res.setHeader('Cache-Control', 'no-store');
  res.setHeader('X-Content-Type-Options', 'nosniff');
  res.setHeader('X-Frame-Options', 'DENY');
  res.setHeader('Referrer-Policy', 'no-referrer');
  res.setHeader('Content-Security-Policy', "default-src 'none'; script-src 'self'; style-src 'self'; connect-src 'self'; frame-ancestors 'none'; base-uri 'none'; form-action 'none'");
}

export function configuration(file) {
  if (!file) throw new Error('Supply a local config JSON file.');
  const data = JSON.parse(readFileSync(file, 'utf8').replace(/^\uFEFF/, ''));
  const path = key => {
    if (typeof data[key] !== 'string' || !data[key].trim()) throw new Error('Missing required config field ' + key + '.');
    return resolve(dirname(resolve(file)), data[key]);
  };
  const port = key => {
    if (!Number.isInteger(data[key]) || data[key] < 1024 || data[key] > 65535) throw new Error('Invalid ' + key + '.');
    return data[key];
  };
  const token = readFileSync(path('tokenFile'), 'utf8').trim();
  if (!/^[a-f0-9]{64}$/.test(token)) throw new Error('The adapter token file must contain 64 lowercase hex digits.');
  return { data, path, port, token };
}

export const isEntryPoint = url => process.argv[1] && pathToFileURL(resolve(process.argv[1])).href === url;
