extends Node3D

const Kit = preload("res://scenery.gd")

var torso: Node3D
var head: Node3D
var arms: Array[Node3D] = []
var elbows: Array[Node3D] = []


func build() -> void:
	var skin := Kit.paint(Color("#c9957d"), .78)
	var sweater := Kit.paint(Color("#252b38"), .82)
	var vest := Kit.paint(Color("#172b55"), .82)
	var vest_edge := Kit.paint(Color("#101d3c"), .70)
	var denim := Kit.paint(Color("#34465d"), .82)
	var shoe := Kit.paint(Color("#17191d"), .74)
	var hair := Kit.paint(Color("#302b2a"), .89)
	var shirt := Kit.paint(Color("#171c2a"), .8)
	var eye_white := Kit.paint(Color("#e6ded1"), .61)
	var iris := Kit.paint(Color("#4a4039"), .52)
	var stubble := Kit.paint(Color("#66564c"), .96)
	for side in [-1.0, 1.0]:
		var leg := Node3D.new()
		leg.position = Vector3(side * .105, .04, 0)
		add_child(leg)
		capsule(leg, Vector3(0, .38, 0), .087, .72, denim)
		capsule(leg, Vector3(0, .05, .065), .082, .13, shoe)
		Kit.box_at(leg, Vector3(0, -.012, .111), Vector3(.17, .045, .23), shoe)
	torso = Node3D.new()
	torso.position.y = .78
	add_child(torso)
	capsule(torso, Vector3(0, .23, 0), .205, .57, sweater)
	# The quilted vest uses separate padded panels and short horizontal channels.
	capsule(torso, Vector3(-.103, .239, .058), .115, .54, vest)
	capsule(torso, Vector3(.103, .239, .058), .115, .54, vest)
	var seam := Kit.paint(Color("#293b66"), .72)
	for y in [.03, .105, .18, .255, .33, .405]:
		for side in [-1.0, 1.0]:
			Kit.box_at(torso, Vector3(side * .104, y, .14), Vector3(.135, .012, .009), seam)
	Kit.box_at(torso, Vector3(0, .24, .169), Vector3(.018, .51, .016), vest_edge)
	Kit.box_at(torso, Vector3(0, .555, .005), Vector3(.14, .10, .16), shirt)
	for side in [-1.0, 1.0]:
		var shoulder := Node3D.new()
		shoulder.position = Vector3(side * .195, .47, 0)
		torso.add_child(shoulder)
		capsule(shoulder, Vector3(0, -.125, 0), .075, .36, sweater)
		var elbow := Node3D.new()
		elbow.position.y = -.28
		shoulder.add_child(elbow)
		capsule(elbow, Vector3(0, -.13, 0), .057, .31, sweater)
		var palm := Kit.mesh_at(elbow, SphereMesh.new(), Vector3(0, -.31, .035), skin)
		palm.scale = Vector3(.062, .076, .028)
		for finger in 3:
			capsule(elbow, Vector3((finger - 1) * .030, -.385, .045), .012, .085, skin)
		capsule(elbow, Vector3(-.064, -.324, .039), .014, .075, skin)
		arms.append(shoulder)
		elbows.append(elbow)
	head = Node3D.new()
	head.position = Vector3(0, .66, .015)
	torso.add_child(head)
	var face := SphereMesh.new()
	face.radius = .135
	face.height = .345
	var face_mesh := Kit.mesh_at(head, face, Vector3(0, .035, .005), skin)
	face_mesh.scale = Vector3(.87, 1.0, .90)
	for side in [-1.0, 1.0]:
		capsule(head, Vector3(side * .125, .04, .007), .025, .075, skin)
		var socket := SphereMesh.new()
		socket.radius = .019
		socket.height = .034
		Kit.mesh_at(head, socket, Vector3(side * .05, .015, .119), eye_white)
		var pupil := SphereMesh.new()
		pupil.radius = .008
		pupil.height = .016
		Kit.mesh_at(head, pupil, Vector3(side * .05, .015, .135), iris)
		var brow := capsule(head, Vector3(side * .05, .065, .116), .009, .056, hair)
		brow.rotation.z = side * -.08
	# Short, narrow nose and calm mouth; geometry carries the expression, not a face decal.
	capsule(head, Vector3(0, -.014, .139), .014, .065, skin)
	var upper_lip := capsule(head, Vector3(0, -.045, .136), .006, .052, stubble)
	upper_lip.rotation.z = PI * .5
	var chin := SphereMesh.new()
	chin.radius = .038
	chin.height = .020
	var chin_mesh := Kit.mesh_at(head, chin, Vector3(0, -.082, .118), stubble)
	chin_mesh.scale = Vector3(1.15, .75, .4)
	# Side swept hairline and short crown.
	var cap := SphereMesh.new()
	cap.radius = .145
	cap.height = .13
	var hair_mesh := Kit.mesh_at(head, cap, Vector3(0, .151, -.004), hair)
	hair_mesh.scale = Vector3(1.0, .77, 1.0)
	var sweep := Kit.box_at(head, Vector3(-.034, .218, .009), Vector3(.17, .035, .11), hair)
	sweep.rotation.z = -.19
	var shoe_tag := Kit.paint(Color("#a4b0bd"), .45, .35)
	Kit.box_at(torso, Vector3(0, .014, .165), Vector3(.006, .40, .008), shoe_tag)


func pose_idle(elapsed: float) -> void:
	if head:
		head.rotation.y = sin(elapsed * .27) * .07
		head.rotation.x = sin(elapsed * .4) * .018
	if torso:
		torso.rotation.z = sin(elapsed * .5) * .012
	for i in arms.size():
		arms[i].rotation.z = (-.08 if i == 0 else .08) + sin(elapsed * .4 + i) * .016


func capsule(parent: Node3D, at: Vector3, radius: float, height: float, material: Material) -> MeshInstance3D:
	var shape := CapsuleMesh.new()
	shape.radius = radius
	shape.height = height
	shape.radial_segments = 14
	shape.rings = 5
	return Kit.mesh_at(parent, shape, at, material)
