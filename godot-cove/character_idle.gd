extends RefCounted

enum { NONE, SHIFT, LOOK, POSTURE, STRETCH, SCRATCH, POCKETS, PHONE }
const NAMES := ["Breathing", "Weight shift", "Look around", "Adjust posture", "Stretch", "Scratch head", "Hands in pockets", "Check phone"]
const DURATIONS := [0.0, 2.8, 3.0, 2.1, 3.15, 2.5, 4.2, 5.1]

var random := RandomNumberGenerator.new()
var duration := 0.0
var wait := 0.0
var kind := NONE
var age := 0.0
var previous := NONE
var side := 1.0


func _init() -> void:
	random.randomize()
	wait = random.randf_range(6.0, 13.0)


func tick(delta: float, stationary: bool, free_hands: bool) -> void:
	if not stationary or (not free_hands and kind >= STRETCH):
		if duration > 0.0:
			wait = random.randf_range(6.0, 13.0)
		duration = 0.0
		kind = NONE
		return
	duration += delta
	if kind != NONE:
		age += delta
		if age < DURATIONS[kind]:
			return
		cancel()
		wait = duration + random.randf_range(7.0, 17.0)
	if duration < wait:
		return
	var choice := random.randi_range(SHIFT, PHONE if duration > 36.0 else POCKETS) if free_hands else random.randi_range(SHIFT, POSTURE)
	if choice == previous:
		choice = LOOK if choice != LOOK else SHIFT
	start(choice)


func cancel() -> void:
	kind = NONE
	age = 0.0


func start(gesture: int) -> void:
	kind = clampi(gesture, NONE, PHONE)
	previous = kind
	age = 0.0
	side = -1.0 if random.randf() < .5 else 1.0


func packet() -> Vector3:
	return Vector3(kind, age, side)


static func weight(state: Vector3) -> float:
	var gesture := clampi(int(state.x), NONE, PHONE)
	if gesture == NONE:
		return 0.0
	return smoothstep(0.0, .42, state.y) * (1.0 - smoothstep(DURATIONS[gesture] - .60, DURATIONS[gesture], state.y))


static func torso(state: Vector3, strength: float) -> Vector3:
	match int(state.x):
		SHIFT: return Vector3(0, .05, .078 * state.z) * strength
		POSTURE: return Vector3(-.12, .02 * state.z, 0) * strength
		STRETCH: return Vector3(-.075, 0, .04 * state.z) * strength
		PHONE: return Vector3(.072, 0, 0) * strength
	return Vector3.ZERO


static func head(state: Vector3, strength: float) -> Vector3:
	match int(state.x):
		LOOK: return Vector3(.055, sin(state.y * 1.35) * .55 * state.z, .07 * state.z) * strength
		SCRATCH: return Vector3(.05, 0, -.11 * state.z) * strength
		PHONE: return Vector3(.32, .03, 0) * strength
	return Vector3.ZERO


static func hand(state: Vector3, side_of_hand: float, strength: float) -> Vector3:
	match int(state.x):
		STRETCH: return Vector3(.27 * side_of_hand, .40, -.14) * strength
		SCRATCH:
			if side_of_hand == state.z:
				return Vector3(-.09 * side_of_hand, .67 + sin(state.y * 17.0) * .023, -.04) * strength
		POCKETS: return Vector3(-.10 * side_of_hand, .04, -.075) * strength
		PHONE: return Vector3(-.18 * side_of_hand, .31, -.28) * strength
	return Vector3.ZERO
