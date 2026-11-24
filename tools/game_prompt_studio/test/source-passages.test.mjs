import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import test from 'node:test';
import { routedSourcePassages } from '../lib/source-passages.mjs';

test('HUD routing scopes excerpts to the owning functions and ignores unrelated matches', () => {
  const db = new DatabaseSync(':memory:');
  try {
    db.exec('CREATE TABLE chunks(path TEXT, line INTEGER, excerpt TEXT)');
    const insert = db.prepare('INSERT INTO chunks VALUES(?,?,?)');
    const cove = 'godot-cove/cove.gd';
    const fishing = 'godot-cove/fishing.gd';
    insert.run(cove, 35, 'func build_hud():\n\tfps.offset_left = -142\n\tfps.offset_right = -14\n\nfunc other():\n\tfps.set_anchors = false');
    insert.run(cove, 49, 'func _unhandled_input(event):\n\tif event.physical_keycode == KEY_F3:\n\t\tfps.visible = not fps.visible');
    insert.run(fishing, 105, 'func update_hud():\n\tfps.text = graphics.description()');
    insert.run('godot-cove/other.gd', 1, 'func layout():\n\tvar text = "HUD FPS"');
    const manifest = { files: {
      [cove]: { symbols: [
        { kind: 'func', name: 'build_hud', line: 35 }, { kind: 'func', name: 'other', line: 39 },
        { kind: 'func', name: '_unhandled_input', line: 49 },
      ] },
      [fishing]: { symbols: [{ kind: 'func', name: 'update_hud', line: 105 }] },
    } };
    const routed = routedSourcePassages(db, manifest, 'HUD layout: check FPS in all presets and preserve the toggle');
    assert.deepEqual(routed.passages.map(item => [item.path, item.title, item.line]), [
      [cove, 'build_hud', 35], [fishing, 'update_hud', 105], [cove, '_unhandled_input', 49],
    ]);
    assert.ok(!routed.passages[0].excerpt.includes('func other'));
    assert.ok(routed.passages.every(item => item.excerpt.length <= 590));
    assert.equal(routedSourcePassages(db, manifest, 'Check water drift and docking'), null);
    assert.equal(routedSourcePassages(db, { files: {} }, 'HUD FPS check'), null);
  } finally {
    db.close();
  }
});
