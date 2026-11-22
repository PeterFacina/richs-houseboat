extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Boat = preload("res://houseboat.gd")
const Avatar = preload("res://crew_avatar.gd")
const Camp = preload("res://crew_camp.gd")
const Catalog = preload("res://fish_species.gd")
const Hands = preload("res://river_hands.gd")
const Fish = preload("res://river_fish.gd")
const NET_READY := 6
const LANDED := 8
const PINE_REACH := 1
const NET_REACH := 2.95
const ITEM_NAMES := {"net": "landing net", "cooler": "ice chest"}

var game: Node3D
var campaign: Node3D
var camp := Camp.new()
var boat: Boat
var rack: Node3D
var models: Dictionary = {}
var view_items: Dictionary = {}
var wheel_grips: Array[Node3D] = []
var gear: Dictionary = {}
var older: Dictionary = {}
var spotlight: SpotLight3D
var lamp: Node3D
var lamp_glass: StandardMaterial3D
var lamp_operator := 0
var lamp_on := false
var brightness := 0.0
var lamp_target := Vector2(0, -.21)
var lamp_set := Vector2(0, -.21)
var dusk := false
var evening := 0.0
var loose_speed := Vector2.ZERO
var last_speed := 0.0
var last_bump := 0.0
var scoops: Dictionary = {}
var kept: Dictionary = {}
var reach_time := 1.0
var swing_time := 1.0
var pending_scoop := false
var snapshot_requested := false
var watch_flash := 0.0
var taking_picture := false
var flash: ColorRect
var last_net := ""
var carried_fish: Dictionary = {}
var transfer_until: Dictionary = {}
var transfers: Array[Dictionary] = []
var fish_models: Dictionary = {}
var fish_view: Node3D
var view_fish: Fish
var chest_open_until := 0.0
var fish_view_kind := ""
var wheel_blend := 0.0
var wheel_sleeves: Array[MeshInstance3D] = []
var view_hands: Dictionary = {}
var view_sleeves: Dictionary = {}
var fish_hands: Array[Node3D] = []


func setup(scene: Node3D, trip: Node3D) -> void:
	game = scene
	campaign = trip
	view_items.net = Tools.build_net(game.eye)
	view_items.cooler = Tools.build_cooler(game.eye)
	for name: String in view_items:
		var held: Node3D = view_items[name]
		view_hands[name] = []
		view_sleeves[name] = []
		for side: float in [-1.0, 1.0]:
			var hand: Node3D = game.rig.glove(side, false)
			view_hands[name].append(hand)
			view_sleeves[name].append(game.rig.make_sleeve(game.eye))
			hand.reparent(held, false)
			hand.position = Vector3(side * .012, -.042, .036) if name == "net" else Vector3(side * .36, .20, .032)
			if name == "cooler":
				hand.rotation = Vector3(.0, side * -.59, side * -.88)
			elif side < 0:
				hand.position.z = -.27
		held.hide()
	for side: float in [-1.0, 1.0]:
		var hand: Node3D = game.rig.glove(side, false)
		hand.reparent(game.eye, false)
		hand.position = Vector3(side * .29, -.61, -.35)
		hand.hide()
		wheel_grips.append(hand)
	fish_view = Node3D.new()
	game.eye.add_child(fish_view)
	fish_view.position = Vector3(0, -.38, -.67)
	view_fish = Fish.new()
	fish_view.add_child(view_fish)
	for side: float in [-1.0, 1.0]:
		var palm: Node3D = game.rig.glove(side)
		game.rig.HandModel.set_pose(palm, "carry")
		fish_hands.append(palm)
		palm.reparent(fish_view, false)
		palm.position = Vector3(side * .17, -.04, .01)
		palm.rotation = Vector3(.12, side * -.5, side * -.65)
	fish_view.hide()
	for side: float in [-1.0, 1.0]:
		wheel_sleeves.append(game.rig.make_sleeve(game.eye))
		wheel_sleeves.back().hide()
	if not campaign.ledger.state.camp_fish.is_empty():
		camp.course = campaign.ledger.state.camp_fish.duplicate(true)
		camp.cooking = true
		camp.cook_until = game.clock + 3.5
	flash = ColorRect.new()
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(flash)
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	flash.hide()
	add_child(camp)
	camp.build_at(game.river, campaign.landings.sites[PINE_REACH])
	fit(game.vessel)


func fit(vessel: Boat) -> void:
	if boat == vessel:
		return
	if is_instance_valid(rack):
		rack.hide()
		rack.queue_free()
	boat = vessel
	rack = Node3D.new()
	boat.add_child(rack)
	rack.name = "CrewDeck"
	models.net = Tools.build_net(rack)
	models.cooler = Tools.build_cooler(rack)
	var iron := Kit.paint(Color("#354344"), .59, .35)
	var brass := Kit.paint(Color("#b19a67"), .53, .30)
	var net_mark := home("net")
	for z: float in [-.54, -.17]:
		var at := net_mark + Vector3(.0, -.043, -z)
		Kit.box_at(rack, at, Vector3(.125, .065, .095), iron)
		Kit.box_at(rack, at + Vector3(-.052, .043, .0), Vector3(.025, .11, .06), brass)
	var cooler_mark := home("cooler")
	Kit.box_at(rack, cooler_mark + Vector3(0, -.022, 0), Vector3(.68, .043, .45), iron)
	var base := lamp_origin()
	Kit.box_at(rack, base + Vector3.DOWN * .13, Vector3(.29, .12, .23), iron)
	Tools.tube(rack, base + Vector3.DOWN * .129, base, .039, .036, brass)
	Kit.box_at(rack, lever_at() + Vector3.DOWN * .035, Vector3(.125, .072, .077), iron)
	Kit.box_at(rack, lever_at(), Vector3(.021, .059, .024), brass).rotation.x = .27
	lamp = Node3D.new()
	rack.add_child(lamp)
	lamp.position = base
	Tools.tube(lamp, Vector3(0, 0, .11), Vector3(0, 0, -.077), .119, .143, iron)
	Tools.tube(lamp, Vector3(0, 0, -.075), Vector3(0, 0, -.106), .146, .148, brass)
	lamp_glass = Kit.paint(Color("#c1c8b7"), .26, .10)
	lamp_glass.emission = Color("#ffe1a3")
	lamp_glass.emission_energy_multiplier = .91
	Tools.tube(lamp, Vector3(0, 0, -.103), Vector3(0, 0, -.112), .136, .136, lamp_glass)
	spotlight = SpotLight3D.new()
	lamp.add_child(spotlight)
	spotlight.position.z = -.127
	spotlight.light_color = Color("#ffe6b8")
	spotlight.light_energy = 4.1
	spotlight.spot_range = 46.0
	spotlight.spot_angle = 21.0
	spotlight.spot_attenuation = .75
	spotlight.spot_angle_attenuation = .77
	spotlight.hide()
	reset_gear()


func home(item: String) -> Vector3:
	if item == "net":
		return Vector3(-.83, .60, .52) if boat.skiff else Vector3(-1.17, 1.29, -.12)
	return Vector3(.49, .366, 1.19) if boat.skiff else Vector3(-.67, .755, -2.28)


func lever_at() -> Vector3:
	return Vector3(.67, .81, -.86) if boat.skiff else Vector3(.88, 1.08, -2.08)


func lamp_origin() -> Vector3:
	return lever_at() + Vector3(0, .125, -.124)


func reset_gear() -> void:
	for item: String in ITEM_NAMES:
		gear[item] = {"owner": 0, "at": home(item), "secured": true, "space": "boat"}
	older.clear()
	loose_speed = Vector2.ZERO
	lamp_on = false
	lamp_operator = 0
	lamp_target = Vector2(0, -.21)
	scoops.clear()


func held_by(peer: int) -> String:
	for item: String in ITEM_NAMES:
		if int(gear[item].owner) == peer:
			return item
	return ""


func own_item() -> String:
	return held_by(campaign.crew.my_id())


func hands_busy() -> bool:
	return not own_item().is_empty() or not held_fish(campaign.crew.my_id()).is_empty() or lamp_operator == campaign.crew.my_id()


func movement_scale() -> float:
	return .70 if own_item() == "cooler" else 1.0


func style() -> Dictionary:
	var hand := "fish" if not held_fish(campaign.crew.my_id()).is_empty() else own_item()
	if game.driving:
		hand = "helm"
	elif lamp_operator == campaign.crew.my_id():
		hand = "lamp"
	return {"tool": hand, "reach": sin(clampf(reach_time / .36, 0, 1) * PI),
		"scoop": sin(clampf(swing_time / .68, 0, 1) * PI)}


func aimed_item() -> String:
	var name := ""
	var distance := 2.12
	for item: String in ITEM_NAMES:
		if gear[item].owner != 0:
			continue
		var point := item_target(item)
		var span: float = game.eye.global_position.distance_to(point)
		if span < distance and campaign.aiming(point, 2.12, .92):
			name = item
			distance = span
	return name


func item_target(item: String) -> Vector3:
	var info: Dictionary = gear[item]
	var owner := int(info.owner)
	if owner != 0:
		var actor: Dictionary = campaign.actor(owner)
		return Vector3(actor.get("at", boat.global_position)) + Vector3.UP * .9
	var origin: Vector3 = info.at if info.get("space", "boat") == "world" else boat.to_global(info.at)
	return origin + Vector3.UP * .22


func target_peer() -> int:
	var reach := 2.36
	var choice := 0
	for peer: int in campaign.crew.avatars:
		var avatar: Avatar = campaign.crew.avatars[peer]
		if not avatar.riding or int(fishing_sample(peer).get("stage", 0)) != 0:
			continue
		var goal := avatar.global_position + Vector3.UP * 1.26
		var distance: float = goal.distance_to(game.eye.global_position)
		if distance < reach and campaign.aiming(goal, reach, .91):
			choice = peer
			reach = distance
	return choice


func interact() -> bool:
	if game.driving:
		return false
	var peer: int = campaign.crew.my_id()
	if game.clock < float(transfer_until.get(peer, 0)):
		return true
	var held := held_fish(peer)
	if not held.is_empty():
		if campaign.aiming(camp.griddle.global_position, 2.3, .84):
			campaign.request("crew_place_fish", null)
			return true
		if campaign.aiming(item_target("cooler"), 2.25, .84):
			campaign.request("crew_store_fish", null)
			return true
		game.notify_angling("E at the ice chest to store the fish, or E at the grill to cook it.", 3)
		return true
	if not game.aboard() and campaign.aiming(camp.griddle.global_position, 2.15, .88):
		campaign.request("crew_cook", null)
		return true
	if lamp_operator == peer:
		campaign.request("crew_lamp", null)
		return true
	var item := own_item()
	if not item.is_empty():
		var friend := target_peer()
		if friend != 0:
			campaign.request("crew_pass", friend)
			return true
		if game.aboard() and campaign.aiming(boat.to_global(home(item)), 2.25, .80):
			campaign.request("crew_drop", true)
			return true
		return false
	if game.aboard() and campaign.aiming(boat.to_global(lever_at()), 1.70, .96):
		campaign.request("crew_lamp", null)
		return true
	var selected := aimed_item()
	if not selected.is_empty():
		campaign.request("crew_grab", selected)
		return true
	return false


func input(event: InputEvent) -> bool:
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED or game.cabin.busy():
		return false
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT and own_item() == "net":
		start_scoop()
		return true
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	match event.physical_keycode:
		KEY_F:
			if not aimed_item().is_empty() and aimed_item() == "cooler" and not hands_busy():
				campaign.request("crew_take_fish", null)
				return true
		KEY_Q:
			if not held_fish(campaign.crew.my_id()).is_empty():
				game.notify_angling("Store the fish with E at the chest, or place it on the grill.", 3)
				return true
			if hands_busy():
				campaign.request("crew_drop", false)
				return true
		KEY_N:
			campaign.request("crew_dusk", null)
			return true
		KEY_H:
			if game.fishing == LANDED:
				campaign.request("crew_keep", game.hook_id)
				return true
		KEY_P:
			snapshot_requested = true
			return true
	return false


func start_scoop() -> void:
	if swing_time >= .60:
		swing_time = 0.0
		pending_scoop = true


func prompt() -> String:
	var peer: int = campaign.crew.my_id()
	if game.clock < float(transfer_until.get(peer, 0)):
		return "Handling fish…"
	if not held_fish(peer).is_empty():
		if campaign.aiming(camp.griddle.global_position, 2.3, .84):
			return "E  Place this fish on the grill" if not camp.cooking else "The grill is occupied. E at the chest to store this fish."
		if campaign.aiming(item_target("cooler"), 2.25, .84):
			return "E  Open lid and put fish in the ice chest"
		return "Carrying a fish  ·  E at ice chest to store / E at campfire to cook"
	if not game.aboard() and campaign.aiming(camp.griddle.global_position, 2.15, .88):
		return camp.instructions(campaign.ledger, game.clock)
	if game.driving:
		return ""
	if lamp_operator == peer:
		return "Move mouse to aim the bow light  ·  E release  ·  Q switch off"
	var item := own_item()
	if not item.is_empty():
		var pass_peer := target_peer()
		if pass_peer != 0:
			return "E  Pass %s to %s  ·  Q set down" % [ITEM_NAMES[item], campaign.crew.person(pass_peer).name]
		if item == "net":
			return "Left click to scoop a surfaced fish  ·  Q set down"
		return "Carry the ice chest ashore  ·  Q set down  ·  E at boat rack to secure"
	var selected := aimed_item()
	if selected == "cooler":
		return "E  Carry ice chest  ·  F open lid / take a fish (%d inside)" % campaign.ledger.state.ice_chest.size()
	return "E  Take the " + ITEM_NAMES[selected] if not selected.is_empty() else ""


func act(peer: int, action: String, argument: Variant, person: Dictionary) -> void:
	if action == "crew_evening_trip":
		if campaign.travel(peer, PINE_REACH, campaign.actor_site(person), true):
			dusk = true
			publish()
			campaign.tell(peer, "Evening at Pine Reach. Keep a fish with H, then cook it at the shore camp.")
		return
	if action in ["crew_take_fish", "crew_store_fish", "crew_place_fish"]:
		fish_action(peer, action, person)
		return
	if action == "crew_cook":
		if not person.onboard and can_reach(person, camp.griddle.global_position, 2.40):
			var message := camp.use(campaign.ledger, game.clock)
			remember_fish()
			publish()
			campaign.tell(peer, message)
		return
	if action == "crew_keep":
		if argument is int:
			keep_catch(peer, argument)
		return
	if action == "crew_dusk":
		dusk = not dusk
		publish()
		campaign.tell(peer, "Evening on the river." if dusk else "Daylight on the river.")
		return
	if person.is_empty() or campaign.captain == peer or not held_fish(peer).is_empty() or game.clock < float(transfer_until.get(peer, 0)):
		return
	var item := held_by(peer)
	match action:
		"crew_grab":
			if argument is String and gear.has(argument) and item.is_empty() and int(gear[argument].owner) == 0 \
					and lamp_operator != peer and can_reach(person, item_target(argument), 2.40):
				if int(fishing_sample(peer).get("stage", 0)) != 0:
					campaign.tell(peer, "Reel in first so you have both hands free.")
					return
				gear[argument].owner = peer
				gear[argument].secured = false
				publish()
				motion_to(peer, "reach")
		"crew_pass":
			if not item.is_empty() and argument is int and argument != peer:
				var recipient: Dictionary = campaign.actor(argument)
				if not recipient.is_empty() and held_by(argument).is_empty() and held_fish(argument).is_empty() \
						and game.clock >= float(transfer_until.get(argument, 0)) and campaign.captain != argument \
						and lamp_operator != argument and int(fishing_sample(argument).get("stage", 0)) == 0 \
						and can_reach(person, recipient.at + Vector3.UP * 1.15, 2.58):
					gear[item].owner = argument
					publish()
					motion_to(peer, "reach")
					motion_to(argument, "reach")
					campaign.tell(argument, "%s passed you the %s." % [campaign.crew.person(peer).name, ITEM_NAMES[item]])
		"crew_drop":
			if lamp_operator == peer:
				lamp_on = false
				lamp_operator = 0
				publish()
			elif not item.is_empty():
				var secured: bool = argument == true and can_reach(person, boat.to_global(home(item)), 2.45)
				drop(peer, item, person, secured)
		"crew_lamp":
			if not person.onboard:
				return
			if lamp_operator == peer:
				lamp_operator = 0
				publish()
			elif lamp_operator == 0 and item.is_empty() and can_reach(person, boat.to_global(lever_at()), 2.05):
				lamp_operator = peer
				lamp_on = true
				motion_to(peer, "reach")
				publish()
		"crew_scoop":
			if item == "net" and argument is Array and argument.size() == 2 and argument[0] is int and argument[1] is int:
				help_land(peer, argument[0], argument[1], person)


func can_reach(person: Dictionary, target: Vector3, metres: float) -> bool:
	return (Vector3(person.at) + Vector3.UP * 1.35).distance_squared_to(target) <= metres * metres


func floor_position(person: Dictionary, item: String) -> Vector3:
	var offset := boat.to_local(person.at)
	var facing := -Basis(Vector3.UP, float(person.get("yaw", boat.heading)) - boat.heading).z
	offset += facing * .49
	var widen := .79 if boat.skiff else 1.02
	offset.x = clampf(offset.x, -widen, widen)
	offset.z = clampf(offset.z, -1.73, 1.72) if boat.skiff else clampf(offset.z, -2.80, -.59)
	offset.y = (.365 if boat.skiff else .755) + (.034 if item == "net" else 0.0)
	return offset


func drop(peer: int, item: String, person: Dictionary, secured: bool) -> void:
	var ashore := not person.is_empty() and not bool(person.get("onboard", false))
	if ashore:
		var facing := -Basis(Vector3.UP, float(person.get("yaw", 0))).z
		var feet: Vector3 = person.at
		var safe: Vector3 = game.safety.find_near(feet + facing * .75, 1.0)
		if not safe.is_finite():
			campaign.tell(peer, "Move onto clear ground before setting down the chest.")
			return
		gear[item].at = safe
		gear[item].space = "world"
		secured = false
	else:
		gear[item].space = "boat"
		gear[item].at = home(item) if secured or person.is_empty() else floor_position(person, item)
	gear[item].owner = 0
	gear[item].secured = secured or person.is_empty()
	if item == "cooler":
		loose_speed = Vector2.ZERO
	publish()
	motion_to(peer, "reach")


func leave(peer: int) -> void:
	if carried_fish.has(peer):
		campaign.ledger.state.ice_chest.append(carried_fish[peer])
		carried_fish.erase(peer)
		remember_fish()
	for item: String in ITEM_NAMES:
		if gear[item].owner == peer:
			drop(peer, item, {}, true)
	scoops.erase(peer)
	kept.erase(peer)
	if lamp_operator == peer:
		lamp_operator = 0
		publish()


func ready_fish() -> Dictionary:
	var found := {}
	var nearest := NET_REACH
	for peer: int in campaign.crew.poses:
		var sample: Dictionary = campaign.crew.poses[peer]
		var line: Dictionary = sample.animation
		var at: Vector3 = line.get("fish", Vector3.INF)
		if Time.get_ticks_msec() - int(sample.received) < 850 and int(line.get("stage", -1)) == NET_READY \
				and at.is_finite() and campaign.aiming(at, nearest, .84):
			found = {"peer": peer, "hook_id": line.get("hook_id", -1)}
			nearest = game.eye.global_position.distance_to(at)
	return found


func help_land(helper: int, angler: int, hook: int, person: Dictionary) -> void:
	if helper == angler or hook <= 0 or int(scoops.get(angler, -1)) == hook:
		return
	var data := fishing_sample(angler)
	var at: Vector3 = data.get("fish", Vector3.INF)
	if int(data.get("stage", -1)) != NET_READY or int(data.get("hook_id", -1)) != hook \
			or not at.is_finite() or not can_reach(person, at, NET_REACH):
		campaign.tell(helper, "Wait for the fish to surface within reach of your net.")
		return
	scoops[angler] = hook
	if angler == campaign.crew.my_id():
		scoop_received(hook, helper)
	else:
		scoop_received.rpc_id(angler, hook, helper)
	campaign.tell(helper, "Fish in the net. %s landed it with your help." % campaign.crew.person(angler).name)


func fishing_sample(peer: int) -> Dictionary:
	if peer == campaign.crew.my_id():
		return game.capture_crew_pose()
	var sample: Dictionary = campaign.crew.poses.get(peer, {})
	return sample.animation if not sample.is_empty() and Time.get_ticks_msec() - int(sample.received) < 850 else {}


func keep_catch(peer: int, hook: int) -> void:
	if hook < 1 or int(kept.get(peer, -1)) == hook:
		return
	var data := fishing_sample(peer)
	if int(data.get("stage", -1)) != LANDED or int(data.get("hook_id", -1)) != hook:
		return
	var kind: int = data.get("species", -1)
	if kind < 0 or kind >= Catalog.all().size():
		return
	if not held_fish(peer).is_empty() or not held_by(peer).is_empty() or game.clock < float(transfer_until.get(peer, 0)):
		campaign.tell(peer, "Put down your gear or store your fish first.")
		return
	if campaign.ledger.state.ice_chest.size() + carried_fish.size() >= 8:
		campaign.tell(peer, "Your crew has eight fish. Cook a fish before keeping another.")
		return
	kept[peer] = hook
	var fish := {"species": kind, "length": clampi(int(data.get("length", 0)), 2, 200)}
	carried_fish[peer] = fish
	remember_fish()
	if peer == campaign.crew.my_id():
		catch_stored(hook)
	else:
		catch_stored.rpc_id(peer, hook)
	var source: Vector3 = data.get("fish", hand_position(peer))
	start_transfer(peer, "hold", fish, source, hand_position(peer))
	publish()
	campaign.tell(peer, "Holding %s. E at the ice chest to store it, or carry it to the grill." % Catalog.profile(kind).name)


@rpc("authority", "call_remote", "reliable")
func catch_stored(hook: int) -> void:
	if hook == game.hook_id and game.fishing == LANDED:
		game.release_line()


@rpc("authority", "call_remote", "reliable")
func scoop_received(hook: int, helper: int) -> void:
	game.accept_crew_scoop(hook, helper, str(campaign.crew.person(helper).get("name", "Your crewmate")))


func motion_to(peer: int, kind: String) -> void:
	if peer == campaign.crew.my_id():
		activity(kind)
	elif campaign.crew.on_server() and campaign.crew.people.has(peer):
		activity.rpc_id(peer, kind)


@rpc("authority", "call_remote", "reliable")
func activity(kind: String) -> void:
	if kind == "reach":
		reach_time = 0.0


func publish() -> void:
	if campaign.crew.on_server() and campaign.crew.people.size() > 1:
		gear_changed.rpc(gear, lamp_on, lamp_operator, dusk, camp.pack(), carried_fish)


func welcome(peer: int) -> void:
	gear_changed.rpc_id(peer, gear, lamp_on, lamp_operator, dusk, camp.pack(), carried_fish)


@rpc("authority", "call_remote", "reliable")
func gear_changed(items: Dictionary, lit: bool, operator: int, evening_enabled: bool, grill: Dictionary, fish_in_hands: Dictionary) -> void:
	gear = items
	lamp_on = lit
	lamp_operator = operator
	dusk = evening_enabled
	camp.unpack(grill)
	carried_fish = fish_in_hands


func moving_parts() -> Dictionary:
	return {"chest": gear.cooler.at, "lamp": lamp_target}


func update_moving_parts(data: Dictionary) -> void:
	if data.has("chest") and gear.cooler.get("space", "boat") == "boat" and not gear.cooler.secured and gear.cooler.owner == 0:
		gear.cooler.at = data.chest
	if data.has("lamp"):
		lamp_target = data.lamp


func tick(delta: float) -> void:
	reach_time += delta
	swing_time += delta
	if pending_scoop and swing_time >= .24:
		pending_scoop = false
		var fish := ready_fish()
		if fish.is_empty():
			game.notify_angling("Get a crewmate’s fish alongside, then aim the net at it.", 2.7)
		else:
			campaign.request("crew_scoop", [fish.peer, fish.hook_id])
	if not campaign.crew.is_guest():
		animate_gear(delta)
	evening = move_toward(evening, 1.0 if dusk else 0.0, delta * .76)
	game.river.set_evening(evening)
	camp.animate(game.clock, evening)
	lamp_set = lamp_set.lerp(lamp_target, 1.0 - exp(-delta * 15.0))
	lamp.rotation = Vector3(lamp_set.y, lamp_set.x, 0)
	var desired_light: float = smoothstep(.004, .065, campaign.ledger.state.charge) if lamp_on else 0.0
	brightness = move_toward(brightness, desired_light, delta * 4.1)
	lamp_glass.emission_enabled = brightness > .008
	lamp_glass.emission_energy_multiplier = .91 * brightness
	spotlight.visible = brightness > .008
	spotlight.light_energy = 4.1 * brightness
	game.river.set_bow_light(spotlight.global_position, -spotlight.global_basis.z, brightness)
	update_fish_visuals(delta)
	draw_crew_fish()
	if snapshot_requested:
		snapshot_requested = false
		take_picture()
	if watch_flash > 0.0:
		watch_flash = maxf(0.0, watch_flash - delta * 3.25)
		flash.color = Color(.92, .96, .88, watch_flash * .54)
		flash.visible = watch_flash > 0.0


func draw_crew_fish() -> void:
	if game.fish.visible or game.trophy.attracted:
		return
	var best := 38.0 * 38.0
	var selected: Avatar
	for peer: int in campaign.crew.avatars:
		var avatar: Avatar = campaign.crew.avatars[peer]
		if not is_instance_valid(avatar.fish) or not avatar.fish.visible or avatar.last_stage not in [4, NET_READY]:
			continue
		var distance: float = game.eye.global_position.distance_squared_to(avatar.fish.global_position)
		if distance < best:
			best = distance
			selected = avatar
	if selected != null:
		var at := selected.fish.global_position
		var heading := (-selected.fish.global_basis.z).slide(Vector3.UP).normalized()
		var depth: float = game.river.wave_height(at, game.clock) - at.y
		game.river.set_fish_shadow(at, heading, maxf(0.0, depth), selected.fish.metres)


func animate_gear(delta: float) -> void:
	if lamp_operator != 0:
		var operator: Dictionary = campaign.actor(lamp_operator)
		if bool(operator.get("onboard", false)) and can_reach(operator, boat.to_global(lamp_origin()), 3.30):
			lamp_target.x = clampf(wrapf(float(operator.get("yaw", boat.heading)) - boat.heading, -PI, PI), -1.38, 1.38)
			lamp_target.y = clampf(float(operator.get("pitch", -.20)), -.72, .22)
		else:
			lamp_operator = 0
			publish()
	for item: String in ITEM_NAMES:
		var owner: int = gear[item].owner
		if owner != 0 and campaign.actor(owner).is_empty():
			drop(owner, item, {}, true)
	var change := (boat.speed - last_speed) / maxf(delta, .001)
	last_speed = boat.speed
	if gear.cooler.owner != 0 or gear.cooler.secured or gear.cooler.get("space", "boat") == "world":
		return
	var heel := boat.wave_pose.z
	var rudder := boat.motor.steering
	var shove := Vector2(9.8 * -sin(heel) + rudder * boat.speed * .66, clampf(change, -4.2, 4.2) - sin(boat.wave_pose.y) * 5.0)
	loose_speed = (loose_speed + shove * delta) * exp(-delta * 1.9)
	var at: Vector3 = gear.cooler.at
	var wanted := at + Vector3(loose_speed.x, 0, loose_speed.y) * delta
	var width := .55 if boat.skiff else .96
	var travel := Vector2(-1.51, 1.53) if boat.skiff else Vector2(-2.65, -.51)
	at.x = clampf(wanted.x, -width, width)
	at.z = clampf(wanted.z, travel.x, travel.y)
	if not is_equal_approx(at.x, wanted.x) or not is_equal_approx(at.z, wanted.z):
		if loose_speed.length() > .52 and game.clock - last_bump > .30:
			game.effects.play_sound(boat.to_global(at), "cast", -13.0)
			last_bump = game.clock
		loose_speed *= -.19
	gear.cooler.at = at


func update_models(delta: float) -> void:
	update_wheel_grips(delta)
	var local: int = campaign.crew.my_id()
	for item: String in ITEM_NAMES:
		var info: Dictionary = gear[item]
		var owner: int = info.owner
		var model: Node3D = models[item]
		var view: Node3D = view_items[item]
		view.visible = owner == local
		for sleeve: MeshInstance3D in view_sleeves[item]:
			sleeve.visible = owner == local
		model.visible = owner != local
		if owner == local:
			pose_view(view, item, delta)
			continue
		var angles := Vector3.ZERO
		if item == "net":
			angles = Vector3(.07, PI, PI * .5) if info.secured else Vector3(-.06, .92, 0)
		var wanted := Transform3D(Basis.from_euler(angles), info.at)
		if info.get("space", "boat") == "world":
			wanted = boat.global_transform.affine_inverse() * wanted
		if owner != 0 and campaign.crew.avatars.has(owner):
			var avatar: Avatar = campaign.crew.avatars[owner]
			wanted = boat.global_transform.affine_inverse() * avatar.tool_grip
		var start: bool = not older.has(item) or int(older[item]) != owner
		older[item] = owner
		model.transform = wanted if start or owner != 0 or info.get("space", "boat") == "world" else model.transform.interpolate_with(wanted, 1.0 - exp(-delta * 15.0))
		if item == "cooler":
			var lid: Node3D = model.get_node("LidHinge")
			lid.rotation.x = lerpf(lid.rotation.x, -1.35 if game.clock < chest_open_until else 0.0, 1.0 - exp(-delta * 8))


func update_wheel_grips(delta: float) -> void:
	var wheel := boat.helm_wheel
	var active: bool = game.driving and is_instance_valid(wheel) and not game.cabin.hands_in_use()
	wheel_blend = move_toward(wheel_blend, 1.0 if active else 0.0, delta * 3.5)
	for index in wheel_grips.size():
		var hand := wheel_grips[index]
		hand.visible = wheel_blend > .01
		wheel_sleeves[index].visible = hand.visible
		if hand.visible and is_instance_valid(wheel):
			var side := float(index * 2 - 1)
			var radius := .139 if boat.skiff else .229
			# Hands stay at 9 and 3 o'clock instead of orbiting through the dashboard.
			var rim_angle := clampf(wheel.rotation.z * .22, -.58, .58)
			var grip := Vector3(side * radius * cos(rim_angle), side * radius * sin(rim_angle), .033)
			var unspun := grip.rotated(Vector3.BACK, -wheel.rotation.z)
			var wheel_basis := wheel.global_basis * Basis(Vector3.BACK, -wheel.rotation.z)
			# A rod grip's shaft axis is local Z. On the wheel it follows the
			# vertical rim tangent, with the backs of both hands facing the player.
			var world_grip := wheel_basis * Basis(Vector3.BACK, rim_angle) \
				* Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)
			var grip_center := Vector3(0, -.015, .035)
			var target: Vector3 = game.eye.to_local(wheel.to_global(unspun) - world_grip * grip_center)
			var rest := Vector3(side * .29, -.61, -.35)
			hand.position = hand.position.lerp(rest.lerp(target, smoothstep(0, 1, wheel_blend)), 1.0 - exp(-delta * 14))
			var rotation_target: Basis = game.eye.global_basis.inverse() * world_grip
			hand.quaternion = hand.quaternion.slerp(rotation_target.get_rotation_quaternion(), 1.0 - exp(-delta * 13))
			var wrist: Vector3 = hand.transform * game.rig.wrist_anchor(hand)
			game.rig.fit_cylinder(wheel_sleeves[index], wrist, Vector3(side * .39, -.64, -.12))


func pose_view(view: Node3D, item: String, delta: float) -> void:
	var reach := sin(clampf(reach_time / .36, 0, 1) * PI)
	var dip := smoothstep(.0, .28, swing_time) * (1.0 - smoothstep(.28, .69, swing_time))
	var clock: float = game.clock
	var walk: float = minf(1.0, game.player.velocity.slide(Vector3.UP).length() * .28)
	var bob: Vector3 = Vector3(sin(clock * 7.5) * .009, cos(clock * 7.5) * .010, 0) * walk * game.rig.motion_amount
	var rest := Vector3(.30, -.377 - reach * .08 - dip * .34, -.64 - dip * .28) if item == "net" else Vector3(0, -.64, -.59)
	rest.y -= .37 * (1.0 - smoothstep(.0, .28, reach_time))
	var turn := Vector3(.21 - dip * .74, -.23 + dip * .22, -.09) if item == "net" else Vector3(-.10, 0, -.04)
	var wanted := Transform3D(Basis.from_euler(turn), rest + bob)
	view.transform = wanted if last_net != item else view.transform.interpolate_with(wanted, 1.0 - exp(-delta * 24.0))
	last_net = item
	for index in 2:
		var side := float(index * 2 - 1)
		var hand: Node3D = view_hands[item][index]
		var point := Vector3(side * .363, .208, .025) if item == "cooler" else Vector3(0, -.01, .055 if side > 0 else -.27)
		Hands.align(hand, point, Basis.IDENTITY, "shaft")
		var wrist: Vector3 = game.eye.to_local(hand.to_global(Hands.wrist(hand)))
		game.rig.fit_cylinder(view_sleeves[item][index], wrist, Vector3(side * .4, -.66, -.12))


func take_picture() -> void:
	if DisplayServer.get_name() == "headless" or taking_picture:
		return
	taking_picture = true
	var show_hud: bool = game.hud.visible
	game.hud.hide()
	await RenderingServer.frame_post_draw
	var photo := get_viewport().get_texture().get_image()
	game.hud.visible = show_hud
	taking_picture = false
	var folder := "user://river_album"
	if DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(folder)) != OK:
		game.notify_angling("Couldn’t open the river photo album.", 3.0)
		return
	var stamp := Time.get_datetime_string_from_system().replace(":", "-")
	var name := "River %s-%03d.png" % [stamp, Time.get_ticks_msec() % 1000]
	if photo.save_png(folder.path_join(name)) == OK:
		camp.load_photo()
		watch_flash = .27
		game.notify_angling("Photo saved in the river album. " + name, 4.2)


func _process(delta: float) -> void:
	if is_instance_valid(boat) and not gear.is_empty():
		update_models(delta)


func held_fish(peer: int) -> Dictionary:
	return carried_fish.get(peer, {})


func restore_trip_fish() -> void:
	carried_fish.clear()
	for fish: Dictionary in campaign.ledger.state.held_fish.values():
		campaign.ledger.state.ice_chest.append(fish)
	campaign.ledger.state.held_fish.clear()
	camp.clear()
	if not campaign.ledger.state.camp_fish.is_empty():
		camp.place_fish(campaign.ledger.state.camp_fish, game.clock)


func remember_fish() -> void:
	campaign.ledger.state.held_fish.clear()
	for peer: int in carried_fish:
		var profile: String = campaign.crew.person(peer).get("profile", str(peer))
		campaign.ledger.state.held_fish[profile] = carried_fish[peer].duplicate(true)
	campaign.ledger.state.camp_fish = camp.course.duplicate(true) if camp.cooking else {}
	campaign.changed()


func hand_position(peer: int) -> Vector3:
	if peer == campaign.crew.my_id():
		return game.eye.to_global(Vector3(0, -.38, -.67))
	var person: Dictionary = campaign.actor(peer)
	return Vector3(person.get("at", boat.global_position)) + Vector3.UP * 1.05 \
		- Basis(Vector3.UP, float(person.get("yaw", 0))).z * .45


func fish_action(peer: int, action: String, person: Dictionary) -> void:
	if person.is_empty() or campaign.captain == peer or game.clock < float(transfer_until.get(peer, 0)):
		return
	var fish := held_fish(peer)
	var chest := item_target("cooler")
	if action in ["crew_take_fish", "crew_store_fish"]:
		if gear.cooler.owner != 0 or not held_by(peer).is_empty() or not can_reach(person, chest, 2.5):
			campaign.tell(peer, "Set the ice chest down nearby first.")
			return
	if action == "crew_take_fish":
		if not fish.is_empty() or int(fishing_sample(peer).get("stage", 0)) != 0:
			return
		if campaign.ledger.state.ice_chest.is_empty():
			campaign.tell(peer, "The ice chest is empty. H holds a newly landed fish.")
			return
		fish = campaign.ledger.state.ice_chest.pop_front()
		carried_fish[peer] = fish
		start_transfer(peer, "take", fish, chest, hand_position(peer))
	elif action == "crew_store_fish":
		if fish.is_empty():
			return
		campaign.ledger.state.ice_chest.append(fish)
		carried_fish.erase(peer)
		start_transfer(peer, "store", fish, hand_position(peer), chest)
	elif action == "crew_place_fish":
		if person.onboard or fish.is_empty() or not can_reach(person, camp.griddle.global_position, 2.5):
			return
		if not camp.place_fish(fish, game.clock):
			campaign.tell(peer, "Finish the fish already on the grill first.")
			return
		carried_fish.erase(peer)
		start_transfer(peer, "grill", fish, hand_position(peer), camp.griddle.global_position + Vector3.UP * .06)
	remember_fish()
	publish()
	var messages := {"crew_take_fish": "Fish in hand. E at the grill to lay it over the fire.",
		"crew_store_fish": "Fish stored. F at the ice chest takes a fish out.",
		"crew_place_fish": "Fish laid on the grill. Let the first side sizzle."}
	campaign.tell(peer, messages[action])


func start_transfer(peer: int, kind: String, fish: Dictionary, source: Vector3, target: Vector3) -> void:
	transfer_visual(peer, kind, fish, source, target)
	if campaign.crew.on_server() and campaign.crew.people.size() > 1:
		transfer_visual.rpc(peer, kind, fish, source, target)


@rpc("authority", "call_remote", "reliable")
func transfer_visual(peer: int, kind: String, fish: Dictionary, source: Vector3, target: Vector3) -> void:
	transfer_until[peer] = game.clock + .85
	if kind in ["take", "store"]:
		chest_open_until = game.clock + 1.5
	if kind == "grill":
		camp.transfer_until = game.clock + .85
	var model := Fish.new()
	add_child(model)
	model.select_species(int(fish.species), clampi(int(fish.length), 12, 65))
	transfers.append({"peer": peer, "kind": kind, "model": model, "start": game.clock, "from": source, "to": target})
	if peer == campaign.crew.my_id():
		reach_time = 0.0


func update_fish_visuals(delta: float) -> void:
	for index in range(transfers.size() - 1, -1, -1):
		var transfer: Dictionary = transfers[index]
		var progress := clampf((game.clock - float(transfer.start)) / .85, 0, 1)
		var destination: Vector3 = hand_position(transfer.peer) if transfer.kind in ["hold", "take"] else transfer.to
		var source: Vector3 = hand_position(transfer.peer) if transfer.kind in ["store", "grill"] else transfer.from
		var at: Vector3 = source.lerp(destination, smoothstep(0, 1, progress)) + Vector3.UP * sin(progress * PI) * .16
		transfer.model.pose(at, game.eye.global_basis.x, PI * .5, .0, 0)
		if progress >= 1:
			transfer.model.queue_free()
			transfers.remove_at(index)
	var local: int = campaign.crew.my_id()
	var fish := held_fish(local)
	var handling: bool = game.clock < float(transfer_until.get(local, 0))
	fish_view.visible = not fish.is_empty() or handling
	view_fish.visible = not fish.is_empty() and not handling
	var rest := Vector3(0, -.38, -.67)
	for transfer: Dictionary in transfers:
		if transfer.peer == local:
			var progress := clampf((game.clock - float(transfer.start)) / .85, 0, 1)
			var goal: Vector3 = transfer.to if transfer.kind in ["store", "grill"] else transfer.from
			var reach: Vector3 = (game.eye.to_local(goal) - rest).limit_length(.65)
			rest += reach * sin(progress * PI)
	fish_view.position = fish_view.position.lerp(rest, 1.0 - exp(-delta * 14))
	if view_fish.visible:
		var kind := "%s/%s" % [fish.species, fish.length]
		if kind != fish_view_kind:
			view_fish.select_species(int(fish.species), clampi(int(fish.length), 12, 65))
			fish_view_kind = kind
		var bob: float = sin(game.clock * 2) * .004 * game.rig.motion_amount
		fish_view.position = fish_view.position.lerp(Vector3(0, -.38 + bob, -.67), 1.0 - exp(-delta * 12))
		view_fish.pose(fish_view.global_position + game.eye.global_basis.x * view_fish.metres * .45, game.eye.global_basis.x, PI * .5, 0, 0)
	for peer: int in carried_fish:
		if peer == local:
			continue
		if not fish_models.has(peer):
			var model := Fish.new()
			add_child(model)
			fish_models[peer] = model
		var model: Fish = fish_models[peer]
		var data: Dictionary = carried_fish[peer]
		var signature := "%s/%s" % [data.species, data.length]
		if model.get_meta("held_kind", "") != signature:
			model.select_species(int(data.species), clampi(int(data.length), 12, 65))
			model.set_meta("held_kind", signature)
		model.visible = game.clock >= float(transfer_until.get(peer, 0))
		model.pose(hand_position(peer), Vector3.RIGHT, PI * .5, 0, 0)
	for peer: int in fish_models.keys():
		if not carried_fish.has(peer):
			fish_models[peer].queue_free()
			fish_models.erase(peer)


func hand_packet() -> Dictionary:
	var hands: Array = []
	var tool_mode := true
	if game.cabin.active >= 0 and game.cabin.holding.visible:
		hands = [game.cabin.left_hand, game.cabin.right_hand]
	elif game.driving:
		hands = wheel_grips
	elif not own_item().is_empty():
		hands = view_hands[own_item()]
	elif fish_view.visible:
		hands = fish_hands
	elif game.rig.visible:
		hands = [game.rig.reel_hand, game.rig.grip_hand]
	else:
		hands = game.rig.fist_hands
		tool_mode = false
	var result := {"hand_mode": 1 if tool_mode else 0}
	var inverse: Transform3D = game.eye.global_transform.affine_inverse()
	if not own_item().is_empty():
		result.tool_pose = inverse * view_items[own_item()].global_transform
	for index in 2:
		var hand: Node3D = hands[index]
		var key := "left" if index == 0 else "right"
		result["hand_" + key] = inverse * hand.global_transform
		if game.cabin.active >= 0 and game.cabin.holding.visible:
			result["hand_" + key].origin += game.cabin.Actions.world_offset(game.cabin.active, game.cabin.action_age)
		result["hand_" + key + "_visible"] = hand.is_visible_in_tree()
		result["hand_" + key + "_pose"] = hand.get("current_pose")
	return result
