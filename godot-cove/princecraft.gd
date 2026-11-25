extends "res://houseboat.gd"

const WHEEL_RADIUS := .145
const FLOOR := .32
const RIBS := [
	Vector3(-2.60, .035, .615), Vector3(-2.37, .31, .598), Vector3(-1.97, .59, .572),
	Vector3(-1.49, .81, .549), Vector3(-.91, .959, .528), Vector3(-.28, 1.032, .513),
	Vector3(.68, 1.042, .499), Vector3(1.64, 1.019, .493), Vector3(2.33, .943, .500),
]

var black := SceneKit.paint(Color("#181c1b"), .34, .25)
var trim := SceneKit.paint(Color("#172320"), .64)
var aluminum := SceneKit.paint(Color("#c5ccca"), .35, .57)
var gold := SceneKit.paint(Color("#bb9451"), .41, .34)
var cushion := SceneKit.paint(Color("#cfc0a3"), .76)
var seat_shell := SceneKit.paint(Color("#938676"), .70)
var deck_cover := SceneKit.paint(Color("#a99778"), .96)
var canopy := SceneKit.paint(Color("#b9a386"), .91)
var binding := SceneKit.paint(Color("#8b785e"), .88)
var liner := SceneKit.paint(Color("#b0a38f"), .86)
var dash_screen := SceneKit.paint(Color("#152622"), .58)


func _init() -> void:
	skiff = true
	river_engine = true
	yaw_rate = .52
	wave_response = 1.37
	turn_heel = -.13
	steering_rate = .94 * 1.15
	throttle_rate = .48
	drive_response = .66
	coast_response = 1.43
	wake_spread = .56
	wake_peak_speed = 5.8
	wheel_radius = WHEEL_RADIUS


func _ready() -> void:
	super._ready()
	name = "PrincecraftHolidayDLX"


func fit_mooring() -> void:
	mooring.fit([Vector3(0, .570, -1.88), Vector3(-.843, .552, 2.18), Vector3(.843, .552, 2.18)],
		[Vector3(0, .637, -2.38), Vector3(-1.013, .580, 2.14), Vector3(1.013, .580, 2.14)],
		["Bow", "Stern port", "Stern starboard"], Vector3(.841, .626, -1.43))


func helm_anchor() -> Vector3:
	return Vector3(.49, FLOOR + .04, .27)


func helm_eye_height() -> float:
	return 1.14


func status_panel_mount() -> Vector3:
	return Vector3(-.51, .79, -.61)


func board_anchor() -> Vector3:
	return Vector3(.12, FLOOR + .06, .97)


func passenger_anchor() -> Vector3:
	return Vector3(-.51, FLOOR, .30)


func fuel_tank_mount() -> Vector3:
	return Vector3(-.28, FLOOR, 1.38)


func motor_mount() -> Vector3:
	return Vector3(0, .25, 2.36)


func motor_size() -> float:
	return .74


func has_bow_spotlight() -> bool:
	return false


func uses_battery() -> bool:
	return false


func speed_limit(_towing: bool) -> float:
	return 9.5


func launch_half_beam() -> float:
	return 1.065


func waterline(at: Vector3, yaw: float) -> PackedVector2Array:
	return world_outline(at, yaw, [Vector2(0, -2.61), Vector2(.64, -1.94), Vector2(.97, -.95),
		Vector2(1.065, -.20), Vector2(1.065, 1.04), Vector2(.95, 2.33), Vector2(.31, 2.74),
		Vector2(-.31, 2.74), Vector2(-.95, 2.33), Vector2(-1.065, 1.04),
		Vector2(-1.065, -.20), Vector2(-.97, -.95), Vector2(-.64, -1.94)])


func supports_deck(world: Vector3) -> bool:
	var local := to_local(world)
	return (absf(local.x) < 1.03 and local.y > .19 and local.y < 2.20
		and local.z > -2.13 and local.z < 2.13)


func geometry() -> void:
	build_hull()
	build_cockpit()
	build_windshield()
	build_canopy()


func build_hull() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var rail := SurfaceTool.new()
	rail.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for i in RIBS.size() - 1:
			var a: Vector3 = RIBS[i]
			var b: Vector3 = RIBS[i + 1]
			var lower_a := hull_at(a, side, 0.0)
			var lower_b := hull_at(b, side, 0.0)
			var upper_a := hull_at(a, side, 1.0)
			var upper_b := hull_at(b, side, 1.0)
			var chine_a := hull_at(a, side, .30)
			var chine_b := hull_at(b, side, .30)
			panel(surface, lower_a, lower_b, chine_a, chine_b, side < 0)
			panel(surface, chine_a, chine_b, upper_a, upper_b, side < 0)
			var edge := Vector3(side * .009, -.051, 0)
			panel(rail, upper_a + edge, upper_b + edge, upper_a + Vector3.UP * .014,
				upper_b + Vector3.UP * .014, side < 0)
		band_detail(side)
		var print_yaw := PI * .5 * side
		hull_label("PRINCECRAFT", Vector3(side * 1.019, .297, .71), print_yaw, .0032, Color("#f3ead5"))
		hull_label("DLX  HOLIDAY", Vector3(side * 1.009, .172, 1.49), print_yaw, .0025, Color("#cda65e"))
	var aft: Vector3 = RIBS[-1]
	panel(surface, hull_at(aft, -1, 0), hull_at(aft, 1, 0), hull_at(aft, -1, .30), hull_at(aft, 1, .30), false)
	panel(surface, hull_at(aft, -1, .30), hull_at(aft, 1, .30), hull_at(aft, -1, 1), hull_at(aft, 1, 1), false)
	commit(surface, black).name = "LowBlackHull"
	commit(rail, trim).name = "Gunwales"
	var foredeck := SurfaceTool.new()
	foredeck.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 4:
		var a: Vector3 = RIBS[i]
		var b: Vector3 = RIBS[i + 1]
		panel(foredeck, hull_at(a, -1, 1), hull_at(a, 1, 1), hull_at(b, -1, 1), hull_at(b, 1, 1), false)
	commit(foredeck, deck_cover).name = "CoveredBow"
	SceneKit.box_at(self, Vector3(0, FLOOR - .05, .61), Vector3(1.84, .10, 3.18), deck_cover)
	SceneKit.collider(self, Vector3(0, FLOOR - .05, .61), Vector3(1.90, .10, 3.17))
	SceneKit.collider(self, Vector3(0, .43, -1.49), Vector3(1.28, .14, 1.17))
	SceneKit.box_at(self, Vector3(0, .358, 2.18), Vector3(1.76, .19, .28), trim)


static func hull_at(rib: Vector3, side: float, level: float) -> Vector3:
	var keel := lerpf(-.40, .39, 1.0 - smoothstep(-2.60, -1.75, rib.x))
	# Follow a shallow V below the chine and flare out toward the gunwale.
	var width := lerpf(.038, .83, level / .30) if level <= .30 else lerpf(.83, 1.0, (level - .30) / .70)
	return Vector3(side * rib.y * width, lerpf(keel, rib.z, level), rib.x)


func band_detail(side: float) -> void:
	hull_stripe(side, [
		Vector3(-1.61, .788, .800), Vector3(-.90, .786, .815), Vector3(-.03, .753, .808),
		Vector3(.43, .699, .791), Vector3(1.12, .662, .740), Vector3(1.98, .704, .722),
	], gold, .010)
	hull_stripe(side, [
		Vector3(-.85, .751, .765), Vector3(-.36, .724, .809), Vector3(-.05, .671, .865),
		Vector3(.38, .632, .878), Vector3(.87, .696, .868), Vector3(1.47, .739, .814),
	], aluminum, .016)
	hull_stripe(side, [
		Vector3(-.28, .714, .728), Vector3(.20, .710, .763), Vector3(.63, .714, .778),
		Vector3(1.36, .744, .767), Vector3(1.93, .761, .765),
	], gold, .021)


func hull_stripe(side: float, marks: Array[Vector3], paint: Material, relief: float) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in marks.size() - 1:
		var a := marks[i]
		var b := marks[i + 1]
		var sections := maxi(1, ceili((b.x - a.x) / .10))
		for section in sections:
			var start := a.lerp(b, float(section) / sections)
			var end := a.lerp(b, float(section + 1) / sections)
			panel(surface, stripe_point(start.x, start.y, side, relief), stripe_point(end.x, end.y, side, relief),
				stripe_point(start.x, start.z, side, relief), stripe_point(end.x, end.z, side, relief), side < 0)
	commit(surface, paint)


static func stripe_point(z: float, level: float, side: float, relief: float) -> Vector3:
	for i in RIBS.size() - 1:
		var a: Vector3 = RIBS[i]
		var b: Vector3 = RIBS[i + 1]
		if z <= b.x:
			var u := inverse_lerp(a.x, b.x, z)
			var v := inverse_lerp(.30, 1.0, level)
			var low_a := hull_at(a, side, .30)
			var low_b := hull_at(b, side, .30)
			var high_a := hull_at(a, side, 1.0)
			var high_b := hull_at(b, side, 1.0)
			var at := low_a + (low_b - low_a) * u + (high_a - low_a) * v if u + v <= 1.0 else (
				high_b + (high_a - high_b) * (1.0 - u) + (low_b - high_b) * (1.0 - v))
			return at + Vector3.RIGHT * side * relief
	return hull_at(RIBS[-1], side, level)


func hull_label(value: String, at: Vector3, yaw: float, pixel: float, ink: Color) -> void:
	var label := Label3D.new()
	label.text = value
	label.font_size = 42
	label.pixel_size = pixel
	label.outline_size = 0
	label.modulate = ink
	label.position = at
	label.rotation.y = yaw
	add_child(label)


func build_cockpit() -> void:
	build_inner_walls()
	for x: float in [-.51, .49]:
		var seat := Node3D.new()
		seat.name = "PassengerSeat" if x < 0.0 else "HelmSeat"
		add_child(seat)
		seat.position = Vector3(x, FLOOR, .29)
		Tools.tube(seat, Vector3(0, .026, 0), Vector3(0, .340, 0), .073, .055, aluminum)
		SceneKit.box_at(seat, Vector3(0, .372, .015), Vector3(.48, .114, .46), cushion)
		SceneKit.box_at(seat, Vector3(0, .347, .03), Vector3(.49, .071, .47), seat_shell)
		var back := SceneKit.box_at(seat, Vector3(0, .565, .216), Vector3(.46, .35, .105), cushion)
		back.rotation.x = -.14
		SceneKit.box_at(seat, Vector3(0, .569, .272), Vector3(.465, .34, .047), seat_shell).rotation.x = -.14
	build_helm()
	SceneKit.box_at(self, Vector3(-.51, .649, -.726), Vector3(.61, .177, .204), seat_shell).rotation.x = -.38
	SceneKit.box_at(self, Vector3(0, .447, -.949), Vector3(1.87, .277, .116), liner).name = "ForwardBulkhead"
	SceneKit.box_at(self, Vector3(0, .49, 1.89), Vector3(1.50, .245, .36), cushion)
	for side: float in [-1.0, 1.0]:
		for z: float in [-1.31, 1.78]:
			Tools.tube(self, Vector3(side * .88, .557, z - .095),
				Vector3(side * .88, .557, z + .095), .018, .013, aluminum)


func build_inner_walls() -> void:
	# The liner meets the sole and returns over the existing hull edge. Keep
	# the gunwale low at the launch dock boarding point.
	var wall := SurfaceTool.new()
	wall.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cap := SurfaceTool.new()
	cap.begin(Mesh.PRIMITIVE_TRIANGLES)
	for side: float in [-1.0, 1.0]:
		for i in range(4, RIBS.size() - 1):
			var a := hull_at(RIBS[i], side, 1.0)
			var b := hull_at(RIBS[i + 1], side, 1.0)
			var inner_a := a - Vector3(side * .080, .012, 0)
			var inner_b := b - Vector3(side * .080, .012, 0)
			var foot_a := Vector3(side * minf(.88, absf(inner_a.x)), FLOOR - .018, a.z)
			var foot_b := Vector3(side * minf(.88, absf(inner_b.x)), FLOOR - .018, b.z)
			panel(wall, foot_a, foot_b, inner_a, inner_b, side > 0.0)
			panel(cap, inner_a, inner_b, a, b, side > 0.0)
			Tools.tube(self, inner_a.lerp(a, .45) + Vector3.UP * .02,
				inner_b.lerp(b, .45) + Vector3.UP * .02, .034, .034, seat_shell)
		var upholstery := SceneKit.box_at(self, Vector3(side * .914, .430, .64),
			Vector3(.058, .115, .98), cushion)
		upholstery.rotation.z = -side * .15
		SceneKit.box_at(self, Vector3(side * .900, .427, 1.52), Vector3(.07, .111, .66), liner)
	var transom := Vector3(0, .420, 2.29)
	SceneKit.box_at(self, transom, Vector3(1.78, .23, .11), liner)
	commit(wall, liner).name = "CockpitLiner"
	commit(cap, seat_shell).name = "GunwaleCaps"


func build_controls() -> void:
	var console := HelmConsole.new()
	console.trim = trim
	console.metal = aluminum
	console.accent = gold
	console.grip = black
	console.screen = dash_screen
	mount_controls(console, Transform3D(Basis(Vector3.RIGHT, -.43), Vector3(.49, .942, -.535)),
		Transform3D(Basis.IDENTITY, Vector3(.865, .552, -.103)))


func build_helm() -> void:
	SceneKit.box_at(self, Vector3(.49, .765, -.549), Vector3(.17, .19, .128), trim)
	var shaft := Node3D.new()
	shaft.name = "SteeringShaft"
	shaft.position = Vector3(.49, .814, -.303)
	shaft.rotation.x = -.34
	add_child(shaft)
	Tools.tube(shaft, Vector3(0, 0, -.261), Vector3.ZERO, .047, .045, trim)
	helm_wheel = Node3D.new()
	helm_wheel.name = "WheelHub"
	shaft.add_child(helm_wheel)
	var wheel := TorusMesh.new()
	wheel.inner_radius = .130
	wheel.outer_radius = .161
	wheel.rings = 24
	wheel.ring_segments = 12
	SceneKit.mesh_at(helm_wheel, wheel, Vector3.ZERO, trim).rotation.x = PI * .5
	for i in 3:
		var angle := TAU * i / 3.0 - PI * .5
		var spoke := Vector3(cos(angle), sin(angle), 0)
		Tools.tube(helm_wheel, Vector3.ZERO, spoke * WHEEL_RADIUS, .014, .009, aluminum)
	Tools.tube(helm_wheel, Vector3(0, 0, -.022), Vector3(0, 0, .027), .050, .043, trim)


func build_windshield() -> void:
	var glass := SceneKit.paint(Color(.47, .66, .65, .22), .19, .08)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	var mid_low := Vector3(0, .733, -.97)
	var mid_high := Vector3(0, 1.228, -.55)
	var nose := Vector3(0, .522, -1.027)
	var cowl := SurfaceTool.new()
	cowl.begin(Mesh.PRIMITIVE_TRIANGLES)
	var cowl_paint := trim.duplicate() as StandardMaterial3D
	cowl_paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	for side: float in [-1.0, 1.0]:
		var base := Vector3(side * .91, .697, -.855)
		var peak := Vector3(side * .82, 1.177, -.411)
		var aft := Vector3(side * .927, .660, .13)
		panel(mesh, mid_low, base, mid_high, peak, side < 0)
		panel(mesh, base, aft, peak, aft, side < 0)
		var bow_edge := hull_at(RIBS[3].lerp(RIBS[4], .83), side, 1.0)
		var rim := hull_at(RIBS[4].lerp(RIBS[5], .087), side, 1.0)
		var middle := hull_at(RIBS[5], side, 1.0)
		var rear := hull_at(RIBS[5].lerp(RIBS[6], .427), side, 1.0)
		var sill := base.lerp(aft, (-.28 - base.z) / (aft.z - base.z))
		panel(cowl, nose, bow_edge, mid_low, base, side < 0)
		var corner := [bow_edge, base, rim] if side < 0.0 else [bow_edge, rim, base]
		for vertex: Vector3 in corner:
			cowl.add_vertex(vertex)
		panel(cowl, rim, middle, base, sill, side < 0)
		panel(cowl, middle, rear, sill, aft, side < 0)
		for segment: Array in [[mid_low, base], [mid_high, peak], [base, peak], [peak, aft], [base, aft]]:
			Tools.tube(self, segment[0], segment[1], .018, .018, aluminum)
	Tools.tube(self, mid_low, mid_high, .015, .015, aluminum)
	commit(mesh, glass).name = "RakedWindshield"
	commit(cowl, cowl_paint).name = "WindshieldCowlAndSideInfill"


func build_canopy() -> void:
	var bows := [
		Vector3(-.60, 1.65, .84), Vector3(-.22, 1.84, .91),
		Vector3(.66, 1.98, .96), Vector3(1.43, 1.966, .94), Vector3(1.74, 1.904, .90),
	]
	var roof := SurfaceTool.new()
	roof.begin(Mesh.PRIMITIVE_TRIANGLES)
	canopy.cull_mode = BaseMaterial3D.CULL_DISABLED
	for i in bows.size() - 1:
		var a: Vector3 = bows[i]
		var b: Vector3 = bows[i + 1]
		for strip in 8:
			var left := float(strip) / 4.0 - 1.0
			var right := float(strip + 1) / 4.0 - 1.0
			panel(roof, canopy_at(a, left), canopy_at(a, right), canopy_at(b, left), canopy_at(b, right), false)
		for side: float in [-1.0, 1.0]:
			Tools.tube(self, canopy_at(a, side), canopy_at(b, side), .016, .016, binding)
	for bow: Vector3 in bows:
		for strip in 8:
			Tools.tube(self, canopy_at(bow, float(strip) / 4.0 - 1.0),
				canopy_at(bow, float(strip + 1) / 4.0 - 1.0), .009, .009, binding)
	commit(roof, canopy).name = "TanCanvasCanopy"
	for side: float in [-1.0, 1.0]:
		var hip := Vector3(side * .94, .551, .62)
		Tools.tube(self, hip, canopy_at(bows[3], side), .016, .014, aluminum)
		Tools.tube(self, hip, canopy_at(bows[1], side), .014, .014, aluminum)
		Tools.tube(self, Vector3(side * .909, .55, 1.83), canopy_at(bows[4], side), .013, .012, aluminum)
		Tools.tube(self, Vector3(side * .92, .68, -.55), canopy_at(bows[0], side), .012, .010, aluminum)


static func canopy_at(bow: Vector3, across: float) -> Vector3:
	return Vector3(bow.z * across, bow.y - .082 * across * across, bow.x)


static func panel(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3, flip: bool) -> void:
	for vertex: Vector3 in [a, c, b, c, d, b] if flip else [a, b, c, b, d, c]:
		surface.add_vertex(vertex)


func commit(surface: SurfaceTool, material: Material) -> MeshInstance3D:
	surface.index()
	surface.generate_normals()
	return SceneKit.mesh_at(self, surface.commit(), Vector3.ZERO, material)
