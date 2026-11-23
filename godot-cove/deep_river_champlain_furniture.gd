extends RefCounted

const Kit = preload("res://scenery.gd")
const Car = preload("res://marina_car_model.gd")
const BAY_START := 24.0
const BAY_PITCH := 3.25
const BAY_SLOPE := .59
const BAY_LANE_EDGE := 3.5

var ground: Callable
var start: Vector2
var along: Vector2
var across: Vector2
var fixtures: Node3D
var steel := Kit.paint(Color("#303c3d"), .59, .31)
var shade := Kit.paint(Color("#3b4543"), .62, .22)
var lens := Kit.paint(Color("#ddd5b5"), .39)
var cast_stone := Kit.paint(Color("#a89779"), .83)
var mulch := Kit.paint(Color("#574434"), .96)
var leaves := [Kit.paint(Color("#4e6734")), Kit.paint(Color("#668246")), Kit.paint(Color("#82924c"))]
var flowers := [Kit.paint(Color("#b85549")), Kit.paint(Color("#d0a744"))]


func build(parent: Node3D, street: Array, elevation: Callable, edge_width: Callable) -> void:
	ground = elevation
	start = Vector2(street[0][0], street[0][1])
	along = (Vector2(street[1][0], street[1][1]) - start).normalized()
	across = along.orthogonal()
	fixtures = Node3D.new()
	fixtures.name = "ChamplainStreetscape"
	parent.add_child(fixtures)
	lens.emission_enabled = true
	lens.emission = Color("#ebca86")
	lens.emission_energy_multiplier = .28
	for side: float in [-1.0, 1.0]:
		var stations := [27.0, 76.0, 117.5, 147.5] if side < 0.0 else [14.0, 42.0, 72.0, 106.0, 134.0, 163.2]
		for station: float in stations:
			add_light(at(station, side * (float(edge_width.call(station, side)) + .40), .147), side)
		var planters := [37.0, 111.0, 143.3] if side < 0.0 else [21.0, 53.0, 122.2, 158.2]
		for station: float in planters:
			add_planter(at(station, side * (float(edge_width.call(station, side)) + .40), .147), int(station))
	for bay: Array in [[4, 1.0, 0, "#8d3733"], [13, 1.0, 1, "#434b49"], [28, 1.0, 2, "#bfc3bc"],
			[35, 1.0, 0, "#873d39"], [39, 1.0, 2, "#466064"], [1, -1.0, 2, "#b9b9aa"], [15, -1.0, 1, "#3a5053"]]:
		var side: float = bay[1]
		var offset := 6.03
		var station: float = BAY_START + (bay[0] + .5) * BAY_PITCH - side * (offset - BAY_LANE_EDGE) * BAY_SLOPE
		park(station, offset * side, (across - along * BAY_SLOPE) * side, bay[2], bay[3])
	park(136.6, -4.24, along, 2, "#6b8791")


func at(station: float, offset: float, lift: float) -> Vector3:
	var p := start + along * station + across * offset
	return Vector3(p.x, ground.call(p.x, p.y) + lift, p.y)


func add_light(foot: Vector3, side: float) -> void:
	var roadward := Vector3(-across.x * side, 0, -across.y * side)
	cylinder(foot + Vector3.UP * .105, .125, .216, .21, steel)
	cylinder(foot + Vector3.UP * .29, .087, .123, .24, steel)
	cylinder(foot + Vector3.UP * 2.44, .040, .067, 4.28, steel)
	var previous := foot + Vector3.UP * 4.58
	for i in range(1, 13):
		var angle := PI * float(i) / 12.0
		var next := foot + roadward * (.39 - .39 * cos(angle)) + Vector3.UP * (4.58 + .43 * sin(angle))
		Kit.beam(fixtures, previous, next, .046, steel)
		previous = next
	cylinder(previous - Vector3.UP * .091, .073, .221, .18, shade)
	cylinder(previous - Vector3.UP * .183, .214, .237, .043, steel)
	cylinder(previous - Vector3.UP * .218, .180, .146, .046, lens)
	var sidearm := Vector3(along.x, 0, along.y) * .37
	Kit.beam(fixtures, foot + Vector3.UP * 3.29, foot + Vector3.UP * 3.29 + sidearm, .027, steel)


func add_planter(foot: Vector3, seed: int) -> void:
	cylinder(foot + Vector3.UP * .17, .23, .145, .34, cast_stone)
	cylinder(foot + Vector3.UP * .338, .204, .215, .018, mulch)
	for i in 7:
		var angle := float(seed) + float(i) * TAU / 7.0
		var p := foot + Vector3(cos(angle) * .139, .412 + float(i % 3) * .039, sin(angle) * .139)
		var leaf := SphereMesh.new()
		leaf.radius = .095
		leaf.height = .16
		leaf.radial_segments = 6
		leaf.rings = 3
		Kit.mesh_at(fixtures, leaf, p, leaves[i % leaves.size()])
		if i % 2 == 0:
			var blossom := SphereMesh.new()
			blossom.radius = .036
			blossom.height = .059
			blossom.radial_segments = 6
			blossom.rings = 3
			Kit.mesh_at(fixtures, blossom, p + Vector3.UP * .091, flowers[(i + seed) % 2])


func cylinder(at_point: Vector3, top: float, base: float, height: float, material: Material) -> void:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = base
	mesh.height = height
	mesh.radial_segments = 10
	Kit.mesh_at(fixtures, mesh, at_point, material)


func park(station: float, offset: float, front: Vector2, model: int, color: String) -> void:
	var parked := StaticBody3D.new()
	parked.name = "ChamplainParkedCar"
	fixtures.add_child(parked)
	var point := at(station, offset, .074)
	var look := Vector3(front.x, 0, front.y).normalized()
	var nose: Vector3 = point + look * 1.35
	var tail: Vector3 = point - look * 1.35
	look.y = (float(ground.call(nose.x, nose.z)) - float(ground.call(tail.x, tail.z))) / 2.7
	parked.transform = Transform3D(Basis.looking_at(look), point)
	var data: Dictionary = Car.MODELS[model].duplicate()
	data.paint = Color(color)
	var car := Car.new()
	parked.add_child(car)
	car.build(data)
	var size: Vector3 = data.size
	Kit.collider(parked, Vector3(0, .61, 0), Vector3(size.x * .94, .83, size.z * .96))
	Kit.collider(parked, Vector3(0, 1.14, .22), Vector3(size.x * .72, .49, size.z * .51))
