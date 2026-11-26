# Architecture and task routing

This is a short navigation map, not a complete specification. Source in the current task checkout is authoritative. Guides are starting points; inspect the actual callers and dependencies before changing behavior.

## Entry points

- [project.godot](../godot-cove/project.godot) configures the title scene and GL compatibility rendering; [title_screen.tscn](../godot-cove/title_screen.tscn) is the configured entry scene.
- The title screen starts [game_world.tscn](../godot-cove/game_world.tscn). [game_world.gd](../godot-cove/game_world.gd) extends [cove.gd](../godot-cove/cove.gd) and coordinates player movement and interaction, vehicles, activities, UI and session setup.
- [deep_river_map.gd](../godot-cove/deep_river_map.gd) builds the town, land terrain, waterfront, river water and regional map from the [Deep River assets](../godot-cove/deep_river/). The Ottawa River chart, navigation and fish populations have their own systems.
- [game_campaign.gd](../godot-cove/game_campaign.gd) integrates boats, regional contracts, Rich's questline and host state. [game_ledger.gd](../godot-cove/game_ledger.gd) persists that shared state and player progression. [multiplayer_session.gd](../godot-cove/multiplayer_session.gd) handles peer identity and transport. [player_notebook.gd](../godot-cove/player_notebook.gd) and [game_menu_theme.gd](../godot-cove/game_menu_theme.gd) support UI across several domains.

## Choose the relevant guide

| Task | Guide or source starting point |
| --- | --- |
| Boat movement, waves, thrust, helm | [Boat and water](systems/BOAT-WATER.md) |
| Host/guest, shared controls, replicated poses | [Multiplayer](systems/MULTIPLAYER.md) |
| Fishing, on-foot input, tools | [Fishing and player](systems/FISHING-PLAYER.md) |
| Camera, contextual interaction, idle poses, dynamic weather | [Gameplay polish](systems/GAMEPLAY-POLISH.md) |
| XP, jobs, economy and saves | [Progression and economy](systems/PROGRESSION-ECONOMY.md) |
| Town, roads and vehicles | `deep_river_*.gd`, `marina_car*.gd`, `vehicle_driver.gd` (search actual callers) |
| Mowing | `lawn_mower.gd`, `shannon_job.gd`, `mowing_routes.gd` |
| Opt-in Riverside visuals and world grass streaming | [Riverside proof of concept](systems/RIVERSIDE-POC.md); `riverside_grass_surface.gd`, `riverside_world_grass.gd` |
| Big Rich, Shannon Lapping, shared quest state | [Quests and character stories](systems/QUESTS.md) |
| AI and Discord workflow | [AI workflow status](AI-WORKFLOW.md), [team workflow](TEAM-WORKFLOW.md) |
| Tests and CI | [Build checks](BUILD-CHECKS.md), [universal XP verification](UNIVERSAL-XP.md) |

## Extending the architecture

See [Game identity](GAME-IDENTITY.md) for the world, narrative and progression direction. New activities can use the existing reward registry, skill catalog and host progression path. As additional quests are implemented, use the existing quest state operations and assess where the campaign dispatch and notebook currently assume a single character. The campaign also integrates a number of boat-specific responsibilities that could move to focused systems during future feature work.

## Retrieval strategy

Start with the relevant guide, then use [Godot source lookup](../tools/godot-lookup/README.md) on Windows or equivalent targeted search. The existing optional Graphify link snapshot is hash-checked by that tool. Read current source ranges around results and expand to callers and tests when needed. Do not read unrelated guides merely to satisfy a checklist. Update this index when adding or moving a subsystem guide.

For a portable, commit-aware symbol and direct-resource index, live GitHub status commands and documentation review checks, see [Living knowledge](LIVING-KNOWLEDGE.md). The index supplements existing source lookup; it does not replace current source or Graphify's richer relationships.
