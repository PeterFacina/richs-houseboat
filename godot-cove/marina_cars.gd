extends Node3D

const Kit = preload("res://scenery.gd")
const RoadCar = preload("res://marina_car.gd")
const Model = preload("res://marina_car_model.gd")
const Map = preload("res://ottawa_map.gd")
const Yard = preload("res://public_works.gd")
const VehicleExit = preload("res://vehicle_exit.gd")
# Inland from the promenade, between the access road and the launch approach.
const LOT := Vector3(18022.6, 0, 12636.8)
const LOT_ANGLE := .16
const BAY_WIDTH := 2.78
const BAY_COUNT := 6

var game: Node3D
var river: Map
var crew: Node
var cars: Array[RoadCar] = []
var drivers := PackedInt32Array()
var remote_input: Dictionary = {}
var snapshot: Array = []
var known_peers := PackedInt32Array()
var send_in := 0.0
var active := -1
var focused := -1
var camera_yaw := 0.0
var camera_pitch := .24
var camera_position: Vector3
var cockpit_view := false
var collision_layer_on_foot: int
var collision_mask_on_foot: int


func setup(fishing_game: Node3D, map: Map, river_crew: Node) -> void:
	game = fishing_game
	river = map
	crew = river_crew
	var sound := RoadCar.engine_sample()
	build_bays()
	for i in Model.MODELS.size():
		add_vehicle("Car%d" % i, Model.MODELS[i], bay(i * BAY_WIDTH, 0), LOT_ANGLE, sound)
	for i in Yard.TRUCK_PARKING.size():
		var slot: Vector3 = Yard.TRUCK_PARKING[i]
		add_vehicle("PublicWorksTruck%d" % (i + 1), Model.WORK_TRUCKS[i],
			Vector3(slot.x, 0, slot.z), slot.y, sound)
	crew.changed.connect(crew_changed)
	crew.member_left.connect(driver_left)


func add_vehicle(node_name: String, model: Dictionary, at: Vector3, heading: float, sound: AudioStreamWAV) -> void:
	var car := RoadCar.new()
	car.name = node_name
	add_child(car)
	car.setup(model, at, heading, river.ground_height, sound)
	cars.append(car)
	drivers.append(0)


func bay(x: float, z: float) -> Vector3:
	return LOT + Vector3(x, 0, z).rotated(Vector3.UP, LOT_ANGLE)


func build_bays() -> void:
	var paint := Kit.paint(Color("#d9cdab"))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in BAY_COUNT + 1:
		var x := (float(i) - .5) * BAY_WIDTH
		paint_stripe(mesh, x, x + .088, -2.95, 2.75)
	for i in BAY_COUNT:
		var x := float(i) * BAY_WIDTH
		paint_stripe(mesh, x - .77, x + .77, 2.32, 2.43)
	var markings := Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, paint)
	markings.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	markings.visibility_range_end = 140.0


func paint_stripe(mesh: SurfaceTool, x0: float, x1: float, z0: float, z1: float) -> void:
	var steps := ceili(maxf(x1 - x0, z1 - z0) / .34)
	for i in steps:
		var t := float(i) / steps
		var t2 := float(i + 1) / steps
		for corner: Vector2 in [Vector2(t, t), Vector2(t2, t), Vector2(t, t2),
				Vector2(t2, t), Vector2(t2, t2), Vector2(t, t2)]:
			var point := bay(lerpf(x0, x1, corner.x), lerpf(z0, z1, corner.y))
			point.y = river.ground_height(point.x, point.z) + .035
			mesh.set_normal(Vector3.UP)
			mesh.add_vertex(point)


func find_focus() -> void:
	focused = -1
	if active >= 0 or game.aboard():
		return
	var eye: Camera3D = game.eye
	for car in cars:
		if car.global_position.distance_squared_to(eye.global_position) < 28.0:
			var ray := PhysicsRayQueryParameters3D.create(eye.global_position,
				eye.global_position - eye.global_basis.z * 3.9, 1, [game.player.get_rid()])
			var hit := get_world_3d().direct_space_state.intersect_ray(ray)
			focused = cars.find(hit.collider) if hit.get("collider") is RoadCar else -1
			return


func interact() -> bool:
	if active >= 0:
		if absf(cars[active].speed) > .55:
			game.notify_angling("Stop the vehicle before getting out.", 2.3)
		elif crew.is_guest():
			seat_order.rpc_id(1, active, "exit")
		else:
			release_driver(crew.my_id(), active)
		return true
	find_focus()
	if focused < 0:
		return false
	if drivers[focused] > 0:
		game.notify_angling("Someone is driving this vehicle.", 2.3)
	elif crew.is_guest():
		seat_order.rpc_id(1, focused, "enter")
	else:
		assign_driver(crew.my_id(), focused)
	return true


func toggle_lights() -> void:
	if active < 0:
		return
	if crew.is_guest():
		seat_order.rpc_id(1, active, "lights")
	else:
		cars[active].lamps_on = not cars[active].lamps_on


func assign_driver(peer: int, which: int) -> void:
	if drivers[which] != 0 or drivers.has(peer):
		return
	drivers[which] = peer
	if peer == crew.my_id():
		enter(which)
	broadcast_seats()


func release_driver(peer: int, which: int) -> void:
	if drivers[which] != peer or absf(cars[which].speed) > .65:
		return
	var exit := find_exit(which)
	if exit == Vector3.INF:
		if peer == crew.my_id():
			game.notify_angling("Pull away from the obstacle to step out.", 2.3)
		else:
			exit_blocked.rpc_id(peer)
		return
	drivers[which] = 0
	remote_input.erase(peer)
	if peer == crew.my_id():
		leave(exit)
	else:
		exit_at.rpc_id(peer, exit)
	broadcast_seats()


func find_exit(which: int) -> Vector3:
	var car := cars[which]
	return VehicleExit.find(car, game.player, Vector2(car.body_size.x, car.body_size.z) * .5, car.heading)

func enter(which: int) -> void:
	active = which
	game.release_line()
	game.sonar_overlay.hide()
	game.rod_pressed = false
	collision_layer_on_foot = game.player.collision_layer
	collision_mask_on_foot = game.player.collision_mask
	game.player.collision_layer = 0
	game.player.collision_mask = 0
	game.player.velocity = Vector3.ZERO
	game.campaign.cancel_preview(false)
	cockpit_view = false
	camera_yaw = 0.0
	camera_pitch = .24
	camera_position = cars[which].global_position + Vector3.BACK.rotated(Vector3.UP, cars[which].heading) * 5.2 + Vector3.UP * 2.6
	follow(1.0)


func leave(place: Vector3) -> void:
	var car := cars[active]
	active = -1
	game.player.global_position = place
	game.player.velocity = Vector3.UP * VehicleExit.LIFT
	game.player.collision_layer = collision_layer_on_foot
	game.player.collision_mask = collision_mask_on_foot
	game.player.reset_physics_interpolation()
	game.eye.position = Vector3.UP * 1.58
	game.eye.rotation = Vector3.ZERO
	game.yaw = car.heading
	game.pitch = -.10
	game.update_view()
	if is_in_bay(car):
		game.notify_angling("Parked in a marina bay.", 2.6)


func orbit(motion: Vector2) -> void:
	camera_yaw = wrapf(camera_yaw - motion.x * .0033, -PI, PI)
	if cockpit_view:
		camera_yaw = clampf(camera_yaw, -1.65, 1.65)
		camera_pitch = clampf(camera_pitch + motion.y * .0033, -.43, .76)
	else:
		camera_pitch = clampf(camera_pitch + motion.y * .0033, .03, .86)


func cycle_camera() -> void:
	cockpit_view = not cockpit_view
	camera_yaw = 0.0
	camera_pitch = .22 if cockpit_view else .24
	if not cockpit_view:
		var car := cars[active]
		camera_position = car.global_position + Vector3.BACK.rotated(Vector3.UP, car.heading) * 5.2 + Vector3.UP * 2.6


func follow(delta: float) -> void:
	var car := cars[active]
	var eye: Camera3D = game.eye
	var walking_body: CharacterBody3D = game.player
	walking_body.global_position = car.global_position
	game.yaw = car.heading
	if cockpit_view:
		var model := car.model
		eye.global_transform = model.global_transform * Transform3D(
			Basis(Vector3.UP, camera_yaw) * Basis(Vector3.RIGHT, -camera_pitch), model.interior.driver_eye)
		return
	var look_at: Vector3 = car.global_position + Vector3.UP * .96 - Vector3.BACK.rotated(Vector3.UP, car.heading) * .72
	var aim := Basis(Vector3.UP, car.heading + camera_yaw) * Basis(Vector3.RIGHT, -camera_pitch)
	var target := look_at + aim.z * (5.9 + minf(1.0, absf(car.speed) * .048)) + Vector3.UP * .52
	camera_position = camera_position.lerp(target, 1.0 - exp(-delta * 10.0))
	var ray := PhysicsRayQueryParameters3D.create(look_at, camera_position, 1, [car.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(ray)
	eye.global_position = hit.position + (look_at - camera_position).normalized() * .20 if not hit.is_empty() else camera_position
	eye.look_at(look_at)


func is_in_bay(car: RoadCar) -> bool:
	var car_at := (car.global_position - LOT).rotated(Vector3.UP, -LOT_ANGLE)
	var stall := roundi(car_at.x / BAY_WIDTH)
	return stall >= 0 and stall < BAY_COUNT and absf(car_at.z) < .58 		and absf(car_at.x - stall * BAY_WIDTH) < .48 and absf(sin(car.heading - LOT_ANGLE)) < .18


func step(delta: float, throttle: float, steering: float, brake: bool, has_input: bool) -> void:
	var input := Vector4.ZERO
	if active >= 0:
		input = Vector4(throttle, steering, float(brake), 1) if has_input else Vector4(0, 0, 1, 1)
	send_in -= delta
	var send := send_in <= 0.0
	if send:
		send_in = .05
	if crew.is_guest():
		if active >= 0 and send and crew.mode == "guest":
			drive_order.rpc_id(1, active, Vector3(input.x, input.y, input.z))
		interpolate_cars(delta)
	else:
		for i in cars.size():
			var driver := drivers[i]
			var command := Vector4.ZERO
			if driver != 0:
				if driver == crew.my_id():
					command = input
				else:
					var remote: Vector4 = remote_input.get(driver, Vector4.ZERO)
					command = remote if remote.w >= Time.get_ticks_msec() else Vector4(0, 0, 1, 1)
			if driver != 0 or absf(cars[i].speed) > .005 or not is_zero_approx(cars[i].steer) or cars[i].engine.playing or cars[i].braking:
				cars[i].drive(delta, command.x, command.y, command.z > .5, driver != 0)
			elif cars[i].model.running_lights[0].visible != cars[i].lamps_on:
				cars[i].present(delta, false, 0)
		if send and crew.on_server() and crew.people.size() > 1:
			var state: Array = []
			for car in cars:
				state.append([car.global_transform, car.heading, car.speed, car.steer, car.spinning, car.braking, car.lamps_on])
			car_poses.rpc(state)
	for index in cars.size():
		var car := cars[index]
		car.model.show_driver(drivers[index], index == active and cockpit_view)
	if active >= 0:
		follow(delta)
	else:
		find_focus()


func hide_drivers() -> void:
	for peer: int in crew.avatars:
		crew.avatars[peer].visible = not drivers.has(peer)


func broadcast_seats() -> void:
	if crew.on_server() and crew.people.size() > 1:
		share_seats.rpc(drivers)


func crew_changed() -> void:
	if crew.on_server():
		var connected := PackedInt32Array()
		for peer: int in crew.people:
			connected.append(peer)
			if peer != 1 and not known_peers.has(peer):
				share_seats.rpc_id(peer, drivers)
		known_peers = connected
	elif not crew.is_guest():
		known_peers.clear()
		remote_input.clear()
		snapshot.clear()
		if active >= 0:
			var place: Vector3 = game.player.global_position
			if place.distance_squared_to(cars[active].global_position) < 1.0:
				place = find_exit(active)
			leave(place if place.is_finite() else bay(BAY_COUNT * BAY_WIDTH, -2) + Vector3.UP)
		drivers.fill(0)


func driver_left(peer: int) -> void:
	var which := drivers.find(peer)
	if which >= 0:
		drivers[which] = 0
		remote_input.erase(peer)
		broadcast_seats()


@rpc("any_peer", "call_remote", "reliable")
func seat_order(which: int, action: String) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if not crew.on_server() or not crew.people.has(peer) or which < 0 or which >= cars.size():
		return
	match action:
		"enter":
			var person: Dictionary = crew.last_pose(peer)
			if not person.is_empty() and not person.onboard and cars[which].global_position.distance_squared_to(person.at) < 22.0:
				assign_driver(peer, which)
		"exit":
			release_driver(peer, which)
		"lights":
			if drivers[which] == peer:
				cars[which].lamps_on = not cars[which].lamps_on


@rpc("any_peer", "call_remote", "unreliable_ordered", 2)
func drive_order(which: int, command: Vector3) -> void:
	var peer := multiplayer.get_remote_sender_id()
	if crew.on_server() and which >= 0 and which < cars.size() and drivers[which] == peer and command.is_finite():
		var limited := command.clamp(Vector3(-1, -1, 0), Vector3.ONE)
		remote_input[peer] = Vector4(limited.x, limited.y, limited.z, Time.get_ticks_msec() + 350)


@rpc("authority", "call_remote", "reliable")
func share_seats(seats: PackedInt32Array) -> void:
	if not crew.is_guest() or seats.size() != cars.size():
		return
	drivers = seats
	var which := drivers.find(crew.my_id())
	if which >= 0 and active < 0:
		enter(which)


@rpc("authority", "call_remote", "reliable")
func exit_at(place: Vector3) -> void:
	if active >= 0 and place.is_finite():
		leave(place)


@rpc("authority", "call_remote", "reliable")
func exit_blocked() -> void:
	game.notify_angling("Pull away from the obstacle to step out.", 2.3)


@rpc("authority", "call_remote", "unreliable_ordered", 1)
func car_poses(state: Array) -> void:
	if crew.is_guest() and state.size() == cars.size():
		snapshot = state


func interpolate_cars(delta: float) -> void:
	for i in snapshot.size():
		var car := cars[i]
		var sample: Array = snapshot[i]
		var target: Transform3D = sample[0]
		var blend := 1.0 - exp(-delta * 20.0)
		if car.global_position.distance_squared_to(target.origin) > 81.0:
			blend = 1.0
		car.global_transform = car.global_transform.interpolate_with(target, blend)
		car.heading = lerp_angle(car.heading, sample[1], blend)
		car.speed = sample[2]
		car.steer = lerpf(car.steer, sample[3], blend)
		car.spinning = lerp_angle(car.spinning, sample[4], blend)
		car.braking = sample[5]
		car.lamps_on = sample[6]
		car.present(delta, drivers[i] != 0, smoothstep(1.0, 13.0, absf(car.speed)))
