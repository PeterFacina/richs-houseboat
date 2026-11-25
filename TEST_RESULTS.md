# Test results

## Court availability and boat controls follow-up

A focused Godot 4.7.2 scene check passed on Windows. It opened tennis during an accepted quest, returned Rich to the yard, untied both Princecraft lines, took the helm, checked throttle retention and neutral, lowered and raised the anchor, and tied the lines again to earn quest credit. The restored houseboat also spawned with both lines rigged. This follow-up used a headless solo fixture.

## Big Rich restoration and tennis integration

Godot 4.7.2 on Windows, with fresh local test profiles. The integration started at `9097d61` and was updated to `5313409` after the road and park changes landed. It uses the tennis implementation in PR #81 and the restoration from playtest commit `3528f7d`. The new roads, park grading, HUD layout and shared game theme were retained.

| Check | Result |
| --- | --- |
| Restoration story | Passed all eight quests, both marina return paths, powered travel, repairs, launch, cabin access, ownership, recruitment and upgrades. Parking and the full-route catch events used fixtures. |
| Tennis and NPC roles | Passed graphical checks for the quest offer, Notebook, shared score HUD, focused match entry, a returned serve, a first-to-seven result, gear restoration on exit, and Rich switching between court, yard and companion duties. Court placement and the remainder of the match used scripted inputs and steps. |
| Four-player localhost | Passed one host and three guests, including two simultaneous repairs, loans, reconnect, rewards, launch, ownership and upgrade replication. The test staged the intervening quest milestones. |
| Saves and existing gameplay | Legacy and prototype saves reloaded. Solo slots, ledger recovery, progression rules, ENet progression and helm handoff, town contracts, vehicle exits and warehouse checks passed. |

Tennis retains its solo rules. The four-player harness logged ENet send errors as guests exited after completing the checks. Separate-machine co-op and the full restoration runtime with an unscripted player remain unmeasured.

## Earlier baseline tests

Godot 4.7.2 on Windows, headless, with isolated temporary APPDATA paths. The source project imported successfully.

| Check | Result |
| --- | --- |
| `verify_progression.gd` | Passed. XP thresholds, points, duplicate events, prerequisites, caps and catalog. |
| `verify_progression_game.gd` | Passed. Legacy save, skill purchases, travel, mowing completion and XP, fish discovery and journal persistence. |
| `verify_progression_network.gd` | Passed. ENet host with two loopback guests, purchase isolation and reconnect. |
| `verify_town_contracts.gd` | Passed. Checked 19 signs and 2,509 trail samples. |
| `verify_warehouse_game.gd` | Passed. Purchase, placement, collision, production, sale and persistence. |
| `verify_ledger_recovery.gd` | Passed. Recovery from malformed JSON, valid fish salvage, preservation of previous save, and resumed rotation. |

## Follow-up checks

- Exported the Windows preset as a PCK and launched it with Godot from an isolated directory. The packaged title ran for 20 frames. The gameplay and town contract suites passed from exported data. Source scene runs still emit direct-image warnings, while the corresponding packaged runs loaded those assets successfully.
- The updated gameplay suite passed a reference comparison between indexed mowing and the full grass scan for the exercised route. It also verified the recorded payout and rejection of another payment for the same day.
- `verify_vehicle_exit.gd` passed level ground, sloped ground and no-ground physics fixtures.
- The updated ENet suite passed on loopback with two guests, including steering input, captain disconnect, helm handoff, and progression on reconnect.

Standalone Windows executable, live movement and vehicle handling, real-network sessions, live casting and HUD legibility, economy pacing, and GPU profiling remain open. The headless runs did not measure rendering frame rate.

## Final mowing navigation

- The Godot gameplay suite passed with the final road trail to the lawn and back to the Public Works parking bay. It checked that the route reaches the lawn waypoint, that the way back is labeled for parking, and that parking and dismounting switches the waypoint to Shannon.
- The same suite verified uncut-grass retargeting, repeated deck passes, the lawn boundary node, and payout. In-game visual readability and the new cutting-load sound still need a playtest.
