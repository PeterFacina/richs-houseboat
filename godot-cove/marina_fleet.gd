extends RefCounted

const Kit = preload("res://scenery.gd")
const BERTHS := [
	[0, 1, 1.0, 7.6, true], [0, 3, 1.0, 7.2, true], [0, 5, 1.0, 6.2, false],
	[1, 1, -1.0, 6.4, false], [1, 4, -1.0, 7.9, true], [1, 6, 1.0, 7.5, true],
	[2, 2, -1.0, 7.2, true], [2, 6, 1.0, 6.2, false],
]
const RIBS := [Vector2(-.49, .76), Vector2(-.38, .91), Vector2(-.06, 1.0),
	Vector2(.18, .91), Vector2(.34, .60), Vector2(.43, .35), Vector2(.50, .035)]

var vessels: Array[Dictionary] = []
var bounds := Rect2()


func build(parent: Node3D, docks: Array, ground: Callable) -> void:
	var cream := Kit.paint(Color("#e0dcd0"), .42)
	var dark := Kit.paint(Color("#25353b"), .49)
	var trim := Kit.paint(Color("#939c99"), .49, .42)
	var glass := Kit.paint(Color("#3c565d"), .22, .23)
	var rope := Kit.paint(Color("#aa9d82"), .95)
	for i in BERTHS.size():
		var bay: Array = BERTHS[i]
		var dock: Array = docks[bay[0]]
		var spacing: int = [7, 10, 9, 6][bay[0]] - 1
		var a := Vector3(dock[0][0], 0, dock[0][1])
		var b := Vector3(dock[1][0], 0, dock[1][1])
		var axis := (b - a).normalized()
		var in_slip := Vector3(-axis.z, 0, axis.x) * float(bay[2])
		var length: float = bay[3]
		var edge := a.lerp(b, (float(bay[1]) + .5) / spacing)
		var anchor := edge + in_slip * (length * .5 + 1.68)
		if float(ground.call(anchor.x, anchor.z)) > -.85:
			continue
		var sailing: bool = bay[4]
		var beam := length * (.303 if sailing else .34)
		var boat := Node3D.new()
		boat.name = "MooredSailboat" if sailing else "MooredRunabout"
		parent.add_child(boat)
		var yaw := atan2(-in_slip.x, -in_slip.z)
		boat.position = anchor
		boat.rotation.y = yaw
		var finish := Kit.paint([Color("#345a79"), Color("#934539"), Color("#4e6863"), Color("#343e4d")][i % 4], .38)
		build_hull(boat, length, beam, cream, finish, dark)
		if sailing:
			build_sailboat(boat, length, beam, cream, glass, finish, trim)
		else:
			build_runabout(boat, length, beam, cream, glass, finish, dark, trim)
		for side: float in [-1.0, 1.0]:
			for z: float in [-length * .26, length * .16]:
				var fender := CylinderMesh.new()
				fender.height = .38
				fender.top_radius = .09
				fender.bottom_radius = .09
				fender.radial_segments = 10
				Kit.mesh_at(boat, fender, Vector3(side * (beam * .5 + .025), .39, z), dark)
			var tie := edge + in_slip * .31 + axis * side * .49 + Vector3.UP * .56
			var bow := boat.to_global(Vector3(side * beam * .19, .63, length * .40))
			Kit.beam(parent, tie, bow, .020, rope)
		vessels.append({"node": boat, "anchor": anchor, "yaw": yaw, "half": Vector2(beam * .64, length * .52)})
		var p := Vector2(anchor.x, anchor.z)
		bounds = Rect2(p, Vector2.ZERO) if vessels.size() == 1 else bounds.expand(p)
	bounds = bounds.grow(5.0)


func build_hull(boat: Node3D, length: float, width: float, upper: Material, stripe: Material, dark: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var bands := [[-.46, .53, .16, .97, stripe], [.16, .97, .54, 1.0, upper]]
		for band: Array in bands:
			var mesh := SurfaceTool.new()
			mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
			for i in RIBS.size() - 1:
				var a: Vector2 = RIBS[i]
				var b: Vector2 = RIBS[i + 1]
				var low_a := hull_point(a, length, width * side * band[1], band[0])
				var low_b := hull_point(b, length, width * side * band[1], band[0])
				var high_a := hull_point(a, length, width * side * band[3], band[2])
				var high_b := hull_point(b, length, width * side * band[3], band[2])
				var order := ([low_a, low_b, high_a, high_a, low_b, high_b] if side > 0.0
					else [low_a, high_a, low_b, high_a, high_b, low_b])
				for vertex in order:
					mesh.add_vertex(vertex)
			mesh.index()
			mesh.generate_normals()
			Kit.mesh_at(boat, mesh.commit(), Vector3.ZERO, band[4])
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in RIBS.size() - 1:
		var a: Vector2 = RIBS[i]
		var b: Vector2 = RIBS[i + 1]
		var left := hull_point(a, length, -width, .54)
		var left_next := hull_point(b, length, -width, .54)
		var right := hull_point(a, length, width, .54)
		var right_next := hull_point(b, length, width, .54)
		for vertex in [left, right, left_next, left_next, right, right_next]:
			surface.add_vertex(vertex)
	surface.generate_normals()
	Kit.mesh_at(boat, surface.commit(), Vector3.ZERO, upper)
	Kit.box_at(boat, Vector3(0, .19, -length * .49), Vector3(width * .76, .70, .07), dark)


func hull_point(rib: Vector2, length: float, width: float, height: float) -> Vector3:
	return Vector3(width * .5 * rib.y, height + maxf(0.0, rib.x) * .28, rib.x * length)


func build_sailboat(boat: Node3D, length: float, beam: float, cream: Material,
		glass: Material, canvas: Material, metal: Material) -> void:
	Kit.box_at(boat, Vector3(0, .73, length * .04), Vector3(beam * .68, .43, length * .42), cream)
	Kit.box_at(boat, Vector3(0, .968, length * .045), Vector3(beam * .72, .09, length * .44), cream)
	for side: float in [-1.0, 1.0]:
		for z: float in [-.64, .17, .98]:
			Kit.box_at(boat, Vector3(side * (beam * .34 + .013), .79, z), Vector3(.034, .18, .55), glass)
		Kit.beam(boat, Vector3(side * beam * .40, .76, -length * .36),
			Vector3(side * beam * .43, .77, length * .24), .023, metal)
		for z: float in [-length * .34, 0, length * .22]:
			Kit.beam(boat, Vector3(side * beam * .40, .56, z), Vector3(side * beam * .41, .77, z), .030, metal)
	Kit.box_at(boat, Vector3(0, .565, -length * .31), Vector3(beam * .61, .056, length * .21), canvas)
	var top := Vector3(0, length * 1.12, .36)
	Kit.beam(boat, Vector3(0, .94, .36), top, .089, metal)
	Kit.beam(boat, Vector3(0, 1.86, .36), Vector3(0, 1.86, -length * .33), .17, canvas)
	for end in [Vector3(0, .73, length * .44), Vector3(0, .63, -length * .44),
			Vector3(-beam * .42, .64, -.39), Vector3(beam * .42, .64, -.39)]:
		Kit.beam(boat, end, top, .018, metal)


func build_runabout(boat: Node3D, length: float, beam: float, cream: Material,
		glass: Material, canvas: Material, dark: Material, metal: Material) -> void:
	var windscreen := Kit.box_at(boat, Vector3(0, .98, length * .125), Vector3(beam * .72, .48, .10), glass)
	windscreen.rotation.x = .40
	Kit.box_at(boat, Vector3(0, .72, -length * .26), Vector3(beam * .72, .31, .61), cream)
	for x: float in [-.40, .40]:
		Kit.box_at(boat, Vector3(x, .80, -.35), Vector3(.43, .46, .48), cream)
	for side: float in [-1.0, 1.0]:
		Kit.beam(boat, Vector3(side * beam * .34, .68, -length * .31),
			Vector3(side * beam * .38, 1.92, -.22), .041, metal)
	Kit.box_at(boat, Vector3(0, 1.91, -.22), Vector3(beam * .88, .061, 1.54), canvas)
	Kit.box_at(boat, Vector3(0, .68, -length * .53), Vector3(.48, .52, .42), dark)


func update(center: Vector3, clock: float, wave: Callable) -> void:
	for berth in vessels:
		var anchor: Vector3 = berth.anchor
		if anchor.distance_squared_to(center) > 310.0 * 310.0:
			continue
		var boat: Node3D = berth.node
		boat.position.y = wave.call(anchor, clock)
		boat.rotation.x = sin(clock * 1.08 + anchor.z) * .008
		boat.rotation.z = cos(clock * .82 + anchor.x) * .012


func blocks(point: Vector3) -> bool:
	if not bounds.has_point(Vector2(point.x, point.z)):
		return false
	for berth in vessels:
		var delta: Vector3 = (point - Vector3(berth.anchor)).rotated(Vector3.UP, -float(berth.yaw))
		var half: Vector2 = berth.half
		if absf(delta.x) < half.x and absf(delta.z) < half.y:
			return true
	return false
