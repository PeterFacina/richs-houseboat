extends RefCounted

const Kit = preload("res://scenery.gd")
const Beach = preload("res://lamure_beach.gd")
const TennisMatch = preload("res://marina_tennis_match.gd")
const COURT_COUNT := 6
const COURT_PITCH := 12.5
const COATING_LIFT := .085
const FENCE_HEIGHT := 2.72
const GATE_WIDTH := 1.68
const NET_HALF_SPAN := 5.98

var site: Node3D
var ground: Callable
var fence := SurfaceTool.new()
var steel_parts: Array[Transform3D] = []
var corner_posts: Array[Vector2] = []
var steel := Kit.paint(Color("#4e5b50"), .66, .24)
var net_post := Kit.paint(Color("#334039"), .73, .16)


func build(parent: Node3D, footprint: Array, trail: Array, height: Callable,
		aggregate: Texture2D, timber: Material) -> void:
	ground = height
	var corners := PackedVector2Array()
	var center := Vector2.ZERO
	for pair: Array in footprint:
		var point := Vector2(pair[0], pair[1])
		corners.append(point)
		center += point * .25
	var across := (corners[1] - corners[0] + corners[2] - corners[3]).normalized()
	var depth := Vector2(-across.y, across.x)
	site = Node3D.new()
	site.name = "YachtClubTennisCourts"
	parent.add_child(site)
	site.position = Vector3(center.x, ground.call(center.x, center.y), center.y)
	site.basis = Basis(horizontal(across), Vector3.UP, horizontal(depth))
	for index in corners.size():
		corners[index] = local_point(corners[index])

	build_pad(corners, aggregate)
	build_enclosure(corners, trail, aggregate, timber)
	build_nets()
	for direction: float in [-1.0, 1.0]:
		var start := corners[0] if direction < 0.0 else corners[3]
		var finish := corners[1] if direction < 0.0 else corners[2]
		for offset: float in [-25.0, 0.0, 25.0]:
			var edge := start.lerp(finish, inverse_lerp(start.x, finish.x, offset))
			build_light(floor_at(edge + Vector2(0, direction * .65)), Vector3.FORWARD * direction)
	for offset: float in [-25.0, 0.0, 25.0]:
		build_light(floor_at(Vector2(offset, 0)), Vector3.RIGHT, true)


func build_pad(corners: PackedVector2Array, aggregate: Texture2D) -> void:
	var material := ShaderMaterial.new()
	material.shader = preload("res://marina_court_surface.gdshader")
	material.set_shader_parameter("aggregate", aggregate)
	material.set_shader_parameter("court_pitch", COURT_PITCH)
	material.set_shader_parameter("court_count", COURT_COUNT)
	var deck := SurfaceTool.new()
	deck.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := ceili(corners[0].distance_to(corners[1]) / .8)
	var rows := ceili(corners[0].distance_to(corners[3]) / .8)
	for row in range(rows + 1):
		var v := float(row) / rows
		var left := corners[0].lerp(corners[3], v)
		var right := corners[1].lerp(corners[2], v)
		for col in range(columns + 1):
			var point := left.lerp(right, float(col) / columns)
			deck.set_normal(Vector3.UP)
			deck.set_uv(point)
			deck.add_vertex(floor_at(point))
	for row in rows:
		for col in columns:
			var a := row * (columns + 1) + col
			var c := a + columns + 1
			for index: int in [a, a + 1, c, a + 1, c + 1, c]:
				deck.add_index(index)
	var pad := Kit.mesh_at(site, deck.commit(), Vector3.ZERO, material)
	pad.name = "CourtCoating"
	pad.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	pad.create_trimesh_collision()


func build_enclosure(corners: PackedVector2Array, trail: Array, aggregate: Texture2D, timber: Material) -> void:
	fence.begin(Mesh.PRIMITIVE_TRIANGLES)
	var edge := (corners[2] - corners[1]).normalized()
	var inward := Vector2(-edge.y, edge.x)
	var gate := corners[1].lerp(corners[2], .47)
	var hinge := gate - edge * GATE_WIDTH * .5
	var latch := gate + edge * GATE_WIDTH * .5
	for index in [0, 2, 3]:
		build_fence_run(corners[index], corners[(index + 1) % 4])
	build_fence_run(corners[1], hinge)
	build_fence_run(latch, corners[2])
	# Fold the leaf back along the fence so players can also approach from inside.
	var opening := hinge + (-edge * .98 + inward * .20) * (GATE_WIDTH - .10)
	var leaf_bottom := floor_at(hinge) + Vector3.UP * .11
	var free_end := leaf_bottom + horizontal(opening - hinge)
	var leaf_top := FENCE_HEIGHT - .29
	add_fence_panel(leaf_bottom, free_end, leaf_top)
	add_steel(leaf_bottom, free_end, .047)
	add_steel(leaf_bottom + Vector3.UP * leaf_top, free_end + Vector3.UP * leaf_top, .047)
	add_steel(free_end, free_end + Vector3.UP * leaf_top, .047)
	add_steel(leaf_bottom + Vector3.UP * 1.01, free_end + Vector3.UP * 1.01, .034)
	add_barrier("OpenGateLeaf", leaf_bottom, free_end, leaf_top)
	var screen := mesh_material(Color("#56675d"), .077, .0030, true)
	Kit.mesh_at(site, fence.commit(), Vector3.ZERO, screen).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	Kit.new().scatter(site, BoxMesh.new(), steel_parts, steel)
	build_entry_furniture(gate, edge, inward, timber)
	if trail.size() >= 2:
		build_approach(gate, inward, trail, aggregate)


func build_fence_run(start: Vector2, finish: Vector2) -> void:
	var bays := ceili(start.distance_to(finish) / 3.15)
	for index in range(bays + 1):
		var point := start.lerp(finish, float(index) / bays)
		var foot := floor_at(point)
		if not corner_posts.has(point):
			corner_posts.append(point)
			add_steel(foot - Vector3.UP * .12, foot + Vector3.UP * (FENCE_HEIGHT + .045), .065)
		if index < bays:
			var next := floor_at(start.lerp(finish, float(index + 1) / bays))
			add_fence_panel(foot + Vector3.UP * .065, next + Vector3.UP * .065, FENCE_HEIGHT - .065)
			add_steel(foot + Vector3.UP * FENCE_HEIGHT, next + Vector3.UP * FENCE_HEIGHT, .043)
			add_steel(foot + Vector3.UP * .075, next + Vector3.UP * .075, .023)
			add_barrier("PerimeterPanel", foot, next, FENCE_HEIGHT)


func add_fence_panel(a: Vector3, b: Vector3, height: float) -> void:
	var length := a.distance_to(b)
	add_screen_quad(fence, a, b, a + Vector3.UP * height, b + Vector3.UP * height, 0.0, length, height)


func add_steel(a: Vector3, b: Vector3, width: float) -> void:
	var up := Vector3.RIGHT if absf((b - a).normalized().y) > .95 else Vector3.UP
	var axes := Basis.looking_at(b - a, up).scaled_local(Vector3(width, width, a.distance_to(b)))
	steel_parts.append(Transform3D(axes, (a + b) * .5))


func add_barrier(label: String, a: Vector3, b: Vector3, height: float) -> void:
	var body := StaticBody3D.new()
	body.name = label
	site.add_child(body)
	var difference := b - a
	body.position = (a + b) * .5 + Vector3.UP * height * .5
	body.basis = Basis.looking_at(Vector3(difference.x, 0, difference.z))
	Kit.collider(body, Vector3.ZERO, Vector3(.08, height + absf(difference.y), Vector2(difference.x, difference.z).length()))


func build_entry_furniture(gate: Vector2, edge: Vector2, inward: Vector2, timber: Material) -> void:
	var facing := Basis.looking_at(horizontal(inward))
	for distance: float in [-5.1, 5.1]:
		var position := floor_at(gate + edge * distance - inward * 1.52)
		var bench := Beach.build_bench(site, position - Vector3.UP * COATING_LIFT, timber)
		bench.name = "CourtsideBench"
		bench.basis = facing
		var body := StaticBody3D.new()
		bench.add_child(body)
		Kit.collider(body, Vector3(0, .48, 0), Vector3(1.89, .95, .53))
	var plaque := Kit.box_at(site, floor_at(gate + edge * 1.95 - inward * .034) + Vector3.UP * 1.63,
		Vector3(1.72, .43, .046), Kit.paint(Color("#3c4a3f")))
	plaque.basis = facing
	var label := Label3D.new()
	label.text = "DEEP RIVER\nYACHT & TENNIS CLUB"
	label.font_size = 35
	label.pixel_size = .0034
	label.outline_size = 0
	label.modulate = Color("#eae7d7")
	label.shaded = true
	plaque.add_child(label)
	label.position.z = .026


func build_approach(gate: Vector2, inward: Vector2, trail: Array, aggregate: Texture2D) -> void:
	var mouth := gate - inward * 1.5
	var finish := Vector2.INF
	var nearest := INF
	for index in range(1, trail.size()):
		var a := local_point(Vector2(trail[index - 1][0], trail[index - 1][1]))
		var b := local_point(Vector2(trail[index][0], trail[index][1]))
		var point := Geometry2D.get_closest_point_to_segment(mouth, a, b)
		if point.distance_squared_to(mouth) < nearest:
			finish = point
			nearest = point.distance_squared_to(mouth)
	var route := Curve2D.new()
	route.bake_interval = .28
	route.add_point(gate, Vector2.ZERO, -inward * 2.2)
	route.add_point(finish, (mouth - finish) * .27)
	var points := route.get_baked_points()
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 8
	for index in points.size():
		var delta := points[mini(index + 1, points.size() - 1)] - points[maxi(0, index - 1)]
		var side := Vector2(delta.y, -delta.x).normalized()
		var width := lerpf(GATE_WIDTH * .5, 1.00, smoothstep(0.0, 4.0, points[index].distance_to(gate)))
		for column in range(columns + 1):
			var offset := lerpf(-width, width, float(column) / columns)
			surface.set_normal(Vector3.UP)
			surface.add_vertex(floor_at(points[index] + side * offset))
	for row in points.size() - 1:
		for column in columns:
			var a := row * (columns + 1) + column
			var c := a + columns + 1
			for index: int in [a, a + 1, c, a + 1, c + 1, c]:
				surface.add_index(index)
	var gravel := Kit.paint(Color("#ded3bc"), .98)
	gravel.albedo_texture = aggregate
	gravel.uv1_triplanar = true
	gravel.uv1_scale = Vector3.ONE * 1.16
	gravel.cull_mode = BaseMaterial3D.CULL_DISABLED
	var approach := Kit.mesh_at(site, surface.commit(), Vector3.ZERO, gravel)
	approach.name = "MarinaPathToTennisGate"
	approach.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func build_nets() -> void:
	var net := SurfaceTool.new()
	var band := SurfaceTool.new()
	for surface: SurfaceTool in [net, band]:
		surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var segments := 12
	for index in segments:
		var a := lerpf(-NET_HALF_SPAN, NET_HALF_SPAN, float(index) / segments)
		var b := lerpf(-NET_HALF_SPAN, NET_HALF_SPAN, float(index + 1) / segments)
		var left := Vector3(a, net_height(a), 0.0)
		var right := Vector3(b, net_height(b), 0.0)
		var tape := Vector3.UP * .061
		add_screen_quad(net, Vector3(a, .015, 0), Vector3(b, .015, 0), left - tape, right - tape, a, b, left.y)
		var lip := Vector3.BACK * .023
		add_screen_quad(band, left - tape - lip, right - tape - lip, left - lip, right - lip, a, b, .061)
		add_screen_quad(band, right - tape + lip, left - tape + lip, right + lip, left + lip, b, a, .061)
		add_screen_quad(band, left + lip, right + lip, left - lip, right - lip, a, b, .046)
	var net_mesh := net.commit()
	var top_band := band.commit()
	var strands := mesh_material(Color("#242c29"), .044, .0028, false)
	var tape_material := Kit.paint(Color("#e8e8dd"))
	tape_material.cull_mode = BaseMaterial3D.CULL_DISABLED
	for index in COURT_COUNT:
		var x := (index - (COURT_COUNT - 1) * .5) * COURT_PITCH
		var start := floor_at(Vector2(x - NET_HALF_SPAN, 0))
		var finish := floor_at(Vector2(x + NET_HALF_SPAN, 0))
		var frame := StaticBody3D.new()
		frame.name = "TennisNet%d" % (index + 1)
		site.add_child(frame)
		frame.position = start.lerp(finish, .5)
		Kit.collider(frame, Vector3(0, .435, 0), Vector3(NET_HALF_SPAN * 2.0, .87, .09))
		Kit.mesh_at(frame, net_mesh, Vector3.ZERO, strands).cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		Kit.mesh_at(frame, top_band, Vector3.ZERO, tape_material)
		for side: float in [-1.0, 1.0]:
			Kit.box_at(frame, Vector3(side * NET_HALF_SPAN, .50, 0), Vector3(.10, 1.19, .10), net_post)
		Kit.box_at(frame, Vector3(0, .426, 0), Vector3(.050, .852, .027), tape_material)
		if index == COURT_COUNT - 1:
			# The last court is nearest the marina approach and open gate.
			var tennis := TennisMatch.new()
			tennis.name = "MarinaTennisMatch"
			frame.add_child(tennis)
			tennis.build(ground, NET_HALF_SPAN, net_height)


static func net_height(x: float) -> float:
	return .915 + .153 * pow(x / NET_HALF_SPAN, 2.0)


func build_light(foot: Vector3, inward: Vector3, paired := false) -> void:
	foot.y -= COATING_LIFT
	var pole := CylinderMesh.new()
	pole.height = 6.6
	pole.top_radius = .042
	pole.bottom_radius = .083
	pole.radial_segments = 8
	var post_material := Kit.paint(Color("#71685a"), .88) if paired else steel
	Kit.mesh_at(site, pole, foot + Vector3.UP * 3.30, post_material)
	Kit.box_at(site, foot + Vector3.UP * .085, Vector3(.32, .23, .32), net_post)
	var body := StaticBody3D.new()
	body.name = "CourtLightPole"
	site.add_child(body)
	body.position = foot
	Kit.collider(body, Vector3.UP * 1.25, Vector3(.17, 2.6, .17))
	var lens := Kit.paint(Color("#cecec0"))
	for direction: Vector3 in ([inward, -inward] if paired else [inward]):
		var arm := foot + Vector3.UP * 6.51 + direction * .29
		var bracket := Kit.box_at(site, arm, Vector3(.093, .077, .68), steel)
		bracket.basis = Basis.looking_at(direction)
		var fixture := Kit.box_at(site, arm - Vector3.UP * .045 + direction * .37,
			Vector3(.42, .135, .35), net_post)
		fixture.basis = bracket.basis.rotated(bracket.basis.x, .22)
		Kit.box_at(fixture, Vector3(0, -.069, 0), Vector3(.34, .012, .26), lens)


func floor_at(point: Vector2) -> Vector3:
	var world := site.position + site.basis * horizontal(point)
	return Vector3(point.x, float(ground.call(world.x, world.z)) - site.position.y + COATING_LIFT, point.y)


func local_point(point: Vector2) -> Vector2:
	var offset := site.basis.inverse() * (horizontal(point) - site.position)
	return Vector2(offset.x, offset.z)


static func horizontal(point: Vector2) -> Vector3:
	return Vector3(point.x, 0, point.y)


static func mesh_material(color: Color, pitch: float, strand: float, diamond: bool) -> ShaderMaterial:
	var material := ShaderMaterial.new()
	material.shader = preload("res://marina_court_mesh.gdshader")
	material.set_shader_parameter("wire", color)
	material.set_shader_parameter("pitch", pitch)
	material.set_shader_parameter("strand", strand)
	material.set_shader_parameter("diamond", diamond)
	return material


static func add_screen_quad(surface: SurfaceTool, a: Vector3, b: Vector3, c: Vector3, d: Vector3,
		start: float, finish: float, height: float) -> void:
	var normal := (b - a).cross(c - a).normalized()
	var corners := [a, b, c, d]
	var uvs := [Vector2(start, 0), Vector2(finish, 0), Vector2(start, height), Vector2(finish, height)]
	for index: int in [0, 2, 1, 2, 3, 1]:
		surface.set_normal(normal)
		surface.set_uv(uvs[index])
		surface.add_vertex(corners[index])
