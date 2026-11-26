extends RefCounted

const Kit = preload("res://scenery.gd")
const Wharf = preload("res://marina_wharf.gd")
const Docks = preload("res://marina_docks.gd")
const GasBar = preload("res://marina_gas_bar.gd")
const Fleet = preload("res://marina_fleet.gd")
const Pines = preload("res://lamure_pines.gd")
const Graphics = preload("res://river_graphics.gd")
const RiversideArt = preload("res://riverside_art.gd")
const WATERFRONT_CANOPY := "res://deep_river/waterfront_canopy.bin"
const YachtClub = preload("res://marina_yacht_club.gd")
const TennisCourts = preload("res://marina_tennis_courts.gd")
const MOWING_LAWN := [
	Vector2(7.5, -10), Vector2(14, -12.5), Vector2(25, -14.5), Vector2(33, -14),
	Vector2(29, -6), Vector2(24, .5), Vector2(17, 7.5), Vector2(7.5, 11.5),
]


static func mowing_lawn_bounds() -> Rect2:
	var bounds := Rect2(MOWING_LAWN[0], Vector2.ZERO)
	for corner: Vector2 in MOWING_LAWN:
		bounds = bounds.expand(corner)
	return bounds

var ground: Callable
var timber: Material
var piling: Material
var wood_scan: Texture2D
var leaf_mesh: ArrayMesh
var distant_leaf_mesh: ArrayMesh
var leaf_material: ShaderMaterial
var trunk_mesh: CylinderMesh
var bark_material: Material
var wharf := Wharf.new()
var docks := Docks.new()
var fleet := Fleet.new()
var gas_bar: GasBar
const Routes = preload("res://mowing_routes.gd")

var mowing_routes: Array[Dictionary]
var grass_transforms: Array[Transform3D]
var park_grass: MultiMeshInstance3D
var riverside_enabled := false
var riverside_center := Vector3.ZERO
var riverside_art := RiversideArt.new()
var riverside_tufts := {}
var riverside_masks := {}


func build(parent: Node3D, layout: Dictionary, ground_lookup: Callable, shore_lookup: Callable,
		wood: Texture2D, concrete: Texture2D, sand: Texture2D, clear_route := Callable(),
		pier_path: Array = []) -> void:
	ground = ground_lookup
	wood_scan = wood
	timber = weathered_wood(Color("#a99073"))
	if riverside_enabled:
		timber.set_shader_parameter("riverside_profile", true)
	piling = Kit.paint(Color("#504c44"))
	var marina := Node3D.new()
	marina.name = "DeepRiverMarina"
	parent.add_child(marina)
	build_breakwall(marina, layout.breakwall)
	var berths := docks.build(marina, layout, ground, timber)
	fleet.build(marina, berths, ground, docks)
	for berth in berths:
		if berth.row == "VisitorDock" and berth.slot == 1:
			build_gas_bar(berth, concrete)
			break
	var courts := TennisCourts.new()
	courts.build(marina, layout.tennis, pier_path, ground, concrete, timber)
	for child in courts.site.get_node("CourtCoating").get_children():
		if child is StaticBody3D:
			# The coating follows the marina terrain. Let its continuous ground collider
			# carry players across the gate, where the raised coating would create a lip.
			child.collision_layer = 0
	var launch := Kit.paint(Color("#aeaaa5"))
	launch.albedo_texture = concrete
	launch.uv1_triplanar = true
	launch.uv1_scale = Vector3.ONE * .43
	drape(marina, layout.boat_launch, launch, 0.012, true)
	var park := point(layout.pavilion, 0)
	park.y = ground.call(park.x, park.z)
	riverside_center = park
	build_pavilion(marina, park)
	build_park(marina, park, sand)
	build_park_grass(marina, park, shore_lookup)
	if FileAccess.file_exists(WATERFRONT_CANOPY):
		build_waterfront_canopy(parent, shore_lookup)
	else:
		build_trees(marina, layout.woodland, layout.buildings)
	YachtClub.build_landscape(marina, ground, render_trees)
	if layout.has("wharf"):
		wharf.build(marina, layout.wharf, ground, concrete, docks)
	docks.finish()
	build_bank_cover(marina, layout, shore_lookup, clear_route)
	if riverside_enabled:
		riverside_art.build_ground_cover(marina, park, ground, shore_lookup, mowing_routes, docks,
			clear_route, riverside_masks, layout)
		build_riverside_mowable_cover(marina, park)


func build_riverside_mowable_cover(parent: Node3D, pavilion: Vector3) -> void:
	var cells := {}
	for index in grass_transforms.size():
		var tuft: Transform3D = grass_transforms[index]
		if Vector2(tuft.origin.x, tuft.origin.z).distance_squared_to(Vector2(pavilion.x, pavilion.z)) \
				> RiversideArt.COVER_RADIUS * RiversideArt.COVER_RADIUS:
			continue
		var cell := Vector2i(floori(tuft.origin.x / RiversideArt.CHUNK), floori(tuft.origin.z / RiversideArt.CHUNK))
		if not cells.has(cell):
			cells[cell] = {"transforms": [], "indices": []}
		var scaled := tuft
		scaled.basis = tuft.basis.scaled_local(Vector3(2.15, 1.70, 2.15))
		cells[cell].transforms.append(scaled)
		cells[cell].indices.append(index)
	var material := ShaderMaterial.new()
	material.shader = preload("res://riverside_grass.gdshader")
	var mesh := RiversideArt.grass_blades()
	for cell: Dictionary in cells.values():
		var transforms: Array[Transform3D] = []
		transforms.assign(cell.transforms)
		var batch := Kit.new().scatter(parent, mesh, transforms, material)
		batch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		batch.set_meta("riverside_count", transforms.size())
		Graphics.batch(batch, "riverside_grass")
		for local_index in cell.indices.size():
			riverside_tufts[cell.indices[local_index]] = [batch, local_index, transforms[local_index]]


func trim_riverside_grass(index: int, cut_scale: float) -> void:
	if not riverside_tufts.has(index):
		return
	var tuft: Array = riverside_tufts[index]
	var transform: Transform3D = tuft[2]
	transform.basis.y *= cut_scale
	(tuft[0] as MultiMeshInstance3D).multimesh.set_instance_transform(tuft[1], transform)


func regrow_riverside_grass(index: int) -> void:
	if not riverside_tufts.has(index):
		return
	var tuft: Array = riverside_tufts[index]
	(tuft[0] as MultiMeshInstance3D).multimesh.set_instance_transform(tuft[1], tuft[2])


func build_gas_bar(berth: Dictionary, concrete: Texture2D) -> void:
	var forward: Vector3 = berth.along
	var outward: Vector3 = berth.outward
	gas_bar = GasBar.new()
	gas_bar.name = "VisitorDockGasBar"
	docks.root.add_child(gas_bar)
	gas_bar.position = berth.edge + outward * (Docks.SPINE_WIDTH * .5 + GasBar.PAD_DEPTH * .5 - .07)
	gas_bar.basis = Basis.looking_at(outward)
	gas_bar.build(concrete)
	var half_length := forward * (GasBar.PAD_LENGTH * .5)
	docks.add_obstacle(gas_bar.position - half_length, gas_bar.position + half_length, GasBar.PAD_DEPTH + .10)


func point(coords: Array, height: float) -> Vector3:
	return Vector3(coords[0], height, coords[1])


func weathered_wood(color: Color, decking := true) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://waterfront_wood.gdshader")
	material.set_shader_parameter("planks", wood_scan)
	material.set_shader_parameter("finish", Vector3(color.r, color.g, color.b))
	material.set_shader_parameter("decking", decking)
	return material


func build_breakwall(parent: Node3D, path: Array) -> void:
	var rng := RandomNumberGenerator.new()
	rng.seed = 410
	var stones: Array[Transform3D] = []
	var rock := SphereMesh.new()
	rock.radial_segments = 7
	rock.rings = 4
	var geometry := rock.get_mesh_arrays()
	var vertices: PackedVector3Array = geometry[Mesh.ARRAY_VERTEX]
	for i in vertices.size():
		var vertex := vertices[i]
		var fracture := sin(vertex.x * 9.1 + vertex.y * 5.3 - vertex.z * 4.7)
		vertices[i] = vertex * (1.0 + fracture * .18)
	geometry[Mesh.ARRAY_VERTEX] = vertices
	var riprap := ArrayMesh.new()
	riprap.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, geometry)
	for index in range(1, path.size()):
		var a := point(path[index - 1], 0)
		var b := point(path[index], 0)
		var along := (b - a).normalized()
		var across := Vector3(-along.z, 0, along.x)
		var pieces := maxi(3, ceili(a.distance_to(b) / 1.45))
		for i in pieces:
			for side: float in [-2.4, -1.1, .65, 2.3]:
				var p := a.lerp(b, float(i) / pieces) + across * (side + rng.randf_range(-.39, .39))
				p.y = maxf(.09, ground.call(p.x, p.z)) + .28
				var scale := Vector3(rng.randf_range(1.4, 2.45), rng.randf_range(.75, 1.42), rng.randf_range(1.3, 2.4))
				var angle := Vector3(rng.randf_range(-.60, .60), rng.randf_range(0, TAU), rng.randf_range(-.38, .38))
				stones.append(Transform3D(Basis.from_euler(angle).scaled_local(scale), p))
	Kit.new().scatter(parent, riprap, stones, Kit.paint(Color("#827f73")))


func drape(parent: Node3D, corners: Array, material: Material, lift: float, launch := false) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var a := point(corners[0], 0)
	var b := point(corners[1], 0)
	var c := point(corners[2], 0)
	var d := point(corners[3], 0)
	var columns := maxi(10, ceili(a.distance_to(b) / 1.18))
	var rows := maxi(10, ceili(a.distance_to(d) / 1.18))
	for row in rows:
		var y0 := float(row) / rows
		var y1 := float(row + 1) / rows
		for col in columns:
			var x0 := float(col) / columns
			var x1 := float(col + 1) / columns
			var quad := [Vector2(x0, y0), Vector2(x1, y0), Vector2(x0, y1), Vector2(x1, y0), Vector2(x1, y1), Vector2(x0, y1)]
			for uv: Vector2 in quad:
				var p := a.lerp(b, uv.x).lerp(d.lerp(c, uv.x), uv.y)
				var height: float = ground.call(p.x, p.z)
				p.y = maxf(height + lift, 0.10 - uv.y * 0.19) if launch else height + lift
				surface.set_normal(Vector3.UP)
				surface.set_uv(uv)
				surface.add_vertex(p)
	if material is BaseMaterial3D:
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	Kit.mesh_at(parent, surface.commit(), Vector3.ZERO, material)


func build_pavilion(parent: Node3D, at: Vector3, roof_color := Color("#365348"),
		seam_color := Color("#506b5d")) -> Node3D:
	var shelter := Node3D.new()
	shelter.name = "PierParkPavilion"
	parent.add_child(shelter)
	shelter.position = at
	var boards := weathered_wood(Color("#936b51"), false)
	var roof := Kit.paint(roof_color, .54, .10)
	var seams := Kit.paint(seam_color, .51, .19)
	var fascia := Kit.paint(Color("#d2c6aa"))
	Kit.box_at(shelter, Vector3(0, .09, 0), Vector3(8.64, .24, 5.76), timber)
	for x: float in [-3.76, 0.0, 3.76]:
		for z: float in [-2.48, 2.48]:
			Kit.box_at(shelter, Vector3(x, 1.73, z), Vector3(.22, 3.12, .22), boards)
			Kit.box_at(shelter, Vector3(x, .26, z), Vector3(.27, .17, .27), fascia)
	for side: float in [-1.0, 1.0]:
		var slope := Node3D.new()
		shelter.add_child(slope)
		slope.position = Vector3(0, 3.81, side * 1.59)
		slope.rotation.x = side * .31
		Kit.box_at(slope, Vector3.ZERO, Vector3(9.45, .11, 3.42), roof)
		Kit.box_at(slope, Vector3(0, -.09, side * 1.68), Vector3(9.47, .16, .105), fascia)
		var seam := BoxMesh.new()
		seam.size = Vector3(.029, .035, 3.38)
		var standing_seams: Array[Transform3D] = []
		for rib in range(-10, 11):
			standing_seams.append(Transform3D(Basis.IDENTITY, Vector3(rib * .432, .067, 0)))
		Kit.new().scatter(slope, seam, standing_seams, seams)
		for x: float in [-4.57, -2.25, 0, 2.25, 4.57]:
			Kit.box_at(slope, Vector3(x, -.13, 0), Vector3(.12, .14, 3.31), boards)
		Kit.box_at(shelter, Vector3(0, 3.18, side * 2.48), Vector3(8.13, .19, .22), boards)
		Kit.box_at(shelter, Vector3(side * 3.76, 1.16, 0), Vector3(.16, .11, 4.98), boards)
		for z: float in [-1.83, -1.20, -.60, 0, .60, 1.20, 1.83]:
			Kit.box_at(shelter, Vector3(side * 3.76, .70, z), Vector3(.065, .94, .065), boards)
	Kit.box_at(shelter, Vector3(0, 4.35, 0), Vector3(9.50, .065, .15), seams)
	for x: float in [-1.85, 1.85]:
		var table := Vector3(x, .94, 0)
		Kit.box_at(shelter, table, Vector3(1.62, .077, .78), timber)
		for side: float in [-1.0, 1.0]:
			Kit.box_at(shelter, table + Vector3(0, -.30, side * .59), Vector3(1.60, .07, .22), timber)
			for z: float in [-.39, .39]:
				Kit.beam(shelter, table + Vector3(side * .50, -.705, z),
					table + Vector3(side * .59, -.06, z * .73), .081, boards)
	var grill := at + Vector3(-5.2, 0, -1.6)
	grill.y = ground.call(grill.x, grill.z)
	var iron := Kit.paint(Color("#383c3a"), .81, .34)
	Kit.box_at(parent, grill + Vector3.UP * .40, Vector3(.10, .80, .10), iron)
	Kit.box_at(parent, grill + Vector3.UP * .85, Vector3(.73, .22, .49), iron)
	for rung in 8:
		Kit.box_at(parent, grill + Vector3(-.29 + rung * .082, .99, 0), Vector3(.020, .026, .46), iron)
	return shelter


func build_park(parent: Node3D, pavilion: Vector3, sand: Texture2D) -> void:
	var center := pavilion + Vector3(-23.1, 0, 5.8)
	var across := Vector3(.962, 0, -.273)
	var depth := across.cross(Vector3.UP)
	var corners := []
	for corner: Vector2 in [Vector2(-1, -1), Vector2(1, -1), Vector2(1, 1), Vector2(-1, 1)]:
		var p := center + across * corner.x * 17.8 + depth * corner.y * 8.5
		corners.append([p.x, p.z])
	var sandpit := ShaderMaterial.new()
	sandpit.shader = preload("res://pier_play_sand.gdshader")
	sandpit.set_shader_parameter("sand", sand)
	drape(parent, corners, sandpit, .045)
	var play := Node3D.new()
	play.name = "PierParkPlayground"
	parent.add_child(play)
	play.position = Vector3(center.x, ground.call(center.x, center.z), center.z)
	play.basis = Basis(across, Vector3.UP, depth)
	var posts := Kit.paint(Color("#38565f"), .59, .12)
	var rails := Kit.paint(Color("#d1ab42"), .47)
	var seats := Kit.paint(Color("#303538"))
	var chain := Kit.paint(Color("#777c79"), .54, .26)
	for side: float in [-1.0, 1.0]:
		var apex := Vector3(5 + 2.37 * side, 2.70, 0)
		for leg: float in [-1.0, 1.0]:
			Kit.beam(play, apex, Vector3(apex.x, -.14, leg * 1.04), .083, posts)
	Kit.box_at(play, Vector3(5, 2.69, 0), Vector3(5.04, .099, .10), posts)
	for x: float in [3.87, 5.98]:
		for side: float in [-1.0, 1.0]:
			Kit.beam(play, Vector3(x + side * .26, 2.65, 0),
				Vector3(x + side * .22, .53, -.14), .018, chain)
		Kit.box_at(play, Vector3(x, .52, -.14), Vector3(.54, .068, .24), seats)
	for x: float in [-4.8, -3.25]:
		for z: float in [-.68, .68]:
			Kit.box_at(play, Vector3(x, 1.15, z), Vector3(.10, 2.52, .10), posts)
		Kit.beam(play, Vector3(x, 1.93, -.72), Vector3(x, 1.93, .71), .063, rails)
	Kit.box_at(play, Vector3(-4.02, 1.25, 0), Vector3(1.65, .12, 1.44), timber)
	Kit.box_at(play, Vector3(-4.03, 2.47, 0), Vector3(1.98, .19, 1.81), posts)
	var chute := Kit.box_at(play, Vector3(-4.03, .75, -1.77), Vector3(.68, .065, 2.46), rails)
	chute.rotation.x = -.45
	for side: float in [-1.0, 1.0]:
		var handrail := Kit.box_at(play, chute.position + Vector3(.32 * side, .100, 0),
			Vector3(.085, .12, 2.48), rails)
		handrail.rotation.x = chute.rotation.x
		Kit.beam(play, Vector3(-4.03 + .46 * side, .04, 1.47),
			Vector3(-4.03 + .46 * side, 1.34, .64), .049, posts)
	for i in 5:
		Kit.box_at(play, Vector3(-4.03, .24 + i * .24, 1.34 - i * .15), Vector3(.88, .045, .13), rails)


func build_park_grass(parent: Node3D, pavilion: Vector3, shore: Callable) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 8151
	var grass: Array[Transform3D] = []
	for z in range(-24, 15):
		for x in range(-42, 50):
			var p := pavilion + Vector3(x + random.randf_range(-.45, .45), 0, z + random.randf_range(-.45, .45))
			p.y = ground.call(p.x, p.z)
			if p.y < .18 or p.y > 1.36 or shore.call(p) > 0.0:
				continue
			if z > -9 and x < 8:
				continue
			var wet := false
			for offset: Vector3 in [Vector3.FORWARD, Vector3.BACK, Vector3.RIGHT, Vector3.LEFT]:
				if shore.call(p + offset * 4.5) > .5:
					wet = true
					break
			if wet and random.randf() > .26:
				var scale := Vector3(random.randf_range(.85, 1.75), random.randf_range(.24, .73), 1.18)
				var angle := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(scale)
				grass.append(Transform3D(angle, p))
	mowing_routes = Routes.load_routes(Vector2(pavilion.x, pavilion.z))
	var occupied := {}
	for route in mowing_routes:
		for zone: PackedVector2Array in route.zones:
			add_route_grass(zone, grass, occupied, random, shore)
	if not grass.is_empty():
		var material := ShaderMaterial.new()
		material.shader = preload("res://river_reeds.gdshader")
		var verge := Kit.new().scatter(parent, reed_mesh(random), grass, material)
		park_grass = verge
		grass_transforms = grass
		verge.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		# The shared MultiMesh also includes routes outside the marina.


func add_route_grass(zone: PackedVector2Array, grass: Array[Transform3D], occupied: Dictionary,
		random: RandomNumberGenerator, shore: Callable) -> void:
	const SPACING := .43
	var area := Routes.bounds(zone)
	for z in range(floori(area.position.y / SPACING), ceili(area.end.y / SPACING)):
		for x in range(floori(area.position.x / SPACING), ceili(area.end.x / SPACING)):
			var cell := Vector2i(x, z)
			var at := (Vector2(cell) + Vector2(.5, .5)) * SPACING
			if occupied.has(cell) or not Geometry2D.is_point_in_polygon(at, zone):
				continue
			var p := Vector3(at.x, ground.call(at.x, at.y), at.y)
			if p.y < .26 or shore.call(p) > 0.0:
				continue
			occupied[cell] = true
			var scale := Vector3(.47, random.randf_range(.18, .36), .52)
			var angle := Basis(Vector3.UP, random.randf_range(0.0, TAU)).scaled_local(scale)
			grass.append(Transform3D(angle, p))


func build_trees(parent: Node3D, woodland: Array, buildings: Array) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 17
	var clearings: Array[Rect2] = []
	for outline: Array in buildings:
		var span := Rect2(Vector2(outline[0][0], outline[0][1]), Vector2.ZERO)
		for vertex: Array in outline:
			span = span.expand(Vector2(vertex[0], vertex[1]))
		clearings.append(span.grow(4.6))
	var crowns: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	for patch: Array in woodland:
		var outline := PackedVector2Array()
		var bounds := Rect2(Vector2(patch[0][0], patch[0][1]), Vector2.ZERO)
		for pair: Array in patch:
			var p := Vector2(pair[0], pair[1])
			outline.append(p)
			bounds = bounds.expand(p)
		for _i in ceili(bounds.get_area() * .018):
			var p := Vector2(random.randf_range(bounds.position.x, bounds.end.x),
				random.randf_range(bounds.position.y, bounds.end.y))
			if not Geometry2D.is_point_in_polygon(p, outline):
				continue
			if clearings.any(func(area: Rect2) -> bool: return area.has_point(p)):
				continue
			var y: float = ground.call(p.x, p.y)
			if y < 0.88:
				continue
			var size := random.randf_range(4.1, 9.8)
			var angle := Basis(Vector3.UP, random.randf_range(0, TAU))
			var basis := angle.scaled_local(Vector3(size, size * 1.16, size * .85))
			var two_crowns := random.randf() < .58
			if YachtClub.LANDSCAPE.has_point(p):
				continue
			crowns.append(Transform3D(basis, Vector3(p.x, y + size * .94, p.y)))
			if two_crowns:
				var branch := angle.x * size * .26
				crowns.append(Transform3D(basis.scaled_local(Vector3(.66, .63, .69)), Vector3(p.x, y + size * 1.12, p.y) + branch))
			stems.append(Transform3D(angle.scaled_local(Vector3(size * .065, size * 1.13, size * .065)),
				Vector3(p.x, y + size * .55, p.y)))
	render_trees(parent, crowns, stems)


func build_canopy(parent: Node3D, points: PackedFloat32Array, marina: Rect2, clearance: Callable,
		replace_tree := Callable()) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 2008
	var groves := {}
	for i in range(0, points.size(), 3):
		var p := Vector2(points[i], points[i + 1])
		if marina.has_point(p):
			continue
		var foot := Vector3(p.x, ground.call(p.x, p.y), p.y)
		if foot.y < .68 or clearance.call(foot) > 0.0:
			continue
		var height := clampf(points[i + 2], 4.0, 26.0)
		var width := height * random.randf_range(.46, .65)
		var angle := Basis(Vector3.UP, random.randf_range(0.0, TAU))
		var second_crown := height > 9.0 and random.randf() < .62
		if replace_tree.is_valid() and replace_tree.call(foot, height):
			continue
		var shape := angle.scaled_local(Vector3(width, height * .76, width * .88))
		var cell := Vector2i(floori(p.x / 150.0), floori(p.y / 150.0))
		if not groves.has(cell):
			var crowns: Array[Transform3D] = []
			var stems: Array[Transform3D] = []
			groves[cell] = [crowns, stems]
		groves[cell][0].append(Transform3D(shape, foot + Vector3.UP * height * .64))
		if second_crown:
			var branch := foot + Vector3.UP * height * .74 + angle.x * width * .23
			groves[cell][0].append(Transform3D(shape.scaled_local(Vector3(.64, .59, .69)), branch))
		groves[cell][1].append(Transform3D(angle.scaled_local(Vector3(width * .073, height * .59, width * .073)),
			foot + Vector3.UP * height * .293))
	for grove: Array in groves.values():
		render_trees(parent, grove[0], grove[1])


func build_waterfront_canopy(parent: Node3D, clearance: Callable) -> void:
	var survey := FileAccess.get_file_as_bytes(WATERFRONT_CANOPY).to_float32_array()
	var forest := Node3D.new()
	forest.name = "WaterfrontCanopy"
	parent.add_child(forest)
	var pines := Pines.new()
	var random := RandomNumberGenerator.new()
	random.seed = 18459
	build_canopy(forest, survey, YachtClub.LANDSCAPE, clearance, func(foot: Vector3, height: float) -> bool:
		if riverside_enabled and RiversideArt.near_marina(foot, riverside_center):
			riverside_art.add_tree(foot, height)
			return true
		if height < 9.5 or random.randf() > .105:
			return false
		pines.plant(foot, height, random)
		return true)
	pines.build(forest)
	if riverside_enabled:
		riverside_art.build_trees(forest)


func render_trees(parent: Node3D, crowns: Array[Transform3D], stems: Array[Transform3D]) -> void:
	if crowns.is_empty():
		return
	if leaf_mesh == null:
		load_tree_materials()
	var kit := Kit.new()
	var near_leaves := kit.scatter(parent, leaf_mesh, crowns, leaf_material)
	var trunks := kit.scatter(parent, trunk_mesh, stems, bark_material)
	var distant_leaves := kit.scatter(parent, distant_leaf_mesh, crowns, leaf_material)
	var bounds := near_leaves.get_aabb().merge(trunks.get_aabb())
	for batch: MultiMeshInstance3D in [near_leaves, trunks, distant_leaves]:
		batch.custom_aabb = bounds
	Graphics.batch(near_leaves, "tree_detail")
	Graphics.batch(trunks, "tree_stem")
	Graphics.batch(distant_leaves, "tree_silhouette")
	distant_leaves.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func load_tree_materials() -> void:
	trunk_mesh = CylinderMesh.new()
	trunk_mesh.radial_segments = 6
	trunk_mesh.top_radius = .29
	trunk_mesh.bottom_radius = .51
	trunk_mesh.height = 1.0
	bark_material = Kit.paint(Color("#554e3e"))
	leaf_mesh = leaf_cards()
	distant_leaf_mesh = leaf_cards(2)
	var image := Image.load_from_file("res://deep_river/shore_canopy.png")
	image.resize(768, 768, Image.INTERPOLATE_LANCZOS)
	image.generate_mipmaps()
	leaf_material = ShaderMaterial.new()
	leaf_material.shader = preload("res://river_canopy.gdshader")
	leaf_material.set_shader_parameter("leaves", ImageTexture.create_from_image(image))
	leaf_material.set_shader_parameter("fall_bounds", Vector4(17490, 12280, 18930, 13510))


func leaf_cards(card_count := 5) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for card in card_count:
		var angle := float(card) * PI / card_count
		var axis := Vector3(cos(angle), 0, sin(angle))
		var across := axis.cross(Vector3.UP)
		var tilt := .55 if card % 2 == 1 else -.18
		var vertical := Vector3.UP.rotated(axis, tilt)
		var offset := across * (.06 - float(card) * .039)
		for uv: Vector2 in [Vector2(0, 1), Vector2(0, 0), Vector2(1, 1), Vector2(1, 1), Vector2(0, 0), Vector2(1, 0)]:
			var horizontal := uv.x - .5
			surface.set_normal((across * .51 + axis * horizontal + Vector3.UP * (1.04 - uv.y)).normalized())
			surface.set_uv(uv if card % 2 == 0 else Vector2(1.0 - uv.x, uv.y))
			surface.add_vertex(offset + axis * horizontal + vertical * (.5 - uv.y))
	if card_count == 2:
		return surface.commit()
	for uv: Vector2 in [Vector2.ZERO, Vector2.DOWN, Vector2.RIGHT,
			Vector2.RIGHT, Vector2.DOWN, Vector2.ONE]:
		surface.set_normal(Vector3.UP)
		surface.set_uv(uv)
		surface.add_vertex(Vector3((uv.x - .5) * .77, .17, (uv.y - .5) * .77))
	return surface.commit()


func build_bank_cover(parent: Node3D, layout: Dictionary, shore: Callable, clear_route: Callable) -> void:
	var random := RandomNumberGenerator.new()
	random.seed = 311
	var reeds: Array[Transform3D] = []
	var rocks: Array[Transform3D] = []
	var access: Array[PackedVector2Array] = []
	for line: Array in layout.dock_access:
		for index in range(1, line.size()):
			var a := Vector2(line[index - 1][0], line[index - 1][1])
			var b := Vector2(line[index][0], line[index][1])
			access.append(PackedVector2Array([a, b]))
	var patch := point(layout.origin, 0)
	var size := Vector2(layout.grid[0], layout.grid[1]) * float(layout.step)
	for z in range(4, int(size.y) - 5, 4):
		for x in range(4, int(size.x) - 5, 4):
			var p := patch + Vector3(x + random.randf_range(-1.8, 1.8), 0, z + random.randf_range(-1.8, 1.8))
			p.y = ground.call(p.x, p.z)
			if p.y < -.10 or p.y > 1.48:
				continue
			if docks.blocks(p) or is_finite(wharf.launch.floor_at(p)):
				continue
			if clear_route.is_valid() and clear_route.call(Vector2(p.x, p.z)):
				continue
			if shore.call(p + Vector3(2.8, 0, 0)) + shore.call(p - Vector3(2.8, 0, 0)) \
					+ shore.call(p + Vector3(0, 0, 2.8)) + shore.call(p - Vector3(0, 0, 2.8)) < .65:
				continue
			var location := Vector2(p.x, p.z)
			if access.any(func(segment: PackedVector2Array) -> bool:
				return Geometry2D.get_closest_point_to_segment(location, segment[0], segment[1]).distance_squared_to(location) < 3.75):
				continue
			var basis := Basis(Vector3.UP, random.randf_range(0, TAU))
			if random.randf() < .35:
				var rock_scale := random.randf_range(.25, 1.6)
				rocks.append(Transform3D(basis.scaled_local(Vector3(rock_scale, rock_scale * .61, rock_scale * .82)), p))
			else:
				var height := random.randf_range(.53, 1.19)
				reeds.append(Transform3D(basis.scaled_local(Vector3(1.3, height, 1.2)), p))
	if not rocks.is_empty():
		var stone := SphereMesh.new()
		stone.radial_segments = 7
		stone.rings = 4
		Kit.new().scatter(parent, stone, rocks, Kit.paint(Color("#77776c")))
	if not reeds.is_empty():
		var material := ShaderMaterial.new()
		material.shader = preload("res://river_reeds.gdshader")
		Kit.new().scatter(parent, reed_mesh(random), reeds, material)


func reed_mesh(random: RandomNumberGenerator) -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for _blade in 13:
		var base := Vector3(random.randf_range(-.31, .31), 0, random.randf_range(-.30, .30))
		var along := Vector3.FORWARD.rotated(Vector3.UP, random.randf_range(0, TAU))
		var edge := along.cross(Vector3.UP) * random.randf_range(.018, .039)
		var height := random.randf_range(.27, .87)
		var middle := base + Vector3.UP * height * .62 + along * .10
		var tip := base + Vector3.UP * height + along * .24
		surface.set_normal(along)
		for vertex in [base - edge, base + edge, middle - edge * .65, middle - edge * .65,
				base + edge, middle + edge * .65, middle - edge * .65, middle + edge * .65, tip]:
			surface.add_vertex(vertex)
	return surface.commit()
