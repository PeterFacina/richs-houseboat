# GPU guard retry incident, 26 November 2026

Investigation: #133. Parent integration record: #94.

> Current status: the independent-review follow-up below supersedes the initial task-only containment claim. The old child worker is now terminated; production is disabled with zero worker processes. The final deterministic live canary passed. All preliminary runs and their token costs are documented.

## Production findings

The deployed worker is pinned to `5531c70e169161ee26877f8671ae2f6f6739e9b6`; indexed game knowledge reached `f7cc23364e2a8088200460132e63e335c2edb582`. Production logs and persisted captures confirm unbounded retries after export guard rejection. The poller catches every generation failure and retries after 120 seconds; rejection writes a private capture, throws an ordinary error, and leaves the GitHub pending marker intact. Capture identity includes generated metrics/output, so deduplication does not suppress new attempts.

The frozen snapshot has **502 captures, 26 published captures/briefs, 476 blocked captures**. Deterministic v1 accounts for 495 generations, of which 476 were blocked (96.16%). Six captures have unrecorded mode and one used original retrieval. The earlier 489/482 figures and initial 501 estimate were superseded by this frozen database count.

Recorded local model input plus output totals **2,300,505 tokens**, not a dollar/API billing estimate. #123 consumed 1,112,842 and #124 consumed 1,079,102, totaling 2,191,944 tokens.

### Grouped capture audit

| Issue | Attempts | Published | Blocked | Original rejection findings |
| --- | ---: | ---: | ---: | --- |
| #123 | 241 | 0 | 241 | Unverified project or asset path: outboard.gd (241); Potential project data disclosure (1) |
| #124 | 234 | 0 | 234 | Unverified project or asset path: outboard.gd (234) |
| #132 | 2 | 1 | 1 | Unverified project or asset path: river_sky.gdshader (1) |
| #66 | 1 | 1 | 0 | None |
| #69 | 1 | 1 | 0 | None |
| #73 | 1 | 1 | 0 | None |
| #74 | 1 | 1 | 0 | None |
| #80 | 1 | 1 | 0 | None |
| #84 | 1 | 1 | 0 | None |
| #87 | 1 | 1 | 0 | None |
| #89 | 1 | 1 | 0 | None |
| #91 | 1 | 1 | 0 | None |
| #95 | 1 | 1 | 0 | None |
| #98 | 1 | 1 | 0 | None |
| #100 | 1 | 1 | 0 | None |
| #103 | 1 | 1 | 0 | None |
| #105 | 1 | 1 | 0 | None |
| #108 | 1 | 1 | 0 | None |
| #110 | 1 | 1 | 0 | None |
| #111 | 1 | 1 | 0 | None |
| #114 | 1 | 1 | 0 | None |
| #115 | 1 | 1 | 0 | None |
| #117 | 1 | 1 | 0 | None |
| #119 | 1 | 1 | 0 | None |
| #120 | 1 | 1 | 0 | None |
| #125 | 1 | 1 | 0 | None |
| #126 | 1 | 1 | 0 | None |
| #129 | 1 | 1 | 0 | None |

Findings count overlaps: one #123 attempt has both the path finding and the disclosure finding.

#123 ran 241 times from 08:45:25Z to 19:25:37Z; #124 ran 234 times from 09:15:37Z to 19:26:55Z. Both contain the same gameplay/weather report but remain separate original issues. GitHub currently records them closed at 19:27:59Z and 19:28:01Z respectively (15:27 AST), before this intervention. We did not close, reopen or rewrite either issue. They published no GPU brief. #132 had one legitimate unverified shader-path rejection and a subsequent published brief.

## Root causes and fix

1. **Permanent rejection treated as transient:** the patched generation boundary reads the existing inbox before model work. An unchanged report with a rejected capture requires human correction and an explicitly revised report. This survives process restarts and main refreshes, using the original capture database without a new table or competing store. The poller remembers the held report and does not generate or repeatedly log it. New rejected captures include exact guard findings for review. Existing published briefs are still checked before generation.
2. **Historical path presented as current evidence:** all 475 #123/#124 failures include `outboard.gd` from the source-verified #103 lesson, while camera/weather retrieval did not select that file as current-task evidence. Lesson anchors had been verified, but rendering exported a bare historical filename. The renderer and model-facing lesson excerpt now refer to the historical source in prose and retain the exact original issue/PR links. Original lesson/review records are unchanged. The guard still rejects any unsupported path in generated implementation text.
3. **Cross-sentence disclosure false positive:** one brief's harmless instruction to transmit idle-animation data was paired with the separate standard handoff asking to report changed files. The disclosure detector now matches within a sentence/clause, while direct and newline-split source/credential disclosure requests remain rejected. Other guard rules remain enabled.

The #132 `river_sky.gdshader` failure was a genuine unsupported current-evidence citation, not a reason to exempt shaders. The guard still rejects it. No rejected example was approved or retroactively published.

## Containment and data preservation

The existing **Houseboat GPU Production Worker** scheduled task was exported, disabled, and stopped. Its restart trigger cannot relaunch the old looping worker. Generation and automatic GitHub outcome collection are paused until a reviewed rollout; dashboard access and readiness-only scheduling remain available. All pending issue bodies/markers and published briefs were preserved. The deployment launcher and existing release remain unchanged.

Consistent SQLite backups of the worker knowledge store and training inbox, the task XML, the private aggregate audit and regression log are stored on the host in `HouseboatGpuKnowledgeRuntime/retry-incident-20261126`. Private prompts, credentials and database contents are not attached here. A full ordered-row comparison against the backup verified unchanged **502 captures, 48 review/audit entries and 18 collected GitHub outcomes**. All approvals and retrieval lessons contained in that history remain intact.

The readiness task remains enabled, Ready, last result 0, with its existing status-only `fine_tune.py tick` command and no authorization flag. No model training, approval, model-weight change, queue deletion, database migration or guard bypass was performed.

## Verification and rollout

- 45 automated worker, Studio and dashboard tests passed, using isolated fixtures and fake model responses.
- Tests cover a rejected capture held across reopening the inbox, repeated checks without new captures, changed-report release of the hold, ordinary publication deduplication, guarded capture persistence and continued viewer/reviewer safeguards.
- Offline replay of all 476 rejected briefs, changing only rendered historical lesson text and applying the corrected detector, clears 475 and still rejects the single unsupported shader citation. This consumes no new model tokens and does not edit captures.
- Do not re-enable the old release. After human PR review/merge, deploy the reviewed worker and its matching Studio/retrieval modules through the existing release mechanism; preserve configuration and data, then re-enable/start the existing worker task. Confirm unchanged rejected reports remain held, a disposable fixture generates once, and pending legitimate jobs proceed with the guard enabled. #123/#124 are closed; no live gameplay report needs reopening to test this.
- Production stays contained pending that reviewed rollout. No claim of a live fixed deployment or new model-generated brief is made.

Startup receipt: current task AGENTS read; bootstrap executed with a working host Python, then the GIMP Python executable used explicitly after the Store alias failed. Latest main fetched and isolated branch based on `f7cc233`. Architecture, AI workflow, team workflow, queue/generation, retrieval and lesson rendering inspected. Exact-function retrieval returned no JavaScript definition, so targeted `rg` and source reads were used. Live open PRs #113 and #116 concern gameplay, with no overlapping worker fix. Implementation by Codex (GPT-6.1 Sol). Gameplay and visual checks are outside this infrastructure change.

## Independent-review follow-up: bounded failures, status and controlled retry

### Correction to initial containment claim

Stopping the scheduled task launcher did **not** stop its child Node process on this Windows host. PID 21680 from release `5531c70` remained alive, despite the task reporting Disabled. #123/#124 were already closed, so their retry loop did not resume, but the old child collected outcomes and picked up synthetic canary #136. Its one generation used 3,367 input plus 341 output tokens (3,708 total) and published once. This is **not** a successful test of the patched worker.

The exact process identity was checked, PID 21680 was terminated, and a command-line process scan verified **zero actual `gpu-worker.mjs` processes**, in addition to the disabled task. The controlled runner now checks both conditions, and its process detector was checked against a known worker command-line fixture. Preserve #136's resulting capture; do not roll back or delete it to conceal the unexpected run. Production now has 503 captures and 27 published captures, with the original 502 capture rows and all 48 review/audit rows preserved. The pre-test and post-test ordered-row comparisons are identical for captures, reviews and all 18 outcomes after actual child containment.

### Persistent generation budget

The existing training inbox gains two additive operational tables, `generation_jobs` and append-only `generation_job_events`. Captures, reviews, outcomes, approval validation and training eligibility are unchanged. Read-only dashboard requests never create tables.

A job is keyed by issue plus the SHA-256 of the original report, so reverting an edit cannot reset a spent budget. Before model work, the worker transactionally reserves one of **three automatic attempts**. Timeouts, malformed/incomplete JSON, output limits and unavailable dependencies consume that budget even if no capture can be saved. A crash leaves its reservation spent. Attempts wait at least 120 seconds, persisted across restarts, and stop at `failed` after exhaustion. Guard rejection stops immediately at `held`. Subsequent issues are processed independently.

If a guarded draft was captured but GitHub publication failed or its response was lost, the worker revalidates and reuses that capture rather than generating again. Existing trusted published briefs are still checked first. No historical capture or approval is deleted when holding or retrying a job.

### Authorized retry of unchanged reports

For an open held/failed job, the dashboard and GitHub status comment show `/gpu-retry JOB_ID`. A configured human GitHub operator posts that exact command on the same issue. The default is repository owner `PeterFacina`; additional operators require an explicit host `HOUSEBOAT_RETRY_REVIEWERS` login list. The GitHub account must also have OWNER, MEMBER or COLLABORATOR association, and be a human User. Tailscale reviewer access alone does not confer infrastructure retry permission, and existing dashboard writer/approval permissions are unchanged.

The command grants **exactly one** additional attempt, preserves the report and cumulative attempt count, records author, timestamp/source comment and job transition, and rotates the job ID so an old command cannot be replayed after restart or another failure. It does not approve an example, override the export guard, reopen an issue or authorize training. Closed reports must remain closed unless separately authorized for reopening. Local host code remains trusted; no public retry endpoint is introduced.

### Dashboard and Discord status

Reviewers see persisted held, failed, retry-wait and publication-pending jobs in Overview and GitHub issues, including attempt counts and fixed actionable reasons. Viewer permissions remain unchanged. The worker publishes/edits one job-status comment on GitHub. The Discord bot's existing refresh follows that sanitized status rather than showing an indefinite Waiting for GPU brief; claim buttons remain unavailable until a guarded brief exists. Notification failures do not spend a model attempt. A lost status-POST response is reconciled without another comment or generation.

Raw model output, raw errors, credentials and private report text are not included in those status projections. Status reason codes map to fixed text. The new live dashboard/bot code is in this PR; it is **not deployed**, so live Discord-card acceptance awaits the reviewed rollout. Isolated tests verify parsing, sanitation, reviewer-only projection and shared message formatting; no live Discord failure card is claimed here.

### Disclosure guard after independent review

The initial sentence-boundary change has been replaced. Disclosure checks again span punctuation and newlines, normalizing deliberately split words such as `source. code` and `source_code`. Only the exact application-owned final HANDOFF section is excluded from disclosure matching; generated gameplay prose is not exempted. This prevents the standard changed-files footer from binding to a legitimate instruction about animation-data replication. Any sensitive request elsewhere remains checked, including a sensitive request following an animation clause. Tests cover periods, semicolons, exclamation marks, multiline commands, underscores, a modified footer, direct credentials/source disclosure and the legitimate animation case. Other guard rules remain active.

### Actual controlled live runs

Each patched runner invocation has a hard cap of **one** real local `/api/chat` request, uses a separate disposable test inbox/index, and uses the existing GPU gate. It requires explicit `--authorize-one-generation`, a new private output directory, a labeled synthetic issue, paused scheduling and zero actual worker processes. It never starts training or modifies the production model selection/weights.

| Canary | Real generations | Input tokens | Output tokens | Total tokens | Publications | Result |
| --- | ---: | ---: | ---: | ---: | ---: | --- |
| #136 | 1 | 3,367 | 341 | 3,708 | 1 | Unexpected old child worker; not patched verification. Capture preserved in production. |
| #137 | 1 | 2,931 | 335 | 3,266 | 1 | Patched job flow passed, original retrieval fallback. Disposable stores. |
| #138 | 1 | 2,747 | 449 | 3,196 | 1 | Patched job flow passed, original retrieval fallback. Disposable stores. |
| #139 | 1 | 3,038 | 722 | 3,760 | 1 | Final deterministic-v1 / verification-v1, guard passed, source `f7cc233`. Disposable stores. |

Total during this follow-up: **four actual generations, 13,930 tokens, four publications**, with all preliminary runs disclosed. No additional model calls were made for repeat polling or restart verification. On #137, #138 and #139, three repeat polls and reopening the inbox returned `already posted` with one capture and one published brief. Model digest remained `bdbd181c33f2ed1b31c972991882db3cf4d192569092138a7d29e973cd9debe8`.

The first disposable fixtures copied the production index without its source checkout. The existing refresh shortcut accepted the copied matching revision and retrieval fell back; those runs are not deterministic successes. The runner was corrected to build a fresh disposable index and verify the checkout before spending its single generation. Its final check requires effective deterministic-v1. #139's published brief is https://github.com/PeterFacina/richs-houseboat/issues/139#issuecomment-7202399232 . All canaries are explicitly synthetic infrastructure requests using the historical intake URL solely as a labeled transport fixture, not new player feedback. No fixture was approved for training.

### Verification and release gate

Final verification: **53 Node worker/Studio/dashboard tests passed**, plus the existing Python training-authorization fixture test passed under the installed training runtime. Syntax checks passed for all changed JavaScript. The knowledge-only GIMP Python could not load SQLite, so its failed test invocation was replaced by the appropriate installed training runtime; no Python environment was changed. Tests cover persistent non-guard budgets, crash reservations, unchanged-report authorized retry, unauthorized/bot/unlisted users, replay prevention, progress on subsequent jobs, published brief deduplication, publication and notification response loss, split-instruction guard regression, and sanitized dashboard/Discord status data.

Production remains **paused with zero actual child workers**. The readiness-only task remains enabled with no training authorization flag. Deploy the reviewed worker/Studio, adapter/dashboard and Discord bot together using the existing architecture only after human review. Back up the live inbox first, allow the additive job-table creation, retain all existing configs/identities, and verify named reviewer visibility plus an actual Discord card before enabling unrestricted polling. Restoring only the old worker or only the task launcher is not a safe restart procedure. Do not merge automatically.
