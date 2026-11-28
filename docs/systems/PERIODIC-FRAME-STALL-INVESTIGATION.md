# Periodic frame-stall investigation

Date: 2026-11-27  
Branch: `peter/resident-simulation`  
Engine: Godot 4.7.2 stable, Compatibility renderer  
GPU: NVIDIA GeForce GTX 1050 4 GB

## Current conclusion

Do not optimize resident scheduling on the present evidence. In fresh-process stationary runs, resident work averages roughly 0.11–0.15 ms per physics tick and peaks at 2.4–3.5 ms. The recurring 80–100 ms stalls remain when resident and gameplay sections are inexpensive.

The initiating periodic stall is render/driver-side. Physics catch-up amplifies it, but does not create it:

- live 720p: 16.74 ms median, 68.42 ms p95, 93.02 ms p99, 104.46 ms worst;
- diagnostic one-physics-step cap: 17.01/47.14/60.19/82.48 ms;
- entire game subtree disabled: 11.75/30.04/44.40/60.89 ms;
- game subtree and render loop disabled: 0.024/0.043/0.081/0.462 ms.

With normal physics, slow clusters recur about every 64 rendered frames and execute two to six physics steps per rendered frame. No instrumented `game_world` section exceeded 6.25 ms in the representative run. Disabling Performance monitor collection did not remove the cadence.

## Resident measurements

Three stationary fresh-process baselines recorded resident maxima of 2.42–3.15 ms and total resident cost of 48.2–57.8 ms across roughly 439 ticks. Two valid walking stress runs recorded resident maxima of 2.48 and 3.21 ms even while whole-frame worst cases exceeded 700 ms. The marina and provisional walking route had no near-resident simulations, so active-near-player behavioral validation remains required, but these results reject residents as the source of the stationary periodic tail.

## Resolution control

The profiler now changes both OS-window size and root viewport content scale. A corrected fresh 960x540 run produced 16.48 ms median, 64.83 ms p95, 86.72 ms p99 and 107.16 ms worst. This single run is not an accepted improvement over 1280x720, and the periodic cadence was unchanged. Pixel fill is therefore unlikely to be the primary cause. Three matched runs per condition are still required before quoting a scaling ratio.

## Next high-value work

1. Capture a marina frame with RenderDoc or equivalent and attribute color, depth, shadow and canvas submissions.
2. Run matched fresh-process render A/B tests that reduce submission count without changing resident, grass, regional, or tree production assets.
3. Identify whether the one-second renderer burst correlates with driver queue synchronization using finer GPU tooling; Godot does not expose trustworthy per-frame GPU duration in Compatibility mode.
4. Retain the physics-step cap only as a diagnostic. It slows simulation and is not a production fix.
5. Validate active residents near multiple players before making any resident scheduling change.

No production optimization is included yet.

## Renderer comparison update

Temporary command-line overrides leave the project configuration unchanged. Three fresh-process Vulkan Mobile runs at the same 1280x720 marina camera produced:

| Run | Median | p95 | p99 | Worst | 1% low |
| --- | ---: | ---: | ---: | ---: | ---: |
| Mobile 1 (cold) | 10.12 ms | 24.68 ms | 38.49 ms | 45.90 ms | 23.71 FPS |
| Mobile 2 | 9.74 ms | 29.88 ms | 51.40 ms | 64.41 ms | 17.92 FPS |
| Mobile 3 | 8.51 ms | 24.56 ms | 42.16 ms | 54.15 ms | 21.57 FPS |

The periodic signature remains, but is materially smaller than Compatibility. A cold Forward+ run produced 14.74/29.43/60.15/76.37 ms median/p95/p99/worst. Forward+ repeats and same-camera captures remain required. Mobile warned that realtime sky radiance is clamped to 256; visual equivalence is not yet accepted.

Exclusive fullscreen Compatibility produced 14.97/46.82/84.95/121.04 ms in its first run. It improved median and p95 but did not eliminate the cadence or worst tail, so window mode is a contributing factor rather than the root fix.

Render-stage signals show slow frames contain both a long `frame_pre_draw` to `frame_post_draw` interval and a long post-draw to next-process interval. This supports rendering/presentation synchronization as the initiating mechanism.

Teammates can run `tools\Run Rendering Benchmark.cmd -Renderer mobile` (or `compatibility` / `forward_plus`). The launcher records OS, CPU, memory, display count, NVIDIA GPU/driver when available, exact renderer output, frame distribution and every detected stall to a timestamped text file under `benchmark-results`. Teammate results are not yet available and no cross-hardware claim is made.

## Scene-complexity controls

Manual Vulkan Mobile playtesting still exhibits the recurring stutter despite approximately 45 FPS and acceptable graphics. A second teammate reports similar stutter on stronger, not-yet-characterized hardware. Mobile remains a throughput improvement, not a stutter solution.

`tests/profile_render_controls.gd` isolates presentation from full-world rendering over 720 measured frames:

| Renderer / control | Median | p95 | p99 | Worst | Frames over 33 ms |
| --- | ---: | ---: | ---: | ---: | ---: |
| Compatibility empty | 0.40 ms | 0.63 ms | 0.84 ms | 1.18 ms | 0 |
| Compatibility 2,600 static MeshInstances | 3.90 ms | 9.48 ms | 14.44 ms | 24.82 ms | 0 |
| Mobile empty | 0.51 ms | 3.09 ms | 3.81 ms | 4.80 ms | 0 |
| Mobile 2,600 static MeshInstances | 2.37 ms | 7.46 ms | 11.83 ms | 15.26 ms | 0 |

The static stress scene uses 2,600 individually submitted visible objects with a shared mesh/material and no shadows. The cadence therefore requires full-world rendering state; it is not an unconditional engine/Windows presentation event or draw count alone.

Fresh-process full-world controls also reject two likely periodic systems:

- static quality sky instead of realtime sky: 16.34/57.76/98.30/131.13 ms median/p95/p99/worst;
- all shadow-casting lights disabled: 14.63/52.60/82.89/120.53 ms.

Both retain the clustered cadence. The next bisection should isolate water/ground shaders, texture/resource diversity and top-level world visibility. Renderer switching, static sky and shadow removal are not production fixes.

## Mesh-resource reproduction

The initiating render stall can now be reproduced without the game. The decisive variable is mesh/buffer resource diversity, not renderer selection or any single visual effect.

The controlled scene holds object count (2,600), geometry (816 triangles per object, approximately 2.12 million submitted triangles), material, camera and disabled shadows constant. The only difference is whether all objects reference one mesh resource or each object owns an equivalent mesh resource:

| Compatibility condition | Runs | Median range | p99 range | Worst range | >33 ms stalls per 720 frames |
| --- | ---: | ---: | ---: | ---: | ---: |
| One shared mesh | 3 | 3.43–3.51 ms | 15.17–18.77 ms | 23.82–26.21 ms | 0 / 0 / 0 |
| 2,600 unique meshes | 3 | 7.72–7.82 ms | 27.80–31.57 ms | 43.91–56.17 ms | 5 / 4 / 1 |

The unique-mesh stalls occur inside `frame_pre_draw` to `frame_post_draw`, not in the post-present interval. This is a minimal reproduction of the initiating renderer stall without gameplay, physics, water, sky, shadows, texture diversity or heterogeneous materials.

Vulkan Mobile reduces the same unique-mesh control to 4.73 ms median, 16.28 ms p99 and 29.32 ms worst. Its equivalent heavy shared-mesh control was 2.34/11.42/15.71 ms. Mobile therefore reduces the cost but does not remove the resource-diversity tail, consistent with the manual playtest.

Full-world controls support the same diagnosis:

- hiding all three water surfaces leaves 16.30/57.04/96.13/125.60 ms median/p95/p99/worst;
- overriding 20,103 enabled geometry instances with one untextured material leaves 14.42/56.61/92.55/98.57 ms;
- reducing the camera far plane from 2.4 km to 300 m reduces draw calls from about 2,620 to 1,222 and p99 to 63.98 ms, but preserves the cadence;
- the heavy shared-mesh control exceeds the real view's approximately 1.8 million primitives without reproducing a stall.

The root cause class is excessive independently allocated/submitted mesh buffers in the procedural world. Their render-server/driver processing periodically blocks frame submission; the subsequent physics catch-up turns the initiating render wait into a longer visible cluster. The evidence does not yet distinguish an engine render-server traversal/command-generation limit from a graphics-driver buffer-management/queue synchronization limit. Windows Performance Recorder exposes GPU and Desktop Composition profiles on this machine, but starting the GPU profile requires the unavailable system-performance tracing privilege (`0xc5585011`), so no ETW GPU queue trace is claimed.

Production work should now inventory the procedural builders that emit single-use meshes, then test spatially bounded reuse or combination on the largest contributors. Any candidate must retain geographic accuracy and culling granularity, and must be compared in three fresh-process full-world runs. No production mesh merge is included in this diagnostic commit.

## Production box-mesh deduplication

The full-world inventory reports 18,982 enabled geometry nodes, 9,275 unique mesh resources and 9,232 single-use mesh resources. The largest coarse owners are Deep River roads (1,528 unique resources), Public Works (1,420), Deep River buildings (835), Deep River marina (802) and River Campaign (799). Deeper ownership attributes 595 to Champlain streetscape, 432 to street-name signs, 274 to floating docks, and repeated sets of 70 to each Public Works bay.

A narrow street-sign primitive cache was rejected and reverted. Three Compatibility pairs showed no repeatable p99 or stall-frequency improvement, demonstrating that removing a few hundred resources is below the useful threshold in this world.

The accepted prototype instead caches immutable `BoxMesh` resources by exact dimensions in the shared `scenery.gd` constructor. Each node retains its own transform, material override, visibility, shadows and parent; collision shapes are untouched. `--no-box-mesh-cache` provides a profiler-only fresh-process baseline. This reduces unique mesh resources from 9,275 to 4,493 (51.6%) and single-use resources from 9,232 to 3,687 (60.1%) without changing geometry-node or surface counts.

Three alternating fresh-process runs per condition at 1280 × 720 produced these median-of-run results:

| Renderer / metric | Baseline | Shared boxes | Change |
| --- | ---: | ---: | ---: |
| Compatibility median | 16.62 ms | 13.79 ms | −17.0% |
| Compatibility p95 | 63.96 ms | 55.76 ms | −12.8% |
| Compatibility p99 | 91.45 ms | 82.95 ms | −9.3% |
| Compatibility worst | 104.84 ms | 89.75 ms | −14.4% |
| Compatibility 1% low | 9.99 FPS | 11.61 FPS | +16.2% |
| Compatibility >33 ms stalls | 22/run | 19/run | −13.6% |
| Compatibility RAM | 1003.98 MB | 990.49 MB | −13.49 MB |
| Mobile median | 9.67 ms | 6.70 ms | −30.7% |
| Mobile p95 | 35.00 ms | 27.96 ms | −20.1% |
| Mobile p99 | 62.53 ms | 50.03 ms | −20.0% |
| Mobile worst | 73.82 ms | 73.90 ms | neutral |
| Mobile 1% low | 15.38 FPS | 15.92 FPS | +3.5% |
| Mobile >33 ms stalls | 16/run | 10/run | −37.5% |
| Mobile RAM | 1095.63 MB | 1070.11 MB | −25.52 MB |

Compatibility recorded 66 total stalls in baseline runs and 58 with sharing; Mobile recorded 46 and 31. Draw calls and primitive counts were unchanged apart from normal frame-state variation. Median startup changed from 53.22 to 52.88 seconds in Compatibility and 62.98 to 61.59 seconds in Mobile. Compatibility's coarse VRAM monitor varied upward by about 13 MB while Mobile fell about 3.6 MB; these renderer counters are recorded but not treated as reliable allocation proof.

The [baseline](../mesh-resource-evidence/baseline.png) and [shared-mesh](../mesh-resource-evidence/optimized.png) captures show the same camera, geometry, materials, time and weather; visual inspection found no difference outside the FPS counter. The headless gameplay-polish suite passed weather, persistence, camera/teleport, fishing, swimming, boat controls, ENet late join, live replication and guest-authority checks.

This is a meaningful production improvement, not a full resolution. The periodic cadence remains, especially in Compatibility, and the evidence still does not distinguish Godot render-server work from driver buffer management. Further work should target the remaining high-resource procedural families and require the same inventory reduction plus matched tail improvement before expansion.

## Live gameplay incident recorder

Manual playtesting confirms the recurring gameplay stutter remains after box-mesh deduplication. Treat mesh-resource diversity as a contributing cost, not a conclusive root cause. No further production optimization is justified until live incidents identify a specific initiating operation.

Run `tools\Run Live Performance Recorder.cmd` for Compatibility or add `-Renderer mobile` for Vulkan Mobile. During actual play, press **F9 immediately after observing a stutter**. The opt-in recorder retains approximately 600 preceding frames and 300 following frames, then writes an incident JSON file under `benchmark-results/live-<timestamp>`. Repeated F9 presses during the post window extend it and are retained as separate marker timestamps.

Each frame records wall time, render pre/post synchronization duration, post-render wait, physics-step count, Godot process/physics monitors, gameplay section deltas, draw/object/primitive counters, resource and node counts, static/video memory, player and camera movement, game mode, simulation clock, and recorder overhead. A companion CSV samples process CPU/memory/I/O plus total physical-disk throughput on the same Unix-millisecond timeline.

Godot 4.7.2 does not expose per-frame GPU execution duration, driver queue wait reasons, pipeline compilation events, named resource allocation/free events, or per-frame disk attribution in this renderer. Session metadata records these as unavailable. Analysis must identify the first long frame in each incident and treat later multi-step physics frames as catch-up unless their script section cost independently precedes the render wait.

### First marked gameplay session

The first manual session captured three F9 incidents in normal `foot` gameplay. The marker is necessarily after the perceived event, so analysis correlated each marker with the nearest preceding contiguous slow-frame cluster rather than assuming the marked frame itself stalled:

| Incident | Initiating cluster | Marker lag | First abnormal frame | Peak frame | State |
| --- | --- | ---: | --- | --- | --- |
| 1 | frames 9846–9848 | 86 frames | 60.43 ms: 28.40 ms render sync, 31.61 ms post-render wait, 2 physics steps | 222.84 ms: 144.13 ms render sync, 75.35 ms post-render wait, 8 steps | stationary player and camera |
| 2 | frames 10452–10456 | 7–11 frames | 54.61 ms: 27.45 ms render sync, 24.52 ms post-render wait, 2 steps | 91.15 ms: 34.30 ms render sync, 55.03 ms post-render wait, 4 steps | walking |
| 3 | frames 10739–10744 | 74–79 frames | 43.04 ms: 21.23 ms render sync, 19.94 ms post-render wait, 2 steps | 79.58 ms: 42.64 ms render sync, 34.07 ms post-render wait, 5 steps | walking |

The common initiating signature is time spent across the rendering/presentation boundary while only two physics steps occur. Physics then expands to 4–8 catch-up steps on later frames. No resident, gameplay, interaction, locomotion, campaign, environment or presentation script section consistently precedes the first wait; resident processing remains small. Movement and camera input are not required because incident 1 begins while both are stationary.

Resource count is unchanged on the initiating frames and static-memory changes are small. One unrelated slow frame added two resources, but that is not shared by the marked incidents. Periodic resource construction/destruction therefore has no positive live correlation yet. The available external sampler also finds no common disk signature: samples nearest the three markers reported respectively 0, 26.4 and 0.06 MB/s total disk throughput, with no process-read growth. Its approximately 1.6-second sampling interval is too coarse to rule out a very short external event, but it rules out sustained game-process reads as the common cause.

Two frames must be excluded from gameplay diagnosis. Frames 10233 and 10763 immediately follow completion of incident-file serialization and each records an approximately 120 ms pause plus an approximately 2.72 MB static-memory decrease. These are recorder-induced file-write/cleanup artifacts, not instances of the original game stall.

This session identifies the initiating subsystem boundary but not the exact lower-level operation. The live incidents support a render-server/driver/presentation synchronization wait followed by physics catch-up; they do not yet distinguish render-server command generation, driver queue/buffer management, or presentation synchronization. A production optimization remains unjustified. The smallest next diagnostic step is lower-level timing at that boundary (ETW/PresentMon or an instrumented engine build where tracing privilege is available), not another content optimization.

## Elevated rendering-boundary trace

Windows includes WPR and exposes `CPU`, `GPU`, and `DesktopComposition` profiles on this computer. WPA, GPUView and PresentMon are not currently on `PATH`. A non-elevated `wpr -start GPU -filemode` reproduces error `0xc5585011` (`Failed to enable the policy to profile system performance`). Do not change the game or install another Godot build to address this; run the trace controller elevated.

1. Start the live recorder normally with `tools\Run Live Performance Recorder.cmd`. Use `-Renderer mobile` in PowerShell only when intentionally tracing Mobile.
2. Double-click `tools\Capture Render Boundary Trace.cmd` and approve the Windows administrator prompt. Its exact WPR start command is `wpr -start CPU -start GPU -start DesktopComposition -filemode`.
3. Keep the trace shorter than 60 seconds. Play until a stutter, press F9 in the game, return to the elevated window and press Enter. This emits `wpr -marker RH_STUTTER_N` and records the wall-clock correlation. Repeat if useful, then type `STOP`.
4. The exact stop command is `wpr -stop <output>\render-boundary.etl "Richs Houseboat rendering-boundary gameplay stalls"`. The script immediately renames the result to `render-boundary.etl.trace` and writes `markers.csv` plus `capture.log` under `%LOCALAPPDATA%\RichsHouseboat\traces\etl-*`. Rename it back to `.etl` only when opening it in WPA. Raw `.etl` files disappeared after both initial captures, including one outside OneDrive; the neutral extension preserves the third capture and the log records WPR's exact exit behavior. Both matching F9 JSON files were retained.

Equivalent manual elevated PowerShell commands are:

```powershell
whoami /priv | findstr /i SeSystemProfilePrivilege
wpr -start CPU -start GPU -start DesktopComposition -filemode
wpr -marker RH_STUTTER_1
wpr -stop "C:\Temp\richs-houseboat-render.etl" "Richs Houseboat rendering-boundary gameplay stalls"
```

If the elevated start still returns `0xc5585011`, open `secpol.msc`, go to **Local Policies → User Rights Assignment → Profile system performance**, add the local **Administrators** group, then sign out and back in before retrying. Do not leave a failed or abandoned session active: `wpr -cancel` stops it without saving.

Open the ETL in Windows Performance Analyzer and align `RH_STUTTER_N` with the F9 JSON Unix timestamp. Inspect, in order: CPU Usage (Precise) by process/thread and wait reason; D3D/Graphics queue packet submission and execution; GPU hardware queue occupancy; Present history and displayed duration; DWM/compositor activity; and disk/page-fault activity. The decisive interpretations are:

- a busy Godot render thread before submission with an idle GPU indicates command generation/submission cost;
- a sleeping Godot thread with a saturated or long-running GPU queue indicates GPU back-pressure;
- completed GPU work followed by a blocked Present and DWM/VSync delay indicates presentation/composition;
- a render wait first, followed by multiple physics ticks, confirms physics as catch-up rather than initiation.

GPUView is optional if WPA exposes the required queues. If it is required, install only the **Windows Performance Toolkit** feature from the matching Windows ADK, then run its `Log.cmd` from an administrator command prompt immediately before the reproduction and run it again within 30–60 seconds to create `Merged.etl`. PresentMon is also optional; when available, target the actual Godot process and record QPC time so its per-present CPU busy/wait, GPU time and display latency can be aligned with ETW.

### Capture-pipeline validation status

Do not request another manual gameplay capture until `tools\Test Render Trace Pipeline.ps1` passes end to end. The automated test starts CPU/GPU/Desktop Composition tracing, emits a marker, stops WPR, checks size and SHA-256, renames the trace, parses it with explicit `tracerpt -l`, and verifies that both the retained trace and non-empty CSV survive. Every native command and exit code is written before the result JSON.

The two manual WPR attempts did not satisfy that test. Both saved the F9 JSON and marker CSV, and the first ETL was briefly observed at 3,145,728 bytes, but the raw ETLs subsequently disappeared. The second attempt used `%LOCALAPPDATA%`, ruling out OneDrive as the common explanation. Neither attempt logged WPR's stop output, so the exact deletion actor is unproven; do not attribute it to OneDrive, Defender or the game. Non-elevated automated probes fail before trace creation with `0xc5585011` for GPU and `0x80070005` for Desktop Composition. The full pipeline therefore remains unvalidated and no ETW conclusion is claimed.

PresentMon 2.6.0 was evaluated as the fallback using Intel's signed portable x64 release (valid Intel Authenticode signature; SHA-256 `B2A706BC6AD475749E3B7E3409263AA1E6906D45BDCF993F6DBC0F660188F1AF`). Its automated five-second capture also fails to start with access denied: PresentMon requires elevation or membership in **Performance Log Users** on this computer. Once privilege is available, its CSV can distinguish CPU busy/wait, time in Present, GPU latency/time/busy/wait, display latency, displayed duration and present mode. It cannot provide CPU thread stacks, named render-server functions, arbitrary resource operations or full DWM/GPU packet timelines, so it is a useful boundary classifier but not a replacement for WPR/GPUView.

### VSync and frame-cap controls

The recorder launcher accepts isolated diagnostic controls and records their effective values in session metadata. It does not change project defaults:

```powershell
& '.\tools\Run Live Performance Recorder.ps1' -Renderer compatibility -VSync disabled -MaxFps 0
& '.\tools\Run Live Performance Recorder.ps1' -Renderer compatibility -VSync disabled -MaxFps 60
& '.\tools\Run Live Performance Recorder.ps1' -Renderer compatibility -VSync enabled  -MaxFps 0
& '.\tools\Run Live Performance Recorder.ps1' -Renderer compatibility -VSync enabled  -MaxFps 60
```

Use at least three fresh-process matched runs per promising condition, with the same camera, resolution and play path. Compare stall frequency and p95/p99, not only median FPS. The uncapped/VSync-off condition tests queue pressure; the 60 FPS cap tests whether pacing before Present prevents queue saturation; VSync-on distinguishes compositor/display blocking. These controls are diagnostic only and must not be treated as a production fix without ETW evidence.
