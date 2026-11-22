extends Node3D

const Kit = preload("res://scenery.gd")
const Badges = preload("res://marina_car_badges.gd")
const FINISHES := {
	"wagon": ["#575b60", "#434950", "#383b3f", "#a5a7a6", "#afd7ea"],
	"suv": ["#55595c", "#383c40", "#31383c", "#a6aeb3", "#9ed9f4"],
	"sedan": ["#9c9891", "#767570", "#4a4b49", "#a3ada7", "#b6dcc1"],
	"convertible": ["#beaa89", "#a59173", "#3f3833", "#754a35", "#b9e0bd"],
	"coupe": ["#54555b", "#35363c", "#333638", "#888c90", "#f0a180"],
}

var driver_eye: Vector3
var steering_wheel: Node3D
var speed_needle: Node3D
var seat: Material
var insert: Material
var dash: Material
var fascia: Material
var screen: Material
var rubber := Kit.paint(Color("#26292c"), .88)
var metal := Kit.paint(Color("#b3b9b8"), .44, .45)
var dial_dark := Kit.paint(Color("#171e23"), .80)
var dial_light := Kit.paint(Color("#d6e1d7"), .76)
var orange := Kit.paint(Color("#eb632f"), .57)


var truck_cab := false


func build(spec: Dictionary) -> void:
	truck_cab = spec.style == "pickup"
	name = "Cabin"
	var size: Vector3 = spec.size
	var belt := float(spec.belt)
	var roof: Array = spec.roof
	var style: String = "suv" if spec.style == "pickup" else spec.style
	var colors: Array = FINISHES[style]
	seat = Kit.paint(Color(colors[0]), .88)
	insert = Kit.paint(Color(colors[1]), .84)
	dash = Kit.paint(Color(colors[2]), .83)
	fascia = Kit.paint(Color(colors[3]), .49, .24)
	screen = Kit.paint(Color(colors[4]), .47)
	screen.emission_enabled = true
	screen.emission = Color(colors[4])
	screen.emission_energy_multiplier = .26
	var front := float(roof[0]) * size.z * .5
	var rear := float(roof[3]) * size.z * .5
	var x := size.x * .213
	var seat_z := lerpf(front, rear, .415)
	var dash_z := front + .26
	driver_eye = Vector3(-x, size.y - .156, seat_z - .020)
	Kit.box_at(self, Vector3(0, .40, (front + rear) * .5), Vector3(size.x * .84, .12, rear - front), rubber)
	for side in [-1.0, 1.0]:
		var door_x := float(side) * size.x * .402
		Kit.box_at(self, Vector3(door_x, (belt + .38) * .5, (front + rear) * .5),
			Vector3(.09, belt - .34, rear - front), dash)
		Kit.box_at(self, Vector3(door_x * .963, belt - .12, seat_z),
			Vector3(.105, .091, (rear - front) * .69), seat)
		Kit.beam(self, Vector3(door_x * .92, belt - .092, dash_z + .24),
			Vector3(door_x * .91, belt - .095, seat_z + .041), .024, fascia)
		Kit.box_at(self, Vector3(door_x * .92, belt - .045, dash_z + .37),
			Vector3(.043, .026, .096), metal)
	Kit.box_at(self, Vector3(0, belt - .16, front + .034), Vector3(size.x * .81, .37, .099), dash)
	Kit.box_at(self, Vector3(0, belt - .108, rear - .055), Vector3(size.x * .82, .235, .135), insert)
	for side in [-1.0, 1.0]:
		build_seat(float(side) * x, seat_z, belt - .237, size.y - .175, .392, style)
	if style == "wagon":
		for side in [-1.0, 1.0]:
			build_seat(float(side) * x, lerpf(seat_z, rear, .47), belt - .25, size.y - .247, .356, style)
	var bench_z := rear - (.27 if style == "wagon" else .37)
	oval(self, Vector3(0, belt - .268, bench_z - .09), Vector3(size.x * .74, .15, .49), seat)
	var bench_back := oval(self, Vector3(0, belt - .06, bench_z + .105), Vector3(size.x * .74, .452, .21), insert)
	bench_back.rotation.x = -.17
	for side in [-1.0, 1.0]:
		oval(self, Vector3(float(side) * x, belt + .124, bench_z + .135),
			Vector3(.195, .176, .137), seat)
	build_dash(size, x, belt, dash_z, style)
	var header_z := float(roof[1]) * size.z * .5 - .035
	Kit.beam(self, Vector3(0, size.y - .045, header_z), Vector3(0, size.y - .14, header_z + .07), .028, rubber)
	var mirror_at := Vector3(0, size.y - .129, header_z + .068)
	var mirror := Kit.box_at(self, mirror_at, Vector3(.199, .052, .020), rubber)
	mirror.rotation.x = -.12
	Kit.box_at(self, mirror_at + Vector3.BACK * .012, Vector3(.184, .040, .008), metal).rotation.x = -.12
	for side in [-1.0, 1.0]:
		var visor := Kit.box_at(self, Vector3(float(side) * x, size.y - .040, header_z + .018),
			Vector3(.23, .014, .080), insert)
		visor.rotation.x = -.16


func build_seat(x: float, z: float, bottom: float, top: float, width: float, style: String) -> void:
	oval(self, Vector3(x, bottom - .075, z + .04), Vector3(width * .94, .20, .41), dash)
	oval(self, Vector3(x, bottom, z), Vector3(width, .185, .51), seat)
	oval(self, Vector3(x, bottom + .043, z - .022), Vector3(width * .72, .126, .407), insert)
	var back_size := (top - bottom) * .91
	var back := oval(self, Vector3(x, bottom + back_size * .47, z + .174), Vector3(width, back_size, .213), seat)
	back.rotation.x = -.174
	var pad := oval(self, back.position + Vector3(0, .013, -.068), Vector3(width * .75, back_size * .83, .134), insert)
	pad.rotation.x = back.rotation.x
	for side in [-1.0, 1.0]:
		var offset := float(side) * width * .22
		Kit.beam(self, Vector3(x + offset, top - .207, z + .210), Vector3(x + offset, top - .113, z + .227), .015, metal)
		if style == "coupe":
			Kit.beam(self, Vector3(x + offset * 1.14, bottom + .13, z + .072),
				Vector3(x + offset * 1.14, bottom + back_size * .78, z + .118), .010, orange)
	oval(self, Vector3(x, top - .07, z + .219), Vector3(width * .66, .176, .167), seat)


func build_dash(size: Vector3, x: float, belt: float, z: float, style: String) -> void:
	oval(self, Vector3(0, belt - .036, z - .009), Vector3(size.x * .82, .286, .441), dash)
	Kit.box_at(self, Vector3(0, belt - .091, z + .136), Vector3(size.x * .69, .074, .091), fascia)
	Kit.box_at(self, Vector3(x, belt - .17, z + .146), Vector3(.403, .105, .088), dash)
	oval(self, Vector3(-x, belt + .122, z + .092), Vector3(.387, .236, .29), dash)
	var console := Kit.box_at(self, Vector3(0, belt - .089, z + .132),
		Vector3(.248 if style != "suv" else .296, .305, .157), fascia)
	console.rotation.x = -.10
	var display := Kit.box_at(self, Vector3(0, belt + .027, z + .217), Vector3(.169, .062, .017), dial_dark)
	display.rotation.x = console.rotation.x
	Kit.box_at(self, Vector3(0, belt + .027, z + .229), Vector3(.139, .034, .007), screen)
	Badges.lettering(self, "FM  98.7", Vector3(0, belt + .028, z + .235), .023, Color("#152932"))
	for dx in [-.150, .150]:
		Kit.box_at(self, Vector3(dx, belt + .022, z + .188), Vector3(.053, .103, .027), dial_dark)
		for row in 4:
			Kit.box_at(self, Vector3(dx, belt - .010 + row * .021, z + .204), Vector3(.043, .006, .006), fascia)
	for dx in [-.074, 0., .074]:
		oval(self, Vector3(dx, belt - .108, z + .224), Vector3(.042, .043, .027), dial_dark)
	Kit.box_at(self, Vector3(0, belt - .224, z + .53), Vector3(.205, .158, .57), dash)
	Kit.box_at(self, Vector3(0, belt - .137, z + .48), Vector3(.155, .021, .206), fascia)
	Kit.beam(self, Vector3(0, belt - .136, z + .473), Vector3(.013, belt - .040, z + .505), .032, rubber)
	oval(self, Vector3(.013, belt - .036, z + .507), Vector3(.061, .051, .074), insert)
	dial(Vector3(-x - .083, belt + .145, z + .239), .062, style, false)
	dial(Vector3(-x + .059, belt + .144, z + .239), .077, style, true)
	build_steering(Vector3(-x, belt + .038, z + .363), style)


func dial(at: Vector3, radius: float, style: String, is_speed: bool) -> void:
	var background: Material = dial_light if style == "convertible" else dial_dark
	var markings: Material = dial_dark if style == "convertible" else dial_light
	var face := CylinderMesh.new()
	face.top_radius = radius
	face.bottom_radius = radius
	face.height = .012
	face.radial_segments = 24
	Kit.mesh_at(self, face, at, background).rotation.x = PI * .5
	for i in range(9):
		var angle := lerpf(-PI * .70, PI * .70, i / 8.0)
		var offset := Vector3(sin(angle), cos(angle), 0)
		var tick := Kit.box_at(self, at + offset * (radius * .823) + Vector3.BACK * .009,
			Vector3(.004, radius * .15, .003), markings)
		tick.rotation.z = -angle
		if is_speed and i % 2 == 0:
			Badges.lettering(self, str(i * 20), at + offset * (radius * .648) + Vector3.BACK * .012, .010,
				Color("#18232a") if style == "convertible" else Color("#d4e4e7"))
	var needle := Node3D.new()
	needle.position = at + Vector3.BACK * .012
	needle.rotation.z = PI * .70 if is_speed else PI * .47
	add_child(needle)
	Kit.box_at(needle, Vector3.UP * (radius * .31), Vector3(.005, radius * .70, .004), orange)
	if is_speed:
		speed_needle = needle
		Badges.lettering(self, "km/h", at + Vector3(0, -.034, .011), .012,
			Color("#18232a") if style == "convertible" else Color("#d4e4e7"))


func build_steering(at: Vector3, style: String) -> void:
	var column := Node3D.new()
	column.position = at
	column.rotation.x = -.26
	add_child(column)
	steering_wheel = Node3D.new()
	column.add_child(steering_wheel)
	var rim := TorusMesh.new()
	rim.inner_radius = .151
	rim.outer_radius = .177
	rim.rings = 28
	rim.ring_segments = 10
	Kit.mesh_at(steering_wheel, rim, Vector3.ZERO, rubber).rotation.x = PI * .5
	for point: Vector3 in [Vector3(-.155, .021, 0), Vector3(.155, .021, 0), Vector3(0, -.164, 0)]:
		Kit.beam(steering_wheel, Vector3.ZERO, point, .040, fascia if style in ["suv", "coupe"] else dash)
	oval(steering_wheel, Vector3(0, .009, .011), Vector3(.155, .109, .071), dash)
	if not truck_cab:
		Badges.stamp(steering_wheel, style, Vector3(0, .017, .048), .046)


func pose(steer: float, speed: float) -> void:
	steering_wheel.rotation.z = steer * 4.6
	speed_needle.rotation.z = lerpf(PI * .70, -PI * .70, clampf(absf(speed) * 3.6 / 160.0, 0, 1))


static func oval(parent: Node3D, at: Vector3, dimensions: Vector3, material: Material) -> MeshInstance3D:
	var cushion := SphereMesh.new()
	cushion.radius = .5
	cushion.height = 1.0
	cushion.radial_segments = 14
	cushion.rings = 7
	var item := Kit.mesh_at(parent, cushion, at, material)
	item.scale = dimensions
	return item
