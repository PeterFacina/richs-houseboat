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
