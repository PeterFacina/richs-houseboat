extends RefCounted

const Kit = preload("res://scenery.gd")
const Beach = preload("res://lamure_beach.gd")
const Marina = preload("res://marina_art.gd")
const Pines = preload("res://lamure_pines.gd")

var ground: Callable


func build(parent: Node3D, layout: Dictionary, elevation: Callable, marina: Marina, pines: Pines) -> void:
	ground = elevation
	var campus := Node3D.new()
	campus.name = "BrockhouseWay"
	parent.add_child(campus)
	var blue := Kit.paint(Color("#27467e"), .70, .12)
	build_school_sign(campus, at(layout.sign), blue)
	for entry: Array in layout.wayfinding:
		var sign := signpost(campus, at(entry[0]), Vector3(entry[1][0], 0, entry[1][1]),
			Vector3(1.75, .48, .09), 1.42, Kit.paint(Color("#2c4c44")))
		letter_panel(sign, entry[2], Vector3(0, 1.52, .051), .00235, Color("#f7f1e6"))
		letter_panel(sign, entry[3], Vector3(0, 1.32, .051), .00235, Color("#dedccb"))
	for pair: Array in layout.benches:
		var bench := Beach.build_bench(campus, at(pair), marina.timber)
		bench.rotation.y = -.67
	var random := RandomNumberGenerator.new()
	random.seed = 110879
	for tree: Array in layout.pines:
		pines.plant(at(tree), float(tree[2]), random)
	build_greenery(campus, layout, marina, random)
	build_ditch(campus, random)
	build_parking(campus)


func build_school_sign(parent: Node3D, foot: Vector3, blue: Material) -> void:
	var sign := signpost(parent, foot, Vector3(-.48, 0, -.88), Vector3(2.70, 1.77, .14), 1.63, blue)
	sign.name = "MackenzieSchoolSign"
	var ivory := Kit.paint(Color("#e0e3da"), .70)
	var board := Kit.paint(Color("#282d35"), .88)
	for side: float in [-1.0, 1.0]:
		Kit.box_at(sign, Vector3(0, 1.77, side * .077), Vector3(2.52, .30, .031), ivory)
		Kit.box_at(sign, Vector3(0, 1.31, side * .077), Vector3(2.52, .54, .031), board)
		Kit.box_at(sign, Vector3(0, .86, side * .077), Vector3(2.52, .23, .031), ivory)
		letter_panel(sign, "MACKENZIE", Vector3(0, 2.27, side * .079), .0054, Color("#f3eee0"), side)
		letter_panel(sign, "Community School", Vector3(0, 2.04, side * .079), .0033, Color("#f0eee1"), side)
		letter_panel(sign, "RENFREW COUNTY", Vector3(0, 1.79, side * .102), .00295, Color("#284570"), side)
		letter_panel(sign, "87 Brockhouse Way", Vector3(0, 1.31, side * .102), .0035, Color("#e3e9db"), side)


func signpost(parent: Node3D, foot: Vector3, face: Vector3, size: Vector3, center: float,
		material: Material) -> Node3D:
	var root := Node3D.new()
	parent.add_child(root)
	root.position = foot
	root.basis = Basis.looking_at(face, Vector3.UP, true)
	for side: float in [-1.0, 1.0]:
		var base := root.to_global(Vector3(side * (size.x * .5 + .027), 0, 0))
		var low := float(ground.call(base.x, base.z)) - foot.y - .05
		var high := center + size.y * .5 + .07
		var x := side * (size.x * .5 + .027)
		Kit.box_at(root, Vector3(x, (high + low) * .5, 0), Vector3(.125, high - low, .128), material)
	Kit.box_at(root, Vector3(0, center, 0), size, material)
	return root


func letter_panel(parent: Node3D, wording: String, position: Vector3, scale: float, tint: Color,
		side := 1.0) -> void:
	var label := Label3D.new()
	parent.add_child(label)
	label.position = position
	label.rotation.y = PI if side < 0.0 else 0.0
	label.text = wording
	label.modulate = tint
	label.font_size = 35
	label.pixel_size = scale
	label.outline_size = 0


func build_parking(campus: Node3D) -> void:
	var zone := Vector2(17994.5, 12933.3)
	var row := Vector2(.53, .848).normalized()
	var across := Vector2(.848, -.53).normalized()
	var marks := SurfaceTool.new()
	marks.begin(Mesh.PRIMITIVE_TRIANGLES)
	marks.set_normal(Vector3.UP)
	for stall in 5:
		var start := zone + row * stall * 2.67
		for section in 6:
			var a := start + across * section * .80
			var b := a + across * .80
			var offset := row * .055
			for p: Vector2 in [a - offset, a + offset, b - offset, b - offset, a + offset, b + offset]:
				marks.add_vertex(at([p.x, p.y]) + Vector3.UP * .026)
	var paint := Kit.paint(Color("#d1ccc1"), .9)
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	Kit.mesh_at(campus, marks.commit(), Vector3.ZERO, paint)
	build_car(campus, zone + row * 1.35 + across * 2.4, across, Color("#344d66"))
	build_car(campus, zone + row * 6.68 + across * 2.4, across, Color("#a3a7aa"))
	build_car(campus, Vector2(18041, 13031), across, Color("#78463c"))


func build_ditch(campus: Node3D, random: RandomNumberGenerator) -> void:
	var stones: Array[Transform3D] = []
	for index in 55:
		var offset := random.randf_range(-3.4, 3.4)
		var x := 18057.0 + offset * .5 + random.randf_range(-.59, .59)
		var z := 12918.0 + offset * .866
		var span := random.randf_range(.15, .36)
		var shape := Basis(Vector3.UP, random.randf() * TAU).scaled_local(Vector3(span, span * .47, span * .78))
		stones.append(Transform3D(shape, at([x, z]) + Vector3.UP * .045))
	var cobble := SphereMesh.new()
	cobble.radial_segments = 7
	cobble.rings = 4
	Kit.new().scatter(campus, cobble, stones, Kit.paint(Color("#777269"), .98))


func build_greenery(campus: Node3D, layout: Dictionary, marina: Marina, random: RandomNumberGenerator) -> void:
	var crowns: Array[Transform3D] = []
	var stems: Array[Transform3D] = []
	for tree: Array in layout.shade_trees:
		add_deciduous(at(tree), tree[2], random, crowns, stems)
	var grass: Array[Transform3D] = []
	var sign := Vector2(layout.sign[0], layout.sign[1])
	for verge: Array in layout.verges:
		for i in range(1, verge.size()):
			var a := Vector2(verge[i - 1][0], verge[i - 1][1])
			var b := Vector2(verge[i][0], verge[i][1])
			var across := (b - a).normalized().orthogonal()
			var count := ceili(a.distance_to(b) * 1.4)
			for blade in count:
				var fraction := (blade + random.randf()) / count
				var p := a.lerp(b, fraction) + across * random.randf_range(-1.8, 1.8)
				if p.distance_squared_to(sign) < 20.0 or footpath_near(p, layout.walkways):
					continue
				var foot := at([p.x, p.y])
				var yaw := Basis(Vector3.UP, random.randf() * TAU)
				var size := Vector3(random.randf_range(.56, 1.45), random.randf_range(.32, .74), .85)
				grass.append(Transform3D(yaw.scaled_local(size), foot))
				if blade % 4 == 0:
					add_deciduous(foot, random.randf_range(.85, 2.55), random, crowns, stems)
	marina.render_trees(campus, crowns, stems)
	var reeds := ShaderMaterial.new()
	reeds.shader = preload("res://river_reeds.gdshader")
	Kit.new().scatter(campus, marina.reed_mesh(random), grass, reeds)


func footpath_near(at: Vector2, trails: Array) -> bool:
	for trail: Array in trails:
		for i in range(1, trail.size()):
			var a := Vector2(trail[i - 1][0], trail[i - 1][1])
			var b := Vector2(trail[i][0], trail[i][1])
			if Geometry2D.get_closest_point_to_segment(at, a, b).distance_squared_to(at) < 2.2:
				return true
	return false


func add_deciduous(foot: Vector3, height: float, random: RandomNumberGenerator,
		crowns: Array[Transform3D], stems: Array[Transform3D]) -> void:
	var foliage := height * random.randf_range(.56, .78)
	var angle := Basis(Vector3.UP, random.randf() * TAU)
	var canopy := angle.scaled_local(Vector3(foliage, height * .72, foliage * .92))
	crowns.append(Transform3D(canopy, foot + Vector3.UP * height * .62))
	crowns.append(Transform3D(canopy.scaled_local(Vector3(.71, .76, .76)),
		foot + Vector3.UP * height * .68 + angle.x * foliage * .28))
	stems.append(Transform3D(angle.scaled_local(Vector3(height * .066, height * .60, height * .066)),
		foot + Vector3.UP * height * .29))


func build_car(parent: Node3D, site: Vector2, heading: Vector2, color: Color) -> void:
	var car := StaticBody3D.new()
	car.name = "ParkedCar"
	parent.add_child(car)
	var p := at([site.x, site.y])
	var ahead := site + heading * 1.6
	var behind := site - heading * 1.6
	var grade := (float(ground.call(ahead.x, ahead.y)) - float(ground.call(behind.x, behind.y))) / 3.2
	car.position = p
	car.basis = Basis.looking_at(Vector3(heading.x, grade, heading.y).normalized())
	var enamel := Kit.paint(color, .32, .35)
	var rubber := Kit.paint(Color("#26292a"), .96)
	var glass := Kit.paint(Color("#3b4c58"), .32, .26)
	var trim := Kit.paint(Color("#797e83"), .49, .35)
	body_shell(car, [Vector3(0, .25, 1.74), Vector3(0, .40, 2.17), Vector3(0, .76, 2.05),
		Vector3(0, .87, 1.34), Vector3(0, .87, -.91), Vector3(0, .67, -2.13), Vector3(0, .33, -2.19),
		Vector3(0, .25, -1.78)], .89, enamel)
	body_shell(car, [Vector3(0, .80, 1.31), Vector3(0, 1.47, .51), Vector3(0, 1.44, -.62),
		Vector3(0, .88, -1.37), Vector3(0, .79, -1.41)], .72, glass)
	Kit.box_at(car, Vector3(0, 1.44, -.04), Vector3(1.38, .066, 1.14), enamel)
	for side: float in [-1.0, 1.0]:
		for wheel: float in [-1.34, 1.31]:
			var tire := CylinderMesh.new()
			tire.top_radius = .31
			tire.bottom_radius = .31
			tire.height = .19
			tire.radial_segments = 18
			var spindle := Vector3(side * .82, .31, wheel)
			Kit.mesh_at(car, tire, spindle, rubber).rotation.z = PI / 2.0
			var hub := tire.duplicate() as CylinderMesh
			hub.top_radius = .174
			hub.bottom_radius = .174
			hub.height = .019
			Kit.mesh_at(car, hub, spindle + Vector3(side * .096, 0, 0), trim).rotation.z = PI / 2.0
		Kit.box_at(car, Vector3(side * .69, .59, -2.126), Vector3(.31, .13, .08), Kit.paint(Color("#ddd8c6")))
		Kit.box_at(car, Vector3(side * .69, .58, 2.126), Vector3(.33, .12, .08), Kit.paint(Color("#992430")))
	Kit.collider(car, Vector3(0, .68, 0), Vector3(1.76, 1.35, 4.25))


func body_shell(parent: Node3D, profile: Array[Vector3], width: float, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in profile.size():
		var a := profile[i]
		var b := profile[(i + 1) % profile.size()]
		var left := Vector3.LEFT * width
		var right := Vector3.RIGHT * width
		for point: Vector3 in [a + left, b + left, a + right, b + left, b + right, a + right]:
			surface.add_vertex(point)
	for i in range(1, profile.size() - 1):
		var left := Vector3.LEFT * width
		var right := Vector3.RIGHT * width
		for point: Vector3 in [profile[0] + left, profile[i + 1] + left, profile[i] + left,
				profile[0] + right, profile[i] + right, profile[i + 1] + right]:
			surface.add_vertex(point)
	surface.generate_normals()
	Kit.mesh_at(parent, surface.commit(), Vector3.ZERO, material)


func at(pair: Array) -> Vector3:
	return Vector3(pair[0], ground.call(pair[0], pair[1]), pair[1])
