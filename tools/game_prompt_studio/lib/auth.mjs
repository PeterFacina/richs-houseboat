import { createHmac, randomBytes, scrypt, scryptSync, timingSafeEqual } from 'node:crypto';
import { promisify } from 'node:util';
import { audit, sha, transaction } from './db.mjs';

const derive = promisify(scrypt);
const cookie = '__Host-studio';
const maxAge = 8 * 60 * 60;
export const validName = name => typeof name === 'string' && /^[a-z0-9][a-z0-9._@-]{1,79}$/.test(name);

export function setUser(db, name, password, role = 'member') {
  if (!validName(name) || !['member', 'admin'].includes(role)) throw new Error('Use a lowercase account name and role member or admin.');
  if (typeof password !== 'string' || password.length < 8 || password.length > 256) throw new Error('Use a password between 8 and 256 characters.');
  const salt = randomBytes(16).toString('hex');
  const digest = scryptSync(password, salt, 64).toString('hex');
  transaction(db, () => {
    db.prepare('INSERT INTO users(name,salt,digest,role) VALUES(?,?,?,?) ON CONFLICT(name) DO UPDATE SET salt=excluded.salt,digest=excluded.digest,role=excluded.role')
      .run(name, salt, digest, role);
    db.prepare('DELETE FROM sessions WHERE username=?').run(name);
    audit(db, name, 'account configured');
  });
}

export function createAuth(db, privateMode, tailscaleUsers) {
  const attempts = new Map();
  let inflight = 0;
  const localCsrf = randomBytes(24).toString('base64url');
  let globalWindow = { count: 0, end: 0 };
  const limit = (entry, time) => entry?.end > time ? entry : { count: 0, end: time + 300_000 };

  function viewer(req) {
    if (!privateMode) return { name: 'Local host', role: 'admin', csrf: localCsrf, token: null };
    if (tailscaleUsers) {
      const identity = req.headers['tailscale-user-login'];
      if (req.socket.remoteAddress !== '127.0.0.1' || typeof identity !== 'string' ||
        !Object.hasOwn(tailscaleUsers, identity)) return null;
      const csrf = createHmac('sha256', localCsrf).update(identity).digest('base64url');
      return { ...tailscaleUsers[identity], csrf };
    }
    const raw = /(?:^|;\s*)__Host-studio=([A-Za-z0-9_-]{43})(?:;|$)/.exec(req.headers.cookie ?? '')?.[1];
    if (!raw) return null;
    const token = sha(raw);
    const row = db.prepare('SELECT s.csrf,u.name,u.role FROM sessions s JOIN users u ON u.name=s.username WHERE token_hash=? AND expires>?')
      .get(token, Date.now());
    return row ? { ...row, token } : null;
  }

  async function login(name, password) {
    const time = Date.now();
    if (typeof password !== 'string' || password.length > 256 || !validName(name)) return { status: 401 };
    for (const [key, value] of attempts) if (value.end <= time) attempts.delete(key);
    const window = limit(attempts.get(name), time);
    globalWindow = limit(globalWindow, time);
    if (inflight >= 3 || window.count >= 8 || globalWindow.count >= 30) return { status: 429 };
    attempts.set(name, window);
    window.count++;
    globalWindow.count++;
    const user = db.prepare('SELECT * FROM users WHERE name=?').get(name);
    let digest;
    inflight++;
    try { digest = await derive(password, user?.salt ?? 'unknown-account', 64); }
    finally { inflight--; }
    if (!user || !timingSafeEqual(digest, Buffer.from(user.digest, 'hex'))) return { status: 401 };
    attempts.delete(name);
    const raw = randomBytes(32).toString('base64url');
    const csrf = randomBytes(24).toString('base64url');
    db.prepare('DELETE FROM sessions WHERE expires<=?').run(time);
    db.prepare('INSERT INTO sessions VALUES (?,?,?,?)').run(sha(raw), name, csrf, time + maxAge * 1000);
    audit(db, name, 'signed in');
    return { status: 200, name, role: user.role, csrf,
      cookie: cookie + '=' + raw + '; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=' + maxAge };
  }

  function logout(user) {
    db.prepare('DELETE FROM sessions WHERE token_hash=?').run(user.token);
    audit(db, user.name, 'signed out');
    return cookie + '=; Path=/; HttpOnly; Secure; SameSite=Strict; Max-Age=0';
  }
  return { viewer, login, logout };
}
