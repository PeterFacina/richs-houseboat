extends Node3D

const Kit = preload("res://scenery.gd")
const Parts = preload("res://houseboat_restoration.gd")
const DECK_HEIGHT := .75
const BEAM := 3.02
const BOW := -3.72
const STERN := 9.45

var variants: Dictionary = {}
var cabin_lamp: OmniLight3D
var panels: Node3D
var deck_canopy: Node3D
var body: PhysicsBody3D
var dry := false
var rail_colliders: Dictionary = {}
var gate_pivots: Dictionary = {}
var gate_colliders: Dictionary = {}
var gate_tweens: Dictionary = {}
var gate_repaired: Dictionary = {}
var gate_open: Dictionary = {}


func build(hull: PhysicsBody3D, on_blocks: bool) -> void:
	body = hull
	dry = on_blocks
	name = "RichsHouseboatModel"
	body.add_child(self)
	var cream := Kit.paint(Color("#c8bc9e"))
	var stripe := Kit.paint(Color("#754338"))
	var green := Kit.paint(Color("#3d5551"))
	var dark := Kit.paint(Color("#2a383a"))
	var aluminum := Kit.paint(Color("#87908b"), .65, .28)
	var glass := Kit.paint(Color(.38, .59, .64, .28), .32)
	glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.cull_mode = BaseMaterial3D.CULL_DISABLED
	var timber := [Kit.paint(Color("#90795a")), Kit.paint(Color("#9c8565")), Kit.paint(Color("#a08a6c"))]
	var length := STERN - BOW
	var centre := (STERN + BOW) *.5
	Kit.box_at(self, Vector3(0, .60, centre), Vector3(BEAM, .23, length), green)
	Kit.box_at(self, Vector3(0, .66, centre), Vector3(BEAM + .02, .09, length + .02), stripe)
	Kit.collider(body, Vector3(0, .657, centre), Vector3(BEAM, .186, length))
	for row in 42:
		var span := length / 42.0
		Kit.box_at(self, Vector3(0, .733, BOW + span * (row + .5)),
			Vector3(BEAM - .055, .032, span - .006), timber[row % timber.size()])

	build_pontoons()
	for side: float in [-1.0, 1.0]:
		var x := side * 1.33
		wall(Vector3(x, 1.03, 2.53), Vector3(.095, .56, 7.76), cream)
		wall(Vector3(x, 2.64, 2.53), Vector3(.095, .18, 7.76), cream)
		Kit.box_at(self, Vector3(x + side * .053, 1.12, 2.53), Vector3(.015, .12, 7.76), stripe)
		for index in 7:
			var z := -1.35 + index * (7.76 / 6.0)
			Kit.box_at(self, Vector3(x, 1.97, z), Vector3(.12, 1.22, .10), cream)
			if index < 6:
				Kit.box_at(self, Vector3(x, 1.97, z + 7.76 / 12.0), Vector3(.025, 1.22, 1.21), glass)
			if index in [0, 3, 6]:
				var seam := Kit.box_at(self, Vector3(x + side * .065, .85, z + .15), Vector3(.02, .16, .24), green)
				seam.rotation.x = .045 * side
		Kit.collider(body, Vector3(x, 1.95, 2.53), Vector3(.095, 1.30, 7.76))
		for z: float in [-.9, 3.26]:
			cylinder(self, Vector3(side * 1.56, .55, z), .095, .49, 10, dark)
	for z: float in [-1.35, 6.41]:
		for side: float in [-1.0, 1.0]:
			wall(Vector3(side * .906, 1.02, z), Vector3(.81, .54, .10), cream)
			wall(Vector3(side * .906, 1.95, z), Vector3(.81, 1.32, .019), glass)
			for x: float in [.49, 1.30]:
				Kit.box_at(self, Vector3(side * x, 1.95, z), Vector3(.065, 1.36, .13), cream)
		wall(Vector3(0, 2.665, z), Vector3(2.66, .13, .10), cream)
		Kit.box_at(self, Vector3(.54, 1.06, z + .066), Vector3(.18, .52, .035), green)
	wall(Vector3(0, 2.79, 2.53), Vector3(2.97, .12, 8.1), green)
	for index in 9:
		Kit.box_at(self, Vector3(-1.31 + index * .329, 2.86, 2.53), Vector3(.023, .021, 7.92), dark)
	Kit.box_at(self, Vector3(-.78, 2.94, 3.63), Vector3(.44, .14, .43), aluminum)
	Kit.box_at(self, Vector3(.82, 2.98, 5.12), Vector3(.21, .20, .26), green)
	Kit.beam(self, Vector3(.82, 2.93, 5.12), Vector3(.86, 3.59, 5.12), .029, dark)
	build_aft_deck(timber[1], dark, aluminum)
	for side: float in [-1.0, 1.0]:
		build_rail("port_rail" if side < 0 else "starboard_rail", side, aluminum)
		for z: float in [-3.54, 6.58]:
			Kit.box_at(self, Vector3(side * 1.22, .79, z), Vector3(.21, .072, .085), dark)
	build_gate("bow_gate", BOW + .13, aluminum, dark)
	build_gate("stern_gate", STERN - .15, aluminum, dark)
	var tag := Label3D.new()
	tag.text = "RICH’S"
	tag.font_size = 40
	tag.pixel_size = .003
	tag.modulate = Color("#eee2c2")
	tag.position = Vector3(0, 1.02, BOW - .024)
	tag.rotation.y = PI
	add_child(tag)
	build_electrical(cream, dark)
	build_fuel()
	build_furnishings(timber[1], cream, green)
	build_upgrades(dark, aluminum)
	if dry:
		Kit.box_at(self, Vector3(0, 1.12, -2.47), Vector3(.52, .72, .38), green)
		Kit.box_at(self, Vector3(0, 1.54, -2.47), Vector3(.61, .13, .45), dark)
		var wheel := TorusMesh.new()
		wheel.inner_radius = .205
		wheel.outer_radius = .247
		wheel.rings = 12
		wheel.ring_segments = 8
		Kit.mesh_at(self, wheel, Vector3(0, 1.69, -2.25), dark).rotation.x = PI / 2.0
		var engine := preload("res://outboard.gd").new()
		engine.position = Vector3(0, .55, 6.73)
		add_child(engine)
		var cover := variant("engine", false)
		Kit.box_at(cover, Vector3(.18, 1.39, 6.78), Vector3(.34, .33, .39), stripe).rotation.z = -.28
		var fitted := variant("engine", true)
		Kit.box_at(fitted, Vector3(.0, 1.34, 6.56), Vector3(.24, .048, .045), aluminum)


func wall(at: Vector3, size: Vector3, material: Material) -> void:
	Kit.box_at(self, at, size, material)
	Kit.collider(body, at, size)


func cylinder(parent: Node3D, at: Vector3, radius: float, length: float, segments: int, material: Material) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = radius
	mesh.bottom_radius = radius
	mesh.height = length
	mesh.radial_segments = segments
	mesh.rings = 0
	return Kit.mesh_at(parent, mesh, at, material)


func variant(component: String, fixed: bool) -> Node3D:
	var root := Node3D.new()
	root.name = component.capitalize().replace(" ", "") + ("Installed" if fixed else "Damaged")
	add_child(root)
	var pair: Array = variants.get(component, [null, null])
	pair[int(fixed)] = root
	variants[component] = pair
	return root


func build_pontoons() -> void:
	for fixed: bool in [false, true]:
		var root := variant("pontoons", fixed)
		var paint := Kit.paint(Color("#929b98") if fixed else Color("#796850"), .71, .23)
		var seams := Kit.paint(Color("#58635e") if fixed else Color("#59483b"), .72)
		for side: float in [-1.0, 1.0]:
			var x := side * 1.01
			var offset := .0 if fixed else side * .11
			cylinder(root, Vector3(x + offset, .062, 2.66), .441, 11.4, 10, paint).rotation.x = PI * .5
			var taper := CylinderMesh.new()
			taper.top_radius = .19
			taper.bottom_radius = .44
			taper.height = .63
			taper.radial_segments = 10
			taper.rings = 0
			Kit.mesh_at(root, taper, Vector3(x + offset, .062, -3.35), paint).rotation.x = -PI * .5
			Kit.mesh_at(root, taper, Vector3(x + offset, .062, 8.68), paint).rotation.x = PI * .5
			for z: float in [-2.65, .7, 4.5, 6.09, 7.14, 8.28]:
				cylinder(root, Vector3(x + offset, .062, z), .449, .039, 10, seams).rotation.x = PI * .5
			if not fixed:
				Kit.box_at(root, Vector3(x + offset + side * .359, .12, -1.90),
					Vector3(.088, .27, .92), seams).rotation.z = side * .27
		if fixed:
			for x: float in [-1.01, 1.01]:
				Kit.collider(body, Vector3(x, .06, 2.66), Vector3(.67, .70, 11.7))


func build_rail(id: String, side: float, alloy: Material) -> void:
	var x := side * 1.44
	for fixed: bool in [false, true]:
		var root := variant(id, fixed)
		for z: float in [-3.59, -1.77, 6.18, 6.65, 9.30]:
			var post := Kit.box_at(root, Vector3(x, 1.16, z), Vector3(.054, .82, .054), alloy)
			if not fixed and z < 0.0:
				post.rotation.z = -side * .29
		for span: Vector2 in [Vector2(-3.59, -1.77), Vector2(6.18, 9.30)]:
			Kit.beam(root, Vector3(x, 1.55, span.x),
				Vector3(x + (0.0 if fixed else .24 * side), 1.55 if fixed else 1.19, span.y), .055, alloy)
			if fixed:
				Kit.beam(root, Vector3(x, 1.13, span.x), Vector3(x, 1.13, span.y), .035, alloy)
	Kit.beam(self, Vector3(x, 1.55, -3.59), Vector3(side * .62, 1.55, -3.59), .05, alloy)
	for span: Vector2 in [Vector2(-3.57, -1.8), Vector2(6.16, 9.32)]:
		var barrier := CollisionShape3D.new()
		var shape := BoxShape3D.new()
		shape.size = Vector3(.07, .82, span.y - span.x)
		barrier.shape = shape
		barrier.position = Vector3(x, 1.16, (span.x + span.y) * .5)
		body.add_child(barrier)
		var shapes: Array = rail_colliders.get(id, [])
		shapes.append(barrier)
		rail_colliders[id] = shapes


func build_aft_deck(wood: Material, dark: Material, alloy: Material) -> void:
	# Cross-members visibly carry the extended platform between the pontoon ends.
	Kit.box_at(self, Vector3(0, .69, 8.04), Vector3(BEAM, .12, 2.72), wood)
	Kit.collider(body, Vector3(0, .69, 8.04), Vector3(BEAM, .16, 2.72))
	for z: float in [6.82, 7.60, 8.38, 9.16]:
		Kit.beam(self, Vector3(-1.39, .48, z), Vector3(1.39, .48, z), .11, dark)
	for side: float in [-1.0, 1.0]:
		Kit.beam(self, Vector3(side * 1.23, .48, 6.75), Vector3(side * 1.23, .48, 9.28), .11, dark)
		var spot := SpotLight3D.new()
		spot.name = "AftDeckSpotlightPort" if side < 0.0 else "AftDeckSpotlightStarboard"
		spot.position = Vector3(side * .83, 2.86, 5.91)
		spot.rotation.x = -PI * .5
		spot.light_color = Color("#f7dfb4")
		spot.light_energy = .72
		spot.spot_range = 5.2
		spot.spot_angle = 46.0
		spot.shadow_enabled = false
		add_child(spot)
	# The physical tank is built at the port mount; keep the grill at starboard.
	var bbq := Node3D.new()
	bbq.name = "AftBarbecue"
	add_child(bbq)
	var black := Kit.paint(Color("#303436"), .58, .30)
	var enamel := Kit.paint(Color("#643d32"), .48, .24)
	for x: float in [.52, 1.15]:
		Kit.beam(bbq, Vector3(x, .75, 8.28), Vector3(x, 1.12, 8.28), .045, dark)
	Kit.box_at(bbq, Vector3(.84, 1.13, 8.28), Vector3(.88, .17, .70), black)
	Kit.collider(body, Vector3(.84, 1.06, 8.28), Vector3(.88, .62, .70))
	Kit.box_at(bbq, Vector3(.84, 1.30, 8.28), Vector3(.82, .17, .64), enamel)
	Kit.box_at(bbq, Vector3(.84, 1.40, 8.28), Vector3(.75, .018, .56), dark)
	for z: float in [8.08, 8.25, 8.42, 8.59]:
		Kit.beam(bbq, Vector3(.48, 1.42, z), Vector3(1.20, 1.42, z), .014, alloy)
	var handle := Kit.beam(bbq, Vector3(.48, 1.51, 7.96), Vector3(1.20, 1.51, 7.96), .025, alloy)
	handle.name = "BarbecueHandle"
	for x: float in [.52, 1.16]:
		var wheel := TorusMesh.new()
		wheel.inner_radius = .045
		wheel.outer_radius = .059
		wheel.rings = 8
		wheel.ring_segments = 8
		Kit.mesh_at(bbq, wheel, Vector3(x, .86, 8.28), black).rotation.x = PI / 2.0


func build_gate(id: String, z: float, alloy: Material, dark: Material) -> void:
	var damaged := variant(id, false)
	var fixed := variant(id, true)
	for root: Node3D in [damaged, fixed]:
		var hinge := Node3D.new()
		hinge.name = id.capitalize() + "Hinge"
		hinge.position = Vector3(-.62, 1.02, z)
		root.add_child(hinge)
		for y: float in [.10, .68]:
			Kit.box_at(hinge, Vector3(0, y, 0), Vector3(.07, .11, .12), alloy)
		for y: float in [.18, .79]:
			Kit.beam(hinge, Vector3(.035, y, .015), Vector3(1.21, y, .015), .043, alloy)
		for x: float in [.10, .42, .74, 1.06, 1.19]:
			Kit.beam(hinge, Vector3(x, .18, 0), Vector3(x, .79, 0), .035, alloy)
		Kit.box_at(hinge, Vector3(1.14, .48, -.05), Vector3(.14, .21, .13), dark)
		if not root == fixed:
			hinge.rotation.z = -.42
		gate_pivots[id] = hinge
		if root == fixed:
			var collision := CollisionShape3D.new()
			var shape := BoxShape3D.new()
			shape.size = Vector3(1.22, .82, .09)
			collision.shape = shape
			collision.position = Vector3(0, 1.43, z)
			collision.disabled = true
			body.add_child(collision)
			gate_colliders[id] = [collision]
	gate_pivots[id] = [damaged.get_child(0), fixed.get_child(0)]
	gate_repaired[id] = false
	gate_open[id] = false


func set_gate_open(id: String, open: bool, animate := true) -> void:
	if not gate_pivots.has(id):
		return
	var pair: Array = gate_pivots[id]
	var fixed: bool = gate_repaired.get(id, false)
	var hinge: Node3D = pair[1] if fixed else pair[0]
	var changed: bool = bool(gate_open.get(id, false)) != open
	gate_open[id] = open
	var target := (PI * .5) if open else 0.0
	if changed and gate_tweens.has(id):
		(gate_tweens[id] as Tween).kill()
	if changed and animate and is_inside_tree():
		var tween := create_tween()
		tween.tween_property(hinge, "rotation:y", target, .32).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
		gate_tweens[id] = tween
	elif changed:
		hinge.rotation.y = target
	for collision: CollisionShape3D in gate_colliders[id]:
		collision.set_deferred("disabled", open or not fixed)


func sync_gates(states: Dictionary) -> void:
	for id: String in gate_pivots:
		set_gate_open(id, states.get(id, false) == true, false)


func gate_focus(camera: Camera3D) -> String:
	for id: String in ["bow_gate", "stern_gate"]:
		if not gate_repaired.get(id, false):
			continue
		var point := to_global(Vector3(0, 1.52, BOW + .13 if id == "bow_gate" else STERN - .15))
		var ray := point - camera.global_position
		if ray.length_squared() <= 3.2 * 3.2 and ray.normalized().dot(-camera.global_basis.z) > .91:
			return id
	return ""


func build_electrical(cream: Material, dark: Material) -> void:
	var copper := Kit.paint(Color("#a05d46"))
	for fixed: bool in [false, true]:
		var wiring := variant("wiring", fixed)
		var battery := variant("battery", fixed)
		var lamps := variant("cabin_lights", fixed)
		var nav := variant("nav_lights", fixed)
		Kit.box_at(wiring, Parts.COMPONENTS.wiring.at, Vector3(.13, .36, .32), dark)
		if fixed:
			Kit.box_at(wiring, Parts.COMPONENTS.wiring.at + Vector3(-.074, 0, 0), Vector3(.032, .32, .27), cream)
		else:
			Kit.beam(wiring, Vector3(1.07, 1.56, .18), Vector3(.91, 1.26, .33), .025, copper)
			Kit.beam(wiring, Vector3(1.07, 1.49, .29), Vector3(1.08, 1.23, .43), .026, dark)
		var battery_pos: Vector3 = Parts.COMPONENTS.battery.at
		Kit.box_at(battery, battery_pos - Vector3.UP * .105, Vector3(.27, .23, .36), dark if fixed else copper)
		for z: float in [-.11, .11]:
			cylinder(battery, battery_pos + Vector3(0, .024, z), .025, .040, 8, cream)
		Kit.box_at(lamps, Vector3(.40, 2.708, 1.94), Vector3(.32, .04, .13), cream if fixed else dark)
		if fixed:
			cabin_lamp = OmniLight3D.new()
			cabin_lamp.position = Vector3(.39, 2.58, 1.94)
			cabin_lamp.light_color = Color("#ffdc9d")
			cabin_lamp.light_energy = .75
			cabin_lamp.omni_range = 3.45
			lamps.add_child(cabin_lamp)
		for side: float in [-1.0, 1.0]:
			var color := Color("#7ee78f") if side > 0 else Color("#fa554d")
			var lens := Kit.paint(color if fixed else Color("#3e4140"), .39)
			if fixed:
				lens.emission_enabled = true
				lens.emission = color
				lens.emission_energy_multiplier = .70
			Kit.box_at(nav, Vector3(side * 1.44, 1.56, -1.83), Vector3(.13, .14, .14), lens)


func build_fuel() -> void:
	for fixed: bool in [false, true]:
		var root := variant("fuel_system", fixed)
		var at: Vector3 = Parts.COMPONENTS.fuel_system.at
		if dry:
			Kit.box_at(root, at - Vector3.UP * .17, Vector3(.49, .32, .33),
				Kit.paint(Color("#953a2f") if fixed else Color("#69524d")))
		var hose := Kit.paint(Color("#242b2d"))
		Kit.beam(root, at, at + Vector3(-.15, -.18, -.24 if fixed else .19), .037, hose)


func build_furnishings(wood: Material, cream: Material, green: Material) -> void:
	var canvas := Kit.paint(Color("#6b6d48"))
	wall(Vector3(.97, 1.02, 1.13), Vector3(.58, .54, 1.64), wood)
	Kit.box_at(self, Vector3(.97, 1.31, 1.13), Vector3(.59, .10, 1.58), canvas)
	Kit.box_at(self, Vector3(1.23, 1.55, 1.13), Vector3(.13, .43, 1.60), canvas)
	Kit.box_at(self, Vector3(.88, 1.384, .54), Vector3(.27, .08, .31), cream).rotation.y = .17
	wall(Vector3(.87, 1.03, 2.61), Vector3(.65, .56, .63), wood)
	Kit.box_at(self, Vector3(.87, 1.34, 2.61), Vector3(.73, .083, .68), green)
	cylinder(self, Vector3(.69, 1.425, 2.48), .034, .092, 8, Kit.paint(Color("#9c442e"))).rotation.z = .14
	cylinder(self, Vector3(.86, 1.402, 2.72), .032, .076, 8, Kit.paint(Color("#a1aaa1"))).rotation.x = 1.2
	Kit.box_at(self, Vector3(1.05, .888, 3.43), Vector3(.36, .27, .51), Kit.paint(Color("#92634a")))
	Kit.box_at(self, Vector3(1.05, .979, 3.69), Vector3(.25, .079, .014), cream)
	if dry:
		wall(Vector3(-.66, 1.105, .70), Vector3(.52, .71, .98), wood)
		wall(Vector3(-.63, 1.14, 1.78), Vector3(.52, .77, .64), cream)
		wall(Vector3(-.84, 1.03, 5.12), Vector3(.74, .56, 1.97), canvas)


func build_upgrades(dark: Material, aluminum: Material) -> void:
	panels = Node3D.new()
	panels.name = "SolarUpgrade"
	add_child(panels)
	var blue := Kit.paint(Color("#354c63"), .38)
	Kit.box_at(panels, Vector3(0, 2.99, 3.59), Vector3(1.62, .10, 1.66), aluminum)
	for row in 4:
		for column in 5:
			Kit.box_at(panels, Vector3(-.62 + column * .31, 3.045, 2.98 + row * .40),
				Vector3(.28, .012, .36), blue)
	deck_canopy = Node3D.new()
	deck_canopy.name = "OutboardUpgradeTrim"
	add_child(deck_canopy)
	Kit.box_at(deck_canopy, Vector3(0, 1.11, 6.76), Vector3(.46, .10, .2), dark)


func apply_state(state: Dictionary) -> void:
	for part: String in variants:
		var fixed := Parts.repaired(state, part)
		var pair: Array = variants[part]
		pair[0].visible = not fixed
		pair[1].visible = fixed
	for id: String in rail_colliders:
		for shape: CollisionShape3D in rail_colliders[id]:
			shape.set_deferred("disabled", not Parts.repaired(state, id))
	for id: String in gate_pivots:
		gate_repaired[id] = Parts.repaired(state, id)
		var pair: Array = gate_pivots[id]
		(pair[0] as Node3D).visible = not gate_repaired[id]
		(pair[1] as Node3D).visible = gate_repaired[id]
		set_gate_open(id, gate_open.get(id, false), false)
	cabin_lamp.visible = Parts.repaired(state, "battery") and Parts.repaired(state, "wiring")
	variants.nav_lights[1].visible = Parts.repaired(state, "nav_lights") and cabin_lamp.visible
	panels.visible = Parts.upgrade_installed(state, "solar")
	deck_canopy.visible = Parts.upgrade_installed(state, "outboard")
