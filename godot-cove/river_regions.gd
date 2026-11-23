extends Node3D

const Kit = preload("res://scenery.gd")
const Pines = preload("res://lamure_pines.gd")
const SECTION_SIZE := 18000.0
const NAMES := ["Entire river reach", "Deep River", "Swisha / Des Joachims", "Chalk River"]
var game: Node3D
var data: Dictionary
var region_label: Label
var helipad := Vector3.ZERO
var cemetery := Vector3.ZERO
var ski := Vector3.ZERO
var road_surfaces: Array[MeshInstance3D] = []
var elapsed := 0.0


func setup(scene: Node3D) -> void:
	game = scene
	name = "RegionalTravel"
	data = JSON.parse_string(FileAccess.get_file_as_string("res://ottawa/regional_access.json"))
	init_helipad()
	for points: Array in data.mcanulty_roads: road(points, 6.4, false)
	var outline: Array = data.cemetery
	var center := Vector2.ZERO
	for index in outline.size() - 1: center += Vector2(outline[index][0], outline[index][1])
	center /= maxi(1, outline.size() - 1)
	cemetery = ground(center)
	var at: Array = data.markers["Mount Martin Ski Club"]
	ski = ground(Vector2(at[0], at[1]))
	var park: Array = data.markers["Grouse Park"]
	var ski_trail := [[ski.x, ski.z], [ski.x - 80, ski.z + 140], park]
	road(ski_trail, 2.2, true)
	build_cemetery(outline)
	# A short gameplay access route from the regional landing to a dam lookout.
	var swisha: Vector3 = game.campaign.landings.sites[3].stand
	road([[swisha.x, swisha.z], [2580, 3790], [2580, 3450], [2470, 3360], [2270, 3380]], 6.4, false, true)
	clear_pad_trees()
	plant_travel_groves(ski_trail)
	region_label = Label.new()
	region_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.hud.add_child(region_label)
	region_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	region_label.offset_left = -200
	region_label.offset_right = 200
	region_label.offset_top = 12


func init_helipad() -> void:
	var p: Array = data.helipad
	helipad = ground(Vector2(p[0], p[1])) + Vector3.UP * .20


func ground(p: Vector2) -> Vector3:
	return Vector3(p.x, game.river.ground_height(p.x, p.y) + .08, p.y)


func road(points: Array, width: float, trail: bool, raised := false) -> void:
	var vertices := SurfaceTool.new()
	vertices.begin(Mesh.PRIMITIVE_TRIANGLES)
	var centers: Array[Vector2] = []
	for index in range(1, points.size()):
		var start := Vector2(points[index - 1][0], points[index - 1][1])
		var end := Vector2(points[index][0], points[index][1])
		var spacing := 6.0 if raised else 2.0
		var divisions := maxi(1, ceili(start.distance_to(end) / spacing))
		for step in divisions:
			centers.append(start.lerp(end,float(step)/divisions))
	centers.append(Vector2(points[-1][0],points[-1][1]))
	var heights := PackedFloat32Array()
	for p in centers: heights.append(maxf(.35,ground(p).y) if raised else ground(p).y)
	if raised:
		# Raise the approach in advance of the bank instead of following the
		# submerged riverbed or making an unwalkable cliff-height step.
		for index in range(heights.size()-2,-1,-1):
			heights[index] = maxf(heights[index],heights[index+1]-centers[index].distance_to(centers[index+1])*.16)
		for index in range(1,heights.size()):
			heights[index] = maxf(heights[index],heights[index-1]-centers[index].distance_to(centers[index-1])*.16)
	var edges: Array[Vector2] = []
	for index in centers.size():
		var incoming := (centers[index] - centers[maxi(index - 1, 0)]).orthogonal().normalized()
		var outgoing := (centers[mini(index + 1, centers.size() - 1)] - centers[index]).orthogonal().normalized()
		var middle := (incoming + outgoing).normalized()
		var alignment := maxf(.72, middle.dot(incoming if index > 0 else outgoing))
		edges.append(middle * (width * .5 / alignment))
	var steel := Kit.paint(Color("#7b8179"), .82)
	for index in range(centers.size()-1):
		for corner: Vector2i in [Vector2i(0,-1),Vector2i(1,-1),Vector2i(0,1),Vector2i(0,1),Vector2i(1,-1),Vector2i(1,1)]:
			var row := index + corner.x
			var p := centers[row] + edges[row] * corner.y
			var at := ground(p)
			# Keep narrow terrain-following surfaces above the terrain and the
			# older atlas street ribbons where their paths cross or overlap.
			at.y = heights[row] if raised else at.y + .10
			vertices.set_uv(p*.25)
			vertices.add_vertex(at)
		if raised and heights[index] - ground(centers[index]).y > .9:
			for side: float in [-.94, .94]:
				var a := centers[index] + edges[index] * side
				var b := centers[index + 1] + edges[index + 1] * side
				var start := Vector3(a.x, heights[index], a.y)
				var end := Vector3(b.x, heights[index + 1], b.y)
				Kit.beam(self, start + Vector3.UP * .83, end + Vector3.UP * .83, .075, steel)
				Kit.box_at(self, start + Vector3.UP * .42, Vector3(.085, .84, .085), steel)
			if index % 3 != 0: continue
			for side in [-.7, .7]:
				var p := ground(centers[index] + edges[index] * side)
				var rise := heights[index]-p.y
				if rise > .1:
					Kit.box_at(self, p + Vector3.UP * rise * .5, Vector3(.38, rise, .38), steel)
	vertices.generate_normals()
	var mesh := vertices.commit()
	var material := Kit.paint(Color("#5c5746") if trail else Color("#454945"), .96)
	if not trail:
		material.albedo_texture = game.river.asphalt_scan
		material.albedo_color = Color.WHITE
	material.cull_mode = BaseMaterial3D.CULL_DISABLED
	var surface := Kit.mesh_at(self, mesh, Vector3.ZERO, material)
	if not raised:
		surface.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	surface.create_trimesh_collision()
	road_surfaces.append(surface)


func plant_travel_groves(trail: Array) -> void:
	var pines := Pines.new()
	var random := RandomNumberGenerator.new()
	random.seed = 2004
	var roads: Array = data.mcanulty_roads.duplicate()
	roads.append(trail)
	for center: Vector3 in [helipad, ski]:
		for index in 105:
			var angle := random.randf_range(0, TAU)
			var offset := Vector2.from_angle(angle) * random.randf_range(22, 104)
			var point := Vector2(center.x, center.z) + offset
			var clear := true
			for line: Array in roads:
				for segment in range(1, line.size()):
					var a := Vector2(line[segment - 1][0], line[segment - 1][1])
					var b := Vector2(line[segment][0], line[segment][1])
					if point.distance_squared_to(Geometry2D.get_closest_point_to_segment(point, a, b)) < 81:
						clear = false
						break
				if not clear: break
			if clear:
				var foot := ground(point)
				if foot.y > 1:
					pines.plant(foot, random.randf_range(7.5, 15.0), random)
	pines.build(game.river)


func build_cemetery(outline: Array) -> void:
	var stone := Kit.paint(Color("#96978c"), .94)
	var iron := Kit.paint(Color("#39423d"), .81, .12)
	var a := Vector2(outline[0][0], outline[0][1])
	var b := Vector2(outline[1][0], outline[1][1])
	var d := Vector2(outline[3][0], outline[3][1])
	var x := (b - a).normalized()
	var z := (d - a).normalized()
	for row in 8:
		for col in 6:
			var p := Vector2(cemetery.x, cemetery.z) + x * ((col - 2.5) * 9) + z * ((row - 3.5) * 10)
			var marker := Kit.box_at(self, ground(p) + Vector3.UP * .42, Vector3(.55, .84, .14), stone)
			marker.rotation.y = -atan2(x.y, x.x)
	# Generic uninscribed markers: no invented names or real burial locations.
	for index in range(1, outline.size()):
		var from := Vector2(outline[index - 1][0], outline[index - 1][1])
		var to := Vector2(outline[index][0], outline[index][1])
		var count := ceili(from.distance_to(to) / 4)
		for post in count:
			if index == 1 and absf(float(post) / count - .5) < .05: continue
			var p := ground(from.lerp(to, float(post) / count))
			Kit.box_at(self, p + Vector3.UP * .55, Vector3(.07, 1.1, .07), iron)
	var entrance := a.lerp(b, .5)
	road([[entrance.x, entrance.y], [cemetery.x, cemetery.z]], 2.4, true)
	var sign := Label3D.new()
	sign.add_to_group(&"town_roadside_signs")
	sign.set_meta(&"sign_span", 2.8)
	sign.text = "DEEP RIVER CEMETERY\nQuiet grounds"
	sign.position = game.river.roadside_sign_foot(ground(entrance + (b - a).normalized() * 5.0), 2.8) + Vector3.UP * 1.5
	sign.font_size = 40
	sign.pixel_size = .012
	sign.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	add_child(sign)


func clear_pad_trees() -> void:
	for kind in ["tree_detail", "tree_silhouette", "tree_stem", "regional_crown", "regional_trunk"]:
		for item in get_tree().get_nodes_in_group("river_graphics_" + kind):
			if not item is MultiMeshInstance3D or not game.river.is_ancestor_of(item): continue
			var area: AABB = item.global_transform * item.get_aabb()
			if not Rect2(Vector2(area.position.x, area.position.z), Vector2(area.size.x, area.size.z)).grow(10).has_point(Vector2(helipad.x, helipad.z)): continue
			for index in item.multimesh.instance_count:
				var pose: Transform3D = item.multimesh.get_instance_transform(index)
				var point: Vector3 = item.to_global(pose.origin)
				if Vector2(point.x - helipad.x, point.z - helipad.z).length() < 11:
					pose.basis = Basis(Vector3.ZERO, Vector3.ZERO, Vector3.ZERO)
					item.multimesh.set_instance_transform(index, pose)


func section_bounds() -> Array[Rect2]:
	var extent: Vector2 = game.river.extent
	var sections: Array[Rect2] = [Rect2(Vector2.ZERO, extent)]
	var section_size := Vector2.ONE * SECTION_SIZE
	for landing: int in [0, 3, 4]:
		var center: Vector3 = game.campaign.landings.sites[landing].stand
		var start := (Vector2(center.x, center.z) - section_size * .5).clamp(Vector2.ZERO, extent - section_size)
		sections.append(Rect2(start, section_size))
	return sections


func tick(delta: float) -> void:
	elapsed += delta
	if elapsed < .5: return
	elapsed = 0
	var at: Vector3 = game.player.global_position
	var closest := 0
	var distance := INF
	for index in [0, 3, 4]:
		var value: float = at.distance_squared_to(game.campaign.landings.sites[index].stand)
		if value < distance:
			distance = value
			closest = index
	region_label.text = {0:"DEEP RIVER", 3:"SWISHA / DES JOACHIMS", 4:"CHALK RIVER"}[closest]
	region_label.visible = not game.menu_blocks_play()
