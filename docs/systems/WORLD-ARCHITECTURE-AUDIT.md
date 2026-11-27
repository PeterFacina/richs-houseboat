# World architecture and performance audit

Date: 2026-11-27  
Branch: `codex/world-architecture-audit`  
Base: `c9f523baefafface7aa7c46c3aa4513bbea0017f` (`origin/main`)  
Engine: Godot 4.7.2 stable, GL Compatibility, OpenGL 3.3, NVIDIA driver 582.66  
Test GPU: NVIDIA GeForce GTX 1050 4 GB (not the target GTX 1050 Ti)

## Executive conclusion

> **Follow-up status (2026-11-27):** independent regions with minimal internal streaming is accepted as the provisional direction. Immediate implementation is paused in favor of local frame-pacing work. See [Local rendering and frame-pacing investigation](LOCAL-PERFORMANCE-INVESTIGATION.md) and the non-destructive [Deep River region manifest](DEEP-RIVER-REGION-MANIFEST.json).

Build independent regional scenes, beginning with a Deep River region, but do not present regionalization as the 60 FPS fix. The current continuous world constructs far more terrain, collision, and regional vegetation than Deep River needs. Removing wholly out-of-region terrain and regional trees in a runtime proof of concept reduced the node count by 6,618, static memory by about 260 MiB, and reported video memory by about 20 MiB. It did not materially improve the stationary marina median frame time or draw count because Godot already culls most distant content.

The highest-value first implementation is therefore a two-part vertical slice:

1. Extract Deep River into an independently loadable region using a non-destructive manifest and baked source data. This addresses approximately one minute of current world construction, memory, unnecessary collision, and future multiplayer interest management.
2. In the same milestone, profile and reduce the rendering cost that remains inside Deep River, beginning with town vegetation and directional-shadow casters. The sampled marina still renders roughly 2,600 draw calls and 1.6–1.8 million primitives after distant regional content is removed.

Choose architecture **B, independent regions with minimal internal streaming**, for the first production milestone. Do not build a generic World Partition clone yet. Add hierarchical local streaming only after moving route measurements show that a complete Deep River scene cannot meet the memory and frame-pacing budgets.

## Evidence status

### Proven in this audit

- The checked-in map is 559 × 400 coarse height samples at 56 m spacing: **31,248 × 22,344 m**, or about **698.2 km²**. One Godot world unit is treated as one metre (`distance_scale = 1`), with finer 2 m or 4 m patches at destinations.
- Deep River, Swisha, and Chalk River Labs are currently built into one `DeepRiverMap` node. `build_landmarks()` constructs Swisha and three simple CNL buildings in the same scene. All coarse terrain tiles create triangle-mesh collision.
- The proposed Deep River envelope contains all current town building batches. Most removable content is terrain/collision and procedural regional forest, not town buildings.
- Current-main rendered baseline at 1280 × 720 Performance/Compatibility on the GTX 1050 misses stable 60 FPS badly in its tail, despite a near-60 median.
- Removing wholly outside terrain/collision and regional tree batches is a large memory/node reduction but not a meaningful stationary marina FPS improvement.

### Supported by earlier work, not independently reproduced here

- PR #135's controlled hide-one-subsystem tests identified trees and directional shadows as the strongest sampled render costs. Those results are directionally consistent with the present runtime inventory, but the exact hide tests were not rerun in this audit.
- PRs #146 and #147 improve Riverside grass arrival through different, overlapping approaches. Neither demonstrates stable 60 FPS, multiplayer correctness, or a general world architecture. They remain experiments and should not be merged or revived automatically.

### Still unmeasured

- GPU frame time under GL Compatibility. Godot's available monitor did not provide a trustworthy separate Compatibility GPU timer.
- Real walking, vehicle-physics driving, boating, region transfer, return transfer, host, and guest routes on current main.
- Target GTX 1050 Ti hardware, controlled 1080p, Mobile, and Forward+ comparisons.
- Cold OS filesystem cache versus warm cache. The asset import was cold, but the valid rendered samples used an imported project cache.
- The boundary screenshot referenced in the brief was not present with the pasted text. The coordinate proposal below is source-derived and must be visually reconciled with that screenshot before production bake boundaries are approved.

## Repository and pull-request status

The task bootstrap fetched `origin/main` and created an isolated worktree. Current open performance PRs inspected through GitHub and fetched PR refs:

| PR | State at audit | Finding |
| --- | --- | --- |
| [#135](https://github.com/PeterFacina/richs-houseboat/pull/135) | Merged into current main | Riverside visual/world-grass rollout. Explicitly reports that stable 60 FPS and invisible driving loads were not achieved. |
| [#146](https://github.com/PeterFacina/richs-houseboat/pull/146) | Open draft | CPU tile/buffer reuse, loading-screen preparation, stop-time queue priority. Reports 17.16 ms median at 720p Performance in one steady marina run and unresolved pop-in/tails. |
| [#147](https://github.com/PeterFacina/richs-houseboat/pull/147) | Open draft | Versioned baked grass records and worker I/O. Reports better coverage but 18.12 ms tennis median and overlap with #146. |

Recommendation: leave #146 and #147 as evidence branches. Extract reusable lessons—offline deterministic data, integrity/version keys, bounded worker I/O, main-thread rendering-object creation—but do not merge either branch as the foundation of regionalization.

## Current architecture audit

### Construction and lifetime

`game_world.gd` instantiates a single gameplay world. During `DeepRiverMap.build()` the game:

- reads the full coarse elevation and shoreline arrays;
- creates coarse terrain mesh tiles and triangle-mesh collision across the full 31.2 × 22.3 km source extent;
- creates higher-resolution terrain/collision patches for the marina, Swisha, and Lamure;
- procedurally scatters regional forest in every coarse map tile, grouped into approximately 550 m MultiMesh cells;
- builds all roads, walkways, 1,674 source building records, town details, marina, Lamure, Riverbank Park, Brockhouse Way, properties, landmarks, and Swisha;
- creates a full-map far-water mesh and a camera-following 230 m near-water grid;
- sets up gameplay, NPC, quest, vehicle, weather, day-cycle, and multiplayer systems in the same world lifetime.

Rendering and simulation have only partial separation. Graphics batches use visibility ranges and the camera-following water mesh limits local water tessellation, but terrain collision and most constructed nodes remain resident. The opt-in Riverside grass streamer has its own spatial/lifecycle logic; the base regional forest, terrain collision, roads, and town content do not share a general region lifecycle.

### Existing spatial techniques

- Coarse terrain tiles: 44 × 44 height cells; at 56 m spacing a full tile spans up to 2,464 m.
- Detailed terrain patches: the same 44-cell tile scheme at 2 m (marina/Lamure) or 4 m (Swisha).
- Regional forest: generated per coarse terrain tile, then split into about 550 m MultiMesh cells.
- Riverside grass: 8 m chunks, nested LOD, bounded per-frame build budget, fallback detail, and a reuse cache on main.
- Town meshes: spatial batches with visibility ranges; town vegetation has detail/silhouette/stem groups.
- Water: full-map inexpensive far surface plus a camera-following 230 m near grid.

These are useful pieces, but they are subsystem-specific rather than a coherent world ownership model.

### Map coordinates and destination separation

| Feature | Current world coordinate/bounds |
| --- | --- |
| Full source map | `(0, 0)` to `(31,248, 22,344)` m |
| Deep River town ground | x `15,889.90–19,389.90`, z `12,210.55–15,185.55` |
| Deep River Marina detail | x `17,640–18,312`, z `12,432–13,216` |
| Lamure detail | x `18,312–18,928`, z `12,880–13,496` |
| McAnulty access data | approximately x `15,360–16,350`, z `10,586–12,183` |
| Swisha destination | approximately `(2,408, 3,738)`; dam source near `(2,159.5, 3,731.8)` |
| Chalk River Labs destination | approximately `(27,580, 18,620)` |

The source itself demonstrates that continuous detailed geography is unnecessary: Swisha is roughly 18 km from the marina and CNL roughly 11 km away, while the authored Deep River town occupies a much smaller area.

## Proposed Deep River boundary

Use a first-pass manifest envelope of:

```text
world-space minimum: (x=14,500, z=10,000)
world-space maximum: (x=20,500, z=15,800)
size: 6,000 × 5,800 m (34.8 km²)
```

This is intentionally generous. It encloses the source town ground, marina, Lamure, all current town building batches, the McAnulty access corridor, surrounding forest, and a substantial Ottawa River boating buffer. It is only about 5.0% of the current 698.2 km² source rectangle. It excludes Swisha and CNL by large margins.

This rectangle is an ownership/bake envelope, not an invisible wall. The final playable polygon should follow natural water/forest limits and surveyed road/river gateways inside the envelope. Keep original world coordinates in baked data and use a region transform only at scene instantiation; do not crop or rewrite the master GIS-derived files.

Proposed gateways:

- **West/up-river highway gateway to Swisha:** place the trigger where the surveyed Highway 17/McAnulty-connected route crosses the approved playable polygon. The exact centerline intersection should be baked from the road polyline, not hand-entered.
- **East/down-river highway gateway to Chalk River Labs:** same rule at the eastern Highway 17 crossing.
- **River gateways:** one upstream and one downstream channel trigger across the navigable river corridor, wide enough for a boat plus stopping distance. Do not use the envelope edge blindly; validate depth, current direction, camera sightlines, and safe turnaround space.

At a gateway, show a Yes/No prompt. No leaves the player and vehicle untouched and applies a short re-prompt cooldown. Yes freezes local controls, captures an authoritative transfer bundle, asynchronously prepares the destination, waits for collision and spawn readiness, migrates the entity group, and releases the old region only when no authority still needs it. Failure returns the group to a marked safe rollback pose with an error, never into unready collision.

### Cheap distant continuity

Preserve geographic context with region-specific proxies:

- low-frequency terrain skirt or horizon mesh generated from the unchanged source heightfield;
- opposite riverbank silhouette/forest impostor with no gameplay collision or navigation;
- far-water plane retained as a visual system, with physics/depth queries restricted to the active navigable water manifest;
- skyline landmark proxies only where a destination is plausibly visible.

Do not instantiate remote destination roads, detailed terrain, tree MultiMeshes, navigation, or collision merely to make the horizon continuous.

## Quantified content outside the proposed boundary

Runtime instrumentation classified transformed AABBs. `inside` is fully enclosed, `crossing` overlaps the boundary, and `outside` is wholly removable from the Deep River scene.

| Runtime content | Inside | Crossing | Wholly outside | Regionalization effect |
| --- | ---: | ---: | ---: | --- |
| Terrain/collision tiles | 123 | 10 | **174** | Outside tile meshes and their triangle-mesh collision disappear from Deep River. |
| Terrain triangles | 460,318 | 38,720 | **586,020** | About 54% of audited terrain triangles are wholly outside. |
| Regional crown batches | 76 / 4,004 instances | 43 / 3,912 | **3,048 / 137,264** | Large construction, node, MultiMesh-buffer, and memory reduction. |
| Regional trunk batches | 76 / 2,002 instances | 43 / 1,956 | **3,048 / 68,632** | Same; trunks and crowns together remove 205,896 instances. |
| Town building shell batches | 542 | 0 | **0** | No stationary Deep River rendering gain; all current town buildings remain. |
| Town building detail batches | 475 | 0 | **0** | Same. |
| Detailed town tree group | 545 / 73,302 instances | 0 | **0** | Entire cost remains local. |
| Town tree silhouette group | 504 / 46,194 instances | 0 | **0** | Entire cost remains local. |
| Town tree stem group | 504 / 29,777 instances | 0 | **0** | Entire cost remains local. |

The town tree groups contain different LOD representations, not necessarily 149,273 simultaneously visible instances. They nevertheless remain owned by Deep River and explain why removing remote forest cannot solve the marina render cost.

### In-memory regionalization A/B

The reversible proof of concept queued only wholly outside regional crown/trunk batches and terrain tile parents for deletion. It preserved crossing content and every town building/tree group. Both samples used the same stationary marina camera in one process.

| Metric | Full continuous world | Deep River-only POC | Change |
| --- | ---: | ---: | ---: |
| Nodes | 26,336 | 19,718 | **-6,618 (-25.1%)** |
| Static memory | 1,001.8 MiB | 741.8 MiB | **-260.0 MiB (-26.0%)** |
| Reported video memory | 515.6 MiB | 495.8 MiB | **-19.8 MiB (-3.8%)** |
| Median primitives | 1,797,609 | 1,644,295 | **-153,314 (-8.5%)** |
| Median draw calls | 2,623 | 2,628 | no improvement/noise |
| Median frame time | 17.014 ms | 16.864 ms | **-0.150 ms (0.9%)** |

The post-delete p95/p99 values regressed because thousands of nodes/resources were destroyed immediately before the second sample and cleanup continued; they are not evidence that a pre-baked region would regress. The test does prove that current culling prevents remote content from dominating steady marina draw count. A production region must avoid constructing those resources at all; it should not delete them after entry.

## Rendered baseline

### Controlled setup

- current `origin/main`, no Riverside opt-in;
- Godot 4.7.2 stable official;
- GL Compatibility, OpenGL 3.3, GTX 1050, driver 582.66;
- 1280 × 720 window, Performance preset, VSync off, 2× MSAA as reported by Godot;
- 2,400 m camera far plane, 72 m directional-shadow range;
- stationary marina start view;
- 120 rendered warm-up frames, then 300 rendered samples;
- imported project cache; normal desktop background environment was not controlled;
- wall-clock rendered frame intervals plus Godot Performance monitors.

Command:

```powershell
& 'build/godot/Godot_v4.7.2-stable_win64_console.exe' --path godot-cove `
  --rendering-method gl_compatibility --resolution 1280x720 `
  --script res://tests/profile_world_runtime.gd -- --profile-only-live
```

### Results

Three valid current-main samples with tail instrumentation were used for frame-tail aggregation. One earlier valid sample without p99 instrumentation was retained only as corroboration.

| Metric | Representative/median-of-runs result |
| --- | ---: |
| World ready time, warm imported cache | **59.3 s** median (56.2–59.7 s) |
| Frame median | **16.99 ms** (~58.9 FPS) |
| Frame p95 | **61.32 ms** |
| Frame p99 | **99.92 ms** |
| Worst 1% average FPS | **~9.6 FPS** |
| Worst observed frame | **112.95 ms** |
| Draw calls, median | **2,623–2,645** |
| Primitives, median | **1.794–1.798 M** |
| Rendered objects, median | **3,049–3,107** |
| Nodes | **26,336** |
| Active 3D physics objects | **2** at stationary sample |
| Static RAM | **~1,002 MiB** |
| Reported VRAM | **~505–520 MiB** |

The median barely approaches the 16.67 ms budget and the p95/p99 are multiple frames long. Stable 60 FPS is not demonstrated. `TIME_PROCESS` and `TIME_PHYSICS_PROCESS` monitor readings did not reconcile cleanly with the wall-clock interval in this fixture, so they are recorded in raw console output but not used to apportion the frame. Event markers and a real moving route are required before assigning individual spikes.

### Baseline limitations and next harness increment

The current script is a stationary fixture, not the complete acceptance harness. Before production changes are approved, add deterministic route assets and event logging for:

- marina stationary and residential stationary;
- town walk, representative drive, maximum normal drive, and cross-river boat;
- region departure, destination-ready, activation, return, and failed-transfer rollback;
- solo, host, and guest, with a late join during or after transfer;
- three repetitions for cold shader/user cache and three for warm cache;
- timestamps for resource request/ready, shader compile indication where available, physics backlog, node activation/destruction, and filesystem reads.

Record median/p95/p99/worst, 1% low, process and physics monitors, draw calls, primitives, rendered objects, nodes, active bodies, RAM/VRAM, load time, queue depth, and regional lifecycle events. Capture GPU timing only when the renderer/API exposes a trustworthy value; label it unavailable otherwise. A headless run remains correctness coverage, never an FPS result.

## Ranked bottlenecks

1. **Frame-time spikes in the existing local Deep River scene — proven.** p95 61 ms, p99 about 100 ms, and ~9.6 FPS worst-1% behavior are unacceptable. Exact event attribution remains to be instrumented.
2. **Local vegetation and directional shadows — strongly supported.** All detailed town vegetation remains inside the boundary. PR #135's controlled tests reduced a 14.75 ms render-only median to 11.64 ms without tree batches and 11.97 ms without directional shadows; shadow removal also cut draws from 3,045 to 2,236. These overlapping tests do not imply additive gains.
3. **Continuous-world construction and residency — proven.** Warm-cache ready time is roughly 56–60 seconds. Remote terrain/collision and 205,896 regional tree instances account for 25% of nodes and about 260 MiB in the removal POC.
4. **High local draw/primitive load — proven.** About 2.6k draws and 1.8M primitives remain in the current sampled view. Regionalization did not lower draw calls.
5. **Grass preparation when Riverside is enabled — prior evidence only for this branch.** PR #135 measured generation far above upload time. Grass is off in the current-main baseline and is not the explanation for the present tail.
6. **Unbounded or synchronous lifecycle work during movement — hypothesis requiring route event correlation.** Existing construction is heavily procedural and main-thread rendering object creation is required. The moving fixtures must identify which preparations, uploads, shader compiles, collision creation, or destruction correlate with spikes.

## Architecture alternatives

| Alternative | Advantages | Problems | Decision |
| --- | --- | --- | --- |
| A. Optimize continuous world | Lowest structural risk; preserves current coordinates and gameplay wiring. | Keeps ~698 km² of terrain source, collision, remote forest, long construction, memory, and irrelevant multiplayer state resident. Does not establish destination ownership. | Reject as the long-term foundation. Continue local render optimization regardless. |
| B. Independent regions, minimal internal streaming | Removes remote construction/residency; clean travel/save/interest boundary; simplest architecture that meets destination plan; can preserve current coordinates. | Deep River still has large local render cost; transitions and split-party authority require explicit design. | **Recommended first.** |
| C. Independent regions plus hierarchical local streaming | Adds bounded activation, simulation LOD, and scalable future density inside each region. | Highest tooling, ownership, bake, traversal, testing, and multiplayer complexity. Premature without moving-route evidence that Deep River itself needs it. | Design manifests to permit it; defer implementation decision. |

## Recommended region model

### Persistent session versus local scene

Keep these outside regional visual scenes:

- stable player/profile IDs, inventory, equipment ownership, money, skills, quest facts, employment state, and save revision;
- authoritative weather seed/time and global day clock, with region-specific presentation derived from them;
- vehicle stable ID, ownership, fuel/damage/cargo, passenger seat assignments, and last safe pose;
- party/peer membership, permissions, and peer-to-region assignment;
- persistent world facts keyed by stable entity ID, not NodePath.

A region scene owns presentation and local runtime state: terrain visuals/collision, local navigation, roads, buildings, vegetation, local NPC representations, water physics/query data, audio, and interaction nodes.

### Manifest

Each versioned region manifest should include:

- stable region ID, source-data revision/hash, bake-tool version, and world-to-region transform;
- playable polygon, visual-proxy bounds, gateway polygons, destination region/gateway IDs, prompt text, and safe rollback pose;
- chunk records with AABB, dependencies, content hashes, byte estimates, and lifecycle classes for render/collision/navigation/simulation;
- stable entity IDs and persistence policy;
- spawn sets for player, boat, road vehicle, passengers, and recovery;
- memory and activation budgets by graphics preset;
- optional future local-streaming grid metadata without requiring it in milestone one.

Use deterministic baking: sorted source IDs, explicit random seeds, canonical floating-point quantization, versioned schema, checksums, and a build report containing counts/bounds. Never use current runtime dictionary iteration or frame timing as bake order.

### Lifecycle separation

Maintain separate readiness states:

```text
requested -> data_ready -> collision_ready -> navigation_ready
          -> render_ready -> simulation_ready -> active
          -> draining -> released
```

Player control may resume after the required collision, spawn, authority, and minimum presentation set are ready. Navigation and NPC simulation may finish later only if no transferred actor depends on them. Render proxies may remain after collision/navigation unload. Use bounded request and activation queues, per-frame budgets, priority by predicted travel direction/time-to-contact, hysteresis around unload thresholds, and cancellation tokens for superseded travel.

For milestone B, region load/unload is coarse. If local streaming is later justified, start with a **uniform grid**, not a quadtree: the project already uses regular terrain/grass grids, most gameplay queries are ground-plane 2D, and predictable neighbor lookup/bake ownership is simpler. Suggested experiments are 128 m and 256 m cells for gameplay ownership, with vegetation render batches smaller than the activation cell where culling requires it. Select size from route measurements, not convention.

### Rendering strategy

- Retain spatial MultiMeshes, but keep batch AABBs small enough for useful culling. Godot culls a MultiMesh as one object, not per instance.
- Bake static terrain, road meshes, classification masks, building shells, and vegetation transforms offline. Do not rebuild 698 km² procedurally at every launch.
- Create shared mesh/material resources once per region/preset. Do not duplicate equivalent materials per chunk.
- Add manual HLOD/proxy meshes for distant groups only where measurement shows draw-call benefit. Godot visibility ranges can swap a house/tree group for a proxy.
- Keep close approved quality. Reduce distant shadow casting before changing close geometry or materials. Test tree shadow impostors/no-shadow distance tiers against fixed captures.
- Do not port Far Cry 5's compute-driven terrain literally. Its GPU compute LOD/culling/stitching architecture is instructive, but GL Compatibility cannot use RenderingDevice compute. The relevant lesson is hierarchical terrain representation and offline/parallel data preparation, not its implementation.
- Occlusion culling is unlikely to be the first win in an open river/town landscape; Godot documents it as most effective in enclosed scenes. Test downtown blocks separately before adopting it broadly.

### NPC, physics, and multiplayer LOD

- Full local simulation only near an interested authoritative peer.
- Coarse scheduled state for distant NPCs: stable route node/progress, activity, needs, and next decision time; no CharacterBody or navigation agent when not needed.
- Static collision loads before entry. Dynamic bodies outside all peer interest either sleep/serialize or continue in a lightweight authoritative region simulation when game rules require it.
- Network interest is `(peer region, nearby local cells, party-critical entities)`, not the full world. Clients never instantiate irrelevant regions.
- The host keeps a region authority instance while any player/entity requires it, even if the host's own avatar is elsewhere. A visual scene and authoritative simulation lifetime must be separable.

### Transfer transaction

1. Gateway validates travel eligibility and displays Yes/No.
2. Authority freezes the vehicle group and captures a revisioned bundle: player(s), vehicle, passengers/seats, inventory references, velocities needed for arrival, quest/world facts, and source rollback pose.
3. Destination region is requested; duplicate requests coalesce and have a timeout/cancel token.
4. Destination validates manifest/save schema and prepares the selected spawn set.
5. Collision and authority become ready before actors are created. Spawn occupancy is checked; fallback poses are ordered and deterministic.
6. Authority atomically changes region assignment and stable entities. Clients acknowledge the new revision; late/stale acknowledgements are ignored.
7. Source representations drain only after all affected peers acknowledge or disconnect policy resolves them.
8. On any failure, restore the source bundle at its safe pose. Never partially transfer cargo/passengers.

Late joins receive persistent session state, their assigned region manifest revision, relevant stable entities, then local snapshots. Save migration maps old continuous-world coordinates to a region plus local pose; unknown/out-of-bounds poses recover to the nearest explicit safe spawn and preserve inventory/progression.

## Research applicability

- [Godot MultiMesh guidance](https://docs.godotengine.org/en/4.7/tutorials/performance/using_multimesh.html): appropriate for repeated vegetation, but a MultiMesh has all-or-nothing culling. This supports smaller spatial batches, not one regional mega-batch.
- [Godot visibility ranges/HLOD](https://docs.godotengine.org/en/stable/tutorials/3d/visibility_ranges.html): appropriate for manually swapping detailed local groups for simple proxies.
- [Godot occlusion culling](https://docs.godotengine.org/en/stable/tutorials/3d/occlusion_culling.html): potentially useful downtown, but documented as most effective in indoor/enclosed scenes and not assumed beneficial for the open river.
- [Unreal World Partition HLOD](https://dev.epicgames.com/documentation/unreal-engine/world-partition-hierarchical-level-of-detail-in-unreal-engine): relevant conceptually—grid ownership and proxy meshes for unloaded cells—but this project should implement only the manifest/proxy subset it measures as useful.
- [Ghost of Tsushima: Zen of Streaming](https://www.gdcvault.com/play/1027205/Zen-of-Streaming-Building-and): relevant principles are data-oriented offline construction, predictable loading, and treating build/patch layout as part of streaming. It does not justify copying a proprietary engine design wholesale.
- [Far Cry 5 terrain rendering](https://gdcvault.com/play/1025480/Terrain-Rendering-in-Far-Cry): relevant for hierarchical terrain LOD, culling, and stitching goals. Its compute pipeline is unsuitable for GL Compatibility and should not be a project dependency.

## Roadmap

### P0 — Reproducible route and event profiler (small/medium)

Dependencies: fixed test saves, deterministic weather/time, route definitions, clean user settings fixture.  
Deliver: CSV/JSON samples, event markers, three warm/cold repetitions, screenshot and command record.  
Acceptance: marina/residential/walk/drive/max-drive/boat plus host/guest routes produce median/p95/p99/1%-low, resource/region events, counts, memory, and explicit unavailable fields without manual transcription.

### P1 — Deep River manifest and offline inventory bake (medium)

Dependencies: approve boundary against the missing screenshot; decide stable ID schema.  
Deliver: non-destructive bake tool reading current source files; versioned Deep River manifest; report matching the counts in this audit; cheap horizon/opposite-bank proxy.  
Acceptance: deterministic byte-identical rebuild on the same toolchain; all 1,674 source building records are accounted for as included/excluded/replaced; no source GIS asset is cropped; boundary/gateway overlay is human-approved.

### P2 — Independent Deep River scene vertical slice (large)

Dependencies: P1, persistent session extraction, transfer bundle schema.  
Deliver: Deep River scene that does not construct Swisha/CNL or wholly outside terrain/forest; collision-ready loading; rollback-safe debug gateway returning to Deep River.  
Expected measurable benefit: roughly 25% fewer nodes and 260 MiB lower static RAM than the current continuous scene are plausible based on the POC; startup should improve substantially because removed content is never generated, but the exact target must be measured after offline baking. Do not claim a large stationary FPS gain.  
Acceptance: memory/node reductions reproduced from a clean launch; no remote-region render/collision/navigation nodes; inventory/quests/weather/vehicle passengers survive ten round trips; failed load restores the source group.

### P3 — Local vegetation and shadow experiment (medium)

Dependencies: P0 fixed captures and route.  
Deliver: controlled A/B for shadow distance/caster classes and spatial vegetation HLOD; no close-quality change.  
Expected measurable benefit: prior single-view tests suggest a 2.8–3.1 ms median opportunity for either trees or shadows, with overlap; treat this as a hypothesis until matched route repetitions.  
Acceptance: statistically consistent improvement in marina, residential, drive, and boat routes; 720p Performance p95 below budget target trajectory; approved fixed-view visual diffs; no missing collision/gameplay trees.

### P4 — Region transfer and multiplayer interest (large)

Dependencies: P2, stable entity IDs, save migration, authoritative region registry.  
Deliver: road/river prompts; player/vehicle/passenger transfer; peer-region interest; split-region host authority; late join/disconnect recovery.  
Acceptance: solo/host/guest ten-cycle matrix; host and guest may occupy different regions; irrelevant clients instantiate no remote visuals; no duplication/loss of cargo, inventory, fuel, passengers, or quest state; old saves migrate or recover safely.

### P5 — Decide local streaming from evidence (decision gate)

If P2–P4 meet memory, load, and route frame-pacing targets with a complete Deep River scene, stop at architecture B. If moving routes still show activation/memory pressure attributable to local content, implement a 128/256 m uniform-grid prototype with separate render/collision/navigation/simulation lifecycles and compare it against the complete-region scene. Adopt hierarchical local streaming only if its measured benefit exceeds its complexity and transition risk.

## Risks

- Current NodePaths and direct scene references may hide persistence coupling; stable IDs and an explicit session model are prerequisite, not cleanup work after transfer.
- Immediate node destruction causes spikes, as the POC demonstrated. Production unload must be budgeted or occur behind a transition, and resources must be reference-counted.
- Large terrain tiles cross the proposed boundary. A bake must split ownership without destructively changing the source heightfield.
- Opposite-bank proxies can conflict with real destination geometry during transition; proxy and detailed content need exclusive visibility ownership.
- Split-region listen-server authority can consume memory for multiple simulation scenes. Separate authoritative data from local visuals and set a tested region-count budget.
- Renderer changes can silently reduce approved quality. Every vegetation/shadow/HLOD change needs fixed visual comparisons and gameplay collision checks.
- Compatibility, Mobile, and Forward+ have different capabilities and shader behavior. Do not globally change renderer based on one stationary sample.

## Immediate recommendation

Build **P0 and P1 first**: the deterministic route/event profiler and the non-destructive Deep River manifest/bake. They are the best investment because they turn the present one-minute procedural world build into measurable, owned data without committing to a rewrite, while also preventing another subsystem optimization from being judged on averages or stationary screenshots alone. In parallel only after the harness is stable, run P3's vegetation/shadow experiment because that is the strongest path to actual frame-time improvement inside Deep River.

Before proceeding to full region extraction, verify the boundary against the intended screenshot, verify highway and river gateway intersections from source polylines, and obtain matched moving-route results on the GTX 1050 and target GTX 1050 Ti. Before claiming the 60 FPS target, require p95/p99 and 1% lows—not merely a median or average—to fit the 16.67 ms frame budget under representative driving and boating.
