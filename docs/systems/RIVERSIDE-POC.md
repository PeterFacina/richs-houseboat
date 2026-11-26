# Riverside marina visual proof of concept

Issue #132 tests a stylized Canadian riverside direction in the existing Deep River Marina. The experiment is **off by default**. Launch the real game with `godot --path godot-cove -- --riverside-poc`; omit that user argument to retain the original look. This flag is local to the client and does not change saved state or multiplayer messages. The repository continues to use GL Compatibility by default.

## Investigation and implementation

The original marina uses surveyed tree positions but presents nearby crowns mostly through foliage cards. The terrain, sky, water, and dock materials already have substantial shader logic. Mowing relies on the original `park_grass` MultiMesh and exact indices in `grass_transforms`; changing its instance order would break cut and regrow behavior. These source relationships, rather than a terrain or physics defect, explain the limited visual density and set the boundary for this change.

The opt-in profile adds curated CC0 Quaternius tree meshes at surveyed marina canopy positions, local shrubs and flowers, and chunked procedural grass clumps. Natural ground cover avoids the mowing routes, paths, docks, playground sand, and pavilion. A separate blade batch follows each existing mowable tuft's index so trimming and regrowth remain tied to gameplay state. The existing graphics presets control the distance and density of added batches. The opt-in sky palette/clouds, mapped marina water, ground, and timber use the existing day cycle and water shaders. The regional map and water physics are unchanged. Shader and asset provenance is in [the asset manifest](../../godot-cove/third_party/quaternius_nature/MANIFEST.md).

The experiment is geographically focused near the pavilion. Terrain colour fades from 125 to 170 m and mapped water from 175 to 280 m. Sky and lighting are shared world systems and switch when the local camera crosses a 240 m radius; this can produce a visible transition and warrants human review. The tree models are a visual treatment of surveyed positions, not a precise species survey.

## Reproducible visual checks

Run `godot --path godot-cove --rendering-method gl_compatibility --script res://tests/capture_riverside.gd -- --benchmark --capture-dir=../docs/riverside-evidence/baseline` for the original, then add `--riverside-poc` and use the `experimental` directory. The script fixes the camera from the marina pavilion coordinates in the checked-out layout, uses the same FOV and day-cycle stages for both profiles, and sets Balanced at 1920 × 1080. It writes five PNGs per profile: public wharf, marina park, boat viewpoint, golden hour, and night marina. These are actual runtime screenshots; the capture script is in the repository. The screenshot pairs are in [riverside-evidence](../riverside-evidence/).

For 720p Performance pass `--preset=performance --capture-resolution=720` after `--`. The capture script temporarily disables a locally saved fullscreen preference and sets the window to 1280 × 720; both the script's earlier resize and Godot's startup `--resolution` option were overridden by that preference. Check the `CAPTURE` dimensions printed in the log. For each view, the script samples 300 frames after a short settle, reports median and 95th percentile wall time between rendered frames and draw calls, then checks mower index identity, cut, regrow, and profile deactivation outside the marina. This is a single stationary-camera run, not the requested three 30-second moving samples; it includes desktop scheduling and can show outliers. It does not provide a separate GPU timer or measure VRAM. See the draft PR for the measured results and test gaps.

The local 1080p Balanced run used Godot 4.7.2, OpenGL Compatibility 3.3, NVIDIA GTX 1050, driver 582.66, and the same saved VSync preference for both profiles. Values below are median / p95 milliseconds; draw calls are original → profile.

| View | Original | Riverside | Draw calls |
| --- | ---: | ---: | ---: |
| Public wharf | 20.86 / 49.67 | 18.02 / 45.52 | 3968 → 4005 |
| Marina park | 12.62 / 27.45 | 12.92 / 34.77 | 2829 → 2889 |
| Boat viewpoint | 15.84 / 39.15 | 17.33 / 33.77 | 4230 → 4268 |
| Golden hour | 21.70 / 44.28 | 23.24 / 45.93 | 5310 → 5371 |
| Night marina | 17.45 / 43.57 | 18.37 / 33.69 | 4105 → 4157 |

The matched 720p Performance pass used the same engine, renderer, and GPU. Values are again median / p95 milliseconds. VSync remained enabled from the local preference, so this is a frame pacing comparison rather than an uncapped GPU throughput test.

| View | Original | Riverside | Draw calls |
| --- | ---: | ---: | ---: |
| Public wharf | 16.64 / 43.47 | 17.22 / 43.59 | 3469 → 3496 |
| Marina park | 9.27 / 21.18 | 9.26 / 23.00 | 1707 → 1746 |
| Boat viewpoint | 14.91 / 36.66 | 15.26 / 39.47 | 3186 → 3211 |
| Golden hour | 19.95 / 55.72 | 20.66 / 51.90 | 4771 → 4809 |
| Night marina | 17.21 / 40.78 | 17.12 / 43.03 | 3806 → 3837 |

The isolated world load and shader compile were successful. The run reported pre-existing warnings about `Image.load_from_file` for project textures, which appeared in both original and experimental captures. The experimental pass reported no script or shader errors and all four targeted mowing/profile checks returned `true`.

## Review limits

The proof of concept requires a human pass for visual quality, transition smoothness while travelling across the marina boundary, water near/far seam during boating, gameplay access around decorative objects, host/guest play, and night navigation. The capture does not exercise vehicle controls, docking, fishing, fueling, saves, or a full day/night cycle. The Compatibility renderer and an NVIDIA GTX 1050 were used for the visual run; Forward+ and integrated GPU remain unmeasured. The CC0 Standard archive does not include the requested complete species range, so the selected vegetation palette is deliberately narrower.
