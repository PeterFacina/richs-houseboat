extends Node3D

const Kit = preload("res://scenery.gd")
const Avatar = preload("res://crew_avatar.gd")
const Pines = preload("res://lamure_pines.gd")
const Gravel = preload("res://regional_gravel.gdshader")
# Right-hand turn off the westernmost baked stretch of Highway 17, toward Mackey.
const TURN := Vector2(15076.695, 12089.987)
const INLAND := Vector2(.5166, -.8562)
const DRIVE := [[TURN.x, TURN.y], [15080.8, 12083.1], [15085.0, 12076.3], [15088.1, 12071.1]]
const SELLER := "Cal"

var river: Node3D
var seller_point: Vector3
var parking: Vector3
var rack: Node3D


static func clears_tree(at: Vector2) -> bool:
	var local := at - TURN
	return absf(local.dot(INLAND.orthogonal())) < 20.0 and local.dot(INLAND) > 5.0 and local.dot(INLAND) < 44.0


func setup(map: Node3D) -> void:
	river = map
	name = "PontoonWorkshop"
	position = Vector3(TURN.x, 0, TURN.y)
	rotation.y = atan2(INLAND.x, INLAND.y)
	build_gravel()
	var building := StaticBody3D.new()
	add_child(building)
	building.position = land(Vector2(0, 32))
	build_garage(building)
	plant_windbreak()

	var seller := Avatar.new()
	add_child(seller)
	seller.position = land(Vector2(5.1, 22.8))
	seller.setup(SELLER, 1)
	seller.update_limbs({}, null, 0, 0.0)
	seller.label.visibility_range_end = 28.0
	seller_point = to_global(seller.position + Vector3.UP * 1.42)
	parking = to_global(land(Vector2(0, 22)))

	rack = Node3D.new()
	add_child(rack)
	rack.position = land(Vector2(8.0, 26.5))
	var timber := Kit.paint(Color("#887355"))
	var alloy := Kit.paint(Color("#a9adaa"), .64, .22)
	for z: float in [-.85, .85]:
		Kit.box_at(rack, Vector3(0, .12, z), Vector3(1.42, .24, .25), timber)
	for side: float in [-.37, .37]:
		float_tube(rack, Vector3(side, .48, 0), .24, 2.7, alloy)


func plant_windbreak() -> void:
	var pines := Pines.new()
	var random := RandomNumberGenerator.new()
	random.seed = 108
	for spot: Vector2 in [Vector2(-16, 26), Vector2(-18, 34), Vector2(-14, 43), Vector2(-9, 49),
			Vector2(-3, 42), Vector2(2, 48), Vector2(7, 42), Vector2(12, 51),
			Vector2(16, 38), Vector2(21, 43), Vector2(18, 28), Vector2(22, 33)]:
		pines.plant(land(spot), random.randf_range(6.5, 13.0), random)
	pines.build(self)


func land(at: Vector2) -> Vector3:
	var world := to_global(Vector3(at.x, 0, at.y))
	return Vector3(at.x, river.ground_height(world.x, world.z), at.y)


func build_gravel() -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for z in range(5, 37):
		var width := lerpf(3.7, 12.0, smoothstep(10.0, 19.0, float(z)))
		var next_width := lerpf(3.7, 12.0, smoothstep(10.0, 19.0, float(z + 1)))
		for corner: Vector2i in [Vector2i(-1, 0), Vector2i(-1, 1), Vector2i(1, 0),
				Vector2i(1, 0), Vector2i(-1, 1), Vector2i(1, 1)]:
			var edge := width if corner.y == 0 else next_width
			surface.set_uv(Vector2(corner.x * 3.7, 0))
			surface.add_vertex(land(Vector2(corner.x * edge, z + corner.y)) + Vector3.UP * .085)
	surface.generate_normals()
	var material := ShaderMaterial.new()
	material.shader = Gravel
	material.set_shader_parameter("half_width", 3.7)
	material.set_shader_parameter("gravel_scan", river.GRAVEL_SCAN)
	material.set_shader_parameter("gravel_normal", river.GRAVEL_NORMAL)
	Kit.mesh_at(self, surface.commit(), Vector3.ZERO, material).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_garage(building: StaticBody3D) -> void:
	var steel := Kit.paint(Color("#73807b"), .92)
	var roof := Kit.paint(Color("#463c35"), .95)
	var door := Kit.paint(Color("#b5a48b"), .92)
	var trim := Kit.paint(Color("#514b40"))
	var rubber := Kit.paint(Color("#333430"))
	var rust := Kit.paint(Color("#865842"))
	Kit.box_at(building, Vector3(0, 1.58, 0), Vector3(9, 3.58, 6.8), steel)
	Kit.collider(building, Vector3(0, 1.58, 0), Vector3(9, 3.58, 6.8))
	Kit.box_at(building, Vector3(0, .13, 0), Vector3(9.06, .31, 6.86), Kit.paint(Color("#6e695f")))
	var seam := Kit.paint(Color("#67736e"), .93)
	for side: float in [-1.0, 1.0]:
		for rib in range(1, 17):
			Kit.box_at(building, Vector3(side * 4.51, 1.81, -3.4 + .4 * rib),
				Vector3(.029, 3.10, .038), seam)
	for side: float in [-1.0, 1.0]:
		var slope := Kit.box_at(building, Vector3(side * 2.34, 3.53, 0), Vector3(4.86, .13, 7.26), roof)
		slope.rotation.z = -side * .09
		Kit.box_at(building, Vector3(side * 4.46, 1.55, -3.44), Vector3(.13, 3.6, .14), trim)
	for panel in 10:
		Kit.box_at(building, Vector3(-.87, .23 + panel * .259, -3.432), Vector3(3.92, .247, .075), door)
	Kit.box_at(building, Vector3(2.89, 1.03, -3.44), Vector3(.98, 2.13, .095), trim)
	Kit.box_at(building, Vector3(2.89, 1.58, -3.50), Vector3(.60, .52, .025), Kit.paint(Color("#667d80")))
	var sign := Label3D.new()
	sign.text = "CAL'S MARINE REPAIR"
	sign.font_size = 52
	sign.pixel_size = .007
	sign.outline_size = 4
	sign.visibility_range_end = 150.0
	building.add_child(sign)
	sign.position = Vector3(-.87, 2.99, -3.49)
	sign.rotation.y = PI
	var scrap := Node3D.new()
	add_child(scrap)
	scrap.position = land(Vector2(-7.6, 29))
	Kit.box_at(scrap, Vector3(0, .26, 0), Vector3(2.05, .15, 1.45), rust)
	Kit.beam(scrap, Vector3(0, .30, .71), Vector3(0, .25, 2.05), .11, rust)
	for side: float in [-1.0, 1.0]:
		var wheel := CylinderMesh.new()
		wheel.top_radius = .32
		wheel.bottom_radius = .32
		wheel.height = .16
		wheel.radial_segments = 12
		Kit.mesh_at(scrap, wheel, Vector3(side * 1.08, .31, 0), rubber).rotation.z = PI * .5
	Kit.box_at(scrap, Vector3(.46, .67, -.07), Vector3(.55, .68, .45), trim).rotation.z = -.22
	Kit.beam(scrap, Vector3(.51, .57, -.08), Vector3(.56, .20, -.62), .10, rust)
	for tire_index in 3:
		var spare := TorusMesh.new()
		spare.inner_radius = .22
		spare.outer_radius = .34
		spare.rings = 12
		spare.ring_segments = 8
		Kit.mesh_at(scrap, spare, Vector3(1.7, .11 + tire_index * .15, -.45 + .06 * tire_index), rubber)


static func float_tube(parent: Node3D, at: Vector3, radius: float, length: float, alloy: Material) -> void:
	var tube := CylinderMesh.new()
	tube.top_radius = radius
	tube.bottom_radius = radius
	tube.height = length - .38
	tube.radial_segments = 12
	Kit.mesh_at(parent, tube, at, alloy).rotation.x = PI * .5
	for end: float in [-1.0, 1.0]:
		var cap := CylinderMesh.new()
		cap.top_radius = radius * .40
		cap.bottom_radius = radius
		cap.height = .19
		cap.radial_segments = 12
		Kit.mesh_at(parent, cap, at + Vector3.BACK * end * (length * .5 - .095), alloy).rotation.x = end * PI * .5
