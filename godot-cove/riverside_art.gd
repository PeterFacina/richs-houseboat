extends RefCounted

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const CHUNK := 24.0
const ASSET_DIR := "res://third_party/quaternius_nature/"
const TREE_MODELS := ["CommonTree_1", "CommonTree_2", "Pine_1", "Pine_3"]

var tree_cells := {}
var model_parts := {}


static func near_marina(foot: Vector3, pavilion: Vector3) -> bool:
	return Vector2(foot.x, foot.z).distance_squared_to(Vector2(pavilion.x, pavilion.z)) < 110.0 * 110.0


func add_tree(foot: Vector3, height: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector2i(roundi(foot.x * 4.0), roundi(foot.z * 4.0)))
	var species := random.randi_range(0, TREE_MODELS.size() - 1)
	var cell := Vector3i(floori(foot.x / 65.0), floori(foot.z / 65.0), species)
	if not tree_cells.has(cell):
		var poses: Array[Transform3D] = []
		tree_cells[cell] = poses
	var turn := random.randf_range(0.0, TAU)
	var scale := height / 7.25 * random.randf_range(.89, 1.11)
	var grove: Array[Transform3D] = tree_cells[cell]
	grove.append(Transform3D(Basis(Vector3.UP, turn).scaled_local(Vector3.ONE * scale),
		foot + Vector3.UP * scale * .24))


func build_trees(parent: Node3D) -> void:
	for cell: Vector3i in tree_cells:
		var transforms: Array[Transform3D] = tree_cells[cell]
		scatter_model(parent, TREE_MODELS[cell.z], transforms, "riverside_tree")


func scatter_model(parent: Node3D, name: String, poses: Array[Transform3D], kind := "") -> void:
	if poses.is_empty():
		return
	if not model_parts.has(name):
		var scene := load(ASSET_DIR + name + ".gltf") as PackedScene
		var root := scene.instantiate() as Node3D
		var parts := []
		for found: Node in root.find_children("*", "MeshInstance3D", true, false):
			var part := found as MeshInstance3D
			if part.mesh == null:
				continue
			var local_pose := Transform3D.IDENTITY
			var node: Node3D = part
			while node != root:
				local_pose = node.transform * local_pose
				node = node.get_parent() as Node3D
			var mesh: Mesh = part.mesh
			if kind == "riverside_tree" and mesh is ArrayMesh and mesh.get_surface_count() > 1:
				mesh = mesh.duplicate() as ArrayMesh
				if name == "CommonTree_2":
					var pale_bark := ShaderMaterial.new()
					pale_bark.shader = preload("res://riverside_bark.gdshader")
					(mesh as ArrayMesh).surface_set_material(0, pale_bark)
				var source := mesh.surface_get_material(1) as StandardMaterial3D
				if source != null and source.albedo_texture != null:
					var foliage := ShaderMaterial.new()
					foliage.shader = preload("res://riverside_foliage.gdshader")
					foliage.set_shader_parameter("foliage", source.albedo_texture)
					foliage.set_shader_parameter("tint", source.albedo_color * (Color("#d6dcbb") if name == "CommonTree_2" else Color.WHITE))
					(mesh as ArrayMesh).surface_set_material(1, foliage)
			parts.append([mesh, local_pose, part.name])
		root.free()
		model_parts[name] = parts
	var kit := Kit.new()
	for part: Array in model_parts[name]:
		var mesh: Mesh = part[0]
		var local_pose: Transform3D = part[1]
		var transforms: Array[Transform3D] = []
		for pose: Transform3D in poses:
			transforms.append(pose * local_pose)
		var batch := kit.scatter(parent, mesh, transforms, null)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "riverside_tree" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if kind != "":
			Graphics.batch(batch, kind)


func build_ground_cover(parent: Node3D, pavilion: Vector3, ground: Callable, shore: Callable,
		mowing_routes: Array[Dictionary], docks: RefCounted, clear_route: Callable) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1328151
	var grass_cells := {}
	var shrubs: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var blooms: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	for z in range(-35, 31):
		for x in range(-56, 59):
			if random.randf() > .52:
				continue
			var p := pavilion + Vector3(x * .76 + random.randf_range(-.30, .30), 0,
				z * .76 + random.randf_range(-.30, .30))
			p.y = ground.call(p.x, p.z)
			if p.y < .25 or p.y > 1.30 or shore.call(p) > 0.0 or docks.blocks(p):
				continue
			if clear_route.is_valid() and clear_route.call(Vector2(p.x, p.z)):
				continue
			var local := Vector2(p.x - pavilion.x, p.z - pavilion.z)
			var sand := local - Vector2(-23.1, 5.8)
			var sand_across := sand.dot(Vector2(.962, -.273))
			var sand_depth := sand.dot(Vector2(.273, .962))
			if local.length_squared() < 7.5 * 7.5 or (absf(sand_across) < 19.3 and absf(sand_depth) < 10.0):
				continue
			var in_route := false
			for route: Dictionary in mowing_routes:
				for zone: PackedVector2Array in route.zones:
					if Geometry2D.is_point_in_polygon(Vector2(p.x, p.z), zone):
						in_route = true
						break
				if in_route:
					break
			if in_route:
				continue
			var cell := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
			if not grass_cells.has(cell):
				var tuft: Array[Transform3D] = []
				grass_cells[cell] = tuft
			var scale := Vector3(random.randf_range(.72, 1.22), random.randf_range(.62, 1.45),
				random.randf_range(.72, 1.18))
			grass_cells[cell].append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(scale), p))
			if random.randf() < .012 and local.length_squared() > 12.0 * 12.0:
				shrubs.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3(random.randf_range(.7, 1.3), random.randf_range(.6, 1.0), random.randf_range(.7, 1.3))),
					p + Vector3.UP * .33))
			if random.randf() < .014:
				blooms.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3(.38, random.randf_range(.45, .72), .38)), p + Vector3.UP * .03))
			if random.randf() < .009:
				ferns.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3.ONE * random.randf_range(.13, .20)), p + Vector3.UP * .03))
			if random.randf() < .003:
				rocks.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3(random.randf_range(.25, .55), random.randf_range(.17, .34), random.randf_range(.24, .48))), p))
	var grass_mesh := grass_blades()
	var grass_material := ShaderMaterial.new()
	grass_material.shader = preload("res://riverside_grass.gdshader")
	var kit := Kit.new()
	for transforms: Array in grass_cells.values():
		var typed: Array[Transform3D] = []
		typed.assign(transforms)
		var batch := kit.scatter(parent, grass_mesh, typed, grass_material)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.set_meta("riverside_count", typed.size())
		Graphics.batch(batch, "riverside_grass")
	scatter_model(parent, "Bush_Common", shrubs)
	scatter_model(parent, "Fern_1", ferns)
	for name: String in ["Flower_3_Group", "Flower_4_Group"]:
		var selected: Array[Transform3D] = []
		for i in blooms.size():
			if i % 2 == (0 if name == "Flower_3_Group" else 1):
				selected.append(blooms[i])
		scatter_model(parent, name, selected)
	for variant in 3:
		var selected: Array[Transform3D] = []
		for i in rocks.size():
			if i % 3 == variant:
				selected.append(rocks[i])
		scatter_model(parent, "Rock_Medium_%d" % (variant + 1), selected)


static func grass_blades() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 7:
		var angle := TAU * float(blade) / 7.0 + float(blade % 3) * .22
		var direction := Vector3(cos(angle), 0, sin(angle))
		var across := direction.cross(Vector3.UP)
		var offset := direction * (.09 + float(blade % 2) * .10)
		var height := .44 + float((blade * 7) % 5) * .065
		var points := [offset, offset + Vector3.UP * height * .48 + direction * .07,
			offset + Vector3.UP * height + direction * .21]
		var widths := [.043, .031, .002]
		for section in 2:
			var lower: Vector3 = points[section]
			var upper: Vector3 = points[section + 1]
			for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1),
					Vector2(-1, 1), Vector2(1, 0), Vector2(1, 1)]:
				var which := section + int(corner.y)
				surface.set_normal((direction * .4 + Vector3.UP).normalized())
				surface.set_uv(Vector2(float(blade) / 7.0, float(which) / 2.0))
				surface.add_vertex((lower if corner.y == 0.0 else upper) + across * widths[which] * corner.x)
	return surface.commit()
