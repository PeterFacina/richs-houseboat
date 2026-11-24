import assert from 'node:assert/strict';
import { DatabaseSync } from 'node:sqlite';
import test from 'node:test';
import { catalogPassages } from '../lib/catalog-passages.mjs';

test('catalog ranker returns bounded function passages from known files', () => {
  const db = new DatabaseSync(':memory:');
  try {
    db.exec('CREATE VIRTUAL TABLE chunks USING fts5(path, line UNINDEXED, excerpt)');
    const add = db.prepare('INSERT INTO chunks VALUES(?,?,?)');
    const pump = 'godot-cove/pump.gd';
    const valve = 'godot-cove/valve.gd';
    add.run(pump, 1, 'func prime_pump():\n\tvalve.open_valve()\n\tpressure += 1\n\nfunc unrelated():\n\tpass');
    add.run(valve, 10, 'func open_valve():\n\tvalve_open = true\n\tpressure = pressure_limit');
    add.run('godot-cove/unindexed.gd', 7, 'func fake_pump():\n\tpressure = 99');
    const manifest = { files: {
      [pump]: { symbols: [{ kind: 'func', name: 'prime_pump', line: 1 },
        { kind: 'func', name: 'unrelated', line: 5 }], references: [valve] },
      [valve]: { symbols: [{ kind: 'func', name: 'open_valve', line: 10 }], references: [] },
    } };
    const result = catalogPassages(db, manifest, 'Inspect prime_pump and valve pressure.');
    assert.deepEqual(new Set(result.map(item => item.title)), new Set(['prime_pump', 'open_valve']));
    assert.ok(result.every(item => item.excerpt.length <= 590 && !item.excerpt.includes('func unrelated')));
    assert.deepEqual(catalogPassages(db, manifest, 'zeppelin'), []);
  } finally {
    db.close();
  }
});
