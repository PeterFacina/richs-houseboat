extends RefCounted

# Distances are measured from the Hillcrest Avenue end of surveyed street 63.
# The May 2025 Street View traverse shows a shaded entrance, open lawns through
# the middle, and another group of mature trees beyond the bend. Keep the
# playground side of the entrance and the house/backyard sites untouched.
const STREET := 63
const HILLCREST_PINES := [Vector2(18480.5215, 13824.9229), Vector2(18460.5215, 13832.4229)]
# Keep clear of the 16 Silvie site in the pending Mario property PR.
const MARIO_SITE := Vector2(18345.5865, 13866.1102)
const MARIO_YAW := .40
const MARIO_BOUNDS := Rect2(Vector2(-9.5, -44.0), Vector2(28.0, 74.0))
const LOCAL_CANOPY_BOUNDS := Rect2(Vector2(18270.0, 13780.0), Vector2(240.0, 220.0))
const TREE_SITES := [
	# station, side of centreline, height, conifer
	[42.0, -11.0, 16.0, true],
	[55.0, 11.0, 11.0, false],
	[78.0, 11.0, 12.0, false],
	[92.0, 12.5, 14.0, false],
	[116.0, 12.0, 10.0, false],
	[125.0, 11.0, 14.0, false],
	[137.0, -7.0, 12.0, true],
	[170.0, 11.0, 12.0, false],
	[180.0, 11.0, 11.0, false],
	[204.0, 14.0, 13.0, true],
	[225.0, -8.0, 12.0, false],
]
const GARDEN_SITES := [
	# Small shrubs and ornamental trees follow visible home frontages.
	[50.0, -7.0, 2.2], [52.0, 16.0, 1.5],
	[68.0, -7.0, 2.0], [68.0, 14.0, 1.5],
	[82.0, 14.0, 1.8], [90.0, 16.0, 2.1],
	[99.0, 14.0, 1.8], [109.0, 16.0, 2.3],
	[118.0, 16.0, 2.0],
	[139.0, -7.0, 2.0],
	[159.0, -7.0, 2.1], [169.0, 16.0, 1.5],
	[179.0, -7.0, 2.0], [199.0, -7.0, 1.7],
	[199.0, 16.0, 1.9], [209.0, 18.0, 1.5],
	[219.0, -7.0, 2.0], [219.0, 12.0, 1.5],
]


static func at_station(line: Array, station: float, side: float) -> Vector2:
	var first := Vector2(line[0][0], line[0][1])
	var middle := Vector2(line[1][0], line[1][1])
	var last := Vector2(line[2][0], line[2][1])
	var first_length := first.distance_to(middle)
	var start := first if station < first_length else middle
	var end := middle if station < first_length else last
	var axis := (end - start).normalized()
	var distance := station if station < first_length else station - first_length
	return start + axis * distance + axis.orthogonal() * side


static func near_survey(point: Vector2, canopy: PackedFloat32Array, radius: float) -> bool:
	var square := radius * radius
	for i in range(0, canopy.size(), 3):
		if point.distance_squared_to(Vector2(canopy[i], canopy[i + 1])) < square:
			return true
	return false


static func replace_entrance_tree(foot: Vector3, height: float, pines: RefCounted) -> bool:
	var point := Vector2(foot.x, foot.z)
	for surveyed: Vector2 in HILLCREST_PINES:
		if point.distance_squared_to(surveyed) < .25:
			var random := RandomNumberGenerator.new()
			random.seed = hash(surveyed)
			pines.plant(foot, minf(height, 21.0), random)
			return true
	return false


static func safe(map: Node3D, point: Vector2, driveways: RefCounted, walkways: RefCounted) -> bool:
	if MARIO_BOUNDS.grow(1.5).has_point((point - MARIO_SITE).rotated(MARIO_YAW)):
		return false
	if driveways.clears_tree(point) or walkways.clears_tree(point):
		return false
	for building: Dictionary in map.meta.buildings:
		var box: Array = building.box
		if Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1]).grow(1.8).has_point(point):
			return false
	return true


static func nearby_open_site(map: Node3D, line: Array, station: float, side: float,
		canopy: PackedFloat32Array, driveways: RefCounted, walkways: RefCounted,
		planted: Array[Vector2], survey_gap: float, planting_gap: float) -> Vector2:
	for drift: float in [0.0, -2.5, 2.5, -5.0, 5.0, -7.5, 7.5]:
		for sideways: float in [0.0, -2.0, 2.0, -4.0, 4.0]:
			var offset := side + sideways
			if absf(offset) < 6.0:
				continue
			if station + drift < 55.0 and offset > 0.0:
				continue # The playground side of the Hillcrest entrance.
			var point := at_station(line, station + drift, offset)
			if near_survey(point, canopy, survey_gap) or not safe(map, point, driveways, walkways):
				continue
			if planted.any(func(other: Vector2) -> bool:
				return point.distance_squared_to(other) < planting_gap * planting_gap):
				continue
			return point
	return Vector2.INF


func build(map: Node3D, art: RefCounted, pines: RefCounted,
		canopy: PackedFloat32Array, driveways: RefCounted, walkways: RefCounted) -> void:
	var line: Array = map.meta.streets[STREET]
	var crowns: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	var planted: Array[Vector2] = []
	var local_canopy := PackedFloat32Array()
	for i in range(0, canopy.size(), 3):
		if LOCAL_CANOPY_BOUNDS.has_point(Vector2(canopy[i], canopy[i + 1])):
			local_canopy.append_array(PackedFloat32Array([canopy[i], canopy[i + 1], canopy[i + 2]]))
	var random := RandomNumberGenerator.new()
	random.seed = 632025
	for site: Array in TREE_SITES:
		var point := nearby_open_site(map, line, site[0], site[1], local_canopy,
			driveways, walkways, planted, 6.0, 7.0)
		if not point.is_finite():
			continue
		planted.append(point)
		var height: float = site[2]
		var foot := Vector3(point.x, map.ground_height(point.x, point.y), point.y)
		if site[3]:
			pines.plant(foot, height, random)
		else:
			var angle := Basis(Vector3.UP, random.randf_range(0.0, TAU))
			var width := height * .54
			crowns.append(Transform3D(angle.scaled_local(Vector3(width, height * .76, width * .88)),
				foot + Vector3.UP * height * .64))
			stems.append(Transform3D(angle.scaled_local(Vector3(width * .073, height * .59, width * .073)),
				foot + Vector3.UP * height * .293))
	for site: Array in GARDEN_SITES:
		for offset: float in [-1.45, 0.0, 1.7]:
			var point := nearby_open_site(map, line, site[0] + offset, site[1], local_canopy,
				driveways, walkways, planted, 2.5, 1.1)
			if not point.is_finite():
				continue
			planted.append(point)
			var height: float = site[2] * random.randf_range(.82, 1.12)
			var foot := Vector3(point.x, map.ground_height(point.x, point.y), point.y)
			var angle := Basis(Vector3.UP, random.randf_range(0.0, TAU))
			crowns.append(Transform3D(angle.scaled_local(Vector3(height * 1.35, height * .85, height * 1.2)),
				foot + Vector3.UP * height * .58))
			stems.append(Transform3D(angle.scaled_local(Vector3(.08, height * .6, .08)),
				foot + Vector3.UP * height * .3))
	if not crowns.is_empty():
		var garden := Node3D.new()
		garden.name = "SilvieStreetscape"
		map.add_child(garden)
		art.render_trees(garden, crowns, stems)
