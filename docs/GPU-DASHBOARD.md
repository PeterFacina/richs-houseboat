# Authoritative GPU dashboard

The dashboard for [issue #85](https://github.com/PeterFacina/richs-houseboat/issues/85) reads the Discord worker’s existing source index and private capture store. It opens neither the standalone Studio’s database nor the Discord bot’s queue. The standalone prompt library, accounts, settings and screenshots remain with the standalone app.

## Data and permissions

| View | Source and scope |
| --- | --- |
| Worker overview | The latest committed main revision, index timestamp, project facts and last observed GitHub target. A live heartbeat supplies the worker release commit, model tag, configured retrieval mode and canary state. With an older worker, the page labels runtime configuration unreported and identifies the last recorded brief separately. |
| Game knowledge | Files actually stored in the worker’s SQLite index and their function declarations in the matching manifest. The manifest total is shown separately when it includes functions in files omitted from excerpt indexing. Search and links use the pinned revision. |
| Retrieval | Published issue links, selected evidence types, guard status, verified lesson use and citations at the captured revision. The dashboard never substitutes current line numbers for old citations. An older capture without a recorded effective mode shows **Unrecorded**. Reviewers also see measured latency, tokens and review metadata. |
| Learning | Reviewer-only counts and outcomes. The curated historical catalogue is checked against the current pinned function bodies and marks stale anchors for revalidation. Ordinary Studio history stays a different evidence type. |

Generated briefs count saved captures, including blocked or unpublished generations. Published counts use capture links. Completed tasks count the latest recorded outcome per issue linked to a published capture. Corrections sum the explicit `humanCorrections` values for those outcomes. Feedback entries are a separate count. Approved training examples count distinct published captures with a stored approval and target. Collecting an example, approving its target and applying a verified historical lesson are separate events. This worker records no model fine-tuning runs. The dashboard cannot initiate one.

Token totals separate Ollama brief generation from coding-agent work on recorded outcomes. Each total carries its measured sample count. Average times and counts use recorded measurements, with missing fields left unrecorded. Coding-agent totals can include cached input and reasoning output when provided. Keep those breakdowns separate from their containing totals. The dashboard does not estimate model costs or test success from missing telemetry.

### Access boundary

- The web server listens on IPv4 loopback behind the existing HTTPS Tailscale Serve route. It checks the expected host and a named viewer or reviewer allowlist using the identity header supplied by Serve. Keep Serve as the sole proxy, keep Funnel off and restrict Tailnet access to the team. Local host processes are trusted at this proxy boundary. Review allowlist membership when repository access changes. [Tailscale Serve identity guidance](https://tailscale.com/docs/features/tailscale-serve#identity-headers)
- The data adapter listens on a different loopback port and requires its own 32-byte secret, stored in a local file readable only by the two service identities. The web server determines the role server-side. Dashboard callers cannot request arbitrary paths or SQL, set their own role, list unpublished captures, or call the worker’s internal generation server.
- Give the adapter access to the two authoritative databases and the worker’s pinned source checkout. Run the web server under a different account without access to the private stores, GitHub credentials or worker environment file. The adapter opens SQLite read-only with a short busy timeout and closes each read transaction promptly. An unavailable store degrades its own view. Neither process scans source into another index, runs a migration, uses `immutable` on the live DB, or initiates a model request. The overview caches its sanitized result in memory for 15 seconds.
- Check the adapter account can read SQLite’s WAL and shared-memory sidecars while the worker has the databases open. Use the existing host-local stores. Keep the adapter on the same machine as their writer. When backing up, use SQLite’s backup API or follow the existing clean-shutdown procedure. [SQLite WAL read-only support](https://sqlite.org/wal.html#read_only_databases)
- The adapter returns named fields only. Raw reports, prompt bodies, request JSON, source excerpts, free-form feedback, corrected targets, unpublished issue IDs and capture IDs remain in the local operator tools. The browser receives no training export, credentials or write route. Review corrections, outcomes and approvals still use the private `training-review.mjs` workflow.

## Run alongside Prompt Studio

1. Use Node 24 on the GPU host. Prepare two local config JSON files outside the repository, with an independent token file containing 64 lowercase hex digits from 32 random bytes. Restrict the config and token files to the relevant local accounts. Choose unused ports.
2. Start the adapter, then the dashboard, with their own local configs. Do not feed either service `.worker.env`. The adapter uses the existing worker storage location if the worker is configured with a nondefault path. Use a separate preview checkout and leave the Discord worker, bot and standalone Studio online.
3. Before cutover, verify the authorized viewer and reviewer roles, an unlisted Tailnet account, direct adapter denial, read-only HTTP methods and lack of database or request exports. Compare a real source revision and an issue’s published evidence against the worker locally. Confirm the dashboard works when the heartbeat is absent or when the store is busy. If testing with a copy, take an online SQLite backup instead of copying the live DB file alone.
4. To share the dashboard alongside Prompt Studio, use a free Tailscale HTTPS port such as `8443`. Set `origin` to the full HTTPS origin including that port, and allow the intended Tailscale login names as `viewer`. Verify that Serve has no existing route on the chosen port before adding it. Verify the dashboard over HTTPS using an allowed account and check that the existing Studio route still opens. To remove the dashboard route, run `tailscale serve --https=8443 off`.
5. The dashboard works with older captures and an older worker. On a separately approved worker rollout, set `HOUSEBOAT_DASHBOARD_STATUS=1` for the reviewed clean worker checkout to publish a versioned heartbeat at `worker-status.json` in its existing knowledge directory. The heartbeat contains allowlisted runtime fields and the last source refresh check. A missing or more than two-minute-old heartbeat is shown as unknown or stale. This setting leaves retrieval, capture and Discord publication under their existing controls.

Example adapter config. Use the actual local worker paths rather than the placeholders.

```json
{
  "port": 8767,
  "tokenFile": "adapter-token.txt",
  "workerStorage": "D:/HouseboatLocal/HouseboatGpuKnowledge",
  "trainingInbox": "D:/HouseboatLocal/HouseboatPromptTraining/examples.sqlite"
}
```

Example web config. Give the web identity access to its config, app and token only. Use the existing exact Tailnet origin.

```json
{
  "port": 8766,
  "adapterPort": 8767,
  "origin": "https://houseboat.example.ts.net:8443",
  "tokenFile": "adapter-token.txt",
  "users": {
    "viewer@example.invalid": "viewer",
    "reviewer@example.invalid": "reviewer"
  }
}
```

```powershell
node tools/gpu-dashboard/adapter.mjs 'D:\HouseboatLocal\adapter.json'
node tools/gpu-dashboard/server.mjs 'D:\HouseboatLocal\dashboard.json'
```

Run the commands in separate local services. Keep the foreground processes in their own consoles during preview.

```powershell
tailscale serve status
tailscale serve --bg --https=8443 http://127.0.0.1:8766
tailscale serve status
```

The worker checks GitHub `main` at startup and before generating a queued brief. The dashboard reads the last committed index and published GitHub brief links from the worker stores. Its Refresh button reloads those records. GitHub links to the private repository require the viewer’s own repository access.

Retrieval lists issues with a published GPU brief. Use the [GitHub issue tracker](https://github.com/PeterFacina/richs-houseboat/issues) to find open issues that are awaiting a brief or are outside the worker queue.

### Recover the Windows web process

If Tailscale returns 502 and the dashboard port has no listener, check the Local Service task’s last exit result and its launcher log. The web process on Windows 11 build 26200 exited with `0xC0000409` on Node.js 24.15.0. The same exit code has been reported upstream on that Windows build. Use a current Node.js 24 LTS build for the web task. The host now runs a dedicated verified Node.js 24.22.3 executable with `--no-maglev`. The web task keeps its startup trigger and an additional one-minute trigger with **IgnoreNew**, so a running instance is left in place and an exited instance can recover. [Node.js Windows crash report](https://github.com/nodejs/node/issues/62260)

The timed trigger started the updated web process after the previous instance was stopped. The browser loaded Game Knowledge with 205 files, and the overview, search, retrieval and learning requests returned 200 over Tailscale. The five dashboard tests passed on the updated runtime.

Replacing the Studio root route is a separate cutover. After approval for that cutover, record the existing proxy target, repoint the root to the reviewed dashboard, and verify HTTPS and both dashboard roles. Restore the recorded proxy target to roll back.

## Verification

```powershell
node --test tools/gpu-dashboard/test/*.test.mjs tools/discord-issue-pilot/*.test.mjs tools/game_prompt_studio/test/*.test.mjs
python -m unittest discover -s tools/knowledge -p 'test_*.py'
```

Tests cover the role boundary, denied writes and adapter bypass, captured citation revisions, redaction, approval deduplication, recorded-only metrics, obsolete worker metadata, and unchanged SQLite contents. An isolated HTTP smoke read the real worker stores at `59f55b3` and matched all 205 indexed files, 1,957 browsable functions out of 2,000 in the manifest, brief counts and recorded input-token totals. It returned seven citations and the fresh indexed revision for issue #84 and validated the #69 lesson. The legacy worker did not emit a heartbeat. No active Tailscale route was changed. Chrome exercised the synthetic overview, function search, mobile retrieval and learning views.

The side-by-side Windows deployment uses a loopback adapter task under the worker data owner and a web task under Local Service. The web task has read access to its runtime files and a separate log directory. The adapter starts at the data owner’s Windows sign-in. The real HTTPS dashboard, its assets, and the existing Studio route returned 200. The worker index matched the GitHub `main` ref at `59f55b3`, and the actual dashboard returned the published evidence for issue #84. Local boundary checks verified both configured viewer roles, reviewer-only access, denied writes and denied direct adapter access. The two viewers’ own devices remain to be checked.

Repository startup used current `AGENTS.md`, the task bootstrap, the architecture and worker guides, and live checks of issues #85 and #64 and draft PR #86. Targeted code inspection checked the Tailscale origin policy and source refresh path.
