extends RefCounted

const Kit = preload("res://scenery.gd")

enum Item { BONG, PEN, MOLSON, MILLER }
const NAMES := ["Bong", "Dab pen", "Molson Canadian", "Miller Lite"]


static func make(parent: Node3D, item: int, location: Vector3) -> Node3D:
	var prop := Node3D.new()
	parent.add_child(prop)
	prop.position = location
	match item:
		Item.BONG:
			build_bong(prop)
		Item.PEN:
			build_pen(prop)
		_:
			build_can(prop, item == Item.MOLSON)
	return prop


static func build_bong(prop: Node3D) -> void:
	var glass := Kit.paint(Color(.68, .91, .84, .36), .19, .05)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var edge := Kit.paint(Color(.75, .90, .83, .65), .18, .08)
	edge.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var water := Kit.paint(Color(.34, .66, .61, .76), .27, .08)
	water.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	var stand := Kit.paint(Color("#294341"), .39)
	tube(prop, Vector3(0, .005, 0), Vector3(0, .021, 0), .077, .077, stand)
	tube(prop, Vector3(0, .016, 0), Vector3(0, .084, 0), .065, .055, glass)
	tube(prop, Vector3(0, .023, 0), Vector3(0, .050, 0), .060, .055, water)
	tube(prop, Vector3(0, .079, 0), Vector3(0, .135, 0), .055, .031, glass)
	tube(prop, Vector3(0, .128, 0), Vector3(0, .271, 0), .031, .031, glass)
	ring(prop, Vector3(0, .270, 0), .024, .035, edge)
	ring(prop, Vector3(0, .030, 0), .061, .070, edge)
	tube(prop, Vector3(-.034, .047, 0), Vector3(-.104, .124, .005), .010, .011, edge)
	tube(prop, Vector3(-.105, .115, .005), Vector3(-.108, .145, .005), .013, .025, stand)
	ring(prop, Vector3(-.108, .145, .005), .016, .026, edge)
	var bowl := Kit.paint(Color("#7d7847"), .89)
	bowl.emission_enabled = true
	bowl.emission = Color("#ee651f")
	bowl.emission_energy_multiplier = 0.0
	var charge := tube(prop, Vector3(-.108, .137, .005), Vector3(-.108, .148, .005), .014, .018, bowl)
	charge.name = "BowlFill"
	charge.hide()
	var bead := SphereMesh.new()
	bead.radial_segments = 10
	bead.rings = 6
	bead.radius = .006
	bead.height = .012
	for i in 3:
		var bubble := Kit.mesh_at(prop, bead, Vector3(-.016 + .015 * i, .043, .014), edge)
		bubble.name = "Bubble%d" % i
		bubble.hide()


static func build_pen(prop: Node3D) -> void:
	var metal := Kit.paint(Color("#24343c"), .38, .49)
	var brushed := Kit.paint(Color("#a5afb4"), .32, .62)
	var rubber := Kit.paint(Color("#24302c"), .56)
	tube(prop, Vector3.ZERO, Vector3(0, .092, 0), .010, .010, metal)
	tube(prop, Vector3(0, .092, 0), Vector3(0, .106, 0), .010, .010, brushed)
	tube(prop, Vector3(0, .107, 0), Vector3(0, .124, 0), .009, .006, rubber)
	var light := Kit.paint(Color("#3db4a1"), .48)
	light.emission_enabled = true
	light.emission = Color("#36daa7")
	light.emission_energy_multiplier = 1.8
	var led := Kit.box_at(prop, Vector3(0, .058, .010), Vector3(.006, .011, .002), light)
	led.name = "Indicator"
	led.hide()


static func build_can(prop: Node3D, molson: bool) -> void:
	var silver := Kit.paint(Color("#d0cfbd"), .30, .61)
	var frost := Kit.paint(Color("#ede6d5"), .43, .19)
	var blue := Kit.paint(Color("#253456"), .49, .23)
	var red := Kit.paint(Color("#a6332d"), .44, .20)
	var accent := red if molson else blue
	tube(prop, Vector3(0, .003, 0), Vector3(0, .103, 0), .032, .033, frost)
	tube(prop, Vector3(0, .103, 0), Vector3(0, .115, 0), .033, .027, silver)
	ring(prop, Vector3(0, .114, 0), .024, .029, silver)
	ring(prop, Vector3(0, .003, 0), .027, .032, silver)
	tube(prop, Vector3(0, .008, 0), Vector3(0, .019, 0), .033, .033, accent)
	tube(prop, Vector3(0, .084, 0), Vector3(0, .092, 0), .033, .033, accent)
	var tab := ring(prop, Vector3(0, .117, -.004), .004, .008, silver)
	tab.scale.z = 1.53
	var opening := Kit.paint(Color("#414643"), .78)
	var slot := Kit.box_at(prop, Vector3(0, .116, .015), Vector3(.017, .001, .013), opening)
	slot.name = "OpenedCan"
	slot.hide()
	for opposite in 2:
		var label := Label3D.new()
		label.text = "MOLSON\nCANADIAN" if molson else "Miller\nLite"
		label.modulate = Color("#2d395c") if molson else Color("#243356")
		label.font_size = 39
		label.outline_size = 0
		label.line_spacing = -4.0
		label.pixel_size = .000255 if molson else .00037
		label.no_depth_test = false
		label.position = Vector3(0, .052, .034 * (1.0 if opposite == 0 else -1.0))
		label.rotation.y = PI * opposite
		prop.add_child(label)


static func make_lighter(parent: Node3D) -> Node3D:
	var lighter := Node3D.new()
	parent.add_child(lighter)
	Kit.box_at(lighter, Vector3(0, .026, 0), Vector3(.026, .048, .014), Kit.paint(Color("#a76434"), .36))
	Kit.box_at(lighter, Vector3(0, .053, 0), Vector3(.025, .012, .015), Kit.paint(Color("#a7a8a2"), .38, .52))
	var paint := Kit.paint(Color("#ffad57"), .30)
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var shape := CylinderMesh.new()
	shape.bottom_radius = .011
	shape.top_radius = .002
	shape.height = .035
	shape.radial_segments = 12
	var flame := Kit.mesh_at(lighter, shape, Vector3(.003, .076, 0), paint)
	flame.name = "Flame"
	flame.hide()
	return lighter


static func tube(parent: Node3D, start: Vector3, end: Vector3, bottom: float, top: float,
		material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.height = start.distance_to(end)
	mesh.bottom_radius = bottom
	mesh.top_radius = top
	mesh.radial_segments = 22
	var part := Kit.mesh_at(parent, mesh, start.lerp(end, .5), material)
	part.quaternion = Quaternion(Vector3.UP, (end - start).normalized())
	return part


static func ring(parent: Node3D, at: Vector3, inside: float, outside: float, material: Material) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inside
	mesh.outer_radius = outside
	mesh.rings = 20
	mesh.ring_segments = 8
	return Kit.mesh_at(parent, mesh, at, material)
