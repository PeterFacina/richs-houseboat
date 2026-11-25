# GPU retrieval and historical learning

## Design

The experiment builds on the strongest deterministic configuration in [PR #77](https://github.com/PeterFacina/richs-houseboat/pull/77). It is available through an explicit experimental command. The Discord worker and Studio defaults are unchanged.

- Rebuild the symbol index from a clean game checkout. Reuse existing scene-to-script and resource references, architecture guides, lexical calls, and corpus-derived term associations. Historical issue and PR titles come from the existing bounded, completed-only snapshot.
- Reserve eight deterministic source passages from the previous ranking. Combine whole-report and clause matches, vocabulary associations, and verified call neighbors to rank the exploratory slots. Apply soft diversity across files and clauses. The same rules apply to new code and unfamiliar reports.
- Trace calls through declared GDScript receiver types and preload aliases, including simple constructs and receiver chains. Resolve statically named calls through `rpc`, `rpc_id` and `call_deferred`. Shared dotted field names provide weak read/write hints. Visually inspecting the intended instance and authority still matters.
- Optionally rerank the exploratory slate with local embeddings. Fit the small embedding model on an isolated Ollama listener for the benchmark. The cache is scoped to the source revision and exact report texts.
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
- The structured audit checks concrete requirement coverage, distinct unsupported or contradicted factual claims, and lesson use. It examines the model-authored draft and its exact evidence. It excludes the automatic quote of the report. Qwen evaluates its own model family in a separate call, so the scores are provisional. The export guard measures reference and content safety independently of factual correctness.
- Token counts include planning and generation. Timings begin at retrieval and end at the export check. One-time index building, ablation caches and quality audits have separate cost and are excluded from per-draft time.

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
node "$tools/audit.mjs" build/learning/comparison.jsonl build/learning/candidate.jsonl > build/learning/audit.jsonl
node "$tools/report.mjs" build/learning/comparison.jsonl build/learning/candidate.jsonl build/learning/audit.jsonl
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
$graph = Get-Content -Raw build/learning/graphify-fresh/graph.json | ConvertFrom-Json -AsHashtable
$coverage = Get-Content -Raw build/learning/graphify-fresh/coverage.json | ConvertFrom-Json -AsHashtable
@{nodes=$graph.nodes; links=$graph.links; hashes=$coverage.sha256_before_and_after} |
  ConvertTo-Json -Depth 30 -Compress | Set-Content -Encoding utf8 build/learning/graph-snapshot.json
node $bench @common @lesson --variants candidate --graph build/learning/graph-snapshot.json > build/learning/graph.jsonl
```
