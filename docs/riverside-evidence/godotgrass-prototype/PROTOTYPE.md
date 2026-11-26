# GodotGrass reference prototype

This opt-in, 17 m radius patch is centred 42 m west and 12 m south of the marina pavilion. Run the game with `--riverside-poc --riverside-grass-prototype` to inspect it. The existing full Riverside cover remains available without the prototype flag; no wider deployment of the adapted grass has been made.

Reference: [2Retr0/GodotGrass](https://github.com/2Retr0/GodotGrass), commit `3785bec8e2567f57faf3b9a6c0e617af710d090a`, MIT copyright 2024 Ethan Truong. The adapted five-section, tapered blade geometry and wind-noise/per-blade variation techniques are documented and licensed by `godot-cove/third_party/godot_grass/LICENSE`. The demo's terrain heightmap, player interaction and other assets are not imported. Our instances take their heights directly from the existing terrain callback and pass through the existing geographic road, path, apron, reserved-area, shore, dock, and mowing-route checks.

Adjust `PROTOTYPE_DENSITY`, `PROTOTYPE_RADIUS`, and `PROTOTYPE_OFFSET` in `godot-cove/riverside_art.gd`. Adjust `blade_height`, `blade_width`, `wind_strength`, `root_color`, and `tip_color` in `godot-cove/riverside_godotgrass.gdshader`. The prototype keeps the existing 16 m MultiMesh chunks and distance fade. GodotGrass's abrupt tile LOD changes are not copied; its README notes visible switching. Performance and farther-distance LOD can be assessed after appearance approval.

The capture views are `grass_patch_close` and `grass_patch_overview` in `godot-cove/tests/capture_riverside.gd`. Captures use Godot 4.7.2 in Compatibility mode, 1280 × 720, Balanced graphics. The same capture script checks mowing index alignment, cut, and regrowth.

## Final tuning pass

After playtest feedback, blade height changed from 0.30 m to 0.20 m, width from 0.038 m to 0.034 m, and density from 100 to 112 blades/m². The original [close](grass_patch_close.png) and [overview](grass_patch_overview.png) captures remain for comparison with the [tuned close](tuning-after/grass_patch_close.png), [tuned overview](tuning-after/grass_patch_overview.png), and [tuned wide meadow](tuning-after/wide_meadow.png) captures. The tuned captures force clear weather in the capture script so saved weather cannot obscure the grass comparison; the game weather system was not changed.
