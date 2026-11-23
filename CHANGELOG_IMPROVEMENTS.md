# Improvement changelog

## Road guidance for the zero-turn

- Raised the mowing waypoint and removed the added direction and blade text from the HUD.
- A ground-following trail with direction arrows uses the town street network to guide the mounted mower to the lawn and back to its Public Works bay. After parking and dismounting, the waypoint points to Shannon.

## Zero-turn mowing guidance

- Replaced route posts with one terrain-following translucent boundary mesh. The world marker targets uncut grass and switches to Shannon when the work is complete.
- The mower HUD shows direction, distance, and the blade control when the deck is disengaged. Route Planner reveals the exact number of remaining cuts.
- The deck samples tight turns as well as forward travel. Reengaging the blades allows an immediate cut, and fresh grass adds a short load response to the engine sound.

## Export, mowing and progression follow-up

- The existing Windows preset produced a PCK that ran from an isolated folder with the raw world data available. Export asset settings were retained.
- `river_campaign.gd` and `shannon_job.gd` now record route completion and pay through one host-side operation per route type and day. A repeat turn-in leaves both cash and XP unchanged. The route HUD reports percentage toward the completion requirement, and Shannon's closing dialogue no longer names a conflicting payment amount.
- Route setup uses the mower's existing spatial index to limit tuft checks to cells within each zone's bounds. The game test compares selected tufts with the previous full-scan method for the exercised route. Render frame rate remains unmeasured.
- The skill notebook shows the remaining XP to the next level. The completed route prompt identifies midnight as the next opening.
- The ENet test now drives helm assignment, steering and handoff on captain disconnect. The vehicle-exit fixture checks flat ground, sloped ground and refusal without ground.

## Campaign save recovery

- `godot-cove/river_ledger.gd` now preserves the known-good previous save on the first write after recovery. After a successful write, ordinary backup rotation resumes.
- The loader skips malformed JSON candidates and damaged held-fish entries while keeping intact fish. Numeric fields accept integer and float representations where appropriate. The writer flushes the staged file and checks the write status before rotating saves.
- `godot-cove/verify_ledger_recovery.gd` exercises corrupt-primary recovery, legacy defaults, intact fish recovery, backup preservation, and a subsequent regular rotation. All checks passed. Disk-full and simultaneous writers were outside this test.

## Fishing feedback

- `godot-cove/fishing.gd` shows the time left to set the hook in the existing bite prompt. The countdown uses the same constant as the existing 2.27-second timeout.
- The in-game progression smoke test loaded the scene and verified fish discovery and catch-journal persistence. Visual readability and live hook timing still need an interactive pass.
