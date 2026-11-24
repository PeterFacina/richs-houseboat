extends RefCounted

const Props = preload("res://cabin_props.gd")
const Hands = preload("res://river_hands.gd")
const DURATION := [5.34, 3.29, 3.02, 3.02]
const VERTICAL_GRIP := Basis(Vector3.RIGHT, Vector3.BACK, Vector3.DOWN)


static func inhale(kind: int, age: float) -> float:
	match kind:
		Props.Item.BONG: return smoothstep(2.17, 2.67, age) * (1 - smoothstep(3.36, 3.82, age))
		Props.Item.PEN: return smoothstep(.52, .91, age) * (1 - smoothstep(1.80, 2.23, age))
		_: return smoothstep(1.08, 1.53, age) * (1 - smoothstep(2.16, 2.63, age))


static func prop_pose(kind: int, age: float, reach: Vector3) -> Transform3D:
	var rest := Vector3(.17, -.36, -.51) if kind == Props.Item.BONG else Vector3(.19, -.29, -.43)
	var turn := Vector3(-.12, -.12, -.04)
	var use := inhale(kind, age)
	if kind == Props.Item.BONG:
		# Bring the mouthpiece inward while the chamber stays ahead of the
		# jacket; an upright tube at the lips buries the holding hand in the chest.
		turn.x = lerpf(-.12, .50, use)
	elif kind == Props.Item.PEN:
		turn.x = lerpf(-.12, .88, use)
	else:
		turn.x = lerpf(-.12, 1.14, use)
	var rotation := Basis.from_euler(turn)
	var mouth := Vector3(0, .271, 0) if kind == Props.Item.BONG else Vector3(0, .124, 0) if kind == Props.Item.PEN else Vector3(0, .117, .015)
	var lip := view_lip(kind)
	var at := rest.lerp(lip - rotation * mouth, use)
	var retrieve := smoothstep(.08, .52, age)
	at = reach.lerp(at, retrieve)
	at += Vector3.DOWN * smoothstep(DURATION[kind] - .6, DURATION[kind], age) * .28
	return Transform3D(rotation, at)


static func view_lip(kind: int) -> Vector3:
	# Keep the close viewmodel inside the camera frustum. The world avatar uses
	# the anatomical mouth target below, with the whole grip assembly shifted.
	match kind:
		Props.Item.BONG: return Vector3(.015, -.012, -.34)
		Props.Item.PEN: return Vector3(.015, -.033, -.20)
		_: return Vector3(.035, -.065, -.30)


static func world_offset(kind: int, age: float) -> Vector3:
	return (Vector3(.015, -.115, -.14) - view_lip(kind)) * inhale(kind, age)


static func right_grip(kind: int) -> Vector3:
	match kind:
		Props.Item.BONG: return Vector3(.018, .105, .008)
		Props.Item.PEN: return Vector3(0, .047, 0)
		_: return Vector3(.004, .055, .003)


static func right_pose(kind: int) -> String:
	return "bottle" if kind == Props.Item.BONG else "pinch" if kind == Props.Item.PEN else "can"


static func attach(hand: Node3D, item: Transform3D, point: Vector3, pose: String) -> void:
	Hands.align(hand, item * point, item.basis * VERTICAL_GRIP, pose)


static func attach_smoking_grip(hand: Node3D, item: Transform3D, point: Vector3, pose: String, side: float) -> void:
	# Put the thumb toward the top of the prop and angle the wrist back
	# toward the shoulder on the side holding it.
	var grip := Basis(Vector3.RIGHT, Vector3.FORWARD, Vector3.UP)
	grip = Basis(Vector3.UP, -side * PI * .25) * grip
	Hands.align(hand, item * point, item.basis * grip, pose)
