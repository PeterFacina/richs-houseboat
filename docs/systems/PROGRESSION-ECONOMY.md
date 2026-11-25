# Progression and economy

Read [Universal XP and skill tree](../UNIVERSAL-XP.md) for the existing detailed integration and verification contract; do not duplicate its rules here.

- [progression.gd](../../godot-cove/progression.gd) references [progression_catalog.gd](../../godot-cove/progression_catalog.gd); skill data lives in [progression_skills.json](../../godot-cove/progression_skills.json).
- [river_ledger.gd](../../godot-cove/river_ledger.gd) exposes load/save, wallet, affordability, spend, route/network and award methods; it references campaign data. Inspect [river_campaign.gd](../../godot-cove/river_campaign.gd) for callers and reward integration.
- [rich_story.gd](../../godot-cove/rich_story.gd) defines the eight restoration quests, loan milestones and ownership transfer. A fresh trip starts at the Pier Road yard. The shared ledger saves the quest, repaired components, launch, ownership and upgrades. Existing saves retain their established start and owned equipment.

Preserve host validation, persistent identities, reward deduplication and save compatibility. Check solo and multiplayer behavior, reload/reconnect, and avoid real player saves in automated tests. Existing progression verification commands are documented in Universal XP. Update that detailed guide when its contract changes.
