extends RefCounted

const LINE_REACH := 4.5
const HAND_REACH := 2.8
const SLACK := .18
const ANCHOR_KEY := KEY_G

var stations: Array[Vector3] = []
var leads: Array[Vector3] = []
var labels: Array[String] = []
var roller := Vector3.ZERO
var anchor := Vector3.INF
var anchor_progress := 0.0
var anchor_down := false
var lines: Array[Dictionary] = []


func fit(coils: Array[Vector3], fairleads: Array[Vector3], names: Array[String], anchor_roller: Vector3) -> void:
	stations = coils
	leads = fairleads
	labels = names
	roller = anchor_roller
	clear()


func secured() -> bool:
	return anchor.is_finite() or tied()


func tied() -> bool:
	for line in lines:
		if line.has("cleat"):
			return true
	return false


func attached(slot: int) -> bool:
	return lines[slot].has("cleat")


func uses_cleat(cleat: int) -> bool:
	for line in lines:
		if int(line.get("cleat", -1)) == cleat:
			return true
	return false


func held_by(peer: int) -> int:
	for slot in lines.size():
		if int(lines[slot].get("holder", 0)) == peer:
			return slot
	return -1


func clear() -> void:
	anchor = Vector3.INF
	anchor_progress = 0.0
	anchor_down = false
	lines.clear()
	for slot in stations.size():
		lines.append({})


func tie(slot: int, cleat: int, endpoint: Vector3, hull: Transform3D, fairlead: Vector3) -> void:
	var lead := hull * fairlead
	var length := Vector2(lead.x - endpoint.x, lead.z - endpoint.z).length() + SLACK
	lines[slot] = {"cleat": cleat, "end": endpoint, "length": length, "lead": fairlead}


func tick_anchor(delta: float) -> void:
	if not anchor.is_finite():
		return
	var travel_time := clampf(.9 - anchor.y * .16, .9, 3.2)
	anchor_progress = move_toward(anchor_progress, 1.0 if anchor_down else 0.0, delta / travel_time)
	if not anchor_down and anchor_progress == 0.0:
		anchor = Vector3.INF


func anchor_hint() -> String:
	if not anchor.is_finite():
		return "G  Lower anchor"
	if not anchor_down:
		return "Raising anchor..."
	if anchor_progress < 1.0:
		return "Lowering anchor..."
	return "G  Raise anchor"


func anchor_lead() -> Vector3:
	return roller + Vector3(.079, -.03, 0)


func constrain(candidate: Vector3, yaw: float) -> Vector3:
	var frame := Basis(Vector3.UP, yaw)
	if anchor.is_finite():
		return limit_distance(candidate, anchor - frame * anchor_lead(), SLACK)
	# Apply only tension from taut lines. Wave heave, pitch and roll are sampled separately.
	for sweep in 3:
		for slot in lines.size():
			if attached(slot):
				var line := lines[slot]
				var center_at: Vector3 = line.end - frame * Vector3(line.get("lead", leads[slot]))
				candidate = limit_distance(candidate, center_at, line.length)
	return candidate


static func limit_distance(candidate: Vector3, center_at: Vector3, length: float) -> Vector3:
	var offset := Vector3(candidate.x - center_at.x, 0, candidate.z - center_at.z)
	return candidate - offset + offset.limit_length(length)


func packet() -> Array:
	return [anchor, lines.duplicate(true), anchor_progress, anchor_down]


func receive(data: Array) -> void:
	anchor = data[0]
	var incoming: Array = data[1]
	for slot in lines.size():
		lines[slot] = incoming[slot] if slot < incoming.size() else {}
	anchor_progress = float(data[2]) if data.size() > 2 else float(anchor.is_finite())
	anchor_down = bool(data[3]) if data.size() > 3 else anchor.is_finite()
