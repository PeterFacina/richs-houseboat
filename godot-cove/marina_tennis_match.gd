extends Node3D

const Kit = preload("res://scenery.gd")
const RichModel = preload("res://rich_model.gd")
const WIN_SCORE := 7
const HALF_WIDTH := 4.115
const BASELINE := 11.885
const BALL_RADIUS := .095
const GRAVITY := 12.8
const COATING_LIFT := .085
const PLAYER_START := Vector2(0, 8.6)
const RICH_START := Vector2(0, -8.7)
const CHALLENGE_SPOT := Vector2(3.9, 2.45)
const POINT_BREAK := 2.1
const SWING_TIME := .32

enum Phase { IDLE, BETWEEN_POINTS, RALLY, RESULT }
signal reset_player(at: Vector3, toward: Vector3)
signal ended

var active: bool:
	get:
		return phase != Phase.IDLE

var phase := Phase.IDLE
var player_points := 0
var rich_points := 0
var message := ""
var wait := 0.0
var player_swing := 0.0
var rich_swing := 0.0
var swing_pending := false
var rich_distance := 0.0
var rich: RichModel
var racket: Node3D
var ball: MeshInstance3D
var shadow: MeshInstance3D
var ground: Callable
var net_top: Callable
var net_half_span: float
var ball_velocity := Vector3.ZERO
var landing := Vector2.ZERO
var from_player := false
var bounced := false
var serve := true
var clean_shot := false


func build(height: Callable, half_span: float, net_height: Callable) -> void:
	ground = height
	net_half_span = half_span
	net_top = net_height
	rich = RichModel.new()
	rich.name = "CourtsideRich"
	add_child(rich)
	rich.build(false)
	rich.hide()
	build_racket(rich.wrists[1], Vector3(0, -.04, .08)).rotation.x = -1.45
	var sphere := SphereMesh.new()
	sphere.radius = BALL_RADIUS
	sphere.height = BALL_RADIUS * 2.0
	sphere.radial_segments = 16
	sphere.rings = 8
	var felt := Kit.paint(Color("#dcf454"), .82)
	felt.emission_enabled = true
	felt.emission = Color("#93a828")
	felt.emission_energy_multiplier = .28
	ball = Kit.mesh_at(self, sphere, Vector3.ZERO, felt)
	var disc := CylinderMesh.new()
	disc.top_radius = .19
	disc.bottom_radius = .19
	disc.height = .012
	disc.radial_segments = 12
	shadow = Kit.mesh_at(self, disc, Vector3.ZERO, Kit.paint(Color("#384737")))
	shadow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	leave()


func prepare_player(camera: Camera3D) -> void:
	racket = build_racket(camera, Vector3(.33, -.47, -.60))
	racket.scale = Vector3.ONE * .72
	racket.hide()


func near_challenge(at: Vector3) -> bool:
	return to_global(feet_at(CHALLENGE_SPOT)).distance_squared_to(at) < 16.0 * 16.0


func focused(camera: Camera3D, player: CharacterBody3D) -> bool:
	if active or not rich.visible or player.global_position.distance_squared_to(rich.global_position) > 3.4 * 3.4:
		return false
	var target := rich.global_position + Vector3.UP * 1.34
	if (target - camera.global_position).normalized().dot(-camera.global_basis.z) < .92:
		return false
	var ray := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(ray).is_empty()


func start() -> void:
	player_points = 0
	rich_points = 0
	queue_point("First to seven. Winner gets bragging rights at the boat launch.")
	racket.show()


func leave() -> void:
	var was_active := active
	phase = Phase.IDLE
	player_swing = 0.0
	rich_swing = 0.0
	swing_pending = false
	rich.position = feet_at(CHALLENGE_SPOT)
	rich.rotation.y = PI * .5
	ball.hide()
	shadow.hide()
	if is_instance_valid(racket):
		racket.hide()
	if was_active:
		ended.emit()


func swing() -> void:
	if phase in [Phase.BETWEEN_POINTS, Phase.RALLY] and player_swing <= 0.0:
		player_swing = SWING_TIME
		swing_pending = phase == Phase.RALLY


func score_text() -> String:
	return "Tennis   ·   You %d — %d Rich   ·   First to %d" % [player_points, rich_points, WIN_SCORE]


func instruction_text(camera: Camera3D) -> String:
	var line := "Rich: " + message
	if phase == Phase.RALLY:
		if from_player:
			line = "Clean hit!" if clean_shot else "Shot away"
		else:
			line = "Swing now" if can_hit(camera) else "Track the ball and hit after the bounce"
	elif phase == Phase.RESULT:
		return line + "\nEsc  Leave court"
	return line + "\nWASD  Move   ·   Mouse  Aim   ·   LMB  Swing   ·   Esc  Quit"


func tick(delta: float, clock: float, player: CharacterBody3D, camera: Camera3D, can_play: bool,
		has_input: bool) -> void:
	rich.visible = can_play
	if not can_play:
		if active:
			leave()
		return
	var local_feet := to_local(player.global_position)
	if not active:
		if local_feet.distance_squared_to(rich.position) < 18.0 * 18.0:
			var offset := local_feet - rich.position
			rich.pose(delta, clock, wrapf(atan2(offset.x, offset.z) - rich.rotation.y, -PI, PI),
				0.0, "", 0.0, 0.0)
		return
	if absf(local_feet.x) > 7.0 or local_feet.z < -.2 or local_feet.z > BASELINE + 4.0:
		leave()
		return
	if not has_input:
		return

	player_swing = maxf(0.0, player_swing - delta)
	rich_swing = maxf(0.0, rich_swing - delta)
	var arc := sin(PI * player_swing / SWING_TIME)
	racket.rotation = Vector3(-.30 - .90 * arc, -.24 - 1.15 * arc, -.34 - .75 * arc)
	racket.position = Vector3(.33 - .28 * arc, -.47 + .10 * arc, -.60)
	var previous_rich := rich.position
	match phase:
		Phase.BETWEEN_POINTS:
			wait -= delta
			if wait <= 0.0:
				feed_ball()
		Phase.RALLY:
			tick_rally(delta, camera, local_feet)
		Phase.RESULT:
			wait -= delta
			if wait <= 0.0:
				leave()
	var travel := rich.position.distance_to(previous_rich)
	rich_distance += travel
	var look := local_feet - rich.position
	rich.rotation.y = lerp_angle(rich.rotation.y, atan2(look.x, look.z), 1.0 - exp(-delta * 10.0))
	rich.pose(delta, clock, 0.0, 0.0, "", 0.0, 0.0, rich_distance, travel / delta / 2.8)
	if rich_swing > 0.0:
		var swing_arc := sin(PI * rich_swing / SWING_TIME)
		rich.upper_arms[1].rotation = rich.upper_arms[1].rotation.lerp(Vector3(-1.35, -.45, -.54), swing_arc)


func queue_point(line: String) -> void:
	phase = Phase.BETWEEN_POINTS
	wait = POINT_BREAK
	message = line
	player_swing = 0.0
	rich_swing = 0.0
	swing_pending = false
	ball.hide()
	shadow.hide()
	rich.position = feet_at(RICH_START)
	rich.rotation.y = 0.0
	reset_player.emit(to_global(feet_at(PLAYER_START)), rich.global_position)


func feed_ball() -> void:
	phase = Phase.RALLY
	ball.position = rich.position + Vector3(0, 1.55, .56)
	var feed_x: float = [0.0, -1.7, 1.7][(player_points + rich_points) % 3]
	hit_toward(Vector2(feed_x, 6.35), 1.53, false)
	serve = true
	rich_swing = SWING_TIME
	ball.show()
	shadow.show()


func hit_toward(target: Vector2, flight_time: float, player_hit: bool) -> void:
	var at := feet_at(target) + Vector3.UP * (BALL_RADIUS + COATING_LIFT)
	ball_velocity = (at - ball.position) / flight_time + Vector3.UP * (.5 * GRAVITY * flight_time)
	landing = target
	bounced = false
	from_player = player_hit
	serve = false
	swing_pending = false


func can_hit(camera: Camera3D) -> bool:
	if phase != Phase.RALLY or from_player or not bounced:
		return false
	var reach := ball.global_position - camera.global_position
	return reach.length_squared() <= 2.35 * 2.35 and reach.normalized().dot(-camera.global_basis.z) > .68


func tick_rally(delta: float, camera: Camera3D, local_feet: Vector3) -> void:
	if swing_pending and player_swing >= SWING_TIME - .18 and can_hit(camera):
		var aim := global_basis.inverse() * -camera.global_basis.z
		var x := clampf(ball.position.x + aim.x * 12.5, -3.92, 3.92)
		var depth := clampf(8.4 + aim.y * 9.0, 5.5, 11.35)
		var height := ball.position.y - feet_at(Vector2(ball.position.x, ball.position.z)).y
		clean_shot = absf(height - 1.18) < .38
		hit_toward(Vector2(x, -depth), 1.06 if clean_shot else 1.57, true)

	if from_player and ball.position.z < -1.5:
		var receiver := Vector2(clampf(landing.x, -3.85, 3.85), maxf(-12.35, landing.y - 1.5))
		rich.position = feet_at(Vector2(rich.position.x, rich.position.z).move_toward(receiver, delta * 3.65))
		var gap := ball.position - rich.position
		if bounced and Vector2(gap.x, gap.z).length_squared() < 1.40 * 1.40 and gap.y > .56 and gap.y < 1.9:
			var reply_x := clampf(-local_feet.x * .58 + signf(rich.position.x) * -.65, -3.2, 3.2)
			hit_toward(Vector2(reply_x, 6.0 + absf(rich.position.x) * .34), 1.35, false)
			rich_swing = SWING_TIME
	elif not from_player:
		var recovery := Vector2(rich.position.x, rich.position.z).move_toward(RICH_START, delta * 3.4)
		rich.position = feet_at(recovery)

	var previous := ball.position
	ball.position += ball_velocity * delta - Vector3.UP * (.5 * GRAVITY * delta * delta)
	ball_velocity.y -= GRAVITY * delta
	if previous.z * ball.position.z <= 0.0 and not is_equal_approx(previous.z, ball.position.z):
		var crossing := previous.lerp(ball.position, inverse_lerp(previous.z, ball.position.z, 0.0))
		if absf(crossing.x) <= net_half_span and crossing.y - BALL_RADIUS <= float(net_top.call(crossing.x)):
			finish_point(not from_player, "Net. You can blame the wind if you like." if from_player else "That net's got a grudge.")
			return

	var at := Vector2(ball.position.x, ball.position.z)
	var floor_y := feet_at(at).y + COATING_LIFT
	shadow.position = Vector3(at.x, floor_y + .014, at.y)
	if ball.position.y <= floor_y + BALL_RADIUS and ball_velocity.y < 0.0:
		if bounced:
			finish_point(from_player, "My knees filed a grievance." if from_player else "Two bounces. Even my boat would've reached that.")
			return
		var receiving_depth := -at.y if from_player else at.y
		if absf(at.x) > HALF_WIDTH + BALL_RADIUS or receiving_depth <= 0.0 or receiving_depth > BASELINE + BALL_RADIUS:
			finish_point(not from_player, "Out. Wrong side of the river." if from_player else "Must've been a gust off the Ottawa.")
			return
		bounced = true
		ball.position.y = floor_y + BALL_RADIUS
		ball_velocity = Vector3(ball_velocity.x * .80, -ball_velocity.y * (.75 if serve else .79), ball_velocity.z * .80)


func finish_point(player_won: bool, line: String) -> void:
	player_points += int(player_won)
	rich_points += int(not player_won)
	if maxi(player_points, rich_points) < WIN_SCORE:
		queue_point(line)
		return
	phase = Phase.RESULT
	wait = 5.5
	swing_pending = false
	ball.hide()
	shadow.hide()
	message = "You win. I'll tell the lads it was doubles." if player_won else "That's seven. Put it in the ship's log."


func feet_at(at: Vector2) -> Vector3:
	var world := to_global(Vector3(at.x, 0, at.y))
	return Vector3(at.x, float(ground.call(world.x, world.z)) - global_position.y, at.y)


static func build_racket(parent: Node3D, at: Vector3) -> Node3D:
	var grip := Node3D.new()
	grip.name = "TennisRacket"
	parent.add_child(grip)
	grip.position = at
	var frame := TorusMesh.new()
	frame.inner_radius = .108
	frame.outer_radius = .123
	frame.rings = 16
	frame.ring_segments = 8
	var hoop := Kit.mesh_at(grip, frame, Vector3.UP * .26, Kit.paint(Color("#d0b165")))
	hoop.rotation.x = PI * .5
	hoop.scale.z = 1.22
	Kit.box_at(grip, Vector3.UP * .066, Vector3(.035, .151, .031), Kit.paint(Color("#293d45")))
	var strings := Kit.paint(Color("#bfcbac"))
	for i in range(-2, 3):
		var offset := i * .033
		var span := 2.0 * sqrt(.109 * .109 - offset * offset)
		Kit.box_at(grip, Vector3(offset, .26, 0), Vector3(.0035, span * 1.22, .0035), strings)
		Kit.box_at(grip, Vector3(0, .26 + offset * 1.22, 0), Vector3(span, .0035, .0035), strings)
	return grip
