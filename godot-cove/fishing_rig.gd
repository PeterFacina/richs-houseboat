extends Node3D

const Kit = preload("res://scenery.gd")
const HandModel = preload("res://river_hands.gd")
const RichModel = preload("res://rich_model.gd")
const SEGMENTS := 16
const GUIDES := [0.16, 0.31, 0.47, 0.62, 0.76, 0.89, 1.0]
const PUNCH_DURATION := .36

var remote_only := false
var blank_mesh: MeshInstance3D
var blank_surface := ArrayMesh.new()
var last_blank_flex := Vector2.INF
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
var forearms: Array[MeshInstance3D] = []
var motion_amount := .65
var hands_blend := 0.0
var punch_hand := 1
var punch_elapsed := PUNCH_DURATION


func _ready() -> void:
	name = "FishingTackle"
	build_rod()
	if not remote_only:
		build_net()


func build_fists(camera: Camera3D) -> void:
	fists = Node3D.new()
	fists.name = "Fists"
	camera.add_child(fists)
	for side in [-1.0, 1.0]:
		var hand := HandModel.build(fists, side, false, "relaxed", false)
		fist_hands.append(hand)
		hand.position = Vector3(side * .315, -.34, -.54)
		forearms.append(make_sleeve(fists))
	fists.hide()


func punch() -> void:
	if punch_elapsed >= PUNCH_DURATION:
		punch_hand = 1 - punch_hand
		punch_elapsed = 0.0


func update_hands(delta: float, clock: float, show_hands: bool, fists_raised: bool) -> void:
	hands_blend = move_toward(hands_blend, 1.0 if show_hands else 0.0, delta * 4.5)
	fists.visible = hands_blend > .005
	if not fists_raised:
		punch_elapsed = PUNCH_DURATION
	if not fists.visible:
		return
	punch_elapsed = minf(punch_elapsed + delta, PUNCH_DURATION)
	var reach := smoothstep(0.0, .095, punch_elapsed) * (1.0 - smoothstep(.105, PUNCH_DURATION, punch_elapsed))
	for index in fist_hands.size():
		var side := -1.0 if index == 0 else 1.0
		var sway := sin(clock * 2.3 + index) * .005 * motion_amount
		var hand := fist_hands[index]
		HandModel.set_pose(hand, "fist" if fists_raised else "relaxed")
		var extension := reach if index == punch_hand else 0.0
		var idle := Vector3(side * .315, -.34 + sway, -.54)
		var wrist_turn := Vector3(-.10, side * .22, -side * .12)
		if fists_raised:
			idle = Vector3(side * .235, -.285 + sway, -.49)
			wrist_turn = Vector3(lerpf(-.24, -.02, extension), side * .15, -side * .16)
		var target := idle.lerp(Vector3(side * .085, -.105, -.88), extension)
		target.y -= (1.0 - smoothstep(0, 1, hands_blend)) * .4
		hand.position = hand.position.lerp(target, 1.0 - exp(-delta * 18))
		hand.quaternion = hand.quaternion.slerp(Basis.from_euler(wrist_turn).get_rotation_quaternion(), 1.0 - exp(-delta * 15))
		var elbow := Vector3(side * .43, -.57, -.18).lerp(Vector3(side * .30, -.53, -.44), extension)
		fit_cylinder(forearms[index], hand.position, elbow)


func build_rod() -> void:
	rod = Node3D.new()
	rod.position = Vector3(.215, -.31, -.63)
	add_child(rod)
	var graphite := Kit.paint(Color("#202a2b"), .70, .08)
	var metal := Kit.paint(Color("#a4ada7"), .63, .30)
	var dark := Kit.paint(Color("#252e30"), .78, .08)
	var cork := Kit.paint(Color("#aa875a"), .95)
	var rubber := Kit.paint(Color("#272d2a"), .94)
	# Separated grip / reel-seat sections avoid the old coplanar wrapping tubes.
	cylinder(rod, Vector3(0, 0, .246), Vector3(0, 0, .035), .018, .0165, cork)
	cylinder(rod, Vector3(0, 0, .265), Vector3(0, 0, .247), .019, .0185, rubber)
	cylinder(rod, Vector3(0, 0, .034), Vector3(0, .012, -.105), .0155, .013, dark)
	cylinder(rod, Vector3(0, .012, -.106), Vector3(-.014, .032, -.239), .014, .010, cork)
	for z: float in [.025, -.085]:
		cylinder(rod, Vector3(0, .004, z + .004), Vector3(0, .004, z), .0168, .0168, metal)
	blank_mesh = no_shadow(Kit.mesh_at(rod, blank_surface, Vector3.ZERO, graphite))
	for index in GUIDES.size():
		var radius := lerpf(.016, .0035, float(index) / (GUIDES.size() - 1))
		var guide := Node3D.new()
		rod.add_child(guide)
		guide_rings.append(guide)
		var ring := TorusMesh.new()
		ring.inner_radius = radius * .80
		ring.outer_radius = radius
		ring.rings = 20
		ring.ring_segments = 8
		var eyelet := no_shadow(Kit.mesh_at(guide, ring, Vector3(0, -radius * 1.15, 0), metal))
		eyelet.rotation.x = PI * .5
		cylinder(guide, Vector3(0, 0, .014), Vector3(0, -radius * .65, 0), .0024, .0018, dark)
	tip = Node3D.new()
	guide_rings[-1].add_child(tip)
	tip.position.y = -.004
	# A compact 2500-size spinning reel, with one spool line surface and a bail.
	cylinder(rod, Vector3(0, -.012, -.025), Vector3(0, -.071, -.035), .008, .011, dark)
	oval(rod, Vector3(0, -.086, -.035), Vector3(.061, .066, .091), dark)
	var spool := Vector3(0, -.098, -.122)
	cylinder(rod, spool + Vector3.BACK * .026, spool + Vector3.FORWARD * .026, .027, .027, Kit.paint(Color("#5e6e63"), .83))
	for end: float in [-.029, .029]:
		cylinder(rod, spool + Vector3.BACK * (end + .002), spool + Vector3.BACK * (end - .002), .033, .033, metal)
	cylinder(rod, spool + Vector3.FORWARD * .033, spool + Vector3.FORWARD * .043, .016, .013, dark)
	rotor = Node3D.new()
	rod.add_child(rotor)
	rotor.position = spool
	var wire := SurfaceTool.new()
	wire.begin(Mesh.PRIMITIVE_TRIANGLES)
	for index in 24:
		var a := index * PI / 24.0
		var b := (index + 1) * PI / 24.0
		add_wire(wire, Vector3(cos(a) * .044, sin(a) * .044, .005 - sin(a) * .025),
			Vector3(cos(b) * .044, sin(b) * .044, .005 - sin(b) * .025), .0015)
	no_shadow(Kit.mesh_at(rotor, wire.commit(), Vector3.ZERO, metal))
	crank = Node3D.new()
	rod.add_child(crank)
	crank.position = Vector3(-.029, -.087, -.025)
	crank_knob = Node3D.new()
	crank.add_child(crank_knob)
	crank_knob.position = Vector3(-.037, -.041, .018)
	cylinder(crank, Vector3.ZERO, crank_knob.position, .005, .004, metal)
	oval(crank_knob, Vector3.LEFT * .007, Vector3(.024, .019, .027), rubber)
	if not remote_only:
		grip_hand = glove(1)
		HandModel.align(grip_hand, Vector3(0, 0, .12), Basis.IDENTITY, "shaft")
		reel_hand = glove(-1)
		HandModel.align(reel_hand, Vector3(-.073, -.125, -.007), Basis(Vector3.UP, PI * .5), "shaft")
	update_blank()


func glove(side: float, sleeve := true) -> Node3D:
	return HandModel.build(rod, side, sleeve)


func make_sleeve(parent: Node3D) -> MeshInstance3D:
	return no_shadow(RichModel.loft(parent, [Vector4(-.5,.026,.023,.026),
		Vector4(-.3,.030,.026,.031), Vector4(0,.035,.030,.036),
		Vector4(.5,.043,.036,.043)], Kit.paint(Color("#465653"), .89), 20))


func wrist_anchor(hand: Node3D) -> Vector3:
	return HandModel.wrist(hand)


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
	rod.rotation.x = lerpf(rod.rotation.x, sin(clock * 1.4) * .011 * motion_amount + swing + set_hook + raised
		- net_up * .76, 1.0 - exp(-delta * 27))
	rod.rotation.y = lerpf(rod.rotation.y, sweep + sideways * tension * .20, 1.0 - exp(-delta * 17))
	rod.rotation.z = lerp_angle(rod.rotation.z, -.082 + cos(clock * 1.1) * .009 * motion_amount + tension * .148 * sideways, 1.0 - exp(-delta * 15))
	rod.visible = net_up < .76
	flex = lerpf(flex, tension * .48 + absf(swing) * .17 + set_hook * .22, 1.0 - exp(-delta * 21))
	side_flex = lerpf(side_flex, sideways * tension * .36, 1.0 - exp(-delta * 17))
	reel_angle = fposmod(reel_angle + retrieve * delta * 17.0, TAU)
	crank.rotation.x = reel_angle
	rotor.rotation.z = fposmod(rotor.rotation.z + delta * (retrieve * 21.0 - payout * 30.0), TAU)
	if not remote_only:
		var palm := Vector3(-.095, -.10, .03)
		if retrieve > .03:
			palm = rod.to_local(crank_knob.global_position) + Vector3(-.005, .002, 0)
		HandModel.align(grip_hand, Vector3(0, 0, .12), Basis.IDENTITY, "shaft")
		HandModel.align(reel_hand, palm, Basis(Vector3.UP, PI * .5), "shaft")
		reel_hand.visible = net_up < .62
	update_blank()


func blank(t: float) -> Vector3:
	return Vector3(lerpf(-.014, -.215, t) + side_flex * t * t,
		lerpf(.032, .412, t) - flex * t * t, lerpf(-.239, -1.99, t) + .072 * flex * t * t)


func update_blank() -> void:
	if Vector2(flex, side_flex).distance_to(last_blank_flex) > .002:
		last_blank_flex = Vector2(flex, side_flex)
		var surface := SurfaceTool.new()
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
		for ring in 32:
			for side in 12:
				for corner: Vector2i in [Vector2i(0,0), Vector2i(1,0), Vector2i(0,1), Vector2i(0,1), Vector2i(1,0), Vector2i(1,1)]:
					var t := (ring + corner.x) / 32.0
					var angle := (side + corner.y) * TAU / 12.0
					var tangent := (blank(minf(1, t + .001)) - blank(maxf(0, t - .001))).normalized()
					var u := tangent.cross(Vector3.UP).normalized()
					var normal := u * cos(angle) + tangent.cross(u) * sin(angle)
					var radius := lerpf(.008, .0014, t)
					surface.set_normal(normal)
					surface.add_vertex(blank(t) + normal * radius)
		blank_surface.clear_surfaces()
		surface.commit(blank_surface)
	for index in GUIDES.size():
		var t: float = GUIDES[index]
		guide_rings[index].position = blank(t)
		guide_rings[index].basis = Basis.looking_at(blank(maxf(0, t - .012)) - blank(t))


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
