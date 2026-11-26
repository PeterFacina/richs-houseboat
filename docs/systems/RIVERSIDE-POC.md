# Riverside marina visual proof of concept

Issue #132 tests a stylized Canadian riverside direction in the existing Deep River Marina. The experiment is **off by default**. Launch the real game with `godot --path godot-cove -- --riverside-poc`; omit that user argument to retain the original look. This flag is local to the client and does not change saved state or multiplayer messages. The repository continues to use GL Compatibility by default.

## Investigation and implementation

The original marina uses surveyed tree positions but presents nearby crowns mostly through foliage cards. The terrain, sky, water, and dock materials already have substantial shader logic. Mowing relies on the original `park_grass` MultiMesh and exact indices in `grass_transforms`; changing its instance order would break cut and regrow behavior. These source relationships, rather than a terrain or physics defect, explain the limited visual density and set the boundary for this change.

The opt-in profile adds curated CC0 Quaternius tree meshes at surveyed marina canopy positions, local shrubs and flowers, and chunked procedural grass clumps. Natural ground cover avoids the mowing routes, paths, docks, playground sand, and pavilion. A separate blade batch follows each existing mowable tuft's index so trimming and regrowth remain tied to gameplay state. The graphics presets control the distance of added batches. The opt-in sky palette/clouds, mapped marina water, ground, and timber use the existing day cycle and water shaders. The regional map and water physics are unchanged. The merged weather system applies after the Riverside daytime palette; storm cloud coverage suppresses the added cloud layer and rainfall softens the Riverside water colour treatment. Shader and asset provenance is in [the asset manifest](../../godot-cove/third_party/quaternius_nature/MANIFEST.md).

The experiment is geographically focused near the pavilion. Iteration 2 terrain colour fades from 155 to 195 m and mapped water from 175 to 280 m. Sky and lighting are shared world systems and switch when the local camera crosses a 240 m radius; this can produce a visible transition and warrants human review. The tree models are a visual treatment of surveyed positions, not a precise species survey.

## Reproducible visual checks

Run `godot --path godot-cove --rendering-method gl_compatibility --script res://tests/capture_riverside.gd -- --benchmark --capture-dir=../docs/riverside-evidence/baseline` for the original, then add `--riverside-poc` and use the `experimental` directory. The script fixes the camera from the marina pavilion coordinates in the checked-out layout, uses the same FOV and day-cycle stages for both profiles, and sets Balanced at 1920 × 1080. It writes eight PNGs per profile: public wharf, marina park, wide meadow, inland ridge, elevated marina, boat viewpoint, golden hour, and night marina. These are actual runtime screenshots; the capture script is in the repository. The initial five screenshot pairs are in [riverside-evidence](../riverside-evidence/).

For 720p Performance pass `--preset=performance --capture-resolution=720` after `--`. The capture script temporarily disables a locally saved fullscreen preference and sets the window to 1280 × 720; both the script's earlier resize and Godot's startup `--resolution` option were overridden by that preference. Check the `CAPTURE` dimensions printed in the log. For each view, the script samples 300 frames after a short settle, reports median and 95th percentile wall time between rendered frames and draw calls, then checks mower index identity, cut, regrow, and profile deactivation outside the marina. This is a single stationary-camera run, not the requested three 30-second moving samples; it includes desktop scheduling and can show outliers. It does not provide a separate GPU timer or measure VRAM. See the draft PR for the measured results and test gaps.

The final local 1080p Balanced run was repeated on the branch rebased onto `f7cc233`. It used Godot 4.7.2, OpenGL Compatibility 3.3, NVIDIA GTX 1050, driver 582.66, and the same saved VSync preference for both profiles. Values below are median / p95 milliseconds; draw calls are original → profile. An earlier pass showed a boat-view median over 20% slower; after removing redundant water/cloud noise samples, a fresh matched run showed a 5.3% median increase there. The large p95 variation still calls for moving-camera playtesting.

| View | Original | Riverside | Draw calls |
| --- | ---: | ---: | ---: |
| Public wharf | 19.11 / 44.83 | 19.36 / 40.86 | 3968 → 4005 |
| Marina park | 13.25 / 26.50 | 13.71 / 31.36 | 2829 → 2889 |
| Boat viewpoint | 16.53 / 36.39 | 17.41 / 45.05 | 4230 → 4268 |
| Golden hour | 22.31 / 54.89 | 23.16 / 56.30 | 5310 → 5371 |
| Night marina | 18.32 / 44.64 | 19.02 / 47.81 | 4105 → 4157 |

The matched 720p Performance pass used the same engine, renderer, and GPU, but was recorded against the task's original base (`a9ff38b`) before weather PR #127 merged. It is retained as an indicative lower-preset comparison; the 1080p Balanced pair was repeated after the rebase. Values are again median / p95 milliseconds. VSync remained enabled from the local preference, so this is a frame pacing comparison rather than an uncapped GPU throughput test.

| View | Original | Riverside | Draw calls |
| --- | ---: | ---: | ---: |
| Public wharf | 16.64 / 43.47 | 17.22 / 43.59 | 3469 → 3496 |
| Marina park | 9.27 / 21.18 | 9.26 / 23.00 | 1707 → 1746 |
| Boat viewpoint | 14.91 / 36.66 | 15.26 / 39.47 | 3186 → 3211 |
| Golden hour | 19.95 / 55.72 | 20.66 / 51.90 | 4771 → 4809 |
| Night marina | 17.21 / 40.78 | 17.12 / 43.03 | 3806 → 3837 |

The isolated world load and shader compile were successful. The run reported pre-existing warnings about `Image.load_from_file` for project textures, which appeared in both original and experimental captures. The experimental pass reported no script or shader errors and all four targeted mowing/profile checks returned `true`.

## Iteration 2: grass and autumn

The first grass pass sampled only an approximately 87 × 50 m rectangle, discarded 48% of points before terrain checks, and stopped rendering at 78 m on Balanced. That caused the showcase patches seen in playtesting. The terrain shader sampled the existing grass photograph for brightness but replaced local ground with a largely uniform green tint. The second pass samples a deterministic circular area within 178 m of the pavilion, keeps eligible points on a 0.55 m grid, and batches clumps in 16 m MultiMeshes. It tests the actual marina apron and riverbank path images, the surveyed marina approach, launch, tennis court and building polygons, shoreline, docks, playground sand, pavilion, and mowing route polygons before placement. Each clump uses a small curved, tapered blade mesh with world-coherent shader wind and varied size, angle, and colour. Grass stays spatially complete on every preset; its blade height fades out at the preset distance rather than truncating an arbitrary portion of each MultiMesh. Preset distances are 55, 72, and 118 m. The terrain uses the existing grass photograph's colour as well as its detail, broad procedural variation, soil flecks, and the original ground normal map beneath the grass. Land surface masks remain in effect.

The surveyed Quaternius tree geometry remains in place. A deterministic, species-weighted palette adds green, golden birch, amber, muted red, and copper crowns among the evergreens. Small procedural leaf clusters sit under deciduous trees away from roads, paths, and mowing routes. The original `grass_transforms` and `park_grass` order remain intact; decorative clumps do not enter mowable polygons, while each nearby original mowable index controls its corresponding scaled blade clump. Water shaders and water physics are unchanged in this iteration.

The visual method follows the terrain tint plus grass filling approach shown in the [Genshin Impact GDC presentation](https://media.gdcvault.com/GDC%2B2021/2021GDC%2B_%2BHaoyu%2BCai%2B_%2Bpresentation%2Bfile.pdf). [Godot's MultiMesh guidance](https://docs.godotengine.org/en/4.5/tutorials/performance/using_multimesh.html) recommends spatial separation because a MultiMesh culls as one object. Its [API documentation](https://docs.godotengine.org/en/4.5/classes/class_multimesh.html) also explains that `visible_instance_count` shows the first N instances, which caused hard rectangular density cuts in the prior layout. We inspected Poly Haven's [CC0 texture library and license](https://polyhaven.com/license); the existing grass photograph was a closer match for a green early-autumn meadow once its colour was used directly, so this iteration adds no new downloaded texture.

Matched 1920 × 1080 Balanced screenshots for eight fixed camera views are in [iteration2/before](../riverside-evidence/iteration2/before/) and [iteration2/after](../riverside-evidence/iteration2/after/). The before checkout is the first Riverside profile with the same merged main changes, including PR #140's river waves and wakes. The capture script prints candidate, accepted, masked, mowing, and chunk counts. The final iteration placed 93,020 decorative clumps across 183 chunks within the 178 m experiment area, compared with the prior small rectangle. It excluded 10,977 candidates using paving and path masks and 1,334 candidates using mowing polygons; other candidates failed road, building, shore, dock, height, or playground checks.

The matched 1920 × 1080 Balanced pass used Godot 4.7.2, GL Compatibility, NVIDIA GTX 1050, and the same saved VSync preference in both runs. Each view has 300 stationary frames after settling. Values are median / p95 milliseconds, followed by draw calls.

| View | Iteration 1 | Iteration 2 | Draw calls |
| --- | ---: | ---: | ---: |
| Public wharf | 18.42 / 46.80 | 18.68 / 49.62 | 4005 → 4022 |
| Marina park | 13.80 / 36.09 | 14.01 / 33.54 | 2889 → 2916 |
| Wide meadow | 25.58 / 43.45 | 29.30 / 48.47 | 3049 → 3143 |
| Inland ridge | 20.44 / 54.68 | 21.02 / 60.04 | 5484 → 5563 |
| Elevated marina | 19.59 / 51.88 | 19.80 / 50.49 | 4547 → 4571 |
| Boat viewpoint | 18.19 / 47.71 | 17.28 / 40.96 | 4265 → 4309 |
| Golden hour | 22.41 / 56.54 | 24.20 / 52.88 | 5367 → 5388 |
| Night marina | 18.75 / 47.01 | 18.57 / 45.47 | 4158 → 4185 |

The wide meadow is the grass-heavy case and rose 14.5% in median frame time. These are wall-clock frame intervals with VSync and desktop scheduling; they are not isolated GPU timings. The final run had no script or shader errors. Mowing index equality, cut, regrow, and profile deactivation checks all returned true. The existing `Image.load_from_file` warnings appeared in both profiles.

At 1280 × 720 Performance, the same wide meadow view measured 13.66 / 35.18 ms for iteration 1 and 16.25 / 39.96 ms for iteration 2, a 19.0% median increase; draw calls rose from 2640 to 2716. The printed capture dimensions confirmed 1280 × 720 despite the saved fullscreen preference. Only the wide meadow was sampled at this preset; [the 720p image pair](../riverside-evidence/iteration2/) is retained separately from the 1080p set. Moving-camera performance, GPU timer/VRAM, integrated GPU, and Scenic remain unmeasured.

The headless `verify_gameplay_polish.gd` run passed with `--riverside-poc` after merging main. Its scripted checks covered weather transitions and persistence, camera occlusion, storm and shoreline wave exposure, fishing casts and bobbers, swimming entry, multiple wakes, steering, anchors, dock lines, and a real ENet late join with live synchronization. This is automated coverage of those systems, not a manual playthrough.

## Approved grass: world coverage

The `--riverside-poc` profile uses the approved 200 blades/m² GodotGrass-derived mesh and shader in the world streamer. The prior marina-only placement remains available with `--riverside-grass-prototype` for comparison. Blade geometry, height, width, colour, wind and shader are shared with the approved prototype. World grass is placed in 8 m MultiMesh chunks with deterministic nested detail levels and the existing graphics preset distance controls. Only chunks around the camera are resident; crossing a chunk boundary updates the desired set and builds pending chunks within a per-frame CPU budget. The grass surface is conservatively classified in 1 m cells: clear natural cells reuse terrain corner heights, mixed boundaries test each blade, and fully excluded cells emit none. Uploading a chunk's transforms is spread over frames. Fast travel prioritizes close cells, uses medium-detail cover while full detail builds, and gives the streamer a slightly larger CPU budget. The original indexed mowable cover remains separate, so trimming and regrowth keep their gameplay mapping.

`riverside_grass_surface.gd` is the single placement authority for world grass. It uses surveyed terrain heights, slope and shoreline clearance, road spans and sidewalk edge profiles, accepted driveway routes, building wall polygons, the same geographical surface images used by the terrain (downtown, marina, Swisha, Brockhouse, riverbank and Lamure), surveyed park and Brockhouse walkways, marina and Lamure access paths, civic parking and construction areas, dock footprints, and mowing polygons. It checks the blade's nearby footprint and wind reach as well as its root against constructed surfaces and water. The Riverside riverbank reeds now consult the road classifier too. Missing required surface images disable world grass instead of placing it on unknown terrain. Keep new paved materials and structures registered here when the map expands.

For representative Compatibility screenshots, run `godot --path godot-cove --rendering-method gl_compatibility --script res://tests/capture_riverside.gd -- --riverside-poc --capture-clear-weather --capture-resolution=720 --view=wide_meadow,residential,downtown,roadside,gravel_driveway,lamure_beach,forest_trail,riverbank --capture-dir=res://../docs/riverside-evidence/world-grass`. The capture waits for all desired chunks at each camera. Add `--stream-benchmark` for a scripted moving camera at 2 and 15 m/s over 300 frames per speed and view. This measures rendering plus CPU scheduling on the test computer; it is not a vehicle control or multiplayer playtest. The [world-grass evidence](../riverside-evidence/world-grass/) contains the actual runtime PNGs. The default, non-opt-in game remains as before.

The final Godot 4.7.2 GL Compatibility run sampled 64 distinct road centers, 64 accepted driveway centers, and the riverbank road/path transition; all were rejected by the grass classifier. It sampled 2,120 rendered blades at the roadside and 1,675 at the riverbank after chunk loading; none overlapped an excluded surface. The screenshots show clear asphalt, sidewalks, gravel path, driveway, parking and Lamure sand. Mowing index identity, visual cut, regrowth and profile deactivation still passed. The capture reported no script or shader errors; existing image-load warnings remained.

The road-following moving camera is a **remaining limitation**. At nominal 2 m/s, both roadside and riverbank had all close chunks ready at the endpoint. At nominal 15 m/s on actual road spans, roadside had 6 of 7 close chunks without full detail (4 with medium-detail fallback), and riverbank had 4 of 7 (4 with fallback). The endpoint PNGs visibly show underfilled roadside lawns. On this GTX 1050 Compatibility run, roadside frame median/p95 was 29.90/70.14 ms and riverbank was 20.23/48.81 ms during the driving samples; grass update median/p95 was 6.19/9.69 ms and 5.92/10.47 ms respectively. The 300 frame script advances nominal distance at 60 Hz and records wall-clock frame intervals with VSync and desktop scheduling, so these figures are indicative rather than GPU timings or a manual vehicle test. Fast-travel coverage and frame pacing need human review before broader approval. GPU timer/VRAM, integrated GPU and manual vehicle or multiplayer runs were not measured in this pass.

## Review limits

The proof of concept requires a human pass for visual quality, transition smoothness while travelling across the marina boundary, water near/far seam during boating, gameplay access around decorative objects, host/guest play, and night navigation. Manual driving, docking, fishing, fueling, saves, a full day/night cycle, and host/guest play remain open. The Compatibility renderer and an NVIDIA GTX 1050 were used for the visual run; Forward+ and integrated GPU remain unmeasured. The CC0 Standard archive does not include the requested complete species range, so the selected vegetation palette is deliberately narrower.
