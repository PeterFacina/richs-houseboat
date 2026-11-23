extends SceneTree

var failures := 0
var checks := 0


func _initialize() -> void:
	create_timer(120.0).timeout.connect(func(): quit(124))
	exercise.call_deferred()


func check(passed: bool, label: String) -> void:
	checks += 1
	if not passed:
		failures += 1
		print("FAIL: ", label)


func exercise() -> void:
	if not "houseboat-audio-test-" in OS.get_user_data_dir().to_lower():
		push_error("Run with an isolated APPDATA directory named houseboat-audio-test-<run>.")
		quit(2)
		return
	var game = load("res://fishing.tscn").instantiate()
	root.add_child(game)
	current_scene = game
	await physics_frame
	await process_frame
	game.set_process(false)
	game.set_physics_process(false)
	if DisplayServer.get_name() != "headless" and not OS.get_cmdline_user_args().is_empty():
		await RenderingServer.frame_post_draw
		root.get_texture().get_image().save_png(OS.get_cmdline_user_args()[0])
	var effects = game.effects
	var amenities = game.campaign.amenities
	var pump = game.campaign.marina_fuel.pumps[0]
	var car = game.marina_cars.cars[0]
	var motor = game.vessel.motor
	var electric = load("res://outboard.gd").new()
	electric.electric = true
	for entry in [["outboard", motor.sound.stream, 44.0],
		["electric", electric.engine_loop(), 120.0],
		["mower", game.mower.motor.stream, 53.0],
		["pickup", car.engine.stream, 38.0],
		["helicopter", game.helicopter.sound.stream, 96.0],
		["fuel", pump.flow_sound.stream, 86.0]]:
		if entry[1].format != AudioStreamWAV.FORMAT_16_BITS:
			print("SKIP PCM inspection of compressed baseline stream: ", entry[0])
			continue
		inspect(entry[0], entry[1], true)
		if entry[2] > 0:
			check(tone_share(entry[1], entry[2]) < .10, entry[0] + " sustained tone removed")
	electric.free()
	for tag in effects.SOUNDS:
		var repeat: bool = tag in ["reel", "drag"]
		inspect(tag, effects.samples[tag], repeat)
		if repeat:
			check(tone_share(effects.samples[tag], 890.0) < .02, tag + " carrier removed")
		else:
			check(absf(effects.samples[tag].get_length() - effects.SOUNDS[tag]) < .001, tag + " cue duration")
	for variant in amenities.sound_bank.size():
		inspect("flush %d" % variant, amenities.sound_bank[variant], false)
	check(amenities.sound_bank.size() == 20, "all flush variants retained")

	# Exercise the production playback gates, rather than just sample generation.
	effects.crank_sounds(1.0, 1.0)
	check(effects.reel.playing and effects.drag.playing, "reel and drag start")
	effects.crank_sounds(0.0, 0.0)
	check(not effects.reel.playing and not effects.drag.playing, "reel and drag stop")
	motor.run(1.0, 1.0, 0.0, true, 0.0)
	check(motor.sound.playing and motor.sound.pitch_scale > 1.0, "outboard start and RPM pitch")
	motor.run(10.0, 0.0, 0.0, false, 0.0)
	check(not motor.sound.playing, "outboard stops with ignition")
	game.mower.mount(game.player)
	check(game.mower.motor.playing, "mower mount starts sound")
	game.mower.leave_seat()
	check(not game.mower.motor.playing, "mower seat exit stops sound")
	car.present(.1, true, 1.0)
	check(car.engine.playing, "pickup occupied starts sound")
	car.present(.1, false, 0.0)
	check(not car.engine.playing, "pickup exit stops sound")
	pump.render_station(pump.rack_pose(), false, true, false, 0.0, 0, 0)
	check(pump.flow_sound.playing and pump.nozzle_sound.playing, "fuel flow starts both sources")
	pump.render_station(pump.rack_pose(), false, false, false, 0.0, 0, 0)
	check(not pump.flow_sound.playing and not pump.nozzle_sound.playing, "fuel flow stops both sources")
	game.helicopter.rotor_speed = .5
	game.helicopter.tick(0.0, false)
	check(game.helicopter.sound.playing, "rotor starts sound")
	game.helicopter.rotor_speed = 0.0
	game.helicopter.tick(0.0, false)
	check(not game.helicopter.sound.playing, "rotor stops sound")
	if not ResourceLoader.exists(amenities.CLIP_AUDIO):
		amenities.state({}, true, 0.0)
		amenities.tick(0.0)
		check(amenities.television_audio.stream == null and not amenities.television_audio.playing, "powered placeholder TV is silent")
	# A short stand-in checks the populated-stream path without licensed media.
	amenities.television_audio.stream = effects.samples.cast
	amenities.tv_epoch = game.clock
	amenities.tv_on = true
	amenities.tick(0.0)
	check(amenities.television_audio.playing, "TV media stream still plays")
	amenities.tv_on = false
	amenities.tick(0.0)
	check(not amenities.television_audio.playing, "TV power off stops media")
	game.pause_menu.preferences.volume = 0.0
	game.pause_menu.apply_settings()
	check(AudioServer.is_bus_mute(0), "master mute")
	game.pause_menu.preferences.volume = .4
	game.pause_menu.apply_settings()
	check(not AudioServer.is_bus_mute(0) and absf(db_to_linear(AudioServer.get_bus_volume_db(0)) - .4) < .001, "master volume")
	print("Audio checks: %d passed, %d failed" % [checks - failures, failures])
	game.free()
	await process_frame
	quit(1 if failures else 0)


func inspect(label: String, stream: AudioStreamWAV, repeat: bool) -> void:
	var count := stream.data.size() / 2
	var mean := 0.0
	var peak := 0.0
	var energy := 0.0
	for index in count:
		var value := stream.data.decode_s16(index * 2) / 32768.0
		mean += value
		energy += value * value
		peak = maxf(peak, absf(value))
	check(count > 0 and energy / count > .00001, label + " audible data")
	check(peak <= .321, label + " peak headroom")
	check(absf(mean / count) < .0002, label + " DC offset")
	check((stream.loop_mode == AudioStreamWAV.LOOP_FORWARD) == repeat, label + " loop mode")
	if repeat:
		check(stream.loop_end == count, label + " loop covers sample")
	else:
		check(stream.data.decode_s16(0) == 0 and stream.data.decode_s16((count - 1) * 2) == 0, label + " tapered edges")


# Goertzel measures energy at a known unwanted baseline oscillator frequency.
func tone_share(stream: AudioStreamWAV, hz: float) -> float:
	var count := stream.data.size() / 2
	var coefficient := 2.0 * cos(TAU * hz / stream.mix_rate)
	var previous := 0.0
	var before_previous := 0.0
	var energy := 0.0
	for index in count:
		var value := stream.data.decode_s16(index * 2) / 32768.0
		var next := value + coefficient * previous - before_previous
		before_previous = previous
		previous = next
		energy += value * value
	return 2.0 * (previous * previous + before_previous * before_previous - coefficient * previous * before_previous) / maxf(count * energy, .000001)
