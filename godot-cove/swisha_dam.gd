extends RefCounted

const Kit = preload("res://scenery.gd")
const Concrete = preload("res://swisha_concrete.gdshader")
const Discharge = preload("res://swisha_water.gdshader")
const BAYS := 8
const STRUCTURE_SCALE := 1.0 / 0.088

var station: Node3D
var wall: ShaderMaterial
var wet_concrete: ShaderMaterial
var penstock: ShaderMaterial
var asphalt: StandardMaterial3D
var steel: StandardMaterial3D
var blue_steel: StandardMaterial3D
var galvanized: StandardMaterial3D
var glass: StandardMaterial3D
var amber: StandardMaterial3D
var deck: float
var width: float
var front: float
var left: float
var right: float
var outlet_spacing: float


func build(parent: Node3D, plan: Dictionary, ground: Callable, assets: String) -> void:
	var south := map_point(plan.crest[0])
	var north := map_point(plan.crest[1])
	var along := (north - south).normalized()
	station = Node3D.new()
	station.name = "DesJoachimsGeneratingStation"
	parent.add_child(station)
	var axes := Basis(along, Vector3.UP, along.cross(Vector3.UP)).scaled_local(Vector3.ONE * STRUCTURE_SCALE)
	station.transform = Transform3D(axes, (south + north) * 0.5)
	width = south.distance_to(north) / STRUCTURE_SCALE
	deck = float(plan.head_level) / STRUCTURE_SCALE + 0.53
	var end_a := station.to_local(map_point(plan.powerhouse[0]))
	var end_b := station.to_local(map_point(plan.powerhouse[1]))
	front = (end_a.z + end_b.z) * 0.5
	left = end_a.x
	right = end_b.x
	outlet_spacing = (right - left) / BAYS
	wall = concrete(Color("#a49b88"), 0.9)
	wet_concrete = concrete(Color("#8f938b"), 1.25)
	penstock = concrete(Color("#82705d"), 1.7)
	asphalt = Kit.paint(Color("#3f4745"))
	steel = Kit.paint(Color("#30383b"), 0.58, 0.24)
	blue_steel = Kit.paint(Color("#526e75"), 0.58, 0.18)
	galvanized = Kit.paint(Color("#969c8d"), 0.55, 0.28)
	glass = Kit.paint(Color("#324953"), 0.36, 0.13)
	amber = Kit.paint(Color("#bd863e"), 0.66, 0.14)
	build_crest()
	build_powerhouse()
	build_discharge(assets)
	build_woodland(parent, plan.woodland, ground)


func map_point(coords: Array) -> Vector3:
	return Vector3(coords[0], 0, coords[1])


func concrete(color: Color, streaks: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Concrete
	material.set_shader_parameter("cement", color)
	material.set_shader_parameter("stain", streaks)
	return material


func solid(at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	return Kit.box_at(station, at, size, material)


func rail(a: Vector3, b: Vector3, thickness: float, material: Material) -> void:
	Kit.beam(station, a, b, thickness, material)


func concrete_section(x0: float, x1: float, profile: PackedVector2Array, material: Material) -> void:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var center := Vector3((x0 + x1) * 0.5, 0, 0)
	for p in profile:
		center += Vector3(0, p.y, p.x) / profile.size()
	for index in profile.size():
		var p := profile[index]
		var q := profile[(index + 1) % profile.size()]
		var a := Vector3(x0, p.y, p.x)
		var b := Vector3(x1, p.y, p.x)
		var c := Vector3(x1, q.y, q.x)
		var d := Vector3(x0, q.y, q.x)
		triangle(mesh, a, b, c, center)
		triangle(mesh, a, c, d, center)
	var triangles := Geometry2D.triangulate_polygon(profile)
	for x: float in [x0, x1]:
		for index in range(0, triangles.size(), 3):
			var a := profile[triangles[index]]
			var b := profile[triangles[index + 1]]
			var c := profile[triangles[index + 2]]
			triangle(mesh, Vector3(x, a.y, a.x), Vector3(x, b.y, b.x), Vector3(x, c.y, c.x), center)
	Kit.mesh_at(station, mesh.commit(), Vector3.ZERO, material)


func triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, center: Vector3) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var exterior := normal.dot((a + b + c) / 3.0 - center) > 0.0
	mesh.set_normal(normal if exterior else -normal)
	mesh.add_vertex(a)
	mesh.add_vertex(c if exterior else b)
	mesh.add_vertex(b if exterior else c)


func build_crest() -> void:
	var wing := PackedVector2Array([Vector2(-0.20, 0.40), Vector2(-0.20, deck - 0.14),
		Vector2(0.76, deck - 0.14), Vector2(3.75, 0.74), Vector2(3.75, 0.40)])
	concrete_section(-width * 0.5 - 0.3, left, wing, wall)
	concrete_section(right, width * 0.5 + 0.34, wing, wall)
	solid(Vector3((left + right) * 0.5, deck * 0.49, 0.28),
		Vector3(right - left, deck - 0.12, 0.95), wet_concrete)
	solid(Vector3(0, deck - 0.06, 0.31), Vector3(width + 0.7, 0.19, 1.42), wall)
	solid(Vector3(0, deck + 0.039, 0.31), Vector3(width + 0.6, 0.032, 0.94), asphalt)
	var walk := StaticBody3D.new()
	walk.name = "CrestDeck"
	station.add_child(walk)
	Kit.collider(walk, Vector3(0, deck - 0.062, 0.32), Vector3(width + 0.7, 0.20, 1.42))
	var posts: Array[Transform3D] = []
	for z: float in [-0.28, 0.94]:
		solid(Vector3(0, deck + 0.10, z), Vector3(width + 0.57, 0.18, 0.11), wall)
		rail(Vector3(-width * 0.5, deck + 0.33, z), Vector3(width * 0.5, deck + 0.33, z), 0.025, galvanized)
		for index in floori(width / 0.57) + 1:
			var x := -width * 0.5 + 0.57 * index
			posts.append(Transform3D(Basis.IDENTITY, Vector3(x, deck + 0.255, z)))
	var post := BoxMesh.new()
	post.size = Vector3(0.026, 0.165, 0.037)
	Kit.new().scatter(station, post, posts, galvanized)
	for z: float in [-0.04, 0.77]:
		rail(Vector3(left - 1.0, deck + 0.062, z), Vector3(right + 2.0, deck + 0.062, z), 0.044, steel)
	var hoist := right - 2.9
	for side: float in [-0.82, 0.82]:
		for z: float in [-0.055, 0.79]:
			var foot := Vector3(hoist + side, deck + 0.04, z)
			rail(foot, foot + Vector3.UP * 0.91, 0.093, steel)
			rail(foot + Vector3.UP * 0.43,
				Vector3(hoist + side * 0.42, deck + 0.91, z), 0.046, steel)
		solid(Vector3(hoist + side, deck + 0.95, 0.36), Vector3(0.15, 0.15, 1.12), amber)
	solid(Vector3(hoist, deck + 1.04, 0.36), Vector3(1.83, 0.17, 0.83), amber)
	solid(Vector3(hoist + 0.48, deck + 1.23, 0.38), Vector3(0.54, 0.24, 0.68), blue_steel)
	solid(Vector3(hoist + 0.49, deck + 1.24, 0.73), Vector3(0.36, 0.12, 0.03), glass)
	for x: float in [left - 1.1, right + 0.92]:
		solid(Vector3(x, deck - 1.10, 0.77), Vector3(0.67, 3.30, 0.89), wet_concrete)
		solid(Vector3(x, deck + 0.58, 0.77), Vector3(0.80, 0.16, 0.96), steel)


func build_powerhouse() -> void:
	var center := (left + right) * 0.5
	var span := right - left
	var roof := 2.53
	var back := front - 2.35
	var body_depth := front - back
	solid(Vector3(center, (1.09 + roof) * 0.5, (front + back) * 0.5),
		Vector3(span + 0.28, roof - 1.09, body_depth), wet_concrete)
	solid(Vector3(center, roof, (front + back) * 0.5), Vector3(span + 0.55, 0.13, body_depth + 0.22), asphalt)
	solid(Vector3(center, roof - 0.108, front + 0.026), Vector3(span + 0.45, 0.082, 0.11), wall)
	solid(Vector3(center, 1.09, front + 0.08), Vector3(span + 0.41, 0.19, 0.49), wall)
	solid(Vector3(center, 0.22, front - 0.65), Vector3(span, 1.1, 0.56), steel)
	solid(Vector3(center, 1.25, front + 0.34), Vector3(span + 0.17, 0.08, 0.092), galvanized)
	solid(Vector3(center, 1.44, front + 0.38), Vector3(span + 0.18, 0.025, 0.034), steel)
	var openings := PackedVector2Array([Vector2(front - 0.95, -0.68), Vector2(front - 0.95, 1.11),
		Vector2(front + 0.39, 1.11), Vector2(front + 0.44, 0.73), Vector2(front + 0.70, -0.68)])
	for index in BAYS + 1:
		var xt := left + outlet_spacing * index
		concrete_section(xt - 0.115, xt + 0.115, openings, wet_concrete)
		solid(Vector3(xt, 1.86, front + 0.025), Vector3(0.15, 1.28, 0.085), wall)
		solid(Vector3(xt, 1.35, front + 0.38), Vector3(0.03, 0.26, 0.031), steel)
	for index in BAYS:
		var x := left + outlet_spacing * (index + 0.5)
		var ramp := PackedVector2Array([Vector2(0.65, 1.14), Vector2(0.65, deck - 0.80),
			Vector2(1.55, deck - 0.80), Vector2(back + 0.10, 2.20), Vector2(back + 0.10, 1.14)])
		concrete_section(x - outlet_spacing * 0.36, x + outlet_spacing * 0.36, ramp, penstock)
		solid(Vector3(x, 0.926, front - 0.025), Vector3(outlet_spacing * 0.80, 0.19, 0.15), steel)
		solid(Vector3(x, 0.826, front + 0.057), Vector3(outlet_spacing * 0.81, 0.055, 0.18), blue_steel)
		solid(Vector3(x, 2.21, front + 0.022), Vector3(outlet_spacing * 0.82, 0.23, 0.046), steel)
		for pane in 4:
			var px := x + (pane - 1.5) * outlet_spacing * 0.20
			solid(Vector3(px, 2.21, front + 0.05), Vector3(outlet_spacing * 0.176, 0.172, 0.014), glass)
		solid(Vector3(x, roof + 0.105, front - 0.79), Vector3(0.24, 0.14, 0.26), galvanized)
		solid(Vector3(x + 0.12, 1.63, front + 0.12), Vector3(0.41, 0.76, 0.25), blue_steel)
		solid(Vector3(x + 0.12, 1.674, front + 0.259), Vector3(0.25, 0.28, 0.024), steel)
		for slot in 5:
			solid(Vector3(x + 0.12, 1.575 + slot * 0.041, front + 0.277),
				Vector3(0.29, 0.018, 0.019), galvanized)
	for x: float in [left, right]:
		solid(Vector3(x, 1.36, front - 0.22), Vector3(0.42, 2.16, 0.81), wet_concrete)
	solid(Vector3(center, 2.423, front + 0.105), Vector3(2.01, 0.18, 0.055), steel)
	var plaque := Label3D.new()
	plaque.text = "DES JOACHIMS"
	plaque.font_size = 52
	plaque.pixel_size = 0.0027
	plaque.outline_size = 0
	plaque.modulate = Color("#dedbc9")
	plaque.position = Vector3(center, 2.424, front + 0.136)
	station.add_child(plaque)


func build_discharge(assets: String) -> void:
	var spray := spray_mesh()
	for index in BAYS:
		var x := left + outlet_spacing * (float(index) + 0.5)
		var force: float = [0.78, 1.0, 0.86, 0.92, 0.73, 1.0, 0.89, 0.80][index]
		add_torrent(x, force, index)
		add_spray(Vector3(x, 0.19, front + 1.20), spray, force)
	var roar := AudioStreamWAV.new()
	roar.format = AudioStreamWAV.FORMAT_16_BITS
	roar.mix_rate = 22050
	roar.data = FileAccess.get_file_as_bytes(assets + "swisha_roar.pcm")
	roar.loop_mode = AudioStreamWAV.LOOP_FORWARD
	roar.loop_end = roar.data.size() >> 1
	var source := AudioStreamPlayer3D.new()
	source.bus = &"Water"
	source.name = "SpillwayRoar"
	source.stream = roar
	source.unit_size = 7.8 * STRUCTURE_SCALE
	source.max_distance = 95.0 * STRUCTURE_SCALE
	source.volume_db = -6.0
	station.add_child(source)
	source.position = Vector3((left + right) * 0.5, 0.39, front + 1.3)
	source.play()


func add_torrent(x: float, force: float, index: int) -> void:
	const STRIPS := 18
	const RIBS := 23
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in RIBS + 1:
		var v := float(row) / RIBS
		for col in STRIPS + 1:
			var u := float(col) / STRIPS
			var edge := (u - 0.5) * 2.0
			var span := outlet_spacing * (0.67 + v * 0.18) * force
			var curl := pow(absf(edge), 3.2) * v * 0.14
			var y := 0.85 - pow(v, 1.18) * 1.04 - curl
			var z := front - 0.025 + pow(v, 0.82) * (1.80 + 0.42 * force) - curl * 0.32
			surface.set_uv(Vector2(u, v))
			surface.add_vertex(Vector3(x + (u - 0.5) * span + sin(v * 7.2 + index) * v * 0.051, y, z))
	for row in RIBS:
		for col in STRIPS:
			var a := row * (STRIPS + 1) + col
			var b := a + STRIPS + 1
			for id in [a, a + 1, b, a + 1, b + 1, b]:
				surface.add_index(id)
	var current := ShaderMaterial.new()
	current.shader = Discharge
	current.set_shader_parameter("pace", 0.69 + force * 0.42)
	current.set_shader_parameter("offset", index * 0.813)
	var flow := Kit.mesh_at(station, surface.commit(), Vector3.ZERO, current)
	flow.name = "Discharge%d" % (index + 1)
	flow.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func spray_mesh() -> QuadMesh:
	var fog := Image.create_empty(48, 48, false, Image.FORMAT_RGBA8)
	for y in 48:
		for x in 48:
			var p := Vector2(x - 23.5, y - 23.5) / 23.5
			var alpha := pow(maxf(0.0, 1.0 - p.length_squared()), 2.7)
			var cloud := 0.70 + 0.18 * cos(p.x * 6.0 + p.y * 8.8) + 0.12 * sin(p.y * 11.1 - p.x * 7.8)
			fog.set_pixel(x, y, Color(0.83, 0.92, 0.92, alpha * cloud))
	var material := Kit.paint(Color.WHITE)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	material.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
	material.vertex_color_use_as_albedo = true
	material.albedo_texture = ImageTexture.create_from_image(fog)
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.81, 0.69)
	mesh.material = material
	return mesh


func add_spray(at: Vector3, mesh: Mesh, force: float) -> void:
	var mist := CPUParticles3D.new()
	mist.mesh = mesh
	mist.amount = 46
	mist.lifetime = 1.35
	mist.preprocess = 1.4
	mist.local_coords = true
	mist.emission_shape = CPUParticles3D.EMISSION_SHAPE_BOX
	mist.emission_box_extents = Vector3(outlet_spacing * 0.24, 0.042, 0.23)
	mist.direction = Vector3(0, 0.8, 0.9).normalized()
	mist.spread = 48.0
	mist.gravity = Vector3(0, -1.18, 0)
	mist.initial_velocity_min = 0.46
	mist.initial_velocity_max = 1.72 * force
	mist.scale_amount_min = 0.34
	mist.scale_amount_max = 1.31
	var grow := Curve.new()
	grow.add_point(Vector2(0.0, 0.43))
	grow.add_point(Vector2(1.0, 1.0))
	mist.scale_amount_curve = grow
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, 0.19, 0.55, 1.0])
	fade.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, 0.56),
		Color(1, 1, 1, 0.31), Color(1, 1, 1, 0)])
	mist.color_ramp = fade
	mist.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	station.add_child(mist)
	mist.position = at
	mist.emitting = true


func build_woodland(parent: Node3D, locations: Array, ground: Callable) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 1304
	var palette := [Color("#394d38"), Color("#496248"), Color("#65704c"), Color("#9b743e"), Color("#a55732")]
	var crowns: Array = [[], [], [], [], []]
	var canopy := SphereMesh.new()
	canopy.radius = 0.57
	canopy.height = 1.18
	canopy.radial_segments = 7
	canopy.rings = 4
	for coords: Array in locations:
		var position := map_point(coords)
		var local := station.to_local(position)
		if absf(local.x) < width * 0.53 and local.z > -1.5 and local.z < 7.2:
			continue
		position.y = ground.call(position.x, position.z)
		var size := rng.randf_range(5.3, 12.8)
		var spin := Basis(Vector3.UP, rng.randf_range(0, TAU))
		var stretch := Vector3(size, size * rng.randf_range(0.94, 1.46), size * 0.84)
		var group := rng.randi_range(0, 4) if rng.randf() < 0.38 else rng.randi_range(0, 2)
		crowns[group].append(Transform3D(spin.scaled_local(stretch), position + Vector3.UP * size * 0.69))
		if size > 9.6:
			var tuft := Vector3(spin.x.x * 0.22, 0.51, spin.x.z * 0.22) * size
			crowns[group].append(Transform3D(spin.scaled_local(stretch * 0.72), position + tuft + Vector3.UP * size * 0.61))
	for index in palette.size():
		var transforms: Array[Transform3D] = []
		transforms.assign(crowns[index])
		Kit.new().scatter(parent, canopy, transforms, Kit.paint(palette[index]))
