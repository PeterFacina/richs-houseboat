# GPU guard retry incident, 26 November 2026

Investigation: #133. Parent integration record: #94.

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
