# GPU brief retrieval benchmark

The benchmark uses sanitized task fixtures based on [the multiplayer helm investigation](https://github.com/PeterFacina/richs-houseboat/issues/66) and [the HUD layout report](https://github.com/PeterFacina/richs-houseboat/issues/69). It indexes pinned game text at `688da719026b5096740f6f610490b7fa70b07422` in a temporary SQLite database. The script expects ordinary Git worktrees and uses its own index and frozen GitHub task summaries.

## Reproduce

From the draft branch, prepare two detached worktrees. Node.js 24, Python 3 and Git are required. Set `HOUSEBOAT_KNOWLEDGE_PYTHON` if Python is installed outside `PATH`.

```powershell
git fetch origin refs/pull/28/head:refs/remotes/origin/pr-28
git worktree add --detach ../gpu-retrieval-main 688da719026b5096740f6f610490b7fa70b07422
git worktree add --detach ../gpu-retrieval-pr28 e3918ec24a692c930106c3218bfa9b4aae7af8c0
git -C ../gpu-retrieval-main sparse-checkout set --no-cone -- '/AGENTS.md' '/docs/**' '/tools/**' '/godot-cove/**/*.gd' '/godot-cove/**/*.godot' '/godot-cove/**/*.tscn' '/godot-cove/**/*.tres' '/godot-cove/**/*.gdshader' '/godot-cove/**/*.gdshaderinc' '/godot-cove/**/*.cs' '/godot-cove/**/*.md' '/godot-cove/**/*.txt' '!/godot-cove/ottawa/**'
node tools/discord-issue-pilot/retrieval-benchmark.mjs --baseline ../gpu-retrieval-main --pr28 ../gpu-retrieval-pr28
```

Append `--runs 3` to generate briefs on local Ollama with Qwen3 14B and a context size of 8,192. Runs rotate variant order and use one local generation at a time. The default command measures retrieval only. `--details` adds the generated responses for the sanitized fixtures to the local output so a reviewer can evaluate claims individually.

Each variant receives the same pinned text, SQLite chunks, fixture and evidence budget. The merged-main variant uses its managed Studio matcher. The #28 variant calls the actual function ranker from its draft head on the same SQLite index. Its legacy matcher precedes the managed symbol catalog, guide classifications and compact GitHub context. The candidate keeps the managed interface and incorporates #28’s approach of merging overlapping chunks and choosing a bounded window inside a function. The pinned source predates the candidate's HUD guide, so the HUD test measures source retrieval without it.

## Scoring

- **Source relevance** counts excerpts that contain a verified primary or supporting anchor for a fixture. **Coverage** counts distinct primary anchors. The anchors come from the pinned code and the [helm review](https://github.com/PeterFacina/richs-houseboat/pull/67) and [HUD draft](https://github.com/PeterFacina/richs-houseboat/pull/70).
- **Range accuracy** checks exact excerpt text at its reported path and line. **Citation relevance** counts references in the generated fields kept by the brief formatter. It excludes the formatter's source inventory. The legacy variant labels some guides as source. Those occupy source slots but do not supply the code anchors scored here. A relevant reference can still accompany an unsupported claim.
- **Context bytes** measure serialized retrieved evidence. **Prompt and output tokens** are Ollama counters. **Generation time** is wall time for the provider request and guarded export. Compare multiple rounds and track cold load separately.

## Retrieval results

| Case | Variant | Relevant source excerpts | Primary anchors | Exact ranges | Evidence bytes |
| --- | --- | ---: | ---: | ---: | ---: |
| #66 helm | Merged main | 2/5 | 0/6 | 5/5 | 5,082 |
| #66 helm | PR #28 | 0/5 | 0/6 | 5/5 | 4,768 |
| #66 helm | Candidate | 7/7 | 6/6 | 7/7 | 4,402 |
| #69 HUD | Merged main | 0/5 | 0/6 | 5/5 | 6,029 |
| #69 HUD | PR #28 | 0/5 | 0/6 | 5/5 | 4,391 |
| #69 HUD | Candidate | 6/6 | 6/6 | 6/6 | 4,188 |

The #69 production capture contained six file-backed excerpts at `342af56`. Their lines were accurate. An isolated replay of the original case reproduced the five source selections. The shortlist ranked short, exact generic identifiers ahead of the HUD owners. The lexical fallback also interpreted a displayed place name as a character-model cue. The candidate replay selected the HUD construction and display updates, toggle handler, calendar, region label, and action-hint consumer. PR #28 improves the passage once a file has been selected, while the tested draft still relies on the older file shortlist. The candidate routes HUD and multiplayer helm reports to owning functions and falls back to the shared search when the pinned index lacks a relevant passage.

The first candidate trial omitted the helm anchor definition. Qwen named its file after reading a guide, so all three helm exports hit the path guard. The final candidate adds the direct anchor definition as evidence and keeps the existing export guard.

## Local Qwen results

Three paired rounds per case used Qwen3 14B. Tokens and wall time are medians. Citations and export counts are totals over the three rounds. Ollama reported 4–9 ms of model load per request in this final series.

| Case | Variant | Input tokens | Output tokens | Generation wall time | Relevant source citations | Guarded exports |
| --- | --- | ---: | ---: | ---: | ---: | ---: |
| #66 helm | Merged main | 2,005 | 831 | 11.30 s | 16/26 | 3/3 |
| #66 helm | PR #28 | 1,937 | 633 | 8.63 s | 0/28 | 0/3 |
| #66 helm | Candidate | 1,879 | 725 | 9.80 s | 33/33 | 3/3 |
| #69 HUD | Merged main | 2,475 | 716 | 9.84 s | 0/9 | 3/3 |
| #69 HUD | PR #28 | 1,884 | 626 | 8.52 s | 0/18 | 3/3 |
| #69 HUD | Candidate | 1,827 | 495 | 6.80 s | 12/12 | 3/3 |

The three #28 helm runs named files outside their retrieved evidence, triggering the path guard. A manual spot check of the final candidate still found imprecise wording about who receives a helm request and HUD claims that went beyond the cited range. Source relevance, claim accuracy and export acceptance are separate checks. The shared formatter also still adds generic implementation boilerplate to notes-only briefs.

These are two development cases used to design the rules. The scores establish a regression check for those cases. A held-out report set is needed to estimate broader accuracy and token effects. Gameplay behavior, screenshots, and runtime host/guest behavior are outside this benchmark.
