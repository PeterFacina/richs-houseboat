extends RefCounted

# Residential parts share each town chunk's trim, glass and collision batches.
const ROAD_CELL := 128.0
const ROAD_SEARCH := 100.0
const STONE := Color("#a29f93")
const GUTTER := Color("#484946")
const GLASS := Color("#4a606f")
const CLADDING := [
	Color("#d6cfbb"), Color("#d5d7cf"), Color("#b7ab91"), Color("#a6b2a9"),
	Color("#b1b9bd"), Color("#c9c1ab"), Color("#a49b87"), Color("#bdc6b5"),
]
const DOORS := [
	Color("#47646b"), Color("#6f4436"), Color("#e0d9c6"), Color("#353c41"),
	Color("#566155"), Color("#79483f"), Color("#6a5b48"),
]

var roads := {}
var frames: SurfaceTool
var glass: SurfaceTool
var steps: SurfaceTool
var ground: Callable
var panel: Callable
var seed := 0
var building: Dictionary
var height := 0.0
var compact := false
var front := -1
var pedestrian_entries: Array[Dictionary] = []
var trim := Color.WHITE
var door := Color.WHITE
var handed := 1.0
var roof_axis := Vector2.RIGHT
var roof_form := 0.0
var roof_tone := 0.0
var roof_fill: Array[Vector3] = []


func catalogue(streets: Array) -> void:
	for line: Array in streets:
		for i in range(1, line.size()):
			var a := Vector2(line[i - 1][0], line[i - 1][1])
			var b := Vector2(line[i][0], line[i][1])
			if a.distance_squared_to(b) < .01:
				continue
			var limits := Rect2(a, Vector2.ZERO).expand(b).grow(ROAD_SEARCH)
			var first := Vector2i((limits.position / ROAD_CELL).floor())
			var last := Vector2i((limits.end / ROAD_CELL).floor())
			for x in range(first.x, last.x + 1):
				for z in range(first.y, last.y + 1):
					var cell := Vector2i(x, z)
					if not roads.has(cell):
						roads[cell] = []
					roads[cell].append([a, b])


static func accepts(footprint: Dictionary, authored: Dictionary) -> bool:
	return authored.is_empty() and footprint.windows == "house" and footprint.detail == null and footprint.name == null


func prepare(footprint: Dictionary, facade_height: float) -> Color:
	building = footprint
	height = facade_height
	seed = posmod(hash(str(building.id)), 1000003)
	var footprint_area := polygon_area(building.walls)
	compact = int(building.floors) == 1 and (footprint_area < 37.0 or height < 2.65)
	front = street_face()
	var edge: Array = building.walls[front]
	roof_axis = Vector2(edge[1][0] - edge[0][0], edge[1][1] - edge[0][1]).normalized()
	trim = Color("#e4dfce").lerp(Color(building.trim), .28)
	door = DOORS[floori(seed / 7.0) % DOORS.size()]
	var rise := 0.0
	for point: Array in building.roof:
		rise = maxf(rise, float(point[2]))
	roof_form = 0.0 if rise < .38 else (1.0 if rise > 1.02 else .5)
	roof_fill.clear()
	if rise < .12 and seed % 5 != 0:
		add_low_hip()
	roof_tone = clampf(float(seed % 8) / 9.0 + Color(building.wall).v * .15, 0.0, 1.0)
	handed = 1.0 if seed % 2 == 0 else -1.0
	var paint := Color(building.wall).lerp(CLADDING[seed % CLADDING.size()], .72)
	# The wall shader gives this range lapped courses and a foundation band.
	paint.a = .66 if seed % 7 != 0 or compact else .74
	return paint


# Give rectangular roof placeholders a modest pitch using their existing eaves.
func add_low_hip() -> void:
	if building.walls.size() != 4:
		return
	var corners: Array[Vector3] = []
	for edge: Array in building.walls:
		corners.append(Vector3(edge[0][0], 0, edge[0][1]))
	var across := corners[3] - corners[0]
	var along := corners[1] - corners[0]
	if minf(along.length(), across.length()) < 2.5 \
			or absf(along.normalized().dot(across.normalized())) > .12 \
			or corners[0].distance_to(corners[1] + corners[3] - corners[2]) > .28:
		return
	if across.length_squared() > along.length_squared():
		corners.push_back(corners.pop_front())
		across = corners[3] - corners[0]
		along = corners[1] - corners[0]
	var run := across.length()
	var inset := minf(run * .35, along.length() * .43)
	var slope := clampf(run * (.10 if compact else .13), .38, 1.38)
	var ridge_a := (corners[0] + corners[3]) * .5 + along.normalized() * inset + Vector3.UP * slope
	var ridge_b := (corners[1] + corners[2]) * .5 - along.normalized() * inset + Vector3.UP * slope
	roof_fill.assign([corners[0], corners[1], ridge_b, corners[0], ridge_b, ridge_a,
		corners[1], corners[2], ridge_b, corners[2], corners[3], ridge_a,
		corners[2], ridge_a, ridge_b, corners[3], corners[0], ridge_a])
	roof_axis = Vector2(along.x, along.z).normalized()
	roof_form = 1.0


func parking_outbuilding() -> bool:
	return height > 2.04 and polygon_area(building.walls) >= 19.5


func roof_coordinate(point: Vector3) -> Vector2:
	var delta := Vector2(point.x - building.center[0], point.z - building.center[1])
	return Vector2(delta.dot(roof_axis), delta.dot(roof_axis.orthogonal()))


func polygon_area(walls: Array) -> float:
	var origin: Array = walls[0][0]
	var sum := 0.0
	for edge: Array in walls:
		sum += (float(edge[0][0]) - float(origin[0])) * (float(edge[1][1]) - float(origin[1])) \
			- (float(edge[1][0]) - float(origin[0])) * (float(edge[0][1]) - float(origin[1]))
	return absf(sum) * .5


func street_face() -> int:
	var center := Vector2(building.center[0], building.center[1])
	var nearest := center
	var distance := ROAD_SEARCH * ROAD_SEARCH
	var cell := Vector2i((center / ROAD_CELL).floor())
	for edge: Array in roads.get(cell, []):
		var at := Geometry2D.get_closest_point_to_segment(center, edge[0], edge[1])
		var d := at.distance_squared_to(center)
		if d < distance:
			nearest = at
			distance = d
	var direction := (nearest - center).normalized()
	var best := -INF
	var result := 0
	for i in building.walls.size():
		var edge: Array = building.walls[i]
		var a := Vector2(edge[0][0], edge[0][1])
		var b := Vector2(edge[1][0], edge[1][1])
		var line := b - a
		var length := line.length()
		if length < (2.25 if compact else 3.1):
			continue
		var facing := (Vector2(-line.y, line.x) / length).dot(direction)
		var score := (facing * 4.0) + minf(length, 14.0) * .17
		if score > best:
			best = score
			result = i
	return result


func facade(index: int, at: Vector3, along: Vector3, normal: Vector3, width: float,
		top_a: Vector3, top_b: Vector3) -> void:
	if width < .25:
		return
	var azimuth := Basis(along, Vector3.UP, normal)
	var face := Transform3D(azimuth, at)
	var slope := (top_b - top_a).normalized()
	var roof_normal := slope.cross(Vector3.UP).normalized()
	panel.call(frames, top_a + roof_normal * .043 - Vector3.UP * .099, slope, roof_normal,
		top_a.distance_to(top_b), .106, trim, roof_normal.cross(slope).normalized())
	if width < 2.1:
		return
	for x in [.034, width - .119]:
		face_piece(face, x, .35, .085, height - .47, trim, .027)
	if absf(top_a.y - at.y - height) < .08 and absf(top_b.y - at.y - height) < .08:
		panel.call(frames, at + Vector3.UP * (height - .14) + normal * .092, along, normal, width,
			.082, GUTTER)
		if index == front or index == (front + 2) % building.walls.size():
			var x := width - .23
			var foot := face * Vector3(x, 0, .08)
			var grade: float = ground.call(foot.x, foot.z)
			var down := clampf(grade - at.y + .15, -.65, height - .6)
			face_piece(face, x - .043, down, .086, height - .15 - down, GUTTER, .052)
			block(frames, face, Vector3(x, down + .039, .151), Vector3(.088, .069, .211), GUTTER)
	if compact:
		utility_face(index, face, width)
		return
	var floors := clampi(int(building.floors), 1, 6)
	var course := height / floors
	var threshold := .34 if course >= 2.7 else .20
	if index == front and width >= 3.35 and course > 2.08:
		entry_face(face, width, course, threshold)
	else:
		wall_windows(face, width, course, 0, index)
	for storey in range(1, floors):
		wall_windows(face, width, course, storey, index)
	if index == front and floors == 1 and building.roof.size() > 6:
		var top := minf(top_a.y, top_b.y) - at.y
		if top > height + .66 and width > 4.2:
			vent(face, width * .5, height + .36)


func utility_face(index: int, face: Transform3D, width: float) -> void:
	if index == front and width >= 2.5 and height >= 1.92:
		var wide := minf(width * .64, 3.6)
		var y := .083
		var rise := minf(height - .25, 2.28)
		var left := (width - wide) * .5
		face_piece(face, left - .085, y, wide + .17, rise + .085, trim)
		face_piece(face, left, y, wide, rise, door, .041)
		for i in 4:
			face_piece(face, left + .025, y + rise * (i + 1) / 5.0, wide - .05, .023, door.darkened(.29), .052)
	elif width > 3.3 and height > 1.85 and (seed + index) % 3 == 0:
		window(face, width * .5, height * .52, .68, .54, false, false)


func entry_fraction() -> float:
	var edge: Array = building.walls[front]
	var width := Vector2(edge[0][0], edge[0][1]).distance_to(Vector2(edge[1][0], edge[1][1]))
	var offset := .24 if width < 9.7 else .06
	return .5 + handed * offset


func entry_face(face: Transform3D, width: float, course: float, threshold: float) -> void:
	var left := handed < 0.0
	var entry_x := width * entry_fraction()
	var opening := minf(2.08, course - threshold - .11)
	var outer := .58
	face_piece(face, entry_x - outer, threshold - .028, outer * 2.0, opening + .13, trim, .034)
	face_piece(face, entry_x - .456, threshold, .912, opening, door, .053)
	var tint := "#647e89" if seed % 3 == 0 else "#506574"
	panel.call(glass, face * Vector3(entry_x - .30, threshold + opening * .58, .067),
		face.basis.x, face.basis.z, .60, minf(.56, opening * .31), Color(tint))
	face_piece(face, entry_x - .315, threshold + .18, .63, opening * .26, door.darkened(.15), .061)
	face_piece(face, entry_x + .316 * handed, threshold + .94, .058, .058, Color("#a09262"), .080)
	var light_x := entry_x - handed * .79
	block(frames, face, Vector3(light_x, threshold + opening - .08, .092),
		Vector3(.145, .235, .15), Color("#464847"))
	face_piece(face, light_x - .041, threshold + opening - .137, .082, .114, Color("#d8c391"), .174)

	var opposite := width * (.67 if left else .33) if width >= 9.7 else width - entry_x
	var space := absf(opposite - entry_x)
	if space > 1.2:
		var picture := minf(2.54, minf(space * .83, width * .40))
		window(face, opposite, threshold + minf(.69, course * .28), picture,
			minf(1.40, course * .47), true, seed % 5 == 1)
	elif width > 5.4:
		window(face, width * (.19 if left else .81), threshold + .60, minf(1.55, width * .24),
			minf(1.22, course * .42), false, seed % 5 == 1)
	if width > 9.8:
		var second := width * (.81 if handed > 0.0 else .19)
		window(face, second, threshold + .72, minf(1.56, width * .17), minf(1.24, course * .42), false, false)
	var approach := build_stoop(face, entry_x, threshold, opening, width)
	var landing := face * Vector3(entry_x, threshold, .43)
	var foot := face * Vector3(entry_x, 0, approach)
	foot.y = ground.call(foot.x, foot.z) + .045
	if absf(landing.y - foot.y) <= 1.23:
		pedestrian_entries.append({"id": str(building.id), "door": landing, "foot": foot,
			"out": face.basis.z})
	entry_details(face, entry_x, opening, threshold, width)
	foundation_planting(face, entry_x, width)


func wall_windows(face: Transform3D, width: float, course: float, storey: int, side: int) -> void:
	var bays := clampi(roundi(width / (3.55 if storey == 0 else 3.1)), 1, 9)
	var space := width / bays
	for bay in bays:
		if side != front and bays >= 3 and (bay + side + seed) % 5 == 0:
			continue
		var x := space * (bay + .5)
		var sill := course * storey + course * (.36 if storey == 0 else .28)
		var span := clampf(space * (.49 if storey == 0 else .54), .54, 1.72)
		window(face, x, sill, span, clampf(course * .45, .52, 1.48), false,
			side == front and seed % 4 == 0 and space > 2.4)


func window(face: Transform3D, x: float, y: float, width: float, rise: float, picture: bool, shutters: bool) -> void:
	var left := x - width * .5
	var base := face * Vector3(left, y, 0)
	if base.y < float(ground.call(base.x, base.z)) + .08:
		return
	face_piece(face, left - .05, y - .042, width + .10, rise + .089, trim, .029)
	panel.call(glass, face * Vector3(left + .068, y + .066, .049), face.basis.x, face.basis.z,
		width - .136, rise - .132, GLASS.darkened(float(seed % 6) * .043))
	if picture:
		for seam in [-.27, .27]:
			face_piece(face, x + width * seam - .029, y + .048, .058, rise - .096, trim, .065)
	else:
		face_piece(face, left + .05, y + rise * .52, width - .10, .051, trim, .064)
	face_piece(face, left - .078, y - .077, width + .156, .061, trim.darkened(.10), .081)
	if picture:
		block(frames, face, Vector3(x, y - .061, .071), Vector3(width + .15, .069, .16), trim.darkened(.14))
		if seed % 5 == 2:
			face_piece(face, left + .12, y + rise * .71, width - .24, .125, Color("#b7afa1"), .056)
	if shutters:
		var span := minf(width * .19, .31)
		for flank in [left - span - .065, left + width + .065]:
			face_piece(face, flank, y - .012, span, rise + .024, door.darkened(.13), .059)
			for row in 4:
				face_piece(face, flank + .018, y + rise * (row + 1) / 5.0, span - .036,
					.024, door.darkened(.32), .063)


func entry_details(face: Transform3D, x: float, opening: float, floor: float, width: float) -> void:
	var hardware := Color("#64635c")
	if seed % 3 == 0:
		face_piece(face, x - .173, floor + opening * .47, .346, .051, hardware, .072)
	var at := clampf(x - handed * 1.13, .29, width - .29)
	if seed % 3 != 1:
		block(frames, face, Vector3(at, floor + .97, .079), Vector3(.232, .252, .126), hardware)
		face_piece(face, at - .062, floor + .965, .124, .057, Color("#9ea4a1"), .153)
		face_piece(face, at - .019, floor + .36, .038, .496, hardware, .055)
	if width > 5.7 and seed % 4 == 2:
		var planter_x := clampf(x - handed * 1.48, .42, width - .42)
		var point := face * Vector3(planter_x, 0, .53)
		var grade: float = ground.call(point.x, point.z) - face.origin.y
		var colors := [Color("#4b6241"), Color("#657946"), Color("#7c8454")]
		block(frames, face, Vector3(planter_x, grade + .134, .53), Vector3(.52, .269, .45), Color("#7e5446"))
		for tuft in 4:
			var offset := float(tuft - 1) * .105
			var reach := .22 + float((seed + tuft * 7) % 4) * .062
			shrub(face, Vector3(planter_x + offset, grade + .23, .53 - absf(offset) * .56),
				Vector3(.18, reach, .16), colors[tuft % colors.size()])


func foundation_planting(face: Transform3D, door_x: float, width: float) -> void:
	if width < 5.1 or seed % 5 == 4:
		return
	var end := width - .68 if door_x < width * .5 else .68
	var toward := signf(door_x - end)
	var tones := [Color("#536944"), Color("#62754b"), Color("#6f8051"), Color("#405e39")]
	for i in 2 + seed % 3:
		var x := end + toward * float(i) * .49
		if absf(x - door_x) < 1.46:
			break
		var reach := .67 + float((seed + i * 13) % 4) * .05
		var at := face * Vector3(x, 0, reach)
		var grade: float = ground.call(at.x, at.z) - face.origin.y
		var size := .24 + float((seed + i * 17) % 5) * .048
		var paint: Color = tones[(seed + i) % tones.size()]
		shrub(face, Vector3(x, grade - .011, reach), Vector3(size, size * 2.0, size), paint)
		shrub(face, Vector3(x + toward * .17, grade - .016, reach + .13), Vector3(size * .63, size * 1.3, size * .65), paint.lightened(.08))


func shrub(face: Transform3D, at: Vector3, size: Vector3, paint: Color) -> void:
	var points := PackedVector3Array()
	for ring in 2:
		for side in 6:
			var angle := TAU * float(side) / 6.0 + at.x * .81
			var irregular := .90 + .14 * sin(float(seed % 57 + side * 17 + ring * 19))
			var radius := irregular * (1.0 if ring == 0 else .68)
			var y := .27 if ring == 0 else .73 + .096 * sin(float(side * 11))
			points.append(Vector3(cos(angle) * radius, y, sin(angle) * radius))
	points.append(Vector3(.09, .96, -.08))
	points.append(Vector3(0, -.16, 0))
	for side in 6:
		var next := (side + 1) % 6
		for tri: Array in [[side, next, side + 6], [next, next + 6, side + 6],
				[side + 6, next + 6, 12], [side, 13, next]]:
			for index: int in tri:
				var p := points[index]
				var light := smoothstep(.15, .94, p.y)
				frames.set_color(paint.darkened(.21 * (1.0 - light)))
				frames.set_normal(face.basis * Vector3(p.x, (p.y - .39) * 1.5, p.z).normalized())
				frames.add_vertex(face * (at + p * size))


func build_stoop(face: Transform3D, x: float, threshold: float, opening: float, width: float) -> float:
	var point := face * Vector3(x, 0, 1.50)
	var terrain: float = ground.call(point.x, point.z) - face.origin.y
	var lift := threshold - terrain
	if lift < .07 or lift > 1.12:
		return .85
	var porch := seed % 5 <= 1 and width > 5.4 and opening > 1.8
	var cover_width := 2.30 if porch else 1.39
	var depth := .82 if porch else .46
	var count := clampi(ceili(lift / .195), 1, 5)
	for i in count:
		var reach := depth + (count - i) * .25
		var top := terrain + lift * float(i + 1) / count
		var inner := reach - .25 if i < count - 1 else 0.0
		block(steps, face, Vector3(x, (top + terrain - .12) * .5, (reach + inner) * .5),
			Vector3(cover_width, top - terrain + .12, reach - inner), STONE if not porch else Color("#a09784"))
	front_path(face, x, depth + count * .25)
	if not porch:
		return depth + count * .25
	var roof_y := threshold + opening + .24
	if seed % 3 == 0:
		for side in [-1.0, 1.0]:
			var slope := Transform3D(Basis(Vector3.BACK, -side * .32), Vector3(x + side * .62, roof_y + .16, .52))
			block(frames, face * slope, Vector3.ZERO, Vector3(1.40, .14, 1.31), GUTTER)
	else:
		block(frames, face, Vector3(x, roof_y, .52), Vector3(2.54, .18, 1.31), GUTTER)
	for direction in [-1.0, 1.0]:
		var post: float = x + direction * .99
		var tall := roof_y - threshold
		block(frames, face, Vector3(post, threshold + tall * .5, .78), Vector3(.095, tall, .095), trim)
		block(frames, face, Vector3(post, threshold + .68, .42), Vector3(.065, .078, .72), trim)
		for i in 2:
			block(frames, face, Vector3(post, threshold + .32, .24 + .24 * i), Vector3(.047, .64, .046), trim)
	return depth + count * .25


func front_path(face: Transform3D, x: float, reach: float) -> void:
	for slab in 3:
		var near := reach + slab * .47
		var points := PackedVector3Array()
		for corner in [Vector2(-.52, 0), Vector2(.52, 0), Vector2(.52, .44), Vector2(-.52, .44)]:
			var at: Vector3 = face * Vector3(x + corner.x, 0, near + corner.y)
			at.y = ground.call(at.x, at.z) + .033
			points.append(at)
		steps.set_color(STONE.darkened(.08))
		steps.set_normal(Vector3.UP)
		for corner in [0, 1, 2, 0, 2, 3]:
			steps.add_vertex(points[corner])


func vent(face: Transform3D, x: float, y: float) -> void:
	face_piece(face, x - .24, y, .48, .33, GUTTER)
	for row in 4:
		face_piece(face, x - .204, y + .055 + row * .060, .408, .023, trim.darkened(.32), .045)


func face_piece(face: Transform3D, x: float, y: float, width: float, rise: float,
		tint: Color, depth := .026) -> void:
	if width > .01 and rise > .01:
		panel.call(frames, face * Vector3(x, y, depth), face.basis.x, face.basis.z, width, rise, tint)


func block(surface: SurfaceTool, face: Transform3D, at: Vector3, size: Vector3, tint: Color) -> void:
	var corner := at - size * .5
	var right := face.basis.x
	var front_axis := face.basis.z
	panel.call(surface, face * (corner + Vector3.BACK * size.z), right, front_axis, size.x, size.y, tint)
	panel.call(surface, face * (corner + Vector3.RIGHT * size.x), -right, -front_axis, size.x, size.y, tint)
	panel.call(surface, face * (corner + Vector3.RIGHT * size.x + Vector3.BACK * size.z), -front_axis,
		right, size.z, size.y, tint)
	panel.call(surface, face * corner, front_axis, -right, size.z, size.y, tint)
	panel.call(surface, face * (corner + Vector3(0, size.y, size.z)), right, Vector3.UP,
		size.x, size.z, tint, -front_axis)
	panel.call(surface, face * corner, right, Vector3.DOWN, size.x, size.z, tint, front_axis)


func chimney(eave: float) -> void:
	if compact:
		return
	var center := Vector2(building.center[0], building.center[1])
	var closest := INF
	var mount := Vector3.ZERO
	if not roof_fill.is_empty():
		mount = (roof_fill[4] + roof_fill[5]) * .5
		closest = 0.0
	for i in range(0, building.roof.size(), 3):
		var points: Array = building.roof.slice(i, i + 3)
		var a := Vector3(points[0][0], points[0][2], points[0][1])
		var b := Vector3(points[1][0], points[1][2], points[1][1])
		var c := Vector3(points[2][0], points[2][2], points[2][1])
		if absf((b - a).cross(c - a).y) < 9.0:
			continue
		var middle := (a + b + c) / 3.0
		var distance := center.distance_squared_to(Vector2(middle.x, middle.z))
		if distance < closest:
			mount = middle
			closest = distance
	if closest == INF:
		return
	mount.y += eave
	var axis := Transform3D(Basis.IDENTITY, mount)
	if seed % 4 == 0:
		block(frames, axis, Vector3(0, .26, 0), Vector3(.49, 1.13, .45), Color("#84634f"))
		block(frames, axis, Vector3(0, .848, 0), Vector3(.58, .105, .53), Color("#534945"))
	else:
		var flashing := Color("#5c6263")
		block(frames, axis, Vector3(0, .06, 0), Vector3(.25, .38, .23), flashing)
		block(frames, axis, Vector3(0, .253, 0), Vector3(.32, .07, .29), flashing.darkened(.17))
