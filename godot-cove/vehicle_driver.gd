extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Avatar = preload("res://crew_avatar.gd")

var head: Node3D
var torso: MeshInstance3D
var sleeve: Array[MeshInstance3D] = []
var forearm: Array[MeshInstance3D] = []
var hands: Array[MeshInstance3D] = []
var seat := Vector3.ZERO
var eyes := Vector3.ZERO
var rig := Avatar.new()


func build(eye_point: Vector3, hip: Vector3) -> void:
	eyes = eye_point
	seat = hip
	add_child(rig)
	var jacket := Kit.paint(Color("#425c63"), .87)
	var denim := Kit.paint(Color("#394346"), .90)
	var skin := Kit.paint(Color("#c59679"), .85)
	var cap := Kit.paint(Color("#39484d"), .87)
	var boots := Kit.paint(Color("#242b2b"), .92)
	torso = Tools.shell(self, seat.lerp(eyes, .47), Vector3(.40, (eyes.y - seat.y) * .87, .255), jacket)
	torso.rotation.x = -.11
	Tools.shell(self, seat + Vector3.UP * .065, Vector3(.33, .22, .27), denim)
	head = Node3D.new()
	add_child(head)
	head.position = eyes
	Tools.shell(head, Vector3(0, -.035, .043), Vector3(.198, .248, .212), skin)
	Tools.shell(head, Vector3(0, -.026, -.067), Vector3(.040, .060, .065), skin)
	Tools.shell(head, Vector3(0, .050, .052), Vector3(.224, .098, .225), cap)
	Tools.shell(head, Vector3(0, .045, -.075), Vector3(.199, .026, .160), cap)
	for side: float in [-1.0, 1.0]:
		Tools.shell(head, Vector3(side * .103, -.036, .047), Vector3(.035, .054, .040), skin)
		Tools.shell(head, Vector3(side * .045, -.010, -.050), Vector3(.023, .012, .015), boots)
		sleeve.append(rig.limb(.069, .062, jacket))
		forearm.append(rig.limb(.050, .031, skin))
		hands.append(Tools.shell(self, Vector3.ZERO, Vector3(.078, .065, .093), skin))
		var hip_side := seat + Vector3(side * .095, .045, .015)
		var knee := hip_side + Vector3(0, .025, -.35)
		var ankle := knee + Vector3(0, -.315, -.10)
		rig.bind_segment(rig.limb(.090, .073, denim), hip_side, knee)
		rig.bind_segment(rig.limb(.072, .050, denim), knee, ankle)
		Tools.shell(self, ankle + Vector3(0, -.009, -.050), Vector3(.116, .101, .204), boots)
	hide()


func pose(left: Vector3, right: Vector3, turning: float, hide_head: bool, hide_arms := false) -> void:
	show()
	head.visible = not hide_head
	head.rotation.y = -turning * .22
	for index in 2:
		var side := float(2 * index - 1)
		var hand := left if index == 0 else right
		var shoulder := seat.lerp(eyes, .71) + Vector3(side * .161, 0, .016)
		var elbow := rig.elbow(shoulder, hand, Vector3(side * .12, -1.0, .10), .265, .255)
		rig.bind_segment(sleeve[index], shoulder, elbow)
		rig.bind_segment(forearm[index], elbow, hand)
		hands[index].position = hand
		sleeve[index].visible = not hide_arms
		forearm[index].visible = not hide_arms
		hands[index].visible = not hide_arms
