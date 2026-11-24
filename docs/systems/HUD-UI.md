# HUD and UI

- [cove.gd](../../godot-cove/cove.gd) builds the HUD containers and FPS label in `build_hud`. `_unhandled_input` handles the F3 visibility toggle. Check inherited input routing when testing key behavior.
- [fishing.gd](../../godot-cove/fishing.gd) overrides `update_hud`. It writes the FPS and graphics preset text and displays the current campaign action hint when its gameplay conditions are satisfied.
- [shannon_job.gd](../../godot-cove/shannon_job.gd) places the calendar label in `setup` and updates its date, time and visibility in `update_clock`. [river_regions.gd](../../godot-cove/river_regions.gd) creates and updates a separate region label.
- [river_campaign.gd](../../godot-cove/river_campaign.gd) provides the action selection logic in `action_hint`. The HUD consumes that result alongside fishing and other state-dependent hints.

Check actual control bounds across graphics presets and viewport sizes. Exercise the FPS toggle and confirm that date and time placement, pause behavior, and contextual hints still work. Record the preset and resolution for screenshots.
