# Held-out GPU brief evaluation

This follow-up to [PR #71](https://github.com/PeterFacina/richs-houseboat/pull/71) tests retrieval and review outside the HUD and multiplayer helm development cases. The benchmark froze its five paraphrased reports, required functions, supporting functions, catalog experiment, and reviewer prompt at `22b6a6a` before measuring retrieval or generating a brief. The cases are based on two public player issues and three public playtest or implementation reports. They describe tasks for evaluation and make no claim of fresh gameplay reproduction. [Frozen cases](../tools/discord-issue-pilot/heldout-cases.json)

| Domain | Report | Expected function ranges |
| --- | --- | --- |
| Fishing motion and sound | [Playtest PR #12](https://github.com/PeterFacina/richs-houseboat/pull/12) | `tick_fight`, `render_fishing`, `pose_rod`, `crank_sounds` |
| Vehicle audio | [Issue #49](https://github.com/PeterFacina/richs-houseboat/issues/49) | `set_ignition`, `run`, `present`, `car_poses` |
| Player animation | [Issue #52](https://github.com/PeterFacina/richs-houseboat/issues/52) | `animate_bong`, `animate_pen`, `pose_action`, `prop_pose` |
| Progression | [PR #14](https://github.com/PeterFacina/richs-houseboat/pull/14) | `award`, `buy`, `snapshot_for`, `register` |
| World generation | [PR #27](https://github.com/PeterFacina/richs-houseboat/pull/27) | `build_town`, `plan`, `find_approach`, `clear_route` |

## Reproduce

Prepare clean detached worktrees at `688da719026b5096740f6f610490b7fa70b07422` for main and `916c2a822f01235791433a419404e0aee3355974` for #71. The main worktree needs the tracked game text and docs. The #71 worktree needs `tools/game_prompt_studio`. A sparse main worktree can use the [prior benchmark's text-only checkout](GPU-RETRIEVAL-BENCHMARK.md#reproduce). Set `HOUSEBOAT_KNOWLEDGE_PYTHON` if Python is outside `PATH`.

```powershell
node tools/discord-issue-pilot/heldout-benchmark.mjs --main ../gpu-retrieval-main --pr71 ../gpu-retrieval-pr71
node tools/discord-issue-pilot/heldout-benchmark.mjs --main ../gpu-retrieval-main --pr71 ../gpu-retrieval-pr71 --generate
```

The first run scores retrieval and writes JSON lines to stdout. The second adds one Qwen3 14B generation per case and variant plus an independent review of each #71 draft. `--details` includes sanitized fixture passages, generated payloads, and review findings to enable claim adjudication. Keep detailed raw benchmark output local. The harness opens a temporary SQLite index of the pinned main source and freezes the GitHub-task input to an empty list. All first passes use the same model tag and digest, context 8,192, detailed tier, temperature 0.25, and the same per-case seed. Variant order rotates across cases. Reviewer passes use the same model with a separate prompt, 8,192 context, and a 1,850-token output cap. Both drafts use the production formatter and export guard. The runner does not call the production worker or read training records.

## Scoring and interpretation

Source relevance counts excerpts overlapping a required or supporting function with body lines. Coverage counts distinct required functions seen at least once. Range fidelity compares the excerpt at the cited path and line with the exact pinned bytes after Studio's per-line clipping. The reviewer uses the same evidence as the #71 draft. It can request further inspection of a missing dependency. Its output cannot supply source evidence the retrieval pass omitted.

For claim scoring, inspect model-authored text retained by the brief formatter. Count each distinct affirmative claim about current code, behavior, or the report that the supplied evidence fails to support. Keep recommendations and genuine questions outside this count. Score preserved report requirements separately. Review the underlying pinned text and evidence ranges to resolve unclear cases. Flag a generated path when it triggers the export guard even if the named file exists elsewhere in the repository. The reviewer is not the judge of its own output.

## Retrieval results

| Case | Main and #71 relevant / returned | Main and #71 required / expected | Catalog relevant / returned | Catalog required / expected |
| --- | ---: | ---: | ---: | ---: |
| Fishing motion | 2/5 | 2/4 | 4/5 | 4/4 |
| Vehicle audio | 0/5 | 0/4 | 0/5 | 0/4 |
| First-person props | 1/5 | 0/4 | 3/5 | 2/4 |
| Progression reconnect | 0/5 | 0/4 | 1/5 | 1/4 |
| Town driveways | 1/5 | 1/4 | 1/5 | 0/4 |
| Total | 4/25 | 3/20 | 9/25 | 7/20 |

Main and #71 returned identical evidence on all five cases. Their general matcher is shared with a few generic filtering changes in #71, whose substantial gains on the previous cases came from explicit HUD and helm routing. The experimental catalog matcher uses corpus frequency, function and path symbols, bounded windows scored against the complete report, and a small boost for already-relevant direct resource dependencies. Subsystem guide retrieval stays in Studio. Exact source ranges matched in all 75 scored excerpts. Generic selection still missed every required vehicle-audio function and lost the driveway entry covered by main. Keep it experimental and evaluate a newly frozen set before promoting it.

## Brief and reviewer results

The final run completed 15 drafts and five reviews. Each row summarizes five cases. Time and token values are medians. Reviewed totals include the original #71 draft and the added review pass. Retrieval scoring excluded its Python selector and shared index build for all variants.

| Variant | Retrieval wall time | Input tokens | Output tokens | Generation wall time | Unsupported premises | Guarded exports |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Main | 25 ms | 2,334 | 591 | 8.49 s | 4 | 5/5 |
| PR #71 | 21 ms | 2,334 | 586 | 8.13 s | 3 | 4/5 |
| Catalog experiment | 123 ms | 1,761 | 756 | 10.48 s | 1 | 5/5 |
| PR #71 plus reviewer | 21 ms | 4,900 | 1,609 | 22.63 s | 3 | 4/5 |

The reviewer alone used medians of 2,566 input and 1,037 output tokens and took 14.57 s. It returned 16 unsupported-claim flags, 11 missing-dependency flags, and two irrelevant-citation flags. No finding was labeled `misunderstood_requirement`. Those are the model's labels, including duplicate or overstated findings. Both the #71 draft and its reviewed version failed the vehicle-audio path check for a file outside the retrieved evidence. Main passed it with the same evidence and generation settings. The small sample and variation between those paired drafts do not establish a change in export reliability. The first main fishing generation included a 10.4 s model load. The other loads were 4–9 ms.

| Case | Main | #71 | Catalog | Reviewed #71 |
| --- | ---: | ---: | ---: | ---: |
| Fishing motion | 0 | 0 | 1 | 0 |
| Vehicle audio | 0 | 0 | 0 | 0 |
| First-person props | 1 | 1 | 0 | 1 |
| Progression reconnect | 0 | 0 | 0 | 0 |
| Town driveways | 3 | 2 | 0 | 2 |

The investigator adjudicated the rendered fields against the report and pinned excerpts using the same rubric for all variants. This was one audit, without an independent second scorer. Examples of distinct unsupported premises counted were a wrong rod-rig receiver name, treating a historical remote-visibility report as part of the current first-person issue, attributing a `use` method to the avatar, assigning driveway clearance to a furniture placement helper and a property-listing helper, and turning a property-listing radius into a driveway clearance requirement. The 43-unit number occurs in the source but applies to another operation.

The reviewer findings identified rod-rig inspection leads, but the revised fishing brief omitted those leads. The rewrites retained a bad avatar method attribution and both incorrect driveway dependencies. They also missed the explicit requirement to test a seated shutdown and the paired highway-frontage and side-street check. The catalog drafts retained both tests. The measured review cost did not produce a lower unsupported-claim count or a higher export pass count. The reviewer and catalog ranker are available in the benchmark only. Production integration would need a new independent case set and better evidence for cross-subsystem dependencies.
