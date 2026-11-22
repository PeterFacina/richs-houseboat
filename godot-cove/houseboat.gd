extends AnimatableBody3D

const SceneKit = preload("res://scenery.gd")
const Swell = preload("res://swell.gd")
const Outboard = preload("res://outboard.gd")
const Panorama = preload("res://houseboat_panorama.gd")
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
var top_speed := 5.2
var water_check: Callable
var hull_name := "LANTERN"
var river_engine := false
var motor: Outboard
var water_flow: Callable
var wave_sampler: Callable
var wave_pose := Vector3.ZERO
var helm_wheel: Node3D
var skiff := false
var foil := false
var foil_lift := 0.0
var throttle_cap := 1.0
var modern_design := false
var classic_exterior: Node3D
var panorama_exterior: Node3D


func _ready() -> void:
	name = "Houseboat"
	sync_to_physics = false
	geometry()
	if river_engine:
		motor = Outboard.new()
		motor.position = Vector3(0, .30, 2.11) if skiff else Vector3(0, .55, 6.72)
		if skiff:
			motor.electric = true
			motor.scale = Vector3.ONE * .60
		add_child(motor)
	sail(0.0, 0.0, false, 0.0)


func helm_anchor() -> Vector3:
	return Vector3(0, .39, .67) if skiff else HELM


func board_anchor() -> Vector3:
	return Vector3(.16, .45, -.91) if skiff else Vector3(0, .93, -2.28)


func supports_deck(world: Vector3) -> bool:
	var local := to_local(world)
	if skiff:
		return absf(local.x) < 1.03 and local.z > -2.28 and local.z < 2.05 and local.y > .19 and local.y < 2.26
	return absf(local.x) < 1.52 and local.z > -3.65 and local.z < 6.6 and local.y > .25 and local.y < 2.9


func sail(delta: float, clock: float, driving: bool, rudder: float) -> void:
	if river_engine:
		motor.run(delta, throttle * throttle_cap, rudder, departed, speed)
		if helm_wheel != null:
			helm_wheel.rotation.z = -motor.steering * 2.40
		sail_river(delta, clock)
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


func sail_river(delta: float, clock: float) -> void:
	var wanted := signf(throttle) * top_speed * pow(absf(throttle * throttle_cap), .77)
	if throttle < 0.0:
		wanted *= .72
	speed = lerpf(speed, wanted, 1.0 - exp(-delta * (.66 if motor.gear != 0 else 1.43)))
	var steer_force := minf(1.0, absf(speed) * .19 + motor.thrust * .48)
	var reverse := -1.0 if (speed < -.18 or (absf(speed) <= .18 and throttle < 0.0)) else 1.0
	heading = wrapf(heading - motor.steering * steer_force * (.94 if skiff else .67) * delta * reverse, -PI, PI)
	var fore := Vector3(-sin(heading), 0, -cos(heading))
	var right := fore.cross(Vector3.UP)
	var length := .65 if skiff else 1.0
	var beam := .68 if skiff else 1.0
	if departed:
		var current: Vector3 = water_flow.call(center, clock)
		var next := center + (fore * speed + current * .78) * delta
		if in_channel(next) and in_channel(next + fore * 3.35 * length) and in_channel(next - fore * (3.61 if skiff else 6.65) * length) \
				and in_channel(next + right * 1.39 * beam) and in_channel(next - right * 1.39 * beam):
			center = next
		else:
			speed *= .53
	var port := sample(center - right * 1.21 * beam, clock)
	var starboard := sample(center + right * 1.21 * beam, clock)
	var bow := sample(center + fore * 2.78 * length, clock)
	var stern := sample(center - fore * (2.61 if skiff else 5.35) * length, clock)
	foil_lift = lerpf(foil_lift, smoothstep(4.8, 9.6, speed) if foil else 0.0, 1.0 - exp(-delta * 1.8))
	var ride := Vector3((port + starboard + bow + stern) * .25,
		clampf(atan2(bow - stern, 5.39 if skiff else 8.13), -.093, .093) + smoothstep(1.05, top_speed, absf(speed)) * .027,
		clampf(atan2(starboard - port, 2.42) + motor.steering * steer_force * .054, -.145, .145))
	wave_pose = wave_pose.lerp(ride, 1.0 - exp(-delta * 6.7))
	var wave_scale := lerpf(1.0, .22, foil_lift)
	transform = Transform3D(Basis.from_euler(Vector3(wave_pose.y * wave_scale, heading, wave_pose.z * wave_scale)),
		center + Vector3.UP * (wave_pose.x * wave_scale + foil_lift * .51))


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
	if skiff or modern_design == enabled:
		return
	if panorama_exterior == null:
		panorama_exterior = Node3D.new()
		panorama_exterior.name = "PanoramaExterior"
		add_child(panorama_exterior)
		Panorama.build(panorama_exterior, hull_name, finish(Color("#b8a280"), .82, true),
			finish(Color("#8c8b7f"), .82, true))
	modern_design = enabled
	classic_exterior.visible = not enabled
	panorama_exterior.visible = enabled


func geometry() -> void:
	if skiff:
		skiff_geometry()
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
	var sign := Label3D.new()
	sign.text = hull_name
	sign.font_size = 40
	sign.pixel_size = 0.0037
	sign.position = Vector3(-1.444, 0.54, 0.39)
	sign.rotation.y = -PI / 2.0
	sign.modulate = Color("#eeddb1")
	classic_exterior.add_child(sign)
	# The old ladder across the aft bulkhead is removed for the new doorway.


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
	var wheel := TorusMesh.new()
	wheel.inner_radius = .132
	wheel.outer_radius = .169
	helm_wheel = SceneKit.mesh_at(self, wheel, Vector3(0, 1.08, -.31), grips)
	helm_wheel.rotation.x = 1.23
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
