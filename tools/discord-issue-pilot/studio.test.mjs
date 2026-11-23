import assert from 'node:assert/strict';
import { once } from 'node:events';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import test from 'node:test';
import { fileURLToPath } from 'node:url';
import { createStudio } from '../game_prompt_studio/server.mjs';
import { studioClient } from './studio.mjs';

test('bot obtains an export-checked brief through the real Studio API', async t => {
  const storage = mkdtempSync(join(tmpdir(), 'houseboat-studio-pilot-'));
  const note = 'The Zero Turn driver steering hands jerk out of place on a sharp left turn. Guest visibility is unverified.';
  let returnInvalidPath = false;
  const server = createStudio({
    project: fileURLToPath(new URL('../../', import.meta.url)),
    storage,
    options: { port: 8765, ollamaPort: 11434, model: 'qwen3:14b', context: 8192,
      keepAliveMinutes: 2, tier: 'detailed', privateOrigin: '', exclude: [] },
    provider: {
      async generate() {
        return { payload: {
          objective: ['Investigate the reported Zero Turn hand movement.'],
          observations: ['The driver reports a jerk during a sharp left turn.'],
          tasks: [returnInvalidPath ? 'Edit godot-cove/nonexistent_pilot_file.gd.'
            : 'Inspect the steering and hand alignment.'],
          verification: ['Repeat the turn as the driver and observe it as a guest.'],
          acceptance: ['Hands stay aligned during the turn.'],
          unknowns: ['Guest visibility is unverified.'],
        }, metrics: { version: 1, context: 8192 } };
      },
    },
  });
  server.listen(0, '127.0.0.1');
  await once(server, 'listening');
  t.after(async () => {
    const closed = once(server, 'close');
    server.close();
    server.closeAllConnections();
    await closed;
    rmSync(storage, { recursive: true, force: true });
  });
  const generate = studioClient('http://127.0.0.1:' + server.address().port);
  const brief = await generate(note);
  assert.ok(brief.includes(note));
  assert.match(brief, /Guest visibility is unverified/);
  returnInvalidPath = true;
  await assert.rejects(generate(note), /Studio blocked the export/);
});
