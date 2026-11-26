extends Node3D

var rain: GPUParticles3D
var rain_style: ParticleProcessMaterial
var volumes: Array[AudioStreamPlayer] = []
var thunder: AudioStreamPlayer3D
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
	for i in 5:
		var layer := AudioStreamPlayer.new()
		layer.volume_db = -80.0
		layer.stream = noise_stream(i)
		add_child(layer)
		layer.play(float(i) * .24)
		volumes.append(layer)
	thunder = AudioStreamPlayer3D.new()
	thunder.stream = noise_stream(5)
	thunder.unit_size = 38.0
	thunder.max_distance = 280.0
	thunder.attenuation_filter_cutoff_hz = 2100
	add_child(thunder)


static func noise_stream(kind: int) -> AudioStreamWAV:
	var rng := RandomNumberGenerator.new()
	rng.seed = 87213 + kind * 19
	var wav := AudioStreamWAV.new()
	wav.mix_rate = 16000
	wav.format = AudioStreamWAV.FORMAT_16_BITS
	var frames := wav.mix_rate * (5 if kind == 5 else 4)
	var bytes := PackedByteArray()
	bytes.resize(frames * 2)
	var slow := 0.0
	var medium := 0.0
	var rumble := 0.0
	for i in frames:
		var white := rng.randf_range(-1.0, 1.0)
		slow = lerpf(slow, white, .012)
		medium = lerpf(medium, white, .085)
		rumble = lerpf(rumble, white, .004)
		var t := float(i) / wav.mix_rate
		var envelope := minf(1.0, float(mini(i, frames - 1 - i)) / 350.0)
		var signal_value := 0.0
		match kind:
			0: signal_value = .18 * white + .55 * medium
			1: signal_value = .13 * white + .55 * medium + .55 * slow
			2: signal_value = .14 * white + medium * .66 + pow(absf(white), 20) * .044
			3: signal_value = (2.5 * slow + medium * .38) * (.69 + .27 * sin(t * TAU * .5))
			4: signal_value = (1.55 * slow + .33 * medium) * (.58 + .40 * sin(t * TAU * .75))
			5: signal_value = (rumble * 3.4 + slow * 1.4 + medium * exp(-t * 12.0)) * exp(-t * .63)
		bytes.encode_s16(i * 2, roundi(clampf(signal_value * envelope, -1, 1) * 32760))
	wav.data = bytes
	if kind < 5:
		wav.loop_mode = AudioStreamWAV.LOOP_FORWARD
		wav.loop_end = frames
	return wav


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
	var next_strike := int(record.get("lightning", 0))
	if next_strike != strike:
		var point: Array = record.get("strike_point", [])
		if strike >= 0 and next_strike > strike and point.size() == 3 and minute - float(record.get("flash_minute", -1000)) < 2.0:
			thunder_origin = Vector3(point[0], point[1], point[2])
			var distance := thunder_origin.distance_to(game.eye.global_position)
			flash = lerpf(1.0, .22, smoothstep(120.0, 900.0, distance))
			thunder_delay = minf(2.7, distance / 165.0)
		strike = next_strike
	flash = maxf(0.0, flash - delta * 3.6)
	game.river.weather_sample = Vector4(sample.x, sample.y, sample.z, sample.w) * weather_quality
	game.river.weather_flash = flash * weather_quality
	game.river.weather_fog_quality = fog_quality
	update_in -= delta
	if update_in <= 0.0:
		update_in = .10
		game.river.weather_wave_scale = 1.0 + smoothstep(.25, 1.0, sample.w) * .27 * game.weather.gameplay_strength
		for material: ShaderMaterial in [game.river.near_water, game.river.far_water, game.river.headpond_water]:
			material.set_shader_parameter("weather_wave_scale", game.river.weather_wave_scale)
			material.set_shader_parameter("use_weather", 1.0)
		RenderingServer.global_shader_parameter_set("river_weather_wet", wet * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_wind", sample.w * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_rain", sample.y * weather_quality)
		RenderingServer.global_shader_parameter_set("river_weather_reflection", reflection_quality)
		for car in game.marina_cars.cars:
			car.model.paint.roughness = lerpf(.36, .22, wet * weather_quality * reflection_quality)
			car.model.paint.clearcoat_roughness = lerpf(.29, .13, wet * weather_quality * reflection_quality)
	if rain == null:
		return
	var origin: Vector3 = game.eye.global_position
	check_in -= delta
	var feet: Vector3 = game.player.global_position
	if check_in <= 0.0 or feet.distance_squared_to(shelter_origin) > .06:
		check_in = .12
		shelter_origin = feet
		covered = is_sheltered(game, feet + Vector3.UP * 1.1)
		var depth: float = game.river.depth_at(origin)
		water_exposure = smoothstep(0.0, 1.6, depth)
	shelter = lerpf(shelter, float(covered), 1.0 - exp(-delta * 5.0))
	rain.global_position = origin + Vector3.UP * 5.7
	rain_style.direction = Vector3(sample.w * .38, -1, sample.w * .13).normalized()
	rain.amount_ratio = clampf(sample.y * particle_quality * weather_quality, 0, 1)
	var visible_rain := not covered and rain.amount_ratio > .015
	if visible_rain != rain.emitting:
		rain.emitting = visible_rain
		rain.visible = visible_rain
		if visible_rain:
			rain.restart()
	var outside := 1.0 - shelter
	var drizzle := sample.y * weather_quality
	var levels := [drizzle * outside * (1.0 - water_exposure) * .32,
		drizzle * outside * water_exposure * .45, drizzle * shelter * .30,
		sample.w * weather_quality * lerpf(.05, .40, outside), sample.w * weather_quality * water_exposure * outside * .23]
	for i in volumes.size():
		var target := linear_to_db(maxf(.0001, levels[i]))
		volumes[i].volume_db = lerpf(volumes[i].volume_db, target, 1.0 - exp(-delta * 4.0))
	if thunder_delay >= 0.0:
		thunder_delay -= delta
		if thunder_delay <= 0.0:
			thunder.global_position = thunder_origin
			thunder.volume_db = lerpf(-4.0, -17.0, shelter) + linear_to_db(maxf(.0001, weather_quality))
			thunder.pitch_scale = lerpf(1.0, .79, shelter)
			thunder.play()
