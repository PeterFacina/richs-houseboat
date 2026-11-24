import { once } from 'node:events';
import { existsSync, mkdtempSync, readFileSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { fileURLToPath } from 'node:url';
import { createStudio } from '../game_prompt_studio/server.mjs';
import { studioClient } from './studio.mjs';

const project = fileURLToPath(new URL('../../', import.meta.url));
const model = process.argv[2] ?? 'qwen3:14b';
const reportFile = process.argv[3];
const note = reportFile ? readFileSync(reportFile, 'utf8').replace(/^\uFEFF/, '').trim()
  : 'When I make a sharp left turn on the Zero Turn, the driver’s steering hands jerk out of place. I haven’t checked whether a guest can see it.';
if (!note || note.length > 6500) throw new Error('The report must contain 1–6500 characters.');
if (!existsSync(join(project, 'godot-cove', 'lawn_mower.gd'))) {
  throw new Error('Extract the smoke test into the shared game checkout containing godot-cove/lawn_mower.gd.');
}
const tags = await fetch('http://127.0.0.1:11434/api/tags', { signal: AbortSignal.timeout(5000) })
  .catch(() => { throw new Error('Start Ollama on this PC before running the GPU smoke test.'); });
if (!tags.ok || !(await tags.json()).models?.some(entry => entry.name === model)) {
  throw new Error('The requested model is not available in Ollama: ' + model);
}

const storage = mkdtempSync(join(tmpdir(), 'houseboat-gpu-smoke-'));
let server;
try {
  server = createStudio({ project, storage, options: {
    port: 8765, ollamaPort: 11434, model, context: 8192, keepAliveMinutes: 2,
    tier: 'detailed', privateOrigin: '', exclude: [],
  } });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  const generate = studioClient('http://127.0.0.1:' + server.address().port);
  const start = performance.now();
  const brief = await generate(note);
  console.log(brief);
  const log = reportFile ? console.error : console.log;
  log('Model: ' + model);
  log('Elapsed: ' + ((performance.now() - start) / 1000).toFixed(1) + ' seconds');
  log('Studio export check: passed');
  if (!reportFile) log('Mower source citation: ' + (/\[S\d+\] godot-cove\/lawn_mower\.gd:\d+/.test(brief) ? 'present' : 'missing'));
} finally {
  if (server?.listening) {
    const closed = once(server, 'close');
    server.close();
    server.closeAllConnections();
    await closed;
  }
  rmSync(storage, { recursive: true, force: true });
}
