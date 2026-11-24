# Boat and water

Verify current source; this is not a physics specification.

- [houseboat.gd](../../godot-cove/houseboat.gd) extends AnimatableBody3D; entry points include `sail`, `sail_river`, `passive_water_velocity`, `sample`, `update_motor`, `advance_steering` and throttle/ignition methods.
- [swell.gd](../../godot-cove/swell.gd) is referenced by the houseboat. [outboard.gd](../../godot-cove/outboard.gd) and [boat_fuel_tank.gd](../../godot-cove/boat_fuel_tank.gd) are also preloaded there.
- [fishing.gd](../../godot-cove/fishing.gd) exposes `step_vessel`, helm throttle and ignition integration. Trace callers through campaign/session code when changing movement.
- [boat_mooring.gd](../../godot-cove/boat_mooring.gd) limits horizontal hull movement while grounded by an anchor or tethered to a cleat. The hull still samples wind, current and waves. [river_mooring.gd](../../godot-cove/river_mooring.gd) registers cleats from the marina and campaign landings and validates each interaction.
- On either boat, look at the bow anchor and press E to lower or raise it. Pick up the bow and stern lines individually with E, aim at reachable dock cleats, and press E to tie each line. E unties a line at the dock cleat or from the boat. Raise the anchor and release all dock lines before taking the helm.
- At a campaign landing, two lines tied to that landing enable services and the L-key board and go-ashore shortcut. Landing saves and ferry arrivals pre-rig both lines. The public launch pre-rigs its own lines on spawn.
- [water.gdshader](../../godot-cove/water.gdshader) is a rendering starting point; do not assume shader waves and physical motion are identical.

## Preserve and verify

Check movement with no driver, helm entry/exit, neutral coasting, forward/reverse thrust, steering, wind/current and wave behavior, boarding/collision, fuel behavior and host/guest agreement as applicable. Verify actual equations and units in current source; no numerical constants are prescribed here. Query current issues and PRs for drift, helm and water changes; inspect relevant diffs before overlapping work. Run startup checks plus targeted tests and human playtesting; record what was not tested.
