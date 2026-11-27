# Local rendering and frame-pacing investigation

Date: 2026-11-27  
Branch: `codex/world-architecture-audit`  
Engine: Godot 4.7.2 stable, Compatibility renderer  
Measured GPU: NVIDIA GeForce GTX 1050 4 GB, driver 582.66

## Decision

Do not merge a production optimization from this investigation yet. The evidence rejects regionalization, resident-avatar prewarming, resolution reduction, and simple tree-part removal as solutions to the severe frame-time tail. The next production candidate should target the resident physics/path workload and must be validated with the deterministic profiler before review.

The provisional world direction remains independent regions with minimal internal streaming. No streaming or transfer implementation is included here.

## Active mode

Every new run now reports the camera mode, graphics preset, renderer, Riverside flag, and presence of the Riverside world-grass node. The measured game was:

- original game mode;
- Riverside disabled (`riverside_enabled=false`);
- no Riverside world-grass node;
- Performance graphics, 2x MSAA, 2.4 km camera range and 72 m directional-shadow range;
- Compatibility renderer at 1280 × 720, VSync disabled.

Therefore these results do not measure PR #146 or PR #147 grass work and do not justify resuming it.

## Deterministic profiling harness

`tests/profile_world_runtime.gd` now supports:

- percentile and 1% low reporting;
- per-spike frame, process, physics, draw, object, primitive, camera and mode correlation;
- stationary, walking, driving and boating trajectories;
- focused crown, trunk, tree-shadow, shadow-distance and resolution experiments;
- game-loop isolation and resident-prewarm A/B modes;
- architecture inventory and regional-removal A/B modes.

`game_world.gd` has an opt-in `--performance-trace` mode that times interaction, locomotion, environment, general gameplay, campaign, residents and presentation. It has no effect unless the benchmark flag is supplied.

## Repeated stationary baseline

Warm rendered stationary runs consistently reproduced the issue:

| Run | Median | p95 | p99 | Worst | 1% low | Draws |
| --- | ---: | ---: | ---: | ---: | ---: | ---: |
| Architecture audit representative | 16.99 ms | 61.32 ms | 99.92 ms | 112.95 ms | 9.6 FPS | 2,623–2,645 |
| Focused run | 16.91 ms | 66.50 ms | 115.41 ms | 126.15 ms | 8.3 FPS | 2,623 |
| Tail diagnostic | 17.07 ms | 63.61 ms | 91.43 ms | 118.82 ms | 9.8 FPS | 2,625 |
| Route-suite baseline | 17.40 ms | 56.70 ms | 101.39 ms | 119.21 ms | 9.0 FPS | 2,625 |

The spike clusters recur approximately every 59–64 rendered frames. Most begin without a meaningful draw/object change. This is not characteristic of a one-time shader compilation event.

## Subsystem isolation

Matched 360-frame diagnostic phases produced:

| Phase | Median | p95 | p99 | 1% low | Interpretation |
| --- | ---: | ---: | ---: | ---: | --- |
| Live | 17.07 ms | 63.61 ms | 91.43 ms | 9.8 FPS | Baseline |
| HUD hidden | 16.02 ms | 62.69 ms | 97.10 ms | 9.7 FPS | HUD is not the tail source |
| `_process` off | 16.90 ms | 69.71 ms | 110.39 ms | 8.4 FPS | Render-process loop is not the tail source |
| `_physics_process` off | 13.12 ms | 35.42 ms | 44.33 ms | 19.5 FPS | Main physics/gameplay loop is a major contributor |
| Both game loops off | 13.15 ms | 40.05 ms | 50.47 ms | 17.9 FPS | Rendering/submission still has a substantial tail |

The Godot aggregate process/physics monitors update too coarsely to attribute individual frames reliably. Wall-clock section timing inside the game loop is the stronger evidence.

### Physics-section trace

The slowest post-load physics ticks included:

- 131.6 ms total: 83.1 ms residents, 36.1 ms general gameplay;
- 122.8 ms total: 106.5 ms residents;
- 58.5 ms total: 27.0 ms residents, 22.9 ms gameplay;
- 35.1 ms total: 31.6 ms residents.

The resident system performs path planning, repeated physics shape casts/rays, blocked-link checks, display activation and avatar animation from the main physics loop. This is the best demonstrated script-side target. General fishing/gameplay work is the secondary script target.

Resident avatar prewarming was tested and rejected: it changed 16.78/64.38/93.07 ms median/p95/p99 to 17.17/73.54/106.37 ms. It shifts work and raises resident cost; it does not solve the periodic simulation load.

## Moving routes

The first deterministic movement pass deliberately drives fixed repeatable coordinates rather than accepting human input variance:

| Route | Median | p95 | p99 | Draws | Status |
| --- | ---: | ---: | ---: | ---: | --- |
| Stationary marina | 17.40 ms | 56.70 ms | 101.39 ms | 2,625 | Valid |
| Walking marina/town | 22.50 ms | 94.71 ms | 132.07 ms | 3,830 | Valid as stress route; reveals dense town cost |
| Driving town | 29.01 ms | 102.52 ms | 151.74 ms | 3,610 | Diagnostic only; part of the provisional line crosses invalid elevation |
| Boating river | 7.70 ms | 33.99 ms | 71.61 ms | 406 | Diagnostic only; route exposed an existing fish-finder typed-array error |

Walking confirms that local content/culling transitions are materially more expensive than the original marina view. The driving and boating paths must be replaced by authored waypoints before they become acceptance gates. Their failures are retained in the harness and report rather than hidden.

## Local vegetation experiments

The initial experiments were intentionally destructive visibility tests, not production proposals:

| Experiment | Median | p95 | p99 | Primitive change | Result |
| --- | ---: | ---: | ---: | ---: | --- |
| Full stationary | 16.91 ms | 66.50 ms | 115.41 ms | baseline | Fails target |
| Hide crown groups | 16.72 ms | 58.11 ms | 100.67 ms | about -20% | Small median gain; tail still catastrophic |
| Hide trunk groups | 16.97 ms | 72.92 ms | 101.06 ms | about -25% | Rejected |
| Disable tree shadows | 17.01 ms | 70.11 ms | 113.07 ms | about -20% | Rejected in this pass |

The sequential shadow-distance and resolution phases became contaminated by visibility-state settling and are not accepted as matched evidence. They remain useful for improving the harness, but not for a production decision.

No tree geometry, impostor, material, or batch-dimension production change was implemented because the hide tests did not demonstrate enough tail improvement to justify asset changes. Those experiments now rank below resident scheduling and draw-submission attribution.

## Resolution scaling

The uncontaminated evidence is qualitative: lowering output resolution did not remove the periodic spike cadence. In the contaminated focused sequence, 540p remained approximately 18.2 ms median / 73.0 ms p95 / 107.8 ms p99. A fresh-process resolution matrix is still required before quoting a GPU scaling ratio.

Godot Compatibility did not expose a trustworthy standalone GPU-frame-time metric in these runs. GPU utilization, GPU clock, VRAM bandwidth, driver queue depth, per-pass GPU duration and hardware counters are explicitly unavailable. The GTX 1050 used here is also not the target GTX 1050 Ti.

## Why the marina uses about 2,600 draws

The renderer reports roughly 3,050 rendered objects and 2,625 draw calls in the stationary view—close to one submitted draw per visible object. Hiding all crown groups removed only about 56 draws while removing hundreds of thousands of primitives. Hiding the HUD removed about 67 draws. Regional deletion removed no meaningful draws.

This establishes that the count is not dominated by a few high-instance vegetation MultiMeshes. It is dominated by many locally visible individual geometry/UI submissions, with additional shadow passes and multi-surface materials. Precise per-pass attribution is unavailable through Godot's Compatibility performance monitors; RenderDoc or an equivalent graphics capture is required to name every pass.

Static merging should therefore use spatially bounded cells, shared materials and explicit maximum bounds. A global town merge would damage culling. Candidate cells should be measured around 32–64 m for street furniture/details and retained only when a fresh-process A/B reduces draws and p95 without increasing visible primitives excessively. No merge is included in this PR.

## Ranked next experiments

1. **Resident scheduling and physics-query budget** — highest demonstrated impact. Measure route preparation, per-resident `simulate`, `observed`, `advance`, and `display` independently; cap planning/query work per tick while keeping nearby residents responsive.
2. **Fresh-process moving-route baselines using authored road/river waypoints** — required acceptance evidence.
3. **Render capture of the marina** — attribute Compatibility color, depth, shadow and canvas passes precisely.
4. **Bounded static-geometry merge prototype** — one 32–64 m marina cell only; stop unless draw and p95 gains are material.
5. **Fresh-process shadow and resolution matrix** — one variant per process, with screenshots and identical camera/time/weather.
6. **Vegetation geometry/LOD/impostor work** — only after the above. Existing hide tests do not justify spending asset-production time yet.

## Stop rules

- Reject any optimization with less than 5% median improvement and no statistically repeatable p95/p99 gain across at least three matched runs.
- Reject visual changes that do not have same-camera before/after captures.
- Never compare variants after a visibility experiment without rebuilding a fresh process.
- Do not use contaminated driving/boating routes as acceptance evidence.
- Keep every production optimization in a separate PR from this audit/profiler PR.

## Visual comparison status

No production visual change was accepted, so there is no proposed visual delta to approve. The visibility-off experiments are intentionally invalid visual configurations. Future production candidates must add same-camera captures at marina, town walking route and river route before review.
