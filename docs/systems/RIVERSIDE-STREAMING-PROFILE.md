# Riverside grass streaming and renderer profile

This record accompanies draft PR #135. It uses the existing `--riverside-poc` mode and Godot 4.7.2 GL Compatibility. The local adapter reports an NVIDIA GTX 1050; it is not the owner's GTX 1050 Ti or an RTX card. The game was sampled at 1280 × 720, Performance (2.4 km camera far plane, 72 m directional shadow range, 2× MSAA), with VSync disabled. Godot exposed draw, primitive, object, node, RAM and VRAM counters; a reliable GPU frame timer was unavailable in this renderer. Frame intervals are wall-clock measurements and may vary with desktop focus and weather.

## Cause and focused change

The original grass update generated individual blade `Transform3D` objects in the physics loop and uploaded each instance separately. In a 300-frame live sample at the Riverside spawn it spent 3,004 ms generating chunks, including 539 ms classifying surface tiles, and 72 ms uploading. Only 11 chunks completed while 146 waited. Hiding the grass and stopping its update returned the scene to roughly the original game's frame time; keeping loaded grass visible while stopping updates was similarly cheap. Thus preparation, rather than the approved shader or blade draw, was the first bottleneck to address.

The streamer now writes the existing deterministic transforms into a packed MultiMesh buffer and uploads each chunk in one call. It caches tile classifications by cell and detail tier and retains up to 64 recently departed prepared batches for return travel. During fast travel it fills empty near cells with medium detail and defers full density until movement slows. If travel begins during a partial full-detail build, that build is dropped so it cannot consume the coverage budget; its cached tile samples remain available. Already loaded full detail remains visible. The per-frame build budget is 1.5 ms while slow and 2.5 ms while fast. The existing exact full-detail surface check, blade geometry, shader, density, height, width, colours, wind and geographic masks remain in place; the sparse travel tier uses five conservative tile samples plus exact checks at boundaries. Mowing's indexed marina grass is unchanged.

## Measurements

| Test | Median frame | p95 frame | Notes |
| --- | ---: | ---: | --- |
| Original live scene, Performance, before change | 17.58 ms | 70.03 ms | 2,934 draws, 2.01 million primitives, 997.7 MB RAM, 475 MB VRAM |
| Riverside live scene, Performance, before change | 29.99 ms | 117.35 ms | 3,008 draws, 2.07 million primitives, 1,062 MB RAM, 599 MB VRAM; 19 active grass chunks |
| Riverside grass update stopped, loaded grass visible, before change | 17.92 ms | 75.52 ms | Controlled render-only check |
| Riverside live scene, Performance, after change | 20.64 ms | 74.60 ms | 3,012 draws, 1.80 million primitives, 1,050 MB RAM, 597 MB VRAM; 23 active chunks; 16 chunks completed in the sampled interval |

These stationary startup samples were separate runs, so they indicate direction rather than a precise speedup ratio. The updated live grass sample spent 1,228 ms generating, 305 ms on tile classification and 6 ms uploading across its 16 completed chunks. The frame-time p95 still misses the 60 FPS target.

The scripted road course uses 300 fixed-step frames at nominal 2 and 15 m/s. Final Performance results: roadside 15 m/s grass update 2.99/5.31 ms median/p95, frame 25.61/38.63 ms; riverbank 3.36/6.36 ms update and 18.57/37.82 ms frame; gravel driveway 3.01/5.46 ms update and 31.12/77.73 ms frame. At 15 m/s all three courses retained medium-detail grass in some near cells, but none reached full detail in all near cells. Roadside ended with 4 medium-detail fallbacks across 7 near cells, riverbank 5/7, driveway 7/7. The remaining near cells on road courses were not classified as fully ready; the screenshot review did not establish whether every unfilled cell was paved. The drive screenshots still show visibly sparse travel grass. This is an improvement in bounded update work, not a claim that fast-travel coverage or stable 60 FPS is solved.

The earlier PR road benchmark used **Balanced** (4.2 km, 4× MSAA), so its frame times must not be compared directly with the Performance road results above.

## Renderer audit

The Performance spawn had about 26,400 nodes but only 3,493 rendered objects and 3,045 draws with grass hidden. Source confirms regional trees and buildings are grouped into spatial batches with explicit visibility ranges, a 72 m Performance shadow distance, and a separate near water grid. It is therefore inaccurate to attribute the cost to the whole map being drawn at once.

A controlled render-only pass hid one group at a time from the same Performance view: baseline 14.75 ms median; no building batches 13.57 ms; no tree batches 11.64 ms; no near water plane 12.87 ms; no directional shadows 11.97 ms. Shadow removal reduced draws from 3,045 to 2,236. These interventions overlap and are not additive. They identify vegetation and shadows as candidates for a separate, measured renderer change, but do not justify altering their approved appearance in this grass PR. No broad renderer edits were made.

## Verification and limits

Compatibility rendered the selected [roadside](../riverside-evidence/world-grass/streaming-verified/roadside.png), [riverbank](../riverside-evidence/world-grass/streaming-verified/riverbank.png) and [driveway](../riverside-evidence/world-grass/streaming-verified/gravel_driveway.png) views, plus their scripted 15 m/s endpoints. The test rejected all 64 sampled road centers and all 64 sampled driveway centers. It checked 1,218 roadside and 1,104 riverbank rendered blade samples against the original eligibility function with zero excluded placements. A separate exhaustive driveway pass checked all 231,598 settled blade positions and all 67,785 fast-travel endpoint blade positions with zero exclusions violated. Mowing index, cut and regrow checks passed. The full-detail roadside capture matches the approved grass structure and stops at the same surveyed surface boundaries.

The owner manually playtested the game, accepted the remaining late-loading behavior, and approved merging this iteration. Remaining checks: boat and teleport playtesting, repeated return travel, exhaustive validation beyond the driveway route, multiplayer gameplay, integrated GPU and teammate RTX hardware, direct GPU frame timing, export packaging, and a matched same-preset pre/post road run. Additional renderer changes should be separately profiled and reviewed.

## Current main integration

After PR #143 entered `main`, its Riverbank Park pedestrian-edge output and Riverside's grass-exclusion callback were both retained at the shared build call. The isolated town-residents fixture passed its route, blocked-link recovery, evening-return and late-joining ENet guest checks. A visible Compatibility Riverside roadside run loaded 162/162 target chunks, validated 1,218/1,218 sampled blade origins, and passed mowing index, cut and regrow checks. A second game window remained open during this integration run, so its frame times are unsuitable for a performance comparison. The owner accepted the remaining late-loading behavior for this merge; a faster GPU alone is not expected to remove the measured CPU preparation cost.
