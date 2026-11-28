# Mesh-resource visual comparison

Both images use the deterministic 1280 × 720 marina profiler camera, Performance graphics, identical weather and game state.

- `baseline.png`: fresh process with `--no-box-mesh-cache`.
- `optimized.png`: fresh process with production box-mesh sharing enabled.

Visual inspection found equivalent geometry, materials, placement, lighting and geographical detail. The FPS counter differs because it is live telemetry.
