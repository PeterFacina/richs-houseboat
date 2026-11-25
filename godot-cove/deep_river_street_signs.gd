extends RefCounted

const BLADE_FONT = preload("res://deep_river/BarlowCondensed-SemiBold.ttf")

const Kit = preload("res://scenery.gd")
const RANGE := 135.0
const SIGN_SPAN := 1.05


func build(parent: Node3D, map: Node3D, junctions: Array) -> void:
	var network := Node3D.new()
	network.name = "StreetNameSigns"
	parent.add_child(network)
	var steel := Kit.paint(Color("#929b9a"), .66, .32)
	var green := Kit.paint(Color("#246047"), .73)
	var trim := Kit.paint(Color("#dce7d7"), .73)
	for junction: Array in junctions:
		var center := Vector2(junction[0][0], junction[0][1])
		var blades: Array = junction[1]
		var at := find_corner(map, center, blades)
		if not at.is_finite():
			continue
		var signpost := Node3D.new()
		network.add_child(signpost)
		signpost.global_position = at
		signpost.set_meta(&"junction", center)
		signpost.set_meta(&"sign_span", SIGN_SPAN)
		signpost.add_to_group(&"town_roadside_signs")
		signpost.add_to_group(&"deep_river_street_names")
		var spacing := .50 if blades.size() > 2 else .32
		var height := 2.39 + (blades.size() - 1) * spacing + .105
		var pole := CylinderMesh.new()
		pole.top_radius = .035
		pole.bottom_radius = .035
		pole.height = height
		pole.radial_segments = 10
		set_range(Kit.mesh_at(signpost, pole, Vector3.UP * (height * .5), steel))
		for i in blades.size():
			var blade: Array = blades[i]
			add_blade(signpost, blade[0], blade[1], 2.39 + i * spacing, trim, green)


func find_corner(map: Node3D, center: Vector2, blades: Array) -> Vector3:
	var first := Vector2.from_angle(blades[0][1])
	var second := Vector2.from_angle(blades[1][1])
	var along := (first + second).normalized()
	var across := (first - second).normalized()
	var clearance := SIGN_SPAN + 1.35
	for blade: Array in blades:
		if blade[0] == "Champlain St":
			clearance = SIGN_SPAN + 2.55
	var footprints: Array[Rect2] = []
	for building: Dictionary in map.meta.buildings:
		var box: Array = building.box
		var footprint := Rect2(box[0], box[1], box[2] - box[0], box[3] - box[1]).grow(.85)
		if footprint.grow(22.0).has_point(center):
			footprints.append(footprint)
	for distance: float in [8.4, 10.5, 12.5, 15.0, 18.0, 20.0]:
		for direction: Vector2 in [along, -along, across, -across]:
			var point := center + direction * distance
			if footprints.any(func(bounds: Rect2) -> bool: return bounds.has_point(point)):
				continue
			if not map.roadside_safe(point) or not map.road_at_sign(point, clearance).is_empty():
				continue
			var height: float = map.ground_height(point.x, point.y)
			return Vector3(point.x, height, point.y)
	return Vector3.INF


func add_blade(parent: Node3D, label: String, heading: float, height: float,
		trim: Material, green: Material) -> void:
	var blade := Node3D.new()
	parent.add_child(blade)
	blade.position.y = height
	blade.rotation.y = -heading
	var wording := label.to_upper()
	var letter_size := .00445
	var width := clampf(BLADE_FONT.get_string_size(wording, HORIZONTAL_ALIGNMENT_LEFT, -1, 38).x * letter_size + .18, .72, 1.96)
	set_range(Kit.box_at(blade, Vector3.ZERO, Vector3(width, .225, .078), trim))
	set_range(Kit.box_at(blade, Vector3.ZERO, Vector3(width - .026, .199, .086), green))
	for side: float in [-1.0, 1.0]:
		var text := Label3D.new()
		blade.add_child(text)
		text.text = wording
		text.font = BLADE_FONT
		text.font_size = 38
		text.pixel_size = letter_size
		text.outline_size = 0
		text.double_sided = false
		text.modulate = Color("#f3f6eb")
		text.position.z = side * .045
		text.rotation.y = PI if side < 0.0 else 0.0
		set_range(text)


func set_range(item: GeometryInstance3D) -> void:
	item.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	item.visibility_range_end = RANGE
	item.visibility_range_end_margin = 12.0
