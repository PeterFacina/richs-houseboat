extends Node3D

const Kit = preload("res://scenery.gd")
const Pines = preload("res://lamure_pines.gd")
const Marina = preload("res://marina_art.gd")

var random := RandomNumberGenerator.new()
var ground_noise := FastNoiseLite.new()
var water: ShaderMaterial


func build() -> void:
	random.seed = 1847
	ground_noise.seed = 231
	ground_noise.frequency = .43
	build_light()
	build_bank()
	build_woods()
	build_grass()
	build_sod()
	water = ShaderMaterial.new()
	water.shader = preload("res://title_water.gdshader")
	var river := PlaneMesh.new()
	river.size = Vector2(240, 220)
	var surface := Kit.mesh_at(self, river, Vector3(24, 0, 35), water)
	surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func set_prop_wash(prop: Vector3, direction: Vector3) -> void:
	water.set_shader_parameter("propeller", Vector2(prop.x, prop.z))
	water.set_shader_parameter("wash_direction", Vector2(direction.x, direction.z))


func build_light() -> void:
	Kit.new().light(self)
	var world := get_child(0) as WorldEnvironment
	var sky := ShaderMaterial.new()
	sky.shader = preload("res://river_sky.gdshader")
	world.environment.sky.sky_material = sky
	world.environment.ambient_light_color = Color("#d2e2e2")
	world.environment.ambient_light_energy = .58
	world.environment.fog_light_color = Color("#afc5cf")
	world.environment.fog_density = .0055
	var sun := get_child(1) as DirectionalLight3D
	sun.rotation_degrees = Vector3(-39, -42, 0)
	sun.light_color = Color("#ffe4bb")
	sun.light_energy = .88
	sun.directional_shadow_max_distance = 48.0


func shore_z(x: float) -> float:
	return -1.30 + .28 * sin(x * .49) + 1.17 * exp(-pow((x + 5.5) / 3.4, 2.0)) - .21 * maxf(x - 8.0, 0.0)


func scar(x: float, z: float) -> float:
	var half_width := lerpf(1.15, .49, smoothstep(-2.0, -4.25, z))
	var edge := absf(x + .12 * sin(z * 1.1)) + ground_noise.get_noise_2d(x * 3.0, z * 3.0) * .34
	return (1.0 - smoothstep(half_width - .22, half_width + .25, edge)) \
		* smoothstep(-4.48, -3.95, z) * (1.0 - smoothstep(-1.55, -.88, z))


func ground_height(x: float, z: float) -> float:
	var inland := shore_z(x) - z
	var texture_height := ground_noise.get_noise_2d(x, z) * .17 * smoothstep(.1, 1.3, absf(inland))
	if inland < 0.0:
		return maxf(-2.6, inland * .49 + texture_height)
	var bluff := 2.22 * smoothstep(.48, 2.55, inland) * exp(-pow((x - .35) / 3.10, 2.0))
	return minf(inland, 6.0) * .30 + .82 * smoothstep(4.0, 12.0, inland) + bluff + texture_height \
		- .22 * scar(x, z) * smoothstep(.05, 1.7, inland)


func build_bank() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 245
	var rows := 121
	var step := .24
	for row in rows:
		var z := -22.0 + step * row
		for column in columns:
			var x := -20.0 + step * column
			var normal := Vector3(ground_height(x - .10, z) - ground_height(x + .10, z), .20,
				ground_height(x, z - .10) - ground_height(x, z + .10)).normalized()
			var sand := 1.0 - smoothstep(.13, .69, shore_z(x) - z)
			surface.set_color(Color(scar(x, z), sand, 0))
			surface.set_normal(normal)
			surface.add_vertex(Vector3(x, ground_height(x, z), z))
	for row in rows - 1:
		for column in columns - 1:
			var corner := row * columns + column
			for index in [corner, corner + 1, corner + columns, corner + 1, corner + columns + 1, corner + columns]:
				surface.add_index(index)
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://title_ground.gdshader")
	for layer: String in ["grass", "sand", "pine-litter"]:
		paint.set_shader_parameter(layer.replace("-", "_") + "_texture", Pines.load_texture(layer + ".jpg"))
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, paint).name = "TornBank"


func build_woods() -> void:
	var pines := Pines.new()
	for index in 53:
		var x := random.randf_range(-22, 37)
		var z := shore_z(x) - random.randf_range(4.8, 16.0)
		# Keep the clearing around Rich and the damaged bank in full sun.
		if x < -16.0 or x > 3.1 or z < -13.5:
			pines.plant(Vector3(x, ground_height(x, z), z), random.randf_range(4.0, 11.5), random)
	pines.build(self)
	# A low wooded reach on the opposite shore keeps the horizon open over the river.
	var distant_pines := Pines.new()
	var far_bank := SurfaceTool.new()
	far_bank.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 37:
		var z := -94.0 + index * 4.0
		var a := distant_bank(z)
		var b := distant_bank(z + 4.0)
		for point in [a - Vector3(2, a.y + .35, 0), a, b, a - Vector3(2, a.y + .35, 0), b, b - Vector3(2, b.y + .35, 0)]:
			far_bank.add_vertex(point)
		for offset: float in [.8, 4.4]:
			var foot := a + Vector3(offset, -.17, random.randf_range(-1.8, 1.8))
			distant_pines.plant(foot, random.randf_range(4.0, 9.4), random)
	far_bank.generate_normals()
	var distant_paint := Kit.paint(Color("#54634a"))
	distant_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	Kit.mesh_at(self, far_bank.commit(), Vector3.ZERO, distant_paint)
	var woods := Node3D.new()
	woods.name = "OppositeShorePines"
	add_child(woods)
	distant_pines.build(woods)
	for tree_batch: GeometryInstance3D in woods.get_children():
		tree_batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func distant_bank(z: float) -> Vector3:
	return Vector3(70.0 + 5.0 * sin(z * .044) + 3.5 * sin(z * .078),
		1.05 + .45 * sin(z * .13) + .42 * cos(z * .05), z)


func build_grass() -> void:
	var tufts: Array[Transform3D] = []
	for index in 1650:
		var x := random.randf_range(-18, 18)
		var z := shore_z(x) - random.randf_range(.34, 9.0)
		if scar(x, z) > .38:
			continue
		var scale_factor := random.randf_range(.13, .45)
		var pose := Basis(Vector3.UP, random.randf() * TAU).scaled(Vector3.ONE * scale_factor)
		tufts.append(Transform3D(pose, Vector3(x, ground_height(x, z) - .018, z)))
	var grass_paint := ShaderMaterial.new()
	grass_paint.shader = preload("res://river_reeds.gdshader")
	var batch := Kit.new().scatter(self, Marina.new().reed_mesh(random), tufts, grass_paint)
	batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_sod() -> void:
	var earth := Kit.paint(Color("#745039"))
	var turf := Kit.paint(Color("#71873d"))
	var clod := CylinderMesh.new()
	clod.radial_segments = 6
	clod.rings = 0
	clod.height = 1.0
	clod.top_radius = .77
	clod.bottom_radius = .49
	for index in 26:
		var side := -1.0 if index % 2 == 0 else 1.0
		var z := random.randf_range(-4.42, -1.26)
		var x := side * (lerpf(1.02, .47, smoothstep(-2.0, -4.25, z)) + random.randf_range(-.11, .36))
		var at := Vector3(x, ground_height(x, z) + .045, z)
		var span := random.randf_range(.06, .19)
		var height := random.randf_range(.055, .17)
		var clump := Kit.mesh_at(self, clod, at, earth)
		var angle := Basis.from_euler(Vector3(random.randf_range(-.5, .5), random.randf() * TAU, side * .34))
		clump.basis = angle.scaled_local(Vector3(span, height, span * 1.35))
		var sod := Kit.mesh_at(self, clod, at + angle.y * height * .42, turf)
		sod.basis = angle.scaled_local(Vector3(span * .90, height * .30, span * 1.22))
