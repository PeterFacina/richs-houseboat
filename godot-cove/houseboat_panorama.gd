extends RefCounted

const Kit = preload("res://scenery.gd")


static func build(parent: Node3D, hull_name: String, timber: ShaderMaterial, siding: Material) -> void:
	var graphite := Kit.paint(Color("#293439"), .43, .24)
	var ivory := Kit.paint(Color("#d8ddd8"), .41, .16)
	var steel := Kit.paint(Color("#bbc7ca"), .29, .58)
	var glass := Kit.paint(Color(.31, .49, .54, .32), .18, .30)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	build_deck(parent, hull_name, timber, graphite, steel)
	build_cabin(parent, siding, graphite, ivory, steel, glass)
	build_roof(parent, timber, graphite, ivory, steel)


static func build_deck(parent: Node3D, hull_name: String, timber: ShaderMaterial,
		graphite: Material, steel: Material) -> void:
	var float_body := CylinderMesh.new()
	float_body.top_radius = .35
	float_body.bottom_radius = .35
	float_body.height = 5.06
	float_body.radial_segments = 12
	float_body.rings = 0
	var float_end := CylinderMesh.new()
	float_end.top_radius = .15
	float_end.bottom_radius = .35
	float_end.height = .67
	float_end.radial_segments = 12
	float_end.rings = 0
	for side in [-1.0, 1.0]:
		var x: float = side * .68
		Kit.mesh_at(parent, float_body, Vector3(x, .13, .02), graphite).rotation.x = PI * .5
		for end in [-1.0, 1.0]:
			Kit.mesh_at(parent, float_end, Vector3(x, .13, .02 + end * 2.865), graphite).rotation.x = end * PI * .5
		Kit.box_at(parent, Vector3(side * 1.408, .641, 0), Vector3(.045, .145, 5.29), graphite)
		Kit.box_at(parent, Vector3(side * 1.433, .628, 0), Vector3(.016, .024, 5.29), steel)
		rail(parent, PackedVector2Array([
			Vector2(side * .70, -3.39), Vector2(side * 1.27, -2.61), Vector2(side * 1.27, -1.68),
		]), .75, 1.39, steel)
		rail(parent, PackedVector2Array([
			Vector2(side * 1.27, 1.31), Vector2(side * 1.25, 2.40), Vector2(side * 1.02, 3.18),
			Vector2(side * .54, 3.18),
		]), .75, 1.39, steel)
		for z in [-1.10, 1.70]:
			Kit.beam(parent, Vector3(side * 1.39, .77, z), Vector3(side * 1.44, .72, z), .015, graphite)
		var sign := Label3D.new()
		sign.text = hull_name + "  /  PANORAMA"
		sign.font_size = 42
		sign.pixel_size = .00155
		sign.modulate = Color("#e1e4d6")
		sign.position = Vector3(side * 1.447, .675, -.88)
		sign.rotation.y = side * PI * .5
		parent.add_child(sign)

	# Keep the finished deck and the shared walking surface at the same height.
	Kit.box_at(parent, Vector3(0, .665, 0), Vector3(2.82, .137, 5.30), timber)
	Kit.box_at(parent, Vector3(0, .665, -3.04), Vector3(1.50, .137, .78), timber)
	Kit.box_at(parent, Vector3(0, .665, 2.975), Vector3(2.18, .137, .65), timber)
	var plank_finishes: Array[ShaderMaterial] = [timber]
	for grain_offset in [1.0, 2.0, 3.0]:
		var finish := timber.duplicate() as ShaderMaterial
		finish.set_shader_parameter("grain_offset", grain_offset)
		plank_finishes.append(finish)
	for index in 33:
		var z := -3.33 + index * .201
		var width := 1.49 if z < -2.65 else (2.17 if z > 2.65 else 2.81)
		Kit.box_at(parent, Vector3(0, .737, z), Vector3(width, .026, .196),
			plank_finishes[index % plank_finishes.size()])
	Kit.box_at(parent, Vector3(0, .667, -3.429), Vector3(1.49, .13, .045), graphite)
	for x in [-.54, .54]:
		rod(parent, Vector3(x, .54, -3.44), Vector3(x, .71, -3.44), .016, graphite)
		var cushion := SphereMesh.new()
		cushion.radius = .13
		cushion.height = .39
		cushion.radial_segments = 12
		cushion.rings = 5
		Kit.mesh_at(parent, cushion, Vector3(x, .54, -3.48), graphite).rotation.z = PI * .5


static func build_cabin(parent: Node3D, siding: Material, graphite: Material,
		ivory: Material, steel: Material, glass: Material) -> void:
	for side in [-1.0, 1.0]:
		var x: float = side * .96
		Kit.box_at(parent, Vector3(x, .87, 1.13), Vector3(.13, .22, 3.18), graphite)
		Kit.box_at(parent, Vector3(x, 2.69, 1.13), Vector3(.13, .15, 3.18), graphite)
		for z in [-.43, .35, 1.13, 2.68]:
			Kit.box_at(parent, Vector3(x, 1.82, z), Vector3(.135, 1.81, .095), graphite)
		for z in [-.04, .74]:
			pane(parent, Vector3(x, 1.82, z), Vector3(.022, 1.69, .695), glass)
		for index in 12:
			var y := 1.04 + index * .139
			Kit.box_at(parent, Vector3(x, y, 1.905), Vector3(.116, .134, 1.46), siding)
		Kit.box_at(parent, Vector3(x + side * .063, 1.82, 1.95), Vector3(.025, 1.66, .26), ivory)
		var surround := TorusMesh.new()
		surround.inner_radius = .123
		surround.outer_radius = .153
		surround.rings = 14
		surround.ring_segments = 8
		Kit.mesh_at(parent, surround, Vector3(x + side * .087, 1.95, 1.95), steel).rotation.z = PI * .5
		rod(parent, Vector3(x + side * .075, 1.95, 1.95),
			Vector3(x + side * .103, 1.95, 1.95), .126, graphite)
		rod(parent, Vector3(side * 1.05, .75, -1.43), Vector3(side * 1.05, 2.75, -1.43), .024, steel)
		Kit.box_at(parent, Vector3(side * 1.05, .766, -1.43), Vector3(.095, .032, .095), steel)

	# The side lites frame the existing open walk-through from the helm.
	for x in [-.76, .76]:
		pane(parent, Vector3(x, 1.79, -.444), Vector3(.34, 1.78, .022), glass)
		for edge in [-.183, .183]:
			Kit.box_at(parent, Vector3(x + edge, 1.76, -.444), Vector3(.049, 2.0, .124), graphite)
		for y in [.82, 1.12, 2.63]:
			Kit.box_at(parent, Vector3(x, y, -.444), Vector3(.40, .053, .12), graphite)
	Kit.box_at(parent, Vector3(0, 2.69, -.444), Vector3(1.98, .15, .13), graphite)
	for side in [-1.0, 1.0]:
		Kit.box_at(parent, Vector3(side * .77, 1.66, 2.70), Vector3(.49, 1.8, .12), siding)
	Kit.box_at(parent, Vector3(0, 2.65, 2.70), Vector3(1.98, .074, .13), graphite)


static func build_roof(parent: Node3D, timber: Material, graphite: Material,
		ivory: Material, steel: Material) -> void:
	Kit.box_at(parent, Vector3(0, 2.82, .65), Vector3(2.28, .148, 4.30), ivory)
	Kit.box_at(parent, Vector3(0, 2.746, .65), Vector3(2.20, .036, 4.23), graphite)
	Kit.box_at(parent, Vector3(0, 2.904, 1.08), Vector3(1.98, .04, 3.16), timber)
	for side in [-1.0, 1.0]:
		rail(parent, PackedVector2Array([
			Vector2(side * 1.02, -.55), Vector2(side * 1.02, .52),
			Vector2(side * 1.02, 1.59), Vector2(side * 1.02, 2.66),
		]), 2.897, 3.53, steel)
	for z in [-.55, 2.66]:
		rail(parent, PackedVector2Array([Vector2(-1.02, z), Vector2(1.02, z)]),
			2.897, 3.53, steel, false)
	var fabric := Kit.paint(Color("#485857"), .94)
	for x in [-.58, .58]:
		Kit.box_at(parent, Vector3(x, 3.068, 1.11), Vector3(.45, .24, 1.28), graphite)
		Kit.box_at(parent, Vector3(x, 3.22, 1.11), Vector3(.43, .09, 1.23), fabric)
		Kit.box_at(parent, Vector3(x * 1.32, 3.32, 1.11), Vector3(.087, .28, 1.25), fabric)
	Kit.box_at(parent, Vector3(0, 3.103, 1.11), Vector3(.33, .035, .62), timber)
	Kit.box_at(parent, Vector3(0, 3.013, 1.11), Vector3(.063, .18, .27), graphite)
	rod(parent, Vector3(.84, 2.90, 2.42), Vector3(.84, 3.71, 2.42), .019, steel)
	Kit.box_at(parent, Vector3(.84, 3.71, 2.42), Vector3(.13, .044, .07), ivory)
	var lamp := Kit.paint(Color("#f2dcae"), .36)
	lamp.emission_enabled = true
	lamp.emission = Color("#f2dcae")
	lamp.emission_energy_multiplier = .45
	for z in [-.95, .95, 2.25]:
		Kit.box_at(parent, Vector3(0, 2.72, z), Vector3(.28, .025, .106), lamp)


static func pane(parent: Node3D, at: Vector3, size: Vector3, glass: Material) -> void:
	Kit.box_at(parent, at, size, glass).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


static func rail(parent: Node3D, points: PackedVector2Array, base: float, top: float,
		steel: Material, posts := true) -> void:
	if posts:
		for point in points:
			rod(parent, Vector3(point.x, base, point.y), Vector3(point.x, top, point.y), .019, steel)
	for index in range(1, points.size()):
		var a := points[index - 1]
		var b := points[index]
		for y in [top, lerpf(base, top, .58), lerpf(base, top, .29)]:
			rod(parent, Vector3(a.x, y, a.y), Vector3(b.x, y, b.y), .018 if y == top else .008, steel)


static func rod(parent: Node3D, a: Vector3, b: Vector3, radius: float, material: Material) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = a.distance_to(b)
	tube.radial_segments = 10
	tube.rings = 0
	var item := Kit.mesh_at(parent, tube, (a + b) * .5, material)
	var direction := (b - a).normalized()
	item.quaternion = Quaternion(Vector3.UP, direction)
