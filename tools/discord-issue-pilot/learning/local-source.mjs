import { execFileSync } from 'node:child_process';
import { resolve } from 'node:path';
import { fileURLToPath } from 'node:url';

export function localSource(path) {
  const root = resolve(path);
  const options = { encoding: 'utf8', maxBuffer: 24 * 1024 * 1024, env: { ...process.env, PYTHONUTF8: '1' } };
  const git = (...args) => execFileSync('git', ['-C', root, ...args], options);
  if (git('status', '--porcelain', '--', 'godot-cove', 'docs', 'tools/godot-lookup').trim()) throw new Error('Source checkout must be clean');
  const script = fileURLToPath(new URL('../../knowledge/index.py', import.meta.url));
  const manifest = JSON.parse(execFileSync(process.env.HOUSEBOAT_KNOWLEDGE_PYTHON || 'python', [script, '--root', root], options));
  if (manifest.dirty) throw new Error('Source manifest is dirty');
  return { root, manifest, tracked: git('ls-files', '-z').split('\0').filter(Boolean) };
}
