extends RefCounted

const DAYS := ["Monday", "Tuesday", "Wednesday", "Thursday", "Friday", "Saturday", "Sunday"]
const MINUTES_PER_DAY := 1440
const MINUTES_PER_SECOND := 0.8
const FILE := "res://mowing_routes.json"
const PARK := [
	Vector2(7.5, -10), Vector2(14, -12.5), Vector2(25, -14.5), Vector2(33, -14),
	Vector2(29, -6), Vector2(24, .5), Vector2(17, 7.5), Vector2(7.5, 11.5),
]


static func bounds(polygon: PackedVector2Array) -> Rect2:
	var area := Rect2(polygon[0], Vector2.ZERO)
	for point in polygon:
		area = area.expand(point)
	return area


static func load_routes(pavilion: Vector2) -> Array[Dictionary]:
	var routes: Array[Dictionary] = []
	var custom: Variant = JSON.parse_string(FileAccess.get_file_as_string(FILE))
	for day in DAYS.size():
		var route := {"name": "Marina lawn %d" % (day + 1), "zones": starter_zones(day, pavilion)}
		if custom is Dictionary and custom.get(DAYS[day]) is Dictionary:
			var entry: Dictionary = custom[DAYS[day]]
			var zones: Array[PackedVector2Array] = []
			if entry.get("zones") is Array:
				for vertices: Variant in entry.zones:
					var polygon := PackedVector2Array()
					if vertices is Array:
						for vertex: Variant in vertices:
							if vertex is Array and vertex.size() == 2 and is_number(vertex[0]) and is_number(vertex[1]):
								polygon.append(Vector2(vertex[0], vertex[1]))
					if polygon.size() >= 3 and Geometry2D.triangulate_polygon(polygon).size() >= 3:
						zones.append(polygon)
			if not zones.is_empty():
				route = {"name": str(entry.get("name", DAYS[day] + " route")), "zones": zones}
		routes.append(route)
	return routes


static func is_number(value: Variant) -> bool:
	return value is float or value is int


static func starter_zones(day: int, pavilion: Vector2) -> Array[PackedVector2Array]:
	var edges := [7.5, 9.5, 11.8, 14.3, 17.3, 20.9, 25.5, 33.0]
	var left: float = edges[day]
	var right: float = edges[day + 1]
	var band := PackedVector2Array([Vector2(left, -16), Vector2(right, -16),
		Vector2(right, 13), Vector2(left, 13)])
	var zones := Geometry2D.intersect_polygons(PackedVector2Array(PARK), band)
	for index in zones.size():
		var polygon := zones[index]
		for vertex in polygon.size():
			polygon[vertex] += pavilion
		zones[index] = polygon
	return zones
