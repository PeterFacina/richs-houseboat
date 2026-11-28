# Procedural box-mesh caching

This production change is deliberately independent of the unresolved periodic-stutter investigation. It shares immutable `BoxMesh` resources with exactly equal dimensions in `scenery.gd`; nodes retain their transforms, material overrides, visibility, shadows and parents, and collision shapes are untouched. `--no-box-mesh-cache` remains a profiler-only baseline switch.

The full-world inventory measured 18,982 enabled geometry nodes, 9,275 unique mesh resources and 9,232 single-use resources. Exact box sharing reduced unique meshes to 4,493 (−51.6%) and single-use meshes to 3,687 (−60.1%) without changing geometry-node or surface counts.

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

Draw calls and primitive counts were unchanged apart from normal frame-state variation. Median startup changed from 53.22 to 52.88 seconds in Compatibility and 62.98 to 61.59 seconds in Mobile. The existing gameplay-polish suite passed weather, persistence, camera/teleport, fishing, swimming, boat controls, ENet late join, live replication and guest-authority checks.

The [baseline](../mesh-resource-evidence/baseline.png) and [shared-mesh](../mesh-resource-evidence/optimized.png) captures use the same camera, geometry, materials, time and weather; visual inspection found no difference outside live telemetry. This optimization improves throughput and tail latency but does **not** eliminate the recurring gameplay stutter, and this PR makes no root-cause claim.
