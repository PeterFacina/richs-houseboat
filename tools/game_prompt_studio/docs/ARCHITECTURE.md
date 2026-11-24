# Data and recovery

The Windows launcher starts a dependency-free Node server on loopback. SQLite stores prompts, revisions, settings, account records, import batches, screenshot bytes, and FTS5 indexes. Browser pages load from the app. Ollama accepts structured generation requests over its separate loopback port. The browser can poll and cancel a generation. Only one job occupies the model per running studio.

## Knowledge

The Discord GPU worker uses Studio's managed generation path. See the [worker knowledge runbook](../../../docs/GPU-WORKER-KNOWLEDGE.md) for the source checkout, transactional index, bounded retrieval, and training provenance. Interactive Studio indexes its configured project and can retrieve subsystem guides from that checkout.

The scanner reads approved root documents and bounded UTF-8 Godot text under `godot-cove`. It records relative paths, sizes, modification times and SHA-256 hashes. A rescan compares hashes and updates changed chunks. The app excludes the baked Ottawa data, caches, private-looking files, sibling playtest copies, linked paths, and large or unsupported files. Add project-relative paths to the app config’s `exclude` array before a scan if you need additional exclusions.

Retrieval uses SQLite FTS5, matched game systems, and the user’s selected files. Each generation stores the excerpts it actually retrieved. The project profile derives a small set of facts from the indexed configuration and launcher. Master-brief reports, teammate imports, user outcomes and screenshot descriptions keep separate provenance. Archived, rejected and superseded Studio records are excluded from new retrieval. Past snapshots remain available for review in saved records.

Restarts retain saved notes, prompt versions, model settings, history and attachments. The runtime database location is shown by `node .\control.mjs paths`. Moving the extracted folder changes the default per-project data path. Use a stable `STUDIO_DATA_DIR` to reopen the chosen database after moving the working copy, then rescan the new copy.

## Back up or restore

Use **Settings → Create backup** or `node .\control.mjs backup`. This uses SQLite’s backup API to generate a consistent `backups\studio-*.sqlite` file. Back up `config.json` separately if you need to keep the loopback ports and private hostname.

To restore, stop the studio and any backup process, then use the data path printed by `node .\control.mjs paths`. Keep the current `studio.sqlite` and any `studio.sqlite-wal` and `studio.sqlite-shm` together in a separate recovery directory outside the live data folder. Copy the selected backup to the live folder as `studio.sqlite`. Start Studio, verify a known record and its attachments, and rescan the project. The backup includes account hashes, studio records and screenshots. Keep it under the host account’s access controls. If restoring a team backup, rotate passwords or revoke and recreate accounts if session invalidation is needed.
