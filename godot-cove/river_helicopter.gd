extends Node3D

const Kit = preload("res://scenery.gd")
const AudioTexture = preload("res://audio_texture.gd")
const Tools = preload("res://crew_tools.gd")
const SEATS := [Vector3(.40, .08, -.62), Vector3(-.40, .08, -.62), Vector3(.40, .08, .45), Vector3(-.40, .08, .45)]
var game: Node3D
var campaign: Node3D
var craft: CharacterBody3D
var seats: Dictionary = {}
var rotor: Node3D
var tail_rotor: Node3D
var rotor_speed := 0.0
var controls := Vector3.ZERO
var turn_input := 0.0
var control_age := 0.0
var packet_age := 0.0
var target_pose := Transform3D.IDENTITY
var target_velocity := Vector3.ZERO
var established := false
var old_seat := -1
var saved_mask := 1
var hud: Label
var sound: AudioStreamPlayer3D


func setup(scene: Node3D) -> void:
	game = scene
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
	hud = Label.new()
	hud.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	hud.add_theme_font_size_override("font_size", 17)
	game.hud.add_child(hud)
	hud.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hud.offset_top = -160
	hud.offset_bottom = -112
	hud.hide()


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
	sign.text = "McANULTY ROAD\nRIVER SURVEY HELICOPTER\nE  Board / leave when landed"
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
		Tools.tube(craft, Vector3(side*.92,.16,-1.45), Vector3(side*.92,.16,1.70), .055,.055,dark)
		for z in [-.85, 1.05]:
			Tools.tube(craft, Vector3(side*.92,.17,z), Vector3(side*.66,.68,z), .035,.035,metal)
		Tools.tube(craft,Vector3(side*.74,.63,-1.12),Vector3(side*.62,1.92,-.90),.025,.025,metal)
		Tools.tube(craft,Vector3(side*.62,1.92,-.90),Vector3(0,2.03,.08),.025,.025,metal)
		Tools.tube(craft,Vector3(side*.74,.63,-1.12),Vector3(0,.70,-1.58),.035,.035,yellow)
		Tools.tube(craft,Vector3(0,.70,-1.58),Vector3(side*.62,1.92,-.90),.025,.025,metal)
		Tools.tube(craft,Vector3(side*.81,.65,.28),Vector3(side*.81,1.93,.28),.035,.035,yellow)
	for at: Vector3 in SEATS:
		Kit.box_at(craft, at+Vector3(0,.77,0),Vector3(.58,.13,.54),dark)
		Kit.box_at(craft, at+Vector3(0,1.10,.23),Vector3(.58,.64,.10),dark)
	Kit.box_at(craft,Vector3(0,1.1,-1.10),Vector3(1.24,.25,.24),dark)
	for x in [-.37, .37]:
		Kit.box_at(craft,Vector3(x,1.25,-1.075),Vector3(.26,.15,.02),Kit.paint(Color("#76b9ad"),.7))
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
	sound = AudioStreamPlayer3D.new()
	craft.add_child(sound)
	sound.position.y = 2
	sound.max_distance = 220
	sound.unit_size = 8
	sound.volume_db = -15
	sound.stream = AudioTexture.loop_texture(7304, 24.0, .10, .45)


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
	if mounted():
		campaign.request("aircraft_leave", false)
		return true
	if game.player.global_position.distance_to(craft.global_position) < 3.2 and campaign.aiming(craft.global_position+Vector3.UP,4,.70):
		campaign.request("aircraft_board",null)
		return true
	return false


func input(event: InputEvent) -> bool:
	if mounted() and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_E and game.play_input():
		return interact()
	return false


func act(peer: int, action: String, emergency: Variant) -> void:
	if action == "aircraft_leave":
		if not seats.has(peer): return
		if emergency != true and (altitude()>2.4 or craft.velocity.length()>3):
			campaign.tell(peer,"Land and slow down before leaving. Esc > Unstuck can recover you in an emergency.")
			return
		remove_peer(peer)
		return
	if action != "aircraft_board" or seats.has(peer) or seats.size() >= 4: return
	var person: Dictionary = campaign.actor(peer)
	if person.is_empty() or Vector3(person.at).distance_to(craft.global_position)>4 or altitude()>2.4 or craft.velocity.length()>3 \
			or campaign.captain == peer or not campaign.amenities.seat_kind(peer).is_empty() \
			or not campaign.crewplay.held_by(peer).is_empty() or not campaign.crewplay.held_fish(peer).is_empty(): return
	for seat in 4:
		if not seats.values().has(seat):
			seats[peer] = seat
			break
	publish_seats()


func remove_peer(peer: int) -> void:
	if not seats.has(peer): return
	seats.erase(peer)
	if pilot() == 0 and not seats.is_empty(): seats[seats.keys()[0]] = 0
	controls = Vector3.ZERO
	turn_input = 0
	publish_seats()


func publish_seats() -> void:
	apply_local_seat()
	if campaign.crew.on_server(): occupants.rpc(seats)


func welcome(peer: int) -> void:
	occupants.rpc_id(peer,seats)
	flight.rpc_id(peer,craft.global_transform,craft.velocity,rotor_speed)


@rpc("authority","call_remote","reliable")
func occupants(value: Dictionary) -> void:
	seats = value.duplicate()
	apply_local_seat()


@rpc("authority","call_remote","unreliable_ordered",1)
func flight(pose: Transform3D, velocity: Vector3, speed: float) -> void:
	target_pose = pose
	target_velocity = velocity
	rotor_speed = speed
	if not established or craft.global_position.distance_to(pose.origin)>30:
		craft.global_transform = pose
	established = true


@rpc("any_peer","call_remote","unreliable_ordered",2)
func steer(movement: Vector3, turn: float) -> void:
	if not campaign.crew.on_server() or multiplayer.get_remote_sender_id() != pilot() or not movement.is_finite() or not is_finite(turn): return
	controls = movement.clamp(Vector3(-1,-1,-1),Vector3.ONE)
	turn_input = clampf(turn,-1,1)
	control_age = 0


func apply_local_seat() -> void:
	var next := my_seat()
	if next == old_seat: return
	if next >= 0:
		if old_seat < 0: saved_mask = game.player.collision_mask
		game.player.collision_mask = 0
		craft.add_collision_exception_with(game.player)
		game.release_line()
		game.sonar_overlay.hide()
		game.yaw = craft.rotation.y
		game.pitch = -.10
	else:
		game.player.collision_mask = saved_mask
		craft.remove_collision_exception_with(game.player)
		var safe: Vector3 = game.safety.find_near(craft.global_position+craft.global_basis.x*2,12)
		if not safe.is_finite():
			var closest := INF
			for site: Dictionary in campaign.landings.sites:
				var distance: float = craft.global_position.distance_squared_to(site.stand)
				if distance < closest:
					var candidate: Vector3 = game.safety.find_near(site.stand,5)
					if candidate.is_finite():
						safe = candidate
						closest = distance
		if safe.is_finite(): game.player.global_position = safe
		game.player.velocity = Vector3.ZERO
		game.eye.position = Vector3(0,1.58,0)
		game.update_view()
	old_seat = next


func escape() -> void:
	if mounted():
		campaign.request("aircraft_leave",true)
		seats.erase(campaign.crew.my_id())
		apply_local_seat()


func tick(delta: float, has_input: bool) -> void:
	apply_local_seat()
	packet_age += delta
	control_age += delta
	if my_seat() == 0:
		var movement := Vector3(game.axis(KEY_D,KEY_A),game.axis(KEY_SPACE,KEY_CTRL),game.axis(KEY_W,KEY_S)) if has_input else Vector3.ZERO
		var turn: float = game.axis(KEY_Z,KEY_Q) if has_input else 0
		if campaign.crew.is_guest():
			if packet_age >= .05: steer.rpc_id(1,movement,turn)
		else:
			controls = movement
			turn_input = turn
			control_age = 0
	var previous_heading := craft.rotation.y
	if not campaign.crew.is_guest():
		if control_age > .4:
			controls = Vector3.ZERO
			turn_input = 0
		rotor_speed = move_toward(rotor_speed,1.0 if not seats.is_empty() else 0.0,delta*.45)
		craft.rotation.y += turn_input * delta * .65
		var wanted := craft.global_basis * Vector3(controls.x,0,-controls.z).limit_length(1) * 24
		wanted.y = controls.y*7 if not seats.is_empty() else -2
		if rotor_speed < .85: wanted = Vector3.DOWN*2
		var horizontal := Vector2(craft.velocity.x,craft.velocity.z).move_toward(Vector2(wanted.x,wanted.z),delta*6)
		craft.velocity = Vector3(horizontal.x,move_toward(craft.velocity.y,wanted.y,delta*4),horizontal.y)
		craft.move_and_slide()
		var floor_height: float = maxf(0,game.river.ground_height(craft.global_position.x,craft.global_position.z))+.12
		if craft.global_position.y < floor_height:
			craft.global_position.y = floor_height
			craft.velocity.y = maxf(0,craft.velocity.y)
		if craft.global_position.y > floor_height+300:
			craft.global_position.y = floor_height+300
			craft.velocity.y = minf(0,craft.velocity.y)
		craft.global_position.x = clampf(craft.global_position.x,10,game.river.extent.x-10)
		craft.global_position.z = clampf(craft.global_position.z,10,game.river.extent.y-10)
		if campaign.crew.on_server() and packet_age >= .05: flight.rpc(craft.global_transform,craft.velocity,rotor_speed)
	else:
		craft.global_transform = craft.global_transform.interpolate_with(target_pose,1-exp(-delta*18))
		craft.velocity = target_velocity
	if packet_age >= .05: packet_age = 0
	rotor.rotation.y = fposmod(rotor.rotation.y + delta*rotor_speed*38,TAU)
	tail_rotor.rotation.x = fposmod(tail_rotor.rotation.x + delta*rotor_speed*53,TAU)
	if rotor_speed > .05:
		if not sound.playing: sound.play()
		sound.pitch_scale = .45+.55*rotor_speed
	else: sound.stop()
	if mounted():
		game.yaw += wrapf(craft.rotation.y-previous_heading,-PI,PI)
		game.player.global_position = craft.to_global(SEATS[my_seat()])
		game.player.rotation.y = game.yaw
		game.player.velocity = craft.velocity
		game.eye.global_basis = Basis.from_euler(Vector3(game.pitch,game.yaw,0))
	hud.visible = mounted() and not game.menu_blocks_play()
	hud.text = ("PILOT · WASD fly · Q/Z turn · Space/Ctrl climb/descend\n" if my_seat()==0 else "PASSENGER\n") + "Altitude %.0f m · %.0f km/h · E leave when landed" % [altitude(),craft.velocity.length()*3.6]
