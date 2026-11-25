import assert from 'node:assert/strict';
import { createHash } from 'node:crypto';
import { mkdirSync, mkdtempSync, rmSync, writeFileSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { dirname, join } from 'node:path';
import test from 'node:test';
import { resolveGameRoutes } from '../knowledge/game-routes.mjs';
import routes from '../knowledge/game-routes.json' with { type: 'json' };
import { buildCodeIndex } from './multistage/code-index.mjs';
import { collectGameEvidence } from './multistage/game-route-evidence.mjs';

test('canonical file passages survive deterministic ranking and resolve legacy names', t => {
  const root = mkdtempSync(join(tmpdir(), 'houseboat-routed-evidence-'));
  t.after(() => rmSync(root, { recursive: true, force: true }));
  const files = {};
  const tracked = [];
  function write(path, text, symbols = []) {
    mkdirSync(dirname(join(root, path)), { recursive: true });
    writeFileSync(join(root, path), text);
    tracked.push(path);
    files[path] = { sha256: createHash('sha256').update(text).digest('hex'), symbols, references: [] };
  }

  const names = [...Object.values(routes.aliases), 'quest_chain.gd', 'npc_quest_offer.gd', 'progression.gd', 'progression_catalog.gd'];
  for (const name of names) {
    if (name.endsWith('.tscn')) write('godot-cove/' + name, '[gd_scene]\n[node name="World" type="Node3D"]\n');
    else write('godot-cove/' + name, 'extends Node\n\nfunc implement_system() -> void:\n\tpass\n',
      [{ kind: 'func', name: 'implement_system', line: 3 }]);
  }
  write('godot-cove/unrelated.gd', 'extends Node\n\nfunc locate_fishing_river_world() -> void:\n\tpass\n',
    [{ kind: 'func', name: 'locate_fishing_river_world', line: 3 }]);
  write('docs/ARCHITECTURE.md', '# Map\n\nThe Deep River map uses terrain data.\n');
  write('docs/GAME-IDENTITY.md', '# Progression\n\nA future research tree could add knowledge unlocks.\n');
  write('docs/systems/QUESTS.md', '# Quest framework\n\nMultiple NPC quests use shared state.\n');
  write('docs/systems/PROGRESSION-ECONOMY.md', '# Universal XP\n\nOwner and guests each gain player XP.\n');
  const index = buildCodeIndex(root, { files }, tracked);

  for (const [legacy, current] of Object.entries(routes.aliases)) {
    const expected = 'godot-cove/' + current;
    assert.equal(collectGameEvidence(index, 'Locate ' + legacy)[0].path, expected);
    assert.equal(collectGameEvidence(index, 'Locate ' + current)[0].path, expected);
  }
  for (const [query, path, guide] of [
    ['Trace the multiple NPC questlines', 'godot-cove/quest_chain.gd', 'docs/systems/QUESTS.md'],
    ['Find Universal XP', 'godot-cove/progression.gd', 'docs/systems/PROGRESSION-ECONOMY.md'],
    ['Find the research tree', 'godot-cove/progression.gd', 'docs/GAME-IDENTITY.md'],
    ['Find res://ottawa/terrain.f32', 'godot-cove/deep_river_map.gd', 'docs/ARCHITECTURE.md'],
  ]) {
    const evidence = collectGameEvidence(index, query);
    assert.equal(evidence[0].path, path);
    assert.ok(evidence.some(item => item.path === guide));
    assert.equal(new Set(evidence.map(item => item.id)).size, evidence.length);
    assert.ok(evidence.reduce((sum, item) => sum + item.excerpt.length, 0) <= 5800);
  }
  assert.match(resolveGameRoutes('res://ottawa/terrain.f32').lookup, /^res:\/\/deep_river\//);
  assert.ok(!collectGameEvidence(index, 'Find Universal XP').some(item => item.path === 'docs/GAME-IDENTITY.md'));
  writeFileSync(join(root, 'godot-cove/game_world.gd'), '# changed after indexing\n');
  assert.throws(() => collectGameEvidence(index, 'Locate fishing.gd'), /Evidence changed/);
});
