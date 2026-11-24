extends Node3D

const Kit = preload("res://scenery.gd")
const MenuTheme = preload("res://river_menu_theme.gd")
const Car = preload("res://marina_car_model.gd")
const Graphics = preload("res://river_graphics.gd")
const Masonry = preload("res://deep_river_plaza_masonry.gdshader")
const Pavement = preload("res://deep_river_plaza_pavement.gdshader")
const Roads = preload("res://deep_river_roads.gd")

# The two surveyed walls meet at the chamfered street corner. The parking
# frontage is on the long wall, with the shorter wall facing Champlain Street.
const FRONT := 0
const RETURN := 1
const SIDE := 2
const APRON_DEPTH := 3.55
const CURB_RISE := .15
const CURB_WIDTH := .17
const LOT_LEVEL := .022
const BAY_START := 1.12
const BAY_WIDTH := 2.86
const BAY_COUNT := 10
const BAY_DEPTH := 5.45
const RAMP_BAY := 3
const CREAM := Color("#e3d9c3")
const FLASHING := Color("#5d7078")

var footprint: Dictionary
var ground: Callable
var roof_level: float
var canopy_level: float
var trim := surface()
var glazing := surface()
var structure := StaticBody3D.new()
var front: Vector3
var corner: Vector3
var front_axis: Vector3
var front_normal: Vector3
var return_axis: Vector3
var return_normal: Vector3
var front_length: float
var return_length: float
var cupola: Vector3
var column_material := Kit.paint(CREAM, .71)


func build(parent: Node3D, building: Dictionary, elevation: Callable,
		asphalt_scan: Texture2D, glass_material: ShaderMaterial, road_material: ShaderMaterial) -> void:
	footprint = building
	ground = elevation
	name = "DeepRiverPlaza"
	parent.add_child(self)
	position = Vector3(building.center[0], 0, building.center[1])
	position.y = ground.call(position.x, position.z)
	add_child(structure)
	structure.name = "PlazaFixtures"

	front = wall_point(building.walls[FRONT][0])
	corner = wall_point(building.walls[FRONT][1])
	front_length = front.distance_to(corner)
	front_axis = (corner - front).normalized()
	front_normal = front_axis.cross(Vector3.UP)
	var return_end := wall_point(building.walls[RETURN][1])
	return_length = corner.distance_to(return_end)
	return_axis = (return_end - corner).normalized()
	return_normal = return_axis.cross(Vector3.UP)
	cupola = corner + (front_normal + return_normal).normalized() * 2.48
	roof_level = building.eave
	canopy_level = roof_level - 1.42

	build_shell(asphalt_scan)
	build_walk(return_end)
	build_lot(road_material)
	build_storefronts()
	build_champlain_frontage()
	build_corner_roof()
	var painted := Kit.paint(Color.WHITE, .72)
	painted.vertex_color_use_as_albedo = true
	finish(trim, painted, "StorefrontDetails")
	finish(glazing, glass_material, "ShopGlass", false, false)


func wall_point(point: Array) -> Vector3:
	return Vector3(point[0] - position.x, 0, point[1] - position.z)


func grade(point: Vector3) -> float:
	return float(ground.call(point.x + position.x, point.z + position.z)) - position.y


func on_grade(point: Vector3, lift: float) -> Vector3:
	return Vector3(point.x, grade(point) + lift, point.z)


func front_at(along: float, outward: float = 0.0) -> Vector3:
	return front + front_axis * along + front_normal * outward


func build_shell(scan: Texture2D) -> void:
	var brick := surface()
	var block := surface()
	var roof := surface()
	for i in footprint.walls.size():
		var edge: Array = footprint.walls[i]
		var a := wall_point(edge[0])
		var b := wall_point(edge[1])
		var along := (b - a).normalized()
		var normal := along.cross(Vector3.UP)
		var finish_brick: bool = i <= SIDE
		var sections := ceili(a.distance_to(b) / 2.0)
		for j in sections:
			var left := a.lerp(b, float(j) / sections)
			var right := a.lerp(b, float(j + 1) / sections)
			var low_left := on_grade(left, -.10)
			var low_right := on_grade(right, -.10)
			wall_face(brick if finish_brick else block, low_left, low_right,
				left + Vector3.UP * (roof_level + .42), right + Vector3.UP * (roof_level + .42),
				a, along, normal, Color.WHITE)
		detail_box(a.lerp(b, .5) + Vector3.UP * (roof_level + .46),
			Vector3(a.distance_to(b) + .08, .105, .31), FLASHING, Basis(along, Vector3.UP, normal))

	for i in range(0, footprint.roof.size(), 3):
		var a := wall_point(footprint.roof[i]) + Vector3.UP * roof_level
		var b := wall_point(footprint.roof[i + 1]) + Vector3.UP * roof_level
		var c := wall_point(footprint.roof[i + 2]) + Vector3.UP * roof_level
		triangle(roof, a, b, c, Vector3.UP, roof_uv(a), roof_uv(b), roof_uv(c))

	finish(brick, masonry(Color("#995d49"), Color("#a4937d"), Vector2(.225, .076), .009),
		"FrontBrick", true)
	finish(block, masonry(Color("#c6bdae"), Color("#a39786"), Vector2(.39, .195), .018),
		"SideBlock", true)
	var membrane := pavement(scan, Color("#555650"))
	finish(roof, membrane, "FlatRoof", true)

	# Roof drains and low-profile mechanical housings read from the flyover.
	for vent: Vector2 in [Vector2(-2.8, -8.5), Vector2(11.6, -5.8), Vector2(2.8, 7.2)]:
		var at := Vector3(vent.x, roof_level, vent.y)
		detail_box(at + Vector3.UP * .18, Vector3(1.05, .36, .78), Color("#686e6b"))
		detail_box(at + Vector3.UP * .38, Vector3(1.20, .08, .91), Color("#8f9389"))
		for slat in 3:
			detail_box(at + Vector3(0, .12 + slat * .08, -.401),
				Vector3(.79, .028, .024), Color("#474d4a"))


func roof_uv(point: Vector3) -> Vector2:
	return Vector2(point.dot(front_axis), point.dot(front_normal))


func build_walk(return_end: Vector3) -> void:
	var pavers := surface()
	var curb := surface()
	var ramps := surface()
	# Miter both walks to the same outer point so the pavers and curb turn
	# continuously around the cupola. Split the curb at the two ramp approaches.
	var turn := corner + (front_normal + return_normal) * (5.35 / (1.0 + front_normal.dot(return_normal)))
	var sidewalk_normal := (wall_point(footprint.walls[SIDE][1]) - return_end).normalized().cross(Vector3.UP)
	var sidewalk_join := return_end + (return_normal + sidewalk_normal) 		* (3.43 / (1.0 + return_normal.dot(sidewalk_normal)))
	var ramp := BAY_START + BAY_WIDTH * (RAMP_BAY + .5)
	var front_stations: Array[float] = [0.0, ramp - 1.45, ramp - .94, ramp + .94, ramp + 1.45,
		30.0, 34.2, front_length]
	var front_outside: Array[Vector3] = []
	for u: float in front_stations:
		front_outside.append(front_at(u, APRON_DEPTH))
	front_outside[6] = front_at(34.2, 5.35)
	front_outside[7] = turn
	walk_section(pavers, curb, ramps, front, front_axis, front_stations, front_outside, ramp, false)

	var return_stations: Array[float] = [0.0, 7.0, 11.65, 12.16, 14.04, 14.55, 18.8, return_length]
	var return_outside: Array[Vector3] = [turn]
	for i in range(1, return_stations.size() - 1):
		var u := return_stations[i]
		return_outside.append(corner + return_axis * u + return_normal * lerpf(5.35, 3.43, u / return_length))
	return_outside.append(sidewalk_join)
	walk_section(pavers, curb, ramps, corner, return_axis, return_stations, return_outside, 13.1, false)

	var side_axis := Vector3.UP.cross(sidewalk_normal)
	walk_section(pavers, curb, ramps, return_end, side_axis, [0.0, 5.0, 8.0],
		[sidewalk_join, return_end + side_axis * 5.0 + sidewalk_normal * 3.43,
			return_end + side_axis * 8.0 + sidewalk_normal * 3.43], -10.0, true)
	finish(pavers, masonry(Color("#b28770"), Color("#a9937e"), Vector2(.208, .107), .006),
		"PaverApron", true)
	finish(curb, Kit.paint(Color("#b7ac99"), .98), "ConcreteCurb", true)
	finish(ramps, Kit.paint(Color("#c5b7a0"), .98), "CurbRamps", true)


func walk_section(pavers: SurfaceTool, curb: SurfaceTool, ramps: SurfaceTool,
		start: Vector3, axis: Vector3, stations: Array[float], outside: Array[Vector3],
		ramp: float, fade_end: bool) -> void:
	var sections := [0.0, .36, .68, 1.0]
	for i in range(1, stations.size()):
		var length := stations[i] - stations[i - 1]
		var samples := ceili(length / .72)
		for j in samples:
			var ends: Array = []
			for t: float in [float(j) / samples, float(j + 1) / samples]:
				var u := lerpf(stations[i - 1], stations[i], t)
				var wall := start + axis * u
				var edge := outside[i - 1].lerp(outside[i], t)
				var curb_inside := edge.move_toward(wall, CURB_WIDTH)
				var lowered := 1.0 - smoothstep(.94, 1.45, absf(u - ramp))
				var fade := 1.0 - smoothstep(5.0, 8.0, u) if fade_end else 1.0
				var profile := PackedVector3Array()
				for across: float in sections:
					var lift := lerpf(CURB_RISE + .04, CURB_RISE, across)
					lift -= lowered * (CURB_RISE - LOT_LEVEL) * smoothstep(.36, 1.0, across)
					profile.append(on_grade(wall.lerp(curb_inside, across), lerpf(LOT_LEVEL, lift, fade)))
				profile.append(on_grade(edge, lerpf(LOT_LEVEL, CURB_RISE, fade)
					- lowered * (CURB_RISE - LOT_LEVEL) * fade))
				profile.append(on_grade(edge, LOT_LEVEL - .009))
				ends.append(profile)
			var a: PackedVector3Array = ends[0]
			var b: PackedVector3Array = ends[1]
			var is_ramp := absf(lerpf(stations[i - 1], stations[i], (j + .5) / samples) - ramp) < 1.45
			for row in 3:
				ground_quad(ramps if is_ramp and row >= 1 else pavers,
					a[row], b[row], a[row + 1], b[row + 1], Vector3.UP)
			var outward := (b[4] - a[4]).slide(Vector3.UP).cross(Vector3.UP).normalized()
			ground_quad(curb, a[3], b[3], a[4], b[4], Vector3.UP)
			ground_quad(curb, a[4], b[4], a[5], b[5], outward)


func build_lot(road_material: ShaderMaterial) -> void:
	var asphalt := surface()
	var width := BAY_COUNT * BAY_WIDTH
	var far := APRON_DEPTH + BAY_DEPTH
	# Carry the lot just under the Ridge Road edge along its open frontage.
	lot_rectangle(asphalt, BAY_START - .90, width + 1.75, APRON_DEPTH - .12, far + 2.85)
	var material := road_material.duplicate() as ShaderMaterial
	material.set_shader_parameter("parking_lot", true)
	material.set_shader_parameter("parking_bays", Vector4(BAY_START, BAY_WIDTH, BAY_COUNT, APRON_DEPTH))
	material.set_shader_parameter("parking_aisle", Vector2(BAY_START + RAMP_BAY * BAY_WIDTH, far))
	Roads.install(self, asphalt, Vector3.ZERO, material, "ParkingAsphalt", true)
	park_car(1, 0, Color("#a14840"), false)
	park_car(5, 1, Color("#d8d9d4"), true)
	park_car(8, 2, Color("#42636e"), false)


func lot_rectangle(mesh: SurfaceTool, u: float, width: float, start: float, end: float) -> void:
	var rows := ceili((end - start) / .65)
	var columns := ceili(width / .65)
	for i in columns:
		var left := u + width * i / columns
		var right := u + width * (i + 1) / columns
		for j in rows:
			var near := lerpf(start, end, float(j) / rows)
			var far := lerpf(start, end, float(j + 1) / rows)
			for uv: Vector2 in [Vector2(left, near), Vector2(right, near), Vector2(left, far),
					Vector2(right, near), Vector2(right, far), Vector2(left, far)]:
				var lift := lerpf(LOT_LEVEL, .008, smoothstep(9.0, 11.85, uv.y))
				mesh.set_uv(uv)
				mesh.add_vertex(on_grade(front_at(uv.x, uv.y), lift))


func park_car(bay: int, model: int, paint: Color, reversed: bool) -> void:
	var data: Dictionary = Car.MODELS[model].duplicate()
	data.paint = paint
	var at := front_at(BAY_START + (bay + .5) * BAY_WIDTH, APRON_DEPTH + BAY_DEPTH * .51)
	var sideways := front_axis * (-1.0 if reversed else 1.0)
	var rear := front_normal * (-1.0 if reversed else 1.0)
	var across := (on_grade(at + sideways, LOT_LEVEL) - on_grade(at - sideways, LOT_LEVEL)).normalized()
	var back := on_grade(at + rear, LOT_LEVEL) - on_grade(at - rear, LOT_LEVEL)
	var up := back.cross(across).normalized()
	var parked := StaticBody3D.new()
	parked.name = "ParkedCar%d" % bay
	add_child(parked)
	parked.transform = Transform3D(Basis(across, up, across.cross(up)), on_grade(at, LOT_LEVEL))
	var car := Car.new()
	parked.add_child(car)
	car.build(data)
	var size: Vector3 = data.size
	Kit.collider(parked, Vector3(0, .61, 0), Vector3(size.x * .94, .83, size.z * .96))
	Kit.collider(parked, Vector3(0, 1.14, .22), Vector3(size.x * .72, .49, size.z * .51))


func build_storefronts() -> void:
	var dark := Color("#3e4643")
	var silver := Color("#b5b4a8")
	var teal := Color("#547871")
	var wine := Color("#664b42")
	var white := Color("#c9c6b6")
	var navy := Color("#354754")
	var oak := Color("#775e49")

	# One window and door module serves each tenant, with tenant-specific
	# mullions, sign panels, and bay proportions.
	store_window(front_at(.95), front_axis, 4.50, 2.54, silver)
	store_door(front_at(5.74), front_axis, 3.61, silver)
	store_window(front_at(9.63), front_axis, 4.37, 2.54, silver)
	store_window(front_at(14.28), front_axis, 3.58, 2.54, silver)
	store_window(front_at(18.95), front_axis, 3.26, 2.42, wine)
	store_door(front_at(22.43), front_axis, 2.20, silver)
	store_window(front_at(25.70), front_axis, 3.37, 2.54, teal)
	store_door(front_at(29.27), front_axis, 2.14, dark)
	store_window(front_at(32.50), front_axis, 4.03, 2.57, white)
	store_door(front_at(36.77), front_axis, 2.83, white)

	store_window(corner + return_axis * .46, return_axis, 3.71, 2.55, white)
	store_door(corner + return_axis * 4.43, return_axis, 2.89, white)
	store_window(corner + return_axis * 8.01, return_axis, 2.46, 2.48, navy)
	store_window(corner + return_axis * 12.18, return_axis, 4.42, 2.46, oak)
	store_door(corner + return_axis * 16.84, return_axis, 2.52, oak)
	store_window(corner + return_axis * 20.19, return_axis, 3.13, 2.30, oak)

	build_canopy(front, front_axis, .18, front_length - 2.35,
		[.45, 5.12, 9.60, 14.17, 18.29, 22.20, 25.30, 29.01, 32.12, 36.09])
	build_canopy(corner, return_axis, 2.15, return_length - .30,
		[3.45, 7.70, 11.54, 16.64, 19.92, 23.58])

	var fascia := front_at(9.24, .90) + Vector3.UP * (roof_level + .25)
	var basis := Basis(front_axis, Vector3.UP, front_normal)
	for u: float in [2.45, 9.24, 16.03]:
		detail_box(front_at(u, .19) + Vector3.UP * (roof_level - .07),
			Vector3(.13, .14, 1.14), FLASHING, basis)
	detail_box(fascia, Vector3(17.1, 1.65, .36), Color("#dbd7ca"), basis)
	detail_box(fascia + front_normal * .204, Vector3(16.78, 1.30, .085), Color("#f7c53e"), basis)
	trail_emblem(fascia - front_axis * 6.72 + front_normal * .255)
	sign_label("TIGER TRAIL MARKET", fascia + front_axis * .75 + front_normal * .267, basis,
		13.45, .78, Color("#29281f"))

	tenant_sign("CHALK RIVER LAUNDRY", front_at(21.94), front_axis, 5.72, Color("#e7ddd0"), wine)
	tenant_sign("RIVER FIT", front_at(28.57), front_axis, 5.14, Color("#315952"), Color("#f1ebd9"))
	tenant_sign("DOLLAR KING", front_at(35.12), front_axis, 5.40, CREAM, Color("#243e74"))
	tenant_sign("DOLLAR KING", corner + return_axis * 6.12, return_axis, 5.65, CREAM, Color("#243e74"))
	tenant_sign("RIVER BEND COFFEE", corner + return_axis * 17.77, return_axis, 6.06,
		Color("#674d3c"), Color("#f4e4c7"))

	build_baskets(front_at(10.03, .70))
	build_bench(corner + return_axis * 7.8 + return_normal * 3.85, return_axis)


func build_champlain_frontage() -> void:
	var start := wall_point(footprint.walls[SIDE][0])
	var end := wall_point(footprint.walls[SIDE][1])
	var length := start.distance_to(end)
	var along := (end - start).normalized()
	var normal := along.cross(Vector3.UP)
	var basis := Basis(along, Vector3.UP, normal)
	var glazing_band := Color("#bbb6a7")
	for i in range(1, 6):
		var station := float(i) * 4.45 + .15
		var at := start + along * station
		store_window(at, along, 3.46, 2.28, glazing_band)
		var eave := at + along * 1.73 + Vector3.UP * (canopy_level - .13)
		detail_box(eave + normal * .30, Vector3(3.77, .145, .66), CREAM, basis)
		detail_box(eave + normal * .62 - Vector3.UP * .036,
			Vector3(3.77, .20, .082), FLASHING, basis)
	detail_box(start + along * length * .5 + Vector3.UP * (canopy_level + .56) + normal * .055,
		Vector3(length - .66, .13, .13), FLASHING, basis)


func build_canopy(start: Vector3, along: Vector3, left: float, right: float,
		posts: Array[float]) -> void:
	var normal := along.cross(Vector3.UP)
	var basis := Basis(along, Vector3.UP, normal)
	var center := start + along * ((left + right) * .5) + Vector3.UP * canopy_level
	var span := right - left
	detail_box(center + normal * 1.17, Vector3(span, .23, 2.42), Color("#c8bcaa"), basis)
	detail_box(center + normal * 2.33 - Vector3.UP * .04,
		Vector3(span, .45, .18), CREAM, basis)
	detail_box(center + normal * 2.38 + Vector3.UP * .205,
		Vector3(span + .03, .078, .17), FLASHING, basis)
	detail_box(center + normal * 2.38 - Vector3.UP * .244,
		Vector3(span, .055, .105), Color("#ab9e89"), basis)
	detail_box(center + normal * 1.16 + Vector3.UP * .135,
		Vector3(span, .052, 2.39), Color("#787f7b"), basis)
	for u in posts:
		var foot := on_grade(start + along * u + normal * 2.17, .184)
		build_column(foot, canopy_level - .15, .078)
	for i in ceili(span / 4.35):
		var light := start + along * (left + 1.45 + i * 4.35)
		detail_box(light + Vector3.UP * (canopy_level - .13) + normal * 1.10,
			Vector3(.66, .065, .17), Color("#eee0c0"), basis)


func store_window(at: Vector3, along: Vector3, width: float, height: float, color: Color) -> void:
	var normal := along.cross(Vector3.UP)
	var ground_line := grade(at + along * width * .5) + .185
	at.y = ground_line + .32
	at += normal * .045
	var basis := Basis(along, Vector3.UP, normal)
	detail_box(at + along * width * .5 + Vector3.UP * (height * .5 - .17),
		Vector3(width + .03, height - .30, .10), color, basis)
	detail_box(at + along * width * .5 - Vector3.UP * .039,
		Vector3(width + .15, .105, .27), Color("#b1a397"), basis)
	var panes := maxi(2, roundi(width / 1.28))
	var pitch := width / panes
	for i in panes:
		var left := at + along * (pitch * i + .048) + normal * .061
		glass_panel(left + Vector3.UP * .049, along, pitch - .096, height - .86, Color("#7c8d8a"))
		glass_panel(left + Vector3.UP * (height - .74), along, pitch - .096, .34, Color("#9a9f8d"))


func store_door(at: Vector3, along: Vector3, width: float, color: Color) -> void:
	var normal := along.cross(Vector3.UP)
	at.y = grade(at + along * width * .5) + .183
	at += normal * .054
	var basis := Basis(along, Vector3.UP, normal)
	detail_box(at + along * width * .5 + Vector3.UP * 1.39, Vector3(width, 2.78, .125), color, basis)
	detail_box(at + along * width * .5 + normal * .065 + Vector3.UP * .025,
		Vector3(width + .07, .057, .23), Color("#b4ada1"), basis)
	var leaf := width * .5
	for i in 2:
		var panel := at + along * (i * leaf + .077) + normal * .078
		glass_panel(panel + Vector3.UP * .15, along, leaf - .154, 1.93, Color("#6f8788"))
		glass_panel(panel + Vector3.UP * 2.20, along, leaf - .154, .493, Color("#9a9f8d"))
		var edge := leaf - .077 if i == 0 else .077
		detail_box(at + along * (i * leaf + edge) + normal * .138 + Vector3.UP * 1.04,
			Vector3(.035, .34, .08), Color("#dad3bf"), basis)
		detail_box(panel + along * (leaf * .29) + Vector3.UP * .99 + normal * .005,
			Vector3(leaf * .48, .057, .016), Color("#c1b49d"), basis)


func glass_panel(at: Vector3, along: Vector3, width: float, height: float, tint: Color) -> void:
	var right := at + along * width
	var rise := Vector3.UP * height
	quad(glazing, at, right, at + rise, right + rise, along.cross(Vector3.UP),
		Vector2(0, 1), Vector2.ONE, Vector2.ZERO, Vector2(1, 0), tint)


func tenant_sign(text: String, at: Vector3, along: Vector3, width: float, background: Color, ink: Color) -> void:
	var normal := along.cross(Vector3.UP)
	var basis := Basis(along, Vector3.UP, normal)
	var center := at + normal * 2.441 + Vector3.UP * (canopy_level - .025)
	detail_box(center, Vector3(width, .49, .12), background, basis)
	sign_label(text, center + normal * .068, basis, width - .38, .35, ink)


func sign_label(text: String, at: Vector3, basis: Basis, width: float, height: float, color: Color) -> void:
	var label := Label3D.new()
	label.text = text
	var sign_font := MenuTheme.get_bold_font()
	label.font = sign_font
	label.font_size = 100
	label.pixel_size = minf(width / sign_font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, 100).x,
		height / 72.0)
	label.outline_size = 0
	label.modulate = color
	label.double_sided = false
	label.shaded = true
	add_child(label)
	label.transform = Transform3D(basis, at)


func trail_emblem(at: Vector3) -> void:
	var ink := Color("#393027")
	var accent := Color("#fff0bc")
	# An angular tiger head with two trail-like cheek stripes.
	emblem_polygon(at, [Vector2(-.57, .44), Vector2(-.26, .31), Vector2(.26, .31),
		Vector2(.57, .44), Vector2(.48, -.11), Vector2(.25, -.40), Vector2(-.25, -.40),
		Vector2(-.48, -.11)], ink)
	var face := at + front_normal * .008
	emblem_polygon(face, [Vector2(-.37, .05), Vector2(-.11, -.045),
		Vector2(-.04, -.12), Vector2(-.30, -.09)], accent)
	emblem_polygon(face, [Vector2(.37, .05), Vector2(.11, -.045),
		Vector2(.04, -.12), Vector2(.30, -.09)], accent)
	emblem_polygon(face, [Vector2(-.23, -.21), Vector2(-.06, -.245), Vector2(0, -.21),
		Vector2(.06, -.245), Vector2(.23, -.21), Vector2(.13, -.33), Vector2(-.13, -.33)], accent)


func emblem_polygon(center: Vector3, points: PackedVector2Array, color: Color) -> void:
	var indices := Geometry2D.triangulate_polygon(points)
	for i in range(0, indices.size(), 3):
		var a := points[indices[i]]
		var b := points[indices[i + 1]]
		var c := points[indices[i + 2]]
		triangle(trim, center + front_axis * a.x + Vector3.UP * a.y,
			center + front_axis * b.x + Vector3.UP * b.y, center + front_axis * c.x + Vector3.UP * c.y,
			front_normal, a, b, c, color)


func build_baskets(ground_point: Vector3) -> void:
	var at := on_grade(ground_point, .183)
	var basis := Basis(front_axis, Vector3.UP, front_normal)
	var plastic := Color("#d4a331")
	detail_box(at + Vector3.UP * .055, Vector3(.57, .11, .38), Color("#514c42"), basis)
	detail_box(at + Vector3.UP * .105, Vector3(.40, .042, .29), plastic, basis)
	for i in 7:
		var layer := at + Vector3.UP * (.23 + i * .052)
		for side: float in [-1.0, 1.0]:
			detail_box(layer + front_axis * side * .24, Vector3(.030, .038, .34), plastic, basis)
			detail_box(layer + front_normal * side * .164, Vector3(.48, .038, .030), plastic, basis)
	for side: float in [-1.0, 1.0]:
		for rib in 7:
			var p := at + front_axis * (-.205 + rib * .069) + front_normal * side * .155
			detail_box(p + Vector3.UP * .32, Vector3(.018, .42, .024), plastic.darkened(.10), basis)
		for rib in 4:
			var p := at + front_axis * side * .228 + front_normal * (-.117 + rib * .078)
			detail_box(p + Vector3.UP * .32, Vector3(.022, .42, .018), plastic.darkened(.10), basis)
	detail_box(at + Vector3.UP * .577 + front_normal * .136, Vector3(.34, .045, .035), Color("#514638"), basis)


func build_bench(ground_point: Vector3, along: Vector3) -> void:
	var normal := along.cross(Vector3.UP)
	var basis := Basis(along, Vector3.UP, normal)
	var at := on_grade(ground_point, CURB_RISE + .02)
	var wood := Color("#785f49")
	for i in 4:
		detail_box(at + Vector3.UP * .47 + normal * (-.18 + i * .116), Vector3(1.68, .054, .097), wood, basis)
	for i in 3:
		detail_box(at + Vector3.UP * (.62 + i * .105) - normal * .21,
			Vector3(1.68, .083, .045), wood, basis)
	for end: float in [-.64, .64]:
		detail_box(at + along * end + Vector3.UP * .22 + normal * .12,
			Vector3(.065, .47, .065), FLASHING, basis)
		detail_box(at + along * end + Vector3.UP * .435 - normal * .21,
			Vector3(.065, .90, .065), FLASHING, basis)
	var collider := StaticBody3D.new()
	add_child(collider)
	collider.transform = Transform3D(basis, at)
	Kit.collider(collider, Vector3(0, .29, 0), Vector3(1.68, .57, .49))


func build_corner_roof() -> void:
	var metal := surface()
	var seams := surface()
	var caps := surface()
	var eave := canopy_level + .55
	var angle := atan2(front_normal.z, front_normal.x) - TAU / 16.0
	var profile := [Vector2(3.70, eave + .02), Vector2(3.70, eave + .115),
		Vector2(3.36, eave + .28), Vector2(2.50, eave + .66), Vector2(1.91, eave + .98),
		Vector2(1.41, eave + 1.63), Vector2(.88, eave + 2.57), Vector2(.10, eave + 3.88)]
	var ribs_per_side := 6
	for side in 8:
		var radial_a := Vector3(cos(angle + TAU * side / 8.0), 0, sin(angle + TAU * side / 8.0))
		var radial_b := Vector3(cos(angle + TAU * (side + 1) / 8.0), 0, sin(angle + TAU * (side + 1) / 8.0))
		var a := cupola + radial_a * 3.38
		var b := cupola + radial_b * 3.38
		var normal := (radial_a + radial_b).normalized()
		build_arch(a, b, normal, eave)
		triangle(caps, cupola + Vector3.UP * (eave - .055), a + Vector3.UP * (eave - .055),
			b + Vector3.UP * (eave - .055), Vector3.DOWN, Vector2.ZERO, Vector2.ZERO, Vector2.ZERO)
		# Keep the rear supports out of the surveyed shell and clear of the doors.
		var outside_front := (a - front).dot(front_normal)
		var outside_return := (a - corner).dot(return_normal)
		if maxf(outside_front, outside_return) > .62:
			build_column(on_grade(a, .181), eave - 1.01, .105)
		for level in range(1, profile.size()):
			var lower: Vector2 = profile[level - 1]
			var upper: Vector2 = profile[level]
			var outside := normal if level == 1 else (normal + Vector3.UP * .60).normalized()
			ground_quad(metal, roof_ring(radial_a, lower), roof_ring(radial_b, lower),
				roof_ring(radial_a, upper), roof_ring(radial_b, upper), outside)
			if level == 1:
				continue
			for rib in ribs_per_side:
				var ray := radial_a.lerp(radial_b, float(rib) / ribs_per_side)
				var across := (radial_b - radial_a).normalized()
				var low := roof_ring(ray, lower)
				var high := roof_ring(ray, upper)
				var raised := Vector3.UP * .028 + ray * .020
				var width := .017 if upper.x > 1.0 else .010
				ground_quad(seams, low - across * width, low + raised,
					high - across * width, high + raised, outside)
				ground_quad(seams, low + raised, low + across * width,
					high + raised, high + across * width, outside)
	finish(metal, Kit.paint(Color("#78919b"), .47, .36), "CupolaMetal")
	finish(seams, Kit.paint(Color("#a0aeb1"), .46, .28), "StandingSeams")
	finish(caps, Kit.paint(CREAM.darkened(.12)), "CupolaSoffit")
	var finial := CylinderMesh.new()
	finial.radial_segments = 10
	finial.height = .26
	finial.top_radius = .018
	finial.bottom_radius = .119
	Kit.mesh_at(self, finial, cupola + Vector3.UP * (eave + 4.00), Kit.paint(FLASHING, .49, .41))


func roof_ring(ray: Vector3, ring: Vector2) -> Vector3:
	return cupola + ray * ring.x + Vector3.UP * ring.y


func build_arch(a: Vector3, b: Vector3, normal: Vector3, eave: float) -> void:
	var along := (b - a).normalized()
	var width := a.distance_to(b)
	var segments := 18
	var soffit := Color("#b9ab93")
	for i in segments:
		var x0 := float(i) / segments
		var x1 := float(i + 1) / segments
		var front_a := a + along * width * x0
		var front_b := a + along * width * x1
		var lower_a := front_a + Vector3.UP * arch_height(x0, eave)
		var lower_b := front_b + Vector3.UP * arch_height(x1, eave)
		var top_a := front_a + Vector3.UP * eave
		var top_b := front_b + Vector3.UP * eave
		ground_quad(trim, lower_a, lower_b, top_a, top_b, normal, CREAM)
		ground_quad(trim, lower_a - normal * .20, lower_b - normal * .20,
			top_a - normal * .20, top_b - normal * .20, -normal, soffit)
		ground_quad(trim, lower_a, lower_b, lower_a - normal * .20, lower_b - normal * .20,
			Vector3.DOWN, soffit)
		var lip := normal * .032
		ground_quad(trim, lower_a + lip, lower_b + lip, lower_a + lip + Vector3.UP * .106,
			lower_b + lip + Vector3.UP * .106, normal, CREAM.lightened(.13))


func arch_height(t: float, eave: float) -> float:
	var radius := (t - .5) / .43
	return eave - 1.02 + .75 * sqrt(maxf(0.0, 1.0 - radius * radius))


func build_column(foot: Vector3, top: float, radius: float) -> void:
	var height := top - foot.y
	var post := CylinderMesh.new()
	post.height = height
	post.radial_segments = 10
	post.bottom_radius = radius
	post.top_radius = radius * .88
	Kit.mesh_at(self, post, foot + Vector3.UP * height * .5, column_material)
	detail_box(foot + Vector3.UP * .14, Vector3(radius * 2.55, .28, radius * 2.55), Color("#cfc3ae"))
	detail_box(foot + Vector3.UP * (height - .041), Vector3(radius * 2.88, .12, radius * 2.88), CREAM)
	Kit.collider(structure, foot + Vector3.UP * height * .5, Vector3(radius * 2, height, radius * 2))


func masonry(face: Color, joint: Color, unit: Vector2, width: float) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Masonry
	material.set_shader_parameter("face_color", face)
	material.set_shader_parameter("joint_color", joint)
	material.set_shader_parameter("block_size", unit)
	material.set_shader_parameter("joint_width", width)
	return material


func pavement(scan: Texture2D, color: Color) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = Pavement
	material.set_shader_parameter("asphalt_scan", scan)
	material.set_shader_parameter("base_color", color)
	return material


func finish(mesh: SurfaceTool, material: Material, label: String,
		collision := false, shadows := true) -> void:
	var item := Kit.mesh_at(self, mesh.commit(), Vector3.ZERO, material)
	item.name = label
	var kind := "building_shell" if label in ["FrontBrick", "SideBlock", "FlatRoof", "CupolaMetal"] \
		else "building_detail"
	Graphics.batch(item, kind)
	if collision:
		item.create_trimesh_collision()
	if not shadows:
		item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func detail_box(at: Vector3, size: Vector3, color: Color, axis := Basis.IDENTITY) -> void:
	var x := axis.x * size.x * .5
	var y := axis.y * size.y * .5
	var z := axis.z * size.z * .5
	for direction: float in [-1.0, 1.0]:
		var end := at + x * direction
		ground_quad(trim, end - y - z, end + y - z, end - y + z, end + y + z, axis.x * direction, color)
		end = at + y * direction
		ground_quad(trim, end - x - z, end + x - z, end - x + z, end + x + z, axis.y * direction, color)
		end = at + z * direction
		ground_quad(trim, end - x - y, end + x - y, end - x + y, end + x + y, axis.z * direction, color)


func wall_face(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		start: Vector3, along: Vector3, normal: Vector3, color: Color) -> void:
	quad(mesh, a, b, c, d, normal, Vector2((a - start).dot(along), a.y),
		Vector2((b - start).dot(along), b.y), Vector2((c - start).dot(along), c.y),
		Vector2((d - start).dot(along), d.y), color)


func ground_quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		normal: Vector3, color := Color.WHITE) -> void:
	quad(mesh, a, b, c, d, normal, roof_uv(a), roof_uv(b), roof_uv(c), roof_uv(d), color)


static func surface() -> SurfaceTool:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	return mesh


static func quad(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		outward: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, uv_d: Vector2,
		color := Color.WHITE) -> void:
	triangle(mesh, a, b, c, outward, uv_a, uv_b, uv_c, color)
	triangle(mesh, b, d, c, outward, uv_b, uv_d, uv_c, color)


static func triangle(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3,
		outward: Vector3, uv_a: Vector2, uv_b: Vector2, uv_c: Vector2, color := Color.WHITE) -> void:
	var normal := (c - a).cross(b - a)
	if normal.length_squared() < .00000001:
		return
	var reverse := normal.dot(outward) < 0.0
	mesh.set_normal((-normal if reverse else normal).normalized())
	mesh.set_color(color)
	mesh.set_uv(uv_a)
	mesh.add_vertex(a)
	mesh.set_uv(uv_c if reverse else uv_b)
	mesh.add_vertex(c if reverse else b)
	mesh.set_uv(uv_b if reverse else uv_c)
	mesh.add_vertex(b if reverse else c)
