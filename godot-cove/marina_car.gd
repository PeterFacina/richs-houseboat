extends CharacterBody3D

const Kit = preload("res://scenery.gd")
const AudioTexture = preload("res://audio_texture.gd")
const Model = preload("res://marina_car_model.gd")

var details: Dictionary
var model: Model
var ground: Callable
var speed := 0.0
var heading := 0.0
var steer := 0.0
var spinning := 0.0
var braking := false
var lamps_on := false
var engine: AudioStreamPlayer3D
var blocked := false
var recovery_seconds := 0.0
var wheelbase: float
var body_size: Vector3
var sway := 0.0
var dive := 0.0


func setup(data: Dictionary, at: Vector3, angle: float, elevation: Callable, sound: AudioStreamWAV) -> void:
	details = data
	ground = elevation
	wheelbase = details.wheelbase
	body_size = details.size
	model = Model.new()
	add_child(model)
	model.build(details)
	Kit.collider(self, Vector3(0, .57, 0), Vector3(body_size.x * .94, .59, body_size.z * .97))
	var roof: Array = details.roof
	Kit.collider(self, Vector3(0, (float(details.belt) + body_size.y) * .5,
		(float(roof[1]) + float(roof[2])) * body_size.z * .25),
		Vector3(body_size.x * .73, body_size.y - float(details.belt),
			body_size.z * (float(roof[2]) - float(roof[1])) * .54))
	heading = angle
	var feet := footprint(at, heading)
	global_transform = Transform3D(ground_basis(heading, feet), Vector3(at.x, mean_height(feet), at.z))
	engine = AudioStreamPlayer3D.new()
	engine.stream = sound
	engine.volume_db = -22.0
	engine.unit_size = 4.5
	engine.max_distance = 80.0
	engine.position = Vector3(0, .59, -body_size.z * .35)
	add_child(engine)


func footprint(at: Vector3, angle: float) -> PackedFloat32Array:
	var levels := PackedFloat32Array()
	for axle in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var p := at + Vector3(body_size.x * .40 * side, 0, wheelbase * .5 * axle).rotated(Vector3.UP, angle)
			levels.append(ground.call(p.x, p.z))
	return levels


func mean_height(feet: PackedFloat32Array) -> float:
	return (feet[0] + feet[1] + feet[2] + feet[3]) * .25


func ground_basis(angle: float, feet: PackedFloat32Array) -> Basis:
	var rise := ((feet[0] + feet[1]) - (feet[2] + feet[3])) * .5 / wheelbase
	var bank := ((feet[1] + feet[3]) - (feet[0] + feet[2])) * .5 / (body_size.x * .8)
	var basis := Basis(Vector3.UP, angle) * Basis(Vector3.RIGHT, atan(rise))
	return basis * Basis(Vector3.BACK, atan(bank))


func drive(delta: float, pedal: float, turning: float, handbrake: bool, occupied: bool, recovery_bonus := 0.0) -> void:
	recovery_seconds = maxf(0.0, recovery_seconds - delta)
	var previous := speed
	var moving_against_pedal := absf(pedal) > .01 and speed * pedal < -.12
	braking = handbrake or moving_against_pedal
	blocked = false
	if braking or not occupied:
		speed = move_toward(speed, 0.0, (10.8 if handbrake else 8.7) * delta)
	elif not is_zero_approx(pedal):
		var limit: float = details.limit if pedal > 0 else 5.6
		var traction := 1.0 - smoothstep(2.0, limit, absf(speed)) * .73
		var slope := global_basis.z.y * 3.2
		speed = clampf(speed + (pedal * float(details.pull) * (1.0 + recovery_bonus if recovery_seconds > 0.0 else 1.0) * traction + slope) * delta, -5.6, details.limit)
	else:
		speed = move_toward(speed, 0.0, (.62 + absf(speed) * .04) * delta)
	var angle_limit := lerpf(.54, .11, smoothstep(2.5, 23.0, absf(speed)))
	steer = move_toward(steer, -turning * angle_limit, 2.9 * delta)
	var next_heading := wrapf(heading + speed / wheelbase * tan(steer) * float(details.grip) * delta, -PI, PI)
	if absf(speed) > .01:
		var travel := Vector3.FORWARD.rotated(Vector3.UP, lerp_angle(heading, next_heading, .5)) * speed * delta
		var destination := global_position + travel
		var feet := footprint(destination, next_heading)
		var elevation := mean_height(feet)
		var lowest_wheel := minf(minf(feet[0], feet[1]), minf(feet[2], feet[3]))
		var permitted := lowest_wheel > -.055 and absf(elevation - global_position.y) < .22 + travel.length() * .50
		var next := Transform3D(ground_basis(next_heading, feet), Vector3(destination.x, elevation, destination.z))
		if permitted and not test_move(next, Vector3.ZERO, null, .004, true):
			var contact := move_and_collide(next.origin - global_position, false, .004)
			if contact == null:
				global_basis = next.basis
				heading = next_heading
				spinning = wrapf(spinning - travel.length() * signf(speed) / model.radius, -PI, PI)
			else:
				speed = 0.0
				blocked = true
		else:
			speed = 0.0
			blocked = true
	if blocked:
		recovery_seconds = 1.0
	braking = braking or blocked
	var acceleration := clampf((speed - previous) / maxf(.001, delta), -10.0, 6.0)
	sway = lerpf(sway, -steer * clampf(absf(speed) / 8.0, 0, 1) * .09, 1.0 - exp(-delta * 7.0))
	dive = lerpf(dive, acceleration * .0045, 1.0 - exp(-delta * 7.0))
	model.rotation = Vector3(dive, 0, sway)
	present(delta, occupied, absf(pedal))


func present(delta: float, occupied: bool, load: float) -> void:
	model.animate(spinning, steer, braking, lamps_on, speed)
	if occupied and not engine.playing:
		engine.play()
	elif not occupied and engine.playing:
		engine.stop()
	if not occupied:
		return
	var road_rpm := fmod(absf(speed) / 6.5, 1.0)
	var revs := .74 + road_rpm * .40 + minf(absf(speed) / 26.0, 1.0) * .31 + load * .20
	engine.pitch_scale = lerpf(engine.pitch_scale, revs * float(details.tone), 1.0 - exp(-delta * 8.0))
	engine.volume_db = lerpf(engine.volume_db, -22.0 + load * 7.0, 1.0 - exp(-delta * 8.0))


static func engine_sample() -> AudioStreamWAV:
	return AudioTexture.loop_texture(7303, 38.0, .12, .55)
