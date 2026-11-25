# Codex gameplay prompt benchmark

Across three paired Codex CLI trials, the deterministic packet reached handoff faster on HUD and solo recovery and slower on guest-car input. Each retrieval mode passed two cases on the first attempt. The two HUD patches missed different parts of the paused behavior. Keep the candidate in preview pending a larger trial.

## Method

- This trial intentionally uses Codex CLI 0.171.0-alpha.13 with `gpt-6.2-sol` and medium reasoning in every arm. The comparison is within Codex. The frozen instructions supplied the packets, cases and scorecard. [Production candidate PR #79](https://github.com/PeterFacina/richs-houseboat/pull/79) · [Benchmark instructions](https://github.com/PeterFacina/richs-houseboat/blob/f06ca9f5bccff63f5fa1f48787d36b15d5c625f4/docs/production-candidate/benchmark/README.md)
- Each session started independently at `9097d61064bd0db0330832d1f355cb595bb0f5f7` in a detached worktree with the original packet bytes followed by identical local-edit and reporting instructions. Agents received opaque arm paths. Godot 4.7.2 stable `ed1daf0bf` ran on the same Windows host. Separate save roots used Windows `APPDATA`. HUD agents used their own fixture roots and the reviewer checked separately isolated data. Godot import regenerated metadata before the HUD sessions, identically for both arms. Those import-only files are excluded from patch totals.
- A preflight showed the workspace-write profile blocked shell launch. All scored Codex sessions used the same full-access tool profile with instructions to stay within their assigned worktree. The preflight contributes no scored metrics.
- The elapsed time is CLI launch through the first complete handoff, including agent-run tests. The HUD and solo pairs each ran concurrently on the same host, so contention and cache scheduling can affect elapsed time. The car arms ran sequentially for exclusive access to the fixed local multiplayer port. Some solo reviewer fixtures overlapped the first car arm, which can affect wall time. The trace does not provide time to first patch. Capturing exact provider input, cached input, output and reasoning output used the CLI's final usage event. Reported input includes cached input, and reasoning output is part of reported output. The scorecard leaves absent measurements blank.
- First-attempt success requires every frozen criterion to pass. The reviewer reproduced behavior in the running Godot game, used matching fixtures on each arm, and recorded qualitative evidence before drawing comparative conclusions. The reviewer gave no directions to the agents after handoff. The scorecard counts distinct corrections needed to satisfy a failed criterion. Patches, raw traces, local data and test harnesses are private. The screenshots show the game viewport of a disposable fixture.

## HUD pause and FPS

| Packet | Retrieval mode | Input | Cached input | Uncached input | Output | Reasoning | Handoff | Frozen items passed | First attempt |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| A | Original | 2,619,727 | 2,539,904 | 79,823 | 11,579 | 3,291 | 469.3 s | 2/3 | No |
| B | Deterministic v1 | 1,484,740 | 1,360,640 | 124,100 | 11,320 | 2,829 | 308.1 s | 2/3 | No |

| Frozen acceptance item | A | B |
| --- | --- | --- |
| Pause hides diagnostics and the clock stays visible and fixed | Pass | Pass |
| Resume restores both F3 states and F4 still changes the preset | Pass | Pass |
| Narrow and wide bounds, live interaction hint and waypoint distance | Fail. Bounds and waypoint passed. The hint disappeared during pause and returned on resume. | Fail. Bounds and hint passed. Waypoint distance stayed stale during solo pause after a controlled position change. |

The reviewer used the Godot game scene at 960 × 640 and 1440 × 600. Both arms kept the clock geometry fixed with diagnostics enabled and disabled, and both advanced the graphics preset after either F3 starting state. A refreshed the same waypoint from 18.1 km to 4.0 km while solo physics was paused at both sizes. B stayed at 18.1 km during the same synthetic position change. B's own playtest verified a live host waypoint update from 0.0 km to 0.3 km while the host menu was open. The strict third-item score covers the live hint and waypoint during the pause itself, as requested in both packets.

A added explicit diagnostic preference state to `cove.gd` and wired it through `fishing.gd` and `river_pause.gd`. The pause process refreshes the waypoint even with solo physics stopped. B touched `fishing.gd` and `river_pause.gd` and retains the hint by keeping the upper-left container visible. Its waypoint update depends on gameplay processing, so it cannot run while the solo scene tree is paused. Both updated `docs/systems/FISHING-PLAYER.md`. Core source navigation for both covered `cove.gd`, `fishing.gd`, `river_pause.gd`, `river_backpack.gd`, `shannon_job.gd`, `river_graphics.gd`, `river_campaign.gd`, `title_screen.gd` and `project.godot`. A also read `river_menu_theme.gd`. B checked the host path in `river_crew.gd`.

A's own rendered checks and the isolated solo-slot smoke passed. Its hint check only asserted the resumed state. B's own rendered checks and headless startup passed. Its paused solo check explicitly expected the waypoint text to stay constant, so it left the required refresh path untested. Both ran `git diff --check`. The reviewer used the same pause, resume, F3, F4, bounds and waypoint checks and visually inspected the same game view at both sizes. The game reported an unrelated typed-array error in `fish_finder.gd` during the review fixture, outside the changed files.

[Packet A active](screenshots/hud-a-active.png) · [Packet A paused](screenshots/hud-a-paused.png) · [Packet B active](screenshots/hud-b-active.png) · [Packet B paused](screenshots/hud-b-paused.png)

For the HUD pair, A completed 25 shell actions and B completed 32. B made one unnecessary source exploration by opening the warehouse gameplay verifier after already finding a usable gameplay-test pattern in the vehicle verifier. B also made one incorrect technical assumption by asserting that solo pause should hold the waypoint distance constant. A had no confirmed unnecessary source step or implementation-guiding technical assumption. The first patches need one correction each. A needs to keep the live hint visible in pause, and B needs a waypoint refresh path while solo gameplay processing is paused.

The lower total input for B was driven by cached input. B used 124,100 uncached input tokens versus 79,823 for A, an increase of 55%. One execution per packet leaves the timing and token deltas sensitive to cache behavior, trial order and individual implementation decisions.

## Solo save recovery notice

| Packet | Retrieval mode | Input | Cached input | Uncached input | Output | Reasoning | Handoff | Frozen items passed | First attempt |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| A | Deterministic v1 | 3,281,041 | 3,199,744 | 81,297 | 9,938 | 1,804 | 331.2 s | 3/3 | Yes |
| B | Original | 4,737,723 | 4,651,264 | 86,459 | 13,129 | 3,453 | 455.9 s | 3/3 | Yes |

| Frozen acceptance item | A | B |
| --- | --- | --- |
| Corrupt and missing primaries with a valid backup produce exactly one solo notice | Pass | Pass |
| Healthy primary, fresh slot and crew produce no notice | Pass | Pass |
| First and later saves preserve expected rotation and journal schema. Existing recovery check passes. | Pass | Pass |

Independent Godot fixtures loaded each save condition, counted visible notice transitions in gameplay, verified expiry and checked the corrupt-save notice before taking mouse control, and compared the journal bytes before and after recovery saves. The first save kept the original backup and the next rotated the newly written primary. Both ran `verify_ledger_recovery.gd`, the modified `verify_solo_slots.gd`, and `verify_progression_network.gd`. Both patches passed `git diff --check`.

Both modified `godot-cove/fishing.gd`, `godot-cove/verify_solo_slots.gd` and `docs/systems/PROGRESSION-ECONOMY.md`. The main investigated paths included `river_ledger.gd`, `river_campaign.gd`, `fishing.gd`, `cove.gd`, `title_screen.gd`, `solo_saves.gd`, `solo_slot_menu.gd` and the existing verification scripts. A uses the existing objective label and yields to genuine objective text. B owns a dedicated transient label, which allows the notice to coexist with the objective and adds a separate HUD row. Both preserve the ledger format and existing load and save paths.

The deterministic packet reached handoff 27% sooner with 31% fewer total input tokens and 6% fewer uncached input tokens. Both met the same acceptance criteria without correction. A made 30 completed shell calls and B made 44. The unnecessary read counted for B was the initial 55 lines of `boat_amenities.gd`, which did not inform the save, HUD notice, crew control or regression test. No implementation-guiding incorrect technical assumption was confirmed in either arm.

[Packet A recovery notice](screenshots/solo-a-corrupt.png) · [Packet B recovery notice](screenshots/solo-b-corrupt.png)

## Multiplayer guest car input status

| Packet | Retrieval mode | Input | Cached input | Uncached input | Output | Reasoning | Handoff | Frozen items passed | First attempt |
| --- | --- | ---: | ---: | ---: | ---: | ---: | ---: | ---: | --- |
| A | Original | 1,823,854 | 1,753,216 | 70,638 | 10,385 | 2,475 | 325.7 s | 4/4 | Yes |
| B | Deterministic v1 | 2,568,241 | 2,467,072 | 101,169 | 12,269 | 4,439 | 394.8 s | 4/4 | Yes |

| Frozen acceptance item | A | B |
| --- | --- | --- |
| Host detects expiry and only the assigned guest sees the status | Pass | Pass |
| Fresh input and seat exit clear the status through re-entry | Pass | Pass |
| Braking, pose application, seats, camera and engine mix retain their behavior | Pass | Pass |
| Isolated host and guest input-loss and recovery exercise | Pass | Pass |

The common Godot test used three separate instances and save roots. The host received steering and throttle during a turn. The driver then stopped sending car RPCs while other ENet traffic continued. Both hosts expired the previous command and applied fail-safe braking. Only the driving guest showed the new line. A new command from the same guest released the brake and hid the line. The guest left and re-entered the same seat. The reviewer checked the rendered HUD, guest steering pose, active driving camera, and playing engine stream with valid pitch and volume. The two agents' headless tests also covered ordinary braking and solo visibility. `verify_vehicle_exit.gd` passed for both. Gameplay audio was checked through playback and mix properties. Listening tests and multi-machine network conditions remain unverified.

Both patches changed `godot-cove/marina_cars.gd`, `godot-cove/fishing.gd` and `docs/systems/MULTIPLAYER.md`. A added `godot-cove/verify_road_car_input.gd` as a reusable regression test. B kept its 15-check equivalent in a local harness. A clears the status in the accepted-command handler. B clears it on the next host vehicle step. Both target the affected driver with a reliable update and keep the existing physics and pose stream. Their main source reads covered `marina_cars.gd`, `marina_car.gd`, `fishing.gd`, `river_crew.gd`, the campaign and lobby paths, and the vehicle-exit and progression-network verifiers.

A completed 27 shell actions and B completed 34. Each read the opening of `verify_progression_game.gd` after finding the relevant vehicle-exit and ENet harnesses. That progression-game read is the unnecessary source step counted for each. No implementation-guiding incorrect technical assumption was confirmed. The deterministic packet took 21% longer and used 41% more total input tokens and 43% more uncached input tokens.

[Packet A affected guest](screenshots/car-a-braking.png) · [Packet B affected guest](screenshots/car-b-braking.png)

## Conclusion and deployment recommendation

The deterministic packet reached handoff sooner on HUD and solo recovery and took longer on guest-car input. First-attempt success was 2/3 for each retrieval mode. Uncached input decreased on solo recovery and increased on HUD and guest-car input. The observed Codex results support a task-specific speed benefit, with insufficient evidence for a general reduction in work at equal quality.

Keep the production candidate in preview. Before deploying, repeat the comparison on additional held-out cases, vary the order within pairs, record reviewer time separately from agent handoff, and track cached and uncached input side by side. Require the frozen checks where a prompt risks an interpretation gap. For HUD, specify that the hint stays visible with the menu open and test the waypoint against a changed position while solo physics is stopped. For multiplayer, keep the existing timeout mechanism as the primary source anchor and ask for a targeted host-and-two-guest turn, recovery and re-entry check. For recovery, point to the existing backup flag and rotation verifier so the agent can limit the patch to the entry notice.

The [completed scorecard](scorecard.csv) records all six sessions. Local raw traces and first patches are retained by arm identifier, and correction times are blank because no correction rounds took place.

Repository startup used the root `AGENTS.md`, architecture and AI/team workflow guides at pinned `9097d610`, with the GitHub report branch based on fetched `main`. The Python launcher alias could not run the bootstrap. The reviewer ran the bootstrap and exact HUD function lookup with a local embedded Python interpreter and used targeted source reads and live GitHub issue, PR and file-list queries. PR #79 contains the candidate and frozen materials. Related drafts #71, #72 and #78 cover retrieval experiments, and #62 covers Kilo results. The Codex report adds a separate paired trial. The game patches, test data and raw traces stayed in their local worktrees.
