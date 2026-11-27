extends Node3D

const SHORE_RANGE := 80.0
const SHORE_STEP := 8.0
const WET_EDGE := .28
const SILENCE := .001
var weather_filter: AudioEffectLowPassFilter
var water_filter: AudioEffectLowPassFilter

var rain: GPUParticles3D
var rain_style: ParticleProcessMaterial
var volumes: Array[AudioStreamPlayer] = []
var thunder: AudioStreamPlayer3D
var bank_waves: AudioStreamPlayer3D
var hull_waves: AudioStreamPlayer3D
var prop_wash: AudioStreamPlayer3D
var bank := Vector3.INF
var shore_search_origin := Vector3.INF
var sample := Vector4.ZERO
var wet := 0.0
var flash := 0.0
var strike := -1
var thunder_delay := -1.0
var thunder_origin := Vector3.ZERO
var shelter := 0.0
var covered := false
var check_in := 0.0
var shelter_origin := Vector3.INF
var update_in := 0.0
var water_exposure := 0.0
var weather_quality := 1.0
var particle_quality := .7
var reflection_quality := .75
var fog_quality := 1.0


func _ready() -> void:
	if DisplayServer.get_name() == "headless":
		return
	rain = GPUParticles3D.new()
	rain.name = "LocalRain"
	rain.emitting = false
	rain.hide()
	rain.amount = 1500
	rain.lifetime = .56
	rain.local_coords = false
	rain.visibility_aabb = AABB(Vector3(-10, -15, -10), Vector3(20, 20, 20))
	rain_style = ParticleProcessMaterial.new()
	rain_style.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_BOX
	rain_style.emission_box_extents = Vector3(7.0, 1.0, 7.0)
	rain_style.direction = Vector3.DOWN
	rain_style.spread = 1.0
	rain_style.particle_flag_align_y = true
	rain_style.initial_velocity_min = 13.0
	rain_style.initial_velocity_max = 18.0
	rain_style.gravity = Vector3.DOWN * 5.0
	rain.process_material = rain_style
	var drop := BoxMesh.new()
	drop.size = Vector3(.007, .29, .007)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://rain_streak.gdshader")
	drop.material = paint
	rain.draw_pass_1 = drop
	rain.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(rain)
	setup_audio()


func setup_audio() -> void:
	for stream: AudioStreamOggVorbis in [
		preload("res://deep_river/environment_audio/light_rain.ogg"),
		preload("res://deep_river/environment_audio/rain_on_water.ogg"),
		preload("res://deep_river/environment_audio/sheltered_rain.ogg"),
		preload("res://deep_river/environment_audio/wind.ogg"),
		preload("res://deep_river/environment_audio/heavy_rain.ogg"),
	]:
		var layer := AudioStreamPlayer.new()
		layer.bus = &"Weather"
		layer.volume_db = -80.0
		layer.stream = stream
		add_child(layer)
		volumes.append(layer)
	thunder = AudioStreamPlayer3D.new()
	thunder.bus = &"Weather"
	thunder.stream = preload("res://deep_river/environment_audio/thunder.ogg")
	thunder.unit_size = 55.0
	thunder.max_distance = 360.0
	thunder.max_db = 0.0
	thunder.attenuation_filter_cutoff_hz = 3800
	add_child(thunder)
	var lapping := preload("res://deep_river/environment_audio/freshwater_lapping.ogg")
	bank_waves = water_loop(lapping, 12.0, SHORE_RANGE, .94)
	hull_waves = water_loop(lapping, 4.0, 23.0, 1.12)
	prop_wash = water_loop(volumes[1].stream, 4.0, 28.0, .88)
	weather_filter = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Weather"), 0)
	water_filter = AudioServer.get_bus_effect(AudioServer.get_bus_index(&"Water"), 0)


func water_loop(stream: AudioStream, unit_size: float, distance: float, pitch: float) -> AudioStreamPlayer3D:
	var layer := AudioStreamPlayer3D.new()
	layer.bus = &"Water"
	layer.stream = stream
	layer.unit_size = unit_size
	layer.max_distance = distance
	layer.max_db = 0.0
	layer.pitch_scale = pitch
	layer.volume_db = -80.0
	add_child(layer)
	return layer


func _exit_tree() -> void:
	RenderingServer.global_shader_parameter_set("river_weather_wet", 0.0)
	RenderingServer.global_shader_parameter_set("river_weather_wind", 0.0)
	RenderingServer.global_shader_parameter_set("river_weather_rain", 0.0)


func is_sheltered(game: Node3D, from: Vector3) -> bool:
	if game.marina_cars.active >= 0 and game.marina_cars.cockpit_view:
		return true
	if game.campaign.dive.active:
		return true
	var query := PhysicsRayQueryParameters3D.create(from, from + Vector3.UP * 15.0, 1, [game.player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	if not hit.is_empty() and hit.normal.y < -.20:
		return true
	return game.aboard() and not game.vessel.skiff and not game.driving \
		and game.vessel.to_local(game.player.global_position).z > -.25 \
		and game.vessel.to_local(game.player.global_position).z < 4.5


func update(game: Node3D, record: Dictionary, minute: float, delta: float) -> void:
	sample = game.weather.sample(record, minute)
	wet = clampf(float(record.get("wet", 0.0)), 0, 1)
	var camera := get_viewport().get_camera_3d()
	var listener: Vector3 = camera.global_position if camera != null else game.eye.global_position
	var next_strike := int(record.get("lightning", 0))
	if next_strike != strike:
		if next_strike < strike:
			thunder_delay = -1.0
		var point: Array = record.get("strike_point", [])
		if strike >= 0 and next_strike > strike and point.size() == 3 and minute - float(record.get("flash_minute", -1000)) < 2.0:
			thunder_origin = Vector3(point[0], point[1], point[2])
			var distance := thunder_origin.distance_to(listener)
			flash = lerpf(1.0, .22, smoothstep(120.0, 900.0, distance))
			thunder_delay = distance / 343.0
		strike = next_strike
	flash = maxf(0.0, flash - delta * 3.6)
	game.river.weather_sample = Vector4(sample.x, sample.y, sample.z, sample.w) * weather_quality
	game.river.weather_flash = flash * weather_quality
	game.river.weather_fog_quality = fog_quality
	update_in -= delta
	if update_in <= 0.0:
		update_in = .10
		game.river.set_water_weather(lerpf(.12, sample.w, game.weather.gameplay_strength),
			sample.z * fog_quality * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_wet", wet * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_wind", sample.w * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_rain", sample.y * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_reflection", reflection_quality)
		for car in game.marina_cars.cars:
			car.model.paint.roughness = lerpf(.36, .22, wet * weather_quality * reflection_quality)
			car.model.paint.clearcoat_roughness = lerpf(.29, .13, wet * weather_quality * reflection_quality)
	if volumes.is_empty():
		return
	var origin: Vector3 = game.eye.global_position
	check_in -= delta
	var feet: Vector3 = game.player.global_position
	if check_in <= 0.0 or feet.distance_squared_to(shelter_origin) > .06:
		check_in = .12
		shelter_origin = feet
		covered = is_sheltered(game, feet + Vector3.UP * 1.1)
		var depth: float = game.river.depth_at(listener)
		water_exposure = smoothstep(0.0, 1.6, depth)
	var audio_covered: bool = covered or game.marina_cars.active >= 0 or game.in_aircraft()
	shelter = lerpf(shelter, float(audio_covered), 1.0 - exp(-delta * 5.0))
	update_water_audio(game, listener, delta)
	update_weather_audio(listener, delta)
	if rain == null:
		return
	rain.global_position = origin + Vector3.UP * 5.7
	rain_style.direction = Vector3(sample.w * .38, -1, sample.w * .13).normalized()
	rain.amount_ratio = clampf(sample.y * particle_quality * weather_quality, 0, 1)
	var visible_rain := not covered and rain.amount_ratio > .015
	if visible_rain != rain.emitting:
		rain.emitting = visible_rain
		rain.visible = visible_rain
		if visible_rain:
			rain.restart()


func update_weather_audio(listener: Vector3, delta: float) -> void:
	var rain_amount := sample.y
	var heavy := smoothstep(.42, .89, rain_amount)
	var outside := 1.0 - shelter
	var light := rain_amount * (1.0 - .60 * heavy) * outside
	var wind := sample.w * smoothstep(.14, .35, sample.w)
	var levels := [light * (1.0 - water_exposure) * .44, light * water_exposure * .51,
		rain_amount * shelter * .32, wind * lerpf(.10, .47, outside), rain_amount * heavy * outside * .48]
	var response := 1.0 - exp(-delta * 3.5)
	for i in volumes.size():
		fade_loop(volumes[i], levels[i], response)
	weather_filter.cutoff_hz = lerpf(16000.0, 1250.0, shelter)
	if thunder_delay >= 0.0:
		thunder_delay = maxf(0.0, thunder_delay - delta)
		if thunder_delay == 0.0:
			thunder_delay = -1.0
			if thunder_origin.distance_to(listener) < thunder.max_distance:
				thunder.global_position = thunder_origin
				thunder.volume_db = lerpf(-9.0, -20.0, shelter)
				thunder.play()


func update_water_audio(game: Node3D, listener: Vector3, delta: float) -> void:
	var river = game.river
	var planar := Vector3(listener.x, 0.0, listener.z)
	if planar.distance_squared_to(shore_search_origin) >= 16.0:
		shore_search_origin = planar
		var next_bank := find_shore(river, planar)
		if next_bank != Vector3.INF and (bank == Vector3.INF \
				or listener.distance_to(next_bank) + 2.0 < listener.distance_to(bank)):
			bank = next_bank
			bank_waves.global_position = bank
		elif next_bank == Vector3.INF:
			bank = Vector3.INF
	var bank_distance := INF if bank == Vector3.INF else listener.distance_to(bank)
	var bank_gain := (1.0 - smoothstep(7.0, SHORE_RANGE, bank_distance)) * lerpf(.16, .29, sample.w)

	var vessel: Node3D = game.vessel
	var afloat: bool = vessel.visible and (vessel.departed or river.wet_clearance(vessel.global_position) > .35)
	var hull_gain := 0.0
	var wash_gain := 0.0
	if afloat and vessel.global_position.distance_squared_to(listener) < 32.0 * 32.0:
		var side := 1.0 if vessel.to_local(listener).x >= 0.0 else -1.0
		var alongside := vessel.to_global(Vector3(side * vessel.launch_half_beam(), 0.0, 0.0))
		var height: float = river.wave_height(alongside, game.clock)
		hull_waves.global_position = Vector3(alongside.x, height, alongside.z)
		prop_wash.global_position = vessel.motor.prop.global_position
		hull_gain = .045 + smoothstep(.01, .19, absf(height)) * .085 + smoothstep(.4, 6.0, absf(vessel.speed)) * .065
		wash_gain = vessel.motor.thrust * .14
		prop_wash.pitch_scale = lerpf(.78, 1.18, vessel.motor.thrust)
		# The bank and hull use the same loop. Give the nearby hull priority.
		var hull_presence := 1.0 - smoothstep(2.0, 16.0, listener.distance_to(hull_waves.global_position))
		bank_gain *= lerpf(1.0, .40, hull_presence)
	var response := 1.0 - exp(-delta * 4.0)
	var cover_gain := lerpf(1.0, .25, shelter)
	fade_loop(bank_waves, bank_gain * cover_gain, response)
	fade_loop(hull_waves, hull_gain * cover_gain, response, 7.0)
	fade_loop(prop_wash, wash_gain * cover_gain, response, 8.0)
	water_filter.cutoff_hz = lerpf(16000.0, 1150.0, shelter)


static func find_shore(river: Node3D, origin: Vector3) -> Vector3:
	var wet: bool = river.wet_clearance(origin) > WET_EDGE
	# Look for a wet/dry crossing in the same masks used by the river and launch.
	for radius in range(int(SHORE_STEP), int(SHORE_RANGE) + 1, int(SHORE_STEP)):
		var closest := Vector3.INF
		var distance_squared := INF
		for spoke in 16:
			var angle := TAU * spoke / 16.0
			var direction := Vector3(cos(angle), 0.0, sin(angle))
			var beyond := origin + direction * radius
			if (river.wet_clearance(beyond) > WET_EDGE) == wet:
				continue
			var near := beyond - direction * SHORE_STEP
			for step in 5:
				var middle := (near + beyond) * .5
				if (river.wet_clearance(middle) > WET_EDGE) == wet:
					near = middle
				else:
					beyond = middle
			var point := near if wet else beyond
			var distance := origin.distance_squared_to(point)
			if distance < distance_squared:
				distance_squared = distance
				closest = point
		if closest != Vector3.INF:
			return closest
	return Vector3.INF


static func fade_loop(layer: Node, target: float, response: float, start := 0.0) -> void:
	var level := lerpf(db_to_linear(layer.volume_db), target, response)
	if level < SILENCE and target < SILENCE:
		if layer.playing:
			layer.stop()
		layer.volume_db = -80.0
	else:
		layer.volume_db = linear_to_db(maxf(.0001, level))
		if not layer.playing:
			layer.play(start)
