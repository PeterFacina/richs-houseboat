# Game identity

Rich's Houseboat is the working title of a multiplayer open-world life simulation built in Godot and set in Deep River, Ontario, Canada. The Ottawa River runs alongside the town. Big Rich leads the existing introductory restoration questline. Shannon Lapping's independent questline is planned.

## World and direction

Deep River is the primary setting and uses the identifier `deep_river`. The Ottawa River uses `ottawa_river` for systems or data specific to that waterway. The playable region includes the town, its waterfront and nearby destinations such as Chalk River and Swisha (Des Joachims). The City of Ottawa is a separate location. The project started as a Garry's Mod recreation of Deep River using geographical data. The working title reflects the original houseboat story and can change independently of game systems.

Players already explore on foot, drive, boat, fish, take mowing jobs, repair and acquire equipment, and make progress solo or with a crew. The long-term loop is to perform activities, gain experience, improve skills and unlock equipment, knowledge and opportunities for more advanced work or quests. Players can specialize. Future possibilities include broader local employment and business opportunities, more technical work, recreation, regional travel and additional characters. The shared systems should be usable by new domains as they are designed.

## Narrative and progression

The introductory chain starts with Big Rich at the Pier Road yard and introduces fishing, boating, driving, repairs and ownership. The [quest guide](systems/QUESTS.md) documents the eight introductory quests and The Roach Reaper, a rare side quest on Silvie Street. Shannon already appears at Public Works as the mowing job contact, with a character model, dialogue and daily routes. Mario's Project Tomorrow introduction and first three missions begin at 16 Silvie Street; later technology progression, the underwater mystery and an exploration-vessel capstone remain future milestones in the [Project Tomorrow guide](systems/MARIO-PROJECT-TOMORROW.md). Additional independent or interconnected character stories are planned.

[Universal XP](UNIVERSAL-XP.md) already connects activity rewards and skill ranks to persistent player profiles. Shared campaign funds, ownership and quest state coexist with per-player XP and skill ranks. A future research tree could grant knowledge or capabilities separately from skill proficiency. See [architecture](ARCHITECTURE.md) for system entry points and [progression and economy](systems/PROGRESSION-ECONOMY.md) for the current integration.

| Term | Meaning |
| --- | --- |
| Experience | Progress earned through participation and accomplishments |
| Skills | Proficiency in an activity or domain |
| Research | Knowledge, technology or capability unlocks |
| Quests | Structured objectives and narrative progression |
| Activities | Repeatable gameplay interactions |
| Jobs | Employment and economic opportunities |
| Equipment | Items and tools that enable activities |
| Economy | Funds, purchases, rewards and transactions |
| Progression | Shared framework connecting player advancement systems |

## Naming and compatibility

Name shared code for its responsibility. Use `game_world` for game coordination and `deep_river_map` for the town, terrain, waterfront and regional map. Use generic names for shared player, NPC, quest, activity, job, progression, research, economy, inventory and multiplayer code. Use names such as `rich_story`, `houseboat_restoration` and `fish_species` for specific features. Check the current source before describing a feature as implemented.

Historical references to `ottawa_map.gd`, `fishing.gd`, `fishing.tscn` and `godot-cove/ottawa/` point to `deep_river_map.gd`, `game_world.gd`, `game_world.tscn` and `godot-cove/deep_river/` in current source. The [architecture index](ARCHITECTURE.md) links the current shared systems.

The legacy desktop data directory, save and identity filenames, quest IDs and multiplayer node names are compatibility contracts. Existing saves are opened in place. The [progression guide](systems/PROGRESSION-ECONOMY.md) and [multiplayer guide](systems/MULTIPLAYER.md) record these exceptions.
