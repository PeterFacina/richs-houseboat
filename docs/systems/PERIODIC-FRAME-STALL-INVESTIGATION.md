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
