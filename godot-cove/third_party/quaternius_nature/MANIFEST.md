# Riverside vegetation asset manifest

The models and textures in this directory are a curated subset of **Stylized Nature MegaKit, Standard edition** by Quaternius. Source: https://quaternius.com/packs/stylizednaturemegakit.html and https://store.godotengine.org/asset/quaternius/stylized-nature-megakit/. The downloaded Standard ZIP was 104,088,529 bytes, SHA-256 `298f6732b872e4cf7b30e6e7abf9641c7f6dc6b326df37ac089533ed7e3d58c9`. The archive's `License_Standard.txt` states CC0 1.0 Universal; the original license is retained here. Attribution is not required, but credit is given to Quaternius. No paid Source-edition models or shaders are included.

| Original and local glTF stem | Role | Modifications in this project |
| --- | --- | --- |
| `CommonTree_1`, `CommonTree_2` | Deciduous canopy, with pale birch-like treatment on variant 2 | Runtime scale, tint, foliage wind; variant 2 bark shader |
| `Pine_1`, `Pine_3` | Temperate evergreen canopy | Runtime scale, foliage wind |
| `Bush_Common` | Park shrubs | Runtime placement and scale |
| `Fern_1` | Understory | Runtime placement and scale |
| `Flower_3_Group`, `Flower_4_Group` | Park wildflowers | Runtime placement and scale |
| `Rock_Medium_1`, `Rock_Medium_2`, `Rock_Medium_3` | Natural rocks | Runtime placement and scale |

Each listed model retains its original `.gltf` and `.bin` filename. Its referenced textures (`Bark_NormalTree.png`, `Bark_NormalTree_Normal.png`, `Leaves_NormalTree_C.png`, `Leaves_TwistedTree_C.png`, `Leaf_Pine_C.png`, `Leaves.png`, `Flowers.png`, and `Rocks_Diffuse.png`) are also retained under their original filenames. Godot `.import` sidecars describe the imported resources. Only the opt-in Riverside profile instantiates these models. A local shader changes the appearance of selected tree surfaces; the original asset files are unmodified.

The grass, foliage, bark, sky, and water shader code in this project is original integration code. The following were researched as technique references, with no demo projects or copied shader files imported: [Malido's CC0 grass article](https://godotshaders.com/shader/stylized-multimesh-grass-shader/), [GDQuest's MIT stylized sky](https://github.com/gdquest-demos/godot-4-stylized-sky), and [Jtfinlay's CC0 water port](https://github.com/Jtfinlay/stylized-water-shader).
