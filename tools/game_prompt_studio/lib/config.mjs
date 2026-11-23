import { existsSync, readFileSync } from 'node:fs';
import { homedir } from 'node:os';
import { dirname, join, resolve } from 'node:path';
import { fileURLToPath } from 'node:url';
import { validName } from './auth.mjs';
import { sha } from './db.mjs';
import { isLocalModel, tiers } from './model.mjs';

export const appDir = dirname(dirname(fileURLToPath(import.meta.url)));
export const projectDir = resolve(appDir, '..', '..');
export const dataDir = process.env.STUDIO_DATA_DIR ? resolve(process.env.STUDIO_DATA_DIR) :
  join(process.env.LOCALAPPDATA || join(homedir(), '.local', 'share'), 'GamePromptStudio', 'projects', sha(projectDir.toLowerCase()).slice(0, 16));
export const configPath = join(dataDir, 'config.json');
const defaults = JSON.parse(readFileSync(join(appDir, 'config.example.json'), 'utf8'));

function validPort(value) {
  return Number.isInteger(value) && value >= 1024 && value <= 65535;
}

export function config() {
  const saved = existsSync(configPath) ? JSON.parse(readFileSync(configPath, 'utf8')) : {};
  const value = { ...defaults, ...saved };
  if (!validPort(value.port) || !validPort(value.ollamaPort) || value.port === value.ollamaPort) throw new Error('Configure separate loopback ports in config.json.');
  if (value.privateOrigin && !/^https:\/\/[a-z0-9-]+(?:\.[a-z0-9-]+)+\.ts\.net$/i.test(value.privateOrigin)) {
    throw new Error('privateOrigin must be the exact HTTPS Tailscale Serve origin with no slash.');
  }
  if (value.tailscaleUsers != null) {
    if (!value.privateOrigin || typeof value.tailscaleUsers !== 'object' || Array.isArray(value.tailscaleUsers)) {
      throw new Error('tailscaleUsers must be an object and requires privateOrigin.');
    }
    const entries = Object.entries(value.tailscaleUsers);
    if (entries.some(([login, account]) => !/^[!-~]{1,320}$/.test(login) || login.includes(',') ||
      !validName(account?.name) || !['admin', 'member'].includes(account?.role))) {
      throw new Error('Each Tailscale login must map to a valid Studio name and an admin or member role.');
    }
    const accounts = Object.values(value.tailscaleUsers);
    if (!accounts.some(account => account.role === 'admin') || new Set(accounts.map(account => account.name)).size !== accounts.length) {
      throw new Error('Configure at least one Tailscale administrator and a unique Studio name for each login.');
    }
  }
  if (!Array.isArray(value.exclude) || value.exclude.some(path => typeof path !== 'string' || path.includes('\\') ||
      path.startsWith('/') || /(?:^|\/)\.\.(?:\/|$)/.test(path))) throw new Error('Use project-relative forward-slash paths for exclude.');
  return { ...value, ...modelSettings(value) };
}

export function modelSettings(value) {
  if (!isLocalModel(value.model)) throw new Error('Select a tagged local model, such as qwen3:14b.');
  if (![4096, 8192, 12288, 16384].includes(value.context)) throw new Error('Choose a supported context size.');
  if (!Number.isInteger(value.keepAliveMinutes) || value.keepAliveMinutes < 0 || value.keepAliveMinutes > 20) throw new Error('Keep-alive must be 0–20 minutes.');
  if (!Object.hasOwn(tiers, value.tier)) throw new Error('Choose a valid output detail.');
  return { model: value.model, context: value.context, keepAliveMinutes: value.keepAliveMinutes, tier: value.tier };
}

export function getSettings(db, startupConfig) {
  const row = db.prepare("SELECT value FROM settings WHERE name='model'").get();
  return modelSettings(row ? JSON.parse(row.value) : startupConfig);
}
