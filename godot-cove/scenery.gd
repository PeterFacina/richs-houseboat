extends RefCounted

const ISLANDS = [
	Vector4(-34.0, 5.0, 28.0, 62.0),
	Vector4(35.0, -37.0, 26.0, 48.0),
	Vector4(-19.0, -86.0, 44.0, 23.0),
]

var noise := FastNoiseLite.new()
var rng := RandomNumberGenerator.new()
static var box_mesh_cache: Dictionary = {}


static func paint(color: Color, roughness := 0.8, metal := 0.0) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = roughness
	material.metallic = metal
	return material


static func mesh_at(parent: Node3D, mesh: Mesh, at: Vector3, material: Material) -> MeshInstance3D:
	var item := MeshInstance3D.new()
	item.mesh = mesh
	item.material_override = material
	parent.add_child(item)
	item.position = at
	return item


static func box_at(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh: BoxMesh
	if OS.get_cmdline_user_args().has("--no-box-mesh-cache"):
		mesh = BoxMesh.new()
		mesh.size = size
	else:
		if not box_mesh_cache.has(size):
			var cached := BoxMesh.new()
			cached.size = size
			box_mesh_cache[size] = cached
		mesh = box_mesh_cache[size]
	return mesh_at(parent, mesh, at, material)


static func beam(parent: Node3D, a: Vector3, b: Vector3, width: float, material: Material) -> MeshInstance3D:
	var length := a.distance_to(b)
	var item := box_at(parent, (a + b) * 0.5, Vector3(width, width, length), material)
	item.basis = Basis.looking_at(b - a, Vector3.FORWARD if absf((b - a).normalized().y) > 0.95 else Vector3.UP)
	return item


static func collider(parent: CollisionObject3D, at: Vector3, size: Vector3) -> void:
	var shape := BoxShape3D.new()
	shape.size = size
	var body := CollisionShape3D.new()
	body.shape = shape
	parent.add_child(body)
	body.position = at


func build(parent: Node3D) -> void:
	noise.seed = 41
	noise.frequency = 0.073
	rng.seed = 191
	light(parent)
	for island in ISLANDS:
		terrain(parent, island)
		forest(parent, island)
	dock(parent)


func light(parent: Node3D) -> void:
	var sky_material := ProceduralSkyMaterial.new()
	sky_material.sky_top_color = Color("#527e9e")
	sky_material.sky_horizon_color = Color("#d5bfa7")
	sky_material.ground_bottom_color = Color("#516d70")
	sky_material.ground_horizon_color = Color("#bdafa0")
	var sky := Sky.new()
	sky.sky_material = sky_material
	var env := Environment.new()
	env.background_mode = Environment.BG_SKY
	env.sky = sky
	env.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	env.ambient_light_color = Color("#bbcbd6")
	env.ambient_light_energy = 0.66
	env.fog_enabled = true
	env.fog_light_color = Color("#adc0c5")
	env.fog_density = 0.004
	env.fog_sky_affect = 0.13
	var world := WorldEnvironment.new()
	world.environment = env
	parent.add_child(world)
	var sun := DirectionalLight3D.new()
	sun.rotation_degrees = Vector3(-34, -42, 0)
	sun.light_color = Color("#ffdfaa")
	sun.light_energy = 0.85
	sun.shadow_enabled = true
	sun.directional_shadow_max_distance = 72
	parent.add_child(sun)


func height(x: float, z: float, island: Vector4) -> float:
	var u := (x - island.x) / island.z
	var v := (z - island.y) / island.w
	var r := Vector2(u, v).length() + 0.085 * noise.get_noise_2d(x, z)
	var shore: float = clampf((1.04 - r) * 2.8, -1.25, 2.5)
	var inland := smoothstep(0.0, 0.7, 1.0 - r)
	var ridge := 14.0 + 4.0 * cos(v * 6.5 + u * 2.0) + 5.5 * noise.get_noise_2d(x * 0.69 + 31, z * 0.69)
	return shore + inland * ridge - 0.16


func terrain(parent: Node3D, island: Vector4) -> void:
	var divisions := 54
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for row in range(divisions + 1):
		var z := island.y + island.w * lerpf(-1.12, 1.12, float(row) / divisions)
		for col in range(divisions + 1):
			var x := island.x + island.z * lerpf(-1.12, 1.12, float(col) / divisions)
			var y := height(x, z, island)
			var normal := Vector3(height(x - 0.4, z, island) - height(x + 0.4, z, island), 0.8,
				height(x, z - 0.4, island) - height(x, z + 0.4, island)).normalized()
			var tint := Color("#a19570").lerp(Color("#65765d"), smoothstep(0.19, 2.0, y))
			tint = tint.lerp(Color("#828578"), smoothstep(0.17, 0.63, 1.0 - normal.y))
			tint = tint.darkened(0.12 + 0.15 * noise.get_noise_2d(x * 2.0, z * 2.0))
			surface.set_color(tint)
			surface.set_normal(normal)
			surface.add_vertex(Vector3(x, y, z))
	var stride := divisions + 1
	for row in range(divisions):
		for col in range(divisions):
			var a := row * stride + col
			for index in [a, a + 1, a + stride, a + 1, a + stride + 1, a + stride]:
				surface.add_index(index)
	var material := ShaderMaterial.new()
	material.shader = preload("res://ground.gdshader")
	var land := mesh_at(parent, surface.commit(), Vector3.ZERO, material)
	land.create_trimesh_collision()


func scatter(parent: Node3D, mesh: Mesh, transforms: Array[Transform3D], material: Material) -> MultiMeshInstance3D:
	var group := MultiMesh.new()
	group.transform_format = MultiMesh.TRANSFORM_3D
	group.mesh = mesh
	group.instance_count = transforms.size()
	for i in transforms.size():
		group.set_instance_transform(i, transforms[i])
	var batch := MultiMeshInstance3D.new()
	batch.multimesh = group
	batch.material_override = material
	parent.add_child(batch)
	return batch


func forest(parent: Node3D, island: Vector4) -> void:
	var stems: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	for i in 345:
		var x := island.x + rng.randf_range(-1.0, 1.0) * island.z
		var z := island.y + rng.randf_range(-1.0, 1.0) * island.w
		var y := height(x, z, island)
		if y < 0.3 or (x > -11 and x < -5 and absf(z - 13.0) < 4.2):
			continue
		if y < 1.5 or rng.randf() < 0.08:
			var scale := rng.randf_range(0.25, 1.45)
			var rock_basis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(scale, scale * 0.47, scale * 0.77))
			stones.append(Transform3D(rock_basis, Vector3(x, y + 0.03, z)))
		elif y < 19.0 and rng.randf() < 0.68:
			var scale := rng.randf_range(0.54, 1.43)
			var axis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3.ONE * scale)
			stems.append(Transform3D(axis, Vector3(x, y + scale * 0.65, z)))
			for layer in 3:
				var width := 1.0 - float(layer) * 0.21
				crowns.append(Transform3D(axis.scaled(Vector3(width, 1, width)),
					Vector3(x, y + (1.34 + layer * 0.57) * scale, z)))
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.088
	trunk.bottom_radius = 0.14
	trunk.height = 1.6
	trunk.radial_segments = 6
	var crown := CylinderMesh.new()
	crown.top_radius = 0.015
	crown.bottom_radius = 0.87
	crown.height = 1.73
	crown.radial_segments = 8
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	scatter(parent, trunk, stems, paint(Color("#624f3d")))
	scatter(parent, crown, crowns, paint(Color("#3d614e")))
	scatter(parent, rock, stones, paint(Color("#7d827b")))


func dock(parent: Node3D) -> void:
	var jetty := StaticBody3D.new()
	parent.add_child(jetty)
	var timber := [paint(Color("#807062")), paint(Color("#9c8771")), paint(Color("#8f7861"))]
	for i in 29:
		box_at(jetty, Vector3(-10.65 + i * 0.326, 0.64, 11.65), Vector3(0.317, 0.16, 3.28), timber[i % 3])
	collider(jetty, Vector3(-6.04, 0.64, 11.65), Vector3(9.45, 0.16, 3.28))
	var posts := paint(Color("#52453c"))
	for x in [-9.9, -7.1, -4.1, -1.65]:
		for z in [10.1, 13.2]:
			box_at(jetty, Vector3(x, 0.16, z), Vector3(0.22, 1.8, 0.22), posts)
			box_at(jetty, Vector3(x, 1.09, z), Vector3(0.25, 0.10, 0.25), timber[1])
