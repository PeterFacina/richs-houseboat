# Riverside grass streaming architecture

## Scope and cause

This branch starts at `origin/main` `c9f523b` (the merged PR #135). The owner approved the grass appearance. No blade mesh, shader, density, height, palette, wind, geographic classifier, or mowing rules were changed.

The baseline spent 4,679 ms generating grass during the scripted tennis walk, including 2,269 ms classifying tiles, while bulk MultiMesh upload consumed 33 ms. Grass generation on the main thread was the immediate bottleneck. The geographic classifier depends on live world state and is not safe to move unchanged to a worker. Instead, the game now saves exact eligible candidate heights and finished deterministic transform buffers, then decompresses and validates them on a bounded worker. The main thread still creates MultiMesh resources and installs scene nodes.

## Implementation

- Each cache record contains all candidate eligibility/elevation samples and the finished packed transforms for one 8 m chunk and detail level. ZSTD compression and SHA-256 detect damaged data. Records are keyed by a versioned source signature that includes grass code, world scene code, and geographic source files. A source change invalidates the old version conservatively.
- A single worker performs file I/O, compression, decompression, and validation. Its queue is limited to four jobs/results. A stale queued load can be cancelled. The user cache is capped at 256 MiB and 4,096 files across versions; up to 16 pending saves can wait in memory. The existing 64-chunk in-memory tile cache remains bounded.
- A 25.9 MiB bundle of 690 cache records prepares spawn, the tennis approach/lawn, and the surveyed road route on a first install. Its eight bake viewpoints are listed in `tests/bake_riverside_grass.gd`. The bundle is included by the export preset. New locations are generated through the unchanged surface classifier, cached for later visits, and use the existing lower-detail grass while full detail is prepared.
- Loading extends 8 m beyond the visual radius, unloading has a further 12 m margin, and movement predicts up to 48 m ahead. At most 32 full-detail batches are held ahead and installed when their cells enter the near zone. During fast travel the existing medium tier remains visible until the player slows. The initial loading screen waits for nearby full-detail grass, with a 30 s cap, before hiding. These limits are for preparation and retention; close-range grass appearance parameters are unchanged.
- Local tile samples and packed-buffer writes avoid repeated dictionary lookups and array appends on cache misses. These source changes were also explored in draft PR #146, which is not merged; reviewers should reconcile that overlap before merging either PR.

## Matched benchmark

Godot 4.7.2, GL Compatibility, 1280×720, Performance preset, clear weather, local GTX 1050. The scripted test holds at the tennis approach for 600 frames, walks the same 1,200-frame route to the tennis lawn, waits 600 frames, then traverses the surveyed road at nominal 5 and 15 m/s for 300 frames each. The optimized comparison temporarily moved the user cache aside and loaded only the shipped bundle, representing a first install. There was one run of each condition; frame times are indicative, not a 60 FPS claim. `tests/profile_grass_architecture.gd` reproduces the route.

| Measure | Main baseline | This branch, bundled first install |
| --- | ---: | ---: |
| Nearby full chunks at tennis start | 0/16 | 16/16 |
| Tennis arrival full / lower-detail / empty | 0 / 10 / 6 | 14 / 4 / 0 |
| Tennis after 10 s full chunks | 0/16 | 17/17 |
| Tennis frame median / p95 | 18.85 / 36.65 ms | 18.12 / 35.69 ms |
| Tennis grass generation / tile classification | 4,679 / 2,269 ms | 3,382 / 1,740 ms |
| Tennis MultiMesh upload | 33 / 60 completions ms | 35 / 256 completions ms |
| Road at 5 m/s, full / lower-detail / empty | 0 / 9 / 7 | 15 / 1 / 0 |
| Road at 5 m/s, frame median / p95 | 29.40 / 54.35 ms | 28.12 / 58.44 ms |
| Road at 15 m/s, full / lower-detail / empty | 0 / 3 / 4 | 5 / 7 / 0 |
| Road at 15 m/s, frame median / p95 | 30.53 / 52.67 ms | 28.83 / 54.27 ms |

The game loading-screen preload took 3.32 s in the bundled run and reported nearby grass ready before the screen cleared. The optimized test reported about 1.0–1.1 GiB process RAM. The changed near-zone counts during driving reflect the new lookahead and radius and are not an equal chunk denominator. The high p95 frame times show that this architecture change does not solve the local GPU/frame-rate limit. The baseline and final screenshots show the same tennis arrival camera: [baseline](../riverside-evidence/grass-architecture/baseline/arrival.png), [optimized](../riverside-evidence/grass-architecture/final-bundled/arrival.png). Settled views: [baseline](../riverside-evidence/grass-architecture/baseline/settled.png), [optimized](../riverside-evidence/grass-architecture/final-bundled/settled.png).

## Verification and limits

- Worker roundtrip: exact cached buffer bytes restored (`GRASS_CACHE_ROUNDTRIP passed=true`).
- Surface checks: 64/64 road centers and 64/64 gravel driveway centers excluded; 243,431/243,431 roadside and 264,345/264,345 driveway grass instances passed the existing full instance eligibility check.
- Mowing index, cut, and regrowth checks passed. Cached grass placement remains deterministic; mowing is applied after batch installation.
- The Windows export pack built successfully and included all 690 baked records. A 180-frame standard-mode startup exited without script errors.
- The benchmark is a scripted camera/world traversal, not vehicle physics, multiplayer, or a manual playtest. Actual 1050 Ti and RTX 2070-class hardware were unavailable. Only the measured first-install areas are baked. Unbaked areas still require main-thread geographic classification and may show lower-detail grass before full detail; widespread zero-pop-in coverage is not established. Multiplayer host/guest and packaged-game playtests are still needed in review.
