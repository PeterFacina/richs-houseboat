# Multiplayer

- [multiplayer_session.gd](../../godot-cove/multiplayer_session.gd) extends Node3D and exposes host/join/session operations, requests, state and ship sharing, steering commands and player poses. Signals include `command_received`, `state_received` and `ship_received`.
- [game_world.gd](../../godot-cove/game_world.gd) includes lobby/session integration. [crew_avatar.gd](../../godot-cove/crew_avatar.gd) is preloaded by the multiplayer session; trace pose and animation producers and consumers before editing.
- [UNIVERSAL-XP.md](../UNIVERSAL-XP.md) documents the host-side progression and persistence contract and a loopback network test.
- Restoration progress and equipment loans use the existing host campaign and per-peer snapshots. Multiple crewmates can repair separate components at once. Tennis remains a solo minigame, so crew trips keep Rich available to the shared story or aboard as a recruited companion.

- The host validates anchor and rope requests against the player's last position and the actual boat and cleats. Guests receive the active anchor, line holders and cleat endpoints with the ship pose. Disconnecting releases a carried line. Tied lines stay with the boat.
- The host owns the wake trail and samples it for hull motion. The reliable join carries live wakes along with the ship clock and weather. Each regular ship update repeats the two latest wake emissions so guests can rebuild the shared surface. Bow spray, ripple geometry and sound use local settings. [Boat and water](BOAT-WATER.md)

For network changes inspect actual RPC annotations, sender validation, ownership, state revisions and disconnect/reconnect handling. Do not assume a client-side visual fix replicates. Playtest with host and guest, including role changes and rejoining; verify state convergence and no duplicated rewards where relevant. Use isolated test saves. Record which endpoints were actually exercised.

The campaign save records one Dab pen. The host checks pickup and drop requests against the current item revision, player reach and a reachable surface. The holder is tied to the existing persistent player identity and sees ownership in their own campaign snapshot. The pose stream carries the held prop, smoking animation and flashlight state. A pen dropped on a boat is stored relative to that craft.

The host advances the saved calendar at the existing rate and includes it with regular ship updates. Guests use the host's calendar for the sky, water, exterior lighting and clock display. The host can use N to advance to the next 19:00 or 08:00. Pine Reach's Go at dusk trip advances to the next 19:00. These advances also pass time for calendar-driven activities.

The host simulates Deep River residents. The existing ship stream carries resident positions, headings and walking velocities. The reliable initial ship state seeds late joiners. Guests render the received positions and leave route decisions to the host. See [Deep River residents](GAMEPLAY-POLISH.md#deep-river-residents).

## Compatibility across the file rename

The world scene retains the root name `OttawaRiverFishing`, and the campaign sets its existing `RiverCampaign` and `Crew` node paths during setup. Godot RPC routing depends on matching scene-tree paths. Method names and RPC annotations, state payloads, profiles and reward contracts keep their existing identifiers. The `game_world` filename describes the source role independently of those paths.
