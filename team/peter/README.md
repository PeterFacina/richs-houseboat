# Peter’s notes

## Current work

- Agree on the Godot baseline the team will start from.
- Set up the private shared repository and test the pull request workflow with a small change.

## Verification and handoff

- Record the baseline commit and engine version after a clean clone runs.
- Link active branches, pull requests, and playtest releases here.
- The workflow pilot confirmed that Discord can open a task in Codex.
- Ethan’s GPU generated the brief for this Discord report.

### Multiplayer helm workflow pilot (#66)

On 2026-11-24, [issue #66](https://github.com/PeterFacina/richs-houseboat/issues/66) received one [guarded GPU brief](https://github.com/PeterFacina/richs-houseboat/issues/66#issuecomment-7137634439) at game revision `86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5`, matching main when checked. Static source review at that revision:

- [Boat and water](../../docs/systems/BOAT-WATER.md) and [Multiplayer](../../docs/systems/MULTIPLAYER.md) are the relevant guides.
- [fishing.gd:642–644](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/fishing.gd#L642-L644) calls campaign helm on interaction while driving or near the wheel. [river_campaign.gd:692–703](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/river_campaign.gd#L692-L703) requests or relinquishes the helm; [request:837–841](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/river_campaign.gd#L837-L841) routes guests to host peer 1 and local authority to perform. [use_helm:1166–1191](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/river_campaign.gd#L1166-L1191) validates ownership, onboard/gear state and distance (1.33 m), assigns captain and undocks; repeat use releases control.
- [river_crew.gd:212–242](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/river_crew.gd#L212-L242) handles requests, reliable captain/state updates and authority ship packets. Steering RPC accepts finite inputs only from the current captain on the server, with throttle clamped to -0.32…1 and rudder to -1…1. [river_campaign.gd:717–738](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/river_campaign.gd#L717-L738) applies remote commands on the host with a 0.7 s timeout; guests use snapshot interpolation instead. [ship_packet, receive_ship, sync_guest and tick_client_ship:1634–1720](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/river_campaign.gd#L1634-L1720) handle vessel state, captain changes and guest pose convergence.
- Brief correction: [cove.gd:241–262](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/cove.gd#L241-L262) contains the base movement/throttle implementation, but [fishing.gd:967–979](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/fishing.gd#L967-L979) overrides stepping and throttle using campaign stepping and hold_throttle. [houseboat.gd:110–111](https://github.com/PeterFacina/richs-houseboat/blob/86cf4a42d28b2d5f119f36cd3b0af75e0befb4f5/godot-cove/houseboat.gd#L110-L111) supplies the helm anchor used in positioning and distance validation. The brief's princecraft.gd:265 citation is a gunwale mesh line, and river_crew.gd:23 is a profile variable, not the helm RPC. The cited project settings and guide paths were checked. Historical reports S11/S12 lack identifiers and could not be validated.
- Overlap: #56 and draft #57 cover idle drift and finishes; the inspected #57 campaign patch sets departed at open-water spawn, not captain transfer. #65 is the earlier notes-only pilot; #64 tracks live sign-off; drafts #31/#63 and #28 cover worker/Studio tooling, #62 benchmark notes. Their changed-file lists do not include this team note. No gameplay edits are needed.

Verification: GitHub evidence and static source only; no Godot runtime, screenshots, host/guest playtest or private GPU training capture verified. Full live worker sign-off remains in #64.
