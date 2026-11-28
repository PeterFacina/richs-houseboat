extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const BASE := "res://deep_river/rich/"
const HEAD_HEIGHT := .239

var torso: Node3D
var head: Node3D
var idle_phone: MeshInstance3D
var hips: MeshInstance3D
var upper_arms: Array[Node3D] = []
var elbows: Array[Node3D] = []
var wrists: Array[Node3D] = []
var legs: Array[Node3D] = []
var shorts_legs: Array[MeshInstance3D] = []
var pace := 0.0
var arm_surfaces: Array[ShaderMaterial] = []
var face: ShaderMaterial
var head_turn := 0.0
var jaw := 0.0


func build(with_props := true) -> void:
	var shorts := ShaderMaterial.new()
	shorts.shader = preload("res://rich_boardshorts.gdshader")
	var shirt := fabric(Color("#c6a5a0"), .80)
	var collar := fabric(Color("#b69592"), .28)
	var arm_skin := Kit.paint(Color("#c18b71"), .83)
	arm_skin.roughness = .87
	for side: float in [-1.0, 1.0]:
		build_leg(side, shorts, arm_skin)
	hips = loft(self, [
		Vector4(.628, .047, .051, .053), Vector4(.674, .137, .079, .078),
		Vector4(.720, .180, .097, .089), Vector4(.775, .176, .094, .086),
		Vector4(.844, .161, .087, .077), Vector4(.862, .009, .009, .012)], shorts, 40)
	hips.position.z = -.015
	torso = joint(self, Vector3(0, .784, 0), "Torso")
	loft(torso, [
		Vector4(.000, .157, .085, .102), Vector4(.012, .172, .091, .112),
		Vector4(.056, .176, .092, .116), Vector4(.120, .181, .096, .129),
		Vector4(.188, .184, .093, .136), Vector4(.252, .184, .094, .130),
		Vector4(.320, .194, .092, .119), Vector4(.393, .206, .089, .115),
		Vector4(.462, .204, .087, .100), Vector4(.523, .174, .083, .090),
		Vector4(.552, .124, .078, .079), Vector4(.569, .076, .063, .066)], shirt, 48, .0018)
	loft(torso, [
		Vector4(.551, .092, .070, .077), Vector4(.569, .079, .065, .070),
		Vector4(.575, .072, .061, .064)], collar, 48)
	head = joint(torso, Vector3(0, .601, .026), "Head")
	head.scale = Vector3(1.10, 1.10, 1.035)
	build_head(arm_skin)
	for side: float in [-1.0, 1.0]:
		build_arm(side, shirt, collar, arm_skin)
	if with_props:
		build_wrench(wrists[0])
		build_beer(wrists[1])


func build_leg(side: float, shorts: Material, skin: Material) -> void:
	var leg := joint(self, Vector3(side * .097, 0, side * .022), "Leg")
	legs.append(leg)
	leg.rotation.y = side * .12
	var foot := Kit.mesh_at(leg, preload("res://deep_river/rich/bare_leg.res"), Vector3.ZERO, skin)
	foot.name = "BareLeg"
	foot.scale.x = side
	shorts_legs.append(loft(leg, [
		Vector4(.463, .077, .073, .083), Vector4(.477, .080, .076, .085),
		Vector4(.509, .080, .077, .086), Vector4(.569, .089, .083, .090),
		Vector4(.633, .089, .089, .094), Vector4(.713, .096, .095, .099),
		Vector4(.798, .087, .086, .090)], shorts, 40, .003))

func build_arm(side: float, shirt: Material, cuff: Material, skin: StandardMaterial3D) -> void:
	var upper := joint(torso, Vector3(side * .159, .475, .001), "Shoulder")
	loft(upper, [
		Vector4(-.211, .078, .078, .081), Vector4(-.192, .080, .080, .084),
		Vector4(-.142, .081, .083, .084), Vector4(-.078, .088, .085, .089),
		Vector4(-.024, .086, .086, .093), Vector4(.020, .076, .083, .084),
		Vector4(.052, .053, .066, .066), Vector4(.063, .032, .047, .051)], shirt, 36, .001)
	loft(upper, [
		Vector4(-.215, .075, .077, .080), Vector4(-.206, .078, .079, .083),
		Vector4(-.197, .078, .079, .083)], cuff, 36)
	var arm := ShaderMaterial.new()
	arm.shader = preload("res://rich_arm.gdshader")
	arm.set_shader_parameter("skin", skin.albedo_color)
	loft(upper, [
		Vector4(-.520, .026, .023, .025), Vector4(-.467, .031, .033, .034),
		Vector4(-.422, .036, .039, .041), Vector4(-.368, .046, .048, .047),
		Vector4(-.326, .049, .050, .050), Vector4(-.302, .048, .050, .050),
		Vector4(-.280, .047, .051, .051), Vector4(-.258, .052, .054, .055),
		Vector4(-.227, .055, .058, .059), Vector4(-.197, .060, .062, .064),
		Vector4(-.174, .060, .062, .064)], arm, 32)
	arm_surfaces.append(arm)
	var elbow := joint(upper, Vector3(0, -.277, 0), "Elbow")
	var hand := joint(elbow, Vector3(0, -.210, .004), "Hand")
	var hand_mesh := preload("res://deep_river/rich/grip.res") if side < 0.0 else preload("res://deep_river/rich/gesture.res")
	Kit.mesh_at(hand, hand_mesh, Vector3.ZERO, skin).name = "Palm"
	upper_arms.append(upper)
	elbows.append(elbow)
	wrists.append(hand)
	if side > 0.0:
		idle_phone = Kit.box_at(hand, Vector3(.014, -.095, .047), Vector3(.067, .122, .012), Kit.paint(Color("#24333e"), .48))
		idle_phone.hide()


func build_beer(wrist: Node3D) -> void:
	var can := joint(wrist, Vector3(-.035, -.073, .046), "BeerCan")
	can.rotation.z = .20
	var body := CylinderMesh.new()
	body.top_radius = .032
	body.bottom_radius = .032
	body.height = .110
	Kit.mesh_at(can, body, Vector3.ZERO, Kit.paint(Color("#287349"), .45))
	var aluminum := Kit.paint(Color("#b9bfc0"), .32, .65)
	for end: float in [-1.0, 1.0]:
		var rim := CylinderMesh.new()
		rim.top_radius = .0325
		rim.bottom_radius = .0325
		rim.height = .005
		Kit.mesh_at(can, rim, Vector3.UP * end * .055, aluminum)
	var badge := Label3D.new()
	badge.text = "BEER"
	badge.font_size = 32
	badge.pixel_size = .00042
	badge.position = Vector3(0, 0, .033)
	can.add_child(badge)


func build_wrench(wrist: Node3D) -> void:
	var steel := Kit.paint(Color("#797e79"), .35, .58)
	var tool := joint(wrist, Vector3(.006, -.060, .025), "BoxEndWrench")
	tool.rotation = Vector3(.35, -.34, -.76)
	var handle := Tools.shell(tool, Vector3(0, -.064, 0), Vector3(.019, .160, .010), steel)
	handle.rotation.z = -.018
	for y: float in [-.145, .015]:
		var ring := TorusMesh.new()
		ring.inner_radius = .0085
		ring.outer_radius = .017
		ring.rings = 13
		ring.ring_segments = 7
		var end := Kit.mesh_at(tool, ring, Vector3.ZERO + Vector3.UP * y, steel)
		end.rotation.x = PI / 2.0


func build_head(skin: Material) -> void:
	var photo := Image.load_from_file(BASE + "rich_face.png")
	photo.generate_mipmaps()
	face = ShaderMaterial.new()
	face.shader = preload("res://rich_skin.gdshader")
	face.set_shader_parameter("portrait", ImageTexture.create_from_image(photo))
	face.set_shader_parameter("skin_tone", skin.albedo_color)
	# Keep the collar end in torso space so the skin can bend into the head.
	var skin_mesh := loft(torso, [
		Vector4(-.066, .065, .064, .068), Vector4(-.051, .062, .061, .065),
		Vector4(-.037, .058, .061, .061), Vector4(-.022, .054, .059, .056),
		Vector4(-.009, .052, .059, .054), Vector4(.004, .053, .061, .055),
		Vector4(.018, .054, .063, .065), Vector4(.032, .056, .063, .073),
		Vector4(.046, .060, .060, .075), Vector4(.059, .065, .067, .075),
		Vector4(.072, .067, .073, .075), Vector4(.083, .070, .077, .075),
		Vector4(.093, .071, .080, .076), Vector4(.105, .073, .084, .075),
		Vector4(.115, .075, .086, .074), Vector4(.125, .076, .087, .073),
		Vector4(.136, .076, .088, .074), Vector4(.148, .075, .090, .077),
		Vector4(.159, .073, .089, .077), Vector4(.175, .070, .087, .076),
		Vector4(.192, .066, .080, .074), Vector4(.210, .055, .068, .064),
		Vector4(.225, .042, .052, .046), Vector4(.236, .020, .028, .027),
		Vector4(HEAD_HEIGHT, .002, .003, .004)], face, 60, 0.0, true)
	skin_mesh.position = head.position
	skin_mesh.scale = head.scale
	var ear_inside := Kit.paint(Color("#9b6656"), .85)
	for side: float in [-1.0, 1.0]:
		var at := Vector3(side * .076, .111, -.004)
		Tools.shell(head, at, Vector3(.024, .062, .040), skin).rotation.z = -.20 * side
		Tools.shell(head, at + Vector3(side * .006, .001, .014), Vector3(.009, .036, .012), ear_inside)
		Tools.shell(head, at + Vector3(side * .004, -.015, .011), Vector3(.017, .015, .015), skin)
	build_glasses()
	build_cap()


func build_glasses() -> void:
	var frames := Kit.paint(Color("#181a1b"), .40, .18)
	var tint := Kit.paint(Color("#253133"), .21, .52)
	tint.clearcoat_enabled = true
	tint.clearcoat = .48
	tint.clearcoat_roughness = .22
	var outline := PackedVector2Array([Vector2(.008, .149), Vector2(.026, .157), Vector2(.054, .157),
		Vector2(.072, .153), Vector2(.085, .144), Vector2(.080, .130), Vector2(.071, .119),
		Vector2(.053, .114), Vector2(.031, .115), Vector2(.016, .122), Vector2(.008, .133)])
	for side: float in [-1.0, 1.0]:
		glasses_lens(outline, side, 1.05, 0.0, frames)
		glasses_lens(outline, side, .87, .0022, tint)
		Tools.tube(head, Vector3(side * .083, .144, .052), Vector3(side * .085, .143, -.024), .0058, .0035, frames)
		Tools.tube(head, Vector3(side * .085, .143, -.024), Vector3(side * .080, .130, -.048), .0035, .0025, frames)
	Tools.tube(head, Vector3(-.014, .147, .116), Vector3(.014, .147, .116), .0045, .0045, frames)


func glasses_lens(outline: PackedVector2Array, side: float, scale_xy: float, depth: float, paint: Material) -> void:
	var center := Vector2(.045, .138)
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in outline.size():
		var a := outline[i]
		var b := outline[(i + 1) % outline.size()]
		for point: Vector2 in [center, a, b] if side > 0.0 else [center, b, a]:
			var p := center + (point - center) * scale_xy
			var z := .119 - .063 * pow(absf(p.x) / .089, 1.8) + depth
			mesh.set_normal(Vector3(side * p.x * 7.6, .11, 1).normalized())
			mesh.add_vertex(Vector3(side * p.x, p.y, z))
	Kit.mesh_at(head, mesh.commit(), Vector3.ZERO, paint)


func build_cap() -> void:
	var khaki := fabric(Color("#a49058"), .30)
	var underside := Kit.paint(Color("#222322"), .90)
	loft(head, [
		Vector4(.171, .078, .079, .091), Vector4(.179, .082, .083, .097),
		Vector4(.195, .082, .085, .098), Vector4(.219, .076, .081, .090),
		Vector4(.237, .063, .064, .071), Vector4(.250, .038, .041, .049),
		Vector4(.255, .006, .008, .011)], khaki, 48)
	Tools.shell(head, Vector3(0, .256, -.004), Vector3(.017, .007, .016), khaki)
	var seam := Kit.paint(Color("#766448"), .92)
	Tools.tube(head, Vector3(0, .249, .049), Vector3(0, .226, .083), .0019, .0019, seam)
	Tools.tube(head, Vector3(0, .226, .083), Vector3(0, .193, .099), .0019, .0019, seam)
	var brim := SurfaceTool.new()
	brim.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := SurfaceTool.new()
	edge.begin(Mesh.PRIMITIVE_TRIANGLES)
	for section in 28:
		var left := float(section) / 14.0 - 1.0
		var right := float(section + 1) / 14.0 - 1.0
		add_bill_strip(brim, bill_point(left, 0), bill_point(right, 0),
			bill_point(left, 1), bill_point(right, 1))
		var thickness := Vector3.DOWN * .006
		add_bill_strip(brim, bill_point(right, 0) + thickness, bill_point(left, 0) + thickness,
			bill_point(right, 1) + thickness, bill_point(left, 1) + thickness)
		add_bill_strip(edge, bill_point(left, 1), bill_point(right, 1),
			bill_point(left, 1) + thickness, bill_point(right, 1) + thickness)
	brim.generate_normals()
	underside.cull_mode = BaseMaterial3D.CULL_DISABLED
	var bill := Kit.mesh_at(head, brim.commit(), Vector3.ZERO, underside)
	bill.name = "ForwardCapBill"
	edge.generate_normals()
	var binding := Kit.paint(Color("#77664b"), .94)
	binding.cull_mode = BaseMaterial3D.CULL_DISABLED
	Kit.mesh_at(head, edge.commit(), Vector3.ZERO, binding)


static func bill_point(across: float, tip: float) -> Vector3:
	var arch := 1.0 - across * across
	return Vector3(across * (.072 + .018 * tip), .182 - .017 * across * across - .016 * tip,
		lerpf(.049 + .040 * arch, .073 + .139 * pow(arch, .56), tip))


static func add_bill_strip(mesh: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3) -> void:
	for vertex in [a, b, c, b, d, c]:
		mesh.add_vertex(vertex)

func pose(delta: float, clock: float, look_yaw: float, look_up: float, gesture: String,
		age: float, mouth: float, distance := 0.0, speed := 0.0, activity := "", task_age := 0.0,
		seated := false, idle_state := Vector3.ZERO) -> void:
	var idle := preload("res://character_idle.gd")
	var idle_weight := idle.weight(idle_state) * (1.0 - speed) if gesture.is_empty() and activity.is_empty() else 0.0
	idle_phone.visible = int(idle_state.x) == idle.PHONE and idle_weight > .62
	var weight := smoothstep(.12, .67, age)
	var settle := 1.0 - exp(-delta * 8.0)
	var rhythm := (.68 + .32 * sin(age * 4.4)) * weight
	pace = lerpf(pace, speed, settle)
	var stride := distance * TAU / .44
	var inspect_wrench := smoothstep(.1, .9, task_age) * (.68 + .32 * sin(task_age * 1.64)) if activity == "wrench" else 0.0
	var check_display := smoothstep(.15, 1.1, task_age) if activity == "sonar" else 0.0
	head_turn = lerp_angle(head_turn, clampf(look_yaw, -.87, .87), settle)
	torso.rotation = Vector3(.020 + cos(clock * 1.66) * .012, head_turn * .24, .017 + sin(clock * .79) * .018)
	torso.rotation.x += .13 * check_display + .069 * pace + (.047 if activity == "rail" else 0.0)
	torso.rotation.z += sin(stride) * pace * .024
	torso.rotation += idle.torso(idle_state, idle_weight)
	torso.position.y = .784 + (1.0 - cos(stride * 2.0)) * pace * .006
	hips.position.y = -.304 if seated else 0.0
	torso.position.y += hips.position.y
	head.rotation.y = head_turn * .76
	head.rotation.x = lerpf(head.rotation.x, clampf(-look_up, -.24, .23) + mouth * .053 - inspect_wrench * .20, settle)
	head.rotation.z = .027 + sin(clock * 1.2) * .024 - mouth * .031
	var idle_head: Vector3 = idle.head(idle_state, idle_weight)
	head.rotation.x += idle_head.x * settle
	head.rotation.y += idle_head.y
	head.rotation.z += idle_head.z
	jaw = lerpf(jaw, mouth, 1.0 - exp(-delta * 24.0))
	face.set_shader_parameter("jaw_open", jaw)
	var rest_scale := Basis.from_scale(head.scale)
	face.set_shader_parameter("pose_basis", rest_scale.inverse() * head.basis)
	for i in 2:
		var side := -1.0 if i == 0 else 1.0
		var phase := stride + i * PI
		var step := 1.0 - 2.0 * acos(cos(phase)) / PI
		legs[i].position = Vector3(side * .097, maxf(0.0, -sin(phase)) * .045 * pace,
			side * .022 + step * .109 * pace)
		legs[i].rotation.x = -sin(phase) * pace * .05
		var arm := Vector3(-.068, -side * .068, side * .119)
		arm.x += step * .14 * pace
		var bend := -.235 + .034 * cos(clock * 1.72 + side)
		var wrist := Vector3(.033, .07 * side, .063 * side)
		var idle_hand: Vector3 = idle.hand(idle_state, side, idle_weight)
		arm += Vector3(-idle_hand.y * 1.35, 0, idle_hand.x * 2.0)
		bend -= idle_hand.y * 1.85
		var trousers := shorts_legs[i]
		var shin: MeshInstance3D = legs[i].get_node("BareLeg")
		if seated:
			legs[i].position = Vector3(side * .115, .013, .339 + side * .031)
			legs[i].rotation.x = -.04
			trousers.position = Vector3(0, .432, .454)
			trousers.rotation.x = -PI * .5
			shin.scale.y = .90
			arm.x -= .11
			bend -= .95
		else:
			trousers.position = Vector3.ZERO
			trousers.rotation.x = 0.0
			shin.scale.y = 1.0
		if i == 0:
			arm.x -= inspect_wrench * .32
			bend -= inspect_wrench * .86
			wrist.y += inspect_wrench * sin(clock * 2.4) * .34
		if i == 1 and check_display > 0.0:
			arm.x -= .64 * check_display
			bend -= (.49 + .13 * sin(task_age * 3.7)) * check_display
		if i == 1 and not gesture.is_empty():
			match gesture:
				"point":
					arm += Vector3(-.75, -.19, .30) * rhythm
					bend -= .57 * rhythm
				"greet":
					arm += Vector3(-.54, .14, .49) * weight
					bend -= 1.13 * weight
					wrist.z += sin(age * 5.4) * .14 * rhythm
				"measure":
					arm += Vector3(-.61, -.25, .17) * rhythm
					bend -= .70 * rhythm
				"shrug":
					arm += Vector3(-.17, -.33, .63) * rhythm
					bend -= 1.04 * rhythm
				_:
					arm += Vector3(-.35, -.17, .21) * rhythm
					bend -= 1.03 * rhythm
		upper_arms[i].rotation = upper_arms[i].rotation.lerp(arm, settle)
		elbows[i].rotation.x = lerpf(elbows[i].rotation.x, bend, settle)
		arm_surfaces[i].set_shader_parameter("elbow_angle", elbows[i].rotation.x)
		wrists[i].rotation = wrists[i].rotation.lerp(wrist, settle)


static func joint(parent: Node3D, at: Vector3, label: String) -> Node3D:
	var node := Node3D.new()
	node.name = label
	parent.add_child(node)
	node.position = at
	return node


static func fabric(color: Color, wear: float) -> ShaderMaterial:
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://rich_cloth.gdshader")
	paint.set_shader_parameter("pigment", color)
	paint.set_shader_parameter("workwear", wear)
	return paint


static func loft(parent: Node3D, rings: Array[Vector4], paint: Material, sides := 28,
		folds := 0.0, portrait := false) -> MeshInstance3D:
	if portrait:
		# More vertical samples let the nose, eye sockets and mouth shaping exist
		# in the mesh instead of depending entirely on the front portrait.
		var detailed: Array[Vector4] = []
		for row in rings.size() - 1:
			for sub in 3:
				detailed.append(rings[row].lerp(rings[row + 1], sub / 3.0))
		detailed.append(rings[-1])
		rings = detailed
	var shape := SurfaceTool.new()
	shape.begin(Mesh.PRIMITIVE_TRIANGLES)
	var vertices := PackedVector3Array()
	var texcoords := PackedVector2Array()
	var coverage := PackedFloat32Array()
	for row in rings.size():
		var ring := rings[row]
		var fraction := float(row) / (rings.size() - 1)
		for segment in sides + 1:
			var turn := PI + float(segment % sides) / sides * TAU
			var toward := cos(turn)
			var wrinkle := folds * (1.0 - .69 * smoothstep(.1, .88, fraction)) \
				* sin(turn * 5.0 + row * .91) * cos(turn * 9.0 - row * 1.33)
			var x := sin(turn) * (ring.y + wrinkle)
			var z := toward * ((ring.w if toward >= 0.0 else ring.z) + wrinkle)
			var uv := Vector2(float(segment) / sides, ring.x)
			if portrait:
				var y := ring.x
				var bridge := .014 * exp(-pow(x / .014, 2) - pow((y - .129) / .033, 2))
				var tip := .036 * exp(-pow(x / .020, 2) - pow((y - .103) / .012, 2))
				var cheeks := .010 * exp(-pow((absf(x) - .043) / .018, 2) - pow((y - .108) / .026, 2))
				var lip := .008 * exp(-pow(x / .038, 2) - pow((y - .073) / .021, 2))
				var sockets := -.004 * exp(-pow((absf(x) - .033) / .020, 2) - pow((y - .136) / .012, 2))
				var chin := .006 * exp(-pow(x / .032, 2) - pow((y - .041) / .017, 2))
				var mouth := -.0025 * exp(-pow(x / .029, 2) - pow((y - .075) / .003, 2))
				var nostrils := -.0025 * exp(-pow((absf(x) - .014) / .005, 2) - pow((y - .100) / .005, 2))
				z += (bridge + tip + cheeks + lip + sockets + chin + mouth + nostrils) * smoothstep(.07, .67, toward)
				z -= .024 * (1.0 - smoothstep(-.043, .058, y))
				uv = Vector2(.50 + x / .243, lerpf(.988, .014, clampf(y / HEAD_HEIGHT, 0.0, 1.0)))
			vertices.append(Vector3(x, ring.x, z))
			texcoords.append(uv)
			var face_weight := smoothstep(.06, .58, toward)
			if portrait:
				face_weight *= smoothstep(.004, .036, ring.x)
			coverage.append(face_weight)
	var stride := sides + 1
	for row in rings.size():
		for segment in stride:
			var index := row * stride + segment
			var around := vertices[row * stride + (segment + 1) % sides] \
				- vertices[row * stride + posmod(segment - 1, sides)]
			var vertical := vertices[mini(row + 1, rings.size() - 1) * stride + segment] \
				- vertices[maxi(row - 1, 0) * stride + segment]
			shape.set_normal(around.cross(vertical).normalized())
			shape.set_color(Color(coverage[index], 0, 0))
			shape.set_uv(texcoords[index])
			shape.set_uv2(Vector2(0, float(row) / (rings.size() - 1)))
			shape.add_vertex(vertices[index])
	for row in rings.size() - 1:
		for segment in sides:
			var a := row * stride + segment
			var b := a + stride
			for index in [a, b, a + 1, a + 1, b, b + 1]:
				shape.add_index(index)
	return Kit.mesh_at(parent, shape.commit(), Vector3.ZERO, paint)
