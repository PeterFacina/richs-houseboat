extends Node3D

const Kit = preload("res://scenery.gd")
const Model = preload("res://rich_houseboat_model.gd")
const PartsData = preload("res://houseboat_restoration.gd")
const LOT := Vector2(18022.0, 12622.0)
const LOT_YAW := PI * .5
const ARRIVAL_OFFSETS := [
	Vector2(-7.5, -3.0), Vector2(-7.5, -1.0),
	Vector2(-7.5, 1.0), Vector2(-7.5, 3.0),
]
const PARTS := Vector2(18033.0, 12654.0)
const FUEL := Vector2(18032.0, 12646.0)
const PONTOON_PICKUP := Vector2(17986.0, 12706.0)

var river: Node3D
var rich_stand := AnimatableBody3D.new()
var hull := StaticBody3D.new()
var yard_gear := StaticBody3D.new()
var model := Model.new()
var ladder_foot: Vector3
var ladder_top: Vector3
var points: Dictionary = {}
var labels: Dictionary = {}
var delivery: Node3D
var pickup_rack: Node3D
var arrivals: Array[Vector3] = []


func setup(map: Node3D, rich_offset: Vector3, rich_rest_yaw: float) -> void:
	river = map
	name = "PierRoadBoatYard"
	var ground := land(LOT)
	var deck_height := ground.y + 1.37
	for x: float in [-1.25, 1.25]:
		for z: float in [-4.0, 4.0]:
			deck_height = maxf(deck_height, yard_ground(Vector2(x, z)).y + 1.37)
	add_child(hull)
	hull.transform = Transform3D(Basis(Vector3.UP, LOT_YAW),
		Vector3(ground.x, deck_height - Model.DECK_HEIGHT, ground.z) - Basis(Vector3.UP, LOT_YAW) * Vector3(0, 0, 1.525))
	hull.name = "OldHouseboatOnBlocks"
	model.build(hull, true)
	add_child(yard_gear)
	yard_gear.transform = hull.transform
	build_access()

	var rich_feet := yard_ground(Vector2(-3.1, 1.8))
	rich_stand.name = "RichYardStation"
	rich_stand.sync_to_physics = false
	add_child(rich_stand)
	rich_stand.rotation.y = LOT_YAW - PI * .5 - rich_rest_yaw
	rich_stand.position = rich_feet - rich_stand.basis * rich_offset
	for offset: Vector2 in ARRIVAL_OFFSETS:
		arrivals.append(yard_ground(offset) + Vector3.UP * .09)
	build_supplies()


func land(at: Vector2) -> Vector3:
	return Vector3(at.x, river.ground_height(at.x, at.y), at.y)


func yard_ground(offset: Vector2) -> Vector3:
	return land(LOT + offset.rotated(-LOT_YAW))


func piece(body: StaticBody3D, at: Vector3, dimensions: Vector3, finish: Material) -> void:
	Kit.box_at(body, at, dimensions, finish)
	Kit.collider(body, at, dimensions)


func build_access() -> void:
	var wood := Kit.paint(Color("#76583e"), .96)
	var endgrain := Kit.paint(Color("#9e7950"), .94)
	var steel := Kit.paint(Color("#a2a39a"), .73)
	for side: float in [-1.04, 1.04]:
		for z: float in [-1.2, 4.3]:
			var at := hull.to_global(Vector3(side, 0, z))
			var floor_y: float = river.ground_height(at.x, at.z) - hull.position.y
			var block_height := maxf(.14, -.25 - floor_y)
			var courses := maxi(1, ceili(block_height / .23))
			for row in courses:
				var height := block_height / courses
				var size := Vector3(.64, height - .006, .80) if row % 2 == 0 else Vector3(.84, height - .006, .58)
				piece(yard_gear, Vector3(side, floor_y + (row + .5) * height, z), size, wood if row % 2 == 0 else endgrain)
	var ladder_x := -1.68
	var step_x := -2.22
	var ladder_z := -1.61
	var feet := hull.to_global(Vector3(step_x, 0, ladder_z))
	var low: float = river.ground_height(feet.x, feet.z) - hull.position.y
	for z: float in [ladder_z - .26, ladder_z + .26]:
		Kit.beam(yard_gear, Vector3(ladder_x - .20, low, z), Vector3(ladder_x, 1.12, z), .073, steel)
	for row in maxi(1, ceili((.75 - low) / .22)):
		var y := low + .14 + row * .22
		Kit.box_at(yard_gear, Vector3(ladder_x - .20 * (1.0 - (y - low) / (1.12 - low)), y, ladder_z),
			Vector3(.14, .05, .56), steel)
	ladder_foot = hull.to_global(Vector3(step_x, low + .06, ladder_z))
	ladder_top = hull.to_global(Vector3(-1.03, .81, ladder_z))
	# A short stern catwalk makes the outboard reachable from the ground.
	var engine_step := hull.to_global(Vector3(0, 0, 7.12))
	var base: float = river.ground_height(engine_step.x, engine_step.z) - hull.position.y
	for level in 3:
		var y := lerpf(base, .32, (level + 1) / 3.0)
		var z := 7.68 - level * .34
		piece(yard_gear, Vector3(0, (base + y) * .5, z),
			Vector3(1.42, maxf(.08, y - base), .38), endgrain)
	for part: String in PartsData.COMPONENTS:
		add_point(part, "", hull.to_global(PartsData.COMPONENTS[part].at))
	points.descend = ladder_foot


func add_point(id: String, title: String, at: Vector3) -> void:
	points[id] = at
	var caption := title if not title.is_empty() else str(PartsData.COMPONENTS[id].name)
	labels[id] = marker(caption, at + Vector3.UP * .37)
	labels[id].hide()


func build_supplies() -> void:
	var wood := Kit.paint(Color("#90724f"))
	var steel := Kit.paint(Color("#333d3e"))
	var red := Kit.paint(Color("#a34b3b"))
	var gold := Kit.paint(Color("#d0b474"))
	var green := Kit.paint(Color("#636d4b"))
	var bench := StaticBody3D.new()
	add_child(bench)
	bench.position = yard_ground(Vector2(-3.56, -.38))
	piece(bench, Vector3.UP * .82, Vector3(1.28, .09, .62), wood)
	for x: float in [-.54, .54]:
		for z: float in [-.23, .23]:
			piece(bench, Vector3(x, .39, z), Vector3(.085, .78, .085), steel)
	Kit.box_at(bench, Vector3(.31, .986, -.13), Vector3(.50, .23, .29), red)
	Kit.box_at(bench, Vector3(.31, 1.114, -.13), Vector3(.18, .042, .058), steel)
	Kit.box_at(bench, Vector3(-.30, .98, .10), Vector3(.31, .22, .33), steel)
	Kit.box_at(bench, Vector3(-.31, 1.008, .271), Vector3(.19, .12, .018), gold)
	add_point("bench", "Rich’s workbench", bench.position + Vector3.UP * .96)
	var chair := Node3D.new()
	add_child(chair)
	chair.position = yard_ground(Vector2(-3.83, 2.84))
	chair.rotation.y = LOT_YAW - .2
	Kit.box_at(chair, Vector3(0, .43, 0), Vector3(.48, .06, .44), green)
	Kit.box_at(chair, Vector3(0, .68, .20), Vector3(.46, .47, .045), green).rotation.x = .14
	for x: float in [-.24, .24]:
		Kit.beam(chair, Vector3(x, .04, -.23), Vector3(x, .54, .23), .038, steel)
		Kit.beam(chair, Vector3(x, .04, .25), Vector3(x, .46, -.23), .038, steel)
	var crate := StaticBody3D.new()
	add_child(crate)
	crate.position = land(PARTS)
	piece(crate, Vector3.UP * .39, Vector3(.96, .78, .72), wood)
	Kit.box_at(crate, Vector3(0, .44, .368), Vector3(.64, .19, .025), gold)
	add_point("supplies", "Marina parts pickup", crate.position + Vector3.UP * .55)
	var cans := StaticBody3D.new()
	add_child(cans)
	cans.position = land(FUEL)
	for side: float in [-.27, .27]:
		piece(cans, Vector3(side, .25, 0), Vector3(.44, .5, .27), red)
		Kit.box_at(cans, Vector3(side, .53, 0), Vector3(.16, .08, .08), steel)
	add_point("fuel_pickup", "Marina fuel reserve", cans.position + Vector3.UP * .40)
	pickup_rack = pontoon_rack(land(PONTOON_PICKUP), wood)
	add_point("pontoon_pickup", "Second-hand pontoons", pickup_rack.position + Vector3.UP * .70)
	labels.pontoon_pickup.visibility_range_end = 115.0
	var delivery_position := yard_ground(Vector2(-2.9, -4.3))
	delivery = pontoon_rack(delivery_position, wood)
	add_point("unload", "Pontoon drop-off", delivery_position + Vector3.UP * .69)


func pontoon_rack(at: Vector3, timber: Material) -> Node3D:
	var rack := Node3D.new()
	add_child(rack)
	rack.position = at
	var alloy := Kit.paint(Color("#98a09c"), .62, .26)
	for z: float in [-.82, .82]:
		Kit.box_at(rack, Vector3(0, .11, z), Vector3(1.62, .22, .19), timber)
	for side: float in [-.41, .41]:
		model.cylinder(rack, Vector3(side, .47, 0), .26, 2.55, 10, alloy).rotation.x = PI * .5
	return rack


func contains_player(feet: Vector3) -> bool:
	var at := hull.to_local(feet)
	return absf(at.x) < 1.90 and at.z > Model.BOW - .32 and at.z < Model.STERN + .38 and at.y >= .56 and at.y < 3.85


func apply_state(saved: Dictionary, active: Array[String]) -> void:
	var launched: bool = saved.get("launched", false)
	hull.visible = not launched
	hull.collision_layer = 0 if launched else 1
	yard_gear.visible = not launched
	yard_gear.collision_layer = 0 if launched else 1
	model.apply_state(saved)
	pickup_rack.visible = not saved.get("flags", {}).get("pontoon_pickup", false)
	delivery.visible = saved.get("flags", {}).get("unload", false) and not PartsData.repaired(saved, "pontoons")
	for id: String in labels:
		labels[id].visible = id in active


func marker(title: String, at: Vector3) -> Label3D:
	var label := Label3D.new()
	label.text = title
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.font_size = 44
	label.outline_size = 10
	label.pixel_size = .003
	label.modulate = Color("#f4d068")
	label.visibility_range_end = 45.0
	add_child(label)
	label.position = at
	return label
