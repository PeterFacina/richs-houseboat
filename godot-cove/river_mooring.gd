extends RefCounted

const Tackle = preload("res://boat_mooring.gd")
const Boat = preload("res://houseboat.gd")
const MAX_SPEED := .70
const COIL_REACH := 1.60
const COIL_RADIUS := .20
const FAIRLEAD_RADIUS := .15
const CLEAT_RADIUS := .19

var cleats: Array[Dictionary] = []
var landing_first: Array[int] = []
var launch_cleats := PackedInt32Array()


func setup(landings: Array[Dictionary], marina: Array[Transform3D], wharf: Array[Transform3D],
		launch_indices: PackedInt32Array) -> void:
	for index in landings.size():
		landing_first.append(cleats.size())
		for hardware: Transform3D in landings[index].cleats:
			add_cleat(hardware, index)
	for index in launch_indices:
		launch_cleats.append(cleats.size() + index)
	for hardware: Transform3D in marina:
		add_cleat(hardware, -1)
	for hardware: Transform3D in wharf:
		add_cleat(hardware, -1)


func add_cleat(hardware: Transform3D, site: int) -> void:
	cleats.append({"at": hardware * Vector3(0, .16, 0), "site": site})


func tie(boat: Boat, slot: int, index: int) -> void:
	var endpoint: Vector3 = cleats[index].at
	var hull := Transform3D(Basis(Vector3.UP, boat.heading), boat.center)
	boat.mooring.tie(slot, index, endpoint, hull, fairlead(boat, slot, endpoint))


func seed_landing(boat: Boat, site: int) -> void:
	var first := landing_first[site]
	seed_pair(boat, PackedInt32Array([first, first + 1, first + 2]))


func seed_launch(boat: Boat) -> void:
	seed_pair(boat, launch_cleats)


func seed_pair(boat: Boat, choices: PackedInt32Array) -> void:
	for bow in [true, false]:
		var best_slot := -1
		var best_cleat := -1
		var distance := Tackle.LINE_REACH
		for slot in boat.mooring.lines.size():
			if (boat.mooring.leads[slot].z < 0.0) != bow:
				continue
			for index in choices:
				if boat.mooring.uses_cleat(index):
					continue
				var gap := line_gap(boat, slot, index)
				if gap < distance:
					best_slot = slot
					best_cleat = index
					distance = gap
		if best_slot >= 0:
			tie(boat, best_slot, best_cleat)


func at_launch(boat: Boat) -> bool:
	return has_pair(boat, launch_cleats)


func site_for(boat: Boat) -> int:
	for site in landing_first.size():
		var first := landing_first[site]
		if has_pair(boat, PackedInt32Array([first, first + 1, first + 2])):
			return site
	return -1


func has_pair(boat: Boat, choices: PackedInt32Array) -> bool:
	var bow := false
	var stern := false
	for slot in boat.mooring.lines.size():
		if not choices.has(int(boat.mooring.lines[slot].get("cleat", -1))):
			continue
		if boat.mooring.leads[slot].z < 0.0:
			bow = true
		else:
			stern = true
	return bow and stern


func fairlead(boat: Boat, slot: int, endpoint: Vector3) -> Vector3:
	var lead := boat.mooring.leads[slot]
	# The electric skiff retains its existing reversible lead positions.
	if boat.uses_battery():
		lead.x = absf(lead.x) * (-1.0 if boat.to_local(endpoint).x < 0.0 else 1.0)
	return lead


func line_gap(boat: Boat, slot: int, index: int) -> float:
	var endpoint: Vector3 = cleats[index].at
	var lead := fairlead(boat, slot, endpoint)
	if absf(lead.x) > .01 and lead.x * boat.to_local(endpoint).x < 0.0:
		return INF
	return endpoint.distance_to(boat.to_global(lead))


func reachable(feet: Vector3, point: Vector3) -> bool:
	return (feet + Vector3.UP * .95).distance_squared_to(point) <= Tackle.HAND_REACH * Tackle.HAND_REACH


func coil_reachable(feet: Vector3, coil: Vector3) -> bool:
	return (feet + Vector3.UP * .95).distance_squared_to(coil) <= COIL_REACH * COIL_REACH


func focus(boat: Boat, peer: int, onboard: bool, feet: Vector3, eye: Camera3D) -> Array:
	var tackle := boat.mooring
	var held := tackle.held_by(peer)
	var selected := []
	var nearest := INF
	if held >= 0:
		for index in cleats.size():
			var endpoint: Vector3 = cleats[index].at
			if not reachable(feet, endpoint) or line_gap(boat, held, index) > Tackle.LINE_REACH \
					or tackle.uses_cleat(index):
				continue
			var distance := aim_distance(eye, endpoint, CLEAT_RADIUS)
			if distance < nearest:
				nearest = distance
				selected = ["tie", held, index, "E  Tie %s line to cleat" % tackle.labels[held].to_lower()]
		if not selected.is_empty():
			return selected
		var coil := boat.to_global(tackle.stations[held])
		if onboard and coil_reachable(feet, coil) and aim_distance(eye, coil + Vector3.UP * .025, COIL_RADIUS) < INF:
			return ["stow", held, -1, "E  Put down %s line" % tackle.labels[held].to_lower()]
		return []
	for slot in tackle.lines.size():
		var line := tackle.lines[slot]
		if line.has("holder"):
			continue
		var coil := boat.to_global(tackle.stations[slot])
		var distance := INF
		if onboard and coil_reachable(feet, coil):
			distance = aim_distance(eye, coil + Vector3.UP * .025, COIL_RADIUS)
		if tackle.attached(slot):
			var lead := boat.to_global(line.get("lead", tackle.leads[slot]))
			if onboard and coil_reachable(feet, lead):
				distance = minf(distance, aim_distance(eye, lead, FAIRLEAD_RADIUS))
			var endpoint: Vector3 = line.end
			if reachable(feet, endpoint):
				distance = minf(distance, aim_distance(eye, endpoint, CLEAT_RADIUS))
		if distance < nearest:
			nearest = distance
			selected = ["untie" if tackle.attached(slot) else "pickup", slot, -1,
				"E  Untie %s line" % tackle.labels[slot].to_lower() if tackle.attached(slot) else
				"E  Pick up %s line" % tackle.labels[slot].to_lower()]
	return selected


func aim_distance(eye: Camera3D, center: Vector3, radius: float) -> float:
	var offset := center - eye.global_position
	var ahead := offset.dot(-eye.global_basis.z)
	if ahead <= 0.0:
		return INF
	var miss_squared := offset.length_squared() - ahead * ahead
	return ahead - sqrt(maxf(0.0, radius * radius - miss_squared)) if miss_squared <= radius * radius else INF


func act(boat: Boat, peer: int, person: Dictionary, value: Array) -> String:
	var action: String = value[0]
	var slot: int = value[1]
	var index: int = value[2]
	var feet: Vector3 = person.at
	var tackle := boat.mooring
	var held := tackle.held_by(peer)
	if slot < 0 or slot >= tackle.lines.size():
		return ""
	var coil := boat.to_global(tackle.stations[slot])
	var at_coil: bool = person.onboard and coil_reachable(feet, coil)
	var line := tackle.lines[slot]
	match action:
		"pickup":
			if at_coil and line.is_empty() and held < 0:
				tackle.lines[slot] = {"holder": peer}
				return "Aim at a dock cleat and press E to tie the %s line." % tackle.labels[slot].to_lower()
		"stow":
			if at_coil and held == slot:
				tackle.lines[slot] = {}
				return "%s line stowed." % tackle.labels[slot]
		"tie":
			if held != slot or index < 0 or index >= cleats.size():
				return ""
			if not reachable(feet, cleats[index].at) or line_gap(boat, slot, index) > Tackle.LINE_REACH \
					or tackle.uses_cleat(index):
				return "Use a free cleat within reach of the line."
			if absf(boat.speed) > MAX_SPEED or tackle.anchor.is_finite():
				return "Stop the boat and raise its anchor before tying up."
			tie(boat, slot, index)
			boat.departed = true
			return "%s line tied." % tackle.labels[slot]
		"untie":
			if held < 0 and tackle.attached(slot):
				var lead := boat.to_global(line.get("lead", tackle.leads[slot]))
				if at_coil or (person.onboard and coil_reachable(feet, lead)) or reachable(feet, line.end):
					tackle.lines[slot] = {}
					return "%s line untied." % tackle.labels[slot]
	return ""
