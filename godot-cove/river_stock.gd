extends RefCounted

const Species = preload("res://fish_species.gd")
const Map = preload("res://ottawa_map.gd")
const CELL := 21.0
const RADIUS := 5

class School:
	var anchor: Vector3
	var kind: int
	var depth: float
	var size_cm: float
	var course: Vector2
	var phase: float
	var number: int

	func position_at(time: float) -> Vector3:
		var side := Vector3(course.y, 0, -course.x)
		var along := Vector3(course.x, 0, course.y)
		var point := anchor + along * sin(time * .16 + phase) * 5.5 + side * cos(time * .12 + phase) * 2.9
		point.y = -maxf(.16, depth + sin(time * .72 + phase) * minf(.43, depth * .28))
		return point


var river: Map
var schools: Dictionary = {}
var active_cell := Vector2i(-999, -999)


func _init(water: Map) -> void:
	river = water


func update(boat: Vector3) -> void:
	var cell := Vector2i(floori(boat.x / CELL), floori(boat.z / CELL))
	if cell == active_cell:
		return
	active_cell = cell
	var next: Dictionary = {}
	for z in range(-RADIUS, RADIUS + 1):
		for x in range(-RADIUS, RADIUS + 1):
			var key := cell + Vector2i(x, z)
			if schools.has(key):
				next[key] = schools[key]
			else:
				next[key] = spawn_school(key)
	schools = next


func spawn_school(cell: Vector2i) -> School:
	var random := RandomNumberGenerator.new()
	random.seed = hash(cell) ^ 417239
	if random.randf() > .81:
		return null
	var anchor := Vector3((cell.x + random.randf_range(.12, .88)) * CELL, 0, (cell.y + random.randf_range(.12, .88)) * CELL)
	var bottom := river.depth_at(anchor)
	if bottom < .46:
		return null
	var pool := Species.local()
	var weights := PackedFloat32Array()
	for index in pool:
		var row := Species.profile(index)
		var rarity := .22 if row.form in ["gar", "esox", "lamprey", "sturgeon"] else .65
		weights.append(Species.habitat(row, bottom) * (1.90 if index < 4 else rarity))
	var school := School.new()
	school.kind = pool[random.rand_weighted(weights)]
	var row := Species.profile(school.kind)
	school.anchor = anchor
	school.depth = Species.feeding_depth(row, bottom)
	school.size_cm = lerpf(row.length_cm[0], row.length_cm[1], (random.randf() + random.randf()) * .5)
	school.course = Vector2.from_angle(random.randf_range(0, TAU))
	school.phase = random.randf_range(0, TAU)
	school.number = random.randi_range(3, 11) if school.size_cm < 22 else random.randi_range(1, 3)
	return school


func location(school: School, time: float) -> Vector3:
	var point := school.position_at(time)
	var depth := river.depth_at(point)
	if depth < .39:
		return Vector3(school.anchor.x, -school.depth, school.anchor.z)
	point.y = maxf(point.y, -depth + .17)
	return point


func school_returns(transducer: Vector3, time: float, beam_width: float) -> Array[Vector2]:
	var echoes: Array[Vector2] = []
	for school: School in schools.values():
		if school == null or school.anchor.distance_squared_to(transducer) > 49.0 * 49.0:
			continue
		var point := location(school, time)
		var delta := point - transducer
		var depth := -delta.y
		var horizontal := Vector2(delta.x, delta.z).length()
		var radius := .5 + depth * beam_width + minf(2.9, float(school.number) * .33)
		if depth > .36 and horizontal < radius:
			var size := smoothstep(4.0, 71.0, school.size_cm) * .65 + .24 + school.number * .019
			echoes.append(Vector2(delta.length(), size * (1.0 - smoothstep(radius * .20, radius, horizontal) * .78)))
	return echoes


func pick_for_bait(point: Vector3, slot: int, time: float, random: RandomNumberGenerator) -> int:
	var bottom := river.depth_at(point)
	var bait_depth := Species.leader(slot, bottom)
	var pool := Species.local()
	var weights := PackedFloat32Array()
	for index in pool:
		var row := Species.profile(index)
		var natural := Species.feeding_depth(row, bottom)
		var depth_fit := exp(-absf(natural - bait_depth) / maxf(1.15, bottom * .23))
		var local_abundance := 2.4 if index < 4 else (0.27 if row.form in ["gar", "esox", "salmonid"] else .61)
		weights.append(Species.rig_affinity(row, slot) * Species.habitat(row, bottom) * depth_fit * local_abundance)
	for school: School in schools.values():
		if school == null or school.anchor.distance_squared_to(point) > 31.0 * 31.0:
			continue
		var found := pool.find(school.kind)
		if weights[found] <= 0.0:
			continue
		var fish := location(school, time)
		var distance := fish.distance_to(Vector3(point.x, -bait_depth, point.z))
		weights[found] *= 1.0 + 4.7 * (1.0 - smoothstep(1.0, 23.0, distance))
	return pool[random.rand_weighted(weights)]
