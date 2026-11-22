extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Fish = preload("res://river_fish.gd")
const Species = preload("res://fish_species.gd")

var body: Node3D
var head: Node3D
var rod: Node3D
var rod_guides: Array[Node3D] = []
var arms: Array[MeshInstance3D] = []
var legs: Array[MeshInstance3D] = []
var palms: Array[MeshInstance3D] = []
var boots: Array[MeshInstance3D] = []
var label: Label3D
var joint_positions: Array[Vector3] = [Vector3.ZERO, Vector3.ZERO]
var stride := 0.0
var walking := 0.0
var stride_axis := Vector3.FORWARD
var action_phase := 0.0
var last_stage := -1
var pointing := 0.0
var bend := 0.0
var relative := Vector3.ZERO
var turn := 0.0
var riding := false
var established := false
var fish: Fish
var float_model: Node3D
var line: MeshInstance3D
var line_mesh: ImmediateMesh
var line_material: StandardMaterial3D
var line_position := Vector3.ZERO
var no_line := true
var tool_grip := Transform3D.IDENTITY


func setup(display_name: String, color_index: int) -> void:
	var canvas := Kit.paint(Color("#425250"), .94)
	var seam := Kit.paint(Color("#303c3a"), .86)
	var jacket := Kit.paint([Color("#b3683e"), Color("#91834d"), Color("#517f83"), Color("#a0564f")][color_index % 4], .83)
	var edge := Kit.paint(Color("#d1c19a"), .71)
	var brass := Kit.paint(Color("#a98b52"), .41, .35)
	var denim := Kit.paint(Color("#394346"), .92)
	var boot_paint := Kit.paint(Color("#262c28"), .78)
	var glove := Kit.paint(Color("#333b34"), .93)
	var skin := Kit.paint([Color("#c39777"), Color("#986d53"), Color("#bc8768")][color_index % 3], .86)
	var cap := Kit.paint(Color("#52635c"), .88)
	body = Node3D.new()
	add_child(body)
	body.position.y = .88
	Tools.shell(body, Vector3(0, .008, .026), Vector3(.33, .30, .225), denim)
	Tools.shell(body, Vector3(0, .264, .046), Vector3(.44, .568, .279), canvas)
	for side in [-1.0, 1.0]:
		var chest := Tools.shell(body, Vector3(side * .099, .303, -.083), Vector3(.207, .456, .135), jacket)
		chest.rotation.z = side * .12
		Kit.box_at(body, Vector3(side * .107, .39, -.151), Vector3(.107, .032, .014), edge)
		Kit.box_at(body, Vector3(side * .110, .236, -.150), Vector3(.120, .082, .027), jacket)
		Kit.box_at(body, Vector3(side * .104, .267, -.168), Vector3(.124, .020, .011), seam)
		Kit.box_at(body, Vector3(side * .102, .33, .185), Vector3(.061, .043, .024), edge)
	Kit.box_at(body, Vector3(0, .299, -.153), Vector3(.022, .310, .030), seam)
	Kit.box_at(body, Vector3(0, .197, -.169), Vector3(.067, .045, .021), brass)
	Tools.shell(body, Vector3(0, .511, .041), Vector3(.248, .158, .207), canvas)
	Tools.tube(body, Vector3(0, .491, 0), Vector3(0, .683, -.009), .079, .076, skin)
	head = Node3D.new()
	body.add_child(head)
	head.position = Vector3(0, .664, -.008)
	Tools.shell(head, Vector3(0, .073, -.002), Vector3(.208, .273, .221), skin)
	Tools.shell(head, Vector3(0, .037, -.053), Vector3(.178, .158, .167), skin)
	Tools.shell(head, Vector3(0, .060, -.113), Vector3(.041, .064, .063), skin)
	for side in [-1.0, 1.0]:
		Tools.shell(head, Vector3(side * .110, .066, -.005), Vector3(.043, .069, .039), skin)
		Tools.shell(head, Vector3(side * .045, .085, -.101), Vector3(.031, .015, .012), boot_paint)
	Tools.shell(head, Vector3(0, .159, .010), Vector3(.229, .136, .249), cap)
	var brim := Tools.shell(head, Vector3(0, .128, -.123), Vector3(.192, .029, .227), cap)
	brim.rotation.x = .14
	Kit.box_at(head, Vector3(0, .164, -.105), Vector3(.056, .033, .01), edge)
	for side in [-1.0, 1.0]:
		arms.append(limb(.069, .096, canvas))
		arms.append(limb(.069, .050, canvas))
		palms.append(Tools.shell(self, Vector3.ZERO, Vector3(.078, .066, .112), glove))
		legs.append(limb(.106, .087, denim))
		legs.append(limb(.085, .061, denim))
		boots.append(Tools.shell(self, Vector3.ZERO, Vector3(.136, .131, .236), boot_paint))
	rod = Node3D.new()
	add_child(rod)
	var cork := Kit.paint(Color("#ac8861"), .88)
	var blank := Kit.paint(Color("#394647"), .44, .32)
	Tools.tube(rod, Vector3(0, 0, .152), Vector3(0, 0, -.226), .026, .017, cork)
	Tools.shell(rod, Vector3(0, -.078, -.041), Vector3(.103, .132, .127), blank)
	for section in 7:
		var joint := Node3D.new()
		var parent: Node3D = rod if rod_guides.is_empty() else rod_guides.back()
		parent.add_child(joint)
		joint.position.z = -.227 if rod_guides.is_empty() else -.212
		var radius := lerpf(.013, .003, section / 6.0)
		Tools.tube(joint, Vector3.ZERO, Vector3.FORWARD * .214, radius, radius * .83, blank)
		rod_guides.append(joint)
	rod.hide()
	label = Label3D.new()
	label.text = display_name
	label.position.y = 1.93
	label.modulate = Color("#edf0e2")
	label.pixel_size = .0045
	label.font_size = 31
	label.outline_size = 5
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(label)
	float_model = Node3D.new()
	add_child(float_model)
	float_model.top_level = true
	Tools.shell(float_model, Vector3.ZERO, Vector3(.081, .093, .081), Kit.paint(Color("#b44c34"), .32))
	Tools.shell(float_model, Vector3(0, -.036, 0), Vector3(.072, .046, .072), Kit.paint(Color("#eee3c6"), .40))
	float_model.hide()
	line_mesh = ImmediateMesh.new()
	line_material = Kit.paint(Color("#cdcbb8"))
	line_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	line_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	line = Kit.mesh_at(self, line_mesh, Vector3.ZERO, line_material)
	line.top_level = true
	line.global_transform = Transform3D.IDENTITY
	line.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	line.hide()


func limb(top: float, bottom: float, paint: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = 1.0
	mesh.radial_segments = 12
	mesh.bottom_radius = top
	mesh.top_radius = bottom
	return Kit.mesh_at(self, mesh, Vector3.ZERO, paint)


func bind_segment(mesh: Node3D, from: Vector3, to: Vector3) -> void:
	var span := to - from
	mesh.position = from.lerp(to, .5)
	mesh.quaternion = Quaternion(Vector3.UP, span.normalized())
	mesh.scale.y = span.length() + .039


func elbow(start: Vector3, requested: Vector3, plane: Vector3, first: float, second: float) -> Vector3:
	var direction := requested - start
	var reach := clampf(direction.length(), .035, first + second - .004)
	direction = direction.normalized()
	var along := (first * first - second * second + reach * reach) / (2.0 * reach)
	var height := sqrt(maxf(.0, first * first - along * along))
	return start + direction * along + plane.slide(direction).normalized() * height


func apply_sample(sample: Dictionary, vessel: Node3D, delta: float, clock: float, camera: Vector3) -> void:
	var next: Vector3 = sample.at
	var new_frame := not established or riding != bool(sample.onboard) or relative.distance_squared_to(next) > 12.0
	var amount := 1.0 if new_frame else 1.0 - exp(-delta * 22.0)
	relative = relative.lerp(next, amount)
	turn = lerp_angle(turn, float(sample.yaw), amount)
	riding = sample.onboard
	established = true
	global_position = vessel.to_global(relative) if riding else relative
	var base := Basis(Vector3.UP, turn)
	global_basis = vessel.global_basis * base if riding else base
	var animation: Dictionary = sample.get("animation", {})
	var movement: Vector3 = animation.get("move", Vector3.ZERO)
	var pace := clampf(Vector2(movement.x, movement.z).length(), 0.0, 4.7)
	walking = lerpf(walking, smoothstep(.1, 2.7, pace), 1.0 - exp(-delta * 13.0))
	if pace > .15:
		var local_move := (global_basis.inverse() * movement).slide(Vector3.UP).normalized()
		stride_axis = stride_axis.lerp(local_move, amount)
	stride += delta * (3.8 + pace * 2.15) * walking
	pointing = lerpf(pointing, float(animation.get("pitch", 0.0)), amount)
	bend = lerpf(bend, float(animation.get("tension", 0.0)), amount)
	var stage := int(animation.get("stage", 0))
	var phase := float(animation.get("age", 0))
	if stage != last_stage or absf(action_phase - phase) > .25:
		action_phase = phase
	else:
		action_phase = lerpf(action_phase + delta, phase, delta * 3.2)
	last_stage = stage
	body.position.y = .88 + absf(sin(stride)) * walking * .029 - bend * .029
	var dip: float = animation.get("scoop", .0)
	body.rotation = Vector3(.06 * walking - .065 * bend - .18 * dip, sin(stride) * walking * .062, .032 * sin(stride) * walking)
	head.rotation.x = pointing * .54
	update_limbs(animation, vessel, stage, clock)
	update_angling(animation, delta, clock, camera)


func update_limbs(animation: Dictionary, vessel: Node3D, stage: int, clock: float) -> void:
	var action := String(animation.get("tool", ""))
	var cast := .0
	if stage == 1:
		cast = .66 * smoothstep(0.0, .105, action_phase) - 1.17 * smoothstep(.105, .215, action_phase) \
			+ .51 * smoothstep(.215, .55, action_phase)
	var show_rod: bool = bool(animation.get("rod", false)) and action.is_empty() and stage < 7
	var cranking: float = animation.get("reel", 0.0)
	var grab: float = animation.get("reach", 0.0)
	var lift: float = animation.get("scoop", 0.0)
	var hold := Basis.from_euler(Vector3(.30 + pointing * .42 + cast + bend * .62, -.08, -.11))
	rod.transform = Transform3D(hold, Vector3(.164, 1.094, -.35) + Vector3(0, bend * .084, 0))
	rod.visible = show_rod
	for index in rod_guides.size():
		rod_guides[index].rotation.x = -bend * (.036 + .028 * index) - absf(cast) * .021
	for index in 2:
		var side := float(index * 2 - 1)
		var cycle := stride + PI * index
		var boot := Vector3(side * .104, .067 + maxf(0.0, sin(cycle)) * walking * .115, 0)
		boot += stride_axis * (cos(cycle) * walking * .219)
		var hip := body.position + Vector3(side * .088, -.006, .024)
		var knee := elbow(hip, boot + Vector3.UP * .025, Vector3.FORWARD, .414, .388)
		bind_segment(legs[index * 2], hip, knee)
		bind_segment(legs[index * 2 + 1], knee, boot + Vector3.UP * .026)
		boots[index].position = boot + Vector3.FORWARD * .061
		boots[index].rotation.x = -sin(cycle) * walking * .16
		var shoulder := body.transform * Vector3(side * .222, .449, .025)
		var hand := Vector3(side * .263, .889 + cos(clock * 1.5 + side) * .012, -.057 - cos(cycle) * walking * .154)
		if show_rod:
			var anchor := Vector3(0, 0, .020) if side > 0 else Vector3(-.069, -.067, -.032)
			if side < 0.0:
				anchor += Vector3(0, cos(clock * 13) * .039, sin(clock * 13) * .039) * cranking
			hand = rod.transform * anchor
		elif action == "helm" and is_instance_valid(vessel.helm_wheel):
			hand = to_local(vessel.helm_wheel.to_global(Vector3(side * .161, .052, .014)))
		elif action == "net":
			hand = Vector3(side * (.18 if side > 0.0 else .02), 1.03 - .47 * lift, -.39 - lift * .23)
		elif action == "cooler":
			hand = Vector3(side * .328, .962, -.402)
		elif action == "fish":
			hand = Vector3(side * .17, 1.02, -.42)
		elif action == "lamp":
			hand = Vector3(side * .14, 1.14, -.40)
		hand += Vector3(.04 * side, .065, -.13) * grab
		var upper := elbow(shoulder, hand, Vector3(side * .76, -.68, .19), .292, .274)
		bind_segment(arms[index * 2], shoulder, upper)
		bind_segment(arms[index * 2 + 1], upper, hand)
		palms[index].position = hand
		palms[index].rotation.x = -.24 + lift * .43
		joint_positions[index] = hand
	var root := joint_positions[1] if action == "net" else joint_positions[0].lerp(joint_positions[1], .5) + Vector3.DOWN * .21
	var orientation := Basis(Vector3.RIGHT, .12 + pointing * .31 - lift * 1.21) if action == "net" else Basis.IDENTITY
	tool_grip = global_transform * Transform3D(orientation, root)


func update_angling(animation: Dictionary, delta: float, clock: float, camera: Vector3) -> void:
	var target: Vector3 = animation.get("end", Vector3.INF)
	var line_active := target.is_finite() and bool(animation.get("line", false))
	if target.is_finite():
		line_position = target if no_line or line_position.distance_squared_to(target) > 63.0 else \
			line_position.lerp(target, 1.0 - exp(-delta * 17.0))
	no_line = not target.is_finite()
	float_model.visible = line_active and bool(animation.get("float", false))
	if float_model.visible:
		float_model.global_position = line_position
		float_model.rotation.x = sin(clock * 2.4) * .15
	line.visible = line_active and rod.visible
	line_mesh.clear_surfaces()
	if line.visible:
		var tip: Vector3 = rod_guides.back().to_global(Vector3.FORWARD * .212)
		var side := (line_position - tip).cross(camera - tip).normalized() * .0019
		line_mesh.surface_begin(Mesh.PRIMITIVE_TRIANGLE_STRIP, line_material)
		for step in 9:
			var t := step / 8.0
			var point := tip.lerp(line_position, t) - Vector3.UP * sin(t * PI) * (.054 + (1.0 - bend) * .13)
			line_mesh.surface_add_vertex(point - side)
			line_mesh.surface_add_vertex(point + side)
		line_mesh.surface_end()
	var kind: int = animation.get("species", -1)
	var at: Vector3 = animation.get("fish", Vector3.INF)
	if kind < 0 or kind >= Species.all().size() or not at.is_finite():
		if is_instance_valid(fish):
			fish.hide()
		return
	if not is_instance_valid(fish):
		fish = Fish.new()
		add_child(fish)
		fish.top_level = true
	var length: int = animation.get("length", 0)
	if fish.current != kind or absf(fish.metres * 100.0 - length) > .4:
		fish.select_species(kind, length)
	var nose := at if not fish.visible or fish.global_position.distance_squared_to(at) > 25.0 else \
		fish.global_position.lerp(at, 1.0 - exp(-delta * 17.0))
	var direction: Vector3 = animation.get("direction", Vector3.FORWARD)
	fish.pose(nose, direction if direction.length_squared() > .1 else Vector3.FORWARD, .15 * sin(clock * 8.6), .115, clock * 11.0)
	fish.show()
