extends Node3D

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const Marina = preload("res://marina_art.gd")
const LamureBeach = preload("res://lamure_beach.gd")
const LamurePines = preload("res://lamure_pines.gd")
const RiverbankPark = preload("res://riverbank_park.gd")
const BrockhouseWay = preload("res://brockhouse_way.gd")
const Swisha = preload("res://swisha_dam.gd")
const Town = preload("res://deep_river_buildings.gd")
const Waves = preload("res://swell.gd")
const Landings = preload("res://river_campaign_data.gd")
const BASE := "res://ottawa/"
const TILE := 44

class TerrainPatch:
	var area: Rect2
	var grid: Vector2i
	var cells: Rect2i
	var spacing: float
	var heights: PackedFloat32Array
	var shore_mask: PackedByteArray
	var shore_unit: float

	func _init(definition: Dictionary, prefix: String) -> void:
		spacing = definition.step
		shore_unit = definition.shore_unit
		grid = Vector2i(int(definition.grid[0]), int(definition.grid[1]))
		area = Rect2(Vector2(definition.origin[0], definition.origin[1]), Vector2(grid - Vector2i.ONE) * spacing)
		var bounds: Array = definition.coarse_limits
		cells = Rect2i(int(bounds[0]), int(bounds[1]), int(bounds[2] - bounds[0]), int(bounds[3] - bounds[1]))
		heights = FileAccess.get_file_as_bytes(prefix + "_height.bin").to_float32_array()
		shore_mask = FileAccess.get_file_as_bytes(prefix + "_shore.bin")

	func height_at(col: int, row: int) -> float:
		return heights[clampi(row, 0, grid.y - 1) * grid.x + clampi(col, 0, grid.x - 1)]

	func clearance(point: Vector2) -> float:
		var local := (point - area.position) / spacing
		return sample_mask(shore_mask, grid, local) * shore_unit

	static func sample_mask(mask: PackedByteArray, grid: Vector2i, point: Vector2) -> float:
		var cell := Vector2i(floori(point.x), floori(point.y))
		var next := (cell + Vector2i.ONE).min(grid - Vector2i.ONE)
		var blend := point - Vector2(cell)
		return lerpf(lerpf(mask[cell.y * grid.x + cell.x], mask[cell.y * grid.x + next.x], blend.x),
			lerpf(mask[next.y * grid.x + cell.x], mask[next.y * grid.x + next.x], blend.x), blend.y)

var meta: Dictionary
var elevation: PackedFloat32Array
var shore: PackedByteArray
var step: float
var shore_step: float
var shore_unit: float
var dam_center: Vector3
var dam_clearance_squared: float
var columns: int
var rows: int
var shore_columns: int
var shore_rows: int
var extent: Vector2
var near_surface: MeshInstance3D
var near_water: ShaderMaterial
var far_water: ShaderMaterial
var headpond_water: ShaderMaterial
var regional_water: Image
var station_water: ImageTexture
var sun_direction: Vector3
var landscape_light: DirectionalLight3D
var landscape_environment: Environment
var sky_paint: ShaderMaterial
var last_evening := -1.0
var fog_scale := 1.0
var marina_patch: TerrainPatch
var lamure_patch: TerrainPatch
var swisha_patch: TerrainPatch
var detail_patches: Array[TerrainPatch]
var riverbed: ImageTexture
var chart_texture: ImageTexture
var day_sky: ImageTexture
var marina_paving: ImageTexture
var asphalt_scan: ImageTexture
var concrete_scan: ImageTexture
var wood_scan: ImageTexture
var windows: ShaderMaterial
var canopy_area := Rect2()
var waterfront := Marina.new()
var lamure := LamureBeach.new()


func build() -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(BASE + "river.json"))
	elevation = FileAccess.get_file_as_bytes(BASE + "height.bin").to_float32_array()
	shore = FileAccess.get_file_as_bytes(BASE + "shore.bin")
	columns = int(meta.columns)
	rows = int(meta.rows)
	shore_columns = int(meta.shore_columns)
	shore_rows = int(meta.shore_rows)
	step = float(meta.step)
	shore_step = float(meta.shore_step)
	shore_unit = float(meta.shore_unit)
	dam_center = measured("dam")
	dam_clearance_squared = pow(float(meta.dam_exclusion), 2.0)
	extent = Vector2(columns - 1, rows - 1) * step
	marina_patch = TerrainPatch.new(meta.marina, BASE + "marina")
	swisha_patch = TerrainPatch.new(meta.swisha, BASE + "swisha")
	detail_patches = [marina_patch, swisha_patch]
	if meta.has("lamure"):
		lamure_patch = TerrainPatch.new(meta.lamure, BASE + "lamure")
		detail_patches.append(lamure_patch)
		meta.places.append({"name": "Lamure Beach", "point": meta.lamure.point})
	regional_water = Image.load_from_file(BASE + "shoals.png")
	chart_texture = ImageTexture.create_from_image(Image.load_from_file(BASE + "chart.png"))
	station_water = ImageTexture.create_from_image(Image.load_from_file(BASE + "swisha_shoals.png"))
	Kit.new().light(self)
	var world: WorldEnvironment = get_child(0)
	sky_paint = ShaderMaterial.new()
	sky_paint.shader = preload("res://river_sky.gdshader")
	day_sky = scanned_surface("day_sky")
	bind_day_sky(sky_paint)
	world.environment.sky.sky_material = sky_paint
	world.environment.fog_density = 0.000135
	world.environment.fog_light_color = Color("#95abb4")
	world.environment.ambient_light_color = Color("#dce3eb")
	world.environment.ambient_light_energy = 0.41
	var sun: DirectionalLight3D = get_child(1)
	landscape_light = sun
	landscape_environment = world.environment
	sun.light_color = Color("#fff6ed")
	sun.light_energy = 0.68
	sun.rotation_degrees = Vector3(-48.0, -42.0, 0)
	sun.directional_shadow_max_distance = 230
	sun_direction = sun.global_basis.z
	var ground := ShaderMaterial.new()
	ground.shader = preload("res://ground.gdshader")
	var gravel := Image.load_from_file(BASE + "riverbed_cobbles.png")
	gravel.generate_mipmaps()
	riverbed = ImageTexture.create_from_image(gravel)
	ground.set_shader_parameter("riverbank", riverbed)
	asphalt_scan = scanned_surface("asphalt")
	concrete_scan = scanned_surface("concrete")
	wood_scan = scanned_surface("wood")
	ground.set_shader_parameter("asphalt_scan", asphalt_scan)
	ground.set_shader_parameter("concrete_scan", concrete_scan)
	ground.set_shader_parameter("grass_scan", scanned_surface("grass"))
	ground.set_shader_parameter("grass_normal", scanned_surface("grass_normal", true))
	var town_ground: Array = meta.get("town_ground", [])
	var town_canopy := PackedFloat32Array()
	if not town_ground.is_empty():
		var aerial := Image.load_from_file(BASE + "deep_river_ground.png")
		aerial.generate_mipmaps()
		ground.set_shader_parameter("town_ground", ImageTexture.create_from_image(aerial))
		ground.set_shader_parameter("town_bounds", Vector4(town_ground[0], town_ground[1], town_ground[2], town_ground[3]))
		var path := BASE + "deep_river_canopy.bin"
		if FileAccess.file_exists(path):
			town_canopy = FileAccess.get_file_as_bytes(path).to_float32_array()
		if not town_canopy.is_empty():
			canopy_area = Rect2(town_ground[0], town_ground[1], town_ground[2], town_ground[3])
	var paving: Array = meta.downtown_paving
	var paving_texture := ImageTexture.create_from_image(Image.load_from_file(BASE + "deep_river_paving.png"))
	ground.set_shader_parameter("town_paving", paving_texture)
	ground.set_shader_parameter("paving_bounds", Vector4(paving[0], paving[1], paving[2] - paving[0], paving[3] - paving[1]))
	ground.set_shader_parameter("station_paving", station_water)
	ground.set_shader_parameter("station_bounds", patch_bounds(swisha_patch))
	if meta.has("brockhouse"):
		var campus := Image.load_from_file(BASE + "brockhouse_surface.png")
		campus.generate_mipmaps()
		var span: Array = meta.brockhouse.bounds
		ground.set_shader_parameter("brockhouse_surface", ImageTexture.create_from_image(campus))
		ground.set_shader_parameter("brockhouse_bounds", Vector4(span[0], span[1], span[2], span[3]))
	var apron := BASE + "marina_paving.png"
	if FileAccess.file_exists(apron):
		marina_paving = ImageTexture.create_from_image(Image.load_from_file(apron))
		bind_marina_paving(ground)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7268
	var tree := CylinderMesh.new()
	tree.top_radius = 0.05
	tree.bottom_radius = 0.88
	tree.height = 1.9
	tree.radial_segments = 6
	var trunk := CylinderMesh.new()
	trunk.top_radius = 0.09
	trunk.bottom_radius = 0.14
	trunk.height = 1.05
	trunk.radial_segments = 5
	var needles := Kit.paint(Color("#315343"))
	var bark := Kit.paint(Color("#674d3a"))
	for row in range(0, rows - 1, TILE):
		for col in range(0, columns - 1, TILE):
			tile(col, row, ground)
			trees_for_tile(col, row, rng, tree, trunk, needles, bark)
	for detail in detail_patches:
		for row in range(0, detail.grid.y - 1, TILE):
			for col in range(0, detail.grid.x - 1, TILE):
				tile(col, row, ground, detail)
	build_water()
	build_town()
	build_landmarks()
	var park := RiverbankPark.new()
	if meta.has("riverbank"):
		park.prepare(meta.riverbank)
		var surface := Image.load_from_file(BASE + "riverbank_surface.png")
		surface.generate_mipmaps()
		ground.set_shader_parameter("riverbank_path_mask", ImageTexture.create_from_image(surface))
		ground.set_shader_parameter("riverbank_path_bounds", Vector4(
			park.bounds.position.x, park.bounds.position.y, park.bounds.size.x, park.bounds.size.y))
	waterfront.build(self, meta.marina, ground_height, wet_clearance, wood_scan, concrete_scan, riverbed,
		park.near_trail, meta.get("riverbank", {}).get("pier_approach", []))
	for material: ShaderMaterial in [near_water, far_water]:
		waterfront.wharf.launch.bind_water(material, concrete_scan)
	if lamure_patch != null:
		build_lamure(ground)
	var pines := LamurePines.new()
	waterfront.build_canopy(self, town_canopy, marina_patch.area, wet_clearance,
		func(foot: Vector3, height: float) -> bool:
			return park.owns_tree(foot) or (lamure_patch != null and pines.place_from_survey(foot, height)))
	if meta.has("riverbank"):
		park.build(self, town_canopy, waterfront, pines, ground_height, wet_clearance, riverbed)
	if meta.has("brockhouse"):
		BrockhouseWay.new().build(self, meta.brockhouse, ground_height, waterfront, pines)
	pines.build(self)
	plant_pine_reach(waterfront)


func build_lamure(ground: ShaderMaterial) -> void:
	var coverage := ImageTexture.create_from_image(Image.load_from_file(BASE + "lamure_surface.png"))
	var shoals := ImageTexture.create_from_image(Image.load_from_file(BASE + "lamure_shoals.png"))
	var sand := scanned_surface("sand")
	ground.set_shader_parameter("lamure_litter", scanned_surface("pine-litter"))
	var paint: Array = meta.lamure.paint_bounds
	var bounds := Vector4(paint[0], paint[1], paint[2], paint[3])
	for material: ShaderMaterial in [ground, near_water, far_water]:
		material.set_shader_parameter("lamure_surface", coverage)
		material.set_shader_parameter("lamure_sand", sand)
		material.set_shader_parameter("lamure_paint_bounds", bounds)
	for material: ShaderMaterial in [near_water, far_water]:
		material.set_shader_parameter("lamure_shoals", shoals)
		material.set_shader_parameter("lamure_bounds", patch_bounds(lamure_patch))
		material.set_shader_parameter("lamure_shore_unit", lamure_patch.shore_unit)
	lamure.build(self, meta.lamure, ground_height, waterfront)


static func scanned_surface(name: String, normal := false) -> ImageTexture:
	var image := Image.load_from_file(BASE + "materials/" + name + ".jpg")
	image.generate_mipmaps(normal)
	return ImageTexture.create_from_image(image)


func bind_day_sky(material: ShaderMaterial) -> void:
	material.set_shader_parameter("day_sky", day_sky)
	material.set_shader_parameter("has_day_sky", true)


func bind_marina_paving(material: ShaderMaterial) -> void:
	if marina_paving != null:
		material.set_shader_parameter("marina_paving", marina_paving)
		material.set_shader_parameter("marina_paving_bounds", patch_bounds(marina_patch))


func point(index: int) -> Vector3:
	var p: Array = meta.places[index].point
	return Vector3(p[0], 0, p[1])


func measured(name: String) -> Vector3:
	var p: Array = meta[name]
	return Vector3(p[0], 0, p[1])


func wet_clearance(world: Vector3) -> float:
	var point := Vector2(world.x, world.z)
	for patch in detail_patches:
		if patch.area.has_point(point):
			return patch.clearance(point)
	var local := point / shore_step
	if not Rect2(Vector2.ZERO, Vector2(shore_columns - 1, shore_rows - 1)).has_point(local):
		return 0.0
	return TerrainPatch.sample_mask(shore, Vector2i(shore_columns, shore_rows), local) * shore_unit


func depth_at(point: Vector3) -> float:
	if wet_clearance(point) <= .28:
		return 0.0
	var bed := maxf(ground_height(point.x, point.z), waterfront.wharf.launch.floor_at(point))
	return maxf(0.0, -bed)


func downstream(point: Vector3, time: float) -> Vector3:
	var open := smoothstep(2.0, 95.0, wet_clearance(point))
	var fast := 1.0 - smoothstep(240.0, 860.0, point.distance_to(dam_center))
	var stream := .11 + .30 * open + .90 * fast
	return Vector3(.84, 0, .543) * stream + Vector3(cos(point.z * .017 + time * .52), 0, sin(time * .41)) * .047


func wave_height(point: Vector3, time: float) -> float:
	return Waves.river_height(point.x, point.z, time) * lerpf(.24, 1.0, smoothstep(0.0, 57.0, wet_clearance(point)))


func can_sail(world: Vector3, minimum_depth := .88) -> bool:
	return world.distance_squared_to(dam_center) >= dam_clearance_squared and depth_at(world) >= minimum_depth \
		and not waterfront.wharf.blocks_water(world) and not waterfront.fleet.blocks(world) and not lamure.blocks_swim_area(world)


func can_fish(point: Vector3) -> bool:
	return point.distance_squared_to(dam_center) >= dam_clearance_squared and depth_at(point) >= .45 \
		and not waterfront.wharf.blocks_water(point) and not waterfront.fleet.blocks(point) and not lamure.blocks_swim_area(point)


func sample(col: int, row: int) -> float:
	return elevation[clampi(row, 0, rows - 1) * columns + clampi(col, 0, columns - 1)]


func ground_height(x: float, z: float) -> float:
	var point := Vector2(x, z)
	var detail: TerrainPatch
	for patch in detail_patches:
		if patch.area.has_point(point):
			detail = patch
			break
	var grid := (point - detail.area.position) / detail.spacing if detail != null else point / step
	var grid_x := grid.x
	var grid_z := grid.y
	var col := floori(grid_x)
	var row := floori(grid_z)
	var a := sample_grid(col, row, detail)
	var b := sample_grid(col + 1, row, detail)
	var c := sample_grid(col, row + 1, detail)
	var d := sample_grid(col + 1, row + 1, detail)
	var u := grid_x - col
	var v := grid_z - row
	if u + v <= 1.0:
		return a + (b - a) * u + (c - a) * v
	return d + (c - d) * (1 - u) + (b - d) * (1 - v)


func sample_grid(col: int, row: int, detail: TerrainPatch) -> float:
	return detail.height_at(col, row) if detail != null else sample(col, row)


func tile(col_start: int, row_start: int, material: Material, detail: TerrainPatch = null) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var grid_width := detail.grid.x if detail != null else columns
	var grid_height := detail.grid.y if detail != null else rows
	var spacing := detail.spacing if detail != null else step
	var origin := detail.area.position if detail != null else Vector2.ZERO
	var width := mini(TILE, grid_width - 1 - col_start)
	var depth := mini(TILE, grid_height - 1 - row_start)
	var replacements: Array[Rect2i] = []
	if detail == null:
		var bounds := Rect2i(col_start, row_start, width, depth)
		for patch in detail_patches:
			if patch.cells.encloses(bounds):
				return
			if patch.cells.intersects(bounds):
				replacements.append(patch.cells)
	for row in range(row_start, row_start + depth + 1):
		for col in range(col_start, col_start + width + 1):
			var height := sample_grid(col, row, detail)
			var normal := Vector3(sample_grid(col - 1, row, detail) - sample_grid(col + 1, row, detail), spacing * 2,
				sample_grid(col, row - 1, detail) - sample_grid(col, row + 1, detail)).normalized()
			var forest := Color("#45583e").lerp(Color("#56634b"), smoothstep(55, 286, height))
			var vegetation := smoothstep(0.25, 2.2, height) if detail != null else smoothstep(1.4, 10.0, height)
			var tint := Color("#948261").lerp(forest, vegetation)
			tint = tint.lerp(Color("#777566"), smoothstep(0.07, 0.31, 1.0 - normal.y))
			surface.set_color(tint)
			surface.set_normal(normal)
			surface.add_vertex(Vector3(origin.x + col * spacing, height, origin.y + row * spacing))
	var stride := width + 1
	for row in depth:
		for col in width:
			if not replacements.is_empty():
				var cell := Vector2i(col_start + col, row_start + row)
				if replacements.any(func(bounds: Rect2i) -> bool: return bounds.has_point(cell)):
					continue
			var i := row * stride + col
			for index in [i, i + 1, i + stride, i + 1, i + stride + 1, i + stride]:
				surface.add_index(index)
	var land := Kit.mesh_at(self, surface.commit(), Vector3.ZERO, material)
	land.create_trimesh_collision()


func trees_for_tile(col: int, row: int, rng: RandomNumberGenerator, tree: Mesh, trunk: Mesh,
		needles: Material, bark: Material) -> void:
	var groves := {}
	var city := point(1)
	var tile_center := Vector3((col + TILE * 0.5) * step, 0, (row + TILE * 0.5) * step)
	var distance_from_city := Vector3(col * step, 0, row * step).distance_to(city)
	var near_dam := tile_center.distance_to(dam_center) < 2150.0
	var count := 1500 if near_dam or distance_from_city < 4300.0 else 550
	for _i in count:
		var x := rng.randf_range(col, mini(col + TILE, columns - 1)) * step
		var z := rng.randf_range(row, mini(row + TILE, rows - 1)) * step
		if Vector2(x, z).distance_squared_to(Landings.SITES[1].plot) < 96.0 * 96.0:
			continue
		var location := Vector2(x, z)
		if swisha_patch.area.has_point(location) or marina_patch.area.has_point(location) or canopy_area.has_point(location):
			continue
		if wet_clearance(Vector3(x, 0, z)) > 0.0:
			continue
		if regional_water.get_pixel(roundi(x / shore_step), roundi(z / shore_step)).g > 0.0:
			continue
		var y := ground_height(x, z)
		if y < 1.1 or y > 520 or Vector3(x, 0, z).distance_squared_to(city) < 420 * 420:
			continue
		var spread := rng.randf_range(2.5, 5.8)
		var axis := Basis(Vector3.UP, rng.randf_range(0, TAU)).scaled(Vector3(spread, spread * 1.18, spread))
		var cell := Vector2i(floori(x / 550.0), floori(z / 550.0))
		if not groves.has(cell):
			var new_stems: Array[Transform3D] = []
			var new_crowns: Array[Transform3D] = []
			groves[cell] = [new_stems, new_crowns]
		var stems: Array[Transform3D] = groves[cell][0]
		var crowns: Array[Transform3D] = groves[cell][1]
		stems.append(Transform3D(axis, Vector3(x, y + 0.43 * spread, z)))
		crowns.append(Transform3D(axis, Vector3(x, y + 1.24 * spread, z)))
		crowns.append(Transform3D(axis.scaled(Vector3(0.72, 0.95, 0.72)), Vector3(x, y + 2.12 * spread, z)))
	var kit := Kit.new()
	for grove: Array in groves.values():
		Graphics.batch(kit.scatter(self, tree, grove[1], needles), "regional_crown")
		Graphics.batch(kit.scatter(self, trunk, grove[0], bark), "regional_trunk")


func plant_pine_reach(trees: Marina) -> void:
	var origin: Vector2 = Landings.SITES[1].plot
	var grove_positions := [
		[Vector2(-78, 21), Vector2(-34, 10), Vector2(-17, 24), Vector2(-12, 78), Vector2(-83, 82)],
		[Vector2(-19, 32), Vector2(47, 21), Vector2(75, 49), Vector2(77, 94), Vector2(-30, 94)],
		[Vector2(42, -4), Vector2(70, 10), Vector2(94, 25), Vector2(87, 60), Vector2(57, 44)],
	]
	var woodland := []
	for grove: Array in grove_positions:
		var polygon := []
		for point: Vector2 in grove:
			polygon.append([origin.x + point.x, origin.y + point.y])
		woodland.append(polygon)
	trees.build_trees(self, woodland, [])


func build_water() -> void:
	var shore_texture := ImageTexture.create_from_image(regional_water)
	var marina_texture := ImageTexture.create_from_image(Image.load_from_file(BASE + "marina_shoals.png"))
	near_water = make_water(shore_texture, marina_texture, false)
	far_water = make_water(shore_texture, marina_texture, true)
	var ocean := PlaneMesh.new()
	ocean.size = extent
	var distant := Kit.mesh_at(self, ocean, Vector3(extent.x / 2, -0.03, extent.y / 2), far_water)
	distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var surface := PlaneMesh.new()
	surface.size = Vector2(230, 230)
	surface.subdivide_width = 180
	surface.subdivide_depth = 180
	near_surface = Kit.mesh_at(self, surface, Vector3.ZERO, near_water)
	near_surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	near_surface.custom_aabb = AABB(Vector3(-115, -1, -115), Vector3(230, 2, 230))
	headpond_water = make_water(shore_texture, marina_texture, false)
	headpond_water.set_shader_parameter("headpond", true)
	var bounds: Array = meta.swisha.head_bounds
	var reservoir := PlaneMesh.new()
	reservoir.size = Vector2(bounds[2] - bounds[0], bounds[3] - bounds[1])
	reservoir.subdivide_width = 96
	reservoir.subdivide_depth = 64
	var lake_center := Vector3((bounds[0] + bounds[2]) * 0.5, meta.swisha.head_level, (bounds[1] + bounds[3]) * 0.5)
	var lake := Kit.mesh_at(self, reservoir, lake_center, headpond_water)
	lake.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func make_water(texture: Texture2D, local_shore: Texture2D, distant: bool) -> ShaderMaterial:
	var shader := ShaderMaterial.new()
	shader.shader = preload("res://water.gdshader")
	bind_day_sky(shader)
	shader.set_shader_parameter("mapped", true)
	shader.set_shader_parameter("distant", distant)
	shader.set_shader_parameter("sun_direction", sun_direction)
	shader.set_shader_parameter("map_size", extent)
	shader.set_shader_parameter("riverbed", riverbed)
	shader.set_shader_parameter("reflect_shore", chart_texture)
	shader.set_shader_parameter("shoals", texture)
	shader.set_shader_parameter("marina_shoals", local_shore)
	shader.set_shader_parameter("swisha_shoals", station_water)
	shader.set_shader_parameter("marina_bounds", patch_bounds(marina_patch))
	shader.set_shader_parameter("swisha_bounds", patch_bounds(swisha_patch))
	shader.set_shader_parameter("shore_units", Vector3(shore_unit, marina_patch.shore_unit, swisha_patch.shore_unit))
	var ends: Array = meta.swisha.powerhouse
	var a := Vector2(ends[0][0], ends[0][1])
	var b := Vector2(ends[1][0], ends[1][1])
	var axis := (b - a).normalized()
	var flow := Vector2(-axis.y, axis.x)
	var origin := (a + b) * 0.5
	shader.set_shader_parameter("outfall", Vector4(origin.x, origin.y, flow.x, flow.y))
	shader.set_shader_parameter("outfall_width", a.distance_to(b))
	return shader


func patch_bounds(patch: TerrainPatch) -> Vector4:
	return Vector4(patch.area.position.x, patch.area.position.y, patch.area.size.x, patch.area.size.y)


func set_water_grid(subdivisions: int) -> void:
	var surface := near_surface.mesh as PlaneMesh
	surface.subdivide_width = subdivisions
	surface.subdivide_depth = subdivisions


func update_water(center: Vector3, clock: float) -> void:
	var p := Vector2(center.x, center.z)
	near_surface.position = Vector3(center.x, 0, center.z)
	for mat in [near_water, far_water, headpond_water]:
		mat.set_shader_parameter("clock", clock)
		mat.set_shader_parameter("center", p)
	waterfront.wharf.update_light(clock, last_evening)
	waterfront.fleet.update(center, clock, wave_height)
	lamure.update_float(center, clock, wave_height)


func set_wake(stern: Vector3, behind: Vector3, speed: float, thrust: float, prop_heading: Vector3) -> void:
	near_water.set_shader_parameter("boat_wake", Vector4(stern.x, stern.z, speed, thrust))
	near_water.set_shader_parameter("wake_heading", Vector2(behind.x, behind.z))
	near_water.set_shader_parameter("prop_heading", Vector2(prop_heading.x, prop_heading.z))


func set_evening(amount: float) -> void:
	if is_equal_approx(amount, last_evening):
		return
	last_evening = amount
	landscape_light.rotation_degrees = Vector3(lerpf(-48.0, -7.5, amount), lerpf(-42.0, -34.0, amount), 0)
	landscape_light.light_color = Color("#fff6ed").lerp(Color("#ffbe87"), amount)
	landscape_light.light_energy = lerpf(.68, .49, amount)
	landscape_environment.ambient_light_color = Color("#dce3eb").lerp(Color("#a3b8eb"), amount)
	landscape_environment.ambient_light_energy = lerpf(.41, .54, amount)
	landscape_environment.fog_light_color = Color("#95abb4").lerp(Color("#7687a5"), amount)
	landscape_environment.fog_density = lerpf(.000135, .00058, amount) * fog_scale
	sun_direction = landscape_light.global_basis.z
	sky_paint.set_shader_parameter("evening", amount)
	windows.set_shader_parameter("evening", amount)
	for material: ShaderMaterial in [near_water, far_water, headpond_water]:
		material.set_shader_parameter("evening", amount)
		material.set_shader_parameter("sun_direction", sun_direction)


func set_bow_light(at: Vector3, direction: Vector3, strength: float) -> void:
	near_water.set_shader_parameter("bow_light", Vector4(at.x, at.y, at.z, strength))
	near_water.set_shader_parameter("bow_direction", direction)


func set_fish_shadow(point: Vector3, heading: Vector3, depth: float, length: float) -> void:
	near_water.set_shader_parameter("hooked_fish", Vector4(point.x, point.z, depth, length))
	near_water.set_shader_parameter("fish_heading", Vector2(heading.x, heading.z).normalized())


func clear_fish_shadow() -> void:
	near_water.set_shader_parameter("hooked_fish", Vector4.ZERO)


func set_surface_slick(data: Vector4) -> void:
	near_water.set_shader_parameter("surface_slick", data)


func build_town() -> void:
	var tile_image := Image.load_from_file(BASE + "deep_river_roofs.png")
	tile_image.generate_mipmaps()
	var textures := ImageTexture.create_from_image(tile_image)
	var buildings := Town.new()
	var footprints: Array = meta.buildings
	if lamure_patch != null:
		var shelter := Vector2(meta.lamure.shelter[0], meta.lamure.shelter[1])
		footprints = footprints.filter(func(building: Dictionary):
			var box: Array = building.box
			return not Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1]).has_point(shelter))
	buildings.build(self, footprints, textures, ground_height, meta.distance_scale,
		scanned_surface("brick"), asphalt_scan, wood_scan)
	windows = buildings.windows
	bind_day_sky(windows)
	var road := SurfaceTool.new()
	road.begin(Mesh.PRIMITIVE_TRIANGLES)
	road.set_normal(Vector3.UP)
	for line: Array in meta.streets:
		add_street(road, line)
	var material := ShaderMaterial.new()
	material.shader = preload("res://town_street.gdshader")
	material.set_shader_parameter("asphalt_scan", asphalt_scan)
	material.set_shader_parameter("concrete_scan", concrete_scan)
	if meta.has("brockhouse"):
		var segment: Array = meta.brockhouse.road_segment
		material.set_shader_parameter("brockhouse_road", Vector4(segment[0], segment[1], segment[2], segment[3]))
	bind_marina_paving(material)
	Kit.mesh_at(self, road.commit(), Vector3.ZERO, material)


func add_street(surface: SurfaceTool, line: Array) -> void:
	var centers := PackedVector2Array()
	for pair: Array in line:
		var at := Vector2(pair[0], pair[1])
		if centers.is_empty() or at.distance_squared_to(centers[-1]) > .01:
			centers.append(at)
	if centers.size() < 2:
		return
	var edges := PackedVector2Array()
	for i in centers.size():
		var incoming := (centers[i] - centers[maxi(0, i - 1)]).orthogonal().normalized()
		var outgoing := (centers[mini(i + 1, centers.size() - 1)] - centers[i]).orthogonal().normalized()
		var across := (incoming + outgoing).normalized()
		var alignment := maxf(absf(across.dot(incoming + outgoing)) * .5, .72)
		edges.append(across * (3.40 / alignment) if i > 0 and i < centers.size() - 1 else across * 3.40)
	for i in range(1, centers.size()):
		var a := centers[i - 1]
		var b := centers[i]
		var near_marina := marina_patch.area.intersects(Rect2(a, Vector2.ZERO).expand(b).grow(4.5))
		var spacing := .92 if near_marina else 6.0
		var cross_sections := 5 if near_marina else 2
		var sections := maxi(1, ceili(a.distance_to(b) / spacing))
		for section in sections:
			var start := float(section) / sections
			var finish := float(section + 1) / sections
			var left := a.lerp(b, start) - edges[i - 1].lerp(edges[i], start)
			var right := a.lerp(b, start) + edges[i - 1].lerp(edges[i], start)
			var end_left := a.lerp(b, finish) - edges[i - 1].lerp(edges[i], finish)
			var end_right := a.lerp(b, finish) + edges[i - 1].lerp(edges[i], finish)
			for across in cross_sections:
				var x0 := float(across) / cross_sections
				var x1 := float(across + 1) / cross_sections
				var corners := [left.lerp(right, x0), left.lerp(right, x1),
					end_left.lerp(end_right, x0), end_left.lerp(end_right, x1)]
				for corner: int in [0, 1, 2, 1, 3, 2]:
					var p: Vector2 = corners[corner]
					surface.set_uv(Vector2(2.0 * (x0 if corner % 2 == 0 else x1) - 1.0, 0.0))
					surface.add_vertex(Vector3(p.x, ground_height(p.x, p.y) + .045, p.y))


func build_landmarks() -> void:
	Swisha.new().build(self, meta.swisha, ground_height, BASE)
	var cement := Kit.paint(Color("#8d8b80"))
	var lab := measured("cnl")
	for slot: Vector3 in [Vector3(-7, 0, 1), Vector3(0, 0, -6), Vector3(9, 0, 4)]:
		var building := lab + slot
		building.y = maxf(0.25, ground_height(building.x, building.z)) + 1.1
		Kit.box_at(self, building, Vector3(6, 2.2, 3.8), cement)
