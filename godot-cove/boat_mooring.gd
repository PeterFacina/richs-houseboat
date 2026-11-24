extends RefCounted

const LINE_REACH := 4.5
const HAND_REACH := 2.8
const SLACK := .18

var anchor := Vector3.INF
var lines: Array[Dictionary] = [{}, {}]


func secured() -> bool:
	return anchor.is_finite() or attached(0) or attached(1)


func attached(slot: int) -> bool:
	return lines[slot].has("cleat")


func held_by(peer: int) -> int:
	for slot in lines.size():
		if int(lines[slot].get("holder", 0)) == peer:
			return slot
	return -1


func clear() -> void:
	anchor = Vector3.INF
	lines = [{}, {}]


static func station(slot: int, small: bool) -> Vector3:
	if slot == 0:
		return Vector3(-.39, .52, -1.63) if small else Vector3(-.54, .88, -2.75)
	return Vector3(-.46, .53, 1.67) if small else Vector3(-.68, .88, 5.30)


static func anchor_station(small: bool) -> Vector3:
	return Vector3(.38, .52, -1.63) if small else Vector3(.55, .88, -2.82)


static func fairlead(slot: int, small: bool, side: float) -> Vector3:
	var point := station(slot, small)
	point.x = side * (.87 if small else 1.34)
	return point


func tie(slot: int, cleat: int, ends: Vector3, local_cleat: Vector3, hull: Transform3D, small: bool) -> void:
	var side := 1.0 if local_cleat.x >= 0.0 else -1.0
	var lead := hull * fairlead(slot, small, side)
	var length := Vector2(lead.x - ends.x, lead.z - ends.z).length() + SLACK
	lines[slot] = {"cleat": cleat, "end": ends, "side": side, "length": length}


func constrain(candidate: Vector3, yaw: float, small: bool) -> Vector3:
	var frame := Basis(Vector3.UP, yaw)
	if anchor.is_finite():
		return limit_distance(candidate, anchor - frame * anchor_station(small), SLACK)
	# Solve unilateral line constraints on the existing kinematic hull. Vertical
	# motion is sampled independently by the wave model.
	for sweep in 3:
		for slot in lines.size():
			if attached(slot):
				var line := lines[slot]
				var center_at: Vector3 = line.end - frame * fairlead(slot, small, line.side)
				candidate = limit_distance(candidate, center_at, line.length)
	return candidate


static func limit_distance(candidate: Vector3, center_at: Vector3, length: float) -> Vector3:
	var offset := Vector3(candidate.x - center_at.x, 0, candidate.z - center_at.z)
	return candidate - offset + offset.limit_length(length)


func packet() -> Array:
	return [anchor, lines.duplicate(true)]


func receive(data: Array) -> void:
	anchor = data[0]
	lines.assign(data[1])
