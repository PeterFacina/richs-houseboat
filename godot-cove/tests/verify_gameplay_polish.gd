extends SceneTree

const Weather = preload("res://river_weather.gd")
const Ledger = preload("res://game_ledger.gd")
const Crew = preload("res://multiplayer_session.gd")
const Sight = preload("res://interaction_sight.gd")
const Idle = preload("res://character_idle.gd")
const Paint = preload("res://scenery.gd")
const Wakes = preload("res://river_wakes.gd")
const Boat = preload("res://houseboat.gd")
const World = preload("res://game_world.gd")
var game
var failures := 0
var initial: Dictionary = {}
var received: Dictionary = {}
var host_clock := 0.0


func _initialize() -> void:
	exercise.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func weather_profiles() -> void:
	var weather := Weather.new()
	var state := {}
	weather.random.seed = 41
	var now := 360.0
	for kind in Weather.NAMES.size():
		var before := weather.sample(state, now)
		weather.force(state, kind, now)
		check(weather.sample(state, now).is_equal_approx(before), "Weather jumps on selection")
		check(weather.sample(state, now + weather.transition_minutes).is_equal_approx(Weather.CONDITIONS[kind]), "Weather preset mismatch")
		now += weather.transition_minutes
	weather.force(state, Weather.STORM, now)
	now += 45.0
	weather.advance(state, now, 50.0)
	check(float(state.wet) > .6 and state.lightning > 0, "Storm should wet roads and strike")
	weather.force(state, Weather.CLEAR, now)
	weather.advance(state, now + 30, 25)
	check(float(state.wet) > 0.0 and float(state.wet) < 1.0, "Dry after rain gradually")
	var ledger := Ledger.new()
	ledger.save_path = "user://weather_fixture.json"
	ledger.state.weather = state
	ledger.state.work_minutes = now + 10.0
	ledger.save_file()
	var loaded := Ledger.new()
	loaded.save_path = ledger.save_path
	check(loaded.load_file(), "Weather fixture failed to reload")
	check(weather.sample(loaded.state.weather, loaded.state.work_minutes).is_equal_approx(weather.sample(state, ledger.state.work_minutes)), "Reload lost transition progress")
	check(is_equal_approx(float(loaded.state.weather.wet), float(state.wet)), "Reload lost wetness")
	var idle := Idle.new()
	idle.start(Idle.SCRATCH)
	idle.tick(.75, true, true)
	check(Idle.weight(idle.packet()) > .8, "Idle gesture should blend in")
	idle.tick(.016, false, true)
	check(Idle.weight(idle.packet()) == 0.0, "Movement should immediately cancel idle")
	print("Nine weather profiles, transition, wetness, lightning, save/reload and idle interruption checked.")


func mounted_view_and_sight() -> void:
	var eye: Camera3D = game.eye
	var player: CharacterBody3D = game.player
	player.global_position = Vector3(0, 100, 0)
	eye.transform = Transform3D(Basis.IDENTITY, Vector3.UP * 1.58)
	var motion = game.camera_motion
	motion.previous_feet = Vector3.INF
	motion.update(eye, player, .016, "foot", 0, 0, 0)
	var raw := eye.global_position
	var target := raw + Vector3.FORWARD * 3.0
	check(Sight.clear(eye, target), "Open target is occluded")
	var wall := StaticBody3D.new()
	game.add_child(wall)
	wall.global_position = raw + Vector3.FORWARD * 1.5
	Paint.collider(wall, Vector3.ZERO, Vector3(2.0, 2.0, .24))
	var roof := StaticBody3D.new()
	game.add_child(roof)
	roof.global_position = raw + Vector3.UP * 1.45
	Paint.collider(roof, Vector3.ZERO, Vector3(3.0, .22, 4.0))
	await physics_frame
	await physics_frame
	check(not Sight.clear(eye, target), "Wall did not block interaction")
	check(not game.campaign.aiming(target, 3.5, .9), "Campaign still accepts obstructed interaction")
	check(game.weather_fx.is_sheltered(game, player.global_position + Vector3.UP * 1.1), "Roof failed shelter check")
	motion.restore(eye)
	eye.global_position = target
	motion.update(eye, player, .016, "helm", 0, 0, 0)
	check(eye.global_position.distance_to(target) > 0.0 and eye.global_position.distance_to(target) <= 1.0, "Mount transition did not blend")
	motion.restore(eye)
	player.global_position.x += 100.0
	var teleported := eye.global_position
	motion.update(eye, player, .016, "foot", 0, 0, 0)
	check(eye.global_position.is_equal_approx(teleported), "Teleport interpolated from previous position")
	check(not game.weather_fx.is_sheltered(game, player.global_position + Vector3.UP * 1.1), "Open ground treated as sheltered")
	InputMap.action_erase_events(&"interact")
	var remap := InputEventKey.new()
	remap.physical_keycode = KEY_Y
	InputMap.action_add_event(&"interact", remap)
	game.reticle.present("door", &"interact", "Open door")
	check(game.reticle.prompt.text == "[Y] Open door", "Reticle did not display rebound interact key")
	check(remap.is_action(&"interact"), "Rebound key does not dispatch interaction")
	print("Occlusion, indoor/outdoor cover, camera mount and teleport, and rebound reticle checked.")


func wait_for(predicate: Callable) -> bool:
	var end := Time.get_ticks_msec() + 6000
	while not predicate.call() and Time.get_ticks_msec() < end:
		await process_frame
	return predicate.call()


func water_motion() -> void:
	var wakes := Wakes.new()
	var current := Vector2(.3, 0.0)
	wakes.emit(10, Vector2.ZERO, Vector2.UP, current, 7.0, .8, .36, 5.5, 1.0)
	wakes.emit(20, Vector2(30, 0), Vector2.UP, current, 7.0, .6, .53, 6.0, 1.0)
	wakes.emit(10, Vector2.ZERO, Vector2.UP, current, 7.0, .8, .36, 5.5, 1.1)
	check(wakes.packets.size() == 2, "Wake emission must be capped per vessel")
	var crest := Vector2(5.0, -5.35)
	var other_crest := Vector2(35.9, -5.35)
	var wake := wakes.height(crest, 2.0, 0)
	check(absf(wake) > .02 and absf(wakes.height(other_crest, 2.0, 0)) > .02, "Both vessel wakes must persist after emission")
	check(is_zero_approx(wakes.height(crest, 2.0, 10)), "The generating hull should not ride its own wake")
	wakes.advance(5.51)
	check(wakes.packets.is_empty() and is_zero_approx(wakes.height(crest, 5.51, 0)), "Wakes must expire")
	for i in 30:
		wakes.emit(i + 100, Vector2.ZERO, Vector2.UP, current, 7.0, .8, .36, 5.5, 6.0)
	check(wakes.packets.size() == Wakes.CAPACITY, "Wake storage must stay bounded")

	var river = game.river
	var boat: Boat = game.vessel
	var launch: Vector3 = river.waterfront.wharf.launch_mark
	var open := Vector3.INF
	var bank := Vector3.INF
	for x in range(-9, 10):
		for z in range(-9, 10):
			var at := launch + Vector3(x * 19, 0, z * 19)
			var clearance: float = river.wet_clearance(at)
			if not open.is_finite() and clearance > 57.0 and boat.can_place(at, 0.0):
				open = at
			if not bank.is_finite() and clearance > 4.0 and clearance < 13.0 and river.depth_at(at) > .45:
				bank = at
	check(open.is_finite() and bank.is_finite(), "Expected usable open and near-shore water samples")
	if not open.is_finite() or not bank.is_finite():
		return
	var calm := 0.0
	var storm := 0.0
	var sheltered := 0.0
	river.set_water_weather(.12, 0.0)
	for i in 120:
		calm += pow(river.wave_height(open, i * .2), 2)
	river.set_water_weather(.94, .29)
	for i in 120:
		storm += pow(river.wave_height(open, i * .2), 2)
		sheltered += pow(river.wave_height(bank, i * .2), 2)
	check(storm > calm * 1.4 and sheltered < storm * .3, "Storm or shelter lost its effect on physical water")
	check(river.near_water.get_shader_parameter("river_amplitudes") == river.wave_amplitudes
		and river.far_water.get_shader_parameter("river_amplitudes") == river.wave_amplitudes,
		"Water material received different amplitudes from the physics sampler")

	var bobber: Node3D = game.effects.bobber
	game.cast_site = bank
	game.change_state(World.Fishing.CASTING)
	game.flight_time = .7
	game.state_age = World.WINDUP + .71
	game.tick_cast()
	check(game.fishing == World.Fishing.WAITING and game.effects.rings.size() == 1
		and is_equal_approx(game.float_site.y, river.wave_height(bank, game.clock)), "Cast failed to land on moving water")
	game.floating(bobber, bank)
	check(is_equal_approx(bobber.position.y, river.wave_height(bank, game.clock)), "Bobber lost surface contact")
	var feet: Vector3 = game.player.global_position
	game.player.global_position = bank + Vector3.DOWN
	var before: int = game.effects.rings.size()
	game.set_swimming(true)
	check(game.effects.rings.size() == before + 1 and not game.effects.droplets.is_empty(), "Water entry missed its splash")
	game.set_swimming(false)
	game.player.global_position = feet
	game.effects.rings.clear()
	game.effects.droplets.clear()

	var old_center: Vector3 = boat.center
	var old_pose: Transform3D = boat.global_transform
	var old_heading: float = boat.heading
	var old_departed: bool = boat.departed
	var old_lines: Array = boat.mooring.packet()
	boat.mooring.clear()
	boat.berth_at(open, 0.0)
	boat.departed = true
	boat.set_ignition(Boat.Ignition.RUN)
	boat.throttle = .8
	boat.wheel_angle = .32
	for i in 90:
		boat.sail(1.0 / 60.0, i / 60.0, true, 0.0)
	check(boat.speed > 1.0 and boat.center.distance_to(open) > .5 and absf(boat.heading) > .025,
		"Powered boat did not accelerate and steer during a storm")
	boat.set_ignition(Boat.Ignition.OFF)
	boat.berth_at(open, 0.0)
	boat.departed = true
	boat.mooring.anchor = open + boat.mooring.anchor_lead()
	boat.mooring.anchor_down = true
	boat.speed = 5.0
	var heave := 0.0
	for i in 120:
		boat.sail_river(1.0 / 60.0, i / 60.0)
		heave = maxf(heave, absf(boat.wave_pose.x))
	check(boat.center.distance_to(open) <= .19 and heave > .025 and boat.speed < 5.0,
		"Anchored hull must ride the swell and stay within slack while the motor coasts down")
	boat.mooring.clear()
	boat.berth_at(open, 0.0)
	boat.departed = true
	var lead: Vector3 = boat.mooring.leads[0]
	boat.mooring.tie(0, 1, open + lead, boat.transform, lead)
	boat.speed = 4.0
	for i in 60:
		boat.sail_river(1.0 / 60.0, i / 60.0)
	check(boat.center.distance_to(open) <= .20 and absf(boat.wave_pose.z) <= .145,
		"Tied hull exceeded line slack or roll limit")
	boat.berth_at(old_center, old_heading)
	boat.global_transform = old_pose
	boat.departed = old_departed
	boat.mooring.receive(old_lines)
	river.set_water_weather(.12, 0)
	print("Checked storm and shoreline exposure, fishing cast and bobber, swim entry, multiple wakes, steering, anchor and dock lines.")


func endpoint(label: String) -> Crew:
	var branch := Node.new()
	branch.name = label
	root.add_child(branch)
	var api := SceneMultiplayer.new()
	api.root_path = branch.get_path()
	set_multiplayer(api, branch.get_path())
	var crew := Crew.new()
	crew.name = "Crew"
	crew.boat = game.vessel
	crew.local_profile = label.md5_text()
	crew.progression_secret = label.sha256_text().left(32)
	branch.add_child(crew)
	return crew


func network_weather() -> void:
	var campaign = game.campaign
	var original: Crew = campaign.crew
	var host := endpoint("WeatherHost")
	campaign.crew = host
	host.requested.connect(func(peer: int, action: String, _argument: Variant):
		if action == "connected": host.enter_river.rpc_id(peer, campaign.initial_ship_packet()))
	var state: Dictionary = campaign.ledger.state
	state.work_minutes = 761.0
	game.weather.force(state.weather, Weather.HEAVY, state.work_minutes - 11.0)
	var trail := Wakes.new()
	var now: float = game.clock
	game.river.wakes.emit(7, Vector2.ZERO, Vector2.UP, Vector2(.3, 0), 7.0, .7, .36, 5.5, now - 1.0)
	host.host("Weather host")
	host.start_session()
	check(host.on_server() and host.started, "Could not start ENet host")
	var guest := endpoint("WeatherGuest")
	guest.ship_received.connect(func(packet: Dictionary):
		trail.receive(packet.get("wakes", PackedVector4Array()), float(packet.clock)))
	guest.weather_received.connect(func(data: Dictionary, stamp: float):
		if initial.is_empty():
			initial = data
		received = data
		host_clock = stamp)
	guest.join("Weather guest", "127.0.0.1")
	check(await wait_for(func(): return not initial.is_empty()), "Join did not deliver weather state")
	check(initial.get("kind") == Weather.HEAVY and host_clock == 761.0, "Late join lost current weather or world time")
	check(is_equal_approx(float(initial.get("start", 0.0)), 750.0), "Late join restarted transition")
	check(trail.packets.size() == 1 and is_equal_approx(trail.height(Vector2(5, -5.35), now, 0),
		game.river.wakes.height(Vector2(5, -5.35), now, 0)), "Late join did not reproduce host wake height")
	game.river.wakes.emit(8, Vector2(2, 0), Vector2.UP, Vector2.ZERO, 7.0, .7, .36, 5.5, now)
	campaign.send_ship()
	check(await wait_for(func(): return trail.packets.size() == 2), "Live wake did not replicate")
	check(is_equal_approx(trail.height(Vector2(6.6, -5.35), now + .9, 0),
		game.river.wakes.height(Vector2(6.6, -5.35), now + .9, 0)), "Guests diverged from the authoritative wake")
	game.weather.strike(state.weather, state.work_minutes, Vector3.ZERO)
	campaign.send_weather()
	check(await wait_for(func(): return int(received.get("lightning", 0)) == int(state.weather.lightning)), "Live strike did not replicate")
	var idle := Vector3(Idle.LOOK, 1.3, 1.0)
	host.pose.rpc_id(guest.my_id(), Vector3.ZERO, 0.0, false, {"idle": idle})
	check(await wait_for(func(): return guest.poses.has(1)), "Guest did not get the host avatar state")
	check(guest.poses.get(1, {}).get("animation", {}).get("idle") == idle, "Idle state did not replicate")
	var old_sample: Vector4 = game.weather.sample(state.weather, state.work_minutes)
	campaign.crew = guest
	if game.cheats.environment != null:
		check(not game.cheats.environment.allowed(), "Guest can invoke the environment debugger")
	campaign.remote_ship = {"work_minutes": 761.0}
	campaign.receive_weather(received, host_clock)
	game.shannon_job.update_clock(.8)
	check(is_equal_approx(float(state.work_minutes), 761.0) and game.weather_fx.sample.is_equal_approx(old_sample), "Guest changed host clock or displayed divergent weather")
	campaign.crew = host
	guest.stop()
	host.stop()
	await process_frame
	guest.get_parent().queue_free()
	host.get_parent().queue_free()
	campaign.crew = original
	game.river.wakes.advance(now + Wakes.LIFETIME)
	print("Real ENet late join and live sync checked for weather, wakes, lightning, idle pose and guest authority.")


func visual_weather() -> void:
	var state: Dictionary = game.campaign.ledger.state
	var eye: Camera3D = game.eye
	var player: CharacterBody3D = game.player
	game.camera_motion.restore(eye)
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	game.reticle.present("")
	var wharf: Vector3 = game.river.waterfront.wharf.launch_mark
	player.global_position = wharf + Vector3(4.0, 4.8, -10.0)
	eye.position = Vector3.UP * 1.58
	eye.look_at(wharf + Vector3(0, 1.1, 1.0))
	var destination := OS.get_environment("TEMP")
	game.campaign.remote_weather_minute = -1.0
	for stage: Array in [[Weather.CLEAR, 790.0, "clear"], [Weather.HEAVY, 790.0, "rain"], [Weather.DENSE_FOG, 405.0, "fog"], [Weather.STORM, 1320.0, "night"]]:
		game.weather.force(state.weather, stage[0], stage[1] - 35.0)
		state.weather.wet = 0.0 if stage[0] == Weather.CLEAR else .89
		state.work_minutes = stage[1]
		for i in 20:
			game.shannon_job.update_clock(.016)
			await process_frame
		var sample_start := Time.get_ticks_usec()
		for i in 45:
			game.shannon_job.update_clock(.016)
			await process_frame
		print("OpenGL %s frame mean: %.2f ms" % [stage[2], (Time.get_ticks_usec() - sample_start) / 45000.0])
		await RenderingServer.frame_post_draw
		var image := root.get_texture().get_image()
		check(image.save_png(destination.path_join("houseboat-polish-" + stage[2] + ".png")) == OK, "Screenshot failed")
		if stage[0] == Weather.HEAVY:
			check(game.weather_fx.rain.emitting, "Outdoor GPU rain did not emit")
	var roof := StaticBody3D.new()
	game.add_child(roof)
	roof.global_position = player.global_position + Vector3.UP * 2.8
	Paint.collider(roof, Vector3.ZERO, Vector3(4, .28, 4))
	await physics_frame
	await physics_frame
	game.shannon_job.update_clock(.20)
	check(not game.weather_fx.rain.emitting and not game.weather_fx.rain.visible, "Sheltered GPU rain remained visible")
	print("OpenGL clear, heavy rain, morning fog, night storm and covered rain checked.")


func exercise() -> void:
	if not "houseboat-polish-" in OS.get_user_data_dir().to_lower():
		push_error("Use an isolated APPDATA directory containing houseboat-polish-.")
		quit(2)
		return
	weather_profiles()
	game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	await mounted_view_and_sight()
	water_motion()
	await network_weather()
	if DisplayServer.get_name() != "headless":
		await visual_weather()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
