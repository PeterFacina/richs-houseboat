extends RefCounted

const Kit = preload("res://scenery.gd")

# The long north edge follows the row of spaces in the aerial reference.
# Both throats reach the respective street centerlines, then clip to the road mesh.
const LOT := [
	Vector2(17974, 13325.2), Vector2(17985, 13325.2), Vector2(17988.2, 13322.7),
	Vector2(17989.4, 13312.5), Vector2(18008.7, 13312.1), Vector2(18024, 13317.7),
	Vector2(18037.5, 13328.3), Vector2(18043.3, 13330.4), Vector2(18049.6, 13324.2),
	Vector2(18051, 13322.9), Vector2(18068.8, 13323.15), Vector2(18073.9, 13325),
	Vector2(18076.7, 13331), Vector2(18076.4, 13340.6), Vector2(18073.0, 13346.1),
	Vector2(18075.0, 13351.1), Vector2(18074.3, 13356.6), Vector2(18077.1, 13360.8),
	Vector2(18081.6, 13364.0), Vector2(18074.2, 13369.5), Vector2(18070.2, 13364.2),
	Vector2(18064, 13359), Vector2(18056, 13354.5), Vector2(18046.7, 13348.9),
	Vector2(18037, 13341.3), Vector2(18030.5, 13343), Vector2(18021.5, 13342.6),
	Vector2(18010.2, 13339.8), Vector2(17996, 13336.65), Vector2(17987, 13335.8),
	Vector2(17983.3, 13333.4), Vector2(17974, 13333.4),
]
const APRON := [
	Vector2(18026.92, 13381.66), Vector2(18047.60, 13357.18),
	Vector2(18055.8, 13363.0), Vector2(18060.4, 13369.8),
	Vector2(18056, 13383.1), Vector2(18036.9, 13393.65),
]
const BOUNDS := Rect2(17973, 13311, 110, 84)
const ORIGIN := Vector2(18020, 13348)
const PAVING_LIFT := .050
const PAINT_LIFT := .071
const CELL := 1.55

var ground: Callable


static func covers(point: Vector2) -> bool:
	return BOUNDS.has_point(point) and (Geometry2D.is_point_in_polygon(point, PackedVector2Array(LOT))
		or Geometry2D.is_point_in_polygon(point, PackedVector2Array(APRON)))


func build(parent: Node3D, elevation: Callable, asphalt: ShaderMaterial, road_edges: Array[PackedVector2Array],
		road_layer: int) -> void:
	ground = elevation
	var site := Node3D.new()
	site.name = "TownHallParking"
	parent.add_child(site)
	site.position = Vector3(ORIGIN.x, 0, ORIGIN.y)
	var paving := SurfaceTool.new()
	paving.begin(Mesh.PRIMITIVE_TRIANGLES)
	for outline: Array in [LOT, APRON]:
		tessellate(paving, PackedVector2Array(outline), road_edges)
	paving.generate_normals()
	var mesh := Kit.mesh_at(site, paving.commit(), Vector3.ZERO, asphalt)
	mesh.name = "ParkingAsphalt"
	mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	mesh.create_trimesh_collision()
	(mesh.get_child(0) as StaticBody3D).collision_layer |= road_layer
	build_markings(site)


func tessellate(surface: SurfaceTool, outline: PackedVector2Array, road_edges: Array[PackedVector2Array]) -> void:
	var local := PackedVector2Array()
	var bounds := Rect2(outline[0] - ORIGIN, Vector2.ZERO)
	for point in outline:
		local.append(point - ORIGIN)
		bounds = bounds.expand(point - ORIGIN)
	var rows := ceili(bounds.size.y / CELL)
	var cols := ceili(bounds.size.x / CELL)
	for row in rows:
		for col in cols:
			var at := bounds.position + Vector2(col, row) * CELL
			var cell := PackedVector2Array([at, at + Vector2(CELL, 0), at + Vector2(CELL, CELL), at + Vector2(0, CELL)])
			var parts := Geometry2D.intersect_polygons(local, cell)
			for road in road_edges:
				if parts.is_empty():
					break
				var remainder: Array[PackedVector2Array] = []
				for part in parts:
					remainder.append_array(Geometry2D.clip_polygons(part, road))
				parts = remainder
			for part in parts:
				for i in Geometry2D.triangulate_polygon(part):
					var p := part[i]
					var world := ORIGIN + p
					surface.set_color(Color.BLACK)
					surface.set_uv(Vector2.ZERO)
					surface.set_uv2(Vector2.ZERO)
					surface.add_vertex(Vector3(p.x, ground.call(world.x, world.y) + PAVING_LIFT, p.y))


func build_markings(parent: Node3D) -> void:
	var paint := SurfaceTool.new()
	paint.begin(Mesh.PRIMITIVE_TRIANGLES)
	stalls(paint, Vector2(17990.7, 13313.3), Vector2(18008.1, 13312.9), Vector2(.12, 1), 6)
	stalls(paint, Vector2(18013.2, 13314.7), Vector2(18036.6, 13329), Vector2(-.56, .83), 8)
	stalls(paint, Vector2(18050.4, 13325.0), Vector2(18070, 13325.1), Vector2(0, 1), 7)
	stalls(paint, Vector2(18075.5, 13331.3), Vector2(18074.45, 13340.1), Vector2(-1, -.07), 4)
	stalls(paint, Vector2(18072.3, 13353.5), Vector2(18073.5, 13357.5), Vector2(-.90, -.32), 2)
	stalls(paint, Vector2(18002.8, 13337.4), Vector2(18018.7, 13341.15), Vector2(.24, -.97), 6)
	stalls(paint, Vector2(18043, 13345.2), Vector2(18054, 13353.5), Vector2(.61, -.8), 5)
	# Striped access aisle next to the spaces behind the civic entrance.
	var aisle := Vector2(18020.0, 13340.7)
	var access := Vector2(.23, -.97)
	var across := Vector2(1, .24).normalized()
	for i in 7:
		var start := aisle + access * (float(i) * .66 + .32)
		mark(paint, start, start + across * 1.47 + access * .41, .11)
	mark(paint, aisle, aisle + access * 4.8, .096)
	mark(paint, aisle + across * 1.64, aisle + across * 1.64 + access * 4.8, .096)
	paint.generate_normals()
	var marks := Kit.mesh_at(parent, paint.commit(), Vector3.ZERO, Kit.paint(Color("#dedbd0"), .93))
	marks.name = "ParkingMarkings"
	marks.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func stalls(surface: SurfaceTool, a: Vector2, b: Vector2, inward: Vector2, lines: int) -> void:
	for i in lines:
		var head := a.lerp(b, float(i) / (lines - 1))
		mark(surface, head, head + inward.normalized() * 4.8, .092)


func mark(surface: SurfaceTool, start: Vector2, finish: Vector2, width: float) -> void:
	var direction := (finish - start).normalized()
	var edge := direction.orthogonal() * width * .5
	var steps := ceili(start.distance_to(finish) / .68)
	for i in steps:
		var a := start.lerp(finish, float(i) / steps)
		var b := start.lerp(finish, float(i + 1) / steps)
		if not covers(a) or not covers(b):
			continue
		for point in [a - edge, a + edge, b - edge, a + edge, b + edge, b - edge]:
			var local: Vector2 = point - ORIGIN
			surface.add_vertex(Vector3(local.x, ground.call(point.x, point.y) + PAINT_LIFT, local.y))
