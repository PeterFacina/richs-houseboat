extends Node3D

const Kit = preload("res://scenery.gd")
const RichModel = preload("res://rich_model.gd")
const RELAXED_HAND = preload("res://ottawa/rich/gesture.res")
const CLOSED_HAND = preload("res://ottawa/rich/grip.res")
const SEGMENTS := 16
const GUIDES := [0.16, 0.31, 0.47, 0.62, 0.76, 0.89, 1.0]
const PUNCH_DURATION := .36

var rod: Node3D
var tip: Node3D
var net: Node3D
var grip_hand: Node3D
var reel_hand: Node3D
var rotor: Node3D
var crank: Node3D
var crank_knob: Node3D
var sections: Array[MeshInstance3D] = []
var guide_rings: Array[Node3D] = []
var flex := 0.0
var side_flex := 0.0
var reel_angle := 0.0
var fists: Node3D
var fist_hands: Array[Node3D] = []
var relaxed_hands: Array[MeshInstance3D] = []
var closed_hands: Array[MeshInstance3D] = []
var forearms: Array[MeshInstance3D] = []
var punch_hand := 1
var punch_elapsed := PUNCH_DURATION


func _ready() -> void:
	name = "FishingTackle"
	build_rod()
	build_net()


func build_fists(camera: Camera3D) -> void:
	fists = Node3D.new()
	fists.name = "Fists"
	camera.add_child(fists)
	var skin := Kit.paint(Color("#c18b71"), .83)
	skin.disable_receive_shadows = true
	for side in [-1.0, 1.0]:
		var hand := Node3D.new()
		fists.add_child(hand)
		fist_hands.append(hand)
		var relaxed := no_shadow(Kit.mesh_at(hand, RELAXED_HAND, Vector3.ZERO, skin))
		var closed := no_shadow(Kit.mesh_at(hand, CLOSED_HAND, Vector3.ZERO, skin))
		# The source meshes point down the wrist axis and use opposite hands.
		relaxed.rotation.x = PI * .5
		relaxed.scale.x = side
		closed.rotation.x = PI * .5
		closed.scale.x = -side
		relaxed_hands.append(relaxed)
		closed_hands.append(closed)
		forearms.append(no_shadow(RichModel.loft(fists, [
			Vector4(-.50, .024, .023, .023),
			Vector4(-.33, .027, .026, .027),
			Vector4(-.12, .032, .031, .033),
			Vector4(.15, .040, .036, .042),
			Vector4(.50, .045, .042, .048),
		], skin, 20)))
	fists.hide()


func punch() -> void:
	if punch_elapsed >= PUNCH_DURATION:
		punch_hand = 1 - punch_hand
		punch_elapsed = 0.0


func update_hands(delta: float, clock: float, show_hands: bool, fists_raised: bool) -> void:
	fists.visible = show_hands
	if not fists_raised:
		punch_elapsed = PUNCH_DURATION
	if not show_hands:
		return
	punch_elapsed = minf(punch_elapsed + delta, PUNCH_DURATION)
	var reach := smoothstep(0.0, .095, punch_elapsed) * (1.0 - smoothstep(.105, PUNCH_DURATION, punch_elapsed))
	for index in fist_hands.size():
		var side := -1.0 if index == 0 else 1.0
		var sway := sin(clock * 2.3 + index) * .007
		var hand := fist_hands[index]
		relaxed_hands[index].visible = not fists_raised
		closed_hands[index].visible = fists_raised
		var extension := reach if index == punch_hand else 0.0
		var idle := Vector3(side * .315, -.34 + sway, -.54)
		var wrist_turn := Vector3(-.10, side * .22, -side * .12)
		if fists_raised:
			idle = Vector3(side * .235, -.285 + sway, -.49)
			wrist_turn = Vector3(lerpf(-.24, -.02, extension), side * .15, -side * .16)
		hand.position = idle.lerp(Vector3(side * .085, -.105, -.88), extension)
		hand.rotation = wrist_turn
		var elbow := Vector3(side * .43, -.57, -.18).lerp(Vector3(side * .30, -.53, -.44), extension)
		fit_cylinder(forearms[index], hand.position, elbow)


func build_rod() -> void:
	rod = Node3D.new()
	rod.position = Vector3(.232, -.308, -.63)
	add_child(rod)
	var graphite := Kit.paint(Color("#263830"), .36, .21)
	var windings := Kit.paint(Color("#a08350"), .4, .22)
	var brushed := Kit.paint(Color("#9aaba3"), .34, .59)
	var dark := Kit.paint(Color("#253138"), .57, .19)
	var cork := Kit.paint(Color("#a58358"), .94)
	var thread := Kit.paint(Color("#6d8276"), .69)
	var rubber := Kit.paint(Color("#272a26"), .90)
	cylinder(rod, Vector3(0, -.024, .276), Vector3(0, -.009, .027), .029, .026, cork)
	for i in 8:
		var z := .054 + i * .028
		cylinder(rod, Vector3(0, -.009 - i * .0018, z), Vector3(0, -.009 - i * .0018, z + .003), .029, .029,
			thread if i % 3 == 0 else cork)
	cylinder(rod, Vector3(0, -.029, .291), Vector3(0, -.024, .265), .033, .029, rubber)
	cylinder(rod, Vector3(0, -.006, .062), Vector3(0, .018, -.121), .022, .018, dark)
	for z: float in [.030, -.068, -.09, -.12]:
		cylinder(rod, Vector3(0, .007 - z * .09, z + .008), Vector3(0, .007 - z * .09, z), .026, .024, brushed)
	cylinder(rod, Vector3(0, .019, -.13), Vector3(-.014, .032, -.239), .016, .014, cork)
	for i in SEGMENTS:
		var mesh := CylinderMesh.new()
		mesh.height = 1.0
		mesh.top_radius = lerpf(.012, .0026, float(i + 1) / SEGMENTS)
		mesh.bottom_radius = lerpf(.012, .0026, float(i) / SEGMENTS)
		mesh.radial_segments = 11
		mesh.rings = 1
		sections.append(no_shadow(Kit.mesh_at(rod, mesh, Vector3.ZERO, graphite)))
	for i in GUIDES.size():
		var size := lerpf(.030, .008, float(i) / (GUIDES.size() - 1))
		var guide := Node3D.new()
		rod.add_child(guide)
		guide_rings.append(guide)
		var ring := TorusMesh.new()
		ring.inner_radius = size * .80
		ring.outer_radius = size
		ring.rings = 20
		ring.ring_segments = 8
		var eyelet := no_shadow(Kit.mesh_at(guide, ring, Vector3(0, -size * .94, 0), brushed))
		eyelet.rotation.x = PI / 2
		cylinder(guide, Vector3(-.003, -.001, .027), Vector3(-size * .51, -size * .50, 0), .0034, .0024, windings)
		cylinder(guide, Vector3(.003, -.001, .027), Vector3(size * .51, -size * .50, 0), .0034, .0024, windings)
	tip = Node3D.new()
	guide_rings[-1].add_child(tip)
	tip.position.y = -.008

	var mount := Vector3(0, -.136, -.031)
	cylinder(rod, Vector3(0, -.019, -.015), Vector3(0, -.105, -.006), .019, .027, dark)
	oval(rod, mount, Vector3(.088, .107, .141), dark)
	oval(rod, mount + Vector3(0, -.012, .044), Vector3(.087, .075, .071), graphite)
	var spool := Vector3(0, -.145, -.158)
	cylinder(rod, spool + Vector3.BACK * .060, spool + Vector3.FORWARD * .043, .050, .044, brushed)
	var line := Kit.paint(Color("#637d6e"), .46, .09)
	cylinder(rod, spool + Vector3.BACK * .029, spool + Vector3.FORWARD * .032, .044, .047, line)
	for i in 7:
		var band := spool + Vector3.FORWARD * (.026 - i * .0083)
		cylinder(rod, band, band + Vector3.FORWARD * .0021, .047, .047, thread)
	cylinder(rod, spool + Vector3.FORWARD * .045, spool + Vector3.FORWARD * .054, .052, .048, windings)
	cylinder(rod, spool + Vector3.FORWARD * .057, spool + Vector3.FORWARD * .075, .029, .025, dark)
	rotor = Node3D.new()
	rotor.position = spool
	rod.add_child(rotor)
	var bail := SurfaceTool.new()
	bail.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 20:
		var a := float(i) / 20 * PI * 1.04
		var b := float(i + 1) / 20 * PI * 1.04
		add_wire(bail, Vector3(cos(a) * .071, sin(a) * .071, .011 - sin(a) * .048),
			Vector3(cos(b) * .071, sin(b) * .071, .011 - sin(b) * .048), .0026)
	no_shadow(Kit.mesh_at(rotor, bail.commit(), Vector3.ZERO, brushed))
	crank = Node3D.new()
	crank.position = Vector3(-.044, -.144, -.025)
	rod.add_child(crank)
	crank_knob = Node3D.new()
	crank_knob.position = Vector3(-.051, -.057, .039)
	crank.add_child(crank_knob)
	cylinder(crank, Vector3.ZERO, Vector3(-.036, -.044, .031), .009, .008, brushed)
	cylinder(crank, Vector3(-.036, -.044, .031), crank_knob.position, .009, .007, brushed)
	oval(crank_knob, Vector3.LEFT * .012, Vector3(.037, .027, .034), rubber)
	grip_hand = glove(1.0)
	grip_hand.position = Vector3(.008, -.011, .141)
	reel_hand = glove(-1.0)
	reel_hand.position = Vector3(-.133, -.156, .051)
	update_blank()


func glove(side: float, sleeve := true) -> Node3D:
	var hand := Node3D.new()
	rod.add_child(hand)
	var fabric := Kit.paint(Color("#3c4a42"), .91)
	var panels := Kit.paint(Color("#262e2b"), .93)
	var seam := Kit.paint(Color("#718072"), .91)
	var cloth := Kit.paint(Color("#4a5549"), .93)
	oval(hand, Vector3(side * .032, -.012, .037), Vector3(.050, .083, .106), fabric)
	oval(hand, Vector3(side * .055, .009, .053), Vector3(.016, .059, .075), panels)
	for i in 4:
		var z := -.010 + i * .023
		var low := -.044 + i * .002
		cylinder(hand, Vector3(side * .033, .005, z), Vector3(side * .029, low * .63, z - .007), .0115, .0105, fabric)
		cylinder(hand, Vector3(side * .029, low * .63, z - .007), Vector3(-side * .004, low, z - .008), .0105, .0092, panels)
		cylinder(hand, Vector3(-side * .004, low, z - .008), Vector3(-side * .024, -.008, z - .006), .0092, .0078, fabric)
		oval(hand, Vector3(-side * .024, -.008, z - .006), Vector3(.016, .019, .018), fabric)
		Kit.beam(hand, Vector3(side * .044, -.003, z - .007), Vector3(side * .042, -.020, z - .007), .0019, seam)
	cylinder(hand, Vector3(side * .045, .007, .043), Vector3(side * .027, .042, .034), .017, .015, fabric)
	cylinder(hand, Vector3(side * .027, .042, .034), Vector3(-side * .015, .032, .001), .014, .010, panels)
	oval(hand, Vector3(-side * .015, .032, .001), Vector3(.020, .016, .021), fabric)
	var wrist := Vector3(side * .042, -.019, .091)
	var arm := Vector3(side * .145, -.114, .365)
	cylinder(hand, wrist, wrist.lerp(arm, .16), .040, .046, panels)
	if sleeve:
		cylinder(hand, wrist.lerp(arm, .14), arm, .046, .065, cloth)
		cylinder(hand, wrist.lerp(arm, .28), wrist.lerp(arm, .31), .055, .056, seam)
	return hand


func pose_rod(delta: float, clock: float, tension: float, sideways: float, cast: float,
		hook: float, lift: bool, retrieve: float, payout: float, net_up: float) -> void:
	var swing := 0.0
	var sweep := 0.0
	if cast >= 0.0:
		var backswing := smoothstep(0.0, .54, cast)
		var forward := smoothstep(.54, 1.17, cast)
		var recovery := smoothstep(1.17, 2.78, cast)
		swing = .67 * backswing - .99 * forward + .32 * recovery
		sweep = .29 * backswing - .43 * forward + .14 * recovery
	var set_hook := sin(clampf(hook, 0, 1) * PI) * .52
	var raised := .24 if lift else 0.0
	rod.rotation.x = lerpf(rod.rotation.x, sin(clock * 1.4) * .017 + swing + set_hook + raised
		- net_up * .76, 1.0 - exp(-delta * 27))
	rod.rotation.y = lerpf(rod.rotation.y, sweep + sideways * tension * .20, 1.0 - exp(-delta * 17))
	rod.rotation.z = -.082 + cos(clock * 1.1) * .013 + tension * .148 * sideways
	rod.visible = net_up < .76
	flex = lerpf(flex, tension * .48 + absf(swing) * .17 + set_hook * .22, 1.0 - exp(-delta * 21))
	side_flex = lerpf(side_flex, sideways * tension * .36, 1.0 - exp(-delta * 17))
	reel_angle = fposmod(reel_angle + retrieve * delta * 17.0, TAU)
	crank.rotation.x = reel_angle
	rotor.rotation.z = fposmod(rotor.rotation.z + delta * (retrieve * 21.0 - payout * 30.0), TAU)
	var palm := Vector3(-.133, -.156, .051)
	if retrieve > .03:
		palm = rod.to_local(crank_knob.global_position) + Vector3(-.021, .004, -.015)
	reel_hand.position = reel_hand.position.lerp(palm, 1.0 - exp(-delta * 24))
	reel_hand.rotation.x = sin(reel_angle) * retrieve * .25
	reel_hand.visible = net_up < .62
	update_blank()


func blank(t: float) -> Vector3:
	return Vector3(lerpf(-.014, -.215, t) + side_flex * t * t,
		lerpf(.032, .412, t) - flex * t * t, lerpf(-.239, -1.99, t) + .072 * flex * t * t)


func update_blank() -> void:
	for i in SEGMENTS:
		var a := blank(float(i) / SEGMENTS)
		var b := blank(float(i + 1) / SEGMENTS)
		fit_cylinder(sections[i], a, b)
	for i in GUIDES.size():
		var t: float = GUIDES[i]
		var a := blank(maxf(0, t - .012))
		var b := blank(t)
		guide_rings[i].position = b
		guide_rings[i].basis = Basis.looking_at(a - b)


func build_net() -> void:
	net = Node3D.new()
	add_child(net)
	var frame := Kit.paint(Color("#929982"), .43, .47)
	var grip := Kit.paint(Color("#404843"), .72)
	var mesh_material := Kit.paint(Color("#39483b"), .83)
	var hoop := SurfaceTool.new()
	var web := SurfaceTool.new()
	hoop.begin(Mesh.PRIMITIVE_TRIANGLES)
	web.begin(Mesh.PRIMITIVE_TRIANGLES)
	const LINKS := 38
	for i in LINKS:
		var angle := float(i) / LINKS * TAU
		var next := float(i + 1) / LINKS * TAU
		add_wire(hoop, knot(angle, 0), knot(next, 0), .007)
		for row in 6:
			var f := float(row) / 6.0
			var t := float(row + 1) / 6.0
			var shift := .027 * row
			add_wire(web, knot(angle + shift, f), knot(next + shift, f), .00145)
			add_wire(web, knot(angle + shift, f), knot(angle + shift + .027, t), .0015)
		add_wire(web, knot(angle + .162, 1), knot(next + .162, 1), .00145)
		if i % 2 == 0:
			add_wire(web, knot(angle + .162, 1), Vector3(0, -.162, 0), .00136)
	no_shadow(Kit.mesh_at(net, hoop.commit(), Vector3.ZERO, frame))
	no_shadow(Kit.mesh_at(net, web.commit(), Vector3.ZERO, mesh_material))
	cylinder(net, Vector3(.31, -.012, .16), Vector3(.57, -.075, .44), .015, .021, frame)
	cylinder(net, Vector3(.55, -.072, .426), Vector3(.67, -.105, .58), .031, .029, grip)
	var hand := glove(-1.0)
	hand.reparent(net, false)
	hand.position = Vector3(.59, -.086, .464)
	hand.rotation.y = .62
	net.hide()


func knot(angle: float, level: float) -> Vector3:
	var rim := lerpf(1.0, .17, pow(level, 1.40))
	return Vector3(cos(angle) * .386 * rim, -.155 * sin(level * PI * .52), sin(angle) * .272 * rim)


func show_net(at: Vector3, progress: float) -> void:
	net.show()
	var f := smoothstep(0.0, .94, progress)
	var approach := to_local(at + Vector3.UP * .070)
	net.position = approach.lerp(Vector3(.006, -.246, -.76), f)
	net.rotation = Vector3(lerpf(.10, .15, f), lerpf(.21, -.26, f), lerpf(.0, -.105, f))


func cylinder(parent: Node3D, a: Vector3, b: Vector3, radius_a: float, radius_b: float, material: Material) -> MeshInstance3D:
	var model := CylinderMesh.new()
	model.height = 1.0
	model.bottom_radius = radius_a
	model.top_radius = radius_b
	model.radial_segments = 14
	model.rings = 1
	var item := no_shadow(Kit.mesh_at(parent, model, Vector3.ZERO, material))
	fit_cylinder(item, a, b)
	return item


func fit_cylinder(item: MeshInstance3D, a: Vector3, b: Vector3) -> void:
	var up := (b - a).normalized()
	var right := up.cross(Vector3.FORWARD if absf(up.z) < .96 else Vector3.UP).normalized()
	item.transform = Transform3D(Basis(right, up * a.distance_to(b), right.cross(up)), (a + b) * .5)


func oval(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> void:
	var shape := SphereMesh.new()
	shape.radial_segments = 18
	shape.rings = 9
	no_shadow(Kit.mesh_at(parent, shape, at, material)).scale = size


func no_shadow(item: MeshInstance3D) -> MeshInstance3D:
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	return item


func add_wire(surface: SurfaceTool, a: Vector3, b: Vector3, radius: float) -> void:
	var direction := (b - a).normalized()
	var i := direction.cross(Vector3.UP if absf(direction.y) < .9 else Vector3.RIGHT).normalized()
	var j := direction.cross(i)
	for side in 6:
		var theta := float(side) * TAU / 6.0
		var next := theta + TAU / 6.0
		var radial_a := i * cos(theta) + j * sin(theta)
		var radial_b := i * cos(next) + j * sin(next)
		surface.set_normal((radial_a + radial_b).normalized())
		for p: Vector3 in [a + radial_a * radius, a + radial_b * radius, b + radial_a * radius,
				a + radial_b * radius, b + radial_b * radius, b + radial_a * radius]:
			surface.add_vertex(p)
