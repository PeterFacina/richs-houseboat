# Multiplayer

- [river_crew.gd](../../godot-cove/river_crew.gd) extends Node3D and exposes host/join/session operations, requests, state and ship sharing, steering commands and player poses. Signals include `command_received`, `state_received` and `ship_received`.
- [fishing.gd](../../godot-cove/fishing.gd) includes lobby/session integration. [crew_avatar.gd](../../godot-cove/crew_avatar.gd) is preloaded by river_crew; trace pose and animation producers and consumers before editing.
- [UNIVERSAL-XP.md](../UNIVERSAL-XP.md) documents the host-side progression and persistence contract and a loopback network test.
- Restoration progress and equipment loans use the existing host campaign and per-peer snapshots. Multiple crewmates can repair separate components at once. Tennis remains a solo minigame, so crew trips keep Rich available to the shared story or aboard as a recruited companion.

For network changes inspect actual RPC annotations, sender validation, ownership, state revisions and disconnect/reconnect handling. Do not assume a client-side visual fix replicates. Playtest with host and guest, including role changes and rejoining; verify state convergence and no duplicated rewards where relevant. Use isolated test saves. Record which endpoints were actually exercised.
