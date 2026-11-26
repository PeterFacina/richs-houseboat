# Quests and character stories

[`quest_chain.gd`](../../godot-cove/quest_chain.gd) provides ordered quest state, acceptance, objective credit and completion using a supplied state dictionary and quest definitions. [`npc_quest_offer.gd`](../../godot-cove/npc_quest_offer.gd) displays the offer and emits the selected response. [`player_notebook.gd`](../../godot-cove/player_notebook.gd) displays quests, local characters, the fish index, the river chart and the catch log. Its quest page currently reads Big Rich's story directly.

## Big Rich's introductory chain

[`rich_story.gd`](../../godot-cove/rich_story.gd) defines the following quests and checks loans, work, objectives and turn-in. [`rich_npc.gd`](../../godot-cove/rich_npc.gd) provides Rich's character behavior and dialogue. [`rich_story_yard.gd`](../../godot-cove/rich_story_yard.gd) builds the yard and its interaction points, and [`houseboat_restoration.gd`](../../godot-cove/houseboat_restoration.gd) describes the boat's restoration components.

| Quest | Objective | Persistent ID |
| --- | --- | --- |
| Gone Fishing | Borrow Rich's Princecraft and rod, land three fish and return the tied boat | `story_fish` |
| New Legs | Borrow the GMC Envoy, follow the road arrows to Cal’s workshop toward Mackey, then deliver and install the pontoons and return the loan | `story_parts` |
| Safety Third | Borrow the welder, repair both railings and return the tool | `story_repair` |
| Dead in the Water | Collect the starter kit and plugs, repair and test the outboard, then return the wrench | `story_engine` |
| Let There Be Light | Repair the wiring, battery and lights, then return the wire strippers | `story_electrical` |
| Running on Empty | Buy and collect fuel, refuel and complete the launch check | `story_fuel` |
| Maiden Voyage | Launch, take Rich fishing, land a fish and return to the yard | `story_voyage` |
| Rich's Retirement Plan | Sign over the houseboat | `story_retire` |

[`game_campaign.gd`](../../godot-cove/game_campaign.gd) routes requests to the host and broadcasts state. Rich's turn-in logic updates restoration, ownership and rewards. [`game_ledger.gd`](../../godot-cove/game_ledger.gd) persists the campaign state, including Rich's quest progress. Player-specific awards use the shared [progression framework](PROGRESSION-ECONOMY.md).

During New Legs, borrow the Envoy at Big Rich’s workbench, then find it in the sixth marina parking bay. The Envoy uses the road guide already used by mowing jobs. The arrows lead west to [Cal’s workshop](../../godot-cove/pontoon_workshop.gd) and guide the loaded SUV back to the Pier Road yard. Park and step out to talk to Cal or unload at the drop-off. If the Envoy is missing, the workbench can recover it to the marina while it is unoccupied.

The existing `story_parts` objectives and loan flags drive the workshop rack, hatch and strapped cargo on each peer. A saved game with pontoons already collected resumes at delivery. Parked Envoy position is saved during the loan, and the host still validates pickup, delivery and turn-in.

## Additional characters

[`shannon_job.gd`](../../godot-cove/shannon_job.gd), [`shannon_model.gd`](../../godot-cove/shannon_model.gd) and [`shannon_voice.gd`](../../godot-cove/shannon_voice.gd) implement Shannon at Public Works and the repeatable mowing job. Shannon Lapping's independent questline is planned. Future chains can have their own state, quest givers and optional links to other characters. As those chains arrive, evaluate how to route their state and notebook entries through the existing framework. Consider main and side quests, repeatable and optional objectives, equipment, skill, research and economic requirements, and persistent multiplayer participation.
