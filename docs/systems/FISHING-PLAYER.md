# Fishing and player

- [fishing.gd](../../godot-cove/fishing.gd) extends cove.gd, preloads rig, water effects, fish species/stock, finder and guide, and includes movement, swimming, gear, interaction and session code. Start with `_physics_process`, `move_on_foot`, `equip_gear`, `interact` or the relevant fishing state transition.
- [fishing_rig.gd](../../godot-cove/fishing_rig.gd), [fish_species.gd](../../godot-cove/fish_species.gd), [river_stock.gd](../../godot-cove/river_stock.gd) are directly referenced by fishing.gd.
- For hands and props, locate current callers of `river_hands.gd`, `river_hand_actions.gd` and `crew_avatar.gd`; check both first-person and remote representations.

- Swim to the water side of a marina ladder and look at its rails for the E climb prompt. The player steps onto the floating dock. The Lamure swim float has its own climb interaction.

Verify relevant state transitions, gear switching, cast/retrieve/landing behavior, movement and camera, and local versus remote animation. Preserve other gear and interaction states. Check existing issues/PRs before changing shared input or animation code. Use screenshots and actual playtesting for visual acceptance where possible.
