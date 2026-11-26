# Gameplay polish and dynamic weather

## Camera, reticle, and characters

The camera blends small, collision-checked offsets after the on-foot, road vehicle, mower, or boat controller supplies its view. Mouse input still updates the heading directly. Camera offsets reset on large position changes and explicit recovery.

The center reticle uses the reach and aim checks from the existing interaction code. The project defines `interact` and `fish_interact` in Godot's InputMap. Prompts display the active binding. Some extended instructions and control reminders still show the default keys.

Players and Big Rich share procedural idle poses for breathing, weight shifts, glances, posture adjustments, stretching, scratching, pockets, and checking a phone. Shannon uses seated glances at her desk. Fishing, seated, helm, and equipped tool poses retain their activity-specific hand positions. Existing pose streams carry a gesture, elapsed time, and handedness.

## Weather and the world clock

The host or solo campaign owns all nine weather presets, wetness, transition timing, and lightning. The shared save stores the weather record with the calendar. Existing saves initialize to clear. The reliable join message includes both transition endpoints. Existing ship updates carry the calendar. Reliable weather updates run at about 1 Hz and are also sent when a preset or lightning event changes.

[river_weather.gd](../../godot-cove/river_weather.gd) defines transition weights, preset duration ranges, and transition length in game minutes. Fog is more likely around dawn. The `gameplay_strength` field scales the effects on bite timing, waves, grip, mowing speed, and incidental patrol timing. A strength of zero gives clear-weather gameplay values.

Weather layers on top of existing solar, sky, and water lighting. Rain gradually wets roads, and wind accelerates drying. Puddles are fixed shader patches. Reflections use existing sky, shore, and material shading. The river shader and wave sampler share wind-dependent amplitudes for the directional swell. Generated audio mixes rain on pavement, water and cover, wind, spatial thunder, and shoreline, hull and prop wash sounds. GPU rain stays near the camera and stops under cover. See [Boat and water](BOAT-WATER.md) for wake synchronization and local water settings.

## Settings and developer controls

Pause **Settings** saves camera smoothing, head bob, weather effects, rain particles, reflection quality, fog quality, and water detail per machine. Each control ranges from zero to one.

In a Godot debug build, the solo player or crew host can open **F2 → Environment and camera** to force a preset, set intensity and wind, advance the clock, trigger lightning, preview a Big Rich idle, toggle camera motion, or display the active reticle category.

## Riverbank Park residents

Five fictional residents walk short, authored routes on the Riverbank Park lookout during solo trips. [Riverbank Residents](../../godot-cove/riverbank_residents.gd) uses the campaign calendar to choose stops. Each resident has weekday and weekend timetables with a stable daily offset. When a trip loads, residents start at the stops for the saved time. After a clock change during play, they walk to their next stops. They pause when a physics body obstructs their route and continue when it clears. Distant idle avatars skip pose updates.

This first stage covers the lookout and uses the existing crew avatar appearance and animation. Residents remain at a park stop overnight. Homes, jobs, dialogue, relationships, weather reactions and shared crew simulation are future stages.

The full-world `res://tests/verify_riverbank_residents.gd` fixture checks schedules and movement on the actual lookout, including an obstruction that appears and clears. Use a fresh APPDATA directory containing `houseboat-142`.

## Implementation files

| Area | Main source files |
| --- | --- |
| Camera, controls, and HUD | `player_camera_motion.gd`, `context_reticle.gd`, `interaction_sight.gd`, `game_world.gd`, `cove.gd`, `project.godot`, `river_pause.gd` |
| Interactions and vehicles | `boat_amenities.gd`, `cabin_life.gd`, `marina_car.gd`, `marina_cars.gd`, `public_works.gd`, `river_helicopter.gd`, `river_landings.gd` |
| Idle poses and multiplayer | `character_idle.gd`, `crew_avatar.gd`, `rich_model.gd`, `rich_npc.gd`, `shannon_job.gd`, `multiplayer_session.gd` |
| Weather and persistence | `river_weather.gd`, `river_weather_fx.gd`, `deep_river_map.gd`, `game_campaign.gd`, `game_ledger.gd` |
| Weather rendering | `rain_streak.gdshader`, `weather_pavement.gdshaderinc`, `river_sky.gdshaderinc`, `water.gdshader`, `champlain_sidewalk.gdshader`, `deep_river_esso_asphalt.gdshader`, `deep_river_plaza_pavement.gdshader`, `regional_road.gdshader`, `town_street.gdshader`, `river_canopy.gdshader`, `river_reeds.gdshader` |
| Debug tools | `river_cheats.gd`, `environment_debug_controls.gd` |
| Documentation and verification | `docs/ARCHITECTURE.md`, this guide, and `tests/verify_gameplay_polish.gd` |

## Verification

Run `res://tests/verify_gameplay_polish.gd` with isolated APPDATA containing `houseboat-polish-`. It checks the nine presets, fade and wetness, save/reload, sight lines and shelter, camera mount/teleport, key rebinding, ENet late join, and host weather and idle updates. It also captures a local OpenGL weather sequence when run with a display.

A 120-frame static marina comparison in Godot 4.7.2 OpenGL at 960 × 540 on a GTX 1060 recorded 13.34 ms median and 14.27 ms p95 on the base revision, versus 13.57 ms median and 14.46 ms p95 with the update. This is a renderer smoke check for one viewpoint. In the separate weather capture, clear weather averaged 13.76 ms per frame and heavy rain averaged 14.57 ms. The existing Dab pen and calendar regression also exercised a host, two guests, and reconnect. The New Legs quest verification passed.

Puddles approximate pooling in the road shader. Local rain suppression covers the player under roofs and in vehicle cabs. From an outdoor view, individual drops still use an approximate emission volume around nearby roofs. The Compatibility renderer uses existing sky reflections and baked shore data. Existing quest schedules remain in effect during bad weather.

## References

The visual research covered SCS Software's wet roads and nighttime storms, Rockstar's fog and reflective surfaces, and Mojang's paired weather and clock commands. The implementation uses the existing sky and town assets plus procedural effects and poses.

- [American Truck Simulator 1.49](https://blog.scssoft.com/2023/11/american-truck-simulator-149-update.html)
- [Red Dead Redemption 2 on PC](https://www.rockstargames.com/newswire/article/75o941131a99k5/Red-Dead-Redemption-2-Now-Available-for-PC)
- [Grand Theft Auto V](https://www.rockstargames.com/gta-v)
- [Minecraft weather and time controls](https://www.minecraft.net/en-us/article/minecraft-commands)
