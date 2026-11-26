extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Boat = preload("res://houseboat.gd")
const HelmConsole = preload("res://boat_helm_console.gd")
const AircraftSteering = preload("res://aircraft_steering.gd")
const Instruments = preload("res://helicopter_instruments.gd")
const STARTUP_CLIP = preload("res://deep_river/helicopter/startup_smoother.wav")
const FLIGHT_LOOP = preload("res://deep_river/helicopter/rotor_flight.wav")
const GROUND_IDLE_LOOP = preload("res://deep_river/helicopter/rotor_ground_idle.wav")
const APPROACH_LOOP = preload("res://deep_river/helicopter/rotor_approach.wav")
const SHUTDOWN_CLIP = preload("res://deep_river/helicopter/rotor_shutdown.wav")
const SEATS := [Vector3(.40, .08, -.62), Vector3(-.40, .08, -.62), Vector3(.40, .08, .45), Vector3(-.40, .08, .45)]
const DOOR_HANDLE := Vector3(.86, 1.30, -.58)
const PITCH_LIMIT := deg_to_rad(24.0)
const BANK_LIMIT := deg_to_rad(22.0)
const BANK_INPUT_RATE := deg_to_rad(40.0)
const PARKED_LOOK_LIMIT := deg_to_rad(65.0)
const TURN_RATE := deg_to_rad(75.0)
const ATTITUDE_RATE := deg_to_rad(65.0)
const ANGULAR_RESPONSE := 14.0
const AIM_LEAD := deg_to_rad(100.0)
const PACKET_INTERVAL := .05
const SKID_CLEARANCE := .15
const RUN_UP_STAGE_SPEED := .90
const RUN_UP_INITIAL_RATE := RUN_UP_STAGE_SPEED / 6.0
const RUN_UP_FINAL_RATE := (1.0 - RUN_UP_STAGE_SPEED) / 4.0
const STARTUP_CATCH_SECONDS := .83
const STARTUP_CROSSFADE := .75
const ROTOR_VOLUME_DB := -15.0
const ROTOR_SPIN_DOWN_RATE := .24
const APPROACH_AUDIO_HEIGHT := 8.0
const APPROACH_AUDIO_FULL_HEIGHT := 1.2
const IDLE_BLEND_RATE := 2.0
const KEY_OFF_FADE_RATE := 14.0
var game: Node3D
var campaign: Node3D
var craft: CharacterBody3D
var seats: Dictionary = {}
var rotor: Node3D
var tail_rotor: Node3D
var rotor_speed := 0.0
var ignition_key: Node3D
var ignition := Boat.Ignition.OFF
var crank_time := 0.0
var crank_confirmed := false
var ignition_hold := -1.0
var ignition_prompt: Label
var door_prompt: Label
var steering: AircraftSteering
var instruments: Instruments
var climb_control := 0.0
var roll_control := 0.0
var bank_target := 0.0
var bank_rate := 0.0
var yaw_rate := 0.0
# Absolute yaw and pitch in radians. The guest resends both targets so a lost packet cannot lose mouse motion.
var flight_aim := Vector2.ZERO
var camera_aim := Vector2.ZERO
var hover_pressed := false
var level_bank := false
var control_age := 0.0
var packet_age := 0.0
var target_pose := Transform3D.IDENTITY
var target_velocity := Vector3.ZERO
var established := false
var old_seat := -1
var saved_mask := 1
var aim_marker: Control
var sound: AudioStreamPlayer3D
var startup_audio: AudioStreamPlayer3D
var ground_idle_audio: AudioStreamPlayer3D
var approach_audio: AudioStreamPlayer3D
var shutdown_audio: AudioStreamPlayer3D
var grounded_audio_mix := 0.0
var approach_audio_mix := 0.0
var on_audio_approach := false
var running_audio_gain := 0.0


func setup(scene: Node3D) -> void:
	game = scene
	steering = game.aircraft_steering
	campaign = game.campaign
	name = "RiverHelicopter"
	craft = CharacterBody3D.new()
	craft.name = "SurveyHelicopter"
	craft.collision_layer = 1
	craft.collision_mask = 1
	add_child(craft)
	var shape := CollisionShape3D.new()
	var capsule := CapsuleShape3D.new()
	capsule.radius = .78
	capsule.height = 2.1
	shape.shape = capsule
	shape.position.y = 1.08
	craft.add_child(shape)
	build_pad()
	craft.global_position = game.regions.helipad + Vector3.UP * .16
	target_pose = craft.global_transform
	build_model()
	aim_marker = Control.new()
	aim_marker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(aim_marker)
	ignition_prompt = game.label("Engine stopped", 16, Color("#fff1bc"))
	aim_marker.add_child(ignition_prompt)
	ignition_prompt.position = Vector2(20, -11)
	ignition_prompt.hide()
	door_prompt = game.label("", 16, Color("#fff1bc"))
	game.hud.add_child(door_prompt)
	door_prompt.hide()
	aim_marker.draw.connect(func() -> void:
		aim_marker.draw_arc(Vector2.ZERO, 9, 0, TAU, 32, Color("#172326"), 5, true)
		aim_marker.draw_arc(Vector2.ZERO, 9, 0, TAU, 32, Color("#fff1bc"), 2, true)
		if ignition_prompt.visible and ignition_hold > 0.0:
			var start := -PI * .5
			var end := start + TAU * clampf(ignition_hold / Boat.START_TIME, 0.0, 1.0)
			aim_marker.draw_arc(Vector2.ZERO, 9, start, end, 32, Color("#80e4ba"), 4, true)
	)
	aim_marker.hide()


func build_pad() -> void:
	var body := StaticBody3D.new()
	add_child(body)
	body.global_position = game.regions.helipad
	var pad := CylinderMesh.new()
	pad.top_radius = 7
	pad.bottom_radius = 7
	pad.height = .18
	pad.radial_segments = 48
	Kit.mesh_at(body, pad, Vector3.DOWN * .09, Kit.paint(Color("#727a72"), .96))
	var collision := CollisionShape3D.new()
	var shape := CylinderShape3D.new()
	shape.radius = 7
	shape.height = .18
	collision.shape = shape
	collision.position.y = -.09
	body.add_child(collision)
	var paint := Kit.paint(Color("#e4d8a3"), .89)
	for side in [-1.0, 1.0]:
		Kit.box_at(body, Vector3(side * .9, .012, 0), Vector3(.23, .012, 3.1), paint)
	Kit.box_at(body, Vector3(0, .012, 0), Vector3(1.8, .012, .23), paint)
	var ring := TorusMesh.new()
	ring.inner_radius = 5.2
	ring.outer_radius = 5.32
	ring.rings = 64
	ring.ring_segments = 6
	Kit.mesh_at(body, ring, Vector3.UP * .02, paint).scale.y = .08
	var sign := Label3D.new()
	sign.text = "McANULTY ROAD\nRIVER SURVEY HELICOPTER"
	sign.position = Vector3(0, 1.5, 7.4)
	sign.font_size = 40
	sign.pixel_size = .012
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	body.add_child(sign)


func build_model() -> void:
	var yellow := Kit.paint(Color("#b9a260"), .64, .12)
	var dark := Kit.paint(Color("#263b40"), .73, .12)
	var metal := Kit.paint(Color("#929e99"), .58, .28)
	var glass := Kit.paint(Color(.26,.45,.49,.18), .21, .12)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.albedo_color.a = .32
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	Tools.shell(craft, Vector3(0, 1.25, .64), Vector3(1.85, 1.6, 1.75), yellow)
	Tools.shell(craft, Vector3(0, 1.33, -.59), Vector3(1.78, 1.45, 2.0), glass)
	Kit.box_at(craft, Vector3(0, .57, -.05), Vector3(1.62, .12, 2.55), dark)
	for side in [-1.0, 1.0]:
		Kit.box_at(craft, Vector3(side * .84, DOOR_HANDLE.y, -.29), Vector3(.025, .034, .98), dark)
		Kit.box_at(craft, DOOR_HANDLE * Vector3(side, 1, 1), Vector3(.055, .040, .13), metal)
		Tools.tube(craft, Vector3(side*.92,.16,-1.45), Vector3(side*.92,.16,1.70), .055,.055,dark)
		for z in [-.85, 1.05]:
			Tools.tube(craft, Vector3(side*.92,.17,z), Vector3(side*.66,.68,z), .035,.035,metal)
		Tools.tube(craft,Vector3(side*.74,.63,-1.12),Vector3(side*.62,1.92,-.90),.025,.025,metal)
		Tools.tube(craft,Vector3(side*.62,1.92,-.90),Vector3(0,2.03,.08),.025,.025,metal)
		Tools.tube(craft,Vector3(side*.74,.63,-1.12),Vector3(0,.70,-1.58),.035,.035,yellow)
		Tools.tube(craft,Vector3(side*.81,.65,.28),Vector3(side*.81,1.93,.28),.035,.035,yellow)
	for at: Vector3 in SEATS:
		Kit.box_at(craft, at+Vector3(0,.77,0),Vector3(.58,.13,.54),dark)
		Kit.box_at(craft, at+Vector3(0,1.10,.23),Vector3(.58,.64,.10),dark)
	Kit.box_at(craft,Vector3(0,1.1,-1.10),Vector3(1.24,.25,.24),dark)
	ignition_key = HelmConsole.build_ignition_key(craft, Vector3(.40, 1.18, -.95))
	Kit.box_at(craft, Vector3(.31, 1.235, -1.19), Vector3(.70, .06, .12), dark)
	var bezel := Kit.box_at(craft, Vector3(.31, 1.38, -1.19), Vector3(.74, .30, .035), dark)
	bezel.rotation.x = -.47
	instruments = Instruments.new()
	instruments.position.z = .019
	bezel.add_child(instruments)
	Tools.tube(craft,Vector3(0,1.56,1.1),Vector3(0,1.90,4.72),.24,.075,yellow)
	Kit.box_at(craft,Vector3(0,2.1,4.5),Vector3(.09,1.3,.62),yellow)
	Tools.tube(craft,Vector3(0,1.98,.12),Vector3(0,2.72,.12),.065,.065,metal)
	rotor = Node3D.new()
	craft.add_child(rotor)
	rotor.position = Vector3(0,2.74,.12)
	for angle in [0.0, PI*.5]:
		var blade := Kit.box_at(rotor,Vector3.ZERO,Vector3(6.6,.035,.15),dark)
		blade.rotation.y = angle
	tail_rotor = Node3D.new()
	craft.add_child(tail_rotor)
	tail_rotor.position = Vector3(.18,1.96,4.70)
	for angle in [0.0,PI*.5]:
		var blade := Kit.box_at(tail_rotor,Vector3.ZERO,Vector3(.035,1.05,.075),dark)
		blade.rotation.x = angle
	sound = create_rotor_player("HelicopterFlightRotor", FLIGHT_LOOP, true)
	ground_idle_audio = create_rotor_player("HelicopterGroundIdle", GROUND_IDLE_LOOP, true)
	approach_audio = create_rotor_player("HelicopterApproach", APPROACH_LOOP, true)
	startup_audio = create_rotor_player("HelicopterStartup", STARTUP_CLIP)
	shutdown_audio = create_rotor_player("HelicopterShutdown", SHUTDOWN_CLIP)


func create_rotor_player(player_name: String, stream: AudioStreamWAV, looping := false) -> AudioStreamPlayer3D:
	var player := AudioStreamPlayer3D.new()
	player.name = player_name
	player.position.y = 2.0
	player.max_distance = 220.0
	player.unit_size = 8.0
	player.volume_db = ROTOR_VOLUME_DB
	player.doppler_tracking = AudioStreamPlayer3D.DOPPLER_TRACKING_DISABLED
	if looping:
		var loop := stream.duplicate() as AudioStreamWAV
		loop.loop_mode = AudioStreamWAV.LOOP_FORWARD
		loop.loop_end = roundi(loop.get_length() * loop.mix_rate)
		player.stream = loop
	else:
		player.stream = stream
	craft.add_child(player)
	return player


func my_seat() -> int:
	return int(seats.get(campaign.crew.my_id(), -1))


func mounted() -> bool:
	return my_seat() >= 0


func pilot() -> int:
	for peer: int in seats:
		if seats[peer] == 0: return peer
	return 0


func altitude() -> float:
	return craft.global_position.y - maxf(0, game.river.ground_height(craft.global_position.x,craft.global_position.z))


func interact() -> bool:
	var seat := my_seat()
	if seat >= 0:
		if seat == 0 and at_ignition_key():
			if ignition == Boat.Ignition.RUN:
				campaign.request("aircraft_ignition", "stop")
			elif ignition_hold < 0.0:
				ignition_hold = 0.0
				campaign.request("aircraft_ignition", "start")
		elif focused_on_door(seat):
			campaign.request("aircraft_leave", false)
		return true
	if landed_and_stopped() and seats.size() < SEATS.size() and focused_on_door(seat):
		campaign.request("aircraft_board",null)
		return true
	return false


func input(event: InputEvent) -> bool:
	var seat := my_seat()
	if event is InputEventMouseMotion and seat == 0:
		if game.play_input() and get_window().has_focus() and not game.cabin.busy() and not Input.is_physical_key_pressed(KEY_H):
			var parked := skids_down()
			steering.mouse_motion(event.screen_relative, game.mouse_sensitivity, craft.rotation.y,
				AIM_LEAD, PARKED_LOOK_LIMIT if parked else PITCH_LIMIT, parked)
		return true
	if seat >= 0 and event is InputEventKey and event.pressed and not event.echo and game.play_input():
		if event.physical_keycode == KEY_E:
			return interact()
		if seat == 0 and event.physical_keycode == KEY_H:
			hover_pressed = true
			return true
	return false


func act(peer: int, action: String, value: Variant) -> void:
	if action == "aircraft_ignition":
		if peer != pilot(): return
		match value:
			"start":
				if ignition == Boat.Ignition.OFF and landed_and_stopped():
					control_age = 0.0
					set_ignition(Boat.Ignition.START)
			"cancel":
				if ignition == Boat.Ignition.START:
					set_ignition(Boat.Ignition.OFF)
			"finish":
				if ignition == Boat.Ignition.START:
					crank_confirmed = true
			"stop":
				if ignition == Boat.Ignition.RUN and landed_and_stopped():
					set_ignition(Boat.Ignition.OFF)
		return
	if action == "aircraft_leave":
		if not seats.has(peer): return
		if value == true:
			remove_peer(peer)
			return
		if not landed_and_stopped():
			campaign.tell(peer,"Land and slow down before leaving. Esc > Unstuck can recover you in an emergency.")
			return
		var landing := exit_by_door(seat_side(seats[peer]))
		if not landing.is_finite():
			campaign.tell(peer, "No clear ground beside this door.")
			return
		remove_peer(peer, landing)
		return
	if action != "aircraft_board" or seats.has(peer) or seats.size() >= SEATS.size(): return
	var person: Dictionary = campaign.actor(peer)
	if person.is_empty() or not landed_and_stopped() or Vector3(person.at).distance_to(craft.global_position) > 4 \
			or campaign.captain == peer or not campaign.amenities.seat_kind(peer).is_empty() \
			or not campaign.crewplay.held_by(peer).is_empty() or not campaign.crewplay.held_fish(peer).is_empty(): return
	for seat in SEATS.size():
		if not seats.values().has(seat):
			seats[peer] = seat
			if seat == 0: clear_controls()
			break
	publish_seats()


func remove_peer(peer: int, landing := Vector3.INF) -> void:
	if not seats.has(peer): return
	var was_pilot: bool = seats[peer] == 0
	seats.erase(peer)
	if was_pilot:
		if not seats.is_empty(): seats[seats.keys()[0]] = 0
		clear_controls()
		if ignition == Boat.Ignition.START or seats.is_empty():
			set_ignition(Boat.Ignition.OFF)
	publish_seats(peer, landing)


func publish_seats(leaver := 0, landing := Vector3.INF) -> void:
	apply_local_seat(landing if leaver == campaign.crew.my_id() else Vector3.INF)
	if campaign.crew.on_server(): occupants.rpc(seats, leaver, landing)


func welcome(peer: int) -> void:
	occupants.rpc_id(peer, seats, 0, Vector3.INF)
	flight.rpc_id(peer,craft.global_transform,craft.velocity,rotor_speed,ignition)


@rpc("authority","call_remote","reliable")
func occupants(value: Dictionary, leaver: int, landing: Vector3) -> void:
	seats = value.duplicate()
	apply_local_seat(landing if leaver == campaign.crew.my_id() else Vector3.INF)


@rpc("authority","call_remote","unreliable_ordered",1)
func flight(pose: Transform3D, velocity: Vector3, speed: float, phase: int) -> void:
	target_pose = pose
	target_velocity = velocity
	rotor_speed = speed
	set_ignition(phase)
	if not established or craft.global_position.distance_to(pose.origin)>30:
		craft.global_transform = pose
	established = true


@rpc("any_peer","call_remote","unreliable_ordered",2)
func steer(climb: float, roll: float, aim: Vector2, level: bool) -> void:
	if not campaign.crew.on_server() or multiplayer.get_remote_sender_id() != pilot() \
			or not is_finite(climb) or not is_finite(roll) or not aim.is_finite(): return
	set_controls(climb, roll, aim, level)


func set_controls(climb: float, roll: float, aim: Vector2, level: bool) -> void:
	climb_control = clampf(climb, -1.0, 1.0)
	roll_control = clampf(roll, -1.0, 1.0)
	flight_aim = Vector2(wrapf(aim.x, -PI, PI), clampf(aim.y, -PITCH_LIMIT, PITCH_LIMIT))
	if level:
		bank_target = 0.0
	control_age = 0


func clear_controls() -> void:
	climb_control = 0.0
	roll_control = 0.0
	bank_target = 0.0
	flight_aim = Vector2(craft.rotation.y, 0)


func apply_local_seat(landing := Vector3.INF) -> void:
	var next := my_seat()
	if next == old_seat: return
	ignition_hold = -1.0
	hover_pressed = false
	level_bank = false
	if next >= 0:
		if old_seat < 0: saved_mask = game.player.collision_mask
		game.player.collision_mask = 0
		craft.add_collision_exception_with(game.player)
		game.release_line()
		game.sonar_overlay.hide()
		game.yaw = craft.rotation.y
		game.pitch = -.10
		steering.aim = Vector2(game.yaw, game.pitch)
		camera_aim = steering.aim
		game.eye.rotation = Vector3(game.pitch, 0, 0)
	else:
		game.player.collision_mask = saved_mask
		craft.remove_collision_exception_with(game.player)
		var safe := landing
		if not safe.is_finite():
			safe = game.safety.find_near(craft.global_position + craft.global_basis.x * 2, 12)
		if not safe.is_finite():
			var closest := INF
			for site: Dictionary in campaign.landings.sites:
				var distance: float = craft.global_position.distance_squared_to(site.stand)
				if distance < closest:
					var candidate: Vector3 = game.safety.find_near(site.stand,5)
					if candidate.is_finite():
						safe = candidate
						closest = distance
		if safe.is_finite(): game.safety.move_to(safe)
		game.player.velocity = Vector3.ZERO
		game.eye.position = Vector3(0,1.58,0)
		game.eye.rotation = Vector3(game.pitch, 0, 0)
		game.update_view()
	old_seat = next
	aim_marker.hide()
	ignition_prompt.hide()
	door_prompt.hide()
	game.update_menu_hud()


func escape() -> void:
	if mounted():
		campaign.request("aircraft_leave",true)
		seats.erase(campaign.crew.my_id())
		apply_local_seat()


func tick(delta: float, has_input: bool) -> void:
	apply_local_seat()
	packet_age += delta
	control_age += delta
	var seat := my_seat()
	if seat == 0:
		var climb := 0.0
		var roll := 0.0
		if has_input:
			climb = game.axis(KEY_SPACE, KEY_CTRL)
			roll = game.axis(KEY_D, KEY_A)
			var parked := skids_down()
			if hover_pressed or Input.is_physical_key_pressed(KEY_H):
				steering.aim = Vector2(craft.rotation.y, 0.0)
				climb = 0.0
				roll = 0.0
				level_bank = true
			elif parked and climb > 0.0 and rotor_ready():
				steering.aim = Vector2(craft.rotation.y, 0.0)
				roll = 0.0
			elif not is_zero_approx(roll):
				level_bank = false
		hover_pressed = false
		if campaign.crew.is_guest():
			if packet_age >= PACKET_INTERVAL:
				steer.rpc_id(1, climb, roll, steering.aim, level_bank)
		else:
			set_controls(climb, roll, steering.aim, level_bank)
	var previous_heading := craft.rotation.y
	if not campaign.crew.is_guest():
		if control_age > .4 or seats.is_empty(): clear_controls()
		tick_ignition(delta)
		step_flight(delta)
		if campaign.crew.on_server() and packet_age >= PACKET_INTERVAL:
			flight.rpc(craft.global_transform, craft.velocity, rotor_speed, ignition)
	else:
		craft.global_transform = craft.global_transform.interpolate_with(target_pose,1-exp(-delta*18))
		craft.velocity = target_velocity
	if packet_age >= PACKET_INTERVAL: packet_age = 0
	rotor.rotation.y = fposmod(rotor.rotation.y + delta*rotor_speed*38,TAU)
	tail_rotor.rotation.x = fposmod(tail_rotor.rotation.x + delta*rotor_speed*53,TAU)
	update_rotor_audio(delta)
	instruments.update_readings(rotor_speed, Vector2(craft.velocity.x, craft.velocity.z).length(), altitude(), rotor_ready())
	if seat >= 0:
		game.player.global_position = craft.to_global(SEATS[seat])
		game.player.velocity = craft.velocity
		update_camera(seat, previous_heading, delta)
	aim_marker.visible = seat == 0 and has_input
	var key_focused := aim_marker.visible and at_ignition_key()
	update_ignition_hold(delta, key_focused and ignition != Boat.Ignition.RUN)
	ignition_prompt.visible = key_focused
	ignition_prompt.text = "Engine running" if ignition == Boat.Ignition.RUN else "Engine stopped"
	update_door_prompt(seat, has_input and not key_focused)
	if aim_marker.visible:
		update_aim_marker()
		aim_marker.queue_redraw()


func at_ignition_key() -> bool:
	return landed_and_stopped() and HelmConsole.aims_at_key(ignition_key, seat_eye(0), aim_direction())


func seat_side(seat: int) -> float:
	return 1.0 if SEATS[seat].x > 0.0 else -1.0


func door_at(seat: int) -> Vector3:
	var side := seat_side(seat) if seat >= 0 else signf(craft.to_local(game.eye.global_position).x)
	return craft.to_global(DOOR_HANDLE * Vector3(1.0 if side == 0.0 else side, 1.0, 1.0))


func focused_on_door(seat: int) -> bool:
	var eye: Camera3D = game.eye
	var offset := door_at(seat) - eye.global_position
	var forward := aim_direction() if seat == 0 else -eye.global_basis.z
	return offset.length_squared() < 3.2 * 3.2 and offset.normalized().dot(forward) > .94


func update_door_prompt(seat: int, has_input: bool) -> void:
	door_prompt.visible = has_input and landed_and_stopped() and (seat >= 0 or seats.size() < SEATS.size()) \
		and focused_on_door(seat)
	if door_prompt.visible:
		door_prompt.text = "Exit available" if seat >= 0 else "Press E to board"
		door_prompt.position = game.eye.unproject_position(door_at(seat)) + Vector2(18.0, -11.0)


func exit_by_door(side: float) -> Vector3:
	for offset_x: float in [1.45, 1.8, 2.2, 2.6]:
		for offset_z: float in [0.0, -.45, .45]:
			var at := craft.to_global(Vector3(side * offset_x, 0.0, DOOR_HANDLE.z + offset_z))
			var clear: Vector3 = game.safety.ground_at(at)
			if clear.is_finite() and clear.y > .10 and absf(clear.y - at.y) < 1.3:
				return clear
	return Vector3.INF


func update_ignition_hold(delta: float, focused: bool) -> void:
	if ignition_hold < 0.0:
		return
	if not focused or not Input.is_physical_key_pressed(KEY_E):
		if ignition_hold < Boat.START_TIME:
			campaign.request("aircraft_ignition", "cancel")
		ignition_hold = -1.0
	elif ignition_hold < Boat.START_TIME:
		ignition_hold = minf(Boat.START_TIME, ignition_hold + delta)
		if ignition_hold >= Boat.START_TIME:
			campaign.request("aircraft_ignition", "finish")


func set_ignition(phase: int) -> void:
	if ignition == phase:
		return
	var was_running := ignition == Boat.Ignition.RUN
	ignition = phase
	ignition_key.rotation.z = [0.0, -.91, -.47][phase]
	crank_time = 0.0
	crank_confirmed = false
	if phase == Boat.Ignition.OFF:
		startup_audio.stop()
		on_audio_approach = false
		if was_running and rotor_speed > .01:
			shutdown_audio.play((1.0 - rotor_speed) / ROTOR_SPIN_DOWN_RATE)
	elif phase == Boat.Ignition.START:
		shutdown_audio.stop()
		startup_audio.volume_db = ROTOR_VOLUME_DB
		startup_audio.play()
	elif not startup_audio.playing and rotor_speed < 1.0:
		# A joining peer may receive RUN after the key was turned.
		var run_up_elapsed := minf(rotor_speed, RUN_UP_STAGE_SPEED) / RUN_UP_INITIAL_RATE
		run_up_elapsed += maxf(0.0, rotor_speed - RUN_UP_STAGE_SPEED) / RUN_UP_FINAL_RATE
		startup_audio.volume_db = ROTOR_VOLUME_DB
		startup_audio.play(STARTUP_CATCH_SECONDS + run_up_elapsed)


func update_rotor_audio(delta: float) -> void:
	if ignition == Boat.Ignition.RUN:
		running_audio_gain = 1.0
		if startup_audio.playing:
			var remaining := STARTUP_CLIP.get_length() - startup_audio.get_playback_position()
			running_audio_gain = 1.0 - smoothstep(0.0, STARTUP_CROSSFADE, remaining)
			startup_audio.volume_db = ROTOR_VOLUME_DB + linear_to_db(maxf(.001, 1.0 - running_audio_gain))
		var ground_target := 1.0 if landed_and_stopped() and climb_control <= .05 else 0.0
		grounded_audio_mix = move_toward(grounded_audio_mix, ground_target, delta * IDLE_BLEND_RATE)
		approach_audio_mix = move_toward(approach_audio_mix, approach_mix_target(), delta * IDLE_BLEND_RATE)
	else:
		running_audio_gain = move_toward(running_audio_gain, 0.0, delta * KEY_OFF_FADE_RATE)

	if running_audio_gain > .001:
		var airborne_gain := running_audio_gain * (1.0 - grounded_audio_mix)
		sound.volume_db = ROTOR_VOLUME_DB + linear_to_db(maxf(.001, airborne_gain * (1.0 - approach_audio_mix)))
		approach_audio.volume_db = ROTOR_VOLUME_DB + linear_to_db(maxf(.001, airborne_gain * approach_audio_mix))
		ground_idle_audio.volume_db = ROTOR_VOLUME_DB + linear_to_db(maxf(.001, running_audio_gain * grounded_audio_mix))
		if not sound.playing:
			sound.play()
			ground_idle_audio.play()
			approach_audio.play()
	elif sound.playing:
		sound.stop()
		ground_idle_audio.stop()
		approach_audio.stop()


func approach_mix_target() -> float:
	var skid_height := craft.global_position.y - flight_floor(craft.global_position)
	# Keep the descent sound through the flare, then let ground idle take over.
	if skid_height >= APPROACH_AUDIO_HEIGHT or climb_control > .05 or craft.velocity.y > .25:
		on_audio_approach = false
	elif rotor_ready() and craft.velocity.y < -.18:
		on_audio_approach = true
	if not on_audio_approach:
		return 0.0
	return 1.0 - smoothstep(APPROACH_AUDIO_FULL_HEIGHT, APPROACH_AUDIO_HEIGHT, skid_height)


func tick_ignition(delta: float) -> void:
	if ignition != Boat.Ignition.START:
		return
	crank_time += delta
	if control_age > .4 or not landed_and_stopped() or crank_time > Boat.START_TIME + 2.0:
		set_ignition(Boat.Ignition.OFF)
	elif crank_confirmed and crank_time >= Boat.START_TIME:
		set_ignition(Boat.Ignition.RUN)


func rotor_ready() -> bool:
	return ignition == Boat.Ignition.RUN and rotor_speed >= 1.0


func step_rotor(delta: float) -> void:
	if ignition != Boat.Ignition.RUN:
		rotor_speed = move_toward(rotor_speed, 0.0, delta * ROTOR_SPIN_DOWN_RATE)
	elif rotor_speed < RUN_UP_STAGE_SPEED:
		rotor_speed = move_toward(rotor_speed, RUN_UP_STAGE_SPEED, delta * RUN_UP_INITIAL_RATE)
	else:
		rotor_speed = move_toward(rotor_speed, 1.0, delta * RUN_UP_FINAL_RATE)


func flight_floor(at: Vector3) -> float:
	var terrain: float = maxf(0, game.river.ground_height(at.x, at.z)) + .12
	var pad: Vector3 = game.regions.helipad
	if Vector2(at.x - pad.x, at.z - pad.z).length_squared() <= 49:
		return maxf(terrain, pad.y + .04)
	return terrain


func skids_down() -> bool:
	return craft.global_position.y - flight_floor(craft.global_position) <= SKID_CLEARANCE


func landed_and_stopped() -> bool:
	return craft.global_position.y - flight_floor(craft.global_position) <= .055 \
		and absf(craft.velocity.y) < .10 and craft.velocity.length_squared() < .25 * .25


func step_flight(delta: float) -> void:
	step_rotor(delta)
	var ready := rotor_ready()
	var clearance := maxf(0, craft.global_position.y - flight_floor(craft.global_position))
	var airborne := smoothstep(SKID_CLEARANCE, 1.6, clearance) if ready else 0.0
	var angles := craft.rotation
	if clearance <= SKID_CLEARANCE:
		flight_aim = Vector2(angles.y, 0.0)
		yaw_rate = 0.0
		bank_target = 0.0
	else:
		bank_target = clampf(bank_target - roll_control * BANK_INPUT_RATE * airborne * delta, -BANK_LIMIT, BANK_LIMIT)
	var heading_error := wrapf(flight_aim.x - angles.y, -PI, PI)
	var pitch_error := flight_aim.y * airborne - angles.x
	var turn_goal := clampf(heading_error * 4, -TURN_RATE, TURN_RATE) * airborne
	var response := 1.0 - exp(-delta * ANGULAR_RESPONSE)
	yaw_rate = lerpf(yaw_rate, turn_goal, response)
	var bank_error := bank_target * airborne - angles.z
	bank_rate = lerpf(bank_rate, clampf(bank_error * 5.0, -ATTITUDE_RATE, ATTITUDE_RATE), response)
	angles.y = wrapf(angles.y + yaw_rate * delta, -PI, PI)
	angles.x += clampf(pitch_error * 5, -ATTITUDE_RATE, ATTITUDE_RATE) * delta
	angles.z = clampf(angles.z + bank_rate * delta, -BANK_LIMIT, BANK_LIMIT)
	craft.rotation = angles

	var forward_speed := 24.0 if angles.x <= 0 else 12.0
	var cyclic := Vector3(-angles.z / BANK_LIMIT * 15.5, 0.0, angles.x / PITCH_LIMIT * forward_speed)
	var wanted := cyclic.limit_length(24.0).rotated(Vector3.UP, angles.y) * airborne
	var horizontal := Vector2(craft.velocity.x, craft.velocity.z)
	var wanted_horizontal := Vector2(wanted.x, wanted.z)
	var acceleration := 6.4 if horizontal.dot(wanted_horizontal - horizontal) > 0 else 8.6
	horizontal = horizontal.move_toward(wanted_horizontal, delta * lerpf(32.0, acceleration, airborne))

	var vertical := climb_control * 6.0 if ready else -2.0
	var descent_limit := lerpf(.65, 6.0, smoothstep(0, 10, clearance))
	vertical = maxf(vertical, -descent_limit)
	var vertical_acceleration := lerpf(2.2, 6.0, airborne) if vertical > maxf(0.0, craft.velocity.y) else 8.0
	craft.velocity = Vector3(horizontal.x, move_toward(craft.velocity.y, vertical, delta * vertical_acceleration), horizontal.y)
	craft.move_and_slide()
	craft.global_position.x = clampf(craft.global_position.x, 10, game.river.extent.x - 10)
	craft.global_position.z = clampf(craft.global_position.z, 10, game.river.extent.y - 10)
	var floor_height := flight_floor(craft.global_position)
	if craft.global_position.y <= floor_height:
		craft.global_position.y = floor_height
		craft.velocity = Vector3.UP * maxf(0, craft.velocity.y)
	elif craft.global_position.y > floor_height + 300:
		craft.global_position.y = floor_height + 300
		craft.velocity.y = minf(0, craft.velocity.y)


func seat_eye(seat: int) -> Vector3:
	return craft.to_global(SEATS[seat] + Vector3.UP * game.STANDING_EYE)


func update_camera(seat: int, previous_heading: float, delta: float) -> void:
	if seat == 0:
		var weight := 1.0 - exp(-delta * 23.0)
		camera_aim.x = lerp_angle(camera_aim.x, steering.aim.x, weight)
		camera_aim.y = lerpf(camera_aim.y, steering.aim.y, weight)
		game.yaw = camera_aim.x
		game.pitch = camera_aim.y
	else:
		game.yaw += wrapf(craft.rotation.y - previous_heading, -PI, PI)
	game.player.rotation.y = game.yaw
	game.eye.global_basis = Basis.from_euler(Vector3(game.pitch, game.yaw, 0))
	game.eye.global_position = seat_eye(seat)


func aim_direction() -> Vector3:
	return -Basis.from_euler(Vector3(steering.aim.y, steering.aim.x, 0)).z


func update_aim_marker() -> void:
	var eye: Camera3D = game.eye
	var direction := eye.global_basis.inverse() * aim_direction()
	direction.z = minf(-.1, direction.z)
	var screen := eye.unproject_position(eye.to_global(direction * 10))
	var margin := Vector2(20, 20)
	aim_marker.position = screen.clamp(margin, eye.get_viewport().get_visible_rect().size - margin)
