extends RefCounted

const Kit = preload("res://scenery.gd")
const Graphics = preload("res://river_graphics.gd")
const BEACH_CENTER := Vector2(18622, 13189)
const COAST := Vector2(.932, -.362)
const HEIGHTS := [.46, .59, .72, .83, .92]
const SPREADS := [.26, .22, .182, .127, .078]

class Grove:
	var stems: Array[Transform3D] = []
	var branches: Array[Transform3D] = []
	var crowns: Array[Transform3D] = []

var groves := {}


func place_from_survey(foot: Vector3, height: float) -> bool:
	var offset := Vector2(foot.x, foot.z) - BEACH_CENTER
	var inland := offset.dot(Vector2(-COAST.y, COAST.x))
	if absf(offset.dot(COAST)) > 118.0 or inland < 9.0 or inland > 68.0 or height < 8.5:
		return false
	var random := RandomNumberGenerator.new()
	random.seed = hash(Vector2i(roundi(foot.x * 4.0), roundi(foot.z * 4.0)))
	if inland > 28.0 and random.randf() > .51:
		return false
	plant(foot, height, random)
	return true


func plant(foot: Vector3, height: float, random: RandomNumberGenerator) -> void:
	var cell := Vector2i(floori(foot.x / 155.0), floori(foot.z / 155.0))
	if not groves.has(cell):
		groves[cell] = Grove.new()
	var grove: Grove = groves[cell]
	var turn := random.randf_range(0, TAU)
	var trunk_width := height * random.randf_range(.026, .037)
	var lean := Vector3(cos(turn), 0.0, sin(turn)) * random.randf_range(.003, .025)
	var stem := Vector3.UP + lean
	grove.stems.append(taper(foot - stem * .16, foot + stem * height * .99, trunk_width))
	for tier in HEIGHTS.size():
		var count := 4 if tier < 3 else 3
		for branch in count:
			var azimuth := turn + TAU * float(branch) / count + tier * 1.32 + random.randf_range(-.29, .29)
			var reach := height * float(SPREADS[tier]) * random.randf_range(.73, 1.18)
			var y := height * (float(HEIGHTS[tier]) + random.randf_range(-.036, .033))
			var start := foot + stem * y
			var branch_basis := Basis(Vector3.UP, azimuth) * Basis(Vector3.BACK, random.randf_range(-.13, .24))
			grove.branches.append(taper(start, start + branch_basis.x * reach * .90, trunk_width * float(SPREADS[tier])))
			var needle_basis := branch_basis.rotated(branch_basis.x, random.randf_range(-.40, .40))
			var tuft := Vector3(reach * 1.03, reach * .52, reach * .74)
			grove.crowns.append(Transform3D(needle_basis.scaled_local(tuft), start + branch_basis.x * reach * .32))
			var fork := needle_basis.rotated(Vector3.UP, random.randf_range(-.66, .68))
			grove.crowns.append(Transform3D(fork.scaled_local(tuft * .69), start + branch_basis.x * reach * .66))
	var leader := Basis(Vector3.BACK, 1.38) * Basis(Vector3.RIGHT, turn)
	var tip := Vector3(height * .135, height * .072, height * .070)
	grove.crowns.append(Transform3D(leader.scaled_local(tip), foot + stem * height * .865))


func build(parent: Node3D) -> void:
	if groves.is_empty():
		return
	var wood := CylinderMesh.new()
	wood.top_radius = .065
	wood.bottom_radius = .50
	wood.height = 1.0
	wood.radial_segments = 9
	var bark := Kit.paint(Color("#beb3a0"), .94)
	bark.albedo_texture = load_texture("pine-bark.jpg")
	bark.uv1_scale = Vector3(1, 9, 1)
	var limb := bark.duplicate() as StandardMaterial3D
	limb.uv1_scale = Vector3(1, 2, 1)
	var foliage := ShaderMaterial.new()
	foliage.shader = preload("res://river_canopy.gdshader")
	foliage.set_shader_parameter("leaves", load_texture("pine-needles.png"))
	foliage.set_shader_parameter("foliage_exposure", 2.55)
	var cards := branch_cards()
	var silhouette := pine_silhouette()
	var kit := Kit.new()
	for grove: Grove in groves.values():
		var stems := kit.scatter(parent, wood, grove.stems, bark)
		var branches := kit.scatter(parent, wood, grove.branches, limb)
		var crowns := kit.scatter(parent, cards, grove.crowns, foliage)
		var silhouettes: Array[Transform3D] = []
		for trunk: Transform3D in grove.stems:
			var height := trunk.basis.y.length()
			var angle := fmod(trunk.origin.x * .43 + trunk.origin.z * .21, TAU)
			var shape := Basis(Vector3.UP, angle).scaled(Vector3.ONE * height)
			silhouettes.append(Transform3D(shape, trunk.origin - trunk.basis.y * .5))
		var distant := kit.scatter(parent, silhouette, silhouettes, foliage)
		var bounds := stems.get_aabb().merge(crowns.get_aabb()).merge(distant.get_aabb())
		for batch: MultiMeshInstance3D in [branches, crowns]:
			batch.custom_aabb = bounds
			Graphics.batch(batch, "tree_detail")
		stems.custom_aabb = bounds
		Graphics.batch(stems, "tree_stem")
		distant.custom_aabb = bounds
		distant.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Graphics.batch(distant, "tree_silhouette")


static func taper(start: Vector3, tip: Vector3, width: float) -> Transform3D:
	var axis := tip - start
	var basis := Basis(Quaternion(Vector3.UP, axis.normalized())).scaled_local(Vector3(width, axis.length(), width))
	return Transform3D(basis, start.lerp(tip, .50))


static func load_texture(name: String) -> ImageTexture:
	var image := Image.load_from_file("res://ottawa/materials/" + name)
	image.generate_mipmaps()
	return ImageTexture.create_from_image(image)


static func branch_cards() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	add_cards(surface, Transform3D.IDENTITY, [0.0, 1.07, -1.07])
	return surface.commit()


static func pine_silhouette() -> ArrayMesh:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for tier in HEIGHTS.size():
		var reach: float = SPREADS[tier]
		for branch in 3:
			var turn := TAU * branch / 3.0 + float(tier) * 1.23
			var basis := Basis(Vector3.UP, turn) * Basis(Vector3.BACK, .19)
			var position := Vector3.UP * float(HEIGHTS[tier]) + basis.x * reach * .09
			var shape := basis.scaled_local(Vector3(reach, reach * .59, reach * .70))
			add_cards(surface, Transform3D(shape, position), [.53, -1.08])
	return surface.commit()


static func add_cards(surface: SurfaceTool, placement: Transform3D, rolls: Array) -> void:
	for roll: float in rolls:
		var across := Vector3.BACK.rotated(Vector3.RIGHT, roll)
		for uv: Vector2 in [Vector2.DOWN, Vector2.ZERO, Vector2.ONE, Vector2.ONE, Vector2.ZERO, Vector2.RIGHT]:
			surface.set_normal((placement.basis * (Vector3.UP + Vector3.RIGHT * .36 + across * (uv.x - .5))).normalized())
			surface.set_uv(uv)
			surface.add_vertex(placement * (Vector3.RIGHT * (1.0 - uv.y) + across * (uv.x - .5)))
