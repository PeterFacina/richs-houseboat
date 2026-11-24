extends RefCounted

const Tackle = preload("res://boat_mooring.gd")
const Boat = preload("res://houseboat.gd")
const MAX_SPEED := .70
const LABELS := ["Bow", "Stern"]

var cleats: Array[Dictionary] = []
var landing_first: Array[int] = []


func setup(landings: Array[Dictionary], marina: Array[Transform3D], wharf: Array[Transform3D]) -> void:
	for index in landings.size():
		landing_first.append(cleats.size())
		for hardware: Transform3D in landings[index].cleats:
			add_cleat(hardware, index)
	for hardware: Transform3D in marina:
		add_cleat(hardware, -1)
	for hardware: Transform3D in wharf:
		add_cleat(hardware, -1)


func add_cleat(hardware: Transform3D, site: int) -> void:
	cleats.append({"at": hardware * Vector3(0, .16, 0), "site": site})


func tie(boat: Boat, slot: int, index: int) -> void:
	var endpoint: Vector3 = cleats[index].at
	var hull := Transform3D(Basis(Vector3.UP, boat.heading), boat.center)
	boat.mooring.tie(slot, index, endpoint, hull.affine_inverse() * endpoint, hull, boat.skiff)


func seed_landing(boat: Boat, site: int) -> void:
	var first := landing_first[site]
	tie(boat, 0, first)
	tie(boat, 1, first + (1 if boat.skiff else 2))


func seed_launch(boat: Boat) -> void:
	for slot in boat.mooring.lines.size():
		var nearest := -1
		var distance := Tackle.LINE_REACH
		for index in range(landing_first.size() * 3, cleats.size()):
			if index == int(boat.mooring.lines[0].get("cleat", -1)):
				continue
			var gap := line_gap(boat, slot, index)
			if gap < distance:
				nearest = index
				distance = gap
		if nearest >= 0:
			tie(boat, slot, nearest)


func site_for(boat: Boat) -> int:
	if not boat.mooring.attached(0) or not boat.mooring.attached(1):
		return -1
	var site: int = cleats[boat.mooring.lines[0].cleat].site
	return site if site == int(cleats[boat.mooring.lines[1].cleat].site) else -1


func line_gap(boat: Boat, slot: int, index: int) -> float:
	var endpoint: Vector3 = cleats[index].at
	var side := 1.0 if boat.to_local(endpoint).x >= 0.0 else -1.0
	return endpoint.distance_to(boat.to_global(Tackle.fairlead(slot, boat.skiff, side)))


func reachable(feet: Vector3, point: Vector3) -> bool:
	return (feet + Vector3.UP * .95).distance_squared_to(point) <= Tackle.HAND_REACH * Tackle.HAND_REACH


func focus(boat: Boat, peer: int, onboard: bool, feet: Vector3, eye: Camera3D) -> Array:
	var tackle := boat.mooring
	var held := tackle.held_by(peer)
	var selected := []
	var angle := .90
	if held >= 0:
		for index in cleats.size():
			var endpoint: Vector3 = cleats[index].at
			if not reachable(feet, endpoint) or line_gap(boat, held, index) > Tackle.LINE_REACH \
					or int(tackle.lines[1 - held].get("cleat", -1)) == index:
				continue
			var dot := (endpoint - eye.global_position).normalized().dot(-eye.global_basis.z)
			if dot > angle:
				angle = dot
				selected = ["tie", held, index, "E  Tie %s line to cleat" % LABELS[held].to_lower()]
		if not selected.is_empty():
			return selected
		var coil := boat.to_global(Tackle.station(held, boat.skiff))
		if onboard and reachable(feet, coil) and alignment(eye, coil) > angle:
			return ["stow", held, -1, "E  Put down %s line" % LABELS[held].to_lower()]
		return []
	var anchor_at := boat.to_global(Tackle.anchor_station(boat.skiff))
	var anchor_angle := alignment(eye, anchor_at)
	if onboard and reachable(feet, anchor_at) and anchor_angle > angle:
		angle = anchor_angle
		selected = ["raise" if tackle.anchor.is_finite() else "lower", -1, -1,
			"E  Raise anchor" if tackle.anchor.is_finite() else "E  Lower anchor"]
	for slot in tackle.lines.size():
		var line := tackle.lines[slot]
		var coil := boat.to_global(Tackle.station(slot, boat.skiff))
		var line_end: Vector3 = line.get("end", Vector3.INF)
		var dot := 0.0
		if onboard and reachable(feet, coil):
			dot = alignment(eye, coil)
		if onboard and tackle.attached(slot):
			var lead := boat.to_global(Tackle.fairlead(slot, boat.skiff, line.side))
			if reachable(feet, lead):
				dot = maxf(dot, alignment(eye, lead))
		if line_end.is_finite() and reachable(feet, line_end):
			dot = maxf(dot, alignment(eye, line_end))
		if dot <= angle or line.has("holder"):
			continue
		angle = dot
		selected = ["untie" if tackle.attached(slot) else "pickup", slot, -1,
			"E  Untie %s line" % LABELS[slot].to_lower() if tackle.attached(slot) else
			"E  Pick up %s line" % LABELS[slot].to_lower()]
	return selected


func alignment(eye: Camera3D, point: Vector3) -> float:
	return (point - eye.global_position).normalized().dot(-eye.global_basis.z)


func act(boat: Boat, river: Node3D, peer: int, person: Dictionary, value: Array) -> String:
	var action: String = value[0]
	var slot: int = value[1]
	var index: int = value[2]
	var feet: Vector3 = person.at
	var tackle := boat.mooring
	var held := tackle.held_by(peer)
	if action == "lower" or action == "raise":
		var lead := boat.to_global(Tackle.anchor_station(boat.skiff))
		if not person.onboard or not reachable(feet, lead) or held >= 0:
			return ""
		if action == "raise" and tackle.anchor.is_finite():
			tackle.anchor = Vector3.INF
			return "Anchor aboard."
		if action == "lower" and not tackle.anchor.is_finite():
			var depth: float = river.depth_at(lead)
			if tackle.secured() or absf(boat.speed) > MAX_SPEED or depth <= .45:
				return "Slow down in open water before lowering the anchor."
			var level := boat.center + Basis(Vector3.UP, boat.heading) * Tackle.anchor_station(boat.skiff)
			tackle.anchor = Vector3(level.x, -depth, level.z)
			boat.departed = true
			return "Anchor down."
		return ""
	if slot < 0 or slot >= tackle.lines.size():
		return ""
	var coil := boat.to_global(Tackle.station(slot, boat.skiff))
	var at_coil: bool = person.onboard and reachable(feet, coil)
	var line := tackle.lines[slot]
	match action:
		"pickup":
			if at_coil and line.is_empty() and held < 0:
				tackle.lines[slot] = {"holder": peer}
				return "Aim at a dock cleat and press E to tie the %s line." % LABELS[slot].to_lower()
		"stow":
			if at_coil and held == slot:
				tackle.lines[slot] = {}
				return "%s line stowed." % LABELS[slot]
		"tie":
			if held != slot or index < 0 or index >= cleats.size():
				return ""
			if not reachable(feet, cleats[index].at) or line_gap(boat, slot, index) > Tackle.LINE_REACH \
					or int(tackle.lines[1 - slot].get("cleat", -1)) == index:
				return "Use a free cleat within reach of the line."
			if absf(boat.speed) > MAX_SPEED or tackle.anchor.is_finite():
				return "Stop the boat and raise its anchor before tying up."
			tie(boat, slot, index)
			boat.departed = true
			return "%s line tied." % LABELS[slot]
		"untie":
			if held < 0 and tackle.attached(slot):
				var lead := boat.to_global(Tackle.fairlead(slot, boat.skiff, line.side))
				if at_coil or (person.onboard and reachable(feet, lead)) or reachable(feet, line.end):
					tackle.lines[slot] = {}
					return "%s line untied." % LABELS[slot]
	return ""
