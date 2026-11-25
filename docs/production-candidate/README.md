# GPU worker production candidate

**Recommendation**. Ready for read-only preview. After review, enable one agreed Discord issue as a canary and inspect the generated brief and private capture before widening it. Keep the original setting as the everyday default until the paired development trials show a measurable benefit without raising the correction burden.

## What the worker uses

- `original` is the default. It uses the same source-ranking route as the current worker. On the three benchmark reports, its evidence matched the pinned production implementation exactly.
- `deterministic-v1` uses PR #77’s function and dependency ranker with no planner. It includes exact Godot source passages, subsystem guides and the existing bounded live GitHub task context. Embeddings and Graphify are disabled. One cached in-memory symbol index per verified commit is reused. Each request verifies the checkout against the SQLite source revision and rechecks the selected file contents.
- Automatic refresh still follows GitHub `main` into the dedicated source cache, atomically updating the SQLite search state. If a refresh fails, the verified persisted revision remains usable with a stale notice. When the cache checkout cannot verify the candidate’s source, the worker automatically uses the original ranker on the pinned persisted index.
- Verified history is selected from reviewed repository material and checked against exact current function hashes. A matching lesson is included directly in a **Verified lesson from a completed task** section. It spells out the earlier failure, merged solution, review feedback and verification. It includes link pairs constructed by Studio from that lesson’s numeric issue and PR IDs. The normal export guard still scans the complete brief. Its link exception applies only to the exact server-rendered source line in the exact verified lesson block.
- Queue behavior, original report capture, model request and source excerpts remain in the existing private training inbox. A brief containing a verified lesson also captures the exact evidence used by the export guard. The same human review command records corrections and approves a corrected response. The deployment requires no training schema migration.

### HUD feedback and training

The curated lesson comes from the [original HUD report](https://github.com/PeterFacina/richs-houseboat/issues/69) and the [merged correction](https://github.com/PeterFacina/richs-houseboat/pull/70). Review noted that right alignment alone left overflow unverified. The follow-up contained the diagnostics, restored the waypoint position calculation, kept the clock above FPS and hid the empty objective. The merge confirms those source changes. Rendered bounds, graphics presets, F3 behavior and screenshots are still verification items.

[The pending training candidate](hud-training-candidate.json) contains reconstructed requirements and a corrected Structured Studio response based on the team-visible issue and PR. It has no private capture ID or reviewer. For approval, a maintainer on the worker machine must read the actual published capture, compare the original context and target, verify the corrected task and then record an explicitly approved private review using `training-review.mjs`. If the original published capture or required verification is missing, leave the proposal pending. Do not copy private review records or training examples into Git.

## Paired development benchmark

Three new reports and acceptance criteria were frozen in `4c77e59` before generation. Every pair used the same requirements and pinned game revision `9097d61064bd0db0330832d1f355cb595bb0f5f7`, the same Qwen3 14B digest, paired seeds and one call through the real worker/Studio path. Prompts were generated through temporary isolated storage with an empty live-task feed so overlap did not vary between arms. A separate live GitHub smoke exercised automatic knowledge retrieval.

| Task | Original input / output | Candidate input / output | Original wall | Candidate wall |
| --- | ---: | ---: | ---: | ---: |
| HUD pause and FPS | 1,929 / 715 | 2,712 / 782 | 19.13 s | 16.61 s |
| Solo recovery notice | 2,232 / 648 | 2,705 / 735 | 13.11 s | 15.82 s |
| Guest car input status | 2,317 / 666 | 2,696 / 522 | 13.09 s | 11.89 s |

All six prompts passed export. The HUD lesson appeared once, in the candidate HUD prompt. Times cover local retrieval and brief generation, with model warm-up and load variability. These figures describe Qwen brief creation.

All six development attempts used the same Codex CLI model and medium reasoning setting in separate clean game worktrees. Windows process policy rejected their child shell calls, including a read of `AGENTS.md`. They executed zero checkout commands and produced no patches or test runs. Kilo was unavailable on this host. Coding-agent development tokens and time, incorrect assumptions, avoidable exploration, patch quality, corrections and first-attempt success consequently have no comparable results. Baseline Godot recovery and vehicle exit checks passed after import and do not stand in for implementing these tasks.

Use the [six Kilo packets, review rubric and scorecard](benchmark/README.md) to complete those trials. With a separate clean checkout and the local Qwen model available, regenerate the prompts as follows. The benchmark CLI only uses temporary capture storage and never polls the queue.

```powershell
New-Item -ItemType Directory -Force build/production-preview | Out-Null
node tools/discord-issue-pilot/production-benchmark.mjs --source '<clean pinned game checkout>' --out build/production-preview/replay
```

## Preview, canary and rollback

1. **Preview first.** Run the read-only smoke below from the reviewed code checkout. It fetches GitHub source into temporary storage, runs one candidate generation and exercises the guard. It may use a read credential for GitHub. Keep the live worker running during preview. Record the worker-code revision with `git rev-parse HEAD`, the log's effective mode, and the indexed game revision.
2. **After approval, start one canary.** Pick a single agreed, pending issue and record its number. Drain and stop the existing worker before starting the reviewed worker checkout against the same private inbox and source cache. Use the current worker's Windows account and environment file, setting `HOUSEBOAT_RETRIEVAL_MODE=deterministic-v1` and `HOUSEBOAT_RETRIEVAL_CANARY_ISSUES=<issue number>`. All other queued issues use the original path. Invalid values fail at startup. Confirm startup prints the expected mode and allowlist.
3. **Inspect the canary.** Check the logged requested and effective retrieval versions, elapsed retrieval time, indexed commit and stale status. Confirm the issue receives one guarded brief and its private capture records that effective mode, exact source revision, model digest and publication link. Review source and requirements, especially any history block. Log subsequent feedback through the existing review tool. Keep the allowlist until a human approves widening it.
4. **Rollback.** Drain and stop the worker, set `HOUSEBOAT_RETRIEVAL_MODE=original` and remove `HOUSEBOAT_RETRIEVAL_CANARY_ISSUES`, then restart it. The existing private inbox and knowledge cache stay in place. If the code itself must be rolled back, restart the previous known-good worker checkout with its original environment. Confirm the worker prints the original mode, or its previous startup banner, and resumes the queue. Published briefs remain linked to the stored captures. Shell variables can override values in the environment file. Check the startup banner before processing a report.

```powershell
$env:HOUSEBOAT_RETRIEVAL_MODE = 'deterministic-v1'
node tools/discord-issue-pilot/gpu-knowledge-smoke.mjs
```

## Verification

30 Node and seven Python tests passed. Coverage includes live-ref refresh against a fixture Git remote, working-tree mismatch fallback, stale recovery, duplicate posting, training capture and feedback, canary routing and exact verified-lesson export boundaries. The live read-only smoke fetched current GitHub main into temporary storage and exported a candidate brief with 11 source passages and three live GitHub tasks. The source was fresh and no retrieval fallback occurred.

Startup receipt. Read the current task and main AGENTS instructions, fetched main, ran `start_task.py`, reviewed architecture and AI workflow guidance, used exact HUD symbol lookup and checked the main-pinned hashes. Live overlap review covered issue #64, the #69/#70 HUD task, and drafts #28, #62, #71, #72, #77 and #78. This follow-up is stacked on PR #78. No gameplay edits are part of the PR. The current worker remained active throughout, and no deployment, private training-store access, training approval or merge occurred.
