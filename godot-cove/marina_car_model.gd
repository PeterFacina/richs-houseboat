extends Node3D

const Driver = preload("res://vehicle_driver.gd")

const Kit = preload("res://scenery.gd")
const Interior = preload("res://marina_car_interior.gd")
const Badges = preload("res://marina_car_badges.gd")
const WindowGlass = preload("res://marina_car_glass.gdshader")
const CABIN_DETAIL_DISTANCE := 55.0
# Each section is [distance from center as a fraction of half-length, width fraction, hood/deck height].
const MODELS := [
	{"label": "Mazda5", "paint": "#a42b2d", "size": Vector3(1.75, 1.62, 4.59), "wheelbase": 2.75,
		"radius": .318, "style": "wagon", "pull": 3.65, "grip": 1.0, "limit": 24.0, "tone": 1.00,
		"body": [[-1.0, .77, .62], [-.91, .97, .72], [-.69, 1.0, .85], [-.38, .97, 1.0],
			[.58, .99, 1.0], [.89, 1.0, .94], [1.0, .84, .84]],
		"roof": [-.50, -.17, .60, .87], "belt": .94},
	{"label": "2013 Ford Escape", "paint": "#626847", "size": Vector3(1.84, 1.68, 4.52), "wheelbase": 2.69,
		"radius": .347, "style": "suv", "pull": 4.20, "grip": 1.09, "limit": 25.0, "tone": .90,
		"body": [[-1.0, .83, .71], [-.89, .98, .91], [-.62, 1.0, .99], [-.34, .97, 1.02],
			[.56, .99, 1.0], [.88, 1.0, .98], [1.0, .82, .86]],
		"roof": [-.48, -.14, .52, .88], "belt": 1.0},
	{"label": "2005 Toyota Corolla", "paint": "#46787a", "size": Vector3(1.70, 1.48, 4.53), "wheelbase": 2.60,
		"radius": .307, "style": "sedan", "pull": 3.35, "grip": 1.02, "limit": 22.0, "tone": 1.12,
		"body": [[-1.0, .78, .59], [-.91, .97, .71], [-.62, 1.0, .80], [-.37, .96, .88],
			[.55, 1.0, .89], [.86, .98, .89], [1.0, .80, .76]],
		"roof": [-.46, -.14, .29, .64], "belt": .86},
	{"label": "2002 Chrysler Sebring Limited", "paint": "#84a0b3", "size": Vector3(1.76, 1.40, 4.92),
		"wheelbase": 2.69, "radius": .322, "style": "convertible", "pull": 4.00, "grip": .94, "limit": 25.0, "tone": .83,
		"body": [[-1.0, .70, .59], [-.92, .96, .69], [-.65, 1.0, .74], [-.38, .97, .82],
			[.49, 1.0, .85], [.82, .98, .86], [1.0, .80, .72]],
		"roof": [-.46, -.16, .24, .61], "belt": .81},
	{"label": "2010 Kia Forte Koup", "paint": "#23242a", "size": Vector3(1.78, 1.40, 4.48), "wheelbase": 2.65,
		"radius": .317, "style": "coupe", "pull": 4.35, "grip": 1.14, "limit": 26.0, "tone": 1.07,
		"body": [[-1.0, .82, .57], [-.89, .99, .73], [-.65, 1.0, .81], [-.36, .97, .87],
			[.50, .99, .89], [.83, 1.0, .95], [1.0, .84, .77]],
		"roof": [-.48, -.12, .26, .73], "belt": .85},
]

const WORK_TRUCKS := [
	{"label": "Public Works white pickup", "paint": "#e1e4e1", "size": Vector3(2.04, 1.97, 5.64),
		"wheelbase": 3.57, "radius": .386, "style": "pickup", "pull": 3.75, "grip": .98, "limit": 23.0, "tone": .82,
		"body": [[-1.0, .91, 1.0], [-.94, .99, 1.13], [-.60, 1.0, 1.20], [-.40, .99, 1.24],
			[.25, .98, 1.20], [.36, 1.0, 1.04], [.89, .99, 1.03], [1.0, .95, 1.02]],
		"roof": [-.48, -.26, .22, .33], "belt": 1.23},
	{"label": "Public Works silver pickup", "paint": "#9fa8ad", "size": Vector3(2.06, 1.97, 5.78),
		"wheelbase": 3.61, "radius": .393, "style": "pickup", "pull": 3.94, "grip": .95, "limit": 24.0, "tone": .77,
		"body": [[-1.0, .89, 1.02], [-.94, .97, 1.15], [-.68, 1.0, 1.22], [-.41, .99, 1.25],
			[.30, .985, 1.22], [.37, 1.0, 1.05], [.91, .99, 1.04], [1.0, .94, 1.03]],
		"roof": [-.49, -.27, .24, .35], "belt": 1.24},
	{"label": "Public Works grey service truck", "paint": "#c2c8c9", "size": Vector3(2.09, 2.02, 5.88),
		"wheelbase": 3.65, "radius": .401, "style": "pickup", "pull": 3.68, "grip": .97, "limit": 22.0, "tone": .75,
		"body": [[-1.0, .91, 1.03], [-.92, .98, 1.16], [-.62, 1.0, 1.23], [-.40, .99, 1.26],
			[.27, .98, 1.22], [.36, 1.0, 1.05], [.92, .99, 1.04], [1.0, .95, 1.03]],
		"roof": [-.48, -.26, .22, .33], "belt": 1.26, "toolbox": true},
]

var driver: Driver
var body_size: Vector3
var radius: float
var wheelbase: float
var paint: StandardMaterial3D
var interior: Interior
var shell: Array[PackedVector3Array] = []
var dark := Kit.paint(Color("#202326"), .78)
var trim := Kit.paint(Color("#9ca7aa"), .37, .63)
var rubber := Kit.paint(Color("#26282a"), .93)
var mirror_glass := Kit.paint(Color("#78909c"), .25, .53)
var glass := ShaderMaterial.new()
var rear_glass := ShaderMaterial.new()
var distant_glass := Kit.paint(Color("#334750"), .32, .20)
var distant_windows := Node3D.new()
var lamp := Kit.paint(Color("#cad2cf"), .22, .42)
var amber := Kit.paint(Color("#e49a34"), .32, .21)
var reflector := Kit.paint(Color("#f0f1e9"), .31, .38)
var tail := Kit.paint(Color("#811d2b"), .34, .18)
var white := Kit.paint(Color("#dcdad0"), .61)
var running_lights: Array[SpotLight3D] = []
var pivots: Array[Node3D] = []
var hubs: Array[Node3D] = []


func build(model: Dictionary) -> void:
	body_size = model.size
	radius = model.radius
	wheelbase = model.wheelbase
	paint = Kit.paint(Color(model.paint), .36, .21)
	paint.clearcoat_enabled = true
	paint.clearcoat = .62
	paint.clearcoat_roughness = .29
	var style: String = model.style
	glass.shader = WindowGlass
	rear_glass.shader = WindowGlass
	rear_glass.set_shader_parameter("smoke", .06 if style in ["wagon", "suv", "coupe"] else .025)
	distant_glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	distant_windows.name = "DistantWindows"
	add_child(distant_windows)
	var cabin_start := float(model.roof[0]) * body_size.z * .5
	var cabin_end := float(model.roof[3]) * body_size.z * .5
	build_body(model.body, cabin_start, cabin_end)
	build_cabin(model.roof, model.belt, style)
	interior = Interior.new()
	add_child(interior)
	interior.build(model)
	combine_meshes(interior)
	combine_meshes(interior.steering_wheel)
	for mesh: MeshInstance3D in interior.find_children("*", "MeshInstance3D", true, false):
		mesh.visibility_range_end = CABIN_DETAIL_DISTANCE
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	combine_meshes(distant_windows)
	for mesh: MeshInstance3D in distant_windows.get_children():
		mesh.visibility_range_begin = CABIN_DETAIL_DISTANCE
		mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_door_details(style, model.belt, cabin_start, cabin_end)
	if style == "pickup":
		build_pickup_fittings(cabin_end, model.get("toolbox", false))
	else:
		build_fittings(style)
	build_wheels(style)
	combine_meshes(self)
	driver = Driver.new()
	driver.name = "SeatedDriver"
	add_child(driver)
	var eye := interior.driver_eye
	driver.build(eye, Vector3(eye.x, float(model.belt) - .19, eye.z + .045))
	for instance: Node in find_children("*", "MeshInstance3D", true, false):
		if is_zero_approx(instance.visibility_range_end):
			instance.visibility_range_end = 255.0
			instance.visibility_range_end_margin = 18.0


func show_driver(peer: int, cockpit: bool) -> void:
	if peer == 0:
		driver.hide()
		return
	var wheel := interior.steering_wheel
	driver.pose(to_local(wheel.to_global(Vector3(-.154, .049, .026))),
		to_local(wheel.to_global(Vector3(.154, .049, .026))), wheel.rotation.z, cockpit)


func build_body(profile: Array, cabin_start: float, cabin_end: float) -> void:
	var stations := PackedFloat32Array([cabin_start, cabin_end])
	for row: Array in profile:
		stations.append(float(row[0]) * body_size.z * .5)
	for axle in [-wheelbase * .5, wheelbase * .5]:
		for fraction in [-1.06, -.93, -.75, -.52, -.27, 0.0, .27, .52, .75, .93, 1.06]:
			stations.append(float(axle) + radius * float(fraction))
	stations.sort()
	var section := 0
	for z: float in stations:
		while section < profile.size() - 2 and z > float(profile[section + 1][0]) * body_size.z * .5:
			section += 1
		var a: Array = profile[section]
		var b: Array = profile[section + 1]
		var t := inverse_lerp(float(a[0]), float(b[0]), z / (body_size.z * .5))
		var half_width := body_size.x * .5 * lerpf(a[1], b[1], t)
		var hood := lerpf(a[2], b[2], t)
		var from_axle := absf(absf(z) - wheelbase * .5)
		var opening := radius * 1.07
		var sill := maxf(.23, radius + sqrt(maxf(0.0, opening * opening - from_axle * from_axle))) if from_axle < opening else .23
		var edge := maxf(hood - .112, sill + .042)
		shell.append(PackedVector3Array([
			Vector3(-half_width * .90, sill, z), Vector3(-half_width, lerpf(sill, edge, .49), z),
			Vector3(-half_width * .997, edge, z), Vector3(-half_width * .83, hood, z),
			Vector3(0, hood + .028, z), Vector3(half_width * .83, hood, z),
			Vector3(half_width * .997, edge, z), Vector3(half_width, lerpf(sill, edge, .49), z),
			Vector3(half_width * .90, sill, z),
		]))
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	mesh.set_smooth_group(0)
	for j in range(shell.size() - 1):
		var z := (shell[j][4].z + shell[j + 1][4].z) * .5
		var in_cabin := z > cabin_start and z < cabin_end
		for i in range(shell[j].size() - 1):
			if in_cabin and i in [3, 4]:
				continue
			quad(mesh, shell[j][i], shell[j][i + 1], shell[j + 1][i + 1], shell[j + 1][i])
	mesh.set_smooth_group(-1)
	for j in [0, shell.size() - 1]:
		var rim: PackedVector3Array = shell[j]
		var center := (rim[4] + (rim[0] + rim[8]) * .5) * .5
		for i in range(rim.size() - 1):
			if j == 0:
				tri(mesh, center, rim[i + 1], rim[i])
			else:
				tri(mesh, center, rim[i], rim[i + 1])
		tri(mesh, center, rim[0] if j == 0 else rim[8], rim[8] if j == 0 else rim[0])
	mesh.generate_normals()
	Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, paint)
	Kit.box_at(self, Vector3(0, .25, 0), Vector3(body_size.x * .83, .12, body_size.z * .93), dark)


func build_cabin(profile: Array, belt: float, style: String) -> void:
	var half := body_size.z * .5
	var waist := body_size.x * .438
	var lid := waist * (.87 if style in ["wagon", "suv", "pickup"] else .81)
	var roof_material := Kit.paint(Color("#262e40"), .89) if style == "convertible" else paint
	var side := PackedVector3Array([
		Vector3(waist * .92, belt - .04, profile[0] * half),
		Vector3(lid * .96, body_size.y - .036, profile[1] * half),
		Vector3(lid, body_size.y - .042, profile[2] * half),
		Vector3(waist * .96, belt - .034, profile[3] * half),
	])
	var mate := PackedVector3Array()
	for point in side:
		mate.append(Vector3(-point.x, point.y, point.z))
	panel(mate[0], mate[1], side[1], side[0], glass)
	var rear_side := side[3]
	var rear_roof := side[2]
	if style == "convertible":
		rear_side.x *= .65
		rear_roof.x *= .78
		panel(side[3], side[2], rear_roof, rear_side, roof_material)
		panel(rear_side * Vector3(-1, 1, 1), rear_roof * Vector3(-1, 1, 1), mate[2], mate[3], roof_material)
	panel(rear_side, rear_roof, rear_roof * Vector3(-1, 1, 1), rear_side * Vector3(-1, 1, 1), rear_glass)
	var roof_middle := Vector3(0, body_size.y, (side[1].z + side[2].z) * .5)
	var roof_front := Vector3(0, body_size.y - .012, side[1].z)
	var roof_rear := Vector3(0, body_size.y - .018, side[2].z)
	panel(mate[1], roof_front, roof_middle, mate[1].lerp(mate[2], .5), roof_material)
	panel(roof_front, side[1], side[1].lerp(side[2], .5), roof_middle, roof_material)
	panel(mate[1].lerp(mate[2], .5), roof_middle, roof_rear, mate[2], roof_material)
	panel(roof_middle, side[1].lerp(side[2], .5), side[2], roof_rear, roof_material)
	for side_index in 2:
		var points := side if side_index == 0 else mate
		var sign_x := 1.0 if side_index == 0 else -1.0
		var top := points[2]
		var bottom := points[3]
		if style == "convertible":
			top = points[2].lerp(points[1], .15)
			bottom = points[3].lerp(points[0], .23)
			panel(bottom, top, points[2], points[3], roof_material)
		panel(points[0], points[1], top, bottom, glass)
		for edge in 4:
			Kit.beam(self, points[edge], points[(edge + 1) % 4], .038 if edge == 2 else .029, roof_material)
		var pillars := [.46, .78] if style in ["wagon", "suv", "sedan", "pickup"] else [.56]
		for fraction: float in pillars:
			var pillar_top := points[1].lerp(points[2], clampf((fraction - .15) / .68, 0.0, 1.0))
			var pillar_foot := points[0].lerp(points[3], fraction)
			var offset := Vector3(sign_x * .008, 0, 0)
			Kit.beam(self, pillar_top + offset, pillar_foot + offset, .059, dark)
		var mirror := points[0] + Vector3(sign_x * .14, .14, .10)
		Kit.beam(self, points[0] + Vector3(0, .06, .1), mirror, .055, dark)
		var housing := Interior.oval(self, mirror, Vector3(.218, .108, .137), dark if style == "convertible" else paint)
		housing.rotation.y = sign_x * .14
		var lens := Interior.oval(self, mirror + Vector3(0, 0, .052), Vector3(.176, .078, .037), mirror_glass)
		lens.rotation.y = housing.rotation.y
		if style == "suv":
			Interior.oval(self, mirror + Vector3(sign_x * .019, -.008, -.055), Vector3(.131, .018, .028), amber)
		if style == "suv":
			var rail_front := points[1] + Vector3.UP * .059
			var rail_rear := points[2] + Vector3.UP * .059
			Kit.beam(self, rail_front, rail_rear, .029, trim)
			Kit.beam(self, points[1], rail_front, .043, dark)
			Kit.beam(self, rail_rear, points[2], .043, dark)
	add_wipers(side, mate)


func add_wipers(right: PackedVector3Array, left: PackedVector3Array) -> void:
	var lower_left := left[0].lerp(left[1], .087)
	var lower_right := right[0].lerp(right[1], .087)
	var offset := Vector3(0, .014, -.015)
	for t in [.23, .64]:
		var hinge := left[0].lerp(right[0], t) + offset
		var blade := lower_left.lerp(lower_right, t + .08) + offset
		Kit.beam(self, hinge, blade, .016, dark)
		Kit.beam(self, blade - Vector3.RIGHT * .186, blade + Vector3.RIGHT * .178 + Vector3.UP * .015, .013, dark)


func add_door_details(style: String, belt: float, cabin_start: float, cabin_end: float) -> void:
	var long_door := style in ["coupe", "convertible"]
	var front := cabin_start + .09
	var back := lerpf(front, cabin_end, .76 if long_door else .83)
	var divider := lerpf(front, back, .53)
	var top := belt - .12
	var bottom := .328 if style == "suv" else .293
	for side in [-1.0, 1.0]:
		trace_body(side, [Vector2(front, top + .01), Vector2(front + .057, belt - .27),
			Vector2(front + .10, bottom + .044), Vector2(front + .16, bottom),
			Vector2(back - .15, bottom), Vector2(back - .076, bottom + .056), Vector2(back, top + .013)], .009, dark)
		if not long_door:
			trace_body(side, [Vector2(divider, top + .02), Vector2(divider + .015, bottom)], .009, dark)
		var catches := [back - .123] if long_door else [divider - .122, back - .128]
		for at: float in catches:
			var position := side_point(side, at, top - .008)
			Kit.box_at(self, position, Vector3(.019, .033, .120), dark)
			Kit.box_at(self, position + Vector3.RIGHT * float(side) * .013, Vector3(.019, .018, .102),
				trim if style == "convertible" else paint)
		if style in ["convertible", "sedan", "suv"]:
			var molding := .043 if style == "suv" else .018
			var level := .327 if style == "suv" else top - .116
			trace_body(side, [Vector2(front + .05, level), Vector2(back + .06, level + .008)],
				molding, dark if style == "suv" else trim)
		elif style == "wagon":
			trace_body(side, [Vector2(divider + .22, top - .14), Vector2(cabin_end + .04, top - .128)], .015, dark)


func trace_body(side: float, path: Array, width: float, material: Material) -> void:
	for i in range(1, path.size()):
		var a: Vector2 = path[i - 1]
		var b: Vector2 = path[i]
		var steps := maxi(1, ceili(a.distance_to(b) / .12))
		var last := side_point(side, a.x, a.y)
		for step in range(1, steps + 1):
			var at := a.lerp(b, float(step) / steps)
			var next := side_point(side, at.x, at.y)
			if last.distance_squared_to(next) > .00001:
				Kit.beam(self, last, next, width, material)
			last = next


func side_point(side: float, z: float, y: float) -> Vector3:
	var section := 0
	while section < shell.size() - 2 and shell[section + 1][4].z < z:
		section += 1
	var a := shell[section]
	var b := shell[section + 1]
	var blend := clampf(inverse_lerp(a[4].z, b[4].z, z), 0, 1)
	for index in range(5, 8):
		var upper := a[index].lerp(b[index], blend)
		var lower := a[index + 1].lerp(b[index + 1], blend)
		if y >= lower.y or index == 7:
			var point := upper.lerp(lower, clampf(inverse_lerp(upper.y, lower.y, y), 0, 1))
			point.x = (point.x + .007) * side
			return point
	return Vector3.ZERO


func build_pickup_fittings(cabin_end: float, has_toolbox: bool) -> void:
	var half := body_size.x * .5
	var nose := -body_size.z * .5
	var tailgate := body_size.z * .5
	var bed_start := cabin_end + .10
	var bed_length := tailgate - bed_start
	var bed_middle := (tailgate + bed_start) * .5
	Kit.box_at(self, Vector3(0, 1.069, bed_middle), Vector3(half * 1.715, .057, bed_length - .08), dark)
	for track in 9:
		Kit.box_at(self, Vector3((track - 4) * .139, 1.105, bed_middle), Vector3(.024, .022, bed_length - .13), rubber)
	for side: float in [-1.0, 1.0]:
		Kit.box_at(self, Vector3(half * .90 * side, 1.19, bed_middle), Vector3(.15, .29, bed_length), paint)
		Kit.box_at(self, Vector3(half * .90 * side, 1.344, bed_middle), Vector3(.157, .031, bed_length), rubber)
		var lamp_x := side * half * .75
		Kit.box_at(self, Vector3(lamp_x, .91, nose - .017), Vector3(.31, .224, .047), lamp)
		Kit.box_at(self, Vector3(lamp_x, .814, nose - .044), Vector3(.302, .043, .02), amber)
		Kit.box_at(self, Vector3(lamp_x, 1.08, tailgate + .028), Vector3(.15, .34, .048), tail)
		Kit.box_at(self, Vector3(lamp_x, .999, tailgate + .056), Vector3(.13, .049, .021), white)
		var light := SpotLight3D.new()
		add_child(light)
		light.position = Vector3(lamp_x, .89, nose - .062)
		light.light_color = Color("#fcf1d8")
		light.light_energy = 1.9
		light.spot_range = 36
		light.spot_angle = 30
		light.hide()
		running_lights.append(light)
	Kit.box_at(self, Vector3(0, 1.176, tailgate - .029), Vector3(half * 1.68, .251, .075), paint)
	Kit.box_at(self, Vector3(0, 1.237, tailgate + .017), Vector3(.225, .043, .023), dark)
	Kit.box_at(self, Vector3(0, .64, tailgate + .018), Vector3(half * 1.92, .155, .154), trim)
	Kit.box_at(self, Vector3(0, .65, nose - .018), Vector3(half * 1.91, .156, .18), trim)
	intake(nose, .775, 1.014, half * .55, half * .57, 4)
	Kit.box_at(self, Vector3(0, .60, tailgate + .105), Vector3(.29, .127, .019), white)
	Badges.lettering(self, "DEEP RIVER", Vector3(0, 1.122, tailgate + .02), .050, dark.albedo_color)
	if has_toolbox:
		Kit.box_at(self, Vector3(0, 1.281, bed_start + .26), Vector3(half * 1.78, .387, .50), trim)
		Kit.box_at(self, Vector3(0, 1.49, bed_start + .26), Vector3(half * 1.81, .047, .55), trim)
		Kit.box_at(self, Vector3(0, body_size.y + .06, .22), Vector3(.88, .077, .148), amber)


func build_fittings(style: String) -> void:
	var nose := -body_size.z * .5 - .005
	var back := body_size.z * .5 + .008
	var half := body_size.x * .5
	build_grille(style, nose)
	build_identification(style, nose, back)
	if style in ["suv", "coupe", "wagon"]:
		Interior.oval(self, Vector3(0, .278, nose - .003), Vector3(half * 1.49, .049, .075), dark)
		Interior.oval(self, Vector3(0, .281, back - .002), Vector3(half * 1.51, .043, .071), dark)
	Kit.box_at(self, Vector3(.51, .272, back - .062), Vector3(.13, .074, .21), trim)
	for s in [-1.0, 1.0]:
		var x := half * .63 * float(s)
		build_headlamp(style, nose, s)
		var fog := CylinderMesh.new()
		fog.top_radius = .040
		fog.bottom_radius = .045
		fog.height = .016
		fog.radial_segments = 14
		Kit.mesh_at(self, fog, Vector3(half * .62 * s, .365, nose - .015), reflector).rotation.x = PI * .5
		build_taillight(style, back, s)
		var beam := SpotLight3D.new()
		beam.position = Vector3(x, .57, nose - .095)
		beam.rotation_degrees.x = -3
		beam.light_color = Color("#f4e7cd")
		beam.light_energy = 1.8
		beam.spot_range = 33
		beam.spot_angle = 31
		beam.hide()
		running_lights.append(beam)
		add_child(beam)


func build_taillight(style: String, back: float, side: float) -> void:
	var width := shell[-1][6].x
	var outer := width * .97
	var inner := width * (.69 if style == "wagon" else .56)
	var level := .668
	var tip := .859 if style == "wagon" else (.763 if style == "suv" else .714)
	panel(Vector3(inner * side, level - .061, back + .014),
		Vector3(outer * side, level - .020, back + .010),
		Vector3(outer * side, tip, back - .018),
		Vector3((inner + .028) * side, level + .034, back + .014), tail)
	panel(Vector3((inner + .022) * side, level - .038, back + .020),
		Vector3(lerpf(inner, outer, .67) * side, level - .017, back + .018),
		Vector3(lerpf(inner, outer, .61) * side, level - .002, back + .018),
		Vector3((inner + .030) * side, level - .022, back + .020), white)


func build_identification(style: String, nose: float, back: float) -> void:
	var crest_height := {"wagon": .578, "suv": .635, "sedan": .545, "convertible": .565, "coupe": .587}
	var crest_y := float(crest_height[style])
	var width := .185 if style == "convertible" else .119
	Badges.stamp(self, style, Vector3(0, crest_y, nose - .044), width, true)
	Badges.stamp(self, style, Vector3(0, .730 if style in ["wagon", "suv"] else .673, back + .014), width)
	var names: Array = Badges.REAR_NAMES[style]
	Badges.lettering(self, names[0], Vector3(-body_size.x * .267, .605, back + .013), .040, Color("#d6dbdc"))
	if not names[1].is_empty():
		Badges.lettering(self, names[1], Vector3(body_size.x * .255, .605, back + .013), .037, Color("#d6dbdc"))
	var plate := Vector3(0, .511, back)
	Kit.box_at(self, plate, Vector3(.316, .137, .025), dark)
	Kit.box_at(self, plate + Vector3.BACK * .019, Vector3(.298, .120, .015), white)
	Badges.lettering(self, "ONTARIO", plate + Vector3(0, .040, .030), .021, Color("#1e4166"))
	Badges.lettering(self, Badges.PLATES[style], plate + Vector3(0, .001, .030), .050, Color("#1e4166"))


func build_headlamp(style: String, nose: float, side: float) -> void:
	var extent := shell[0][6].x
	var inner := extent * (.49 if style == "suv" else .54)
	var outer := extent * 1.025
	var lower := .531 if style == "suv" else .481
	var rise := .128 if style in ["wagon", "suv", "coupe"] else .112
	var sweep := .026 if style in ["sedan", "convertible"] else .062
	var center := Vector3(lerpf(inner, outer, .49) * side, lower + rise * .54, nose - .022)
	var contour := PackedVector3Array([
		Vector3(inner * side, lower + .028, nose - .018),
		Vector3((inner + .037) * side, lower, nose - .024),
		Vector3(lerpf(inner, outer, .65) * side, lower + .006, nose - .024),
		Vector3((outer - .014) * side, lower + .038, nose - .015),
		Vector3(outer * side, lower + rise + sweep * .31, nose + .008),
		Vector3((outer - .046) * side, lower + rise, nose - .008),
		Vector3((inner + .043) * side, lower + rise * .78, nose - .023),
	])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in contour.size():
		var next := (i + 1) % contour.size()
		tri(surface, center, contour[i] if side > 0 else contour[next], contour[next] if side > 0 else contour[i])
	surface.generate_normals()
	lamp.cull_mode = BaseMaterial3D.CULL_DISABLED
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, lamp)
	panel(contour[2].lerp(center, .21) + Vector3.FORWARD * .010,
		contour[3] + Vector3.FORWARD * .012, contour[4] + Vector3.FORWARD * .013,
		contour[5].lerp(center, .43) + Vector3.FORWARD * .011, amber)
	var bulb := CylinderMesh.new()
	bulb.top_radius = rise * .24
	bulb.bottom_radius = bulb.top_radius
	bulb.radial_segments = 14
	bulb.height = .008
	for i in 2:
		var position := center + Vector3((-0.055 + i * .058) * side, .005, -.010)
		Kit.mesh_at(self, bulb, position, reflector).rotation.x = PI * .5


func build_grille(style: String, nose: float) -> void:
	match style:
		"wagon":
			intake(nose, .36, .527, .42, .58, 2)
		"suv":
			intake(nose, .349, .521, .43, .31, 2)
			intake(nose, .586, .656, .30, .41, 1)
		"convertible":
			intake(nose, .369, .539, .37, .445, 4)
			Kit.box_at(self, Vector3(0, .563, nose - .021), Vector3(.245, .025, .018), trim)
		"coupe":
			intake(nose, .395, .505, .465, .387, 1)
			intake(nose, .559, .62, .29, .39, 0)
			Kit.box_at(self, Vector3(0, .615, nose - .024), Vector3(.207, .033, .019), paint)
		_:
			intake(nose, .492, .591, .28, .427, 2)
			intake(nose, .328, .414, .49, .40, 1)


func intake(z: float, bottom: float, top: float, lower: float, upper: float, bars: int) -> void:
	var face := z - .014
	panel(Vector3(-lower, bottom, face), Vector3(lower, bottom, face),
		Vector3(upper, top, face), Vector3(-upper, top, face), dark)
	for i in bars:
		var t := float(i + 1) / (bars + 1)
		Kit.box_at(self, Vector3(0, lerpf(bottom, top, t), face - .005),
			Vector3(lerpf(lower, upper, t) * 1.91, .009, .009), trim)


func build_wheels(style: String) -> void:
	var track := body_size.x * .5 - .087
	var patterns := {"wagon": 10, "suv": 5, "sedan": 6, "convertible": 12, "coupe": 5, "pickup": 6}
	var spokes: int = patterns[style]
	var spoke_width := .023 if spokes > 6 else .042
	for axle in [-1.0, 1.0]:
		for side in [-1.0, 1.0]:
			var pivot := Node3D.new()
			add_child(pivot)
			pivot.position = Vector3(track * side, radius, wheelbase * .5 * axle)
			pivots.append(pivot)
			var hub := Node3D.new()
			pivot.add_child(hub)
			hubs.append(hub)
			wheel_disc(hub, radius, .193, 0, rubber)
			wheel_disc(hub, radius * .93, .206, 0, dark)
			wheel_disc(hub, radius * .636, .215, 0, trim)
			wheel_disc(hub, radius * .552, .012, side * .115, dark)
			wheel_disc(hub, radius * .19, .024, side * .123, trim)
			for i in spokes:
				var angle := float(i) * TAU / spokes
				var radial := Vector3(0, cos(angle), sin(angle))
				var arm := Kit.box_at(hub, radial * radius * .37 + Vector3(side * .127, 0, 0),
					Vector3(.022, radius * .43, spoke_width), trim)
				arm.rotation.x = angle
			combine_meshes(hub)
			var cap := null if style == "pickup" else Badges.stamp(hub, style, Vector3(side * .137, 0, 0), .045)
			if cap != null:
				cap.rotation.y = side * PI * .5
				cap.visibility_range_end = 12.0


func wheel_disc(hub: Node3D, width: float, depth: float, at_x: float, material: Material) -> void:
	var disc := CylinderMesh.new()
	disc.top_radius = width
	disc.bottom_radius = width
	disc.height = depth
	disc.radial_segments = 24
	Kit.mesh_at(hub, disc, Vector3(at_x, 0, 0), material).rotation.z = PI * .5


func combine_meshes(parent: Node3D) -> void:
	var surfaces := {}
	for child in parent.get_children():
		if not child is MeshInstance3D:
			continue
		var material: Material = child.material_override
		# Keep each pane separate so blend sorting can use its own position.
		if material is ShaderMaterial:
			continue
		if not surfaces.has(material):
			var surface := SurfaceTool.new()
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
			surfaces[material] = surface
		var mesh: Mesh = child.mesh
		var batch: SurfaceTool = surfaces[material]
		var arrays := mesh.surface_get_arrays(0)
		var vertices: PackedVector3Array = arrays[Mesh.ARRAY_VERTEX]
		var normals: PackedVector3Array = arrays[Mesh.ARRAY_NORMAL]
		var indices: PackedInt32Array = arrays[Mesh.ARRAY_INDEX] if arrays[Mesh.ARRAY_INDEX] != null else PackedInt32Array()
		var placement: Transform3D = child.transform
		var normal_basis := placement.basis.inverse().transposed()
		for i in (vertices.size() if indices.is_empty() else indices.size()):
			var vertex := i if indices.is_empty() else indices[i]
			batch.set_normal((normal_basis * normals[vertex]).normalized())
			batch.add_vertex(placement * vertices[vertex])
		parent.remove_child(child)
		child.free()
	for material: Material in surfaces:
		Kit.mesh_at(parent, surfaces[material].commit(), Vector3.ZERO, material)


func animate(wheel_turn: float, steer: float, braking: bool, lamps_on: bool, speed: float) -> void:
	for i in hubs.size():
		hubs[i].rotation.x = wheel_turn
		pivots[i].rotation.y = steer if i < 2 else 0.0
	for beam in running_lights:
		beam.visible = lamps_on
	lamp.emission_enabled = lamps_on
	lamp.emission = Color("#f9ecc0")
	tail.emission_enabled = braking or lamps_on
	tail.emission = Color("#e62a20")
	tail.emission_energy_multiplier = 1.12 if braking else .32
	interior.pose(steer, speed)


func panel(a: Vector3, b: Vector3, c: Vector3, d: Vector3, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := (a + b + c + d) * .25
	if material is ShaderMaterial:
		var corners := PackedVector3Array([a, b, c, d])
		var uv := PackedVector2Array([Vector2.ZERO, Vector2.DOWN, Vector2.ONE, Vector2.RIGHT])
		for index in [0, 1, 2, 0, 2, 3]:
			surface.set_uv(uv[index])
			surface.add_vertex(corners[index] - center)
	else:
		quad(surface, a - center, b - center, c - center, d - center)
	surface.generate_normals()
	var mesh := surface.commit()
	var item := Kit.mesh_at(self, mesh, center, material)
	if material is BaseMaterial3D:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	else:
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		item.visibility_range_end = CABIN_DETAIL_DISTANCE
		Kit.mesh_at(distant_windows, mesh, center, distant_glass)


static func quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	tri(surface, a, b, c)
	tri(surface, a, c, d)


static func tri(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3) -> void:
	surface.add_vertex(a)
	surface.add_vertex(b)
	surface.add_vertex(c)
