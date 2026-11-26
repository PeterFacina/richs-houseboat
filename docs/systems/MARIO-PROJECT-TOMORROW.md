# Project Tomorrow: first playable slice

This slice introduces Mario at the modeled 16 Silvie Street property and establishes his workshop as the first stop in an invention and exploration story. Mario's authored story lines remain the source of truth. The companion dialogue boundary exposes persona, location, mission stage, nearby objects and up to eight bounded shared-memory events; a future provider may return display text only. No inference service, GPU endpoint, voice synthesis or provider action is connected in this slice.

The property is a hand-built approximation from the supplied street and yard photographs. The lot position is an estimate based on the Silvie Street and Hillcrest Avenue references. The images do not establish exact dimensions or a complete interior plan; house scale, parcel boundaries and unseen garage details should be treated as approximations. The garage, yard and workshop props are original geometry rather than image textures.

## Playable missions

| Mission | Player actions and trigger | Completion and saved state |
| --- | --- | --- |
| 1. The Man on Silvie Street | Find Mario's garage, inspect the measuring square, then talk to Mario. The authored conversation establishes Rich's introduction and Mario's electric-outboard challenge. | `intro_tool_found`, shared memory and mission step persist in the campaign ledger. Completing the introduction unlocks Mario's companion/workshop. Reopening Mario's conversation presents the current objective. |
| 2. Electric Outboard | Collect the battery, motor and controller assemblies from the garage bench. The visible prototype assembles as its components are collected; Rich's skepticism sets up a controlled test. | The three-part list, prototype unlock and next mission step persist in the campaign ledger. Duplicate and out-of-range collection requests are rejected. |
| 3. First Test | Start the test with Mario, pilot the existing boat on open water for 180 m, respond to the endurance warning by reducing throttle, and return to Mario. | A safe shutdown records the trial, completes the slice and unlocks the friendly-rivalry and endurance-research story flags. A short endurance battery is the recoverable failure. Trial distance, attempt count, warning and safe shutdown persist in the campaign ledger; the completed test can be repeated from Mario. |

The host validates each request against the sender's on-foot location and the current step. The host alone advances the river-trial state; guests use the same shared mission state and receive host messages. The test measures travel with the current boat physics and does not yet equip or simulate a distinct electric motor. The existing boat system provides the piloting loop for this first playable pass.

## Future milestones

1. Improve the Mario mesh and animation from front, profile and three-quarter in-engine references. Add natural hands, more individualized facial geometry, woodworking and companion idles, and clipping checks.
2. Refine the property dimensions and orientation against an owner-confirmed site plan. Add collision-tested garage access, the backyard shed, covered side structure, fire pit and machine clearances.
3. Build a real electric outboard component on the vehicle system, then add repeatable handling and endurance tests and an optional Rich-versus-Mario race.
4. Evaluate a separate, private NPC inference service on the nominated GPU with measured latency, concurrency, cost, timeouts and offline fallback. Keep generated text untrusted and display-only; preserve authored quest controls and host authority.
5. Continue the story with repeatable sensor tests, confirmation of a fictional submerged research instrument, then camera/sonar/ROV recovery gameplay and a modular exploration-vessel capstone.
6. Add workshop progression from electronics assembly to metal fabrication, robotics and underwater equipment. Keep upgrades within the existing residence and avoid XP grinding or a futuristic campus.

The first PR stops after the first three missions. It does not attempt the longer-term technology progression system.

## Visual and gameplay verification

The PNGs in `docs/screenshots/` are Godot Compatibility-renderer previews of the generated property and companion geometry. They are not screenshots of live gameplay. A live solo session loaded the Mission 1 HUD and showed the measuring-square objective. Desktop input did not produce a reliable route through the property and mission chain, so collection, the 180 m boat trial, retry behavior and guest synchronization still need a human in-game pass.
