# Riverside marina visual proof of concept

Issue #132 tests a stylized Canadian riverside direction in the existing Deep River Marina. The experiment is **off by default**. Launch the real game with `godot --path godot-cove -- --riverside-poc`; omit that user argument to retain the original look. This flag is local to the client and does not change saved state or multiplayer messages. The repository continues to use GL Compatibility by default.

## Investigation and implementation

The original marina uses surveyed tree positions but presents nearby crowns mostly through foliage cards. The terrain, sky, water, and dock materials already have substantial shader logic. Mowing relies on the original `park_grass` MultiMesh and exact indices in `grass_transforms`; changing its instance order would break cut and regrow behavior. These source relationships, rather than a terrain or physics defect, explain the limited visual density and set the boundary for this change.

The opt-in profile adds curated CC0 Quaternius tree meshes at surveyed marina canopy positions, local shrubs and flowers, and chunked procedural grass clumps. Natural ground cover avoids the mowing routes, paths, docks, playground sand, and pavilion. A separate blade batch follows each existing mowable tuft's index so trimming and regrowth remain tied to gameplay state. The graphics presets control the distance of added batches. The opt-in sky palette/clouds, mapped marina water, ground, and timber use the existing day cycle and water shaders. The regional map and water physics are unchanged. The merged weather system applies after the Riverside daytime palette; storm cloud coverage suppresses the added cloud layer and rainfall softens the Riverside water colour treatment. Shader and asset provenance is in [the asset manifest](../../godot-cove/third_party/quaternius_nature/MANIFEST.md).

The experiment is geographically focused near the pavilion. Iteration 2 terrain colour fades from 155 to 195 m and mapped water from 175 to 280 m. Sky and lighting are shared world systems and switch when the local camera crosses a 240 m radius; this can produce a visible transition and warrants human review. The tree models are a visual treatment of surveyed positions, not a precise species survey.

## Reproducible visual checks

Run `godot --path godot-cove --rendering-method gl_compatibility --script res://tests/capture_riverside.gd -- --benchmark --capture-dir=../docs/riverside-evidence/baseline` for the original, then add `--riverside-poc` and use the `experimental` directory. The script fixes the camera from the marina pavilion coordinates in the checked-out layout, uses the same FOV and day-cycle stages for both profiles, and sets Balanced at 1920 × 1080. It writes five PNGs per profile: public wharf, marina park, boat viewpoint, golden hour, and night marina. These are actual runtime screenshots; the capture script is in the repository. The screenshot pairs are in [riverside-evidence](../riverside-evidence/).

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

Matched 1920 × 1080 Balanced screenshots for eight fixed camera views are in [iteration2/before](../riverside-evidence/iteration2/before/) and [iteration2/after](../riverside-evidence/iteration2/after/). The capture script prints candidate, accepted, masked, mowing, and chunk counts. The matched benchmark results and remaining playtest gaps are recorded below.

## Review limits

The proof of concept requires a human pass for visual quality, transition smoothness while travelling across the marina boundary, water near/far seam during boating, gameplay access around decorative objects, host/guest play, and night navigation. The capture does not exercise vehicle controls, docking, fishing, fueling, saves, or a full day/night cycle. The Compatibility renderer and an NVIDIA GTX 1050 were used for the visual run; Forward+ and integrated GPU remain unmeasured. The CC0 Standard archive does not include the requested complete species range, so the selected vegetation palette is deliberately narrower.
