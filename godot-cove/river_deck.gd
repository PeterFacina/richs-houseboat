extends Node3D

const Kit = preload("res://scenery.gd")
const Boat = preload("res://houseboat.gd")
const Ledger = preload("res://river_ledger.gd")

var vessel: Boat
var tools: Node3D
var panel: Label3D
var pump: Node3D
var battery: Node3D
var capstan: Node3D
var winch: Node3D
var freight: Node3D
var barge: Node3D
var jib: Node3D
var object: Node3D
var marker: Label3D
var drum: Node3D
var cable: MeshInstance3D
var moor_lines: Array[MeshInstance3D] = []
var rescue_tow: Node3D
var steel := Kit.paint(Color("#64777b"), .47, .29)
var bronze := Kit.paint(Color("#bb955c"), .58, .21)
var wood := Kit.paint(Color("#a5845f"))
var dark := Kit.paint(Color("#303e42"))
var warning := Kit.paint(Color("#d58d43"))
var recovery_pose := Vector3.ZERO
var task_kind := ""
var cargo_kind := ""


func _ready() -> void:
	cable = rope(self, .021, dark)
	cable.hide()
	for i in 2:
		moor_lines.append(rope(self, .027, bronze))
		moor_lines.back().hide()


func rope(parent: Node3D, thickness: float, material: Material) -> MeshInstance3D:
	return Kit.box_at(parent, Vector3.ZERO, Vector3(thickness, thickness, 1.0), material)


func fit(boat: Boat) -> void:
	if is_instance_valid(tools):
		tools.free()
	vessel = boat
	tools = Node3D.new()
	boat.add_child(tools)
	winch = Node3D.new()
	tools.add_child(winch)
	winch.position = Vector3(.60, .34, -1.25) if boat.skiff else Vector3(.68, .75, -2.31)
	Kit.box_at(winch, Vector3(0, .038, 0), Vector3(.43, .079, .35), steel)
	for side in [-1.0, 1.0]:
		Kit.box_at(winch, Vector3(side * .17, .173, 0), Vector3(.09, .26, .18), steel)
	drum = Node3D.new()
	winch.add_child(drum)
	drum.position.y = .19
	cylinder(drum, Vector3.ZERO, .095, .24, dark).rotate_z(PI * .5)
	for i in 12:
		cylinder(drum, Vector3((i - 5.5) * .016, 0, 0), .104, .008, steel).rotate_z(PI * .5)
	Kit.box_at(drum, Vector3(0, .101, 0), Vector3(.105, .033, .07), warning)
	pump = Node3D.new()
	tools.add_child(pump)
	pump.position = Vector3(-.56, .39, -.92) if boat.skiff else Vector3(.67, .788, 1.02)
	Kit.box_at(pump, Vector3(0, .027, 0), Vector3(.41, .061, .29), steel)
	cylinder(pump, Vector3(.017, .195, .01), .121, .27, steel).rotate_z(PI * .5)
	cylinder(pump, Vector3(-.15, .171, 0), .087, .102, dark).rotate_z(PI * .5)
	for i in 7:
		cylinder(pump, Vector3(-.084 + i * .026, .194, .01), .126, .011, dark).rotate_z(PI * .5)
	cylinder(pump, Vector3(.133, .238, .012), .102, .133, warning)
	cylinder(pump, Vector3(.131, .339, .015), .029, .10, bronze)
	Kit.beam(pump, Vector3(.131, .365, .015), Vector3(.131, .369, -.185), .052, bronze)
	battery = Node3D.new()
	tools.add_child(battery)
	battery.position = Vector3(.54, .39, 1.32) if boat.skiff else Vector3(.65, .757, 1.74)
	Kit.box_at(battery, Vector3(0, .15, 0), Vector3(.40, .27, .31), dark)
	Kit.box_at(battery, Vector3(0, .303, 0), Vector3(.405, .044, .316), steel)
	for side in [-1.0, 1.0]:
		cylinder(battery, Vector3(side * .128, .344, .082), .026, .047, bronze)
	var panel_mount := Vector3(.54, 1.204, -.07) if boat.skiff else Vector3(-.63, 1.66, -2.36)
	var console := Node3D.new()
	console.name = "BatteryBilgeDisplay"
	tools.add_child(console)
	console.position = panel_mount
	if boat.skiff:
		var foot := Vector3(panel_mount.x, .36, panel_mount.z)
		var bracket := panel_mount - Vector3.UP * .105
		Kit.box_at(tools, foot.lerp(bracket, .5), Vector3(.076, bracket.y - foot.y, .085), dark).name = "StatusPanelPedestal"
		Kit.box_at(tools, foot + Vector3.UP * .009, Vector3(.172, .022, .162), steel).name = "StatusPanelDeckPlate"
		for x in [-.061, .061]:
			for z in [-.055, .055]:
				cylinder(tools, foot + Vector3(x, .022, z), .008, .008, dark)
	else:
		console.rotation = Vector3(-.47, .51, 0)
		var display_back := console.transform * Vector3(0, -.062, -.028)
		Kit.beam(tools, Vector3(-.26, 1.56, -2.45), display_back, .074, dark).name = "StatusPanelHelmBracket"
	Kit.box_at(console, Vector3.ZERO, Vector3(.475, .235, .081), dark)
	Kit.box_at(console, Vector3(0, 0, .044), Vector3(.458, .217, .018), Kit.paint(Color("#273c3a")))
	panel = label(console, "", Vector3(0, -.001, .055), .0018, Color("#e4efd0"))
	Kit.box_at(console, Vector3(.19, -.086, .057), Vector3(.022, .013, .008), warning)
	freight = Node3D.new()
	tools.add_child(freight)
	freight.position = Vector3(-.57, .37, 1.22) if boat.skiff else Vector3(.61, .754, -2.57)
	cargo_kind = ""
	freight.hide()


func label(parent: Node3D, text: String, at: Vector3, pixel: float, ink: Color) -> Label3D:
	var display := Label3D.new()
	display.text = text
	display.modulate = ink
	display.pixel_size = pixel
	display.font_size = 25
	display.position = at
	display.outline_size = 3
	parent.add_child(display)
	return display


func cylinder(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = height
	mesh.radial_segments = 12
	return Kit.mesh_at(parent, mesh, at, material)


func crate(parent: Node3D, at: Vector3, extra := false) -> void:
	Kit.box_at(parent, at + Vector3.UP * .215, Vector3(.65, .43, .51), wood)
	for x in [-.217, .217]:
		Kit.box_at(parent, at + Vector3(x, .224, 0), Vector3(.056, .457, .538), steel)
	Kit.box_at(parent, at + Vector3(0, .234, .259), Vector3(.213, .104, .013), dark if extra else bronze)


func make_barge() -> Node3D:
	var tug := Node3D.new()
	add_child(tug)
	for side in [-1.0, 1.0]:
		Kit.box_at(tug, Vector3(side * 1.15, -.111, 0), Vector3(.77, .62, 4.90), dark)
		Kit.box_at(tug, Vector3(side * 1.15, .208, 0), Vector3(.82, .090, 4.94), steel)
	for i in 15:
		Kit.box_at(tug, Vector3(0, .34, (i - 7) * .319), Vector3(2.95, .15, .306), wood)
	Kit.box_at(tug, Vector3(0, .427, -.05), Vector3(.66, .26, .73), dark)
	cylinder(tug, Vector3(0, .536, -.05), .39, .33, warning)
	Kit.box_at(tug, Vector3(0, 1.063, -.05), Vector3(.21, 1.31, .22), warning)
	jib = Node3D.new()
	tug.add_child(jib)
	jib.position = Vector3(0, 1.69, -.053)
	Kit.beam(jib, Vector3.ZERO, Vector3(0, 1.52, 2.02), .18, warning)
	Kit.beam(jib, Vector3(0, -.38, .0), Vector3(0, 1.52, 2.02), .088, steel)
	Kit.box_at(jib, Vector3(0, 1.52, 2.02), Vector3(.23, .22, .23), dark)
	var tow_seam := Kit.box_at(tug, Vector3.ZERO, Vector3(.026, .025, 1.0), dark)
	tow_seam.name = "TowLine"
	return tug


func rescue_boat() -> Node3D:
	var dinghy := Node3D.new()
	add_child(dinghy)
	Kit.box_at(dinghy, Vector3(0, .108, .14), Vector3(1.18, .36, 2.22), warning)
	for side in [-1.0, 1.0]:
		Kit.beam(dinghy, Vector3(side * .55, .264, -.80), Vector3(0, .324, -1.48), .14, warning)
		Kit.beam(dinghy, Vector3(side * .56, .257, -.83), Vector3(side * .56, .255, 1.14), .141, warning)
	Kit.box_at(dinghy, Vector3(0, .307, .63), Vector3(1.05, .13, .29), wood)
	Kit.box_at(dinghy, Vector3(0, .309, -.41), Vector3(1.03, .14, .41), wood)
	Kit.box_at(dinghy, Vector3(0, .315, 1.43), Vector3(.30, .52, .29), dark)
	var pennant := cylinder(dinghy, Vector3(.32, .71, .31), .023, .86, steel)
	Kit.box_at(pennant, Vector3(.106, .36, 0), Vector3(.213, .15, .034), warning)
	var line := rope(dinghy, .025, dark)
	line.name = "TowLine"
	line.hide()
	return dinghy


func set_target(kind: String, world: Vector3, title: String) -> void:
	if kind == task_kind and world.is_equal_approx(recovery_pose):
		return
	if is_instance_valid(object):
		object.queue_free()
	task_kind = kind
	recovery_pose = world
	if kind.is_empty():
		return
	object = rescue_boat() if kind == "rescue" else Node3D.new()
	if object.get_parent() == null:
		add_child(object)
	object.position = world
	if kind != "rescue":
		cylinder(object, Vector3(0, -.088, 0), .37, .26, steel)
		cylinder(object, Vector3(0, .134, 0), .24, .29, Kit.paint(Color("#71ad94")) if kind == "survey" else warning)
		Kit.box_at(object, Vector3(0, .52, 0), Vector3(.069, .77, .069), steel)
		Kit.box_at(object, Vector3(.05, .80, 0), Vector3(.33, .19, .045), warning)
		if kind == "salvage":
			var load_mesh := Node3D.new()
			object.add_child(load_mesh)
			load_mesh.name = "Lift"
			crate(load_mesh, Vector3.ZERO, true)
	marker = label(object, title, Vector3.UP * 2.2, .010, Color("#fff0c7"))
	marker.billboard = BaseMaterial3D.BILLBOARD_ENABLED


func dock_lines(a: Vector3, b: Vector3, line: MeshInstance3D) -> void:
	if a.distance_squared_to(b) < .0001:
		line.hide()
		return
	line.global_transform = Transform3D(Basis.looking_at(b - a,
		Vector3.FORWARD if absf((b - a).normalized().y) > .96 else Vector3.UP).scaled_local(Vector3(1, 1, a.distance_to(b))), (a + b) * .5)
	line.show()


func mooring(landing: Dictionary) -> void:
	if landing.is_empty():
		for line in moor_lines:
			line.hide()
		return
	var knot: Vector3 = landing.transfer + Vector3.UP * .08
	var direction: Vector3 = landing.forward
	for i in moor_lines.size():
		var seam := float(i * 2 - 1)
		var attach := vessel.to_global(Vector3(-.92, .51, seam * 1.42)) if vessel.skiff else \
			vessel.to_global(Vector3(-1.37, .81, seam * 2.14))
		dock_lines(attach, knot + direction * (seam * 1.18 + 1.13), moor_lines[i])


func animate_tow(craft: Node3D, offset: float, tow_length: float, delta: float, clock: float) -> void:
	var pos := vessel.to_global(Vector3(0, 0, offset))
	pos.y = vessel.sample(pos, clock) + .025
	var target := Transform3D(Basis.from_euler(Vector3(sin(clock * 1.5) * .032, vessel.heading,
		cos(clock * 1.85) * .054)), pos)
	if craft.visible and craft.global_position.distance_squared_to(pos) < 25.0:
		craft.global_transform = craft.global_transform.interpolate_with(target, 1.0 - exp(-delta * 7.5))
	else:
		craft.global_transform = target
	craft.show()
	dock_lines(vessel.to_global(Vector3(0, .52, 2.10 if vessel.skiff else 3.27)),
		craft.to_global(Vector3(0, .40, -tow_length)), craft.get_node("TowLine"))


func animate(delta: float, water_time: float, ledger: Ledger, live_target: Vector3, active_lift: float, clock: float) -> void:
	var status: Dictionary = ledger.state
	var job := ledger.active_job()
	var carrying: bool = not job.is_empty() and status.stage == "return" and job.kind in ["freight", "salvage", "dive"]
	if carrying and cargo_kind != job.kind:
		for model in freight.get_children():
			model.queue_free()
		crate(freight, Vector3.ZERO, job.kind != "freight")
		cargo_kind = job.kind
	freight.visible = carrying
	pump.visible = ledger.has_upgrade("pump")
	battery.visible = ledger.has_upgrade("battery")
	winch.visible = ledger.has_upgrade("winch")
	var pipe: String = "AUTO" if status.pump_on and pump.visible else "MANUAL"
	var capacity := 1.8 if ledger.has_upgrade("battery") else .46
	panel.text = "BAT %d%%  •  BILGE %.0f L\n%s     %s" % [
		roundi(100.0 * status.charge / capacity), 90.0 * status.bilge, pipe,
		"FOIL UP" if vessel.foil_lift > .6 else ("ELECTRIC" if vessel.skiff else "%.0f L FUEL" % status.fuel)]
	if status.tow:
		if not is_instance_valid(barge):
			barge = make_barge()
		animate_tow(barge, 8.28, 2.48, delta, clock)
		jib.rotation.y = .2 + active_lift * .64
	elif is_instance_valid(barge):
		barge.hide()
	if not job.is_empty() and job.kind == "rescue" and status.stage == "return":
		if not is_instance_valid(rescue_tow):
			rescue_tow = rescue_boat()
		animate_tow(rescue_tow, 11.7 if status.tow else 6.9, 1.37, delta, clock)
	elif is_instance_valid(rescue_tow):
		rescue_tow.hide()
	cable.hide()
	if task_kind.is_empty() or not is_instance_valid(object):
		return
	object.global_position = live_target + Vector3.UP * water_time
	object.rotation = Vector3(sin(clock * 1.39) * .09, 0, cos(clock * 2.04) * .08)
	if task_kind == "salvage":
		var lift: Node3D = object.get_node("Lift")
		var hoist_at := jib.to_global(Vector3(0, 1.52, 2.02)) if is_instance_valid(barge) and barge.visible else winch.to_global(Vector3(0, .25, 0))
		var below := live_target + Vector3.DOWN * (1.6 - active_lift * 2.15)
		lift.global_position = below.lerp(hoist_at - Vector3.UP * .56, smoothstep(.68, 1.0, active_lift))
		lift.visible = active_lift > 0.0
		if active_lift > 0:
			drum.rotation.x += delta * 9.4
			dock_lines(hoist_at, lift.global_position + Vector3.UP * .43, cable)
