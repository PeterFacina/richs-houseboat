import { DatabaseSync } from 'node:sqlite';
import { join } from 'node:path';

export function gpuWorkLock(directory) {
  const db = new DatabaseSync(join(directory, 'gpu-activity.sqlite'));
  db.exec('PRAGMA busy_timeout=0; CREATE TABLE IF NOT EXISTS gpu_gate (id INTEGER PRIMARY KEY)');
  return {
    async run(work) {
      try { db.exec('BEGIN IMMEDIATE'); }
      catch (error) {
        if (error.errcode !== 5) throw error;
        throw new Error('GPU busy with an approved training or evaluation run.');
      }
      try { return await work(); }
      finally { db.exec('ROLLBACK'); }
    },
    close() { db.close(); },
  };
}
