extends AnimatableBody3D

signal grass_trimmed(index: int)

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const VehicleExit = preload("res://vehicle_exit.gd")
const Driver = preload("res://vehicle_driver.gd")
const TRACK := .51
const HALF_WHEELBASE := .69
const WHEEL_POINTS := [
	Vector3(-TRACK, 0, -HALF_WHEELBASE), Vector3(TRACK, 0, -HALF_WHEELBASE),
	Vector3(-TRACK, 0, HALF_WHEELBASE), Vector3(TRACK, 0, HALF_WHEELBASE),
]
const WHEEL_RADII := [.153, .153, .29, .29]
const SEATED_FEET := Vector3(0, .11, .25)
const BODY_CENTER := Vector3(0, .69, .06)
const BODY_SIZE := Vector3(1.47, .88, 1.96)
const CUT_DECK := Vector3(0, .22, -.21)
const CUT_HEIGHT := .22
const DRIVE_SPEEDS := [2.4, 4.35, 5.8, 7.2]
const THROTTLE_NAMES := ["Low", "Normal", "High", "Transport"]
const LOWEST_UP := .68
const REVERSE_SPEED := 2.05
const TURN_SPEED := 2.35

var river: Node3D
var cut_width := .71
var rider: CharacterBody3D
var body_shape: Shape3D
var motor: AudioStreamPlayer3D
var wheels: Array[Node3D] = []
var casters: Array[Node3D] = []
var levers: Array[Node3D] = []
var hands: Array[Node3D] = []
var arms: Array[MeshInstance3D] = []
var rider_visual := Node3D.new()
var seated := Driver.new()
var chase_view := false
var rider_camera: Camera3D
var throttle_lever := Node3D.new()
var throttle_index := 1
var speed := 0.0
var yaw := 0.0
var blades := false
var grass: MultiMeshInstance3D
var grass_cells: Dictionary = {}
var grass_cut := PackedByteArray()
var grass_transforms: Array[Transform3D]
var last_cut := Vector3.INF
var last_cut_yaw := 0.0
var blade_load := 0.0
var shared_grass: AnimatableBody3D


func setup(map: Node3D, parking: Vector3, heading: float, grass_owner: AnimatableBody3D = null) -> void:
	river = map
	shared_grass = grass_owner
	yaw = heading
	name = "ZeroTurnMower" if shared_grass == null else "SpareMower"
	sync_to_physics = false
	build_model()
	Kit.collider(self, BODY_CENTER, BODY_SIZE)
	var collider := get_child(get_child_count() - 1) as CollisionShape3D
	body_shape = collider.shape
	var pose := ground_pose(parking, yaw)
	global_transform = pose if pose.origin.is_finite() else Transform3D(Basis(Vector3.UP, yaw), parking)
	update_wheels(0.0, 0.0, 0.0)
	motor = AudioStreamPlayer3D.new()
	motor.stream = engine_loop()
	motor.position = Vector3(0, .57, .79)
	motor.unit_size = 2.2
	motor.max_distance = 35.0
	motor.volume_db = -20.0
	add_child(motor)
	if shared_grass == null:
		grass = river.waterfront.park_grass
		grass_transforms = river.waterfront.grass_transforms
		index_grass()


func build_model() -> void:
	var orange := Kit.paint(Color("#b95324"), .58, .19)
	var dark := Kit.paint(Color("#292d2c"), .76)
	var steel := Kit.paint(Color("#91958a"), .45, .5)
	var rubber := Kit.paint(Color("#242321"), .96)
	var tread := Kit.paint(Color("#363430"), .91)
	Kit.box_at(self, Vector3(0, .43, .16), Vector3(.86, .22, 1.60), dark)
	Kit.box_at(self, Vector3(0, .36, -.61), Vector3(.91, .11, .49), steel)
	Kit.box_at(self, CUT_DECK, Vector3(1.39, .17, .71), orange)
	Kit.box_at(self, CUT_DECK + Vector3(.69, -.032, .08), Vector3(.25, .095, .33), dark)
	Kit.box_at(self, Vector3(0, .62, .78), Vector3(.80, .42, .47), orange)
	for vent in 5:
		Kit.box_at(self, Vector3((vent - 2) * .102, .74, 1.019), Vector3(.058, .085, .014), dark)
	Kit.box_at(self, Vector3(0, .75, .23), Vector3(.45, .14, .43), rubber)
	var backrest := Kit.box_at(self, Vector3(0, .96, .424), Vector3(.45, .38, .113), rubber)
	backrest.rotation.x = .14
	for side: float in [-1.0, 1.0]:
		Kit.box_at(self, Vector3(side * .53, .636, .58), Vector3(.30, .12, .48), orange)
		var lever := Node3D.new()
		add_child(lever)
		lever.position = Vector3(side * .39, .57, .06)
		Kit.beam(lever, Vector3.ZERO, Vector3(0, .47, -.10), .038, steel)
		Kit.beam(lever, Vector3(0, .47, -.10), Vector3(-side * .22, .47, -.10), .062, rubber)
		levers.append(lever)
	add_child(rider_visual)
	rider_visual.hide()
	build_rider()
	rider_visual.add_child(seated)
	seated.build(Vector3(0, 1.66, .29), Vector3(0, .82, .29))
	seated.pose(Vector3(-.30, 1.04, -.05), Vector3(.30, 1.04, -.05), 0, true, true)
	add_child(throttle_lever)
	throttle_lever.position = Vector3(.56, .71, .32)
	Kit.box_at(self, Vector3(.56, .707, .32), Vector3(.085, .045, .21), dark)
	Kit.beam(throttle_lever, Vector3.ZERO, Vector3(0, .13, 0), .027, steel)
	Kit.box_at(throttle_lever, Vector3(0, .13, 0), Vector3(.07, .044, .041), Kit.paint(Color("#e9c74e")))
	update_throttle_lever()
	for index in WHEEL_POINTS.size():
		var caster := Node3D.new()
		add_child(caster)
		caster.position = WHEEL_POINTS[index]
		casters.append(caster)
		if index < 2:
			Kit.box_at(caster, Vector3(0, .17, 0), Vector3(.24, .055, .10), steel)
			for side: float in [-1.0, 1.0]:
				Kit.box_at(caster, Vector3(side * .084, .085, 0), Vector3(.035, .17, .075), steel)
		var wheel := Node3D.new()
		caster.add_child(wheel)
		wheels.append(wheel)
		var radius: float = WHEEL_RADII[index]
		var width := .12 if index < 2 else .25
		add_wheel_mesh(wheel, radius, width, rubber)
		add_wheel_mesh(wheel, radius * .52, width + .018, steel)
		for lug in 14:
			var angle := lug * TAU / 14.0
			var block := Kit.box_at(wheel, Vector3(0, cos(angle), sin(angle)) * (radius - .004),
				Vector3(width * .88, .019, radius * .20), tread)
			block.rotation.x = angle


func build_rider() -> void:
	var skin := Kit.paint(Color("#bd896f"), .84)
	var sleeve := Kit.paint(Color("#354549"))
	for i in levers.size():
		var side := float(2 * i - 1)
		var glove := Node3D.new()
		rider_visual.add_child(glove)
		hands.append(glove)
		Tools.shell(glove, Vector3(0, .020, .019), Vector3(.089, .054, .098), skin)
		for finger in 4:
			var x := -.031 + finger * .019
			Tools.shell(glove, Vector3(x, .009, -.025), Vector3(.019, .055, .045), skin).rotation.x = -.45
			Tools.shell(glove, Vector3(x, -.017, -.013), Vector3(.019, .021, .043), skin)
		Tools.shell(glove, Vector3(-side * .038, .002, .017), Vector3(.028, .033, .067), skin).rotation.y = side * .38
		for item: Array in [[sleeve, .078], [skin, .058]]:
			var cylinder := CylinderMesh.new()
			cylinder.height = 1.0
			cylinder.top_radius = item[1] * .5
			cylinder.bottom_radius = item[1] * .72
			arms.append(Kit.mesh_at(rider_visual, cylinder, Vector3.ZERO, item[0]))
	pose_rider_arms()


func pose_rider_arms() -> void:
	for index in levers.size():
		var side := float(2 * index - 1)
		var grip := Vector3(-side * .128, .47, -.10)
		var lever := levers[index]
		var hand := hands[index]
		hand.transform = lever.transform * Transform3D(Basis.IDENTITY, grip)
		var shoulder := Vector3(side * .26, 1.38, .31)
		var elbow := Vector3(side * .32, 1.095, .37 + .25 * hand.position.z)
		pose_arm(arms[index * 2], shoulder, elbow)
		pose_arm(arms[index * 2 + 1], elbow, hand.position + Vector3(0, .013, .052))


func pose_arm(segment: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var span := b - a
	segment.position = (a + b) * .5
	segment.basis = Basis(Quaternion(Vector3.UP, span.normalized())).scaled_local(Vector3(1, span.length(), 1))


func shift_throttle(change: int) -> void:
	throttle_index = clampi(throttle_index + change, 0, DRIVE_SPEEDS.size() - 1)
	update_throttle_lever()


func update_throttle_lever() -> void:
	throttle_lever.rotation.x = lerpf(.49, -.54, float(throttle_index) / (DRIVE_SPEEDS.size() - 1))


func throttle_label() -> String:
	return THROTTLE_NAMES[throttle_index]


func add_wheel_mesh(parent: Node3D, radius: float, width: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = width
	mesh.radial_segments = 20
	Kit.mesh_at(parent, mesh, Vector3.ZERO, material).rotation.z = PI * .5


func ground_pose(at: Vector3, heading: float) -> Transform3D:
	var flat := Basis(Vector3.UP, heading)
	var contacts := PackedVector3Array()
	for wheel: Vector3 in WHEEL_POINTS:
		var point := at + flat * wheel
		point.y = river.ground_height(point.x, point.z)
		if point.y < .14 or (point.y < .55 and river.wet_clearance(point) > .26):
			return Transform3D(Basis.IDENTITY, Vector3.INF)
		contacts.append(point)
	var forward := (contacts[0] + contacts[1] - contacts[2] - contacts[3]) * .5
	var right := (contacts[1] + contacts[3] - contacts[0] - contacts[2]) * .5
	var up := right.cross(forward).normalized()
	if up.y < LOWEST_UP:
		return Transform3D(Basis.IDENTITY, Vector3.INF)
	var center := (contacts[0] + contacts[1] + contacts[2] + contacts[3]) * .25
	center.y = maxf(center.y, river.ground_height(at.x, at.z) - .11)
	return Transform3D(Basis.looking_at(forward, up), center)


func clear_at(shape: Shape3D, pose: Transform3D, ignored: Array[RID], check_ground := true) -> bool:
	var query := PhysicsShapeQueryParameters3D.new()
	query.shape = shape
	query.transform = pose
	query.collision_mask = 1
	query.exclude = ignored
	var hits := get_world_3d().direct_space_state.intersect_shape(query, 1 if check_ground else 16)
	for hit in hits:
		var obstacle: Node = hit.collider
		if check_ground or obstacle == null or not obstacle.is_in_group("ottawa_terrain"):
			return false
	return true


func near(player: CharacterBody3D, eye: Camera3D) -> bool:
	var target := to_global(Vector3(0, .92, .12))
	if player.global_position.distance_squared_to(target) > 2.45 * 2.45:
		return false
	var query := PhysicsRayQueryParameters3D.create(eye.global_position, target, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or hit.rid == get_rid()


func mount(player: CharacterBody3D) -> void:
	rider = player
	rider.add_collision_exception_with(self)
	rider_visual.show()
	position_rider()
	rider.reset_physics_interpolation()
	motor.play()


func dismount() -> bool:
	var clear := VehicleExit.find(self, rider, Vector2(.77, 1.07), yaw, true)
	if not clear.is_finite():
		return false
	rider.global_position = clear
	rider.velocity = Vector3.UP * VehicleExit.LIFT
	leave_seat()
	return true

func leave_for_flight() -> void:
	if dismount():
		return
	rider.global_position = to_global(Vector3(0, BODY_CENTER.y + BODY_SIZE.y * .5 + .08, 0))
	leave_seat()


func leave_seat() -> void:
	rider.reset_physics_interpolation()
	rider.remove_collision_exception_with(self)
	if is_instance_valid(rider_camera):
		rider_camera.position = Vector3.UP * 1.58
		rider_camera.rotation = Vector3.ZERO
	rider_camera = null
	chase_view = false
	rider = null
	rider_visual.hide()
	speed = 0.0
	blades = false
	last_cut = Vector3.INF
	motor.stop()
	for lever in levers:
		lever.rotation.x = 0.0


func update_rider_camera(camera: Camera3D) -> void:
	rider_camera = camera
	seated.head.visible = chase_view
	if not chase_view:
		camera.position = Vector3.UP * 1.58
		camera.rotation = Vector3(camera.rotation.x, 0, 0)
		return
	var target := to_global(Vector3(0, 1.26, -.09))
	var behind := to_global(Vector3(0, 2.69, 4.0))
	var ray := PhysicsRayQueryParameters3D.create(target, behind, 1, [get_rid(), rider.get_rid()])
	var blocked := get_world_3d().direct_space_state.intersect_ray(ray)
	camera.global_position = blocked.position + (target - behind).normalized() * .18 if not blocked.is_empty() else behind
	camera.look_at(target)


func position_rider() -> void:
	rider.global_position = to_global(SEATED_FEET)
	rider.velocity = Vector3.ZERO


func drive(delta: float, throttle: float, steering: float) -> float:
	var start_yaw := yaw
	var top_speed: float = DRIVE_SPEEDS[throttle_index]
	var grade := lerpf(.52, 1.0, smoothstep(LOWEST_UP, .96, global_basis.y.y))
	var desired := throttle * (top_speed if throttle >= 0.0 else REVERSE_SPEED) * grade
	var acceleration := 3.15 if absf(desired) > absf(speed) and desired * speed >= 0.0 else 6.8
	speed = move_toward(speed, desired, delta * acceleration)
	var turn := steering * TURN_SPEED * lerpf(1.0, .58, clampf(absf(speed) / top_speed, 0.0, 1.0)) * delta
	var next_yaw := wrapf(yaw + turn, -PI, PI)
	var forward := -Basis(Vector3.UP, yaw + turn * .5).z
	var start := global_position
	if (not is_zero_approx(speed) or not is_zero_approx(turn)) and not try_pose(start + forward * speed * delta, next_yaw):
		speed = 0.0
		if absf(turn) > .00001:
			try_pose(start, next_yaw)
	var turned := angle_difference(start_yaw, yaw)
	update_wheels(speed * delta, turned, steering)
	for index in levers.size():
		levers[index].rotation.x = -.27 * clampf(throttle + steering * (1.0 if index == 0 else -1.0), -1.0, 1.0)
	pose_rider_arms()
	var load := maxf(clampf(absf(speed) / top_speed, 0.0, 1.0), absf(steering) * .42)
	blade_load = move_toward(blade_load, 0.0, delta * 3.5)
	if blades and (last_cut.distance_squared_to(to_global(CUT_DECK)) > .15 * .15 \
			or absf(angle_difference(last_cut_yaw, yaw)) >= .12):
		blade_load = maxf(blade_load, clampf(cut_grass() / 7.0, 0.0, 1.0))
	var cutting_load := blade_load if blades else 0.0
	motor.pitch_scale = lerpf(motor.pitch_scale, .82 + .44 * load + (.19 if blades else 0.0) \
		- .10 * cutting_load, minf(1.0, delta * 5.0))
	motor.volume_db = -20.0 + 6.0 * load + (3.0 if blades else 0.0) + 2.0 * cutting_load
	position_rider()
	return turned


func try_pose(at: Vector3, heading: float) -> bool:
	var pose := ground_pose(at, heading)
	var run := Vector2(at.x - global_position.x, at.z - global_position.z).length()
	if not pose.origin.is_finite() or absf(pose.origin.y - global_position.y) > .16 + run * 1.12:
		return false
	if not clear_at(body_shape, pose.translated_local(BODY_CENTER), [get_rid(), rider.get_rid()], false):
		return false
	global_transform = pose
	yaw = heading
	return true


func update_wheels(distance: float, turned: float, steering: float) -> void:
	for index in wheels.size():
		var caster := casters[index]
		var wheel_at: Vector3 = WHEEL_POINTS[index]
		var point := to_global(wheel_at)
		if index < 2:
			caster.rotation.y = steering * (.83 if absf(speed) < .4 else .40)
		var ground: float = river.ground_height(point.x, point.z)
		caster.position.y = (ground - point.y + WHEEL_RADII[index]) / global_basis.y.y
		wheels[index].rotate_x(-(distance + turned * wheel_at.x) / WHEEL_RADII[index])


func index_grass() -> void:
	if not is_instance_valid(grass):
		return
	grass_cut.resize(grass_transforms.size())
	for index in grass_transforms.size():
		var at := grass_point(index)
		var cell := Vector2i(floori(at.x), floori(at.z))
		if not grass_cells.has(cell):
			grass_cells[cell] = []
		grass_cells[cell].append(index)


func grass_point(index: int) -> Vector3:
	return grass.to_global(grass_transforms[index].origin)


func cut_grass() -> int:
	last_cut = to_global(CUT_DECK)
	last_cut_yaw = yaw
	if shared_grass == null:
		return trim_at(global_transform, cut_width)
	return shared_grass.trim_at(global_transform, cut_width)


func trim_at(pose: Transform3D, width := .71) -> int:
	if not is_instance_valid(grass):
		return 0
	var deck := pose * CUT_DECK
	var center := Vector2i(floori(deck.x), floori(deck.z))
	var inverse := pose.affine_inverse()
	var instances := grass.multimesh
	var trimmed := 0
	for z in range(center.y - 1, center.y + 2):
		for x in range(center.x - 1, center.x + 2):
			for index: int in grass_cells.get(Vector2i(x, z), []):
				if grass_cut[index]:
					continue
				var tuft := grass_transforms[index]
				var local := inverse * grass.to_global(tuft.origin) - CUT_DECK
				if absf(local.x) <= width and absf(local.z) <= .39:
					tuft.basis.y *= CUT_HEIGHT
					instances.set_instance_transform(index, tuft)
					grass_cut[index] = 1
					trimmed += 1
					grass_trimmed.emit(index)
	return trimmed


func regrow_grass(indices: Array) -> void:
	for index: int in indices:
		if not grass_cut[index]:
			continue
		grass.multimesh.set_instance_transform(index, grass_transforms[index])
		grass_cut[index] = 0
	last_cut = Vector3.INF


func engine_loop() -> AudioStreamWAV:
	const RATE := 22050
	var pcm := PackedByteArray()
	pcm.resize(RATE * 2)
	for frame in RATE:
		var t := float(frame) / RATE
		var phase := TAU * 53.0 * t
		var firing := sin(phase + .19 * sin(phase * 2.0))
		var value := .44 * firing + .20 * sin(phase * 2.0) + .14 * pow(maxf(0, firing), 5.0)
		value += .062 * sin(phase * 6.0) + .043 * sin(TAU * 367.0 * t)
		pcm.encode_s16(frame * 2, roundi(value * 24500.0))
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = RATE
	stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	stream.loop_end = RATE
	stream.data = pcm
	return stream
