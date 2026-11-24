# Multi-stage GPU retrieval experiment

Keep this experiment opt-in. The multi-stage path retrieved **21 of 40 required functions (52.5%)**. The best comparison ranker reached **14 of 40 (35%)**. The experiment missed the **80%** target. Disabling the follow-up planner raised retrieval to **23 of 40 (57.5%)** in a retrieval-only ablation. The new index and ranking stack warrants further testing. The measured planner behavior does not support a production rollout.

## Implementation

- Reuses the team’s commit-aware Godot manifest for symbols and literal `res://` dependencies. Adds a searchable record per function, named declaration and scene resource or node. Ranges resolve to text from the pinned checkout, and file hashes get checked again before the final brief. Rebuilding against another clean source revision incorporates its tracked code automatically.
- Builds directional lexical call and caller links, direct resource/scene links, and guide links. It resolves unqualified local calls and calls through literal preload aliases. Unique-name cross-file matches remain hints. It strips ordinary comments and quoted strings before scanning calls. Scene/script links come from the existing literal reference index.
- Ranks identifier, path and body hits with inverse document frequency. A corpus-derived semantic expansion uses co-occurrence with symbols and paths. Search candidates come from the whole report, report clauses and nearby source links. There are no gameplay-specific routing tables. Semantic similarity here is distributional term association. It does not use a dense embedding model.
- Searches the architecture index and subsystem guides alongside source. The optional GitHub snapshot adds dated completed issue and merged PR titles as historical context. The capture routine reuses the existing read-only GitHub helper. It drops URLs and recognized token patterns in titles, stores no issue bodies, and performs no network access during retrieval. Benchmark history excludes the regression reports and PRs explicitly closing their issues. At most two matching history titles are sent.
- Starts with three source leads. Local Qwen can request exact functions, indexed files, dependency hints or a short ranked search. It sees excerpts and candidate handles, and can request one further round if the first uncovered new evidence. Requests resolve only within the pinned index. Repeated, invalid and unresolved requests make no progress and never become final citations. When the planner stops or fails, the remaining slots come from deterministic ranking.
- Uses at most two planning rounds, five requests per round, 12,000 serialized bytes per planning input, and 25 seconds per planner call. The final evidence has at most 11 source passages within a 5,800-character excerpt budget, plus the bounded labels and paths. All model calls use an 8,192-token context and the benchmark shares a 120-second per-case signal. Final generation uses the existing formatter and export guard. The source guard validates identities and paths. The factual review below checks claims separately.

### Graphify reuse

The existing `tools/godot-lookup/links.json` has 136 links. The benchmark found zero exact-byte endpoint matches in the Windows checkout. Sixteen endpoint files matched the snapshot after CRLF-to-LF normalization. Matching both endpoints retained 13 links and skipped 123. All 13 surviving links duplicated relationships already derived from literal resources. Disabling Graphify gave identical selections on the ten cases in the offline ablation. The synthetic integration test exercises an additional verified edge and rejects a stale one. The adapter supports a future fresh snapshot without needing Graphify running in the experiment. Regenerating a Graphify snapshot was outside this run.

## Benchmark design

- Source and documents came from the same clean `688da719026b5096740f6f610490b7fa70b07422` tree used in #72. The production ranker at that revision and the deployed worker baseline `32330f7` had identical index and Python selector files. The checked comparison ranker was PR #71 head `916c2a822f01235791433a419404e0aee3355974`. The catalog arm used PR #72 at `247b556e3fa41ef1c421717ad7681cf1995c4f7d`. Current team main was `9097d61064bd0db0330832d1f355cb595bb0f5f7` when checked. It has newer gameplay; keeping the previous source made the regression comparison reproducible.
- Reused the [five #72 reports and anchors](../tools/discord-issue-pilot/heldout-cases.json). Froze [five new reports, expected functions and scoring requirements](../tools/discord-issue-pilot/multistage-cases.json) in `795e08419117fe5753b0005f8c059e06f2656435` before running any benchmark. The new reports cover television sync, refueling, solo reset, warehouse placement and helicopter exit. The candidate uses the report only. It receives no expected functions or benchmark IDs.
- One draft per case and arm, 40 completed drafts. All arms used the same Ollama `qwen3:14b` digest `bdbd181c33f2ed1b31c972991882db3cf4d192569092138a7d29e973cd9debe8`, Detailed generation, 8,192 context, temperature 0.25, and the same seed per case. The planner used temperature 0.1 and a 420-output-token cap per call. Baseline ordering rotated per report. The multi-stage arm ran in a separate sequential batch on the same service. All three older arms used the empty live-task list and pinned SQLite source configuration from #72. The multi-stage arm used the [frozen completed-title snapshot](../tools/discord-issue-pilot/multistage-history.json) as one of the experimental changes. That snapshot has 10 completed issues and 36 merged PRs through the source commit timestamp.
- **Function coverage** requires overlap with body lines in a frozen required function. **Source relevance** divides passages overlapping a required or supporting function by returned source passages. This excludes guides and history. A later source range can be relevant in practice without appearing in the frozen list. Every source and guide excerpt passed a range check against the pinned text. All arms use 5,800 characters for excerpts. The candidate returns more, shorter passages while the older arms normally return five source passages.
- **Requirement coverage** is the number of frozen requirements carried concretely and consistently in model-authored draft text. The automatic quote of the player report earns no credit. **Unsupported claims** are distinct factual premises unsupported by the supplied report and exact evidence. Genuine questions and proposed changes are excluded. One author audited the 40 rendered drafts with the [recorded decisions](../tools/discord-issue-pilot/multistage-adjudication.json). A second reviewer and repeated generations were outside this run.
- **Total wall time** starts before per-case retrieval, includes Python selection where used and all planner and drafting calls, and ends after the export check. Shared manifest/SQLite construction is outside that measurement. Token counts include planner requests for the multi-stage arm. The same process did one draft at a time and reused the production Ollama service. Model warm-up and unrelated service load can affect latency.

## Results

| Arm | Required functions | Relevant sources | Requirements | Unsupported claims | Export passes | Median input / output tokens | Median total time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Production | 6/40 | 9/50 | 36/46 | 5 | 10/10 | 2,329 / 599 | 11.28 s |
| PR #71 | 6/40 | 9/50 | 36/46 | 7 | 9/10 | 2,329 / 619 | 10.90 s |
| PR #72 catalog | 14/40 | 17/50 | 41/46 | 2 | 10/10 | 1,649 / 619 | 11.11 s |
| Multi-stage | 21/40 | 30/110 | 40/46 | 8 | 10/10 | 7,720 / 981 | 19.95 s |

The catalog had the highest source precision at **34%**. Multi-stage recovered more relevant passages and its precision was **27%**. Median multi-stage draft-only consumption was 2,542 input and 669 output tokens. Median retrieval including planning was 8.31 s, compared with 0.25–0.37 s in the older arms. Summed per-case wall times were 120.95 s for production, 108.22 s for #71, 116.99 s for catalog and 199.98 s for multi-stage. The single guard rejection was #71’s vehicle audio draft citing `houseboat.gd` outside its retrieved evidence.

| Set and arm | Required functions | Relevant sources | Requirements | Unsupported | Exports | Median input / output | Median total |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Regression · Production | 3/20 | 4/25 | 17/21 | 3 | 5/5 | 2,334 / 552 | 11.52 s |
| Regression · #71 | 3/20 | 4/25 | 17/21 | 5 | 4/5 | 2,334 / 600 | 10.07 s |
| Regression · Catalog | 7/20 | 9/25 | 21/21 | 1 | 5/5 | 1,761 / 637 | 11.20 s |
| Regression · Multi-stage | 12/20 | 17/55 | 19/21 | 6 | 5/5 | 7,784 / 956 | 19.48 s |
| Independent · Production | 3/20 | 5/25 | 19/25 | 2 | 5/5 | 2,324 / 629 | 11.04 s |
| Independent · #71 | 3/20 | 5/25 | 19/25 | 2 | 5/5 | 2,324 / 638 | 11.46 s |
| Independent · Catalog | 7/20 | 8/25 | 20/25 | 1 | 5/5 | 1,530 / 584 | 10.55 s |
| Independent · Multi-stage | 9/20 | 13/55 | 21/25 | 2 | 5/5 | 7,656 / 1,005 | 23.32 s |

| Report | Production | #71 | Catalog | Multi-stage | Multi-stage, planner disabled |
| --- | ---: | ---: | ---: | ---: | ---: |
| Fishing motion | 2/4 | 2/4 | 4/4 | 3/4 | 4/4 |
| Vehicle audio | 0/4 | 0/4 | 0/4 | 1/4 | 1/4 |
| First-person props | 0/4 | 0/4 | 2/4 | 4/4 | 4/4 |
| Progression reconnect | 0/4 | 0/4 | 1/4 | 1/4 | 1/4 |
| Town driveways | 1/4 | 1/4 | 0/4 | 3/4 | 3/4 |
| Cabin TV sync | 1/4 | 1/4 | 1/4 | 1/4 | 1/4 |
| Fuel nozzle sale | 0/4 | 0/4 | 1/4 | 1/4 | 1/4 |
| Solo slot reset | 1/4 | 1/4 | 2/4 | 3/4 | 4/4 |
| Warehouse rack placement | 0/4 | 0/4 | 1/4 | 2/4 | 2/4 |
| Helicopter door exit | 1/4 | 1/4 | 2/4 | 2/4 | 2/4 |

The planner made 17 calls across ten reports. In three reports its requests resolved to no additional evidence. The deterministic ablation reached 23/40 and 36/110 relevant source passages, with no model generation or claim score. The planner displaced the fishing rig’s `pose_rod` and title screen’s `finish_loading` passages. In the vehicle-audio case it retrieved mower and helicopter audio even though the report asked for boats and road cars. The TV case retrieved several declarations but missed the state and welcome handlers. The measured claim counts include wrong function ownership and assumptions such as per-guest mowing rewards. Export success did not catch those factual errors.

## Reproduce

Use clean checkouts with the pinned revisions above and the existing local Qwen3 14B model. `--main` expects the game text, docs and `tools` from `688da71`. `--pr71` needs the #71 Studio modules and their dependencies. `HOUSEBOAT_KNOWLEDGE_PYTHON` can point to a working Python executable. Use an ignored local results directory. The detailed logs contain source and model text for review and should stay local.

```powershell
New-Item -ItemType Directory -Force build/multistage | Out-Null
$bench = 'tools/discord-issue-pilot/multistage-benchmark.mjs'
$source = '<path to clean 688da71 checkout>'
$pr71 = '<path to clean 916c2a8 checkout>'
node $bench --main $source --pr71 $pr71 --variants production,pr71,catalog --generate --details > build/multistage/comparison.jsonl
node $bench --main $source --pr71 $pr71 --variants multistage --generate --details > build/multistage/candidate.jsonl
node tools/discord-issue-pilot/multistage/summarize.mjs tools/discord-issue-pilot/multistage-adjudication.json build/multistage/comparison.jsonl build/multistage/candidate.jsonl
node $bench --main $source --pr71 $pr71 --variants multistage > build/multistage/without-planner.jsonl
node $bench --main $source --pr71 $pr71 --variants multistage --no-graphify > build/multistage/without-graphify.jsonl
```

Use `--cases regression` or `--cases independent` for a subset. `--port` selects an alternate local Ollama listener if one is available. The checked-in adjudication belongs to this run. For a fresh generation, review the new model-authored fields against the frozen requirements and evidence, then supply the new adjudication to the summarizer. The shipped notes and metrics exclude the raw benchmark requests and drafts.

For an arbitrary report and another clean checkout, run `node tools/discord-issue-pilot/multistage/experiment.mjs --source <checkout> --report <UTF-8-file>`. Add `--generate` for a guarded Qwen brief, `--details` for exact source excerpts, or `--history <snapshot.json>` for historical titles. To capture a fresh bounded title snapshot, call `python tools/discord-issue-pilot/multistage/history.py --through <UTC-commit-timestamp>` with approved read access through the existing GitHub helper. The command prints JSON. Use the checked-in snapshot to repeat the published evaluation.

## Review and next iteration

1. Reserve the strongest deterministic function passages and make the planner add to them. Reject a proposed passage when its only connection is a broad shared concept such as an engine or door. Measure deterministic versus model-augmented retrieval on a newly frozen set at equal passage counts as well as equal excerpt budgets.
2. Improve typed receiver resolution and RPC/state producer–consumer wiring. The principal misses were cross-file paths such as outboard and car presentation, profile registration and snapshots, and welcome/state handlers. Use stronger verified call and resource edges, then test whether more focused graph walks improve coverage and precision.
3. Test a fresh Graphify snapshot and a dedicated offline embedding approach as separate ablations. The surviving Graphify links provided zero incremental edges in this evaluation. The current term-association method supplies a dependency-free baseline. Limit hard-to-verify graph relations to nominations until confirmed in code.
4. Give a later draft stage an explicit requirement checklist and score it independently of retrieval. Require a second reviewer and more held-out cases before changing defaults. Keep fine-tuning deferred until evidence retrieval and scoring are reliable.

The worktree bootstrapped with current `AGENTS.md`, the architecture, AI workflow, living knowledge and GPU worker guides. Live overlap and changed paths were checked for #28, #62, #71 and #72, and the new fuel and aircraft targets were inspected with `retrieve.py`. The sandbox could not launch the Windows Python alias for the first exact lookup. The approved local rerun succeeded. Tested with Codex, Node 24.15.0 and Python 3.12.10. **23 Node tests and seven Python tests passed.** A separate-report offline run verified the standalone entry point. Gameplay runtime, repeated GPU trials, independent adjudication and a fresh Graphify rebuild remain unverified.

The production worker kept the same PID and start time before and after. Its code, queue, configuration and private training data were left in place. The experiment used temporary SQLite indexes and explicit local report inputs. It performed no gameplay edits, worker deployment, model training or merge.
