extends SceneTree

const Crew = preload("res://multiplayer_session.gd")
const Cycle = preload("res://river_day_cycle.gd")
const Ledger = preload("res://game_ledger.gd")
const Backpack = preload("res://river_backpack.gd")
const Props = preload("res://cabin_props.gd")

var game
var campaign
var failed := false
var snapshots := {}
var guest_ship := {}


func _initialize() -> void:
	call_deferred("exercise")


func check(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true


func verify_cycle() -> void:
	for minute: float in [0.0, Cycle.DAWN, Cycle.SUNRISE, Cycle.MORNING, Cycle.MIDDAY, Cycle.AFTERNOON,
			Cycle.GOLDEN_HOUR, Cycle.SUNSET, Cycle.TWILIGHT, Cycle.NIGHT]:
		var before := Cycle.sample(minute - .01)
		var after := Cycle.sample(minute + .01)
		check(Vector3(before.sun).distance_to(after.sun) < .001, "Sun position jumps at %s" % minute)
		check(is_equal_approx(float(before.ambient_energy), float(after.ambient_energy)), "Ambient jumps at %s" % minute)
		check(Cycle.sample(minute) == Cycle.sample(minute + 1440), "Cycle differs on the next day")
	var ledger: Dictionary = campaign.ledger.state
	ledger.work_minutes = 780.0
	game.shannon_job.update_clock(5.0)
	check(is_equal_approx(float(ledger.work_minutes), 784.0), "Clock speed changed")
	var noon_sun: Vector3 = game.river.sun_direction
	check(game.river.landscape_light.visible and not game.river.moon_light.visible, "Noon direct light did not apply")
	check(not game.river.town_hall.exterior_lights[0].visible, "Street or building light stayed on at noon")
	ledger.work_minutes = 1320.0
	game.shannon_job.update_clock(0.0)
	check(not game.river.landscape_light.visible and game.river.moon_light.visible, "Night moonlight did not apply")
	check(game.river.town_hall.exterior_lights[0].visible, "Street or building light stayed off at night")
	check(noon_sun.dot(game.river.sun_direction) < 0.0, "Night did not move the sun under the horizon")
	for water: ShaderMaterial in [game.river.near_water, game.river.far_water, game.river.headpond_water]:
		check(water.get_shader_parameter("sun_direction") == game.river.sun_direction
			and float(water.get_shader_parameter("moon_strength")) > .0, "Water disagrees with the sky")
	print("Clock rate, phase boundaries, midnight, sun and moon, lamps, and water uniforms checked.")


func aim(at: Vector3) -> void:
	game.eye.look_at(at)


func verify_pen() -> void:
	var pen: Node3D = game.dab_pen
	var boat: Node3D = game.vessel
	campaign.story.state().launched = true
	campaign.story.sync_world()
	await physics_frame
	game.player.global_position = boat.to_global(Vector3(.43, .79, .83))
	await physics_frame
	var shelf: Vector3 = pen.pickup_point()
	if not shelf.is_finite():
		check(false, "The launched houseboat does not expose its galley pen")
		return
	aim(shelf)
	pen.update_focus(true)
	check(pen.focused and game.aboard(), "The pen cannot be targeted from the houseboat floor")
	var peer: int = campaign.crew.my_id()
	pen.request("pickup")
	check(pen.owns(peer) and not pen.shelf.visible and game.backpack.shortcuts.has(Backpack.PEN), "Pickup did not populate Backpack and hotbar")
	if not pen.owns(peer):
		return
	pen.request("drop")
	check(pen.space() == "houseboat" and pen.dropped.get_parent() == boat, "Deck drop did not attach to the houseboat")
	aim(pen.pickup_point())
	pen.update_focus(true)
	check(pen.focused, "Cannot target a pen dropped on the houseboat")
	pen.request("pickup")
	game.equip_gear(Backpack.PEN)
	check(game.backpack.equipped == Backpack.PEN, "Cannot re-pick and equip pen")
	var ground: Vector3 = game.river.town_hall.to_global(Vector3(0, 0, 27))
	ground.y = game.river.ground_height(ground.x, ground.z)
	var at: Vector3 = game.safety.find_near(ground, 4.0)
	if not at.is_finite():
		at = game.safety.find_near(game.campaign.landings.sites[0].stand, 8.0)
	check(at.is_finite(), "No dry ground found for portable use")
	if not at.is_finite():
		return
	game.player.global_position = at
	await physics_frame
	game.cabin.pen_in_hand = true
	game.cabin.update_action(.02)
	check(game.capture_crew_pose().get("use_item") == Props.Item.PEN, "Equipped pen is missing from player pose")
	for index in 2:
		game.cabin.use_pen()
		game.cabin.update_action(1.02)
		var pose: Dictionary = game.capture_crew_pose()
		check(pose.get("use_item") == Props.Item.PEN and pose.get("hand_right_visible"), "Pen use pose was not published")
		game.cabin.update_action(1.4)
		game.cabin.update_action(1.0)
		check(game.cabin.high_until > game.cabin.clock and pen.owns(peer), "Use removed the pen or lost the high")
	var restored := Ledger.new()
	check(restored.load_file() and restored.state.dab_pen.get("space") == "carried", "Carried pen did not survive the save")
	pen.request("drop")
	check(not pen.owns(peer) and pen.dropped.visible and game.backpack.equipped == Backpack.NONE, "Drop failed to clear inventory")
	check(restored.load_file() and restored.state.dab_pen.get("space") == "world", "Dropped pen did not survive the save")
	var on_ground: Vector3 = pen.pickup_point()
	game.player.global_position = at + Vector3(.55, 0, .48)
	await physics_frame
	aim(on_ground)
	pen.update_focus(true)
	check(pen.focused, "Dropped pen cannot be targeted")
	pen.request("pickup")
	check(pen.owns(peer) and not pen.dropped.visible, "Dropped pen could not be picked up again")
	pen.request("drop")
	print("Solo shelf focus, equip, repeat use ashore, pose, high, save, drop and re-pickup checked.")


func endpoint(label: String) -> Crew:
	var group := Node.new()
	group.name = label
	root.add_child(group)
	var api := SceneMultiplayer.new()
	api.root_path = group.get_path()
	set_multiplayer(api, group.get_path())
	var crew := Crew.new()
	crew.name = "Crew"
	crew.boat = game.vessel
	crew.local_profile = label.md5_text()
	crew.progression_secret = label.sha256_text().left(32)
	group.add_child(crew)
	return crew


func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()


func verify_network() -> void:
	var original: Crew = campaign.crew
	var host := endpoint("Host")
	campaign.crew = host
	host.requested.connect(func(peer: int, action: String, value: Variant):
		if action == "connected":
			host.share_state.rpc_id(peer, campaign.snapshot_for(peer), campaign.dock, 0, 1)
		else:
			campaign.remote_request(peer, action, value))
	host.host("Host")
	host.start_session()
	var guest := endpoint("Guest")
	var other := endpoint("Other")
	for client: Crew in [guest, other]:
		var key := str(client.get_parent().name)
		client.state_received.connect(func(data, _dock, _captain, _revision): snapshots[key] = data.dab_pen)
		client.join(key, "127.0.0.1")
	guest.ship_received.connect(func(data: Dictionary): guest_ship = data)
	var ready := await until(func(): return snapshots.size() == 2)
	check(ready, "Guests did not receive initial pen positions")
	if ready and game.dab_pen.space() == "world":
		var target: Vector3 = game.dab_pen.pickup_point()
		var feet := target + Vector3(.32, -.025, .5)
		var look := Basis.looking_at(target - (feet + Vector3.UP * 1.48)).get_euler()
		var peer := guest.my_id()
		guest.pose.rpc_id(1, feet, look.y, false, {"pitch": look.x})
		other.pose.rpc_id(1, feet, look.y, false, {"pitch": look.x})
		check(await until(func(): return host.poses.has(peer) and host.poses.has(other.my_id())), "Guest poses did not reach host")
		var serial := int(snapshots.Guest.serial)
		guest.order.rpc_id(1, game.dab_pen.ACTION, ["pickup", serial])
		guest.order.rpc_id(1, game.dab_pen.ACTION, ["pickup", serial])
		check(await until(func(): return bool(snapshots.Guest.owned) and snapshots.Other.space == "carried"),
			"Authoritative guest pickup did not reach both clients")
		other.order.rpc_id(1, game.dab_pen.ACTION, ["pickup", serial])
		other.order.rpc_id(1, game.dab_pen.ACTION, ["drop", serial + 1])
		await create_timer(.15).timeout
		check(not snapshots.Other.owned and not snapshots.Guest.has("owner") and int(snapshots.Guest.serial) == serial + 1,
			"Duplicate or foreign request changed ownership")
		var pose := {"use_item": Props.Item.PEN, "use_prop": Transform3D.IDENTITY, "use_age": 2.5, "use_serial": 7, "flashlight": true}
		guest.pose.rpc_id(other.my_id(), feet, look.y, false, pose)
		check(await until(func(): return other.poses.has(peer)), "Peer did not receive pen pose")
		other.tick(.016, game.player, false, 0.0, game.capture_crew_pose, game.clock, game.eye.global_position)
		check(other.avatars.has(peer), "Guest avatar was not created")
		if other.avatars.has(peer):
			var avatar = other.avatars[peer]
			check(avatar.use_props[Props.Item.PEN].visible and avatar.smoke_serial == 7, "Avatar did not show pen and exhale")
			check(is_instance_valid(avatar.flashlight) and avatar.flashlight.visible, "Guest flashlight did not replicate")
		campaign.send_ship()
		check(await until(func(): return guest_ship.get("work_minutes") == campaign.ledger.state.work_minutes),
			"Host work minutes did not replicate")
		var host_ledger: Dictionary = campaign.ledger.state
		campaign.ledger.state = host_ledger.duplicate()
		campaign.ledger.state.work_minutes = 480.0
		campaign.crew = guest
		campaign.remote_ship = guest_ship
		game.shannon_job.update_clock(.1)
		check(campaign.ledger.state.work_minutes == host_ledger.work_minutes and game.river.moon_light.visible,
			"Guest did not apply the host's clock jump and lighting")
		campaign.crew = host
		campaign.ledger.state = host_ledger
		campaign.remote_ship = {}
		guest.stop()
		check(await until(func(): return not host.people.has(peer)), "Guest did not disconnect")
		snapshots.erase("Guest")
		guest.join("Guest", "127.0.0.1")
		check(await until(func(): return snapshots.has("Guest") and bool(snapshots.Guest.owned)), "Owner lost the pen on reconnect")
	else:
		check(false, "No dropped pen for the network fixture")
	guest.stop()
	other.stop()
	host.stop()
	campaign.crew = original
	for crew: Crew in [guest, other, host]:
		crew.get_parent().queue_free()
	print("ENet host, two guests, one owner, repeated requests, avatar exhale, host clock, and reconnect checked.")


func exercise() -> void:
	if not "houseboat-120-" in OS.get_user_data_dir().to_lower() or FileAccess.file_exists(Ledger.SAVE):
		push_error("Run with a fresh isolated user-data directory containing houseboat-120-.")
		quit(2)
		return
	game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	campaign = game.campaign
	game.set_physics_process(false)
	await physics_frame
	await physics_frame
	verify_cycle()
	await verify_pen()
	await verify_network()
	game.queue_free()
	await process_frame
	quit(1 if failed else 0)
