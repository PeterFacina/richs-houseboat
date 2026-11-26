# Project Tomorrow: first playable slice

This slice introduces Mario at the modeled 16 Silvie Street property and establishes his workshop as the first stop in an invention and exploration story. Mario's authored story lines remain the source of truth. The companion dialogue boundary exposes persona, location, mission stage, nearby objects and up to eight bounded shared-memory events; a future provider may return display text only. No inference service, GPU endpoint, voice synthesis or provider action is connected in this slice.

The property now replaces the mapped `ms-1022` duplex footprint, whose center matches the [Google Maps pin for 16 Silvie Street](https://www.google.com/maps/place/16+Silvie+St,+Deep+River,+ON+K0J+1P0/@46.0966177,-77.4830823,18z) (46.0966177, -77.4830823). We compared the 10–16 Silvie Street properties to place this address. The owner-provided photos are the primary visual reference. Street View identifies May 2025 imagery; the aerial imagery checked in Maps is labeled ©2026, so this work does not claim to have verified a 2025 aerial capture. The supplied images do not establish surveyed parcel dimensions or a complete interior plan. House scale, lot boundaries, and unseen outbuilding details remain approximations. The house faces Silvie Street, Mario occupies the right-hand unit, and the shed, woodworking garage, fire pit, and rear access are kept on that side of the duplex. The rear approach avoids the neighboring mapped `ms-3` house footprint.

## Playable missions

| Mission | Player actions and trigger | Completion and saved state |
| --- | --- | --- |
| 1. The Man on Silvie Street | Find Mario's garage, inspect the measuring square, then talk to Mario. The authored conversation establishes Rich's introduction and Mario's electric-outboard challenge. | `intro_tool_found`, shared memory and mission step persist in the campaign ledger. Completing the introduction unlocks Mario's companion/workshop. Reopening Mario's conversation presents the current objective. |
| 2. Electric Outboard | Collect the battery, motor and controller assemblies from the garage bench. The visible prototype assembles as its components are collected; Rich's skepticism sets up a controlled test. | The three-part list, prototype unlock and next mission step persist in the campaign ledger. Duplicate and out-of-range collection requests are rejected. |
| 3. First Test | Start the test with Mario, pilot the existing boat on open water for 180 m, respond to the endurance warning by reducing throttle, and return to Mario. | A safe shutdown records the trial, completes the slice and unlocks the friendly-rivalry and endurance-research story flags. A short endurance battery is the recoverable failure. Trial distance, attempt count, warning and safe shutdown persist in the campaign ledger; the completed test can be repeated from Mario. |

The host validates each request against the sender's on-foot location and the current step. The host alone advances the river-trial state; guests use the same shared mission state and receive host messages. The test measures travel with the current boat physics and does not yet equip or simulate a distinct electric motor. The existing boat system provides the piloting loop for this first playable pass.

## Future milestones

1. Improve the Mario mesh and animation from front, profile and three-quarter in-engine references. Add natural hands, more individualized facial geometry, woodworking and companion idles, and clipping checks.
2. Refine dimensions and orientation against an owner-confirmed parcel/site plan and any dated aerial reference. Add verified boundaries, outbuilding interiors, and final garage/workshop clearances. The current layout is a location- and orientation-corrected approximation.
3. Build a real electric outboard component on the vehicle system, then add repeatable handling and endurance tests and an optional Rich-versus-Mario race.
4. Evaluate a separate, private NPC inference service on the nominated GPU with measured latency, concurrency, cost, timeouts and offline fallback. Keep generated text untrusted and display-only; preserve authored quest controls and host authority.
5. Continue the story with repeatable sensor tests, confirmation of a fictional submerged research instrument, then camera/sonar/ROV recovery gameplay and a modular exploration-vessel capstone.
6. Add workshop progression from electronics assembly to metal fabrication, robotics and underwater equipment. Keep upgrades within the existing residence and avoid XP grinding or a futuristic campus.

The first PR stops after the first three missions. It does not attempt the longer-term technology progression system.

## Visual and gameplay verification

The `mario-property-street.png`, `mario-property-backyard.png`, `mario-property-rear-street.png` and `mario-property-aerial.png` captures were rendered from the full Godot town scene with the Compatibility renderer. They show the corrected approach and property from the requested angles. Shape-cast checks verify the rear street-to-shed-to-yard route and the yard-to-woodworking-garage route. This property-only pass changes no dialogue, quest-step, companion or progression logic. The first three missions, saved-state behavior, multiplayer guest synchronization and Mario's appearance remain outside this playtest and need human gameplay review.
