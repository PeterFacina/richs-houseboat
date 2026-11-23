extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Shape = preload("res://rich_model.gd")
const NAME := "Marina Attendant"
const TALK_POINT := Vector3(0, 1.68, .07)

var torso: Node3D
var head: Node3D
var name_tag: Label3D
var shoulders: Array[Node3D] = []
var elbows: Array[Node3D] = []


func build() -> void:
	var workshirt := Kit.paint(Color("#548582"), .87)
	var seam := Kit.paint(Color("#33595a"), .9)
	var badge := Kit.paint(Color("#dccd9f"), .78)
	var denim := Kit.paint(Color("#353f46"), .91)
	var boot := Kit.paint(Color("#272b27"), .85)
	var skin := Kit.paint(Color("#a96f50"), .82)
	var shade := Kit.paint(Color("#89523c"), .90)
	torso = Node3D.new()
	add_child(torso)
	torso.position.y = .90
	Shape.loft(torso, [
		Vector4(-.095, .136, .085, .084), Vector4(-.035, .191, .107, .103),
		Vector4(.046, .218, .131, .117), Vector4(.170, .229, .146, .126),
		Vector4(.31, .252, .142, .120), Vector4(.469, .262, .122, .108),
		Vector4(.521, .229, .110, .095), Vector4(.555, .135, .087, .077),
		Vector4(.565, .078, .064, .065)], workshirt, 32)
	Kit.box_at(torso, Vector3(0, .282, .143), Vector3(.027, .476, .015), seam)
	for i in 4:
		Tools.shell(torso, Vector3(0, .126 + i * .092, .155), Vector3(.012, .012, .010), badge)
	for side: float in [-1.0, 1.0]:
		var pocket := Vector3(side * .121, .345, .132)
		Kit.box_at(torso, pocket, Vector3(.105, .106, .018), workshirt)
		Kit.box_at(torso, pocket + Vector3(0, .039, .013), Vector3(.114, .026, .016), seam)
		Kit.beam(torso, Vector3(side * .059, .548, .055), Vector3(side * .094, .472, .130), .029, seam)
		var leg := Vector3(side * .115, 0, 0)
		Tools.tube(self, leg + Vector3(0, .153, .018), leg + Vector3(0, .832, -.032), .072, .112, denim)
		Kit.box_at(self, leg + Vector3(0, .087, .057), Vector3(.159, .15, .266), boot)
		Kit.box_at(self, leg + Vector3(0, .025, .057), Vector3(.164, .048, .275), seam)
		build_arm(side, workshirt, seam, skin)
	Kit.box_at(torso, Vector3(.128, .435, .135), Vector3(.125, .039, .012), badge)
	var patch := Label3D.new()
	patch.text = "MARINA"
	patch.position = Vector3(.128, .435, .144)
	patch.font_size = 24
	patch.pixel_size = .00117
	patch.outline_size = 0
	patch.modulate = Color("#284b48")
	torso.add_child(patch)
	build_head(skin, shade)

	name_tag = Label3D.new()
	name_tag.text = NAME
	name_tag.position.y = 2.10
	name_tag.font_size = 30
	name_tag.pixel_size = .0032
	name_tag.modulate = Color("#f3ecd9")
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.hide()
	add_child(name_tag)


func build_arm(side: float, shirt: Material, seam: Material, skin: Material) -> void:
	var shoulder := Node3D.new()
	torso.add_child(shoulder)
	shoulder.position = Vector3(side * .231, .467, -.002)
	shoulders.append(shoulder)
	Tools.tube(shoulder, Vector3.DOWN * .185, Vector3.UP * .028, .091, .096, shirt)
	Tools.tube(shoulder, Vector3.DOWN * .194, Vector3.DOWN * .177, .088, .091, seam)
	Tools.tube(shoulder, Vector3.DOWN * .263, Vector3.DOWN * .168, .069, .081, skin)
	var elbow := Node3D.new()
	shoulder.add_child(elbow)
	elbow.position.y = -.262
	elbows.append(elbow)
	Tools.tube(elbow, Vector3.DOWN * .216, Vector3.UP * .012, .044, .071, skin)
	Tools.shell(elbow, Vector3(0, -.239, .015), Vector3(.096, .111, .057), skin)
	Tools.shell(elbow, Vector3(side * .037, -.218, .022), Vector3(.040, .056, .034), skin)


func build_head(skin: Material, shade: Material) -> void:
	var dark := Kit.paint(Color("#322822"), .86)
	var cap := Kit.paint(Color("#354448"), .93)
	Tools.tube(torso, Vector3.UP * .528, Vector3.UP * .662, .081, .074, skin)
	head = Node3D.new()
	torso.add_child(head)
	head.position.y = .633
	Tools.shell(head, Vector3(0, .107, .004), Vector3(.249, .280, .228), skin)
	Tools.shell(head, Vector3(0, .046, .055), Vector3(.226, .169, .175), skin)
	Tools.shell(head, Vector3(0, .113, .113), Vector3(.058, .058, .077), skin)
	Tools.shell(head, Vector3(0, .039, .132), Vector3(.070, .012, .013), shade)
	for side: float in [-1.0, 1.0]:
		Tools.shell(head, Vector3(side * .124, .096, .005), Vector3(.042, .067, .043), skin)
		Tools.shell(head, Vector3(side * .053, .134, .105), Vector3(.035, .017, .015), dark)
		Tools.shell(head, Vector3(side * .054, .158, .103), Vector3(.046, .014, .014), shade).rotation.z = -.10 * side
	Tools.shell(head, Vector3(0, .197, -.008), Vector3(.271, .137, .259), cap)
	Tools.shell(head, Vector3(0, .172, .114), Vector3(.230, .031, .203), cap).rotation.x = .14


func pose(delta: float, clock: float, viewer: Vector3, gesture: String, age: float) -> void:
	var local_view := to_local(viewer) - TALK_POINT
	var nearby := local_view.length_squared() < 11.0 * 11.0
	name_tag.visible = nearby
	var gaze := clampf(atan2(local_view.x, local_view.z), -.69, .69) if nearby else sin(clock * .51) * .11
	var blend := 1.0 - exp(-delta * 10.0)
	torso.rotation.z = .025 + sin(clock * 1.45) * .014
	head.rotation.y = lerp_angle(head.rotation.y, gaze, blend)
	for index in 2:
		var side := float(index * 2 - 1)
		var arm := Vector3(-.10, 0, .16 * side)
		var bend := -.15
		if index == 0 and not gesture.is_empty():
			var reach := smoothstep(.06, .43, age) * (1.0 - smoothstep(1.23, 1.65, age))
			arm += Vector3(-.31, 0, -.83) * reach
			bend -= (.99 + sin(age * 9.0) * .12 if gesture == "greet" else .24) * reach
		shoulders[index].rotation = shoulders[index].rotation.lerp(arm, blend)
		elbows[index].rotation.x = lerpf(elbows[index].rotation.x, bend, blend)
