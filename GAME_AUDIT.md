# Rich's Houseboat game audit

Scope is the d575a3c source archive. The unpacked collaboration copies contain separate town work and lack the progression scripts requested in the brief.

## Confirmed findings

- Campaign saves stage writes, then rotate the primary file into a previous-save slot. After the loader falls back to that slot, the next save can rotate the rejected primary over the good recovery copy.
- The campaign loader assigns each held-fish value to a typed dictionary. One malformed entry in otherwise readable JSON can abort recovery.
- Source startup emits warnings for direct image loads. The Windows preset retains the relevant raw assets, and a PCK launched outside the source tree passed the world and gameplay checks. A standalone Windows executable remains a separate verification step.
- Mowing cash used to depend on the interaction state to prevent a duplicate payout. The campaign now checks the persisted completion day before changing cash or XP.
- Mowing route setup scanned all grass instances for each zone, despite the mower having a world-cell index. Route setup now queries the cells overlapping the bounds and retains the same polygon inclusion test.

## Architecture and open checks

- The title scene enters the fishing scene, which coordinates player physics, vehicle and boat interactions, fishing, maps, campaign, preferences, and skills UI. Vehicle exit clearance has a shared helper.
- RiverCampaign owns reward transactions and per-player progression snapshots. RiverCrew handles ENet registration, pose updates, session state and boat steering. Physical evidence for reward actions and behavior under latency still need focused review.
- RiverLedger persists campaign and crew state separately. Fishing records and graphics preferences have separate paths. Public Works builds the job site, and MowingRoutes loads seven daily slots with fallback geometry.
- OttawaMap builds terrain and leads into Deep River road, building, property and vegetation generators. Measure scene build time, draw calls and frame times before changing asset generation.
