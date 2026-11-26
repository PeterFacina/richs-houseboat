extends RefCounted

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const CHUNK := 16.0
const COVER_RADIUS := 178.0
const COVER_SPACING := .55
const PROTOTYPE_RADIUS := 17.0
const PROTOTYPE_DENSITY := 170.0 # Individual blades per square metre.
const PROTOTYPE_PAVING_CLEARANCE := .35 # Covers the maximum wind displacement and blade half-width.
const PROTOTYPE_OFFSET := Vector2(-42.0, 12.0) # Relative to the pavilion.
const ASSET_DIR := "res://third_party/quaternius_nature/"
const TREE_MODELS := ["CommonTree_1", "CommonTree_2", "Pine_1", "Pine_3"]
const TREE_PALETTES := [
	["#4f7450", "#c2a34a", "#d89a49", "#ad6042", "#795746"],
	["#d5ba57", "#e0c96e", "#b98340", "#7b9154"],
	["#365942"],
	["#46624b"],
]

var tree_cells := {}
var deciduous_feet: Array[Vector3] = []
var model_parts := {}


static func near_marina(foot: Vector3, pavilion: Vector3) -> bool:
	return Vector2(foot.x, foot.z).distance_squared_to(Vector2(pavilion.x, pavilion.z)) < 110.0 * 110.0


func add_tree(foot: Vector3, height: float) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector2i(roundi(foot.x * 4.0), roundi(foot.z * 4.0)))
	var roll := random.randf()
	var species := 0 if roll < .28 else (1 if roll < .57 else (2 if roll < .79 else 3))
	var shade := random.randi_range(0, TREE_PALETTES[species].size() - 1)
	var cell := Vector4i(floori(foot.x / 65.0), floori(foot.z / 65.0), species, shade)
	if not tree_cells.has(cell):
		var poses: Array[Transform3D] = []
		tree_cells[cell] = poses
	var turn := random.randf_range(0.0, TAU)
	var scale := height / 7.25 * random.randf_range(.89, 1.11)
	var grove: Array[Transform3D] = tree_cells[cell]
	grove.append(Transform3D(Basis(Vector3.UP, turn).scaled_local(Vector3.ONE * scale),
		foot + Vector3.UP * scale * .24))
	if species < 2:
		deciduous_feet.append(foot)


func build_trees(parent: Node3D) -> void:
	for cell: Vector4i in tree_cells:
		var transforms: Array[Transform3D] = tree_cells[cell]
		scatter_model(parent, TREE_MODELS[cell.z], transforms, "riverside_tree",
			Color(TREE_PALETTES[cell.z][cell.w]))


func scatter_model(parent: Node3D, name: String, poses: Array[Transform3D], kind := "",
		palette := Color.WHITE) -> void:
	if poses.is_empty():
		return
	var cache_key := name + palette.to_html() if kind == "riverside_tree" else name
	if not model_parts.has(cache_key):
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
					foliage.set_shader_parameter("tint", source.albedo_color)
					foliage.set_shader_parameter("palette", palette)
					foliage.set_shader_parameter("recolor", 1.0 if name.begins_with("CommonTree") else 0.0)
					(mesh as ArrayMesh).surface_set_material(1, foliage)
			parts.append([mesh, local_pose, part.name])
		root.free()
		model_parts[cache_key] = parts
	var kit := Kit.new()
	for part: Array in model_parts[cache_key]:
		var mesh: Mesh = part[0]
		var local_pose: Transform3D = part[1]
		var transforms: Array[Transform3D] = []
		for pose: Transform3D in poses:
			transforms.append(pose * local_pose)
		var batch := kit.scatter(parent, mesh, transforms, null)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF if kind == "riverside_tree" else GeometryInstance3D.SHADOW_CASTING_SETTING_ON
		if kind != "":
			Graphics.batch(batch, kind)


static func mask_value(mask: Array, location: Vector2) -> Color:
	var image: Image = mask[0]
	var bounds: Vector4 = mask[1]
	var uv := (location - Vector2(bounds.x, bounds.y)) / Vector2(bounds.z, bounds.w)
	if uv.x < 0.0 or uv.y < 0.0 or uv.x > 1.0 or uv.y > 1.0:
		return Color.BLACK
	return image.get_pixel(clampi(int(uv.x * image.get_width()), 0, image.get_width() - 1),
		clampi(int(uv.y * image.get_height()), 0, image.get_height() - 1))


static func near_approach(masks: Dictionary, location: Vector2) -> bool:
	if not masks.has("approach"):
		return false
	var line: PackedVector2Array = masks.approach
	for index in range(1, line.size()):
		if Geometry2D.get_closest_point_to_segment(location, line[index - 1], line[index]) \
				.distance_squared_to(location) < 30.25:
			return true
	return false


func build_ground_cover(parent: Node3D, pavilion: Vector3, ground: Callable, shore: Callable,
		mowing_routes: Array[Dictionary], docks: RefCounted, clear_route: Callable,
		masks: Dictionary, layout: Dictionary) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 1328151
	var grass_cells := {}
	var shrubs: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var blooms: Array[Transform3D] = []
	var ferns: Array[Transform3D] = []
	var route_zones: Array[Dictionary] = []
	for route: Dictionary in mowing_routes:
		for zone: PackedVector2Array in route.zones:
			var bounds := Rect2(zone[0], Vector2.ZERO)
			for point: Vector2 in zone:
				bounds = bounds.expand(point)
			route_zones.append({"bounds": bounds, "zone": zone})
	var reserved: Array[Dictionary] = []
	for area_name: String in ["buildings", "tennis", "boat_launch"]:
		if not layout.has(area_name):
			continue
		var outlines: Array = layout[area_name] if area_name == "buildings" else [layout[area_name]]
		for outline: Array in outlines:
			var polygon := PackedVector2Array()
			for corner: Array in outline:
				polygon.append(Vector2(corner[0], corner[1]))
			var bounds := Rect2(polygon[0], Vector2.ZERO)
			for point: Vector2 in polygon:
				bounds = bounds.expand(point)
			reserved.append({"bounds": bounds.grow(1.2), "zone": polygon})
	var counts := {"candidates": 0, "eligible": 0, "approach": 0, "masked": 0, "mowing": 0}
	var prototype := OS.get_cmdline_user_args().has("--riverside-grass-prototype")
	if prototype and (not masks.has_all(["approach", "apron", "path"]) or not clear_route.is_valid()):
		push_error("Riverside grass prototype requires all paved-surface exclusions")
		return
	var paving_samples: Array[Vector2] = [Vector2.ZERO]
	if prototype:
		for direction in 8:
			paving_samples.append(Vector2.RIGHT.rotated(TAU * float(direction) / 8.0) * PROTOTYPE_PAVING_CLEARANCE)
	var spacing := 1.0 / sqrt(PROTOTYPE_DENSITY) if prototype else COVER_SPACING
	var radius := PROTOTYPE_RADIUS if prototype else COVER_RADIUS
	var center := pavilion + Vector3(PROTOTYPE_OFFSET.x, 0.0, PROTOTYPE_OFFSET.y) if prototype else pavilion
	var span := ceili(radius / spacing)
	for z in range(-span, span + 1):
		for x in range(-span, span + 1):
			var jitter := spacing * .34 if prototype else .31
			var p := center + Vector3(x * spacing + random.randf_range(-jitter, jitter), 0,
				z * spacing + random.randf_range(-jitter, jitter))
			var local := Vector2(p.x - pavilion.x, p.z - pavilion.z)
			if Vector2(p.x - center.x, p.z - center.z).length_squared() > radius * radius:
				continue
			counts.candidates += 1
			var sand := local - Vector2(-23.1, 5.8)
			var sand_across := sand.dot(Vector2(.962, -.273))
			var sand_depth := sand.dot(Vector2(.273, .962))
			if (absf(local.x) < 5.8 and absf(local.y) < 4.1) or \
					(absf(sand_across) < 19.3 and absf(sand_depth) < 10.0):
				continue
			var place := Vector2(p.x, p.z)
			if near_approach(masks, place):
				counts.approach += 1
				continue
			var paved := false
			for offset: Vector2 in paving_samples:
				var sample := place + offset
				if masks.has("apron") and mask_value(masks.apron, sample).r > .08:
					paved = true
					break
				if masks.has("path"):
					var path := mask_value(masks.path, sample)
					if maxf(maxf(path.r, path.g), path.b) > .11:
						paved = true
						break
			if paved:
				counts.masked += 1
				continue
			var blocked := false
			for area: Dictionary in reserved:
				if area.bounds.has_point(place) and Geometry2D.is_point_in_polygon(place, area.zone):
					blocked = true
					break
			if blocked:
				continue
			for area: Dictionary in route_zones:
				if area.bounds.has_point(place) and Geometry2D.is_point_in_polygon(place, area.zone):
					blocked = true
					break
			if blocked:
				counts.mowing += 1
				continue
			p.y = ground.call(p.x, p.z)
			if p.y < .28 or p.y > 32.0 or shore.call(p) > 0.0 or docks.blocks(p):
				continue
			if clear_route.is_valid() and clear_route.call(place):
				continue
			counts.eligible += 1
			var cell := Vector2i(floori(p.x / CHUNK), floori(p.z / CHUNK))
			if not grass_cells.has(cell):
				var tuft: Array[Transform3D] = []
				grass_cells[cell] = tuft
			var scale := Vector3.ONE if prototype else Vector3(random.randf_range(1.10, 1.48),
				random.randf_range(.65, 1.12), random.randf_range(1.10, 1.48))
			grass_cells[cell].append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(scale), p))
			if prototype:
				continue
			if random.randf() < .0007 and local.length_squared() > 12.0 * 12.0:
				shrubs.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3(random.randf_range(.7, 1.3), random.randf_range(.6, 1.0), random.randf_range(.7, 1.3))),
					p + Vector3.UP * .33))
			if random.randf() < .0009:
				blooms.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3(.38, random.randf_range(.45, .72), .38)), p + Vector3.UP * .03))
			if random.randf() < .0006:
				ferns.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3.ONE * random.randf_range(.13, .20)), p + Vector3.UP * .03))
			if random.randf() < .0002:
				rocks.append(Transform3D(Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(
					Vector3(random.randf_range(.25, .55), random.randf_range(.17, .34), random.randf_range(.24, .48))), p))
	print("RIVERSIDE_COVER prototype=", prototype, " ", counts, " chunks=", grass_cells.size())
	var grass_mesh := godotgrass_blade() if prototype else grass_blades()
	var grass_material := ShaderMaterial.new()
	if prototype:
		grass_material.shader = preload("res://riverside_godotgrass.gdshader")
		var wind_noise := FastNoiseLite.new()
		wind_noise.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
		wind_noise.frequency = .0275
		var wind_texture := NoiseTexture2D.new()
		wind_texture.width = 256
		wind_texture.height = 256
		wind_texture.seamless = true
		wind_texture.noise = wind_noise
		grass_material.set_shader_parameter("wind_noise", wind_texture)
	else:
		grass_material.shader = preload("res://riverside_grass.gdshader")
	var kit := Kit.new()
	for transforms: Array in grass_cells.values():
		var typed: Array[Transform3D] = []
		typed.assign(transforms)
		var batch := kit.scatter(parent, grass_mesh, typed, grass_material)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.set_meta("riverside_count", typed.size())
		Graphics.batch(batch, "riverside_grass")
	if prototype:
		return
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
	build_leaf_litter(parent, pavilion, ground, shore, docks, clear_route, masks, route_zones)


func build_leaf_litter(parent: Node3D, pavilion: Vector3, ground: Callable, shore: Callable,
		docks: RefCounted, clear_route: Callable, masks: Dictionary,
		route_zones: Array[Dictionary]) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 132923
	var cells := {}
	for foot: Vector3 in deciduous_feet:
		if Vector2(foot.x, foot.z).distance_squared_to(Vector2(pavilion.x, pavilion.z)) > COVER_RADIUS * COVER_RADIUS:
			continue
		for piece in 24:
			var offset := Vector2(random.randf_range(-6.8, 6.8), random.randf_range(-6.8, 6.8))
			if offset.length_squared() > 46.0:
				continue
			var at := Vector2(foot.x, foot.z) + offset
			if near_approach(masks, at):
				continue
			if masks.has("apron") and mask_value(masks.apron, at).r > .08:
				continue
			if masks.has("path"):
				var path := mask_value(masks.path, at)
				if maxf(maxf(path.r, path.g), path.b) > .11:
					continue
			var on_lawn := false
			for area: Dictionary in route_zones:
				if area.bounds.has_point(at) and Geometry2D.is_point_in_polygon(at, area.zone):
					on_lawn = true
					break
			if on_lawn:
				continue
			var point := Vector3(at.x, ground.call(at.x, at.y), at.y)
			if point.y < .25 or point.y > 32.0 or shore.call(point) > 0.0 or docks.blocks(point):
				continue
			if clear_route.is_valid() and clear_route.call(at):
				continue
			point.y += .027
			var cell := Vector2i(floori(at.x / CHUNK), floori(at.y / CHUNK))
			if not cells.has(cell):
				var poses: Array[Transform3D] = []
				cells[cell] = poses
			var scale := random.randf_range(.72, 1.25)
			cells[cell].append(Transform3D(Basis(Vector3.UP,
				random.randf_range(0.0, TAU)).scaled_local(Vector3.ONE * scale), point))
	if cells.is_empty():
		return
	var material := ShaderMaterial.new()
	material.shader = preload("res://riverside_leaves.gdshader")
	var mesh := fallen_leaves()
	for poses: Array[Transform3D] in cells.values():
		var batch := Kit.new().scatter(parent, mesh, poses, material)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Graphics.batch(batch, "riverside_leaves")


static func fallen_leaves() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for leaf in 6:
		var angle := float(leaf) * 2.39996
		var center := Vector3(cos(angle), .006 * float(leaf % 3), sin(angle)) * (.12 + .075 * float(leaf % 3))
		var direction := Vector3(cos(angle + .9), 0, sin(angle + .9))
		var across := Vector3(-direction.z, 0, direction.x) * .055
		var front := center + direction * .105 + Vector3.UP * .018
		var back := center - direction * .10
		for vertex: Vector3 in [back, center + across, front, back, front, center - across]:
			surface.set_normal(Vector3.UP)
			surface.set_uv(Vector2(float(leaf) / 6.0, 0))
			surface.add_vertex(vertex)
	return surface.commit()


## Five tapered sections following GodotGrass's 11-vertex high-detail blade.
## Source: https://github.com/2Retr0/GodotGrass (MIT, see third_party/godot_grass/LICENSE).
static func godotgrass_blade() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in 5:
		var low := float(section) / 5.0
		var high := float(section + 1) / 5.0
		var lower_width := .05 * (1.0 - low * low)
		var upper_width := .05 * (1.0 - high * high)
		for point: Vector2 in [Vector2(-1.0, low), Vector2(1.0, low),
				Vector2(-1.0, high), Vector2(-1.0, high), Vector2(1.0, low), Vector2(1.0, high)]:
			var width := upper_width if point.y == high else lower_width
			surface.set_normal(Vector3.FORWARD)
			surface.set_uv(Vector2((point.x + 1.0) * .5, point.y))
			surface.add_vertex(Vector3(point.x * width, point.y * .75, 0.0))
	return surface.commit()


static func grass_blades() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for blade in 5:
		var angle := TAU * float(blade) / 5.0 + float(blade % 3) * .22
		var direction := Vector3(cos(angle), 0, sin(angle))
		var across := direction.cross(Vector3.UP)
		var offset := direction * (.09 + float(blade % 2) * .10)
		var height := .31 + float((blade * 7) % 5) * .047
		var points := [offset, offset + Vector3.UP * height * .48 + direction * .07,
			offset + Vector3.UP * height + direction * .21]
		var widths := [.026, .019, .0015]
		for section in 2:
			var lower: Vector3 = points[section]
			var upper: Vector3 = points[section + 1]
			for corner: Vector2 in [Vector2(-1, 0), Vector2(1, 0), Vector2(-1, 1),
					Vector2(-1, 1), Vector2(1, 0), Vector2(1, 1)]:
				var which := section + int(corner.y)
				surface.set_normal((direction * .4 + Vector3.UP).normalized())
				surface.set_uv(Vector2(float(blade) / 5.0, float(which) / 2.0))
				surface.add_vertex((lower if corner.y == 0.0 else upper) + across * widths[which] * corner.x)
	return surface.commit()
