extends RefCounted

const Chain = preload("res://quest_chain.gd")
const Yard = preload("res://rich_story_yard.gd")
const Parts = preload("res://houseboat_restoration.gd")
const XP = preload("res://progression.gd")
const Boat = preload("res://houseboat.gd")
const ToolView = preload("res://repair_tool_view.gd")
const RoadGuide = preload("res://mowing_road_guide.gd")
const NPC_ID := "big_rich"
const NPC_NAME := "Big Rich"
const ACTION := "rich_story"
const VERSION := 2
const BITE_RATE := 1.15
const FUEL_SAVING := .10
const RETIREMENT := "She’s yours, boys. Insurance, gas, maintenance — all yours. I’ll be here Saturday morning. Make sure the fridge is stocked."
const KEEP_ROD := "Ah, just keep the rod, bud. I’ve got about six of the bloody things at home. But I want my boat back."
const QUESTS := [
	{"id": "story_fish", "title": "Gone Fishing", "cash": 18, "target": 5.0,
		"text": "Take my Princecraft and the old rod. I want three fish caught and the boat tied back up at the marina. Mind the ropes on your way out.",
		"steps": [["borrow_boat", "Borrow the Princecraft and old rod at Rich’s workbench."],
			["river_trip", "Untie the bow and stern lines with E. Take the helm, start the engine, and use W to add throttle."],
			["fish", "Press Space for neutral, leave the helm and land three fish with the old rod."],
			["boat_return", "Tie the bow and stern lines to marina cleats with E, then step ashore."],
			["checkin", "Talk to Rich to return the Princecraft."]]},
	{"id": "story_parts", "title": "New Legs", "cash": 16, "target": 5.0,
		"text": "Cal’s got a pair of used floats at his shop out toward Mackey. Take my GMC Envoy from the marina lot. Follow the arrows on Highway 17 and tell him Rich sent you.",
		"steps": [["borrow_car", "Borrow Rich’s GMC Envoy at the workbench."],
			["pontoon_pickup", "Follow the road arrows in the Envoy and talk to Cal at his workshop."],
			["unload", "Follow the arrows back to the marina. Park by the drop-off at Rich’s yard and unload."],
			["pontoons", "Hold E at the hull to install the pontoons."],
			["checkin", "Return the Envoy loan to Rich."]]},
	{"id": "story_repair", "title": "Safety Third", "cash": 17, "target": 4.0,
		"text": "You can borrow my welder, bud. Just make sure I get it back. Last fella I lent it to moved to Pembroke.",
		"steps": [["bench", "Pick up Rich’s welder and welding wire at the workbench."],
			["port_rail", "Equip the welder and hold E on the port railing."],
			["starboard_rail", "Weld the starboard railing."],
			["checkin", "Return the welder to Rich."]]},
	{"id": "story_engine", "title": "Dead in the Water", "cash": 18, "target": 5.0,
		"text": "Bring my wrench. The marina’s got plugs and a starter kit. If you find a ten mil socket in there, it’s mine now.",
		"steps": [["bench", "Pick up Rich’s wrench at his workbench."],
			["supplies", "Pick up the starter kit and plugs beside the marina shack."],
			["engine", "Equip the wrench and hold E at the outboard."],
			["engine_test", "Hold E at the repaired outboard to run a brief test."],
			["checkin", "Return the wrench to Rich."]]},
	{"id": "story_electrical", "title": "Let There Be Light", "cash": 20, "target": 7.0,
		"text": "Red to red, bud. The fridge is already full, so give her lights before someone goes rummaging in the dark.",
		"steps": [["bench", "Pick up Rich’s wire strippers at his workbench."],
			["supplies", "Collect the battery, wire and bulbs at the marina shack."],
			["wiring", "Equip the wire strippers and repair the wiring inside the front door."],
			["battery", "Fit the new battery beside the wiring panel."],
			["cabin_lights", "Fit the ceiling lamp inside the cabin."],
			["nav_lights", "Repair the navigation lights beside the front door."],
			["checkin", "Return the wire strippers to Rich."]]},
	{"id": "story_fuel", "title": "Running on Empty", "cash": 16, "target": 4.0,
		"text": "The red cans at the marina are mine. Fourteen bucks for enough fuel to get us out there. Check the whole lot over before we shove off.",
		"steps": [["fuel_pickup", "Collect the fuel can at the marina reserve. $14 crew cash."],
			["fuel_system", "Hold E at the tank on the aft deck to connect the hose and refuel."],
			["final_check", "Check the launch list at the yard workbench."],
			["checkin", "Return the fuel can and tell Rich the boat is ready."]]},
	{"id": "story_voyage", "title": "Maiden Voyage", "cash": 28, "target": 6.0,
		"text": "I’m coming with you. Take her past the marina, catch us a fish and bring her back here with the same number of holes.",
		"steps": [["launch", "Launch the restored houseboat from the yard workbench."],
			["rich_aboard", "Board at the public launch and meet Rich aboard."],
			["river_trip", "Untie both dock lines and drive out to fishing water beyond the marina."],
			["fish", "Land one fish aboard the houseboat."],
			["boat_return", "Tie the bow and stern lines to marina cleats with E, then step ashore."],
			["checkin", "Check in with Rich at the yard."]]},
	{"id": "story_retire", "title": "Rich’s Retirement Plan", "cash": 25, "target": 1.0,
		"text": "I still like going out in a boat. I just don’t like being the poor bugger who owns it. Got a minute?",
		"steps": [["checkin", "Sign over the houseboat with Rich."]]},
]

var campaign: Node3D
var game: Node3D
var yard := Yard.new()
var marker: Label3D
var guest_slots: Dictionary = {}
var work: Dictionary = {}
var rich_at_tennis := false
var equipped_tools: Dictionary = {}
var local_work := ""
var local_elapsed := 0.0
var local_finished := false
var effects := ToolView.new()
var test_sound: AudioStreamPlayer3D
var road_guide: RoadGuide
var next_route_check := 0.0


func setup(owner: Node3D, new_game: bool) -> void:
	campaign = owner
	game = owner.game
	if state().is_empty():
		state().managed = new_game
		state().shore_start = new_game
		state().version = VERSION
	normalize()
	game.river.add_child(yard)
	yard.setup(game.river, campaign.rich.STATION, campaign.rich.REST_YAW)
	game.eye.add_child(effects)
	effects.setup()
	test_sound = AudioStreamPlayer3D.new()
	test_sound.bus = &"Vehicles"
	test_sound.stream = preload("res://deep_river/princecraft/catch.wav")
	test_sound.max_distance = 28.0
	yard.add_child(test_sound)
	test_sound.position = yard.points.engine
	marker = yard.marker("", Vector3.ZERO)
	marker.reparent(campaign.rich, false)
	marker.pixel_size = .006
	marker.font_size = 58
	sync_world()


func state() -> Dictionary:
	return campaign.ledger.state.rich_story


func normalize() -> void:
	var saved := state()
	if int(saved.get("version", 0)) < VERSION:
		migrate(saved)
	for key: String in ["components", "flags", "loans", "upgrades"]:
		if not saved.get(key) is Dictionary:
			saved[key] = {}
	saved.step = clampi(int(saved.get("step", 0)), 0, QUESTS.size())
	saved.accepted = saved.get("accepted", false) == true and saved.step < QUESTS.size()
	restore_required_parts(saved)
	restore_loan_items(saved)
	saved.fish = clampi(int(saved.get("fish", 0)), 0, 3)
	saved.metres = clampf(float(saved.get("metres", 0)), 0, 500)
	saved.managed = saved.get("managed", false) == true
	saved.launched = saved.get("launched", false) == true and Parts.all_repaired(saved)
	saved.rod_owned = saved.get("rod_owned", false) == true or saved.step > 0
	saved.companion = saved.get("companion", false) == true and owns_houseboat()
	recount()


func restore_required_parts(saved: Dictionary) -> void:
	var requirements := {"pontoons": 1, "port_rail": 2, "starboard_rail": 2, "engine": 3,
		"wiring": 4, "battery": 4, "cabin_lights": 4, "nav_lights": 4, "fuel_system": 5}
	for id: String in Parts.COMPONENTS:
		if int(saved.step) > int(requirements[id]):
			Parts.install(saved, id)
		elif not saved.components.get(id, {}) is Dictionary:
			saved.components.erase(id)


func restore_loan_items(saved: Dictionary) -> void:
	if not saved.accepted:
		saved.loans.clear()
		return
	if saved.step == 0 and saved.flags.get("borrow_boat") == true:
		saved.loans.princecraft = true
		saved.loans.rod = true
	elif saved.step == 1 and saved.flags.get("borrow_car") == true:
		saved.loans.transport = true
	elif saved.step in [2, 3, 4] and saved.flags.get("bench") == true:
		saved.loans[tool_for_quest()] = true
	elif saved.step == 5 and saved.flags.get("fuel_pickup") == true:
		saved.loans.fuel_can = true


func migrate(saved: Dictionary) -> void:
	var old_step := int(saved.get("step", 0))
	saved.managed = saved.get("shore_start", false) == true
	saved.version = VERSION
	saved.components = {}
	saved.flags = {}
	saved.loans = {}
	saved.upgrades = {}
	saved.accepted = false
	saved.step = 0
	if old_step >= 2:
		saved.rod_owned = true
		saved.step = 1
	if old_step >= 5:
		for id: String in Parts.COMPONENTS:
			Parts.install(saved, id)
		saved.step = 6
		saved.launched = saved.get("yard_departed", false) or old_step >= 6
	if old_step >= 6:
		saved.step = 8 if old_step >= 7 else 7


func current() -> Dictionary:
	return Chain.current(state(), QUESTS)


func status() -> Chain.Status:
	return Chain.status(state(), QUESTS)


func owns_houseboat() -> bool:
	return int(state().get("step", 0)) == QUESTS.size()


func managed() -> bool:
	return state().get("managed", false)


func restrict_boat() -> bool:
	return managed() and not state().launched


func rod_allowed() -> bool:
	return not managed() or state().rod_owned or state().loans.has("rod")


func rod_label() -> String:
	if state().rod_owned:
		return "Big Rich’s Old Fishing Rod"
	if state().loans.has("rod"):
		return "Old Fishing Rod · Property of Big Rich"
	return "Fishing rod"


func repair_tool() -> String:
	for id: String in ["welder", "wrench", "strippers"]:
		if state().loans.has(id):
			return id
	return ""


func named_craft() -> bool:
	return game.vessel == campaign.houseboat or game.vessel == campaign.princecraft


func companion_aboard() -> bool:
	return state().companion and not rich_at_tennis and named_craft() and campaign.rich.hull == game.vessel


func set_rich_at_tennis(courtside: bool) -> void:
	if rich_at_tennis == courtside:
		return
	rich_at_tennis = courtside
	campaign.rich.visible = not courtside
	campaign.rich.stand.set_deferred("disabled", courtside)
	if courtside:
		campaign.rich.captions.hide()


func sync_world() -> void:
	if not is_instance_valid(marker):
		return
	var rich = campaign.rich
	var voyage_rider: bool = is_active("story_voyage") and state().launched and not flag("boat_return")
	var aboard_rich: bool = named_craft() and (state().companion or voyage_rider)
	if aboard_rich and game.vessel == campaign.princecraft:
		rich.mount(game.vessel, true, game.vessel.passenger_anchor())
	elif aboard_rich:
		rich.mount(campaign.houseboat, false)
	else:
		rich.mount(yard.rich_stand, false)
	marker.position = Vector3.UP * (1.58 if rich.seated else 1.99)
	marker.text = ""
	if status() != Chain.Status.FINISHED and not voyage_rider:
		marker.text = "!" if status() == Chain.Status.AVAILABLE else "?"
		marker.modulate = Color("#b0b4b0") if status() == Chain.Status.IN_PROGRESS else Color("#f7d56f")
	var active: Array[String] = []
	for id: String in yard.points:
		if not yard_action(id).is_empty():
			active.append(id)
	yard.apply_state(state(), active)
	sync_transport()
	if is_instance_valid(campaign.houseboat.restoration_model):
		campaign.houseboat.restoration_model.apply_state(state() if managed() else working_components())
		var rebuilt := Parts.upgrade_installed(state(), "outboard")
		campaign.houseboat.motor.scale = Vector3.ONE * (1.12 if rebuilt else 1.0)
	if restrict_boat() and game.vessel == campaign.houseboat:
		game.vessel.hide()
		game.vessel.collision_layer = 0
	elif game.vessel == campaign.houseboat:
		game.vessel.show()
		game.vessel.collision_layer = 1
	if is_instance_valid(game.backpack):
		game.backpack.set_story_gear(rod_allowed(), rod_label(), repair_tool())
	game.refresh_story_ui()


func setup_transport() -> void:
	road_guide = RoadGuide.new()
	game.add_child(road_guide)
	road_guide.setup(game.river)
	road_guide.extra_roads = [Yard.Workshop.DRIVE]
	road_guide.surface_height = game.river.driving_height
	if transport_loaned() and not campaign.crew.is_guest():
		restore_envoy_pose()
	sync_transport()


func sync_transport() -> void:
	if not is_instance_valid(game.marina_cars):
		return
	var fleet = game.marina_cars
	var loaded := transport_loaned() and flag("pontoon_pickup") and not flag("unload")
	fleet.cars[fleet.ENVOY].model.set_pontoons_loaded(loaded)


func transport_loaned() -> bool:
	return current().get("id", "") == "story_parts" and state().loans.get("transport", false)


func road_destination() -> Vector3:
	if not transport_loaned() or flag("unload"):
		return Vector3.INF
	return yard.points.unload if flag("pontoon_pickup") else yard.workshop.parking


func tick_transport(delta: float, has_input: bool) -> void:
	var fleet = game.marina_cars
	var target := road_destination()
	if not has_input or fleet.active != fleet.ENVOY or not target.is_finite():
		road_guide.reset()
		next_route_check = 0.0
		return
	var origin: Vector3 = fleet.cars[fleet.ENVOY].global_position
	next_route_check -= delta
	if next_route_check <= 0.0:
		road_guide.navigate(origin, target, game.public_works)
		next_route_check = .4
	road_guide.update_paint(origin)


func working_components() -> Dictionary:
	var model_state := {"components": {}, "upgrades": state().upgrades}
	for id: String in Parts.COMPONENTS:
		Parts.install(model_state, id)
	return model_state


func shore_arrival() -> bool:
	return state().get("shore_start", false) and (not state().launched or not owns_houseboat()) and campaign.dock < 0


func use_guest_slot(peer: int) -> int:
	if not guest_slots.has(peer):
		for index in range(1, yard.arrivals.size()):
			if not guest_slots.values().has(index):
				guest_slots[peer] = index
				break
	return guest_slots.get(peer, 1)


func arrive(slot: int) -> void:
	var at := yard.arrivals[clampi(slot, 0, yard.arrivals.size() - 1)]
	place_local(at, atan2(at.x - Yard.LOT.x, at.z - Yard.LOT.y), -.055)
	game.spawn_point = at


func place_local(at: Vector3, heading: float, tilt: float) -> void:
	game.set_swimming(false)
	game.player.global_position = at
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	game.yaw = heading
	game.pitch = tilt
	game.update_view()
	game.boarded = game.aboard()


func restore_local() -> void:
	var saved: Dictionary = campaign.ledger.state.player_position
	if saved.get("onboard", false) == true and game.vessel.visible:
		campaign.keep_player_on_deck(game.vessel, game.vessel.board_anchor())
		return
	if saved.get("feet") is Array and saved.feet.size() == 3:
		var at := Vector3(float(saved.feet[0]), float(saved.feet[1]), float(saved.feet[2]))
		if at.is_finite() and at.y > -.3 and absf(at.y - game.river.ground_height(at.x, at.z)) < 2.5:
			place_local(at, float(saved.get("yaw", 0.0)), clampf(float(saved.get("pitch", 0.0)), -1.38, 1.38))
			return
	if shore_arrival():
		arrive(0)


func remember_local() -> void:
	if game.aboard():
		campaign.ledger.state.player_position = {"onboard": true} if managed() else {}
	elif not game.swimming and not game.flying and not game.in_aircraft() and game.mower.rider == null \
			and game.marina_cars.active < 0 and game.player.is_on_floor() and not yard.contains_player(game.player.global_position):
		var at: Vector3 = game.player.global_position
		campaign.ledger.state.player_position = {"feet": [at.x, at.y, at.z], "yaw": game.yaw, "pitch": game.pitch}


func save_vehicle_poses() -> void:
	var boat: Boat = game.vessel
	if managed() and (state().launched or state().loans.has("princecraft")):
		state().boat_pose = [boat.center.x, boat.center.z, boat.heading, boat.departed]
	var fleet = game.marina_cars
	if is_instance_valid(fleet) and transport_loaned() and fleet.drivers[fleet.ENVOY] == 0:
		var car = fleet.cars[fleet.ENVOY]
		var at: Vector3 = car.global_position
		state().envoy_pose = [at.x, at.z, car.heading]


func restore_envoy_pose() -> void:
	var saved: Variant = state().get("envoy_pose", [])
	if not saved is Array or saved.size() != 3:
		return
	for value: Variant in saved:
		if not (value is float or value is int):
			return
	var at := Vector2(float(saved[0]), float(saved[1]))
	var heading := float(saved[2])
	if not at.is_finite() or not is_finite(heading) or not Rect2(Vector2.ZERO, game.river.extent).has_point(at):
		return
	game.marina_cars.park_envoy(Vector3(at.x, 0, at.y), heading)


func restore_boat_pose() -> bool:
	var saved: Variant = state().get("boat_pose", [])
	if not managed() or not saved is Array or saved.size() != 4 or restrict_boat() and game.vessel != campaign.princecraft:
		return false
	var at := Vector3(float(saved[0]), 0.0, float(saved[1]))
	var heading := float(saved[2])
	if not at.is_finite() or not is_finite(heading) or not game.vessel.can_place(at, heading):
		return false
	game.vessel.berth_at(at, heading)
	game.vessel.departed = saved[3] == true
	return true


func npc_in_reach(person: Dictionary) -> bool:
	if person.is_empty() or rich_at_tennis:
		return false
	if campaign.rich.hull == yard.rich_stand:
		return not person.onboard and campaign.rich.close_enough(person.at)
	return person.onboard and campaign.rich.hull == game.vessel and campaign.rich.close_enough(person.at)


func can_open() -> bool:
	return not game.driving and npc_in_reach(campaign.actor(campaign.crew.my_id())) 		and campaign.rich.focused(game.eye, game.player)


func near_target(person: Dictionary, point: Vector3, radius := 2.9) -> bool:
	return not person.is_empty() and not person.onboard and Vector3(person.at).distance_to(point) < radius


func is_active(id: String) -> bool:
	return status() == Chain.Status.IN_PROGRESS and current().get("id", "") == id


func flag(id: String) -> bool:
	return state().flags.get(id, false) == true


func mark(id: String) -> void:
	state().flags[id] = true
	recount()


func done(id: String) -> bool:
	if Parts.COMPONENTS.has(id):
		return Parts.repaired(state(), id)
	if id == "fish":
		return state().fish >= (3 if current().get("id") == "story_fish" else 1)
	return flag(id)


func recount() -> void:
	var saved := state()
	var quest := current()
	saved.progress = 0.0
	if not saved.accepted or quest.is_empty():
		return
	for objective: Array in quest.steps:
		if objective[0] != "checkin" and done(objective[0]):
			saved.progress += 1.0
	# The final check-in is completed atomically by the normal NPC turn-in.
	if saved.progress >= quest.target - 1.0:
		saved.progress = quest.target


func yard_action(id: String) -> String:
	if owns_houseboat() and id == "bench":
		return "upgrades"
	if status() != Chain.Status.IN_PROGRESS:
		return ""
	match current().id:
		"story_fish":
			if id == "bench" and not flag("borrow_boat"): return "borrow_boat"
			if id == "bench" and recovery_needed(): return "recover_princecraft"
		"story_parts":
			if id == "bench" and not flag("borrow_car"): return "borrow_car"
			if id == "bench" and can_recover_envoy(): return "recover_envoy"
			if id == "pontoon_pickup" and flag("borrow_car") and not flag(id): return id
			if id == "unload" and flag("pontoon_pickup") and not flag(id): return id
			if id == "pontoons" and flag("unload") and not done(id): return id
		"story_repair":
			if id == "bench" and not flag("bench"): return id
			if id in ["port_rail", "starboard_rail"] and flag("bench") and not done(id): return id
		"story_engine":
			if id == "bench" and not flag("bench"): return id
			if id == "supplies" and not flag(id): return id
			if id == "engine" and flag("bench") and flag("supplies"):
				if not done(id): return id
				if not flag("engine_test"): return "engine_test"
		"story_electrical":
			if id == "bench" and not flag("bench"): return id
			if id == "supplies" and not flag(id): return id
			if id in ["wiring", "battery", "cabin_lights", "nav_lights"] and flag("bench") and flag("supplies") and not done(id): return id
		"story_fuel":
			if id == "fuel_pickup" and not flag(id): return id
			if id == "fuel_system" and flag("fuel_pickup") and not done(id): return id
			if id == "bench" and done("fuel_system") and not flag("final_check"): return "final_check"
		"story_voyage":
			if id == "bench" and not state().launched: return "launch"
			if id == "bench" and recovery_needed(): return "recover_houseboat"
	return ""


func target_action() -> String:
	var person: Dictionary = campaign.actor(campaign.crew.my_id())
	if person.onboard or game.swimming or game.driving:
		return ""
	var selected := ""
	var nearest := INF
	for id: String in yard.points:
		var action := yard_action(id)
		var point: Vector3 = yard.points[id]
		if action.is_empty() or not campaign.aiming(point, 2.85, .84):
			continue
		var score: float = (point - game.eye.global_position).normalized().dot(game.eye.global_basis.z)
		if score < nearest:
			nearest = score
			selected = action
	if not state().launched:
		if near_target(person, yard.ladder_foot, 1.45) and ladder_focus(yard.ladder_top, nearest):
			return "climb"
		if near_target(person, yard.ladder_top, .86) and ladder_focus(yard.ladder_foot, nearest):
			return "descend"
	return selected


func ladder_focus(at: Vector3, other: float) -> bool:
	return campaign.aiming(at, 3.9, .67) and (at - game.eye.global_position).normalized().dot(game.eye.global_basis.z) < other


func hint(include_ownership := true) -> String:
	if can_open():
		return "E  Talk to Big Rich" if status() != Chain.Status.READY else "E  Check in with Big Rich"
	var action := target_action()
	if Parts.COMPONENTS.has(action):
		var component: Dictionary = Parts.COMPONENTS[action]
		var requirement := str(component.part)
		if not component.tool.is_empty():
			requirement = Parts.TOOLS[component.tool] + " + " + requirement
		var control := "Hold E" if can_use_tool(action) else "Equip %s in the Backpack" % Parts.TOOLS[component.tool]
		return "%s  ·  %s%s\nWorn  ·  %s" % [control, component.name,
			"  %d%%" % roundi(100.0 * local_elapsed / component.time) if local_work == action else "", requirement]
	match action:
		"climb": return "E  Climb the houseboat ladder"
		"descend": return "E  Climb down"
		"borrow_boat": return "E  Borrow Princecraft and rod · Property of Big Rich"
		"borrow_car": return "E  Borrow GMC Envoy · Property of Big Rich"
		"recover_envoy": return "E  Recover the Envoy to the marina parking lot"
		"bench": return "E  Take %s · Property of Big Rich" % tool_name_for_quest()
		"pontoon_pickup": return "E  Talk to Cal about the used pontoons"
		"unload": return "E  Unload pontoons at Rich’s yard"
		"supplies": return "E  Collect the replacement parts"
		"fuel_pickup": return "E  Borrow fuel can · $14 fuel"
		"final_check": return "E  Check the launch list"
		"engine_test": return "Hold E  ·  Test the outboard"
		"launch": return "E  Launch the houseboat"
		"recover_princecraft", "recover_houseboat": return "E  Ask Rich to recover the boat to the launch"
		"upgrades": return "E  View houseboat upgrades"
	if include_ownership and game.aboard() and state().loans.has("princecraft") and game.vessel == campaign.princecraft:
		return "Princecraft · Property of Big Rich"
	return ""


func tool_name_for_quest() -> String:
	return Parts.TOOLS.get(tool_for_quest(), "")


func tool_for_quest() -> String:
	return {"story_repair": "welder", "story_engine": "wrench", "story_electrical": "strippers"}.get(current().get("id", ""), "")


func interact() -> bool:
	if can_open():
		if is_active("story_voyage") and campaign.rich.hull == game.vessel:
			campaign.request(ACTION, [NPC_ID, current().id, "rich_aboard"])
		else:
			game.open_story_offer()
		return true
	var action := target_action()
	if action.is_empty():
		return false
	if action == "climb" or action == "descend":
		var target := yard.ladder_top if action == "climb" else yard.ladder_foot
		var origin := yard.ladder_foot if action == "climb" else yard.ladder_top
		var direction := target - origin
		place_local(target, atan2(-direction.x, -direction.z), -.12)
	elif action == "upgrades":
		game.open_story_offer(true)
	elif work_time(action) <= 0.0:
		campaign.request(ACTION, [NPC_ID, current().id, action])
	return true


func work_time(id: String) -> float:
	return float(Parts.COMPONENTS[id].time) if Parts.COMPONENTS.has(id) else (2.6 if id == "engine_test" else 0.0)


func can_use_tool(id: String) -> bool:
	var tool: String = Parts.COMPONENTS.get(id, {}).get("tool", "")
	return tool.is_empty() or (repair_tool() == tool and game.backpack.equipped == game.Backpack.REPAIR)


func update_repair(delta: float, input_allowed: bool, held: bool) -> bool:
	var tool_ready: bool = input_allowed and not game.cabin.busy() and game.can_use_fuel() \
		and not campaign.marina_fuel.is_local_holder()
	var action := target_action() if tool_ready else ""
	var valid := held and work_time(action) > 0.0 and can_use_tool(action)
	if not valid or local_work != action:
		if not local_work.is_empty():
			campaign.request(ACTION, [NPC_ID, current().get("id", ""), "cancel:" + local_work])
		local_work = ""
		local_finished = false
		local_elapsed = 0.0
	if valid:
		var duration := work_time(action)
		if local_work.is_empty():
			local_work = action
			campaign.request(ACTION, [NPC_ID, current().id, "start:" + action])
		local_elapsed += delta
		if local_elapsed >= duration + .10 and not local_finished:
			local_finished = true
			campaign.request(ACTION, [NPC_ID, current().id, "finish:" + action])
	var tool := repair_tool() if tool_ready and game.backpack.equipped == game.Backpack.REPAIR else ""
	effects.update_view(tool, valid and not local_finished, delta)
	return valid


func yard_point_for(action: String) -> String:
	match action:
		"borrow_boat", "borrow_car", "final_check", "launch", "recover_princecraft", "recover_houseboat", "recover_envoy": return "bench"
		"engine_test": return "engine"
	return action


func can_work(person: Dictionary, id: String) -> bool:
	var point_id := yard_point_for(id)
	if person.is_empty() or person.onboard or not yard.points.has(point_id) or yard_action(point_id) != id:
		return false
	var at: Vector3 = yard.points[point_id]
	var eye_level := Vector3(person.at) + Vector3.UP * 1.40
	return eye_level.distance_to(at) < 3.10


func tick_work() -> void:
	if campaign.crew.is_guest():
		return
	for peer: int in work.keys():
		var session: Dictionary = work[peer]
		if not can_work(campaign.actor(peer), session.id) or game.clock - session.at > work_time(session.id) + 2.0:
			work.erase(peer)


func perform_work(peer: int, verb: String, id: String, person: Dictionary) -> void:
	if verb == "cancel":
		if work.get(peer, {}).get("id") == id:
			work.erase(peer)
		return
	if work_time(id) <= 0.0 or not can_work(person, id):
		return
	var required: String = Parts.COMPONENTS.get(id, {}).get("tool", "")
	if not required.is_empty() and (not state().loans.has(required) or equipped_tools.get(peer) != required):
		return
	if verb == "start":
		for member: int in work:
			if member != peer and work[member].id == id:
				campaign.tell(peer, "A crewmate is already working on that part.")
				return
		work[peer] = {"id": id, "at": game.clock}
		return
	var session: Dictionary = work.get(peer, {})
	if verb != "finish" or session.get("id") != id or game.clock - float(session.at) < work_time(id) - .12:
		return
	work.erase(peer)
	if Parts.COMPONENTS.has(id):
		Parts.install(state(), id)
		if id == "fuel_system":
			campaign.ledger.state.fuel = campaign.Ledger.FUEL_CAPACITY
		if id == "battery":
			campaign.ledger.state.charge = .75
		recount()
		campaign.changed()
		campaign.tell(peer, "%s installed." % Parts.COMPONENTS[id].name)
	else:
		mark(id)
		campaign.changed()
		campaign.tell(peer, "Outboard test passed. It’ll run in the water.")
		campaign.tell(peer, "", campaign.STORY_ENGINE_TEST)


func allowed_to_invite() -> bool:
	var boat: Boat = game.vessel
	return named_craft() and boat.visible and absf(boat.speed) <= .65 and boat.center.distance_to(yard.rich_stand.position) < 175.0


func perform(peer: int, args: Variant, person: Dictionary) -> void:
	if not args is Array or args.size() != 3 or args[0] != NPC_ID or not args[1] is String or not args[2] is String:
		return
	var quest_id: String = args[1]
	var action: String = args[2]
	if action.begins_with("tool:"):
		var equipped := action.trim_prefix("tool:")
		if equipped.is_empty():
			equipped_tools.erase(peer)
			work.erase(peer)
		elif state().loans.has(equipped) and equipped == tool_for_quest():
			equipped_tools[peer] = equipped
		return
	if action in ["invite", "dismiss"]:
		if owns_houseboat() and npc_in_reach(person):
			invite_or_dismiss(peer, action)
		return
	if action.begins_with("upgrade:"):
		purchase_upgrade(peer, action.trim_prefix("upgrade:"), person)
		return
	var quest := current()
	if quest.is_empty() or quest.id != quest_id:
		return
	if action.contains(":"):
		perform_work(peer, action.get_slice(":", 0), action.get_slice(":", 1), person)
		return
	match action:
		"accept":
			if npc_in_reach(person) and Chain.accept(state(), QUESTS, quest_id):
				if quest_id == "story_voyage" and state().launched:
					state().flags.launch = true
				recount()
				campaign.changed()
				campaign.tell(peer, "Accepted  ·  " + quest.title)
		"complete":
			if npc_in_reach(person):
				turn_in(peer, quest)
		"rich_aboard":
			if is_active("story_voyage") and npc_in_reach(person) and person.onboard:
				mark("rich_aboard")
				campaign.changed()
				campaign.tell(peer, "Big Rich: I’m right here, bud. There’s good water beyond the marina.")
		_:
			if can_work(person, action):
				use_yard(peer, action)


func turn_in(peer: int, quest: Dictionary) -> void:
	if status() != Chain.Status.READY:
		return
	if quest.id == "story_fish" and not crew_ashore():
		campaign.tell(peer, "Bring everyone ashore to return the Princecraft.")
		return
	if quest.id == "story_fish" and state().loans.has("princecraft"):
		campaign.return_story_princecraft()
	if quest.id == "story_parts" and not envoy_parked(yard.points.unload, 23.0):
		campaign.tell(peer, "Park the Envoy by the pontoon drop-off and step out before returning it.")
		return
	finish_quest(peer, quest)


func complete_for_debug(peer: int, quest_id: String) -> void:
	var quest := current()
	if quest.is_empty() or quest.id != quest_id or status() != Chain.Status.READY:
		return
	if quest.id == "story_fish" and state().loans.has("princecraft"):
		campaign.return_story_princecraft()
	finish_quest(peer, quest)


func finish_quest(peer: int, quest: Dictionary) -> void:
	if not Chain.complete(state(), QUESTS, quest.id):
		return
	if quest.id == "story_parts":
		state().loans.erase("transport")
		state().erase("envoy_pose")
	if quest.id == "story_fish":
		state().rod_owned = true
	state().flags.clear()
	state().loans.clear()
	state().fish = 0
	state().metres = 0.0
	work.clear()
	equipped_tools.clear()
	campaign.ledger.state.cash += quest.cash
	for member: int in campaign.crew.people:
		XP.award(campaign.progression_for(member), quest.id, "rich_story/" + quest.id)
	if campaign.crew.mode == "solo":
		XP.award(campaign.progression_for(peer), quest.id, "rich_story/" + quest.id)
	campaign.changed()
	var reply := "%s complete  ·  $%d for the crew" % [quest.title, quest.cash]
	if quest.id == "story_fish":
		reply = KEEP_ROD
	elif quest.id == "story_retire":
		reply = RETIREMENT
	campaign.tell(peer, reply)


func envoy_parked(point: Vector3, radius: float) -> bool:
	var fleet = game.marina_cars
	var car = fleet.cars[fleet.ENVOY]
	return fleet.drivers[fleet.ENVOY] == 0 and absf(car.speed) < .65 and car.global_position.distance_to(point) <= radius


func can_recover_envoy() -> bool:
	return is_instance_valid(game.marina_cars) and not envoy_parked(game.marina_cars.LOT, 42.0) \
		and game.marina_cars.drivers[game.marina_cars.ENVOY] == 0


func crew_ashore() -> bool:
	for peer: int in campaign.crew.people:
		var person: Dictionary = campaign.actor(peer)
		if person.is_empty() or person.onboard:
			return false
	return not game.aboard()


func yard_clear() -> bool:
	for peer: int in campaign.crew.people:
		var person: Dictionary = campaign.actor(peer)
		if person.is_empty() or yard.contains_player(person.at):
			return false
	return not yard.contains_player(game.player.global_position)


func recovery_needed() -> bool:
	return game.vessel.visible and campaign.dock < 0 and not campaign.at_launch_berth(game.vessel)


func use_yard(peer: int, action: String) -> void:
	match action:
		"borrow_boat":
			if not crew_ashore() or not campaign.place_story_craft("princecraft"):
				campaign.tell(peer, "Clear the shared boat and launch berth first.")
				return
			state().loans.princecraft = true
			state().loans.rod = true
			campaign.tell(peer, "Princecraft and rod loaned. Find the boat at the public launch sign.")
		"borrow_car":
			state().loans.transport = true
			campaign.tell(peer, "The GMC Envoy is at the far end of the marina parking row. Press E at its door.")
		"recover_envoy":
			if not game.marina_cars.recover_envoy():
				campaign.tell(peer, "Clear the parking bay before recovering the Envoy.")
				return
			campaign.tell(peer, "The Envoy is back in its marina bay.")
		"pontoon_pickup":
			if not envoy_parked(yard.workshop.parking, 12.0):
				campaign.tell(peer, "Cal: Park Rich’s Envoy in the gravel lot and hop out. I’ll help with the straps.")
				return
			campaign.tell(peer, "Cal: They’re strapped in. The hatch stays up until you unload at Rich’s yard.")
		"unload":
			if not envoy_parked(yard.points.unload, 23.0):
				campaign.tell(peer, "Park the Envoy by the pontoon drop-off and step out to unload.")
				return
			campaign.tell(peer, "Pontoons unloaded. Hold E at the hull to install them.")
		"fuel_pickup":
			if campaign.ledger.state.cash < 14:
				campaign.tell(peer, "The reserve costs $14. Sell a catch or do a marina job.")
				return
			campaign.ledger.state.cash -= 14
			state().loans.fuel_can = true
		"final_check":
			if not Parts.all_repaired(state()):
				return
			campaign.tell(peer, "Floats, rails, outboard, lights and fuel checked. Ready to launch.")
		"launch":
			if not Parts.all_repaired(state()) or not yard_clear() or not crew_ashore():
				campaign.tell(peer, "Finish the repairs and get everyone off the boat before launch.")
				return
			if not campaign.place_story_craft("houseboat"):
				campaign.tell(peer, "The launch berth is obstructed.")
				return
			state().launched = true
			campaign.ledger.state.fuel = campaign.Ledger.FUEL_CAPACITY
			campaign.tell(peer, "Houseboat at the public launch. Meet Rich aboard.")
		"recover_princecraft", "recover_houseboat":
			if not crew_ashore() or not campaign.place_story_craft(action.trim_prefix("recover_")):
				campaign.tell(peer, "Wait until everyone is safely ashore before recovering the boat.")
				return
			campaign.tell(peer, "Boat recovered to the public launch.")
		"supplies":
			campaign.tell(peer, "Loaded the replacement parts for %s." % current().title)
		_:
			return
	mark(action)
	campaign.changed()
	if action in ["borrow_boat", "launch", "recover_princecraft", "recover_houseboat"] and campaign.crew.on_server():
		campaign.send_ship()


func invite_or_dismiss(peer: int, action: String) -> void:
	var invited := action == "invite"
	if invited == state().companion:
		return
	if invited and not allowed_to_invite():
		campaign.tell(peer, "Tie up a houseboat or Princecraft near the marina first.")
		return
	state().companion = invited
	campaign.changed()
	campaign.tell(peer, "Big Rich is aboard." if invited else "Big Rich will wait at the marina yard.")


func purchase_upgrade(peer: int, id: String, person: Dictionary) -> void:
	if not owns_houseboat() or not Parts.UPGRADES.has(id) or Parts.upgrade_installed(state(), id) \
			or not near_target(person, yard.points.bench):
		return
	var upgrade: Dictionary = Parts.UPGRADES[id]
	if campaign.ledger.state.cash < upgrade.cash or campaign.ledger.state.parts < upgrade.parts:
		campaign.tell(peer, "The crew needs $%d and %d parts." % [upgrade.cash, upgrade.parts])
		return
	campaign.ledger.state.cash -= upgrade.cash
	campaign.ledger.state.parts -= upgrade.parts
	state().upgrades[id] = true
	campaign.changed()
	campaign.tell(peer, upgrade.name + " installed.")


func record_catch(peer: int, at: Vector3) -> void:
	if not flag("river_trip"):
		return
	var on_loan: bool = is_active("story_fish") and game.vessel == campaign.princecraft
	var on_voyage: bool = is_active("story_voyage") and game.vessel == campaign.houseboat
	if (on_loan or on_voyage) and game.vessel.supports_deck(at) and not done("fish"):
		state().fish += 1
		recount()
		campaign.changed()
		var target := 3 if current().id == "story_fish" else 1
		campaign.tell(peer, "Catch logged  ·  %d / %d" % [state().fish, target])


func powered_distance(peer: int, metres: float, delta: float) -> void:
	if peer <= 0 or metres <= 0.0 or metres > 20.0 * delta or flag("river_trip"):
		return
	var fish_run: bool = is_active("story_fish") and flag("borrow_boat") and game.vessel == campaign.princecraft
	var voyage: bool = is_active("story_voyage") and flag("rich_aboard") and game.vessel == campaign.houseboat
	if not fish_run and not voyage:
		return
	state().metres += metres
	var center: Vector3 = game.vessel.center
	var launch: Vector3 = game.river.waterfront.wharf.launch_center(game.vessel.launch_half_beam())
	if state().metres >= (100.0 if voyage else 55.0) and center.distance_to(launch) >= (72.0 if voyage else 38.0):
		mark("river_trip")
		campaign.changed()
		campaign.tell(peer, "Fishing water reached. Stop the boat and cast.")


func docked(peer: int, site: int) -> void:
	if site != 0 or not done("fish"):
		return
	var craft_matches: bool = (is_active("story_fish") and game.vessel == campaign.princecraft) or 		(is_active("story_voyage") and game.vessel == campaign.houseboat)
	if craft_matches and not flag("boat_return"):
		mark("boat_return")
		campaign.tell(peer, "Tied up at the marina. Find Big Rich at his yard.")


func objectives_text(quest: Dictionary) -> String:
	var lines := PackedStringArray()
	for step: Array in quest.steps:
		var was_completed: bool = QUESTS.find(quest) < int(state().step)
		var current_task: bool = quest.id == current().get("id", "") and state().accepted
		var checked: bool = was_completed or (current_task and step[0] != "checkin" and done(step[0]))
		var counter := ""
		if step[0] == "fish" and current_task:
			counter = "  %d/%d" % [state().fish, 3 if quest.id == "story_fish" else 1]
		lines.append(("%s  %s%s" % ["✓" if checked else "·", step[1], counter]))
	return "\n".join(lines)


func progress_text() -> String:
	var quest := current()
	if quest.is_empty():
		return "Houseboat owned by your crew."
	match status():
		Chain.Status.AVAILABLE: return "Available  ·  Talk to Big Rich"
		Chain.Status.READY: return "Ready to turn in  ·  Talk to Big Rich"
	for objective: Array in quest.steps:
		if objective[0] != "checkin" and not done(objective[0]):
			return objective[1] + ("  %d/%d" % [state().fish, 3 if quest.id == "story_fish" else 1] if objective[0] == "fish" else "")
	return "Check in with Big Rich"
