# Fishing and player

- [game_world.gd](../../godot-cove/game_world.gd) extends cove.gd, preloads rig, water effects, fish species/stock, finder and guide, and includes movement, swimming, gear, interaction and session code. Start with `_physics_process`, `move_on_foot`, `equip_gear`, `interact` or the relevant fishing state transition.
- [fishing_rig.gd](../../godot-cove/fishing_rig.gd), [fish_species.gd](../../godot-cove/fish_species.gd), [river_stock.gd](../../godot-cove/river_stock.gd) are directly referenced by game_world.gd.
- For hands and props, locate current callers of `river_hands.gd`, `river_hand_actions.gd` and `crew_avatar.gd`; check both first-person and remote representations.
- In a solo trip, follow the marina path through the Yacht & Tennis Club gate to the court marked Tennis with Big Rich. Rich takes a break from his quest or companion duties while the player is at the court and resumes them when the player leaves. Look at him and press E. Aim with the mouse and click after the ball bounces within reach. The match plays to seven and Esc leaves the match. [The court match](../../godot-cove/marina_tennis_match.gd) owns the rally and score. The player script handles input, uses the shared HUD, and restores equipped gear at the end of the match.
- B opens the [River Notebook](../../godot-cove/player_notebook.gd), which embeds the Fish Index and River Chart and links to Boat Services. The Notebook and [quest offer](../../godot-cove/npc_quest_offer.gd) share the existing game theme. The fishing input and Backpack remain available outside tennis matches and menus.

- Swim to the water side of a marina ladder and look at its rails for the E climb prompt. The player steps onto the floating dock. The Lamure swim float has its own climb interaction.

The Dab pen starts on the houseboat galley tray. Look at it and press E to pick it up. Equip it from the Backpack or assign it to a hotbar slot. Left click uses it on foot, and Q sets it down on a solid surface while equipped. The galley and dropped prop use the same model as the held pen. Carrying it between uses leaves it available in the Backpack, and the smoking sequence applies the existing high effect. T toggles the on-foot flashlight.

## Solo HUD verification

Use this checklist when changing or reviewing the shared HUD. Keep the run in a disposable solo trip and record the game revision, viewport size, selected destination, and before/after values.

1. Check a narrow and a wide window (the recorded pilot used 960 × 640 and 1440 × 600). Select a waypoint and note its displayed distance, the date/time, and FPS state. Press F3 to hide and show diagnostics; confirm the date/time stays in place and FPS appears only when enabled. Press F4 from both F3 states and record the graphics preset each time.
2. Open the pause menu. Record whether the live interaction hint and waypoint distance remain visible while it stays open. Resume and record both again. In solo mode the pause menu pauses the scene tree; do not treat a resumed-only check as a paused check.
3. With the same waypoint selected, pause again and change the player or vessel position in the disposable fixture. Compare the distance before and after while still paused, then resume and compare once more. Record whether the value refreshed while paused, only after resume, or stayed stale.
4. When a remote scene tree or equivalent inspector is available, record `get_global_rect()` for the FPS label, date/time label, objective, interaction instruction, and waypoint label at each viewport size. Compare each rectangle with the viewport bounds and note any clipping or overlap. Record the waypoint pin and distance-label placement as well. If runtime bounds or a fixture cannot be inspected, list that check as not run rather than inferring bounds from alignment.

The current source builds FPS in the shared top-right HUD, inserts the date/time above it, toggles FPS with F3, pauses solo play through the pause menu, and writes the selected waypoint distance from the player or vessel position. See [`cove.gd`](../../godot-cove/cove.gd) (`build_hud`, `_unhandled_input`), [`shannon_job.gd`](../../godot-cove/shannon_job.gd) (`update_clock`), [`river_pause.gd`](../../godot-cove/river_pause.gd) (`open`, `close`), and [`game_world.gd`](../../godot-cove/game_world.gd) (`update_hud`). The boat marker refresh path is in [`river_chart.gd`](../../godot-cove/river_chart.gd) (`update_boat`). These source references describe wiring, not a runtime pass.

The prior paired HUD pilot at `9097d61064bd0db0330832d1f355cb595bb0f5f7` used both viewport sizes and reported bounds passing. Its two variants disagreed on paused behavior: one kept the hint visible but left waypoint distance stale after a controlled position change; the other refreshed distance from 18.1 km to 4.0 km but lost the hint while paused. The exact Control rectangles and waypoint screen coordinates were not retained. See the [recorded HUD pilot](../codex-gameplay-benchmark/README.md#hud-pause-and-fps); do not treat those results as a fresh check of the current revision.

For issue #98, the procedure is documented. The current HUD acceptance checks remain unverified because the runtime attempt below did not reach the HUD.

### Issue #98 runtime attempt

On the PR #99 checkout (`833dbf4`), Godot 4.7.2 stable (`ed1daf0bf`) completed a fresh headless editor import with exit code 0. Before import, the title screen rendered with a fallback typeface; after import it rendered with the project's `Playfull Rocket` font. The initial screenshot was an import-state artifact, not a font change in this documentation patch.

I launched Play Solo in an empty slot using an isolated `%APPDATA%` directory. The title stayed on “Launching…” and the log repeatedly reported `Invalid access to property or key 'motor' on a base object of type 'Nil'` at `title_screen.gd:96`, before the loading completion path. Launching `res://game_world.tscn` directly stayed on the Godot splash while the map initialized; its log emitted “Loaded resource as image file” warnings from map construction. Neither attempt reached the HUD, so F3/F4, narrow/wide HUD placement, actual Control rectangles, pause/resume hint visibility, waypoint placement, and paused position-refresh behavior remain unverified at this revision. The gameplay launch issue is outside this notes-only change and was not modified here.

Verify relevant state transitions, gear switching, cast/retrieve/landing behavior, movement and camera, and local versus remote animation. Preserve other gear and interaction states. Check existing issues/PRs before changing shared input or animation code. Use screenshots and actual playtesting for visual acceptance where possible.
