extends RefCounted

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const WALLS = preload("res://deep_river_walls.gdshader")
const YachtClub = preload("res://marina_yacht_club.gd")
const Champlain = preload("res://deep_river_champlain.gd")
const GiantTigerPlaza = preload("res://deep_river_plaza.gd")

var roof: SurfaceTool
var walls: SurfaceTool
var frames: SurfaceTool
var glass: SurfaceTool
var town: Node3D
var ground_height: Callable
var metre: float
var windows: ShaderMaterial
var champlain := Champlain.new()


func build(parent: Node3D, buildings: Array, texture: Texture2D, ground: Callable, scale: float,
		brick: Texture2D, aggregate: Texture2D, wood: Texture2D, road_material: ShaderMaterial) -> void:
	ground_height = ground
	metre = scale
	var district := Node3D.new()
	district.name = "DeepRiverBuildings"
	parent.add_child(district)
	var chunks := {}
	var giant_tiger: Dictionary
	for building: Dictionary in buildings:
		if building.detail == "giant_tiger":
			giant_tiger = building
			continue
		if building.windows == "club":
			continue
		var cell := Vector2i(floori(float(building.center[0]) / 192.0), floori(float(building.center[1]) / 192.0))
		if not chunks.has(cell):
			chunks[cell] = []
		chunks[cell].append(building)
	var roof_material := ShaderMaterial.new()
	roof_material.shader = preload("res://deep_river_roof.gdshader")
	roof_material.set_shader_parameter("roof_atlas", texture)
	roof_material.set_shader_parameter("aggregate", aggregate)
	var brick_and_siding := ShaderMaterial.new()
	brick_and_siding.shader = WALLS
	brick_and_siding.set_shader_parameter("brick_scan", brick)
	brick_and_siding.set_shader_parameter("wood_scan", wood)
	var trim := Kit.paint(Color.WHITE, 0.77)
	trim.vertex_color_use_as_albedo = true
	var storefront_glass := Kit.paint(Color.WHITE, 0.18)
	storefront_glass.vertex_color_use_as_albedo = true
	storefront_glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	windows = ShaderMaterial.new()
	windows.shader = preload("res://deep_river_glass.gdshader")
	for block: Array in chunks.values():
		town = Node3D.new()
		district.add_child(town)
		roof = SurfaceTool.new()
		walls = SurfaceTool.new()
		frames = SurfaceTool.new()
		glass = SurfaceTool.new()
		for surface in [roof, walls, frames, glass]:
			surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		champlain.setup(town, walls, frames, glass, ground_height, panel)
		for building: Dictionary in block:
			build_one(building)
		for detail in town.get_children():
			if detail is GeometryInstance3D:
				Graphics.batch(detail, "building_detail")
		build_batch(roof, roof_material, "building_shell")
		build_batch(champlain.roofs, trim, "building_shell")
		var shell := build_batch(walls, brick_and_siding, "building_shell")
		if shell != null:
			shell.create_trimesh_collision()
		build_batch(frames, trim, "building_detail")
		build_batch(glass, windows, "building_detail")
		var panes := build_batch(champlain.plaza.panes, storefront_glass, "building_detail")
		if panes != null:
			panes.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		var landings := build_batch(champlain.plaza.landings, trim, "building_detail")
		if landings != null:
			landings.create_trimesh_collision()
		var signboards := build_batch(champlain.plaza.signboards, trim, "building_detail")
		if signboards != null:
			signboards.add_to_group(Champlain.Plaza.SIGNS)

	if not giant_tiger.is_empty():
		GiantTigerPlaza.new().build(district, giant_tiger, ground_height, aggregate, windows, road_material)
	if buildings.any(func(building: Dictionary) -> bool: return building.id == "hexagon"):
		var club_root := Node3D.new()
		district.add_child(club_root)
		YachtClub.new().build(club_root, ground, windows, aggregate)
		for detail in club_root.find_children("*", "GeometryInstance3D", true, false):
			Graphics.batch(detail, "building_shell")


func build_batch(surface: SurfaceTool, material: Material, kind: String) -> MeshInstance3D:
	var mesh := surface.commit()
	if mesh == null or mesh.get_surface_count() == 0:
		return null
	var instance := Kit.mesh_at(town, mesh, Vector3.ZERO, material)
	Graphics.batch(instance, kind)
	return instance


func build_one(building: Dictionary) -> void:
	var profile: Dictionary = Champlain.BUILDINGS.get(building.id, {})
	var grade: Array = profile.get("grade_anchor", building.center)
	var base: float = ground_height.call(grade[0], grade[1])
	var eave: float = base + profile.get("eave", building.eave)
	if profile.is_empty():
		build_mapped_roof(building, eave)
	else:
		champlain.build_roof(building, profile, eave)

	var wall_color := Color(profile.get("wall", building.wall))
	wall_color.a = 0.0 if building.finish == "brick" or not profile.is_empty() else 1.0
	var trim := Color(building.trim)
	var toward_street := Vector3.ZERO
	if building.front is Array:
		toward_street = Vector3(building.front[0] - building.center[0], 0,
			building.front[1] - building.center[1]).normalized()
	var main_front := -1
	var greatest_width := 0.0
	for index in building.walls.size():
		var edge: Array = building.walls[index]
		var a := Vector3(edge[0][0], 0, edge[0][1])
		var b := Vector3(edge[1][0], 0, edge[1][1])
		var score := (b - a).cross(Vector3.UP).dot(toward_street)
		if building.windows == "school":
			score *= a.distance_to(b)
		if score > greatest_width:
			greatest_width = score
			main_front = index
	for index in building.walls.size():
		var edge: Array = building.walls[index]
		var top_a := roof_point(edge[0], eave)
		var top_b := roof_point(edge[1], eave)
		var a := Vector3(top_a.x, base, top_a.z)
		var b := Vector3(top_b.x, base, top_b.z)
		var width := b.distance_to(a)
		if width < 0.0001:
			continue
		var along := (b - a) / width
		var normal := along.cross(Vector3.UP)
		a.y = minf(base, ground_height.call(a.x, a.z)) - 0.05
		b.y = minf(base, ground_height.call(b.x, b.z)) - 0.05
		var facade := Vector3(a.x, base, a.z)
		var kind: String = profile.get("kind", "")
		if kind in ["lcbo", "plaza"] and index == profile.front:
			champlain.build_recessed_front(kind, facade, Basis(along, Vector3.UP, normal), width,
				eave - base, wall_color, a.y, b.y)
			continue
		if not profile.is_empty() and champlain.build_shop_face(kind, index, facade, Basis(along, Vector3.UP, normal),
				width, eave - base, wall_color, a.y, b.y):
			continue
		if kind == "lcbo" and index == 3:
			wall_color = Color(0.44, 0.30, 0.23, 0.0)
		elif kind == "lcbo":
			wall_color = Color(Color(profile.wall), 0.0)
		elif kind == "forest_corner":
			wall_color.a = 0.32
		if kind == "pharmacy":
			var split_a := Vector3(a.x, base + Champlain.PHARMACY_UPPER_BASE, a.z)
			var split_b := Vector3(b.x, split_a.y, b.z)
			add_wall(a, b, split_a, split_b, normal, wall_color)
			add_wall(split_a, split_b, top_a, top_b, normal, Color(0.75, 0.72, 0.66, 1.0))
		else:
			add_wall(a, b, top_a, top_b, normal, wall_color)
		if not profile.is_empty():
			champlain.build_face(profile, index, facade, along, normal, width, eave - base)
			continue
		if width < metre * 2.75 or building.windows == "utility":
			continue
		if building.windows == "school":
			make_school_facade(facade, along, normal, width, building.eave, index == main_front)
			continue
		var street_facing := toward_street == Vector3.ZERO or normal.dot(toward_street) > 0.56
		make_windows(building, facade, along, normal, width, trim, street_facing)
		if index == main_front and building.detail != null:
			add_landmark_detail(building, facade, along, normal, width, trim)


func build_mapped_roof(building: Dictionary, eave: float) -> void:
	var roof_box := Rect2(building.box[0], building.box[1],
		building.box[2] - building.box[0], building.box[3] - building.box[1])
	var uv_box := Rect2(building.uv[0], building.uv[1],
		building.uv[2] - building.uv[0], building.uv[3] - building.uv[1])
	for index in range(0, building.roof.size(), 3):
		var a := roof_point(building.roof[index], eave)
		var b := roof_point(building.roof[index + 1], eave)
		var c := roof_point(building.roof[index + 2], eave)
		var normal := (c - a).cross(b - a).normalized()
		var triangle := [a, b, c] if normal.y >= 0.0 else [a, c, b]
		roof.set_normal(normal if normal.y >= 0.0 else -normal)
		for p: Vector3 in triangle:
			var locality := (Vector2(p.x, p.z) - roof_box.position) / roof_box.size
			roof.set_uv(uv_box.position + locality.clamp(Vector2.ZERO, Vector2.ONE) * uv_box.size)
			roof.add_vertex(p)

func roof_point(point: Array, eave: float) -> Vector3:
	return Vector3(point[0], eave + point[2], point[1])


func add_wall(a: Vector3, b: Vector3, top_a: Vector3, top_b: Vector3, normal: Vector3, color: Color) -> void:
	var width := Vector2(a.x, a.z).distance_to(Vector2(b.x, b.z)) / metre
	var end := (b.y - a.y) / metre
	var low_left := Vector2.ZERO
	var low_right := Vector2(width, end)
	var high_left := Vector2(0, (top_a.y - a.y) / metre)
	var high_right := Vector2(width, (top_b.y - a.y) / metre)
	if color.a > 0.25 and color.a < 0.4:
		var grade_a: float = ground_height.call(a.x, a.z)
		var grade_b: float = ground_height.call(b.x, b.z)
		low_left.y = a.y - grade_a
		low_right.y = b.y - grade_b
		high_left.y = top_a.y - grade_a
		high_right.y = top_b.y - grade_b
	walls.set_color(color)
	walls.set_normal(normal)
	for pair in [[a, low_left], [top_a, high_left], [b, low_right],
			[top_a, high_left], [top_b, high_right], [b, low_right]]:
		walls.set_uv(pair[1])
		walls.add_vertex(pair[0])


func panel(surface: SurfaceTool, origin: Vector3, along: Vector3, outward: Vector3,
		width: float, height: float, color: Color, up := Vector3.UP) -> void:
	var a := origin
	var b := origin + along * width
	var c := b + up * height
	var d := a + up * height
	surface.set_color(color)
	surface.set_normal(outward)
	var corners := [a, b, c, d]
	var uv := [Vector2(0, 1), Vector2(1, 1), Vector2(1, 0), Vector2.ZERO]
	for index: int in [0, 3, 1, 3, 2, 1]:
		surface.set_uv(uv[index])
		surface.add_vertex(corners[index])


func make_windows(building: Dictionary, origin: Vector3, along: Vector3, normal: Vector3,
		width: float, trim: Color, frontage: bool) -> void:
	var shopfront: bool = building.windows == "shop" and frontage
	var civic_front: bool = building.windows == "civic" and frontage
	var ribbon: bool = building.windows == "civic" or (building.windows == "library" and frontage)
	if not frontage and building.windows == "shop":
		return
	var floors := int(building.floors)
	var floor_height: float = building.eave / maxi(floors, 1)
	var spacing := (2.9 if ribbon or shopfront else 3.7) * metre
	var bays := clampi(roundi(width / spacing), 1, 18)
	var pitch := width / bays
	var width_ratio := 0.93 if civic_front else (0.84 if ribbon or shopfront else 0.47)
	var frame_width := minf(pitch * width_ratio, pitch - metre * 0.22)
	var frame_height := minf(floor_height * (0.73 if shopfront or ribbon else 0.44), metre * 2.5)
	var sill := floor_height * (0.12 if shopfront else 0.34)
	var bevel := metre * 0.087
	if frame_width <= bevel * 2.0 or frame_height <= bevel * 2.0:
		return
	for level in floors:
		for bay in bays:
			var corner := origin + along * (pitch * (bay + 0.5) - frame_width * 0.5)
			corner.y += float(level) * floor_height + sill
			if corner.y < float(ground_height.call(corner.x, corner.z)) + metre * 0.07:
				continue
			corner += normal * 0.016
			panel(frames, corner, along, normal, frame_width, frame_height, trim)
			var inner := corner + along * bevel + Vector3.UP * bevel + normal * 0.011
			var shade := Color("#465362").lerp(Color("#28343d"), float((bay + level) % 3) * 0.18)
			panel(glass, inner, along, normal, frame_width - bevel * 2.0, frame_height - bevel * 2.0, shade)
			if civic_front or shopfront:
				var lip := Kit.box_at(town,
					corner + along * frame_width * .5 + normal * metre * .035 - Vector3.UP * metre * .028,
					Vector3(frame_width + metre * .04, metre * .065, metre * .12), Kit.paint(trim))
				lip.basis = Basis(along, Vector3.UP, normal)
			if ribbon or shopfront or building.windows == "house":
				var jamb := corner + along * (frame_width * 0.5 - bevel * 0.32) + normal * 0.020
				panel(frames, jamb, along, normal, bevel * 0.64, frame_height, trim)
	if shopfront or civic_front:
		var canopy_height := metre * 2.6 if civic_front else sill + frame_height + metre * 0.25
		var canopy_depth := metre * (2.3 if civic_front else 1.52)
		var above := origin + Vector3.UP * canopy_height
		var posts := Kit.paint(Color("#9d9382") if civic_front else trim)
		var canopy := Kit.box_at(town, above + along * width * 0.5 + normal * canopy_depth * 0.49,
			Vector3(width, metre * 0.25, canopy_depth), posts)
		canopy.basis = Basis(along, Vector3.UP, normal)
		for i in range(1, bays):
			var foot := origin + along * pitch * i + normal * canopy_depth * 0.90
			foot.y = ground_height.call(foot.x, foot.z)
			if foot.y < above.y:
				Kit.beam(town, foot, Vector3(foot.x, above.y, foot.z), metre * 0.15, posts)


func make_school_facade(origin: Vector3, along: Vector3, outward: Vector3, width: float,
		height: float, main_front: bool) -> void:
	var coping := Color("#b1a698")
	var frame := Color("#b9b7ae")
	var sill := Color("#8c8280")
	var glass_tint := Color("#42515c")
	var face := origin + outward * .023
	panel(frames, face + Vector3.UP * (height - .21), along, outward, width, .22, coping)
	var count := maxi(1, roundi(width / 3.7))
	var bay := width / count
	var entry_offset := width * .62
	for index in count:
		var center := bay * (index + .5)
		var entry_bay := main_front and absf(center - entry_offset) < 4.60
		var actual_width := bay * (.72 if index % 5 != 4 else .44)
		var edge := face + along * (center - actual_width * .5)
		for level in 2:
			if entry_bay:
				continue
			var window_at := edge + Vector3.UP * (1.33 + 2.43 * level)
			panel(frames, window_at - Vector3.UP * .12, along, outward, actual_width, 1.27, sill)
			panel(frames, window_at + outward * .011, along, outward, actual_width, 1.04, frame)
			for lite in 3:
				var pitch := actual_width / 3.0
				var tint := glass_tint.darkened(float((index + lite) % 3) * .065)
				var pane_at := window_at + outward * .024 + Vector3.UP * .055 + along * (lite * pitch + .041)
				panel(glass, pane_at, along, outward, pitch - .081, .925, tint)
	if main_front:
		build_school_entry(origin + along * entry_offset, along, outward)


func build_school_entry(center: Vector3, along: Vector3, outward: Vector3) -> void:
	center.y = ground_height.call(center.x, center.z) + .065
	var pale := Kit.paint(Color("#c5beb1"))
	var metal := Kit.paint(Color("#45505a"), .69, .22)
	var axis := Basis(along, Vector3.UP, outward)
	var surround := Kit.box_at(town, center + Vector3.UP * 1.92 + outward * .09, Vector3(6.05, 3.80, .22), pale)
	surround.basis = axis
	var frontage := center + outward * .22 - along * 2.63
	panel(frames, frontage, along, outward, 5.26, 2.76, Color("#50545a"))
	for index in 5:
		panel(glass, frontage + along * (index * 1.045 + .047) + Vector3.UP * .10 + outward * .014,
			along, outward, .95, 2.52, Color("#415564"))
	var canopy := Kit.box_at(town, center + outward * 1.34 + Vector3.UP * 3.05, Vector3(6.42, .25, 2.57), pale)
	canopy.basis = axis
	var band := Kit.box_at(town, canopy.position + outward * 1.28, Vector3(6.44, .22, .09), metal)
	band.basis = axis
	for side: float in [-1.0, 1.0]:
		var top := center + along * side * 2.80 + outward * 2.38 + Vector3.UP * 2.96
		var foot := Vector3(top.x, ground_height.call(top.x, top.z), top.z)
		Kit.beam(town, foot - Vector3.UP * .06, top, .18, metal)


func add_landmark_detail(building: Dictionary, origin: Vector3, along: Vector3,
		normal: Vector3, width: float, trim: Color) -> void:
	if building.detail == "town_hall_entry":
		var center: Vector3 = origin + along * width * 0.5 + Vector3.UP * building.eave + normal * 0.022
		var half_width := minf(width * 0.38, metre * 2.87)
		var left := center - along * half_width
		var right := center + along * half_width
		var peak := center + Vector3.UP * metre * 3.45
		var tint := Color("#46575e")
		panel(glass, left - Vector3.UP * (building.eave - metre * 0.74),
			along, normal, half_width * 2.0, building.eave - metre * 0.74, tint)
		glass.set_color(tint)
		glass.set_normal(normal)
		for p: Vector3 in [left, peak, right]:
			glass.add_vertex(p)
		var rear := -normal * metre * 2.6
		for edge: Vector3 in [left, right]:
			var slope_normal := (peak - edge).cross(rear).normalized()
			glass.set_normal(slope_normal if slope_normal.y > 0 else -slope_normal)
			var slope := [edge, peak, edge + rear, peak, peak + rear, edge + rear]
			if slope_normal.y > 0:
				slope.reverse()
			for p: Vector3 in slope:
				glass.add_vertex(p)
		var metal := Kit.paint(trim)
		Kit.beam(town, left, peak, metre * 0.22, metal)
		Kit.beam(town, peak, right, metre * 0.22, metal)
		for part: float in [-1.0, -0.34, 0.34, 1.0]:
			var vertical := center + along * half_width * part + normal * 0.002
			Kit.beam(town, vertical - Vector3.UP * (building.eave - metre * 0.84),
				vertical + Vector3.UP * metre * (1.0 - absf(part)) * 3.45, metre * 0.09, metal)
		for level: float in [-4.2, -2.65, -1.1, 0.0, 1.65, 2.66]:
			var rail_center := center + Vector3.UP * metre * level + normal * 0.003
			var rail := along * half_width * (1.0 - maxf(level, 0.0) / 3.45)
			Kit.beam(town, rail_center - rail, rail_center + rail, metre * 0.075, metal)
		var clock := CylinderMesh.new()
		clock.top_radius = metre * 0.55
		clock.bottom_radius = clock.top_radius
		clock.height = metre * 0.065
		clock.radial_segments = 24
		var clock_center := center + Vector3.UP * metre * 0.86 + normal * 0.006
		var face := Kit.mesh_at(town, clock, clock_center, Kit.paint(Color("#eae7dc")))
		face.basis = Basis(along, normal, -Vector3.UP)
		var hub := clock_center + normal * metre * 0.06
		Kit.beam(town, hub, hub + Vector3.UP * metre * 0.34, metre * 0.04, metal)
		Kit.beam(town, hub, hub + along * metre * 0.19 - Vector3.UP * metre * 0.13, metre * 0.05, metal)
	elif building.detail == "library_clerestory":
		var span := width * 0.84
		var roof_depth := 0.0
		for edge: Array in building.walls:
			roof_depth = maxf(roof_depth, -Vector3(edge[0][0] - origin.x, 0, edge[0][1] - origin.z).dot(normal))
		var shed := origin + along * width * 0.5 - normal * roof_depth * 0.69
		shed.y += float(building.eave) + metre * 2.30
		var trim_cap := Kit.box_at(town, shed, Vector3(span, metre * 1.44, roof_depth * 0.17), Kit.paint(trim))
		trim_cap.basis = Basis(along, Vector3.UP, normal)
		var dark_roof := Kit.box_at(town, shed + Vector3.UP * metre * 0.73,
			Vector3(span + metre * 0.24, metre * 0.13, roof_depth * 0.19), Kit.paint(Color("#545752")))
		dark_roof.basis = trim_cap.basis
