extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Boat = preload("res://houseboat.gd")
const Avatar = preload("res://crew_avatar.gd")
const Camp = preload("res://crew_camp.gd")
const Catalog = preload("res://fish_species.gd")
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


func setup(scene: Node3D, trip: Node3D) -> void:
	game = scene
	campaign = trip
	view_items.net = Tools.build_net(game.eye)
	view_items.cooler = Tools.build_cooler(game.eye)
	for name: String in view_items:
		var held: Node3D = view_items[name]
		for side: float in [-1.0, 1.0]:
			var hand: Node3D = game.rig.glove(side)
			hand.reparent(held, false)
			hand.position = Vector3(side * .012, -.042, .036) if name == "net" else Vector3(side * .36, .20, .032)
			if name == "cooler":
				hand.rotation = Vector3(.0, side * -.59, side * -.88)
			elif side < 0:
				hand.position.z = -.27
		held.hide()
	for side: float in [-1.0, 1.0]:
		var hand: Node3D = game.rig.glove(side)
		hand.reparent(game.eye, false)
		hand.hide()
		wheel_grips.append(hand)
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
		gear[item] = {"owner": 0, "at": home(item), "secured": true}
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
	return not own_item().is_empty() or lamp_operator == campaign.crew.my_id()


func movement_scale() -> float:
	return .70 if own_item() == "cooler" else 1.0


func style() -> Dictionary:
	var hand := own_item()
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
	var model: Node3D = models[item]
	return model.to_global(Vector3(0, .22, 0) if item == "cooler" else Vector3(0, -.03, -.26))


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
	if not game.aboard():
		if campaign.aiming(camp.griddle.global_position, 2.15, .88):
			campaign.request("crew_cook", null)
			return true
		return false
	if game.driving:
		return false
	var crew_id: int = campaign.crew.my_id()
	if lamp_operator == crew_id:
		campaign.request("crew_lamp", null)
		return true
	var item := own_item()
	if not item.is_empty():
		var friend := target_peer()
		if friend != 0:
			campaign.request("crew_pass", friend)
			return true
		if campaign.aiming(boat.to_global(home(item)), 2.25, .80):
			campaign.request("crew_drop", true)
			return true
		return false
	if campaign.aiming(boat.to_global(lever_at()), 1.70, .96):
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
		KEY_Q:
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
	if not game.aboard():
		return camp.instructions(campaign.ledger, game.clock) if campaign.aiming(camp.griddle.global_position, 2.15, .88) else ""
	if game.driving:
		return ""
	var peer: int = campaign.crew.my_id()
	if lamp_operator == peer:
		return "Move mouse to aim the bow light  •  E release   •   Q switch off"
	var item := own_item()
	if not item.is_empty():
		var pass_peer := target_peer()
		if pass_peer != 0:
			return "E  Pass %s to %s   •   Q set down" % [ITEM_NAMES[item], campaign.crew.person(pass_peer).name]
		if item == "net":
			var reach := ready_fish()
			if not reach.is_empty():
				return "Left click to scoop %s’s fish    •    Q set down" % campaign.crew.person(reach.peer).name
			return "Aim at a crew member’s fish as it surfaces   •   Q set down"
		return "E at the rack to strap the ice chest down   •   Q set down here"
	if campaign.aiming(boat.to_global(lever_at()), 1.70, .96):
		return "E  Aim the bow spotlight"
	var target := aimed_item()
	return "E  Take the " + ITEM_NAMES[target] if not target.is_empty() else ""


func act(peer: int, action: String, argument: Variant, person: Dictionary) -> void:
	if action == "crew_evening_trip":
		if campaign.travel(peer, PINE_REACH, campaign.actor_site(person), true):
			dusk = true
			publish()
			campaign.tell(peer, "Evening at Pine Reach. Keep a fish with H, then cook it at the shore camp.")
		return
	if action == "crew_cook":
		if not person.onboard and can_reach(person, camp.griddle.global_position, 2.40):
			var message := camp.use(campaign.ledger, game.clock)
			campaign.changed()
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
	if not bool(person.get("onboard", false)) or campaign.captain == peer:
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
				if bool(recipient.get("onboard", false)) and held_by(argument).is_empty() and campaign.captain != argument \
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
	gear[item].at = home(item) if secured or person.is_empty() else floor_position(person, item)
	gear[item].owner = 0
	gear[item].secured = secured or person.is_empty()
	if item == "cooler":
		loose_speed = Vector2.ZERO
	publish()
	motion_to(peer, "reach")


func leave(peer: int) -> void:
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
	if campaign.ledger.state.ice_chest.size() >= 8:
		campaign.tell(peer, "The ice chest is full. Cook some of the catch at Pine Reach.")
		return
	kept[peer] = hook
	campaign.ledger.state.ice_chest.append({"species": kind, "length": clampi(int(data.get("length", 0)), 2, 200)})
	campaign.changed()
	if peer == campaign.crew.my_id():
		catch_stored(hook)
	else:
		catch_stored.rpc_id(peer, hook)
	campaign.tell(peer, "%s in the ice chest. Take it to the Pine Reach grill." % Catalog.profile(kind).name)


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
		gear_changed.rpc(gear, lamp_on, lamp_operator, dusk, camp.pack())


func welcome(peer: int) -> void:
	gear_changed.rpc_id(peer, gear, lamp_on, lamp_operator, dusk, camp.pack())


@rpc("authority", "call_remote", "reliable")
func gear_changed(items: Dictionary, lit: bool, operator: int, evening_enabled: bool, grill: Dictionary) -> void:
	gear = items
	lamp_on = lit
	lamp_operator = operator
	dusk = evening_enabled
	camp.unpack(grill)


func moving_parts() -> Dictionary:
	return {"chest": gear.cooler.at, "lamp": lamp_target}


func update_moving_parts(data: Dictionary) -> void:
	if data.has("chest") and not gear.cooler.secured and gear.cooler.owner == 0:
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
	update_models(delta)
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
		if owner != 0 and not bool(campaign.actor(owner).get("onboard", false)):
			drop(owner, item, {}, true)
	var change := (boat.speed - last_speed) / maxf(delta, .001)
	last_speed = boat.speed
	if gear.cooler.owner != 0 or gear.cooler.secured:
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
	update_wheel_grips()
	var local: int = campaign.crew.my_id()
	for item: String in ITEM_NAMES:
		var info: Dictionary = gear[item]
		var owner: int = info.owner
		var model: Node3D = models[item]
		var view: Node3D = view_items[item]
		view.visible = owner == local
		model.visible = owner != local
		if owner == local:
			pose_view(view, item, delta)
			continue
		var angles := Vector3.ZERO
		if item == "net":
			angles = Vector3(.07, PI, PI * .5) if info.secured else Vector3(-.06, .92, 0)
		var wanted := Transform3D(Basis.from_euler(angles), info.at)
		if owner != 0 and campaign.crew.avatars.has(owner):
			var avatar: Avatar = campaign.crew.avatars[owner]
			wanted = boat.global_transform.affine_inverse() * avatar.tool_grip
		var start: bool = not older.has(item) or int(older[item]) != owner
		older[item] = owner
		model.transform = wanted if start else model.transform.interpolate_with(wanted, 1.0 - exp(-delta * 22.0))


func update_wheel_grips() -> void:
	var wheel := boat.helm_wheel
	var visible_grip: bool = game.driving and is_instance_valid(wheel) and not game.cabin.hands_in_use()
	for index in wheel_grips.size():
		var hand := wheel_grips[index]
		hand.visible = visible_grip
		if visible_grip:
			var side := float(index * 2 - 1)
			var radius := .139 if boat.skiff else .229
			var target := wheel.to_global(Vector3(side * radius, .018, .033))
			hand.position = game.eye.to_local(target) + Vector3(-side * .028, .019, -.048)
			hand.rotation = Vector3(.27, side * -.64, side * -.31 + wheel.rotation.z * .48)


func pose_view(view: Node3D, item: String, delta: float) -> void:
	var reach := sin(clampf(reach_time / .36, 0, 1) * PI)
	var dip := smoothstep(.0, .28, swing_time) * (1.0 - smoothstep(.28, .69, swing_time))
	var clock: float = game.clock
	var walk: float = minf(1.0, game.player.velocity.slide(Vector3.UP).length() * .28)
	var bob := Vector3(sin(clock * 8.5) * .015, absf(cos(clock * 8.5)) * .018, 0) * walk
	var rest := Vector3(.30, -.377 - reach * .08 - dip * .34, -.64 - dip * .28) if item == "net" else Vector3(0, -.68, -.79)
	rest.y -= .37 * (1.0 - smoothstep(.0, .28, reach_time))
	var turn := Vector3(.21 - dip * .74, -.23 + dip * .22, -.09) if item == "net" else Vector3(-.10, 0, -.04)
	var wanted := Transform3D(Basis.from_euler(turn), rest + bob)
	view.transform = wanted if last_net != item else view.transform.interpolate_with(wanted, 1.0 - exp(-delta * 24.0))
	last_net = item


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
