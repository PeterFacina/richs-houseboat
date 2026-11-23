extends RefCounted

const Kit = preload("res://scenery.gd")
const Docks = preload("res://marina_docks.gd")
const MOORED := [
	["HutSlips", 0, 1.0, "skiff", 4.7, 1.58, Color("#608178")],
	["HutSlips", 2, 1.0, "runabout", 5.1, 1.91, Color("#af553f")],
	["HutSlips", 4, 1.0, "skiff", 4.5, 1.63, Color("#566772")],
	["BasinDock1", 1, -1.0, "pontoon", 6.7, 2.45, Color("#325d6a")],
	["BasinDock1", 5, 1.0, "sailboat", 7.05, 2.28, Color("#3f626e")],
	["BasinDock2", 2, -1.0, "runabout", 6.45, 2.32, Color("#355984")],
	["BasinDock2", 6, 1.0, "pontoon", 6.5, 2.42, Color("#67554a")],
]
const RIBS := [Vector2(-.49, .76), Vector2(-.38, .91), Vector2(-.06, 1.0),
	Vector2(.18, .91), Vector2(.34, .60), Vector2(.43, .35), Vector2(.50, .035)]

var vessels: Array[Dictionary] = []


func build(parent: Node3D, berths: Array[Dictionary], ground: Callable, docks: Docks) -> void:
	var cream := Kit.paint(Color("#e0dcd0"), .42)
	var dark := Kit.paint(Color("#25353b"), .49)
	var trim := Kit.paint(Color("#939c99"), .49, .42)
	var glass := Kit.paint(Color("#3c565d"), .22, .23)
	var rope := Kit.paint(Color("#aa9d82"), .95)
	var fleet := Node3D.new()
	fleet.name = "MooredBoats"
	parent.add_child(fleet)
	for berth: Dictionary in berths:
		for plan: Array in MOORED:
			if berth.row == plan[0] and berth.slot == plan[1] and berth.side == plan[2]:
				var length: float = plan[4]
				var beam: float = plan[5]
				var edge: Vector3 = berth.edge
				var outward: Vector3 = berth.outward
				var anchor := Vector3(edge.x, 0, edge.z) + outward * (length * .5 + 1.51)
				if float(ground.call(anchor.x, anchor.z)) <= -.69 and berth.width > beam + .55:
					var boat := Node3D.new()
					boat.name = "Moored" + str(plan[3]).capitalize()
					fleet.add_child(boat, true)
					boat.position = anchor
					boat.basis = Basis.looking_at(outward)
					var finish := Kit.paint(plan[6], .42)
					if plan[3] == "pontoon":
						build_pontoon(boat, length, beam, cream, dark, trim, finish)
					else:
						build_hull(boat, length, beam, trim if plan[3] == "skiff" else cream, finish, dark)
						match plan[3]:
							"skiff": build_skiff(boat, length, beam, trim, dark, finish)
							"sailboat": build_sailboat(boat, length, beam, cream, glass, finish, trim)
							_: build_runabout(boat, length, beam, cream, glass, finish, dark, trim)
					for side: float in [-1.0, 1.0]:
						var fender := CylinderMesh.new()
						fender.height = .38
						fender.top_radius = .085
						fender.bottom_radius = .085
						fender.radial_segments = 10
						Kit.mesh_at(boat, fender, Vector3(side * (beam * .5 + .015), .39, -.31), dark)
						var tie: Vector3 = edge + outward * .98 + berth.along * side * .65
						var bow := boat.to_global(Vector3(side * beam * .19, .60, length * .44))
						Kit.beam(fleet, tie, bow, .018, rope)
					docks.add_obstacle(anchor - outward * length * .56, anchor + outward * length * .50, beam + .16)
					vessels.append({"node": boat, "anchor": anchor})


func build_skiff(boat: Node3D, length: float, beam: float, alloy: Material, dark: Material,
		seat: Material) -> void:
	for side: float in [-1.0, 1.0]:
		Kit.beam(boat, Vector3(side * beam * .43, .62, -length * .35),
			Vector3(side * beam * .43, .65, length * .27), .045, alloy)
	for z: float in [-length * .25, .0, length * .22]:
		Kit.box_at(boat, Vector3(0, .663, z), Vector3(beam * .78, .12, .28), seat)
	Kit.box_at(boat, Vector3(0, .54, -length * .52), Vector3(.31, .42, .32), dark)
	Kit.beam(boat, Vector3(0, .68, -length * .52), Vector3(.19, .71, -length * .41), .036, dark)


func build_pontoon(boat: Node3D, length: float, beam: float, cream: Material,
		dark: Material, alloy: Material, canvas: Material) -> void:
	for side: float in [-1.0, 1.0]:
		var x := side * beam * .344
		var tube := CapsuleMesh.new()
		tube.radius = beam * .132
		tube.height = length
		tube.radial_segments = 12
		tube.rings = 4
		Kit.mesh_at(boat, tube, Vector3(x, .01, 0), alloy).rotation.x = PI * .5
	Kit.box_at(boat, Vector3(0, .36, 0), Vector3(beam, .13, length * .91), dark)
	for side: float in [-1.0, 1.0]:
		var x := side * beam * .468
		Kit.box_at(boat, Vector3(x, .72, 0), Vector3(.06, .53, length * .80), canvas)
		Kit.beam(boat, Vector3(x, 1.01, -length * .41), Vector3(x, 1.01, length * .41), .045, alloy)
		for z: float in [-length * .31, length * .09]:
			Kit.beam(boat, Vector3(x, .58, z), Vector3(x, 1.93, z + .19), .039, alloy)
		Kit.box_at(boat, Vector3(x * .71, .66, length * .22), Vector3(.44, .35, length * .29), cream)
	Kit.box_at(boat, Vector3(0, 1.94, -length * .09), Vector3(beam * .98, .073, length * .46), canvas)
	Kit.box_at(boat, Vector3(.46, .79, -.62), Vector3(.44, .58, .47), cream)
	Kit.box_at(boat, Vector3(0, .57, -length * .48), Vector3(.46, .54, .47), dark)


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
