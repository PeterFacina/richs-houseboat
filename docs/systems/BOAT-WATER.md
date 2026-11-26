# Boat and water

Verify current source; this is not a physics specification.

- [houseboat.gd](../../godot-cove/houseboat.gd) extends AnimatableBody3D; entry points include `sail`, `sail_river`, `passive_water_velocity`, `sample`, `update_motor`, `advance_steering` and throttle/ignition methods.
- [swell.gd](../../godot-cove/swell.gd) is referenced by the houseboat. [outboard.gd](../../godot-cove/outboard.gd) and [boat_fuel_tank.gd](../../godot-cove/boat_fuel_tank.gd) are also preloaded there.
- [game_world.gd](../../godot-cove/game_world.gd) exposes `step_vessel`, helm throttle and ignition integration. Trace callers through campaign/session code when changing movement.
- [boat_mooring.gd](../../godot-cove/boat_mooring.gd) limits horizontal hull movement while grounded by an anchor or tethered to a cleat. The hull still samples wind, current and waves. [river_mooring.gd](../../godot-cove/river_mooring.gd) registers cleats from the marina and campaign landings and validates each interaction.
- At the helm, press G in neutral to lower the anchor or press G again to raise it. Pick up the bow and stern lines individually with E, aim at reachable dock cleats, and press E to tie each line. E unties a line at the dock cleat or from the boat. Release all dock lines before taking the helm. The anchor holds the boat at neutral until raised.
- At a campaign landing, two lines tied to that landing enable services and the L-key board and go-ashore shortcut. Landing saves and ferry arrivals pre-rig both lines. The public launch pre-rigs its own lines on spawn.
- W/S quickly adjusts the throttle and R/F makes smaller changes. Releasing the key leaves the lever set. Space shifts straight to neutral. The lever also passes through neutral when changing direction and returns to neutral when leaving the helm or securing the boat.
- [water.gdshader](../../godot-cove/water.gdshader) uses the directional wave coefficients in [swell.gd](../../godot-cove/swell.gd). Shore clearance and the sheltered area inside the surveyed marina breakwall reduce wave height. The existing wind and current inputs still drive passive boat drift, with an additional prevailing-wind contribution to the boat flow.

[The day and night profile](../../godot-cove/river_day_cycle.gd) defines the clock thresholds, lighting colours, brightness and transition widths. The Deep River map applies the same sun direction, moonlight and sky palette to the backdrop, Ottawa River water, the Swisha headpond and building reflections. Nearby street and building lights fade in during dusk and out through dawn.

## River surface and wakes

The near mesh follows the player on a fixed world grid. Its displacement fades between 89 and 112 metres into the distant plane. The distant shader keeps the same swell normals and water colours. The terrain masks, riverbed and chart still define where the river appears and where the bottom can be seen. The Compatibility renderer uses the existing sky and baked shoreline reflections, plus the existing boat light cue. Dynamic reflections of individual scene objects would need a separate rendering pass.

[River wakes](../../godot-cove/river_wakes.gd) retain up to 12 packets for up to 4.5 seconds. Speed, acceleration, hull spread and prop thrust set strength and shape. Each packet drifts with the water and spreads outward as it fades. Authoritative hull motion samples wakes from other sources, with an explicit height cap. The existing campaign operates one player-controlled hull at a time. Other visible vessels at the marina can already use the shared surface sampler.

The host sends recent wake emissions in the ship stream and seeds a late join with the full live trail. The existing ship clock and host weather determine wave phase and amplitude. Wake packets expire in memory and add no save fields. Bow spray, fishing and swimming ripples, and water audio render or play locally.

**Settings → Water detail** changes fine ripples, rain rings, local reflections, bow spray and ripple geometry. Graphics presets still set water mesh density. Water detail changes only local presentation. Shore, hull and prop wash audio use spatial sources and blend with the existing weather mix.

The visual target is sheltered, dark freshwater with restrained foam. Deep River Marina photography and the Ottawa River beach walk are the local references. The game references are freshwater surface detail in Red Dead Redemption 2, hull response in Sea of Thieves, and persistent disturbed water behind boats in GTA V. [Deep River Marina](https://www.deepriver.ca/) · [Deep River beach walk](https://www.youtube.com/watch?v=RiagUuvnkkY) · [Red Dead Redemption 2](https://www.rockstargames.com/reddeadredemption2) · [Sea of Thieves](https://www.seaofthieves.com/) · [Grand Theft Auto V](https://www.rockstargames.com/gta-v)

## Preserve and verify

Check movement with no driver, helm entry/exit, neutral coasting, forward/reverse thrust, steering, wind/current and wave behavior, boarding/collision, fuel behavior and host/guest agreement as applicable. Verify actual equations and units in current source; no numerical constants are prescribed here. Query current issues and PRs for drift, helm and water changes; inspect relevant diffs before overlapping work. Run startup checks plus targeted tests and human playtesting; record what was not tested.

Run `res://tests/verify_gameplay_polish.gd` under a disposable APPDATA path containing `houseboat-polish-`. It samples calm, storm and sheltered water, checks the shader amplitude inputs, tests wake overlap and expiry, lands a cast, enters the water and exercises steering, anchoring and dock-line limits. Its ENet loopback checks initial and live wake data. Run it with an OpenGL window to capture clear, heavy rain, morning fog and night storm at the public wharf. Include a manual helm and boarding pass, a live crew trip, and a listening pass for audio acceptance.

A matched Compatibility run on Godot 4.7.2 and a GTX 1060 3 GB used Balanced graphics at 960 × 540 with VSync off. Each view sampled 180 frames after 100 warm-up frames. The baseline was main `f7cc233`.

| View | Median, before → after | 95th percentile, before → after |
| --- | ---: | ---: |
| Underway at 5.1 m/s in a thunderstorm | 9.15 → 8.53 ms | 13.85 → 14.56 ms |
| Public wharf, clear | 15.10 → 14.67 ms | 19.97 → 25.13 ms |
| Public wharf, heavy rain | 15.11 → 14.73 ms | 18.41 → 19.59 ms |

Scene construction through the first physics frame took 30.07 s and 30.52 s in the underway runs. Desktop timing varied and the clear-wharf 95th percentile was higher in the matched comparison. These measurements cover one machine and renderer.

[Riverside draft #135](https://github.com/PeterFacina/richs-houseboat/pull/135) adds opt-in marina colour, reflection and foam treatments. The default simulation changes here share its shader and map code. A dry-run integration found a water shader conflict, plus the map and sky conflicts already present between that draft and main.
