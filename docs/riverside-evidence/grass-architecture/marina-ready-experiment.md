# Marina ready-buffer experiment

The controlled area is the maximum visible grass radius around the actual marina player spawn at `(17921.57, 12731.43)`. It contains 812 contiguous 8 m cells. All three LOD records are present for every cell, including explicit empty records, so the experiment performs no runtime geographic classification.

## Data

- Compact baseline: 812 marina cells, 21,266,044 bytes.
- Ready buffers: 2,436 records, 420,856,560 bytes uncompressed.
- Non-empty ready records: 1,937.
- Exact ready-versus-compact buffer comparison: 2,436 checked, 0 mismatches.

## Rendered timing

Both runs used the same Balanced graphics setting, bundle-only reads, the real renderer, 210 desired/active chunks, and 226 cache loads.

| Stage | Compact control | Ready buffers |
| --- | ---: | ---: |
| Full preload wall time | 849 ms | 426 ms |
| Disk/read total | 135.470 ms | 263.743 ms |
| Decompression total | 99.505 ms | 0 ms |
| Transform reconstruction total | 544.600 ms | 0 ms |
| Maximum worker queue wait | 675.816 ms | 79.564 ms |
| MultiMesh upload total | 47.126 ms | 81.500 ms |
| Activation total | 2.821 ms | 10.176 ms |
| Runtime geographic generation | 0 ms | 0 ms |
| Median steady FPS | 59.40 | 60.49 |
| P95 steady frame time | 34.885 ms | 35.104 ms |

Queue and result-wait totals are cumulative latency across jobs and are not additive wall-clock stages; the maximum is included to show the scheduling delay experienced by one record.

## Finding

Transform reconstruction was the dominant avoidable bottleneck in the compact format. Compressed ready buffers reduced wall time to 600 ms, but decompression still consumed 179 ms in the rendered run. Storing the exact buffers uncompressed reduced preload to 426 ms, a 2.0x improvement over compact. The remaining floor is raw file I/O plus main-thread MultiMesh upload, not geographic classification or transform reconstruction.

## Correctness

- 224,950 compact instances and 224,950 ready instances were checked against the production surface classifier; both runs reported 0 excluded instances.
- Road center probes passed 64/64 and driveway center probes passed 64/64.
- Mowing cut and regrow passed with both compact and ready buffers using the real renderer.
- The blade mesh, material, density, deterministic position, rotation, and height data are unchanged.
