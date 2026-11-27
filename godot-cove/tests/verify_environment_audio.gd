extends SceneTree

const FX = preload("res://river_weather_fx.gd")
const Weather = preload("res://river_weather.gd")
const Pause = preload("res://river_pause.gd")

var game: Node3D
var fx: Node3D
var failures := 0


class StraightBank extends Node3D:
	func wet_clearance(point: Vector3) -> float:
		return maxf(0.0, point.x)


func _initialize() -> void:
	exercise.call_deferred()


func check(condition: bool, description: String) -> void:
	if not condition:
		failures += 1
		push_error(description)


func check_settings() -> void:
	# Existing configurations have only a master setting.
	var legacy := ConfigFile.new()
	legacy.set_value("settings", "volume", .64)
	legacy.save(Pause.SAVE)
	var menu := Pause.new()
	root.add_child(menu)
	menu.setup()
	check(is_equal_approx(menu.preferences.volume, .64), "Legacy master setting was lost")
	for key: String in Pause.AUDIO_BUSES:
		var bus := AudioServer.get_bus_index(Pause.AUDIO_BUSES[key])
		check(bus > 0 and menu.sliders.has(key) and menu.preferences[key] == 1.0, "Missing audio setting: " + key)
	menu.sliders["water_volume"].value = 0.0
	menu.sliders["weather_volume"].value = .35
	var water := AudioServer.get_bus_index(&"Water")
	var weather := AudioServer.get_bus_index(&"Weather")
	check(AudioServer.is_bus_mute(water) and not AudioServer.is_bus_mute(weather), "Audio categories are not independent")
	menu.free()
	menu = Pause.new()
	root.add_child(menu)
	menu.setup()
	check(menu.preferences.water_volume == 0.0 and is_equal_approx(menu.preferences.weather_volume, .35), "Audio settings failed to reload")
	menu.sliders["water_volume"].value = 1.0
	menu.sliders["weather_volume"].value = 1.0
	menu.free()


func check_shore() -> void:
	var river := StraightBank.new()
	var near := FX.find_shore(river, Vector3(-5, 0, 0))
	var inland := FX.find_shore(river, Vector3(-55, 0, 0))
	check(absf(near.x - FX.WET_EDGE) < .3 and absf(inland.x - FX.WET_EDGE) < .3, "Emitter did not use the wet edge")
	check(FX.find_shore(river, Vector3(-81, 0, 0)) == Vector3.INF, "Found shore outside the audible range")
	check(FX.find_shore(river, Vector3(90, 0, 0)) == Vector3.INF, "Found shore in open water beyond the range")
	river.free()

	var launch: Vector3 = game.river.waterfront.wharf.launch_mark
	var shoreline := FX.find_shore(game.river, launch)
	check(shoreline != Vector3.INF and game.river.wet_clearance(shoreline) > FX.WET_EDGE, "Deep River launch did not resolve to mapped water")
	game.vessel.hide()
	fx.sample.w = .12
	fx.update_water_audio(game, shoreline + Vector3.UP * 1.7, 2.0)
	check(fx.bank_waves.playing and fx.bank_waves.bus == &"Water", "No spatial wave loop at the waterfront")
	check(fx.bank_waves.global_position.distance_to(shoreline) < 2.0, "Wave source left the mapped waterfront")
	for site: Vector2 in [Vector2(17957, 13320), Vector2(18515, 13829)]:
		var height: float = game.river.ground_height(site.x, site.y)
		fx.update_water_audio(game, Vector3(site.x, height + 1.7, site.y), 3.0)
		check(not fx.bank_waves.playing, "Wave loop persisted inland at %s" % site)

	game.vessel.show()
	game.vessel.departed = true
	game.vessel.speed = 3.0
	game.vessel.motor.thrust = .6
	var alongside: Vector3 = game.vessel.to_global(Vector3(.5, 1.8, 0))
	fx.update_water_audio(game, alongside, 2.0)
	check(fx.hull_waves.playing and fx.prop_wash.playing, "Moving boat did not produce hull and prop audio")
	check(fx.prop_wash.global_position.is_equal_approx(game.vessel.motor.prop.global_position), "Prop wash isn't attached to the prop")
	fx.update_water_audio(game, alongside + Vector3.UP * 80.0, 3.0)
	check(not fx.hull_waves.playing and not fx.prop_wash.playing, "Boat loops persisted away from the boat")


func check_breaking_waves() -> void:
	var exposed := [
		Vector3(18700, 0, 13190),
		Vector3(18240, 0, 13170),
		Vector3(18170, 0, 12700),
	]
	var counts: Array[int] = []
	for kind in [Weather.CLEAR, Weather.WINDY, Weather.STORM]:
		var weather: Vector4 = Weather.CONDITIONS[kind]
		game.river.set_water_weather(weather.w, weather.z)
		var breaks := 0
		for site: Vector3 in exposed:
			fx.bank = FX.find_shore(game.river, site)
			if fx.bank == Vector3.INF:
				continue
			fx.shore_sample_clock = -INF
			for i in 480:
				var clock := float(i) * .075
				fx.update_shore_splash(game.river, clock, 1.0, 1.0)
				if fx.shore_splash.playing:
					breaks += 1
					check(fx.shore_splash.global_position == fx.bank, "Splash originated away from the bank")
					check(fx.shore_height < game.river.wave_height(fx.bank, clock - .075),
						"Splash did not follow a crest at the bank")
					fx.shore_splash.stop()
		counts.append(breaks)
	check(counts[0] == 0 and counts[1] > 0 and counts[2] > 0, "Mapped shoreline splash counts: %s" % [counts])
	print("Mapped shoreline splashes across calm, windy, and stormy runs: ", counts)
	fx.bank = Vector3.INF
	fx.shore_search_origin = Vector3.INF
	game.river.set_water_weather(.12, 0.0)


func check_weather() -> void:
	var state: Dictionary = {}
	var minute := 630.0
	var eye: Camera3D = game.eye
	var weather_bus := AudioServer.get_bus_index(&"Weather")
	var filter := AudioServer.get_bus_effect(weather_bus, 0) as AudioEffectLowPassFilter
	fx.weather_quality = 0.0
	game.player.global_position = Vector3(18000, 80, 13000)
	eye.position = Vector3.UP * 1.6
	for kind in Weather.NAMES.size():
		game.weather.force(state, kind, minute)
		minute += game.weather.transition_minutes
		fx.update(game, state, minute, 2.5)
		var quiet_wind := kind in [Weather.CLEAR, Weather.FOG, Weather.DENSE_FOG]
		check(fx.volumes[3].playing != quiet_wind, "Wrong wind playback state for " + Weather.NAMES[kind])
		if kind == Weather.WINDY:
			check(fx.volumes[3].volume_db > -10.0, "Wind did not follow weather intensity")
		if kind == Weather.RAIN:
			check(fx.volumes[0].playing and not fx.volumes[4].playing, "Light rain activated the wrong layers")
		if kind in [Weather.HEAVY, Weather.STORM]:
			check(fx.volumes[4].playing, "Heavy rain bed is missing")
	check(not fx.volumes[0].playing and not fx.volumes[4].playing, "Rain loops did not stop in dry weather")

	game.weather.force(state, Weather.HEAVY, minute)
	minute += game.weather.transition_minutes
	fx.update(game, state, minute, 2.5)
	var open_wind: float = fx.volumes[3].volume_db
	game.marina_cars.active = 0
	fx.update(game, state, minute, .08)
	check(fx.shelter > 0.0 and fx.shelter < 1.0, "Cab cover did not fade in")
	fx.update(game, state, minute, 2.5)
	check(filter.cutoff_hz < 1400 and fx.volumes[2].playing and fx.volumes[3].volume_db < open_wind, "Cab did not muffle and reduce outdoor audio")
	game.marina_cars.active = -1
	fx.update(game, state, minute, 2.5)
	check(filter.cutoff_hz > 15000, "Outdoor weather remained muffled")

	state.lightning = 1
	var strike := eye.global_position + Vector3(170, 0, 0)
	state.strike_point = [strike.x, strike.y, strike.z]
	state.flash_minute = minute
	fx.update(game, state, minute, .01)
	check(fx.thunder_delay > .4 and not fx.thunder.playing, "Thunder did not wait for distance-based delay")
	fx.update(game, state, minute, .6)
	check(fx.thunder_delay == -1.0 and fx.thunder.playing and fx.thunder.global_position.is_equal_approx(strike), "Thunder did not play at the synchronized lightning position")
	fx.thunder.stop()
	fx.update(game, state, minute, .1)
	check(not fx.thunder.playing, "Repeated weather state replayed thunder")


func peak(capture: AudioEffectCapture, duration: float) -> float:
	capture.clear_buffer()
	await create_timer(duration).timeout
	var maximum := 0.0
	for frame in capture.get_buffer(capture.get_frames_available()):
		maximum = maxf(maximum, absf(frame.x))
		maximum = maxf(maximum, absf(frame.y))
	return maximum


func check_native_mix() -> void:
	var water := AudioServer.get_bus_index(&"Water")
	var water_capture := AudioEffectCapture.new()
	AudioServer.add_bus_effect(water, water_capture)
	var main_capture := AudioEffectCapture.new()
	main_capture.buffer_length = 5.0
	AudioServer.add_bus_effect(0, main_capture)

	var camera: Camera3D = game.eye
	camera.make_current()
	var launch: Vector3 = game.river.waterfront.wharf.launch_mark
	var shore := FX.find_shore(game.river, launch)
	game.vessel.hide()
	fx.shelter = 0.0
	fx.sample = Weather.CONDITIONS[Weather.CLEAR]
	camera.global_position = shore + Vector3.UP * 1.7
	fx.update_water_audio(game, camera.global_position, 3.0)
	var shore_peak := await peak(water_capture, .6)
	check(shore_peak > .005, "The native waterfront mix contained no water signal")

	for site: Vector2 in [Vector2(17957, 13320), Vector2(18515, 13829)]:
		var height: float = game.river.ground_height(site.x, site.y)
		camera.global_position = Vector3(site.x, height + 1.7, site.y)
		fx.update_water_audio(game, camera.global_position, 3.0)
		await create_timer(.1).timeout
		var inland_peak := await peak(water_capture, .35)
		check(inland_peak < .00001, "Native water output persisted inland at %s" % site)

	camera.global_position = shore + Vector3.UP * 1.7
	fx.sample = Weather.CONDITIONS[Weather.STORM]
	fx.update_water_audio(game, camera.global_position, 3.0)
	fx.thunder_origin = camera.global_position + Vector3(28, 0, 0)
	fx.thunder_delay = .01
	fx.update_weather_audio(camera.global_position, 3.0)
	var storm_peak := await peak(main_capture, 4.0)
	check(storm_peak > .01 and storm_peak <= .9, "Native combined storm mix was silent or clipped")
	print("Native mix peaks: waterfront water %.1f dBFS, storm master %.1f dBFS." %
		[linear_to_db(shore_peak), linear_to_db(storm_peak)])
	AudioServer.remove_bus_effect(water, AudioServer.get_bus_effect_count(water) - 1)
	AudioServer.remove_bus_effect(0, AudioServer.get_bus_effect_count(0) - 1)


func exercise() -> void:
	if not "houseboat-audio-148" in OS.get_user_data_dir().to_lower():
		push_error("Use an isolated APPDATA or XDG_DATA_HOME directory containing houseboat-audio-148.")
		quit(2)
		return
	check_settings()
	game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	await physics_frame
	fx = game.weather_fx
	if DisplayServer.get_name() == "headless":
		fx.setup_audio()
	check_shore()
	check_breaking_waves()
	check_weather()
	if DisplayServer.get_name() != "headless":
		await check_native_mix()
	game.queue_free()
	await process_frame
	print("Environmental audio checks completed with %d failures." % failures)
	quit(1 if failures else 0)
