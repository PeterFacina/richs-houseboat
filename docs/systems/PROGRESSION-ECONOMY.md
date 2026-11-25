# Progression and economy

Read [Universal XP and skill tree](../UNIVERSAL-XP.md) for the existing detailed integration and verification contract; do not duplicate its rules here.

- [progression.gd](../../godot-cove/progression.gd) references [progression_catalog.gd](../../godot-cove/progression_catalog.gd); skill data lives in [progression_skills.json](../../godot-cove/progression_skills.json).
- [game_ledger.gd](../../godot-cove/game_ledger.gd) exposes load/save, wallet, affordability, spend, route/network and award methods; it references campaign data. Inspect [game_campaign.gd](../../godot-cove/game_campaign.gd) for callers and reward integration.
- [rich_story.gd](../../godot-cove/rich_story.gd) defines the eight restoration quests, loan milestones and ownership transfer. A fresh trip starts at the Pier Road yard. The shared ledger saves the quest, repaired components, launch, ownership and upgrades. Existing saves retain their established start and owned equipment.

Activities route eligible events through the campaign to the host. The ledger keeps campaign cash, property, equipment and quest state. The progression module defines reward events, and the catalog defines skill ranks and effects. Purchases and XP persist in each player's profile within the host campaign. The event IDs guard rewards across reload and reconnect. New activities should use those integration points. Future research may unlock knowledge or capabilities independently of skill ranks.

## Desktop save compatibility

The project displays Rich's Houseboat — Deep River and explicitly selects its existing Godot data directory. Windows and macOS use `Godot/app_userdata/Rich's Houseboat — Ottawa River`. Linux and BSD use the lowercase `godot` base folder. See [Godot user data paths](https://docs.godotengine.org/en/stable/tutorials/io/data_paths.html).

The ledger and solo slot code still open `ottawa_river_campaign.json`, `ottawa_river_campaign_2.json`, `ottawa_river_multiplayer.json`, `ottawa_crew_id.txt`, `ottawa_progression_id.txt`, `ottawa_catches.json`, `ottawa_catches_2.json` and `ottawa_multiplayer_catches.json`. Preferences, backups and player profiles use the same directory and identifiers. There is no file move or copy step at startup. Save recovery and existing schema upgrades continue through the ledger.

Preserve host validation, persistent identities, reward deduplication and save compatibility. Check solo and multiplayer behavior, reload/reconnect, and avoid real player saves in automated tests. Existing progression verification commands are documented in Universal XP. Update that detailed guide when its contract changes.
