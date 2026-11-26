extends SceneTree

const Weather = preload("res://river_weather.gd")
const Ledger = preload("res://game_ledger.gd")
const Crew = preload("res://multiplayer_session.gd")
const Sight = preload("res://interaction_sight.gd")
const Idle = preload("res://character_idle.gd")
const Paint = preload("res://scenery.gd")
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
	host.host("Weather host")
	host.start_session()
	check(host.on_server() and host.started, "Could not start ENet host")
	var guest := endpoint("WeatherGuest")
	guest.weather_received.connect(func(data: Dictionary, stamp: float):
		if initial.is_empty():
			initial = data
		received = data
		host_clock = stamp)
	guest.join("Weather guest", "127.0.0.1")
	check(await wait_for(func(): return not initial.is_empty()), "Join did not deliver weather state")
	check(initial.get("kind") == Weather.HEAVY and host_clock == 761.0, "Late join lost current weather or world time")
	check(is_equal_approx(float(initial.get("start", 0.0)), 750.0), "Late join restarted transition")
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
	print("Real ENet host, late join, transition progress, lightning update, idle packet and guest authority checked.")


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
	await network_weather()
	if DisplayServer.get_name() != "headless":
		await visual_weather()
	game.queue_free()
	await process_frame
	quit(1 if failures else 0)
