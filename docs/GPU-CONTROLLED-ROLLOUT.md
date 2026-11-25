# Controlled GPU worker rollout

Keep original retrieval as the everyday default. The implementation is ready for review and a single notes-only Discord canary after human authorization. The next signal is whether the live workflow produces a useful brief with a matching private capture and a documented development outcome.

## What Josh’s trials showed

Josh’s report includes three paired Codex CLI trials, a scorecard and rendered game checks on `9097d610`. Both retrieval modes passed two of the three tasks on the first attempt. The timings cover agent handoff and include cache, order and host contention effects. Correction rounds and reviewer time were outside the timing. The published report supplies the review evidence. The raw traces and patches remained with the reviewer. [PR #82 and the merged benchmark](codex-gameplay-benchmark/README.md)

| Case | Original → deterministic handoff | Original → deterministic uncached input | First attempts |
| --- | ---: | ---: | --- |
| HUD pause and FPS | 469.3 s → 308.1 s | 79,823 → 124,100 | Both missed one of three criteria |
| Solo recovery notice | 455.9 s → 331.2 s | 86,459 → 81,297 | Both passed |
| Guest car input status | 325.7 s → 394.8 s | 70,638 → 101,169 | Both passed |

- **HUD.** The original patch checked the resumed hint and missed its visibility while paused. The deterministic patch left waypoint refresh on normal gameplay processing and asserted a fixed distance during its paused solo check. The common fixture changed position while solo physics was paused and surfaced that gap. The pause controller stops the scene tree in solo play, so validating only multiplayer or the resumed state misses a different execution path. A single bundled criterion covered bounds, hints and a live value. Separate all three and specify the state at observation time. [Pause controller](../godot-cove/river_pause.gd) · [HUD update](https://github.com/PeterFacina/richs-houseboat/blob/9097d610/godot-cove/fishing.gd)
- **Solo recovery.** Both patches used compatible save behavior. Existing `river_ledger.gd` distinguishes recovery through `recovered_primary` and protects the previous backup on the next successful write. Use that path and the existing recovery verifier as anchors. Verify a healthy primary and fresh slot as negative controls when those cases are in scope. [Ledger and recovery test](https://github.com/PeterFacina/richs-houseboat/blob/9097d610/godot-cove/river_ledger.gd)
- **Guest car.** Both passed the common three-instance test. The deterministic run explored more and used more uncached input. The host already owns command acceptance and the expiry brake in `drive_order` and `step`. A targeted check can exercise the affected driver, a separate observer, fresh input and seat re-entry without navigating unrelated progression code. [Vehicle input](../godot-cove/marina_cars.gd)

The candidate keeps PR #77’s deterministic ranking and the verified lesson render from [PR #79](https://github.com/PeterFacina/richs-houseboat/pull/79). It applies `verification-v1` only when deterministic retrieval succeeds. It asks for separate observable checks, named states and transitions, controlled before/after inputs, relevant multiplayer roles and a focused existing test. Documentation and diagnostic reports should record actual results, including stale behavior, while keeping the requested scope. An early preview assumed a top-right waypoint position. The exact proposed report’s preview preserved the paused before/after check and left waypoint placement open. It still suggested the hint should be visible. Review the live brief against the report before anyone claims it.

## Integration and training review

The draft is directly based on current main at `ba9f0319bcabddc7a2862be9ce7414e07ad7fffc`. It brings in the deployed path from PR #79 without its experimental branches. Original retrieval and default Studio generation continue to use main’s existing ranker and prompt. Neither the additional Qwen planner nor Graphify or GPU embeddings are part of this path. GitHub main refresh, exact file checking, stale-index fallback, guarded export, duplicate comment protection, training capture and the Discord claim flow use their existing boundaries.

The #69 private review used the actual linked capture read-only. The capture’s original report and model request matched the issue, and the recorded brief matched its GitHub publication. Its captured evidence accepted the corrected target through Studio’s export guard. The original brief did not spell out F3, measured Control bounds, the empty objective row or continued waypoint updates. The proposed target adds those checks in the context of #70’s follow-up changes. The runtime acceptance and approving human decision are still open. The proposal stores no capture ID, raw request, evidence or private feedback. [Issue #69](https://github.com/PeterFacina/richs-houseboat/issues/69) · [Merged PR #70](https://github.com/PeterFacina/richs-houseboat/pull/70) · [Pending training target](production-candidate/hud-training-candidate.json)

Current main kept the relevant layout, waypoint and empty-row behavior. Changes to `update_hud` add other gameplay paths, including tennis, which intentionally hides the waypoint in that mode. I inspected the changed function and refreshed its exact lesson fingerprint at current main. The anchors for `build_hud` and the clock setup matched unchanged. A later source mismatch suppresses the lesson until it is reviewed again. A prior merge, historical reuse and an outcome entry never grant training approval.

## Run one approved Discord canary

This is the live check described in [issue #64](https://github.com/PeterFacina/richs-houseboat/issues/64). Use a fresh, agreed notes-only report. The queue marker can remain on already-briefed issues, so do not pick an issue by marker alone. Use this report if the team agrees to the HUD guide task.

> Update the HUD and UI guide with a short notes-only procedure for checking F3, FPS, the date and time, and waypoint distance. Document actual behavior in a narrow and wide window in solo play. Record whether the live interaction hint is visible while the pause menu stays open and again after resume. Change the player or vessel position in a disposable fixture while paused and compare the waypoint distance before and after. Record the observed waypoint placement and whether the value refreshes or stays stale. Leave game code and controls intact. Use actual Control bounds where possible and list any checks you could not run.

1. **Preview with the worker still running.** On the reviewed checkout, run `gpu-knowledge-smoke.mjs` in original and candidate modes. Use `--report` with the agreed local text and `--out` with fresh local output paths if the operator wants to inspect the draft. The preview uses temporary storage, a reserved local issue number and read-only GitHub calls. Record the worker Git commit and the game revision. Check the exact wording and constraints in the draft before authorizing a live post.
2. **After authorization, back up and drain.** Record the known-good worker checkout and current mode. Take an online SQLite backup of the private inbox or a copy after a clean shutdown. An active WAL database needs SQLite’s backup API to include committed WAL records. Keep the backup on approved private storage. Let any current generation finish, stop the GPU worker, and leave the Discord bot online. This makes sure the old worker cannot claim the canary before its issue number is configured.
3. **Queue precisely one report.** Submit the agreed message through Discord **Apps → Create pilot issue**. Confirm its GitHub issue is open, has the normal pending marker and has no guarded brief. Keep that issue number. In the reviewed worker checkout’s local environment, set `HOUSEBOAT_RETRIEVAL_MODE=deterministic-v1` and `HOUSEBOAT_RETRIEVAL_CANARY_ISSUES=<that issue number>`. The setting accepts exactly one positive issue number. A missing or multiple selection fails startup. Other issues keep original retrieval and original drafting. Start one worker with its existing Windows account, private inbox and knowledge-cache settings.
4. **Validate the live handoff.** Verify one guarded GitHub comment, Discord **Ready to claim**, requested and effective `deterministic-v1`, brief version `verification-v1`, and a fresh source revision matching GitHub main at generation. Check the relevant history block and the separate paused and resumed observations. On the worker, review the linked capture locally and verify the report, exact model request, evidence, model digest, release/retrieval identifiers and publication link. Record only sanitized results and the issue/comment links in #64. If the brief is already present, falls back, uses stale source or fails a check, record the actual outcome and leave the normal duplicate-post protection in place.
5. **Return to original after the canary.** Drain and stop the worker, set `HOUSEBOAT_RETRIEVAL_MODE=original`, clear `HOUSEBOAT_RETRIEVAL_CANARY_ISSUES` from both the local environment file and inherited shell environment, and restart one worker. If the reviewed code must also be rolled back, restart the known-good checkout and original environment. Verify normal queue handling and an existing publication link using the same private inbox. Keep the backup and original knowledge cache in private storage. Widening scope requires another decision.

```powershell
# Run the preview from the repository root with the normal read credential.
$env:HOUSEBOAT_RETRIEVAL_MODE = 'deterministic-v1'
node tools/discord-issue-pilot/gpu-knowledge-smoke.mjs --report '<local notes file>' --out '<new local output file>'
# At the approved rollout, launch from tools/discord-issue-pilot with its existing local environment file.
node --env-file=.worker.env gpu-worker.mjs
```

## Record completed-task outcomes

After a task is complete and its linked PR is verified by the reviewer, create a local JSON file and use `node training-review.mjs record ISSUE outcome.json` on the GPU PC. The record joins a published capture, the completed PR, a named reviewer and the observed results. It takes retrieval and brief version from the capture. This appends to the existing reviews table without touching the original capture or approving a training target. Use `node training-review.mjs outcomes` for the latest outcome per issue, with private text and capture identifiers omitted.

```json
{
  "status": "outcome",
  "captureId": "<linked capture from the private inbox>",
  "prUrl": "https://github.com/PeterFacina/richs-houseboat/pull/123",
  "reviewer": "<reviewer>",
  "summary": "<checks, implementation result and corrections>",
  "firstAttempt": "unverified",
  "verification": "partial"
}
```

Record first attempt as `passed`, `failed` or `unverified`. Use `passed` only when the submitted patch passes its acceptance checks without a correction. Verification also supports `partial`. Optional measurements are `developmentSeconds`, `reviewSeconds`, `correctionSeconds`, `inputTokens`, `cachedInputTokens`, `outputTokens`, `reasoningTokens`, `incorrectAssumptions`, `unnecessarySourceSteps` and `humanCorrections`. Omit measurements that were unavailable. Keep agent logs and review JSON private.

## Verification and remaining limits

- All 23 Node and seven Python tests passed. Tests cover single-issue routing, single mock notes-only publication with retry protection, original prompts and fallback, trusted lesson URLs, stale checks, issue refresh, capture and review.
- The current-main source and guide selections matched #79 on three focused retrieval-only checks. The read-only local Qwen preview fetched fresh GitHub main, completed both modes and passed export. The verified lesson rendered in candidate mode. These tests used temporary capture storage. They did not post a live comment.
- An isolated SQLite rehearsal used the previous worker to create history, made an online backup, opened it with the candidate, recorded an outcome, and reopened it with the previous worker. Original capture, link and review history survived, and duplicate capture stayed idempotent. The live worker process stayed running and the private HUD review used a read-only connection. Godot 4.7.2 ledger recovery and vehicle exit baseline scripts passed on a separate current-main checkout with disposable game data.
- The canary’s live Discord write, production restart and rollback, and any gameplay implementation from the preview still need human-authorized verification. The six benchmark results do not establish a general development improvement. Repeat outcomes with comparable settings and distinguish first-attempt, reviewer and correction time before expanding scope.

Startup receipt. Read the branch and current-main AGENTS instructions, ran the team bootstrap, checked current main and live GitHub overlap, used exact HUD symbol lookup and compared the reviewed function bodies. #82 is merged and covers benchmark evidence. #79 and its parent retrieval drafts supplied the candidate. #64 remains the live acceptance check.
