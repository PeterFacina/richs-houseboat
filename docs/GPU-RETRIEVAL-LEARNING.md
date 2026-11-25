# GPU retrieval and historical learning

Keep PR #77’s deterministic retrieval as the benchmark reference. The new planner reached **36 of 60 required functions (60%)**, one more than PR #77 and below the **80%** target. It used about three times as many input tokens. The candidate remains an opt-in experiment. Keep the verified lesson workflow available for review. The embedding and Graphify ablations did not justify their operational cost.

## Design

The experiment builds on the strongest deterministic configuration in [PR #77](https://github.com/PeterFacina/richs-houseboat/pull/77). It is available through an explicit experimental command. The Discord worker and Studio defaults are unchanged.

- Rebuild the symbol index from a clean game checkout. Reuse existing scene-to-script and resource references, architecture guides, lexical calls, and corpus-derived term associations. Historical issue and PR titles come from the existing bounded, completed-only snapshot.
- Reserve eight deterministic source passages from the previous ranking. Combine whole-report and clause matches, vocabulary associations, and verified call neighbors to rank the exploratory slots. Apply soft diversity across files and clauses. The same rules apply to new code and unfamiliar reports.
- Trace calls through declared GDScript receiver types and preload aliases, including simple constructs and receiver chains. Resolve statically named calls through `rpc`, `rpc_id` and `call_deferred`. Shared dotted field names provide weak read/write hints. Visually inspecting the intended instance and authority still matters.
- Optionally rerank the exploratory slate with local embeddings. Run the pretrained embedding model on an isolated Ollama listener for the benchmark. The cache is scoped to the source revision and exact report texts.
- Give Qwen up to three exploratory slots. It can see the reserved passages and request an indexed function, file, dependency or short search. Each result needs lexical or graph support. The planner has two rounds with at most four processed actions per round, a 9,400-byte request cap and 25 seconds per call. An invalid response or a round with zero progress leaves the open slots to the deterministic ranker. Both modes have 11 source slots and share the 5,800-character excerpt budget. The full run has a 120-second deadline and an 8,192-token model context.
- Recheck file hashes before generation. Keep factual premises tied to excerpts, preserve specific report constraints and turn gaps in the evidence into concrete investigation questions. Use the standard Studio draft formatter and export guard.

## Historical lesson

The seed record links [issue #69](https://github.com/PeterFacina/richs-houseboat/issues/69), its guarded brief and the correction history in [merged PR #70](https://github.com/PeterFacina/richs-houseboat/pull/70). Initial right alignment left the narrow-window bounds unverified. Removing a location label also removed a position used to update waypoint distance. The merged code restores the waypoint input, puts HUD elements in a top-right container, keeps the clock above the optional FPS row and hides the empty objective. The source confirms layout wiring. Verification still requires measuring rendered Control bounds and exercising the toggles at runtime.

Each curated record supplies issue and PR provenance, the initial failure, the merged correction, verification limits and source anchors. The pin command records hashes of the exact named functions. The status command suppresses stale records when any anchor changes and lists training eligibility only after an identified reviewer approves the exact record fingerprint. Approval is a reviewable local data field. Automation never writes an approval or invokes training. The checked-in record has no training approval.

Records are curated from reviewed evidence. The workflow does not infer corrections from arbitrary PR text or attribute commits to reviewers. It distinguishes code confirmation from runtime evidence. A lexical scope check limits selection to one relevant verified lesson per report. Its prompt block describes the past task and its limits. Evaluation excludes closed reports and their associated PRs from retrieval history, with a separate transfer probe for the earlier HUD task.

## Benchmark setup

- All comparisons use the clean game tree at `9097d61064bd0db0330832d1f355cb595bb0f5f7`. The production index and Python selector at that revision matched the deployed versions. The PR #77 baseline uses the checked-out implementation at `0ed6fd9b6defd4eaf5dffcf9b7bfc785b13fcd20` with the planner disabled. Both use the same pinned game and guides as the candidate.
- Used ten prior reports as regression cases. Froze five new reports, four required functions per report, supporting functions and requirement rubrics in commit `99e1b61` before evaluation. The new reports cover campaign backup recovery, guest docking, the spill/muskie encounter, guest car input expiry and swim/board transitions. One separately reported HUD transfer case checks historical relevance. Gold functions and rubrics are unavailable to retrieval and draft generation.
- The four primary arms are production, PR #77 deterministic, candidate deterministic and candidate with the additive planner. The candidate arms include the revised drafting instructions and the lesson snapshot. Model-assisted audits therefore compare the combined prompt paths. The source-only Graphify and dense ablations isolate the changes they make to retrieval.
- The same RTX 5070 Ti and local `qwen3:14b` digest `bdbd181c33f2ed1b31c972991882db3cf4d192569092138a7d29e973cd9debe8` served every draft. Cases use paired seeds within each trial. Model loads and normal worker traffic can affect observed time. Primary runs use separate sequential batches. The report script keeps trials and the history probe separate.
- Required function coverage counts exact source passages that overlap a required body. Relevance is the share of returned source passages that overlap any frozen required or supporting function. Guide and history passages are excluded. These metrics use a fixed reference list, which can miss legitimate alternative navigation paths.
- The quality review checks concrete requirement coverage, distinct unsupported factual premises and lesson use in the model-authored text that survives formatting. It excludes the automatic quote of the report. One reviewer checked all 20 primary independent drafts and seven HUD probe drafts. The export guard measures reference and content safety independently of factual correctness.
- Token counts include planning and generation. Timings begin at retrieval and end at the export check. One-time index building, ablation caches and quality audits have separate cost and are excluded from per-draft time.

## Primary results

The table covers the 15 gameplay reports. The separate history probe brings the primary benchmark to 64 generated drafts.

| Arm | Required functions | Regression | Independent | Relevant source | Export passes | Median input / output tokens | Median time | Total time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | ---: |
| Production | 8/60 | 6/40 | 2/20 | 11/75 | 14/15 | 2,309 / 552 | 10.05 s | 165.33 s |
| PR #77 deterministic | 35/60 | 23/40 | 12/20 | 55/165 | 15/15 | 2,738 / 655 | 11.72 s | 180.68 s |
| Candidate deterministic | 33/60 | 21/40 | 12/20 | 55/165 | 15/15 | 2,762 / 642 | 11.55 s | 164.03 s |
| Additive planner | 36/60 | 23/40 | 13/20 | 57/165 | 15/15 | 8,264 / 954 | 19.29 s | 289.77 s |

The planner kept the eight reserved excerpts byte-for-byte across both candidate settings on all 16 reports. Across the 15 gameplay cases, it completed 30 calls, filled 40 exploratory slots and rejected 34 requests. The planner runs recovered one additional required function over PR #77 in the new reports and tied its coverage on regression. The deterministic candidate missed two of PR #77’s regression functions. No arm met the coverage target. One production brief failed its export check for a path absent from its evidence. All original excerpts and guide passages in the benchmark matched the pinned source.

| New report | Production | PR #77 | Candidate | Additive |
| --- | ---: | ---: | ---: | ---: |
| Campaign backup recovery | 1/4 | 3/4 | 3/4 | 3/4 |
| Guest docking | 1/4 | 2/4 | 2/4 | 2/4 |
| Spill and trophy muskie | 0/4 | 3/4 | 3/4 | 4/4 |
| Guest driving input expiry | 0/4 | 2/4 | 2/4 | 2/4 |
| Swim and board transition | 0/4 | 2/4 | 2/4 | 2/4 |
| HUD history probe | 1/4 | 2/4 | 2/4 | 2/4 |

Deterministic and additive retrieval each supplied the verified #69/#70 lesson on the HUD probe in both trials and supplied it zero times on the 15 unrelated reports. The HUD briefs referenced current code and proposed checking bounds and toggles. None of the four briefs that received the lesson carried its failed approach and merged correction into the model-authored work. The test covers one relevant and 15 unrelated reports for one curated lesson.

## Development brief review

| Arm | Primary independent drafts reviewed | Requirements retained | Unsupported claims |
| --- | ---: | ---: | ---: |
| Production | 5/5 | 17/20 | 1 |
| PR #77 deterministic | 5/5 | 19/20 | 1 |
| Candidate deterministic | 5/5 | 20/20 | 1 |
| Additive planner | 5/5 | 18/20 | 3 |

The deterministic candidate retained all 20 requirements on this set. Neither candidate established a factual accuracy improvement over PR #77. The additive draft omitted the constraint to preserve helm and fishing controls on the swim report. One additive recovery brief asked whether the backup rotation logic in `solo_saves.gd` preserves the last good state. The cited function lists paths and the ledger implements rotation. The faulty premise survived in an open question and the draft passed the export guard.

The [review decisions](../tools/discord-issue-pilot/learning-review.json) record the covered requirements and verbatim unsupported premises for the exact draft fingerprints. All seven reviewed HUD drafts addressed 4/4 requirements. The two Qwen audit attempts had false positives, including proposed tests treated as factual claims and history credit assigned without the lesson. Their grades were discarded. Regression and repeated independent drafts were scored for retrieval and export, with factual and requirement review limited to the stated subset. A separate reviewer has yet to confirm the quality scores.

## Repeat trial

A second paired seed ran on the five independent reports and HUD probe for the three retrieval experiments. The table covers the five independent reports. All three repeat drafts for the HUD probe covered 2/4 required functions and passed the guard.

| Arm | Required functions | Relevant source | Export passes | Median input / output tokens | Median time | Total time |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| PR #77 deterministic | 12/20 | 19/55 | 5/5 | 2,738 / 544 | 9.88 s | 52.41 s |
| Candidate deterministic | 12/20 | 20/55 | 5/5 | 2,750 / 599 | 9.79 s | 49.10 s |
| Additive planner | 14/20 | 21/55 | 5/5 | 8,334 / 857 | 17.14 s | 92.09 s |

The planner gained a second function on the independent report set with the alternate seed. The deterministic arms repeated their source selections. Both planner trials on that set fell below 80% coverage.

## Source-only ablations

| Deterministic arm | Regression | Independent | Relevant passages on 15 reports | HUD probe |
| --- | ---: | ---: | ---: | ---: |
| Candidate | 21/40 | 12/20 | 55/165 | 2/4 |
| Candidate with fresh Graphify | 21/40 | 12/20 | 55/165 | 2/4 |
| Candidate with GPU embeddings | 21/40 | 12/20 | 55/165 | 1/4 |

The local index held 185 files, 4,070 source declarations, nine guide sections and 438 file links. It recorded 1,449 typed call matches, 43 resolved dispatch matches and 554 shared-field hints. The checked-in older Graphify snapshot supplied 13 current file links, all redundant with the manifest. A fresh run processed 125 Godot files in 12.17 seconds, producing 1,941 nodes, 6,644 edges and 2,217 extracted call edges with zero reported parser error lines. Only four call edges added information after matching endpoint content hashes, exact function labels and declaration lines. They changed no selected passages in this set.

The generation-only Qwen endpoint rejected the embedding request. The isolated GPU listener used `qwen3-embedding:0.6b` digest `ac6da0dfba84a81fdbfbaf330198c33cd77c4cdfc53e8bc50eb581914a15621d`. It produced 256-dimension vectors for 16 reports and 489 exploratory candidate functions in 58.01 seconds with 90,899 input tokens and 1.23 GB of reported VRAM. This reranks a lexical shortlist, which limits recall gains when the correct function never reaches the shortlist. It changed ordering or selection in nine reports and dropped one required function in the HUD probe. The separate listener was stopped after the cache was built.

The guest docking drafts recovered the action and mooring functions and missed guest result handling and the deck position helper. The remote car drafts missed `drive_order` and `interpolate_cars` in the primary candidate runs. These are examples of ownership and replication paths that lexical and candidate graph retrieval still miss.

## Reproduce

Use Node 24, Python 3.12, the pinned Qwen model and two clean checkouts. Choose an ignored local output directory. The detailed logs contain draft text and source excerpts.

```powershell
New-Item -ItemType Directory -Force build/learning | Out-Null
$bench = 'tools/discord-issue-pilot/multistage-benchmark.mjs'
$tools = 'tools/discord-issue-pilot/learning'
$source = '<clean 9097d61 checkout>'
$pr77 = '<clean 0ed6fd9 checkout>'
$common = @('--main', $source, '--pr77', $pr77)
$lesson = @('--lessons', 'tools/discord-issue-pilot/learning-lessons.json')
node $bench @common --variants production,pr77 --generate --details > build/learning/comparison.jsonl
node $bench @common @lesson --variants candidate,additive --generate --details > build/learning/candidate.jsonl
node $bench @common @lesson --variants pr77,candidate,additive --cases independent,history-probe --trial 1 --generate --details > build/learning/repeat.jsonl
$logs = @('build/learning/comparison.jsonl', 'build/learning/candidate.jsonl', 'build/learning/repeat.jsonl')
node "$tools/report.mjs" @logs
```

For quality scores, review the model-authored fields against the frozen rubric and the supplied excerpts. Record decisions in the same format as `learning-review.json`, with `payloadSha256` computed over the UTF-8 output of Node's `JSON.stringify(payload)`. For the exact original drafts, the checked-in review is usable directly. Regenerated drafts with a different fingerprint need fresh decisions. The validator also checks that flagged claims occur in the formatted model text.

```powershell
node "$tools/audit.mjs" tools/discord-issue-pilot/learning-review.json @logs > build/learning/review.jsonl
node "$tools/report.mjs" @logs build/learning/review.jsonl
```

For an arbitrary report, add `--learning` to the standalone experiment. Add `--planner` to enable exploratory Qwen requests. `--generate` generates and checks an export. `--details` includes exact excerpts. `--history` accepts a completed-title snapshot.

```powershell
node tools/discord-issue-pilot/multistage/experiment.mjs --source $source --report '<report.txt>' --learning @lesson --generate
node "$tools/lesson-review.mjs" status $source $lesson[1]
node "$tools/lesson-review.mjs" pin $source '<curated unpinned lessons JSON>'
```

To reproduce embeddings, start a separate loopback-only Ollama server on port 11635 with cloud use disabled and its own model directory. Pull `qwen3-embedding:0.6b` into that store. The cache command uses the fixtures by default or accepts up to 20 explicit `--report` files for other reports. An unfamiliar report requires its own query embedding in the cache.

```powershell
node "$tools/embedding-cache.mjs" --source $source --port 11635 --out build/learning/embedding-cache.json
node $bench @common @lesson --variants candidate --embeddings build/learning/embedding-cache.json > build/learning/dense.jsonl
```

For fresh Graphify, reuse `tools/graphify-studio-benchmark/build_snapshot.py` from PR #28 at `e3918ec24a692c930106c3218bfa9b4aae7af8c0`. Run it against the pinned `godot-cove` directory in an isolated environment with the [Graphify Godot fork](https://github.com/hidalgob/graphify-godot) at `cd3d27cc5b201e1135dbc8d62db0704e4040b66b` and `tree-sitter-language-pack==0.13.0`. Pack the emitted graph’s nodes and links with the coverage report’s input hashes.

```powershell
& '<isolated Graphify Python>' '<PR #28 checkout>/tools/graphify-studio-benchmark/build_snapshot.py' (Join-Path $source godot-cove) build/learning/graphify-fresh
$graph = Get-Content -Raw build/learning/graphify-fresh/graph.json | ConvertFrom-Json -AsHashtable
$coverage = Get-Content -Raw build/learning/graphify-fresh/coverage.json | ConvertFrom-Json -AsHashtable
@{nodes=$graph.nodes; links=$graph.links; hashes=$coverage.sha256_before_and_after} |
  ConvertTo-Json -Depth 30 -Compress | Set-Content -Encoding utf8 build/learning/graph-snapshot.json
node $bench @common @lesson --variants candidate --graph build/learning/graph-snapshot.json > build/learning/graph.jsonl
```

## Production readiness

1. Keep production operating as-is and leave PR #77’s deterministic path as the comparison to beat. Keep the additive planner optional for evidence investigations. Its extra calls and tokens yielded a small coverage gain, while dense reranking and fresh Graphify edges had no benefit on the 15-report measure.
2. Improve deterministic navigation from input entry points to state writers, replication and presentation. Promote verified receiver identity and scoped incoming/outgoing edges ahead of generic body hits. Review the failure cases around car input expiry, guest docking result handling and swim/board transitions. Freeze a new set before comparing the next ranker.
3. Keep the curated lesson and fingerprint workflow. Check that a relevant lesson’s concrete constraints survive formatting, then obtain a second reviewer and more positive and negative transfer cases. Keep private training data and model weights out of the workflow.
4. Before changing the worker default, require higher coverage on independent cases, independent human review of factual claims and requirements, then review latency and low-confidence routing against an explicit budget.

## Verification and scope

Passed 28 Node tests and seven Python tests. The new cases exercise stale and approved lesson handling, typed receivers, named RPC and Graphify hash checks, out-of-scope request rejection, and preservation of reserved snippets. Also ran the standalone opt-in command on the HUD report and confirmed the lesson passed source verification with no training approvals. The work began with the team task workflow and overlap review. No Godot gameplay runtime checks were performed. The benchmark measured retrieval and generated briefs.

The production GPU worker ran during the experiment. The worker code, queue and settings remained in place, and the private training store was neither read nor updated. There were no gameplay edits, deployment, fine-tuning or merge.
