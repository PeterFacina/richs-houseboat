# Architecture and task routing

This is a short navigation map, not a complete specification. Source in the current task checkout is authoritative. Guides are starting points; inspect the actual callers and dependencies before changing behavior.

## Entry points

- [project.godot](../godot-cove/project.godot) configures the title scene and GL compatibility rendering; [title_screen.tscn](../godot-cove/title_screen.tscn) is the configured entry scene.
- [fishing.gd](../godot-cove/fishing.gd) extends [cove.gd](../godot-cove/cove.gd) and includes gameplay input, vessel stepping, fishing and session integration. Do not assume its responsibility is limited to fishing.

## Choose the relevant guide

| Task | Guide or source starting point |
| --- | --- |
| Boat movement, waves, thrust, helm | [Boat and water](systems/BOAT-WATER.md) |
| Host/guest, shared controls, replicated poses | [Multiplayer](systems/MULTIPLAYER.md) |
| Fishing, on-foot input, tools | [Fishing and player](systems/FISHING-PLAYER.md) |
| XP, jobs, economy and saves | [Progression and economy](systems/PROGRESSION-ECONOMY.md) |
| Town, roads and vehicles | `deep_river_*.gd`, `marina_car*.gd`, `vehicle_driver.gd` (search actual callers) |
| Mowing | `lawn_mower.gd`, `shannon_job.gd`, `mowing_routes.gd` |
| AI and Discord workflow | [AI workflow status](AI-WORKFLOW.md), [team workflow](TEAM-WORKFLOW.md) |
| Tests and CI | [Build checks](BUILD-CHECKS.md), [universal XP verification](UNIVERSAL-XP.md) |

## Retrieval strategy

Start with the relevant guide, then use [Godot source lookup](../tools/godot-lookup/README.md) on Windows or equivalent targeted search. The existing optional Graphify link snapshot is hash-checked by that tool. Read current source ranges around results and expand to callers and tests when needed. Do not read unrelated guides merely to satisfy a checklist. Update this index when adding or moving a subsystem guide.

For a portable, commit-aware symbol and direct-resource index, live GitHub status commands and documentation review checks, see [Living knowledge](LIVING-KNOWLEDGE.md). The index supplements existing source lookup; it does not replace current source or Graphify's richer relationships.
