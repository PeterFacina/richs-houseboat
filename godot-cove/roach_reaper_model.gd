extends Node3D

const Kit = preload("res://scenery.gd")
const Hands = preload("res://river_hands.gd")
const Actions = preload("res://river_hand_actions.gd")
const Props = preload("res://cabin_props.gd")

var jacket := Kit.paint(Color("#657652"))
var denim := Kit.paint(Color("#364558"))
var skin := Kit.paint(Color("#bc8c6b"))
var boot := Kit.paint(Color("#39302a"))
var cap := Kit.paint(Color("#cb8a4b"))
var torso: MeshInstance3D
var arms: Array[MeshInstance3D] = []
var legs: Array[MeshInstance3D] = []
var head := Node3D.new()
var phone := Node3D.new()
var right_hand: Node3D
var left_hand: Node3D
var joint: Node3D
var ember: MeshInstance3D
var smoke: CPUParticles3D


func _ready() -> void:
	torso = rounded(self, Vector3.ZERO, Vector3(.43, .48, .30), jacket)
	for index in 4:
		arms.append(rounded(self, Vector3.ZERO, Vector3.ONE, jacket))
		legs.append(rounded(self, Vector3.ZERO, Vector3.ONE, denim))
	for side: float in [-1.0, 1.0]:
		rounded(self, Vector3(side * .14, .09, -.59), Vector3(.14, .17, .27), boot)
	add_child(head)
	rounded(head, Vector3.ZERO, Vector3(.21, .27, .22), skin)
	rounded(head, Vector3(0, -.006, .103), Vector3(.045, .045, .047), skin)
	rounded(head, Vector3(0, -.086, .048), Vector3(.173, .067, .164), boot)
	for side: float in [-1.0, 1.0]:
		rounded(head, Vector3(side * .044, .020, .097), Vector3(.021, .015, .012), boot)
	rounded(head, Vector3(0, .088, -.008), Vector3(.231, .115, .221), cap)
	rounded(head, Vector3(0, .058, .097), Vector3(.212, .025, .167), cap)
	add_child(phone)
	Kit.box_at(phone, Vector3.ZERO, Vector3(.068, .012, .125), boot)
	var screen := Kit.paint(Color("#78858e"))
	screen.emission_enabled = true
	screen.emission = Color("#8098ad")
	Kit.box_at(phone, Vector3.UP * .006, Vector3(.057, .003, .108), screen)
	var light := SpotLight3D.new()
	light.rotation.x = -PI * .5
	light.spot_range = 2.1
	light.spot_angle = 31.0
	light.light_energy = 2.1
	light.light_color = Color("#dce9ff")
	phone.add_child(light)
	right_hand = Hands.build(self, 1.0, false, "hold", false)
	left_hand = Hands.build(self, -1.0, false, "relaxed", false)
	joint = build_roach(self, true)
	ember = joint.get_child(2)
	smoke = CPUParticles3D.new()
	smoke.emitting = false
	smoke.amount = 18
	smoke.lifetime = 1.3
	smoke.direction = Vector3(0, .56, 1)
	smoke.spread = 22.0
	smoke.initial_velocity_min = .36
	smoke.initial_velocity_max = .67
	smoke.gravity = Vector3.UP * .31
	smoke.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(smoke)


func set_smoke_mesh(mesh: Mesh) -> void:
	smoke.mesh = mesh
	var fade := Gradient.new()
	fade.offsets = PackedFloat32Array([0.0, .2, .68, 1.0])
	fade.colors = PackedColorArray([Color.TRANSPARENT, Color(1, 1, 1, .32), Color(1, 1, 1, .12), Color.TRANSPARENT])
	smoke.color_ramp = fade


func animate(clock: float, smoke_age: float) -> void:
	var smoking := smoke_age >= 0.0
	var scanning := sin(clock * 1.13) * (.45 + .55 * pow(maxf(0.0, sin(clock * .47)), 4.0))
	var rise := smoothstep(0.0, .65, smoke_age)
	var hips := Vector3(0, .51, -.32).lerp(Vector3(0, .60, -.47), rise)
	var shoulders := Vector3(.035 * scanning, .61, .14).lerp(Vector3(0, .96, -.29), rise)
	segment(torso, hips, shoulders, .36, .23)
	head.position = shoulders + Vector3(.064 * scanning * (1.0 - rise), .075, .207).lerp(Vector3(0, .20, .051), rise)
	head.rotation = Vector3(lerpf(.61 + .18 * scanning, -.09, rise), .46 * scanning * (1.0 - rise), 0)
	var wrist := Vector3(.23 + .10 * scanning, .20 + .04 * cos(clock * 1.09), .44 + .11 * scanning)
	var left_support := Vector3(-.22, .040, .41).lerp(Vector3(-.19, .36, -.10), rise)
	var elbow := Vector3(.22, .40, .26).lerp(Vector3(.31, .67, -.23), rise)
	phone.position = wrist + Vector3(.009, .012, .045)
	phone.rotation = Vector3(.19 + .27 * scanning, .37 * scanning, .24)
	phone.visible = not smoking
	joint.visible = smoking
	if smoking:
		var inhale := Actions.inhale(Props.Item.PEN, smoke_age - .62)
		var lip := head.transform * Vector3(0, -.063, .111)
		joint.rotation = Vector3(lerpf(.42, PI * .5, inhale), 0, 0)
		joint.position = Vector3(.23, .67, .04).lerp(lip, inhale)
		Actions.attach_smoking_grip(right_hand, joint.transform, Vector3.UP * .037, "pinch", 1.0)
		ember.scale = Vector3.ONE * (1.0 + .37 * inhale)
		smoke.position = lip + Vector3.FORWARD * -.025
		smoke.emitting = smoke_age > 2.93 and smoke_age < 3.87
	else:
		Hands.align(right_hand, phone.position + phone.basis * Vector3(.021, 0, -.022), phone.basis, "hold")
		smoke.emitting = false
	Hands.align(left_hand, left_support, Basis.IDENTITY, "relaxed")
	var left_wrist := left_hand.transform * Hands.wrist(left_hand)
	wrist = right_hand.transform * Hands.wrist(right_hand)
	for index in 2:
		var side := -1.0 if index == 0 else 1.0
		var shoulder := shoulders + Vector3(side * .185, -.025, 0)
		var flex := Vector3(-.24, .32, .23).lerp(Vector3(-.23, .62, -.25), rise) if index == 0 else elbow
		segment(arms[index * 2], shoulder, flex, .106, .105)
		segment(arms[index * 2 + 1], flex, left_wrist if index == 0 else wrist, .088, .088)
		var knee := Vector3(side * .17, .103, -.14)
		segment(legs[index * 2], hips + Vector3(side * .115, 0, 0), knee, .153, .15)
		segment(legs[index * 2 + 1], knee, Vector3(side * .14, .095, -.55), .14, .14)


static func build_roach(parent: Node3D, lit: bool) -> Node3D:
	var model := Node3D.new()
	parent.add_child(model)
	Kit.box_at(model, Vector3(0, .022, 0), Vector3(.016, .042, .016), Kit.paint(Color("#b39c73")))
	Kit.mesh_at(model, cone(.009, .013, .054), Vector3.UP * .065, Kit.paint(Color("#ece0bf")))
	var ash := Kit.paint(Color("#ef4e18") if lit else Color("#332a27"))
	if lit:
		ash.emission_enabled = true
		ash.emission = Color("#ff4314")
		ash.emission_energy_multiplier = 2.0
	Kit.mesh_at(model, cone(.008, .009, .012), Vector3.UP * .095, ash)
	return model


static func cone(top: float, bottom: float, height: float) -> CylinderMesh:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 9
	mesh.rings = 1
	return mesh


static func rounded(parent: Node3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = .5
	mesh.height = 1.0
	mesh.radial_segments = 14
	mesh.rings = 8
	var part := Kit.mesh_at(parent, mesh, at, material)
	part.scale = size
	return part


static func segment(part: MeshInstance3D, start: Vector3, end: Vector3, width: float, depth: float) -> void:
	var direction := end - start
	part.transform = Transform3D(Basis(Quaternion(Vector3.UP, direction.normalized())).scaled_local(
		Vector3(width, direction.length() + .07, depth)), (start + end) * .5)
