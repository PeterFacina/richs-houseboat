# Riverside Phase 2 streaming experiment

Draft review record. Based on `origin/main` at `c9f523b` (PR #135 integrated), using Godot 4.7.2 GL Compatibility. The existing Riverside mode, standard graphics mode, grass mesh, shader, colours, wind, close density, geographic exclusions and mowing are unchanged. The test machine reports an NVIDIA GTX 1050. An older game window remained open during both benchmark worktrees, so the numbers include that shared background load.

## Diagnosis and changes

The PR #135 profile found chunk generation on the CPU to dominate grass uploads. A fresh 720p Performance stationary profile of this base spent 1,333 ms in generation, including 335 ms in tile classification, versus 8.6 ms in upload across a 300-frame sample. The frame interval was 25.01 ms median and 82.44 ms p95; 17 chunks completed and 154 waited. The surface eligibility function checks surveyed roads, pavement paint, occupied areas, water and slope before accepting a blade. These checks are required to keep grass off paved surfaces.

The branch's separate cold profile spent 1,275 ms generating, including 314 ms in tile classification, and 6.2 ms uploading; 15 chunks completed and 182 waited. The frame interval was 23.47 / 79.53 ms median / p95. It recorded zero edge-height cache hits during cold startup, as expected. Different chunk counts and desktop variability prevent treating that small stationary difference as a speedup.

This branch makes a small streaming experiment:

- Load candidates within a circular visual radius plus 4 m, and retain prepared active chunks for another 12 m before unloading. The existing visual distance still culls them.
- Estimate travel direction and speed from the moving viewpoint, look up to 36 m forward and prioritize medium-detail chunks within 24 m of that predicted position. Nearby full detail still has top priority. Existing three distance tiers and the 64-chunk return cache remain.
- Reuse exact sampled edge heights across detail tiers while the corresponding chunk remains active or in the bounded return cache. Preallocate the existing MultiMesh transform buffer before filling it; upload remains one bulk operation per chunk. This does not change blade transforms or geographic decisions.

A prototype moved deterministic transform writing to `WorkerThreadPool`, after keeping geographic eligibility and scene/resource updates on the main thread. It did not materially improve the 15 m/s road frame interval (28.19 ms baseline versus 27.47 ms prototype median; p95 remained about 59 ms). The main-thread surface checks remained dominant, so the prototype was removed. No background workers ship in this branch. An offline static cache would need a versioned geography key, invalidation rules and a realistic storage budget; it is not implemented here.

## Matched movement benchmarks

Both worktrees ran the same capture script, route, clear weather, GL Compatibility renderer, camera height and 300 fixed movement samples per speed. The base is detached at `c9f523b`; the branch used the same capture harness. Road is a 1280 × 720 Performance window. The water-facing camera route uses a 1920 × 1080 Balanced window and captures, while Godot reports a 1280 × 720 logical viewport. `boat` below is a camera movement proxy, not boat physics. Results are single runs and include startup/import and desktop scheduling noise. `update` is the grass update call; `frame` is wall-clock interval. Values are median / p95 in milliseconds.

| View and nominal speed | Base update | Branch update | Base frame | Branch frame | Base / branch active chunks at endpoint |
| --- | ---: | ---: | ---: | ---: | ---: |
| Road 2 m/s | 0.016 / 2.183 | 0.017 / 2.875 | 16.713 / 35.641 | 16.922 / 35.330 | 166 / 190 |
| Road 5 m/s | 1.657 / 4.225 | 1.668 / 4.042 | 18.075 / 43.311 | 18.206 / 37.382 | 151 / 196 |
| Road 15 m/s | 3.095 / 5.516 | 3.018 / 5.926 | 27.468 / 58.608 | 27.578 / 56.518 | 78 / 119 |
| Road 25 m/s | 2.962 / 5.328 | 3.070 / 5.786 | 28.245 / 52.474 | 27.541 / 56.516 | 32 / 43 |
| Road return, 25 m/s | 3.006 / 5.195 | 2.895 / 5.488 | 15.593 / 31.177 | 15.697 / 35.045 | 64 / 96 |
| Water view 15 m/s | 3.094 / 8.087 | 2.929 / 6.483 | 18.922 / 41.405 | 17.749 / 38.763 | 169 / 241 |
| Water view 25 m/s | 2.984 / 6.969 | 3.082 / 8.383 | 20.129 / 36.401 | 20.956 / 47.312 | 52 / 101 |

The branch prepared more chunks around and ahead of the moving camera, with roughly 9–14 MB more measured RAM on the road endpoints and less than 1 MB more measured VRAM. At 15 m/s road the branch had 7 missing among 12 sampled near/ahead cells, compared with 7/7 on base; its five additional ready cells are ahead-zone cells. This is a coverage gain without a convincing road frame-time improvement. At 25 m/s, near cells and return travel still show missing grass. Cold roadside near coverage took 478 frames on base and 492 on branch. Neither worktree recovered all nearby chunks within 120 frames after teleport. No stable 60 FPS or 30 FPS claim follows from these results.

The screenshots show the same camera viewpoints: [base settled road](../riverside-evidence/phase2/baseline-road-720/roadside.png), [branch settled road](../riverside-evidence/phase2/after-road-720/roadside.png), [base driving road](../riverside-evidence/phase2/baseline-road-720/roadside_drive_end.png), [branch driving road](../riverside-evidence/phase2/after-road-720/roadside_drive_end.png), [base water view](../riverside-evidence/phase2/baseline-boat-1080/from_boat_drive_end.png), [branch water view](../riverside-evidence/phase2/after-boat-1080/from_boat_drive_end.png). These are runtime captures; they also show the remaining sparse travel coverage.

## Rendering and verification

The independent rendering audit uses separate interventions for building batches, tree batches, the near water plane and directional shadows with grass hidden. The Balanced window was 1920 × 1080, with a 1280 × 720 logical viewport, 125 m shadow range and VSync off. A 300-frame sample per intervention reported:

| Render sample | Median / p95 frame ms | Median draws | Median primitives |
| --- | ---: | ---: | ---: |
| Base scene, grass hidden | 29.76 / 48.80 | 3,618 | 2.50 million |
| Buildings hidden | 32.02 / 51.56 | 3,535 | 2.49 million |
| Trees hidden | 17.97 / 33.42 | 3,375 | 1.52 million |
| Near water hidden | 31.28 / 49.15 | 3,616 | 2.47 million |
| Directional shadow range zero | 30.36 / 47.81 | 2,330 | 2.47 million |

The interventions overlap and run sequentially, so differences are directional, not additive. Trees were the strongest rendered-scene cost in this view; eliminating shadows lowered draw calls but did not improve the measured median frame interval. The PR #135 [streaming profile](RIVERSIDE-STREAMING-PROFILE.md) records the earlier 720p Performance audit. Source inspection confirms regional tree/building visibility batches, a preset-dependent shadow range and a distinct near water plane; this branch changes none of those systems. Godot's Compatibility renderer did not expose a reliable GPU frame timer in this harness.

The 720p road capture rejected all 64 sampled road centers and 64 driveway centers. All 1,393 sampled settled roadside blade origins passed the original geographic eligibility function. A separate exhaustive pass checked 229,893 settled and 136,722 driving-end blade origins, with zero rejected placements. The route's mowing index, cut and regrow assertions passed. Standard mode launched and completed a 300-frame Performance smoke profile with no world-grass chunks and no script errors. The camera routes cover standing at startup, slow movement, nominal sprint speed, driving, higher speed, reverse return and teleport. They do not simulate actual vehicle or boat physics. Multiplayer host/guest, saves, low-end integrated GPU, dedicated team GPUs and human pop-in assessment remain untested on this branch.

This experiment needs human review before merge. More prefetch consumes memory and does not solve late grass on the slow GPU. The most promising future work is a carefully versioned, bounded cache of immutable geographic classifications or a pure-data worker path after separating those checks from live world objects. Neither is justified by these measurements without a separate design and comparison.

## Owner playtest follow-up: visible cold loading

The owner approved the grass appearance but reported watching a previously empty field fill over several seconds on a GeForce GTX 1050 Ti. The local test adapter identifies a GTX 1050, so these measurements do not certify the owner's hardware or 60 FPS. The existing normal gameplay build budget is 1.5 ms per update. A roadside 720p Performance cold capture from this PR's previous commit prepared only 72/185 target chunks after 1,800 frames (41.52 s), with near full detail unfinished. That reproduces the long visible fill.

The focused CPU change uses a local packed-buffer reference and local loop state instead of repeated dictionary access for every transform component. Adjacent tiles now reuse exact conservative geographic samples, and a fully conservative tile avoids a duplicate regular pass. There is no change to the mesh, shader, height, width, density, colour, wind, placement seed or exclusion function. With the same normal budget, the roadside cold capture reached 130/185 chunks after 1,800 frames (39.04 s); near full detail was still unfinished. With a 20 ms capture-only budget, full preparation fell from 21.44 to 15.46 s. Both settled captures contained exactly 185 chunks and 229,893 blades and produced the identical MultiMesh buffer hash `1905392881`.

The game already had a loading screen. Riverside now uses it to prepare the initial camera's target grass chunks with a 50 ms build budget before the loading layer closes, capped at 30 s, then restores the normal 1.5 ms gameplay budget. On a Compatibility Balanced startup, all 305/305 target chunks were ready before gameplay became visible. Grass preloading took 19.11 s and total scene startup took 80.57 s on the local PC. A 20 ms loading-only trial took 24.62 s of grass preloading and 85.13 s total. This removes the initial chunk-by-chunk reveal at the cost of a longer initial load; it does not precompute every later destination or solve fast-travel pop-in.

A separate 300-frame cold live Performance profile moved from 27.92 / 91.29 ms median / p95 frame interval to 25.43 / 85.16 ms. Grass generation fell from 1,722 ms over 21 completed chunks to 1,230 ms over 22 completed chunks; tile classification fell from 522 to 210 ms. The different completed counts, background game windows and desktop scheduling make these directional results. A scripted 15 m/s road pass measured 2.90 / 5.10 ms median / p95 grass update time, but 28.29 / 65.38 ms frame interval; it does **not** meet stable 60 FPS. Exhaustive checks accepted all 229,893 settled roadside and 140,459 driving-end blade origins under the original geographic eligibility rules; mowing cut and regrow checks passed.

After the final loading screen cleared, a 300-frame stationary sample at the marina measured **25.44 / 73.81 ms** median / p95 at the saved 1920 × 1080 Balanced setting (305 active chunks). Switching the same loaded scene to a 1280 × 720 Performance window measured **17.16 / 59.10 ms** (266 active chunks), roughly 58.3 FPS at the median with large spikes. An earlier 20 ms preload trial measured 25.29 / 82.39 ms Balanced and 16.76 / 59.15 ms Performance, illustrating run-to-run variation. A separate standard-mode Performance smoke sample without Riverside grass measured 17.57 / 57.97 ms. Neither mode establishes stable 60 FPS on this test PC, and the tested GTX 1050 is not the owner's GTX 1050 Ti. A wider rendering and frame-pacing change would need its own measured visual review; this grass fix does not claim to solve that cost.

Still required before claiming the 60 FPS target: a repeatable benchmark on the owner's actual GTX 1050 Ti, including their resolution, graphics preset and reported field location; sustained driving and return travel; and host/guest playtests. The 30 s loading cap can still leave some grass streaming on larger presets or slower machines. This PR remains a draft for human visual and load-time review.
