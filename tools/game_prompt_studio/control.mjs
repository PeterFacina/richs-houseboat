import { stdout } from 'node:process';
import { openDb, audit, snapshot } from './lib/db.mjs';
import { setUser, validName } from './lib/auth.mjs';
import { config, configPath, dataDir, projectDir } from './lib/config.mjs';
import { scan } from './lib/index.mjs';

const [action, rawName, role] = process.argv.slice(2);
const name = rawName?.toLowerCase();
if (action === 'paths') {
  console.log(JSON.stringify({ dataDir, configPath, port: config().port, ollamaPort: config().ollamaPort, privateOrigin: config().privateOrigin }));
} else {
  const db = openDb(dataDir);
  try {
    if (action === 'init') {
      console.log(JSON.stringify(scan(db, projectDir, config().exclude)));
    } else if (action === 'user-set') {
      if (process.stdin.isTTY) throw new Error('Use team_windows.ps1 to enter a password securely.');
      let password = '';
      for await (const chunk of process.stdin.setEncoding('utf8')) {
        password += chunk;
        if (password.length > 260) throw new Error('Password is too long.');
      }
      setUser(db, name, password.replace(/\r?\n$/, ''), role);
      stdout.write('Account saved and previous sessions revoked.\n');
    } else if (action === 'user-revoke') {
      if (!validName(name)) throw new Error('Enter a valid account name.');
      const result = db.prepare('DELETE FROM users WHERE name=?').run(name);
      if (result.changes) audit(db, name, 'account revoked');
      console.log(result.changes ? 'Account and active sessions revoked.' : 'No matching account.');
    } else if (action === 'backup') {
      console.log((await snapshot(db, dataDir)).name);
    } else {
      throw new Error('Choose init, paths, user-set, user-revoke, or backup.');
    }
  } finally { db.close(); }
}
