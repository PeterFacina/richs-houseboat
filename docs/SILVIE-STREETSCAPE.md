# Silvie Street streetscape pass

The supplied May 2025 Street View traverse, Hillcrest view, and in-game view guided this local pass. Distances in `silvie_streetscape.gd` start at the Hillcrest end of surveyed road 63. Planting sites are approximate because the recording does not provide survey coordinates for individual trees or garden beds. Each proposed site moves by at most 7.5 m along the road and 4 m across it to avoid mapped driveways, walkways, buildings, existing trees, and the 16 Silvie property in pending PR #130.

The entrance keeps the existing park and playground clear. Two existing surveyed broadleaf trees on the residential side become pines to match the prominent conifers in the reference. A few mature trees and grouped shrubs fill gaps along the residential frontages while leaving open lawns between them. The road follows its existing surveyed centreline and junctions; only Silvie Street's half-width changes from 3.4 m to 3.1 m, with a narrower gravel shoulder and a local asphalt colour variation. Existing curbs at the Hillcrest approach remain, and no new sidewalks were added.

## Visual checks

The paired images use a 70° camera at 1.7 m eye height, 1600 × 900, OpenGL 3, looking along road 63 from the same positions before and after the change:

| From Hillcrest | Before | After |
| --- | --- | --- |
| 0 m | [baseline](screenshots/silvie-streetscape/before-0.jpg) | [updated](screenshots/silvie-streetscape/after-0.jpg) |
| 80 m | [baseline](screenshots/silvie-streetscape/before-80.jpg) | [updated](screenshots/silvie-streetscape/after-80.jpg) |
| 170 m | [baseline](screenshots/silvie-streetscape/before-170.jpg) | [updated](screenshots/silvie-streetscape/after-170.jpg) |

In one 180-frame render sample at the 170 m view, the clean `origin/main` archive measured 52.2 FPS and this branch measured 54.3 FPS with the same settings. That short sample does not establish a reliable performance change. The added deciduous trees and shrubs use the existing MultiMesh canopy renderer; pines use the existing instanced pine renderer. No new vegetation collision shapes were added. Godot's headless game startup and map build completed without script errors. A full manual vehicle drive along the street remains for review.

The mapped house facades are generic. They were left alone as requested, so architectural differences from Street View remain. The park and playground, Mario's house and yard, other streets, and global lighting were not changed.
