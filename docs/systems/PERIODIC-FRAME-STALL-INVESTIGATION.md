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
