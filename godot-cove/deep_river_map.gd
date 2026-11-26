extends Node3D

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const Marina = preload("res://marina_art.gd")
const MarinaDocks = preload("res://marina_docks.gd")
const MarinaLaunch = preload("res://marina_launch.gd")
const LamureBeach = preload("res://lamure_beach.gd")
const LamurePines = preload("res://lamure_pines.gd")
const RiverbankPark = preload("res://riverbank_park.gd")
const BrockhouseWay = preload("res://brockhouse_way.gd")
const Swisha = preload("res://swisha_dam.gd")
const Town = preload("res://deep_river_buildings.gd")
const BuildingsDriveways = preload("res://deep_river_driveways.gd")
const TownHall = preload("res://deep_river_town_hall.gd")
const EssoPlaza = preload("res://deep_river_esso_plaza.gd")
const PropertySites = preload("res://deep_river_properties.gd")
const MarioProperty = preload("res://mario_property.gd")
const RoadNetwork = preload("res://deep_river_roads.gd")
const PontoonWorkshop = preload("res://pontoon_workshop.gd")
const PublicWorks = preload("res://public_works.gd")
const Waves = preload("res://swell.gd")
const Landings = preload("res://game_campaign_data.gd")
const BASE := "res://deep_river/"
const ROAD_SCAN = preload("res://deep_river/materials/road_asphalt033_color.jpg")
const ROAD_NORMAL = preload("res://deep_river/materials/road_asphalt033_normal.jpg")
const GRAVEL_SCAN = preload("res://deep_river/materials/gravel_road_diff_1k.jpg")
const GRAVEL_NORMAL = preload("res://deep_river/materials/gravel_road_nor_gl_1k.jpg")
const TILE := 44
const PLAZA_PORTICO_TREE := Vector2(18000.5215, 13239.9229)
var town_walkways: RoadNetwork.Walkways

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

var town_hall := TownHall.new()
var property_sites: Array[Node3D] = []
var meta: Dictionary
var highway_clearance: Array[Dictionary] = []
var regional_streets: Array = preload("res://deep_river/regional_access.json").data.mcanulty_roads
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
const DayCycle = preload("res://river_day_cycle.gd")
var last_evening := 0.0
var last_solar_minute := -1.0
var sky_fog_density := .00010
var solar_energy := .82
var moon_light: DirectionalLight3D
var fog_scale := 1.0
var marina_patch: TerrainPatch
var lamure_patch: TerrainPatch
var swisha_patch: TerrainPatch
var detail_patches: Array[TerrainPatch]
var riverbed: ImageTexture
var chart_texture: ImageTexture
var day_sky: ImageTexture
var marina_paving: ImageTexture
var marina_water: Image
var asphalt_scan: ImageTexture
var concrete_scan: ImageTexture
var wood_scan: ImageTexture
var windows: ShaderMaterial
var esso_plaza: EssoPlaza
var canopy_area := Rect2()
var waterfront := Marina.new()
var lamure := LamureBeach.new()


func build(checkpoint := Callable()) -> void:
	meta = JSON.parse_string(FileAccess.get_file_as_string(BASE + "river.json"))
	for index: int in RoadNetwork.HIGHWAY:
		var line: Array = meta.streets[index]
		for i in range(1, line.size()):
			var a := Vector2(line[i - 1][0], line[i - 1][1])
			var b := Vector2(line[i][0], line[i][1])
			highway_clearance.append({"a": a, "b": b, "area": Rect2(a, Vector2.ZERO).expand(b).grow(11.5)})
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
	marina_water = Image.load_from_file(BASE + "marina_shoals.png")
	if meta.marina.get("wharf", {}).has("launch_ramp"):
		waterfront.wharf.launch.prepare(meta.marina.wharf.launch_ramp)
		cut_launch_channel()
	swisha_patch = TerrainPatch.new(meta.swisha, BASE + "swisha")
	detail_patches = [marina_patch, swisha_patch]
	var park := RiverbankPark.new()
	if meta.has("lamure"):
		lamure_patch = TerrainPatch.new(meta.lamure, BASE + "lamure")
		detail_patches.append(lamure_patch)
		meta.places.append({"name": "Lamure Beach", "point": meta.lamure.point})
	if meta.has("riverbank"):
		park.prepare(meta.riverbank)
		marina_patch.heights = park.grade_parking(marina_patch.heights, marina_patch.grid,
			marina_patch.area.position, marina_patch.spacing, ground_height)
	regional_water = Image.load_from_file(BASE + "shoals.png")
	chart_texture = ImageTexture.create_from_image(Image.load_from_file(BASE + "chart.png"))
	station_water = ImageTexture.create_from_image(Image.load_from_file(BASE + "swisha_shoals.png"))
	Kit.new().light(self)
	var world: WorldEnvironment = get_child(0)
	sky_paint = ShaderMaterial.new()
	sky_paint.shader = preload("res://river_sky.gdshader")
	sky_paint.set_shader_parameter("use_day_cycle", true)
	day_sky = scanned_surface("day_sky")
	bind_day_sky(sky_paint)
	world.environment.sky.sky_material = sky_paint
	world.environment.fog_density = .00010
	world.environment.fog_light_color = Color("#b7bdb4")
	world.environment.ambient_light_color = Color("#d1dce0")
	world.environment.ambient_light_energy = .29
	world.environment.tonemap_mode = Environment.TONE_MAPPER_FILMIC
	world.environment.tonemap_white = 6.0
	world.environment.tonemap_exposure = 1.05
	var sun: DirectionalLight3D = get_child(1)
	landscape_light = sun
	landscape_environment = world.environment
	sun.light_color = Color("#fff6ed")
	sun.light_energy = .82
	sun.rotation_degrees = Vector3(-48.0, -42.0, 0)
	sun.directional_shadow_max_distance = 230
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	sun_direction = sun.global_basis.z
	moon_light = DirectionalLight3D.new()
	moon_light.name = "Moonlight"
	moon_light.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon_light.light_color = Color("#b4c9ff")
	moon_light.light_energy = 0.0
	moon_light.shadow_enabled = true
	moon_light.directional_shadow_max_distance = 80.0
	add_child(moon_light)
	world.environment.sky.process_mode = Sky.PROCESS_MODE_REALTIME
	world.environment.sky.radiance_size = Sky.RADIANCE_SIZE_32
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
	ground.set_shader_parameter("road_scan", ROAD_SCAN)
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
			if checkpoint.is_valid():
				await checkpoint.call("Building terrain and collisions")
			tile(col, row, ground)
			trees_for_tile(col, row, rng, tree, trunk, needles, bark)
	for detail in detail_patches:
		for row in range(0, detail.grid.y - 1, TILE):
			for col in range(0, detail.grid.x - 1, TILE):
				if checkpoint.is_valid():
					await checkpoint.call("Building terrain and collisions")
				tile(col, row, ground, detail)
	build_water()
	var brick := scanned_surface("brick")
	var residential_driveways := await build_town(paving_texture, ground, brick, checkpoint)
	if checkpoint.is_valid():
		await checkpoint.call("Building properties and waterfront")
	property_sites = PropertySites.build(self, ground_height, concrete_scan, brick, wood_scan)
	MarioProperty.build(self, ground_height, wood_scan)
	build_landmarks()
	if meta.has("riverbank"):
		var surface := Image.load_from_file(BASE + "riverbank_surface.png")
		park.clear_old_path_paint(surface)
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
	if checkpoint.is_valid():
		await checkpoint.call("Building vegetation")
	var pines := LamurePines.new()
	var champlain: Array = meta.streets[RoadNetwork.CHAMPLAIN]
	var street_start := Vector2(champlain[0][0], champlain[0][1])
	var street_axis := (Vector2(champlain[1][0], champlain[1][1]) - street_start).normalized()
	waterfront.build_canopy(self, town_canopy, marina_patch.area, wet_clearance,
		func(foot: Vector3, height: float) -> bool:
			# This surveyed tree stands under the new corner portico.
			var point := Vector2(foot.x, foot.z)
			if point.distance_squared_to(PLAZA_PORTICO_TREE) < .25:
				return true
			return PublicWorks.cleared_for_construction(foot) or park.owns_tree(foot) \
				or residential_driveways.clears_tree(point) \
				or town_walkways.clears_tree(point) \
				or RoadNetwork.clears_champlain_tree(point, street_start, street_axis) \
				or RoadNetwork.CivicParking.covers(point) \
					or PropertySites.clears_tree(point) or MarioProperty.clears_tree(point) \
					or EssoPlaza.clears_tree(point) \
				or highway_has_tree_conflict(point, highway_clearance) \
				or point.distance_squared_to(RiverbankPark.GAZEBO_SITE) < 36.0 \
				or (lamure_patch != null and pines.place_from_survey(foot, height)))
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
		and not waterfront.docks.blocks(world) and not lamure.blocks_swim_area(world)


func can_fish(point: Vector3) -> bool:
	return point.distance_squared_to(dam_center) >= dam_clearance_squared and depth_at(point) >= .45 \
		and not waterfront.docks.blocks(point) and not lamure.blocks_swim_area(point)


func marina_hull_clear(hull: PackedVector2Array, minimum_depth: float) -> bool:
	if waterfront.docks.overlaps(hull):
		return false
	var channel := waterfront.wharf.launch.bounds.grow(25.0)
	if not channel.intersects(MarinaDocks.polygon_bounds(hull)):
		return true
	for corner: Vector2 in hull:
		if depth_at(Vector3(corner.x, 0, corner.y)) < minimum_depth:
			return false
	return true


func cut_launch_channel() -> void:
	var launch: MarinaLaunch = waterfront.wharf.launch
	var patch := marina_patch
	var area := launch.bounds.grow(29.0).intersection(patch.area)
	var first := Vector2i(((area.position - patch.area.position) / patch.spacing).floor())
	var last := Vector2i(((area.end - patch.area.position) / patch.spacing).ceil())
	for row in range(first.y, last.y + 1):
		for col in range(first.x, last.x + 1):
			var index := row * patch.grid.x + col
			var at := patch.area.position + Vector2(col, row) * patch.spacing
			var original := patch.heights[index]
			var height: float = launch.channel_bed(at, original)
			if is_equal_approx(height, original):
				continue
			patch.heights[index] = height
			var bed := maxf(height, launch.floor_at(Vector3(at.x, 0, at.y)))
			var depth := maxf(0.0, -bed)
			var wet := roundi(clampf(depth * 2.1, 0.0, 8.0) / patch.shore_unit)
			patch.shore_mask[index] = maxi(patch.shore_mask[index], wet)
			var tint := marina_water.get_pixel(col, row)
			tint.r = float(patch.shore_mask[index]) / 255.0
			tint.b = depth / 63.75
			marina_water.set_pixel(col, row, tint)


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


func driving_height(x: float, z: float) -> float:
	var land := ground_height(x, z)
	var at := Vector3(x, land, z)
	var query := PhysicsRayQueryParameters3D.create(at + Vector3.UP, at - Vector3.UP * .10,
		RoadNetwork.ROAD_LAYER)
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return maxf(land, hit.position.y) if not hit.is_empty() else land


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
	land.get_child(0).add_to_group("ottawa_terrain")


func trees_for_tile(col: int, row: int, rng: RandomNumberGenerator, tree: Mesh, trunk: Mesh,
		needles: Material, bark: Material) -> void:
	var groves := {}
	var city := point(1)
	var tile_center := Vector3((col + TILE * 0.5) * step, 0, (row + TILE * 0.5) * step)
	var distance_from_city := Vector3(col * step, 0, row * step).distance_to(city)
	var near_dam := tile_center.distance_to(dam_center) < 2150.0
	var tile_area := Rect2(Vector2(col, row) * step, Vector2.ONE * TILE * step)
	var near_highway := highway_clearance.filter(func(span: Dictionary): return span.area.intersects(tile_area))
	var count := 1500 if near_dam or distance_from_city < 4300.0 else 550
	for _i in count:
		var x := rng.randf_range(col, mini(col + TILE, columns - 1)) * step
		var z := rng.randf_range(row, mini(row + TILE, rows - 1)) * step
		if Vector2(x, z).distance_squared_to(Landings.SITES[1].plot) < 96.0 * 96.0:
			continue
		var location := Vector2(x, z)
		if swisha_patch.area.has_point(location) or marina_patch.area.has_point(location) or canopy_area.has_point(location) \
				or PublicWorks.road_clearance(location) or PropertySites.clears_tree(location) \
				or MarioProperty.clears_tree(location) \
				or PontoonWorkshop.clears_tree(location) \
				or highway_has_tree_conflict(location, near_highway):
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
	var marina_texture := ImageTexture.create_from_image(marina_water)
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


func set_wake(stern: Vector3, behind: Vector3, speed: float, thrust: float, prop_heading: Vector3,
		spread: float, peak_speed: float) -> void:
	var wash := thrust * smoothstep(.25, 1.2, speed)
	near_water.set_shader_parameter("boat_wake", Vector4(stern.x, stern.z, speed, wash))
	near_water.set_shader_parameter("wake_spread", spread)
	near_water.set_shader_parameter("wake_peak_speed", peak_speed)
	near_water.set_shader_parameter("wake_heading", Vector2(behind.x, behind.z))
	near_water.set_shader_parameter("prop_heading", Vector2(prop_heading.x, prop_heading.z))


func update_day_cycle(work_minutes: float) -> void:
	var minute := snappedf(work_minutes, DayCycle.UPDATE_MINUTES)
	if minute == last_solar_minute:
		return
	last_solar_minute = minute
	var light := DayCycle.sample(minute)
	sun_direction = light.sun
	solar_energy = light.sun_energy
	last_evening = light.lights
	landscape_light.basis = Basis.looking_at(-sun_direction)
	landscape_light.light_color = light.direct
	landscape_light.light_energy = solar_energy
	landscape_light.visible = solar_energy > 0.0
	moon_light.basis = Basis.looking_at(sun_direction)
	moon_light.light_energy = light.moon_energy
	moon_light.visible = light.moon_energy > 0.0
	landscape_environment.ambient_light_color = light.ambient
	landscape_environment.ambient_light_energy = light.ambient_energy
	landscape_environment.fog_light_color = light.fog
	sky_fog_density = light.fog_density
	landscape_environment.fog_density = sky_fog_density * fog_scale
	landscape_environment.tonemap_exposure = light.exposure
	windows.set_shader_parameter("evening", last_evening)
	town_hall.set_evening(last_evening)
	esso_plaza.glazing.set_shader_parameter("evening", last_evening)
	for material: ShaderMaterial in [sky_paint, near_water, far_water, headpond_water, windows,
			town_hall.glass, town_hall.glass_alt, esso_plaza.glazing]:
		material.set_shader_parameter("sun_direction", sun_direction)
		material.set_shader_parameter("sky_zenith", light.zenith)
		material.set_shader_parameter("sky_horizon", light.horizon)
		material.set_shader_parameter("sky_glow", light.glow)
		material.set_shader_parameter("sun_color", light.direct)
		material.set_shader_parameter("sun_strength", solar_energy)
		material.set_shader_parameter("moon_strength", light.moon_energy)
		material.set_shader_parameter("night_weight", light.night)
		material.set_shader_parameter("photo_weight", light.photo)


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


func build_town(paving_texture: Texture2D, terrain: Material, brick: Texture2D,
		checkpoint: Callable) -> BuildingsDriveways:
	var tile_image := Image.load_from_file(BASE + "deep_river_roofs.png")
	tile_image.generate_mipmaps()
	var textures := ImageTexture.create_from_image(tile_image)
	var buildings := Town.new()
	var footprints: Array = meta.buildings.filter(func(building: Dictionary) -> bool:
		return not PublicWorks.REPLACED_FOOTPRINTS.has(building.id) and building.id != RiverbankPark.GAZEBO_FOOTPRINT \
			and not TownHall.FOOTPRINTS.has(building.id) and not PropertySites.replaces(building.id) \
			and not MarioProperty.replaces(building.id) \
			and not EssoPlaza.REPLACED_FOOTPRINTS.has(building.id))
	if lamure_patch != null:
		var shelter := Vector2(meta.lamure.shelter[0], meta.lamure.shelter[1])
		footprints = footprints.filter(func(building: Dictionary):
			var box: Array = building.box
			return not Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1]).has_point(shelter))
	var detail_areas: Array[Rect2] = [marina_patch.area]
	if lamure_patch != null:
		detail_areas.append(lamure_patch.area)
	var roads := RoadNetwork.new()
	await roads.build(self, meta, ground_height, marina_paving, detail_areas,
		ROAD_SCAN, ROAD_NORMAL, concrete_scan, asphalt_scan, GRAVEL_SCAN, GRAVEL_NORMAL, paving_texture, checkpoint)
	await buildings.build(self, footprints, textures, ground_height, meta.distance_scale,
		brick, asphalt_scan, wood_scan, roads.paved, meta.streets,
		regional_streets, meta.buildings, concrete_scan, checkpoint)
	town_walkways = roads.build_walkways(buildings.driveways, concrete_scan, asphalt_scan, terrain)
	windows = buildings.windows
	bind_day_sky(windows)
	add_child(town_hall)
	town_hall.build(ground_height, concrete_scan, waterfront.render_trees)
	bind_day_sky(town_hall.glass)
	bind_day_sky(town_hall.glass_alt)
	esso_plaza = EssoPlaza.new()
	add_child(esso_plaza)
	esso_plaza.build(ground_height, asphalt_scan, concrete_scan, brick)
	bind_day_sky(esso_plaza.glazing)
	return buildings.driveways


static func highway_has_tree_conflict(point: Vector2, spans: Array) -> bool:
	for span: Dictionary in spans:
		if span.area.has_point(point) and point.distance_squared_to(
				Geometry2D.get_closest_point_to_segment(point, span.a, span.b)) < 11.5 * 11.5:
			return true
	return false


func roadside_sign_foot(foot: Vector3, half_span: float) -> Vector3:
	var point := Vector2(foot.x, foot.z)
	var height_offset := foot.y - ground_height(foot.x, foot.z)
	for attempt in 4:
		var crossing := road_at_sign(point, half_span)
		if crossing.is_empty():
			break
		var center: Vector2 = crossing.center
		var edge: Vector2 = crossing.edge
		var preferred := center + edge
		var alternate := center - edge
		if roadside_safe(alternate) and (not roadside_safe(preferred) \
				or not road_at_sign(preferred, half_span).is_empty()):
			preferred = alternate
		point = preferred
	if not road_at_sign(point, half_span).is_empty():
		var origin := Vector2(foot.x, foot.z)
		for radius in range(2, 42, 2):
			for direction in 16:
				var candidate := origin + Vector2.RIGHT.rotated(TAU * direction / 16.0) * radius
				if roadside_safe(candidate) and road_at_sign(candidate, half_span).is_empty():
					return Vector3(candidate.x, ground_height(candidate.x, candidate.y) + height_offset, candidate.y)
	return Vector3(point.x, ground_height(point.x, point.y) + height_offset, point.y)


func roadside_safe(at: Vector2) -> bool:
	var ground := ground_height(at.x, at.y)
	return ground > .15 and (ground > .65 or wet_clearance(Vector3(at.x, ground, at.y)) < .1)


func road_at_sign(point: Vector2, half_span: float) -> Dictionary:
	var lines: Array = meta.streets.duplicate()
	lines.append_array(regional_streets)
	lines.append(PublicWorks.CEDAR_ROAD)
	lines.append(PublicWorks.YARD_DRIVE)
	if meta.has("brockhouse"):
		var road: Array = meta.brockhouse.road_segment
		lines.append([[road[0], road[1]], [road[2], road[3]]])
	var best := INF
	var found := {}
	for index in lines.size():
		var line: Array = lines[index]
		var width := RoadNetwork.HIGHWAY_HALF_WIDTH if index in RoadNetwork.HIGHWAY else RoadNetwork.STREET_HALF_WIDTH
		var search_width := RoadNetwork.PARKING_HALF_WIDTH if index == RoadNetwork.CHAMPLAIN else width
		for i in range(1, line.size()):
			var a := Vector2(line[i - 1][0], line[i - 1][1])
			var b := Vector2(line[i][0], line[i][1])
			if a.is_equal_approx(b) or not Rect2(a, Vector2.ZERO).expand(b).grow(search_width + half_span).has_point(point):
				continue
			var center := Geometry2D.get_closest_point_to_segment(point, a, b)
			var clearance := width + half_span
			if index == RoadNetwork.CHAMPLAIN and i == 1:
				var side := (point - center).dot((b - a).orthogonal())
				clearance = RoadNetwork.champlain_half_width(a.distance_to(center), side) + half_span
			var distance := point.distance_squared_to(center)
			if distance < best and distance < clearance * clearance:
				best = distance
				var normal := (b - a).orthogonal().normalized()
				if (point - center).dot(normal) < -.015:
					normal = -normal
				found = {"center": center, "edge": normal * (clearance + .85)}
	return found


func build_landmarks() -> void:
	Swisha.new().build(self, meta.swisha, ground_height, BASE)
	var cement := Kit.paint(Color("#8d8b80"))
	var lab := measured("cnl")
	for slot: Vector3 in [Vector3(-7, 0, 1), Vector3(0, 0, -6), Vector3(9, 0, 4)]:
		var building := lab + slot
		building.y = maxf(0.25, ground_height(building.x, building.z)) + 1.1
		Kit.box_at(self, building, Vector3(6, 2.2, 3.8), cement)
