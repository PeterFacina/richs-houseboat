# Game Prompt Studio handoff for Peter

Source snapshot of Studio 1.0.0 from the GPU PC. Studio lives at `tools/game_prompt_studio/` in the standalone game folder. The separate team checkout was clean on `main` at `34a7a51`. Studio is absent from that commit.

## Set up locally

Extract the archive into an editable Rich’s Houseboat game root containing `godot-cove/project.godot`. Keep the archive’s `tools/game_prompt_studio/` path so Studio can find the game. Use Node.js 24 or later and a locally running Ollama with the selected model installed. The package uses Node’s built-in SQLite and has no npm dependencies.

From that game root in PowerShell:

```powershell
Set-Location '.\tools\game_prompt_studio'
$env:STUDIO_DATA_DIR = Join-Path $env:LOCALAPPDATA 'GamePromptStudio\peter-local-dev'
npm.cmd test
node .\server.mjs
```

Open `http://127.0.0.1:8765/`. First launch builds the source index in the local data directory. `config.example.json` supplies the default model `qwen3:14b` and Ollama port `11434`. Use Studio Settings to select an installed local model. The archive contains sample configuration only.

## Browser and local HTTP contract

The browser submit handler lives in `public/app.js` at `readTask()` and the `compose-form` handler. It sends a generation request, polls the job about every 750 ms, then calls `loadRecord()` to get the saved brief.

1. `GET /api/session` returns `{privateMode, tailscaleMode, user: {name, role, csrf} | null}`. Use the session’s CSRF token for writes. In default loopback mode, use the exact local origin as `Origin` and send `Content-Type: application/json`, `X-Studio-Request: 1`, and `X-Studio-CSRF: <session token>` on the JSON POST. Private mode uses its configured host and existing authentication.
2. `POST /api/generate` accepts `{note, title?, tier?, focus?, parentId?, priority?, author?, tags?}`. Only `note` is required, with at most 6,500 characters. `tier` is `quick`, `detailed` or `comprehensive`, and defaults to the current setting. `focus` accepts up to four indexed project-relative paths. `parentId` is an existing prompt ID or null. `priority` is `Low`, `Normal` or `High`. The response is HTTP 202 with `{id: "<job UUID>"}`. HTTP 409 means the local model already has an active job.
3. `GET /api/jobs/<job UUID>` returns `{status, recordId?, findings?, error?}`. Status is `working`, `canceling`, `complete`, `failed`, or `canceled`. On completion, `recordId` is the saved numeric record ID and `findings` is an array of export-check messages. Jobs are in memory and polled by the same Studio identity. The optional `POST /api/jobs/<job UUID>/cancel` returns `{status}`.
4. `GET /api/prompts/<record ID>` returns the saved record. Read `prompt` for the brief, `status` for `generated` or `needs revision`, `evidence` for source provenance, and `findings` for review. Other fields include `id`, `title`, `note`, `model`, `tier`, `author`, `tags`, `priority`, `outcome`, `generation`, `created_at`, `updated_at`, `revision`, and `parent_id`. Source evidence has `id`, `kind: "source"`, `path`, `line`, `excerpt` and `reason`. Other evidence kinds are historical reports, imports, Studio history, or screenshot descriptions.
5. `GET /api/prompts/<record ID>/download` runs the export guard and returns UTF-8 plain text on HTTP 200. HTTP 422 returns JSON `{error, findings?}`. A completed job can still require revision, so use the guarded download or surface its findings before handing off the brief.

Minimal generation input:

```json
{"note":"Describe the observed issue and what remains unverified."}
```

## Integration location

`server.mjs` exports `createStudio()` and contains the generation and record routes. Its internal `startJob()` validates the job lifecycle and runs retrieval (`lib/index.mjs`), the Ollama provider and deterministic renderer (`lib/model.mjs`), export checks, and persistence (`lib/db.mjs`). A client with an authorized local Studio session can use the existing HTTP contract. For an eventual in-process adapter, the complete `startJob()` pipeline is the extraction point. The Ollama provider alone only returns structured model output and metrics.

The active GPU Studio returned HTTP 403 for a direct loopback request using the default Host header. A later integration with that deployment needs its approved authentication path. The handoff covers the existing local interface.

## Verification

- Existing suite passed 11 of 11 tests on Node.js 24.15.0.
- One real generation ran through a temporary loopback Studio with the live model settings and running Ollama 0.40.17. The temporary index contained 82 files. The job completed with `qwen3:14b` and took about 25 seconds. The live Studio database was opened read-only for model settings.
- The exact Zero Turn report stayed in the brief. Guest visibility remained an open check. All five cited source files and lines were present, and the guard and TXT download returned HTTP 200. The downloaded text matched the stored brief.
- Grounding gap. The temporary index used the standalone game root, which lacks `godot-cove/lawn_mower.gd`. The team checkout contains that file. The brief cited available crew, avatar and other game code, so it did not ground the issue in the mower implementation.
- This handoff preserves the runtime and test files byte for byte. README and START_HERE were adjusted in the archive for local setup. It bundles this handoff guide with the example configuration, without host data.
