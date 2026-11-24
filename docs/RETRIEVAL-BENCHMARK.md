# Coding-agent retrieval benchmark

## Exploratory runs — 2026-11-24

Task: read-only investigation of houseboat water interaction before helm use. Both reports identified the initial departed gate and overlapping issue/PR. Source revision: bca3d16dc9aecb5f43ce5fb2fa6b6712e957f33a. Kilo Auto Free selected different underlying models (UI labels truncated: Nemotron 3.5 Sup... and ERNIE-5.5-Flash-P...). These are user-reported UI counters and agent reports, not independently instrumented traces.

| Metric | Original | Stricter prompt |
| --- | ---: | ---: |
| Input tokens | 153,100 | 145,400 |
| Active context | 130,700 | 73,700 |
| Output tokens | 4,100 | 2,700 |
| Reasoning tokens | 7,200 | 2,300 |
| Cache reads | ~1,100,000 | 569,100 |
| Reported cost | $0 | $0 |

Input decreased ~5.0%, active context ~43.6%. Cache reads are repeated/reused context, not unique input. Do not add counters without knowing provider accounting. The original agent reported ~2,600 source lines; the second used narrower ranges and the Python index, but skipped the PR diff and overgeneralized the departed condition after helm exit. The first run lacked access to Python from the agent environment. Model selection, environment and retrieval strategy all changed; no causal savings established.

## Controlled comparison

Use fresh sessions, the same explicitly selected model/provider, same pinned source revision, same task, equivalent live GitHub evidence (or frozen sanitized fixture), same permissions and comparable cache conditions. Record model/version, revision, tool calls, source bytes/lines, input/output/reasoning/cache counters separately, context peak or final (label which), elapsed time and cost. Repeat at least three paired runs if feasible. Do not treat Auto Free routing as a fixed model. Score accuracy independently: before first helm versus after leaving helm, moored behavior, actual callers, dependencies, overlap evidence from relevant diff, read-only compliance. Count omissions and false claims. No savings claim if quality degrades. Publish sanitized results in GitHub; no private logs or credentials.

## Third exploratory run — 2026-11-24

Revision 67add06505414f9c40ee34c4e65c32b9483dde0a (PR #60 merged; no gameplay changes in that PR). Kilo Auto Free selected Nemotron 3 Ultra. Original task prompt reused. UI: 129,100 input, 109,400 active context (43%), 4,000 output, 860 reasoning, ~1,200,000 cache reads, $0. Input down ~15.7% versus run 1, not attributable to retrieval because model changed and agent did not use the new tools. Agent self-audit reported not rereading AGENTS.md, choosing direct reads, incorrectly assuming github_context.py required gh, and having working Python. It missed issue #56 and PR #57 and contradicted itself about ignition-off drift. Self-reported source line and tool counts are inconsistent, so do not treat them as measured. The user separately verified actual function retrieval and live GitHub shortlist on Windows and ran all four existing tests successfully (2.442 s). Next test: required startup command and receipt; measure compliance and accuracy before claiming savings.

## Fourth exploratory run — 2026-11-24

Revision 86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5 (PR #61 merged). Original read-only prompt reused. Kilo Auto Free UI label: Nemotron 3.5 Super... (truncated; appears to match run 1, exact version not verified). User-reported counters: 78,700 input, 70,000 active context (27%), 2,900 output, 3,200 reasoning, 403,200 cache reads, $0 cost. Compared with run 1: 48.6% less input and 46.4% less active context; compared with run 3: 39.0% less input. These are descriptive comparisons, not controlled causal estimates.

Agent receipt reports reading AGENTS.md, running start_task.py, consulting ARCHITECTURE.md and BOAT-WATER.md, using retrieve.py for passive_water_velocity, sail_river and sail, and github_context.py for PR #57 and selected file patches. Report identified issue #56 and draft PR #57, distinguished classic demo from river campaign, and explained the departed gate and open-water spawn patch. Runtime behavior and tool traces were not independently verified; no playtest was performed. User separately verified bootstrap and seven passing unit tests (4.254 s); expected missing origin/main in test fixtures emitted harmless stderr messages. Target of 50,000 input tokens not yet met.

## Next experiments

Keep retrieval infrastructure unchanged. Repeat the original prompt in a fresh session at revision 86cf4a4, preferably pinning the same model as run 4; capture counters before follow-up. Compare startup receipt, evidence, correctness and token counters. Then test transfer to multiplayer with a separate fresh session: investigate how a guest takes and releases the houseboat helm and how host authority and vessel state are synchronized; identify relevant guides, functions, dependencies and overlapping GitHub work, report revision and tools, read-only. This is a new task, not a direct token-savings comparison to the drift task. Record actual model, revision, live overlap changes, counters and verification gaps. For a later editing benchmark, select an unclaimed scoped issue, use an isolated task branch and human-reviewed PR; assess tests and playtest acceptance alongside consumption. Do not alter the live GPU worker as part of these experiments.

## Fifth and sixth exploratory runs — 2026-11-24

Both runs used revision 86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5 and explicitly selected Nemotron 3.5 Super VL Free, Instant (1M context window). User-provided UI counters and agent reports, not independently instrumented traces.

| Metric | Run 5: repeat drift task | Run 6: multiplayer helm |
| --- | ---: | ---: |
| Input tokens | 91,900 | 130,900 |
| Active context | 78,100 (8%) | 111,500 (11%) |
| Output tokens | 4,000 | 5,800 |
| Reasoning tokens | 0 | 0 |
| Cache reads | 403,200 | ~2,200,000 |
| Reported cost | $0 | $0 |

Run 5 reported successful startup, function retrieval and live overlap checks. Input was 40.0% below run 1, but 16.8% above run 4. It missed the central departed gate in its explanation, incorrectly treated an empty PR file-list response as proof of no committed changes, and speculated about visual jitter. The mode and context capacity differed from run 4, so this was not a controlled replication. Run 6 reported successful startup, relevant guides, live overlap query, one function retrieval and conventional targeted reads. It traced host authority, helm acquisition/release, captain validation, remote input expiry, RPC channels and state synchronization. It did not report inspecting the relevant PR patch; the detailed technical claims and tool traces have not been independently audited. No runtime or playtest verification was performed in either read-only run. Run 6 is a different task and cannot establish savings against the drift baseline. Reported context percentages use different capacities across runs; compare absolute tokens instead.

Across runs 4–6, startup compliance was consistently reported, but correct conclusions and efficient retrieval are not guaranteed. The next controlled mode comparison should repeat the original drift task in fresh sessions at the same source revision and with the same explicitly selected model, changing only reasoning effort where available. Record exact mode, model, context capacity, live overlap evidence and counters before follow-ups. Keep workflow unchanged for this comparison. The 50K target remains unmet. Do not interpret missing or empty GitHub tool output as proof of no overlap or changes; verify with an independent targeted query or report uncertainty.
