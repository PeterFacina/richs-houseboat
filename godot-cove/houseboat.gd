extends AnimatableBody3D

const SceneKit = preload("res://scenery.gd")
const Swell = preload("res://swell.gd")
const Outboard = preload("res://outboard.gd")
const Panorama = preload("res://houseboat_panorama.gd")
const RestorationModel = preload("res://rich_houseboat_model.gd")
const FuelTank = preload("res://boat_fuel_tank.gd")
const HelmConsole = preload("res://boat_helm_console.gd")
const Tools = preload("res://crew_tools.gd")
const Mooring = preload("res://boat_mooring.gd")
const STARTER = preload("res://deep_river/princecraft/starter.wav")
const CATCH = preload("res://deep_river/princecraft/catch.wav")
const START_TIME := .75
const SHUTDOWN_TIME := .32
const START_VOLUME := -13.0
const THROTTLE_STEP := .05
const THROTTLE_REPEAT_DELAY := .22
const CURRENT_SAMPLE_INTERVAL := 2.8
const MAX_WIND_DRIFT := .16
const CURRENT_DRIFT_SHARE := .30
const MAX_PASSIVE_DRIFT := .32
const DRIFT_RESPONSE := .70
enum Ignition { OFF, START, RUN }
const BERTH := Vector3(0.0, 0.0, 12.0)
const HELM := Vector3(0.0, 0.80, -1.44)
const SPAN := [Vector2(-3.8, 0.0), Vector2(-3.31, 0.76), Vector2(-2.63, 1.30),
	Vector2(-1.66, 1.43), Vector2(1.84, 1.43), Vector2(3.15, 1.17), Vector2(3.30, 0.97)]
const LONG_SPAN := [Vector2(-3.8, 0), Vector2(-3.31, .76), Vector2(-2.63, 1.3),
	Vector2(-1.66, 1.43), Vector2(5.95, 1.43), Vector2(6.55, 1.25), Vector2(6.66, 1.12)]

var center := BERTH
var heading := 0.0
var speed := 0.0
var throttle := 0.0
var departed := false
var mooring := Mooring.new()
var top_speed := 5.2
var water_check: Callable
var marina_check: Callable
var hull_name := "LANTERN"
var river_engine := false
var motor: Outboard
var water_flow: Callable
var current_rng := RandomNumberGenerator.new()
var current_sample_left := 0.0
var wind_target := Vector2.ZERO
var wind_drift := Vector2.ZERO
var drift_velocity := Vector3.ZERO
var drift_remainder := Vector3.ZERO
var wave_sampler: Callable
var wave_pose := Vector3.ZERO
var helm_wheel: Node3D
var skiff := false
var foil := false
var foil_lift := 0.0
var throttle_cap := 1.0
var modern_design := false
var restoration_design := false
var restoration_model: RestorationModel
var classic_exterior: Node3D
var panorama_exterior: Node3D
var fuel_filler: Marker3D
var helm_console: HelmConsole
var ignition := Ignition.OFF
var wheel_angle := 0.0
var requested_throttle := 0.0
var throttle_repeat := 0.0
var crank_time := 0.0
var crank_confirmed := false
var shutdown_left := 0.0
var startup_audio: AudioStreamPlayer3D
var shutdown_audio: AudioStreamPlayer3D
var steering_rate := .69
var throttle_rate := .34
var drive_response := .52
var coast_response := 1.18
var yaw_rate := .45
var wave_response := .56
var turn_heel := .054
var wake_spread := .36
var wake_peak_speed := 5.3
var wheel_radius := .229
var helm_view_pitch := -.33


func _ready() -> void:
	name = "Houseboat"
	sync_to_physics = false
	geometry()
	fit_mooring()
	if river_engine:
		if uses_battery():
			yaw_rate = .80
			wave_response = 1.0
			steering_rate = .95
			throttle_rate = .48
			drive_response = .74
			coast_response = 1.55
			wake_spread = .33
			wake_peak_speed = 6.2
		fuel_filler = FuelTank.build(self, fuel_tank_mount(), "RESERVE" if uses_battery() else "FUEL")
		build_controls()
		motor = Outboard.new()
		motor.position = motor_mount()
		motor.electric = uses_battery()
		motor.scale = Vector3.ONE * motor_size()
		add_child(motor)
		startup_audio = AudioStreamPlayer3D.new()
		startup_audio.bus = &"Vehicles"
		startup_audio.name = "OutboardStartup"
		startup_audio.position = motor.sound.position
		startup_audio.unit_size = 5.1
		startup_audio.max_distance = 87.0
		startup_audio.volume_db = START_VOLUME
		motor.add_child(startup_audio)
		shutdown_audio = AudioStreamPlayer3D.new()
		shutdown_audio.bus = &"Vehicles"
		shutdown_audio.name = "OutboardShutdown"
		shutdown_audio.position = motor.sound.position
		shutdown_audio.unit_size = 5.1
		shutdown_audio.max_distance = 87.0
		shutdown_audio.volume_db = -14.0
		shutdown_audio.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
		motor.add_child(shutdown_audio)
	sail(0.0, 0.0, false, 0.0)


func helm_anchor() -> Vector3:
	return Vector3(0, .39, .67) if skiff else HELM


func fuel_tank_mount() -> Vector3:
	return Vector3(-.27, .36, 1.49) if skiff else (Vector3(-.92, .91, 8.15) if restoration_design else Vector3(-1.07, .75, -1.69))


func build_controls() -> void:
	var console := HelmConsole.new()
	if skiff:
		mount_controls(console,
			Transform3D(Basis(Vector3.RIGHT, -.38).scaled(Vector3.ONE * .74), Vector3(0, 1.236, -.55)),
			Transform3D(Basis.IDENTITY.scaled(Vector3.ONE * .78), Vector3(.315, .95, -.29)))
		SceneKit.box_at(self, Vector3(0, 1.113, -.58), Vector3(.131, .20, .12), console.trim)
	else:
		mount_controls(console, Transform3D(Basis(Vector3.RIGHT, -.32), Vector3(0, 1.982, -2.54)),
			Transform3D(Basis.IDENTITY, Vector3(.408, 1.56, -2.32)))
		SceneKit.box_at(self, Vector3(0, 1.75, -2.59), Vector3(.175, .31, .17), console.trim)
		SceneKit.box_at(self, Vector3(.304, 1.50, -2.38), Vector3(.24, .072, .18), console.trim)


func mount_controls(console: HelmConsole, dash: Transform3D, lever: Transform3D) -> void:
	helm_console = console
	helm_console.name = "InstrumentPanel"
	add_child(helm_console)
	helm_console.transform = dash
	helm_console.build(self, lever)


func helm_eye_height() -> float:
	return 1.58


func status_panel_mount() -> Vector3:
	return Vector3(.54, 1.204, -.07) if skiff else Vector3(-.63, 1.66, -2.36)


func has_bow_spotlight() -> bool:
	return true


func uses_battery() -> bool:
	return skiff


func motor_mount() -> Vector3:
	return Vector3(0, .30, 2.11) if skiff else Vector3(0, .55, 6.72)


func motor_size() -> float:
	return .60 if skiff else 1.0


func speed_limit(towing: bool) -> float:
	if skiff:
		return 11.9 if foil else 8.4
	return 4.5 if towing else 6.5


func board_anchor() -> Vector3:
	return Vector3(.16, .45, -.91) if skiff else Vector3(0, .93, -2.28)


func launch_half_beam() -> float:
	return 1.02 if skiff else 1.55


func fit_mooring() -> void:
	if skiff:
		mooring.fit([Vector3(-.44, .38, -1.39), Vector3(-.64, .36, 1.54)],
			[Vector3(-.87, .49, -1.39), Vector3(-.91, .49, 1.54)],
			["Bow", "Stern"], Vector3(.82, .56, -1.28))
		return
	var bow := -3.28 if restoration_design else -2.85
	var stern := 8.95 if restoration_design else 3.03
	var bow_inset := 1.09 if restoration_design else .72
	var stern_inset := .91 if restoration_design else .82
	var bow_edge := 1.54 if restoration_design else 1.04
	var stern_edge := 1.54 if restoration_design else 1.10
	mooring.fit(
		[Vector3(-bow_inset, .75, bow), Vector3(bow_inset, .75, bow),
			Vector3(-stern_inset, .75, stern), Vector3(stern_inset, .75, stern)],
		[Vector3(-bow_edge, .84, bow), Vector3(bow_edge, .84, bow),
			Vector3(-stern_edge, .84, stern), Vector3(stern_edge, .84, stern)],
		["Bow port", "Bow starboard", "Stern port", "Stern starboard"],
		Vector3(1.57 if restoration_design else 1.39, .86, -2.31))


func berth_at(at: Vector3, yaw: float) -> void:
	mooring.clear()
	clear_passive_drift()
	center = at
	heading = yaw
	speed = 0.0
	throttle = 0.0
	wave_pose = Vector3.ZERO
	foil_lift = 0.0
	departed = false
	global_transform = Transform3D(Basis(Vector3.UP, heading), center)
	if motor != null:
		wheel_angle = 0.0
		motor.steering = 0.0
		helm_wheel.basis = Basis.IDENTITY
		reset_ignition()
	reset_physics_interpolation()


func waterline(at: Vector3, yaw: float) -> PackedVector2Array:
	var beam := launch_half_beam()
	var bow := 2.45 if skiff else 3.82
	var stern := 2.43 if skiff else (9.72 if restoration_design else 7.05)
	return world_outline(at, yaw, [Vector2(0, -bow), Vector2(beam * .82, -bow * .69),
			Vector2(beam, -bow * .35), Vector2(beam, stern * .85), Vector2(.31, stern),
			Vector2(-.31, stern), Vector2(-beam, stern * .85), Vector2(-beam, -bow * .35),
			Vector2(-beam * .82, -bow * .69)])


static func world_outline(at: Vector3, yaw: float, corners: Array[Vector2]) -> PackedVector2Array:
	var outline := PackedVector2Array()
	for corner: Vector2 in corners:
		outline.append(Vector2(at.x, at.z) + corner.rotated(-yaw))
	return outline


func can_place(at: Vector3, yaw: float) -> bool:
	var forward := Vector3(-sin(yaw), 0, -cos(yaw))
	var side := forward.cross(Vector3.UP)
	var fore := 2.18 if skiff else 3.35
	var aft := 2.35 if skiff else (9.10 if restoration_design else 6.65)
	var beam := .945 if skiff else 1.39
	return in_channel(at) and in_channel(at + forward * fore) and in_channel(at - forward * aft) \
		and in_channel(at + side * beam) and in_channel(at - side * beam) \
		and (not marina_check.is_valid() or marina_check.call(waterline(at, yaw), .49 if skiff else .88))


func supports_deck(world: Vector3) -> bool:
	var local := to_local(world)
	if skiff:
		return absf(local.x) < 1.03 and local.z > -2.28 and local.z < 2.05 and local.y > .19 and local.y < 2.26
	return absf(local.x) < 1.52 and local.z > -3.65 and local.z < (9.35 if restoration_design else 6.6) and local.y > .25 and local.y < 2.9


func sail(delta: float, clock: float, driving: bool, rudder: float) -> void:
	if river_engine:
		update_motor(delta)
		sail_river(delta, clock)
		helm_console.update_instruments(speed, throttle)
		return
	speed = move_toward(speed, throttle * top_speed, delta * (2.1 if driving else 3.6))
	if driving:
		heading -= rudder * delta * (0.45 + absf(speed) * 0.095)
	var fore := Vector3(-sin(heading), 0, -cos(heading))
	var right := fore.cross(Vector3.UP)
	var candidate := center + fore * speed * delta
	if departed:
		if in_channel(candidate):
			center = candidate
		else:
			speed *= 0.3
	var port_wave := sample(center - right * 1.28, clock)
	var starboard_wave := sample(center + right * 1.28, clock)
	var bow_wave := sample(center + fore * 2.60, clock)
	var stern_wave := sample(center - fore * 2.60, clock)
	var heave := (port_wave + starboard_wave + bow_wave + stern_wave) * 0.25
	if not departed:
		heave *= 0.58
	var tilt := Vector3(clampf(atan2(bow_wave - stern_wave, 5.2), -0.085, 0.085),
		heading, clampf(atan2(starboard_wave - port_wave, 2.56), -0.10, 0.10))
	if not departed:
		tilt.x *= 0.42
		tilt.z *= 0.42
	transform = Transform3D(Basis.from_euler(tilt), center + Vector3.UP * heave)


func neutral_throttle() -> void:
	throttle = 0.0
	requested_throttle = 0.0
	throttle_repeat = 0.0


func clear_helm() -> void:
	neutral_throttle()
	if ignition == Ignition.START:
		set_ignition(Ignition.OFF)


func key_focused(camera: Camera3D) -> bool:
	return HelmConsole.aims_at_key(helm_console.ignition_key, camera.global_position, -camera.global_basis.z)


func set_ignition(phase: int) -> void:
	if phase == ignition:
		return
	var previous := ignition
	ignition = phase
	crank_time = 0.0
	crank_confirmed = false
	helm_console.ignition_key.rotation.z = [0.0, -.91, -.47][phase]
	shutdown_left = 0.0
	if phase == Ignition.OFF:
		clear_helm()
		motor.thrust = 0.0
		if previous == Ignition.RUN:
			shutdown_left = SHUTDOWN_TIME
			if not uses_battery():
				startup_audio.stop()
				shutdown_audio.stream = shutdown_stream(motor.rpm)
				shutdown_audio.play()
			return
	startup_audio.stop()
	shutdown_audio.stop()
	startup_audio.volume_db = START_VOLUME
	if phase == Ignition.START:
		motor.rpm = 0.0
		motor.sound.stop()
		motor.load_sound.stop()
	if not uses_battery() and (phase == Ignition.START or (phase == Ignition.RUN and previous == Ignition.START)):
		startup_audio.stream = STARTER if phase == Ignition.START else CATCH
		startup_audio.play()


func reset_ignition() -> void:
	set_ignition(Ignition.OFF)
	clear_helm()
	shutdown_left = 0.0
	startup_audio.stop()
	shutdown_audio.stop()
	motor.sound.stop()
	motor.load_sound.stop()
	motor.rpm = 0.0
	motor.audio_state = Outboard.AudioState.OFF


func tick_ignition(delta: float) -> void:
	if ignition != Ignition.START:
		return
	crank_time += delta
	if crank_confirmed and crank_time >= START_TIME:
		set_ignition(Ignition.RUN)
	elif crank_time > START_TIME + 2.0:
		set_ignition(Ignition.OFF)


func shutdown_stream(rpm: float) -> AudioStreamWAV:
	const RATE := 22050
	const DURATION := .86
	const FRAME_COUNT := int(RATE * DURATION)
	var pcm := PackedByteArray()
	pcm.resize(FRAME_COUNT * 2)
	var phase := 0.0
	var initial_hz := maxf(24.0, rpm / 60.0 * 2.0)
	for frame in FRAME_COUNT:
		var t := float(frame) / RATE
		var progress := t / DURATION
		var frequency := lerpf(initial_hz, 24.0, smoothstep(0.0, 1.0, progress))
		phase += TAU * frequency / RATE
		var envelope := pow(1.0 - progress, 1.35)
		var pulse := sin(phase)
		var exhaust := .54 * pulse + .24 * sin(phase * 2.0 + .65) + .10 * sin(phase * 4.0 + 1.1)
		var value := exhaust * envelope
		pcm.encode_s16(frame * 2, roundi(clampf(value, -1.0, 1.0) * 23500.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.data = pcm
	return stream


func nudge_throttle(direction: float) -> void:
	if ignition == Ignition.RUN and not mooring.secured():
		change_throttle(direction, THROTTLE_STEP)
		throttle_repeat = THROTTLE_REPEAT_DELAY


func hold_throttle(delta: float, adjustment: float, helm_input: float) -> void:
	if ignition != Ignition.RUN or mooring.secured():
		neutral_throttle()
		return
	if helm_input != 0.0:
		change_throttle(helm_input, delta * .90)
		throttle_repeat = 0.0
	elif adjustment == 0.0:
		throttle_repeat = 0.0
	else:
		var delay := throttle_repeat
		throttle_repeat = maxf(0.0, delay - delta)
		change_throttle(adjustment, maxf(0.0, delta - delay) * throttle_rate)


func change_throttle(direction: float, amount: float) -> void:
	var next := move_toward(requested_throttle, 1.0 if direction > 0.0 else -.32, amount)
	# Pass through the neutral detent before crossing between gears.
	requested_throttle = 0.0 if next * requested_throttle < 0.0 else next


func advance_steering(delta: float, direction: float, center_wheel: bool) -> void:
	if center_wheel:
		wheel_angle = move_toward(wheel_angle, 0.0, delta * 1.6)
	else:
		wheel_angle = clampf(wheel_angle + direction * delta * steering_rate, -1.0, 1.0)


func update_motor(delta: float) -> void:
	var running := ignition == Ignition.RUN
	var gain := 1.0 if running else 0.0
	if shutdown_left > 0.0:
		shutdown_left = maxf(0.0, shutdown_left - delta)
		gain = shutdown_left / SHUTDOWN_TIME
		if startup_audio.playing:
			if gain > 0.0:
				startup_audio.volume_db = START_VOLUME + linear_to_db(gain)
			else:
				startup_audio.stop()
	var power := throttle * throttle_cap if running else 0.0
	var startup_progress := -1.0
	if running and startup_audio.playing:
		startup_progress = clampf(startup_audio.get_playback_position() / maxf(.001, startup_audio.stream.get_length()), 0.0, 1.0)
		var crossfade := smoothstep(.52, .99, startup_progress)
		var starter_gain := maxf(.0001, cos(crossfade * PI * .5))
		startup_audio.volume_db = START_VOLUME + linear_to_db(starter_gain)
	motor.run(delta, power, wheel_angle, running and not startup_audio.playing, speed, gain, startup_progress)
	if startup_audio.playing:
		motor.audio_state = Outboard.AudioState.STARTUP
	helm_wheel.basis = Basis(Vector3.BACK, -wheel_angle * 1.272)


func sail_river(delta: float, clock: float) -> void:
	var power := throttle * throttle_cap if ignition == Ignition.RUN else 0.0
	var wanted := signf(power) * top_speed * pow(absf(power), .77)
	if power < 0.0:
		wanted *= .72
	speed = lerpf(speed, wanted, 1.0 - exp(-delta * (drive_response if motor.gear != 0 else coast_response)))
	var steer_force := minf(1.0, absf(speed) * .19 + motor.thrust * .48)
	var reverse := -1.0 if (speed < -.18 or (absf(speed) <= .18 and throttle < 0.0)) else 1.0
	var secured := mooring.secured()
	var turn := heading if secured else \
		wrapf(heading - motor.steering * steer_force * yaw_rate * delta * reverse, -PI, PI)
	var length := .65 if skiff else 1.0
	var beam := .68 if skiff else 1.0
	if departed:
		var current := passive_water_velocity(delta, clock, power != 0.0)
		var course := Vector3(-sin(turn), 0, -cos(turn))
		var driven_position := center + course * (speed * delta)
		var drift_step := current * delta + drift_remainder
		var free_position := driven_position + drift_step
		var next := mooring.constrain(free_position, turn) if secured else free_position
		if can_place(next, turn):
			# Keep sub-millimetre steps on the metre-grid map. Discard motion
			# stopped by a taut line or the anchor rather than carrying it into release.
			if next == free_position:
				drift_remainder = drift_step - (next - driven_position)
			else:
				clear_passive_drift()
			center = next
			heading = turn
		else:
			clear_passive_drift()
			speed *= .53
			if not marina_check.is_valid() or marina_check.call(waterline(center, turn), .49 if skiff else .88):
				heading = turn
	else:
		clear_passive_drift()
	var fore := Vector3(-sin(heading), 0, -cos(heading))
	var right := fore.cross(Vector3.UP)
	var port := sample(center - right * 1.21 * beam, clock)
	var starboard := sample(center + right * 1.21 * beam, clock)
	var bow := sample(center + fore * 2.78 * length, clock)
	var stern := sample(center - fore * (2.61 if skiff else (7.70 if restoration_design else 5.35)) * length, clock)
	foil_lift = lerpf(foil_lift, smoothstep(4.8, 9.6, speed) if foil else 0.0, 1.0 - exp(-delta * 1.8))
	var ride := Vector3((port + starboard + bow + stern) * .25 * minf(1.0, wave_response),
		clampf(atan2(bow - stern, 5.39 if skiff else (9.42 if restoration_design else 8.13)) * wave_response, -.093, .093)
			+ smoothstep(1.05, top_speed, absf(speed)) * .027,
		clampf((atan2(starboard - port, 2.42) + motor.steering * steer_force * turn_heel) * wave_response, -.145, .145))
	wave_pose = wave_pose.lerp(ride, 1.0 - exp(-delta * 6.7))
	var wave_scale := lerpf(1.0, .22, foil_lift)
	transform = Transform3D(Basis.from_euler(Vector3(wave_pose.y * wave_scale, heading, wave_pose.z * wave_scale)),
		center + Vector3.UP * (wave_pose.x * wave_scale + foil_lift * .51))


func passive_water_velocity(delta: float, clock: float, under_power: bool) -> Vector3:
	current_sample_left -= delta
	if current_sample_left <= 0.0:
		current_sample_left += CURRENT_SAMPLE_INTERVAL
		var strength := clampf(current_rng.randfn(.55, .18), 0.0, 1.0)
		var direction := current_rng.randf_range(-.85, .85)
		wind_target = Vector2.from_angle(direction) * strength * MAX_WIND_DRIFT
	wind_drift = wind_drift.lerp(wind_target, 1.0 - exp(-delta * 1.6))
	if under_power or not water_flow.is_valid():
		clear_passive_drift()
		return Vector3.ZERO
	var flow: Vector3 = water_flow.call(center, clock)
	var target := Vector3(flow.x * CURRENT_DRIFT_SHARE + wind_drift.x, 0.0,
		flow.z * CURRENT_DRIFT_SHARE + wind_drift.y).limit_length(MAX_PASSIVE_DRIFT)
	drift_velocity = drift_velocity.lerp(target, 1.0 - exp(-delta * DRIFT_RESPONSE))
	return drift_velocity


func clear_passive_drift() -> void:
	drift_velocity = Vector3.ZERO
	drift_remainder = Vector3.ZERO


func in_channel(candidate: Vector3) -> bool:
	if water_check.is_valid():
		return water_check.call(candidate)
	if absf(candidate.x) > 22.0 or candidate.z < -62.0 or candidate.z > 41.0:
		return false
	for key in SceneKit.ISLANDS:
		var island: Vector4 = key
		if Vector2((candidate.x - island.x) / island.z, (candidate.z - island.y) / island.w).length() < 1.00:
			return false
	return true


func sample(point: Vector3, clock: float) -> float:
	if wave_sampler.is_valid():
		return wave_sampler.call(point, clock)
	return Swell.height(point.x, point.z, clock)


func band(low: float, high: float, low_scale: float, high_scale: float, material: Material, parent: Node3D) -> MeshInstance3D:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var outline := SPAN if skiff else LONG_SPAN
	for i in range(outline.size() - 1):
		var a: Vector2 = outline[i]
		var b: Vector2 = outline[i + 1]
		for side in [-1.0, 1.0]:
			var ll := Vector3(a.y * low_scale * side, low, a.x)
			var lr := Vector3(b.y * low_scale * side, low, b.x)
			var ul := Vector3(a.y * high_scale * side, high, a.x)
			var ur := Vector3(b.y * high_scale * side, high, b.x)
			var corners := [ll, ul, lr, lr, ul, ur] if side < 0 else [ll, lr, ul, lr, ur, ul]
			for vertex in corners:
				mesh.add_vertex(vertex)
	mesh.generate_normals()
	return SceneKit.mesh_at(parent, mesh.commit(), Vector3.ZERO, material)


func set_modern_design(enabled: bool) -> void:
	if skiff or restoration_design or modern_design == enabled:
		return
	if panorama_exterior == null:
		panorama_exterior = Node3D.new()
		panorama_exterior.name = "PanoramaExterior"
		add_child(panorama_exterior)
		Panorama.build(panorama_exterior, hull_name, finish(Color("#b8a280"), .82, true),
			finish(Color("#8c8b7f"), .82, true))
	modern_design = enabled
	yaw_rate = .41 if enabled else .45
	wave_response = .52 if enabled else .56
	drive_response = .49 if enabled else .52
	wake_spread = .38 if enabled else .36
	classic_exterior.visible = not enabled
	panorama_exterior.visible = enabled


func geometry() -> void:
	if skiff:
		skiff_geometry()
		return
	if restoration_design:
		restoration_model = RestorationModel.new()
		restoration_model.build(self, false)
		build_classic_wheel(SceneKit.paint(Color("#a99461")), SceneKit.paint(Color("#30474b")),
			SceneKit.paint(Color("#293237")), SceneKit.paint(Color("#c8bc9e")))
		return
	classic_exterior = Node3D.new()
	classic_exterior.name = "ClassicExterior"
	add_child(classic_exterior)
	var cream: Material = SceneKit.paint(Color("#d9cbb2"))
	var red: Material = SceneKit.paint(Color("#9a4235"))
	var hull: Material = SceneKit.paint(Color("#20404a"))
	var black := SceneKit.paint(Color("#293237"))
	var brass := SceneKit.paint(Color("#b29052"), 0.38, 0.45)
	var rubber := SceneKit.paint(Color("#293234"))
	var glass := SceneKit.paint(Color("#284d57"), 0.21, 0.22)
	var gleam := SceneKit.paint(Color("#65939a"))
	var wood := [SceneKit.paint(Color("#8c6d55")), SceneKit.paint(Color("#a38265")), SceneKit.paint(Color("#9a785f"))]
	for material in [hull, cream, red]:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if river_engine:
		cream = finish(Color("#ccbea2"), .47)
		red = finish(Color("#954e40"), .43)
		hull = finish(Color("#304951"), .36)
		glass.albedo_color = Color(.41, .64, .66, .24)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.roughness = .31
		wood = [finish(Color("#8d7760"), .8, true), finish(Color("#947e62"), .8, true), finish(Color("#887454"), .8, true)]
	band(-0.86, -0.23, 0.52, 0.91, hull, classic_exterior)
	band(-0.23, 0.40, 0.91, 1.0, hull, classic_exterior)
	band(0.40, 0.52, 1.0, 1.01, cream, classic_exterior)
	band(0.52, 0.73, 1.01, 1.0, red, classic_exterior)
	band(0.72, 0.80, 1.0, 1.02, black, classic_exterior)
	SceneKit.box_at(classic_exterior, Vector3(0, 0.38, 3.27), Vector3(2.03, 0.73, 0.09), hull)
	for index in 33:
		var z := -3.48 + index * 0.20
		var width := lerpf(0.33, 1.42, smoothstep(-3.72, -2.20, z))
		width = lerpf(width, 1.03, smoothstep(2.0, 3.20, z))
		SceneKit.box_at(classic_exterior, Vector3(0, 0.69, z), Vector3(width * 2.0, 0.12, 0.195), wood[index % 3])
	SceneKit.collider(self, Vector3(0, 0.69, 0.0), Vector3(2.82, 0.12, 5.30))
	SceneKit.collider(self, Vector3(0, 0.69, -3.05), Vector3(1.50, 0.12, 0.78))
	SceneKit.collider(self, Vector3(0, 0.69, 2.96), Vector3(2.18, 0.12, 0.70))
	for side in [-1.0, 1.0]:
		for z in [-2.52, -1.65, 1.18, 2.13, 2.89]:
			var x: float = side * (1.23 if z < 2.4 else 1.10)
			SceneKit.box_at(classic_exterior, Vector3(x, 1.04, z), Vector3(0.045, 0.57, 0.045), brass)
		SceneKit.beam(classic_exterior, Vector3(side * 1.23, 1.31, -2.52), Vector3(side * 1.23, 1.31, -1.65), 0.045, black)
		SceneKit.beam(classic_exterior, Vector3(side * 1.23, 1.31, 1.18), Vector3(side * 1.10, 1.31, 2.89), 0.045, black)
		var side_x: float = side * 0.96
		SceneKit.box_at(classic_exterior, Vector3(side_x, 1.05, 1.13), Vector3(0.13, 0.64, 3.18), red)
		SceneKit.box_at(classic_exterior, Vector3(side_x, 2.34, 1.13), Vector3(0.13, 0.25, 3.18), red)
		for z in [-0.43, 0.37, 1.16, 1.95, 2.68]:
			SceneKit.box_at(classic_exterior, Vector3(side_x, 1.86, z), Vector3(0.15, 1.10, 0.105), cream)
		for z in [-0.03, 0.77, 1.57, 2.30]:
			SceneKit.box_at(classic_exterior, Vector3(side_x, 1.86, z), Vector3(0.105, 0.81, 0.68), glass)
			SceneKit.box_at(classic_exterior, Vector3(side_x + side * 0.058, 2.10, z), Vector3(0.009, 0.027, 0.59), gleam)
		SceneKit.collider(self, Vector3(side_x, 1.56, 1.13), Vector3(0.16, 1.6, 3.18))
		var float_bumper := CylinderMesh.new()
		float_bumper.height = 0.40
		float_bumper.top_radius = 0.115
		float_bumper.bottom_radius = 0.115
		float_bumper.radial_segments = 10
		for z in [-1.1, 1.70]:
			SceneKit.mesh_at(self, float_bumper, Vector3(side * 1.44, 0.55, z), rubber)
	for side in [-1.0, 1.0]:
		SceneKit.box_at(classic_exterior, Vector3(side * .77, 1.66, 2.70), Vector3(.49, 1.8, .12), red)
		SceneKit.collider(self, Vector3(side * .77, 1.66, 2.70), Vector3(.49, 1.8, .12))
	SceneKit.box_at(classic_exterior, Vector3(0, 2.50, 2.70), Vector3(1.05, .08, .12), cream)
	for x in [-0.76, 0.76]:
		SceneKit.box_at(classic_exterior, Vector3(x, 1.63, -0.44), Vector3(0.41, 1.69, 0.15), red)
		SceneKit.collider(self, Vector3(x, 1.63, -0.44), Vector3(0.41, 1.69, 0.15))
	SceneKit.box_at(classic_exterior, Vector3(0, 2.34, -0.43), Vector3(1.92, 0.28, 0.16), cream)
	SceneKit.box_at(classic_exterior, Vector3(0, 2.54, 1.17), Vector3(2.36, 0.18, 3.45), cream)
	SceneKit.box_at(classic_exterior, Vector3(0, 2.64, 1.17), Vector3(2.10, 0.09, 3.30), hull)
	for x in [-0.84, -0.45, 0.0, 0.45, 0.84]:
		SceneKit.box_at(classic_exterior, Vector3(x, 2.694, 1.17), Vector3(0.035, 0.029, 3.17), black)
	SceneKit.box_at(classic_exterior, Vector3(-0.66, 2.91, 2.04), Vector3(0.23, 0.42, 0.28), black)
	SceneKit.box_at(classic_exterior, Vector3(-0.66, 3.13, 2.04), Vector3(0.28, 0.06, 0.33), brass)
	SceneKit.beam(classic_exterior, Vector3(0.45, 2.67, 1.72), Vector3(0.45, 3.69, 1.72), 0.042, black)
	build_classic_wheel(brass, hull, black, cream)
	var sign := Label3D.new()
	sign.text = hull_name
	sign.font_size = 40
	sign.pixel_size = 0.0037
	sign.position = Vector3(-1.444, 0.54, 0.39)
	sign.rotation.y = -PI / 2.0
	sign.modulate = Color("#eeddb1")
	classic_exterior.add_child(sign)


func build_classic_wheel(brass: Material, hull: Material, black: Material, cream: Material) -> void:
	var console_z := -2.47 if river_engine else -.87
	var console_y := 1.56 if river_engine else 1.49
	SceneKit.box_at(self, Vector3(0, 1.09, console_z), Vector3(.52, .69, .36), hull)
	SceneKit.box_at(self, Vector3(0, console_y, console_z), Vector3(.59, .15, .42), black)
	if river_engine:
		SceneKit.box_at(self, Vector3(0, 1.46, console_z), Vector3(.51, .16, .35), cream)
	var wheel := TorusMesh.new()
	wheel.inner_radius = 0.206
	wheel.outer_radius = 0.257
	wheel.rings = 12
	wheel.ring_segments = 9
	helm_wheel = Node3D.new()
	add_child(helm_wheel)
	helm_wheel.position = Vector3(0, 1.68, console_z + .216) if river_engine else Vector3(0, 1.51, -1.127)
	var ring := SceneKit.mesh_at(helm_wheel, wheel, Vector3.ZERO, brass)
	ring.rotation.x = PI / 2.0
	for i in 6:
		var angle := i * TAU / 6.0
		SceneKit.beam(helm_wheel, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * 0.221, 0.024, brass)


func skiff_geometry() -> void:
	var alloy := finish(Color("#628185"), .38)
	var rail := finish(Color("#bed0cf"), .46)
	var grips := finish(Color("#344746"), .66)
	var timber := finish(Color("#a18969"), .74, true)
	var hull := Node3D.new()
	add_child(hull)
	hull.scale = Vector3(.68, .61, .64)
	band(-.86, -.24, .52, .88, alloy, hull)
	band(-.24, .39, .88, 1.0, alloy, hull)
	band(.39, .55, 1.0, 1.0, rail, hull)
	SceneKit.box_at(self, Vector3(0, .29, -.03), Vector3(1.88, .14, 3.64), grips)
	SceneKit.box_at(self, Vector3(0, .28, -1.98), Vector3(.96, .14, .44), timber)
	SceneKit.collider(self, Vector3(0, .29, -.03), Vector3(1.87, .14, 3.65))
	SceneKit.collider(self, Vector3(0, .28, -1.98), Vector3(.96, .14, .44))
	SceneKit.box_at(self, Vector3(0, .20, 2.05), Vector3(1.34, .42, .13), alloy)
	for x in [-1.0, 1.0]:
		SceneKit.beam(self, Vector3(x * .93, .46, 1.83), Vector3(x * .93, .46, -1.39), .044, rail)
		SceneKit.beam(self, Vector3(x * .93, .46, -1.39), Vector3(x * .14, .40, -2.38), .044, rail)
	SceneKit.box_at(self, Vector3(0, .68, -.44), Vector3(.43, .68, .33), alloy)
	SceneKit.box_at(self, Vector3(0, 1.02, -.43), Vector3(.46, .06, .38), grips)
	SceneKit.box_at(self, Vector3(0, .73, 1.03), Vector3(.82, .12, .39), grips)
	SceneKit.box_at(self, Vector3(0, .53, 1.03), Vector3(.29, .39, .27), alloy)
	SceneKit.box_at(self, Vector3(0, .54, -1.37), Vector3(1.47, .31, .55), timber)
	var shaft := Node3D.new()
	add_child(shaft)
	shaft.position = Vector3(0, 1.143, -.225)
	shaft.rotation.x = -.34
	Tools.tube(self, Vector3(0, 1.053, -.39), shaft.position, .037, .034, grips)
	helm_wheel = Node3D.new()
	shaft.add_child(helm_wheel)
	wheel_radius = .149
	var wheel := TorusMesh.new()
	wheel.inner_radius = .132
	wheel.outer_radius = .169
	SceneKit.mesh_at(helm_wheel, wheel, Vector3.ZERO, grips).rotation.x = PI * .5
	for i in 3:
		var angle := TAU * i / 3.0
		SceneKit.beam(helm_wheel, Vector3.ZERO, Vector3(cos(angle), sin(angle), 0) * wheel_radius, .017, rail)
	var tag := Label3D.new()
	tag.text = "ELECTRIC"
	tag.pixel_size = .0028
	tag.position = Vector3(-.976, .15, .32)
	tag.rotation.y = -PI * .5
	tag.modulate = Color("#e5f7dc")
	add_child(tag)


func add_foil() -> void:
	if foil:
		return
	foil = true
	var alloy := finish(Color("#343d50"), .41)
	for lengthwise in [-1.0, 1.20]:
		for x in [-.50, .50]:
			SceneKit.box_at(self, Vector3(x, -.44, lengthwise), Vector3(.09, .76, .21), alloy)
		var wing := SceneKit.box_at(self, Vector3(0, -.82, lengthwise), Vector3(2.62 if lengthwise < 0 else 1.66, .075, .40), alloy)
		wing.rotation.x = .045


func finish(color: Color, matte: float, timber := false) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://boat_finish.gdshader")
	material.set_shader_parameter("coat", color)
	material.set_shader_parameter("matte", matte)
	material.set_shader_parameter("timber", timber)
	return material


func stern_fittings(rubber: Material, panel: Material) -> void:
	var steel := SceneKit.paint(Color("#8d9495"), .32, .56)
	var pipe := SceneKit.paint(Color("#363b3c"), .53, .29)
	SceneKit.box_at(self, Vector3(0, .76, 3.262), Vector3(2.02, .076, .139), rubber)
	SceneKit.box_at(self, Vector3(0, .42, 3.332), Vector3(.79, .54, .048), steel)
	for side in [-1.0, 1.0]:
		var x: float = side * .81
		SceneKit.box_at(self, Vector3(x, .761, 3.04), Vector3(.162, .037, .069), steel)
		for z in [2.992, 3.086]:
			SceneKit.box_at(self, Vector3(x, .794, z), Vector3(.045, .058, .039), steel)
		SceneKit.beam(self, Vector3(x, .823, 2.966), Vector3(x, .823, 3.111), .043, steel)
		SceneKit.box_at(classic_exterior, Vector3(side * .928, 1.48, 2.755), Vector3(.044, 1.28, .035), panel)
	for y in [1.018, 1.179, 1.338, 1.499, 1.658, 1.819]:
		SceneKit.box_at(classic_exterior, Vector3(0, y, 2.765), Vector3(1.77, .013, .017), pipe)
	var cable := [Vector3(-.33, .69, 3.18), Vector3(-.29, .74, 3.36), Vector3(-.18, .72, 3.48), Vector3(-.12, .66, 3.56)]
	for index in range(1, cable.size()):
		SceneKit.beam(self, cable[index - 1], cable[index], .022, rubber)
