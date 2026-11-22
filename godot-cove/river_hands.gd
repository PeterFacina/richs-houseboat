extends RefCounted

const Hand = preload("res://river_hand_instance.gd")


static func build(parent: Node3D, side: float, sleeve: bool, pose := "shaft", tool := true) -> Node3D:
	var hand := Hand.new()
	parent.add_child(hand)
	hand.initialize(side, sleeve, pose, tool)
	return hand


static func set_pose(hand: Node3D, pose: String) -> void:
	hand.call("set_pose", pose)


static func wrist(hand: Node3D) -> Vector3:
	return hand.get("wrist_anchor")


static func align(hand: Node3D, point: Vector3, orientation: Basis, pose := "shaft") -> void:
	set_pose(hand, pose)
	var contact: Vector3 = hand.call("contact_point")
	hand.transform = Transform3D(orientation, point - orientation * contact)
