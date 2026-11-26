extends RefCounted

const Property = preload("res://warehouse_property.gd")
const Kit = preload("res://scenery.gd")
const MARIO_HOME := Vector2(18455.0, 13792.0)

# Directions face the access road. The first three shells follow the surveyed parcels.
const LISTINGS := [
	{"id": "walker_works", "footprint": "378665089", "name": "Walker Road Workshop", "price": 1200, "cells": Vector2i(4, 4),
		"at": Vector2(17430.6283, 13684.749), "angle": 2.62, "size": Vector2(15, 13), "height": 4.5, "color": Color("#a38e74"), "bays": 1},
	{"id": "highway_lockup", "footprint": "378665087", "name": "Highway Supply Lockup", "price": 2800, "cells": Vector2i(5, 4),
		"at": Vector2(17318.1083, 13618.4345), "angle": -.63, "size": Vector2(16, 15), "height": 4.8, "color": Color("#83918b"), "bays": 2},
	{"id": "walker_storehouse", "footprint": "378665085", "name": "West Highway Storehouse", "price": 4800, "cells": Vector2i(8, 3),
		"at": Vector2(17256.7437, 13579.5444), "angle": -.594, "size": Vector2(26, 12), "height": 5.7, "color": Color("#9e775e"), "bays": 3},
	{"id": "mcanulty_freight", "footprint": "", "name": "McAnulty Freight Depot", "price": 8000, "cells": Vector2i(14, 8),
		"at": Vector2(15931, 11331), "angle": -.81, "size": Vector2(41, 26), "height": 7.2, "color": Color("#657685"), "bays": 4},
]


static func replaces(footprint: String) -> bool:
	for entry: Dictionary in LISTINGS:
		if not entry.footprint.is_empty() and footprint == entry.footprint:
			return true
	return false


static func near_property(area: Rect2) -> bool:
	if area.grow(43.0).has_point(MARIO_HOME):
		return true
	for entry: Dictionary in LISTINGS:
		if area.grow(43.0).has_point(entry.at):
			return true
	return false


static func clears_tree(at: Vector2) -> bool:
	var home_local := (at - MARIO_HOME).rotated(-1.16)
	if Rect2(Vector2(-23.0, -18.0), Vector2(36.0, 39.0)).has_point(home_local):
		return true
	for entry: Dictionary in LISTINGS:
		if at.distance_squared_to(entry.at) > 65.0 * 65.0:
			continue
		var p: Vector2 = (at - entry.at).rotated(entry.angle)
		var size: Vector2 = entry.size
		if Rect2(-size * .5 - Vector2(8, 8), size + Vector2(16, 27)).has_point(p):
			return true
	return false


static func build(parent: Node3D, elevation: Callable, concrete: Texture2D, brick: Texture2D, wood: Texture2D) -> Array[Node3D]:
	var properties: Array[Node3D] = []
	for entry: Dictionary in LISTINGS:
		var site := Property.new()
		site.name = entry.id
		site.property_id = entry.id
		site.property_name = entry.name
		site.price = entry.price
		site.grid_size = entry.cells
		var size: Vector2 = entry.size
		site.floor_bounds = Rect2(-size * .5 + Vector2(.28, .28), size - Vector2(.56, .56))
		parent.add_child(site)
		site.position = Vector3(entry.at.x, 0, entry.at.y)
		site.rotation.y = entry.angle
		var grades := sample_grades(site, size, elevation)
		site.position.y = grades.y + .16
		build_shell(site, entry, elevation, concrete, brick if entry.bays == 3 else wood if entry.bays == 1 else null,
			maxf(.48, site.position.y - grades.x + .15))
		properties.append(site)
	return properties


static func sample_grades(site: Node3D, size: Vector2, elevation: Callable) -> Vector2:
	var low := INF
	var high := -INF
	var columns := ceili(size.x)
	var rows := ceili(size.y)
	for x in columns + 1:
		for z in rows + 1:
			var local := (Vector2(float(x) / columns, float(z) / rows) - Vector2.ONE * .5) * size
			var at := site.to_global(Vector3(local.x, 0, local.y))
			var ground: float = elevation.call(at.x, at.z)
			low = minf(low, ground)
			high = maxf(high, ground)
	return Vector2(low, high)


static func build_shell(site: Node3D, entry: Dictionary, elevation: Callable, concrete_scan: Texture2D,
		siding_scan: Texture2D, foundation: float) -> void:
	var size: Vector2 = entry.size
	var edge := size.x * .5
	var front := size.y * .5
	var height: float = entry.height
	var siding := textured(entry.color.lightened(.13), siding_scan, .45)
	var rib := Kit.paint(entry.color.darkened(.22), .69, .23)
	var trim := Kit.paint(Color("#3d4749"), .72, .30)
	var concrete := textured(Color("#c5bfb4"), concrete_scan, .36)
	var inside_trim := Kit.paint(Color("#9b9890"))
	var slab := Kit.paint(Color("#a9aaab"), .86)
	var ceiling := Kit.paint(Color("#7f898c"), .84)
	var glass := Kit.paint(Color("#537581"), .25, .43)
	var door_panel := Kit.paint(Color("#b6b9ae"), .61, .22)
	var glow := Kit.paint(Color("#fff2d7"))
	glow.emission_enabled = true
	glow.emission = Color("#fff1cc")
	var body := StaticBody3D.new()
	site.add_child(body)
	# A foundation skirt covers grade changes without creating a buried wall at the entrance.
	solid(body, Vector3(0, -foundation * .5, 0), Vector3(size.x, foundation, size.y), slab)
	for seam in range(-floori(edge / 4.0), floori(edge / 4.0) + 1):
		Kit.box_at(site, Vector3(seam * 4.0, .002, 0), Vector3(.019, .004, size.y - .30), inside_trim)
	for seam in range(-floori(front / 4.0), floori(front / 4.0) + 1):
		Kit.box_at(site, Vector3(0, .003, seam * 4.0), Vector3(size.x - .30, .004, .019), inside_trim)
	Kit.box_at(site, Vector3(0, .155, -front + .132), Vector3(size.x - .26, .31, .055), inside_trim)
	solid(body, Vector3(0, height * .5, -front), Vector3(size.x, height, .24), siding)
	for x in [-edge, edge]:
		solid(body, Vector3(x, height * .5, 0), Vector3(.24, height, size.y), siding)
		Kit.box_at(site, Vector3(x, height - .18, 0), Vector3(.29, .22, size.y + .10), trim)
		for i in floori(size.y / 1.2):
			Kit.box_at(site, Vector3(x + signf(x) * .135, height * .53, -front + .75 + i * 1.2),
				Vector3(.042, height * .91, .069), rib)
	var entry_x := edge - 1.38
	var split := entry_x - .78
	solid(body, Vector3((-edge + split) * .5, height * .5, front), Vector3(split + edge, height, .27), siding)
	solid(body, Vector3((entry_x + .78 + edge) * .5, height * .5, front),
		Vector3(edge - entry_x - .78, height, .27), siding)
	solid(body, Vector3(entry_x, (height + 2.32) * .5, front), Vector3(1.56, height - 2.32, .27), siding)
	var roof := Node3D.new()
	site.add_child(roof)
	solid(body, Vector3(0, height - .11, 0), Vector3(size.x, .23, size.y), ceiling)
	var pitch := .105 if entry.bays > 1 else .18
	gable_ends(roof, edge, front, height, edge * tan(pitch), siding)
	for side in [-1.0, 1.0]:
		var roof_leaf := Kit.box_at(roof, Vector3(side * edge * .5, height + edge * .5 * tan(pitch), 0),
			Vector3(edge / cos(pitch) + .36, .20, size.y + .63), trim)
		roof_leaf.rotation.z = -side * pitch
		for z in range(-floori(front), floori(front) + 1, 2):
			var seam := Kit.box_at(roof, roof_leaf.position + Vector3(0, .122, z),
				Vector3(edge / cos(pitch) + .36, .04, .05), rib)
			seam.rotation.z = roof_leaf.rotation.z
	Kit.box_at(site, Vector3(0, height - .35, front + .156), Vector3(size.x, .21, .06), trim)
	Kit.box_at(site, Vector3(0, height - .35, -front - .147), Vector3(size.x, .21, .06), trim)
	if entry.bays in [2, 4]:
		for x in range(-floori(edge * 4), floori(edge * 4) + 1):
			var horizontal := x * .25
			Kit.box_at(site, Vector3(horizontal, height * .5, -front - .138), Vector3(.032, height - .31, .04), rib)
			Kit.box_at(site, Vector3(horizontal, height - .79, front + .16), Vector3(.032, .70, .04), rib)
	var covered := (split + edge - .54)
	var spacing := covered / float(entry.bays)
	for i in int(entry.bays):
		var x := -edge + .27 + (i + .5) * spacing
		var width := minf(spacing - .72, 5.6)
		var rise := minf(height - .92, 3.9)
		Kit.box_at(site, Vector3(x, rise * .5, front + .159), Vector3(width + .15, rise + .13, .11), trim)
		Kit.box_at(site, Vector3(x, rise + .26, front + .298), Vector3(width + .23, .11, .34), trim)
		for post in [-1.0, 1.0]:
			Kit.box_at(site, Vector3(x + post * (width * .5 + .23), .48, front + .62), Vector3(.13, .96, .15), rib)
		Kit.box_at(site, Vector3(x, rise * .5, front + .23), Vector3(width, rise, .06), door_panel)
		for rib_index in 7:
			Kit.box_at(site, Vector3(x, rise * (rib_index + 1) / 8.0, front + .267), Vector3(width, .035, .026), rib)
		for pane in 3:
			Kit.box_at(site, Vector3(x + (pane - 1) * width * .267, rise * .72, front + .269),
				Vector3(width * .24, .34, .022), glass)
	var lock_body := StaticBody3D.new()
	site.add_child(lock_body)
	var door := solid(lock_body, Vector3(entry_x, 1.16, front), Vector3(1.53, 2.32, .19), trim)
	Kit.box_at(site, Vector3(entry_x, 2.58, front + .23), Vector3(.37, .12, .27), glow)
	site.sale_position = Vector3(entry_x - .15, 0, front + 2.35)
	var sign := Label3D.new()
	site.add_child(sign)
	sign.position = Vector3(edge - 2.2, 3.02, front + .223)
	Kit.box_at(site, sign.position - Vector3.BACK * .041, Vector3(4.05, .78, .068), trim)
	sign.text = "%s\nFOR SALE  $%d" % [entry.name, entry.price]
	sign.font_size = 46
	sign.pixel_size = .0062
	sign.outline_size = 5
	sign.double_sided = false
	site.ownership_changed.connect(func(owned: bool):
		door.visible = not owned
		lock_body.process_mode = Node.PROCESS_MODE_DISABLED if owned else Node.PROCESS_MODE_INHERIT
		sign.text = entry.name if owned else "%s\nFOR SALE  $%d" % [entry.name, entry.price])
	for x in range(-floori(edge * .76), floori(edge * .76) + 1, 6):
		Kit.box_at(site, Vector3(x, height - .28, 0), Vector3(.21, .33, size.y - .29), trim)
		for z in [-front * .64, 0.0, front * .64]:
			Kit.box_at(site, Vector3(x, height - .49, z), Vector3(2.10, .12, .31), trim)
			Kit.box_at(site, Vector3(x, height - .57, z), Vector3(1.92, .06, .21), glow)
			var lamp := SpotLight3D.new()
			site.add_child(lamp)
			lamp.position = Vector3(x, height - .65, z)
			lamp.rotation_degrees.x = -90
			lamp.light_color = Color("#fff4df")
			lamp.light_energy = 3.15
			lamp.spot_range = 12
			lamp.spot_angle = 66
	apron(site, size, elevation, concrete)


static func apron(site: Node3D, size: Vector2, elevation: Callable, material: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var columns := 12
	var rows := 10
	for z in rows + 1:
		for x in columns + 1:
			var p := Vector3(lerpf(-size.x * .5, size.x * .5, float(x) / columns), 0,
				size.y * .5 - .09 + z * 1.3)
			var at := site.to_global(p)
			var terrain := float(elevation.call(at.x, at.z)) - site.global_position.y + .062
			p.y = maxf(terrain, lerpf(.012, terrain, smoothstep(0, 1, float(z) / rows)))
			surface.add_vertex(p)
	for z in rows:
		for x in columns:
			var i := z * (columns + 1) + x
			for vertex in [i, i + 1, i + columns + 1, i + 1, i + columns + 2, i + columns + 1]:
				surface.add_index(vertex)
	surface.generate_normals()
	var mesh := Kit.mesh_at(site, surface.commit(), Vector3.ZERO, material)
	mesh.create_trimesh_collision()


static func textured(color: Color, scan: Texture2D, repeats: float) -> StandardMaterial3D:
	var material := Kit.paint(color)
	if scan != null:
		material.albedo_texture = scan
		material.uv1_triplanar = true
		material.uv1_scale = Vector3.ONE * repeats
	return material


static func solid(body: StaticBody3D, at: Vector3, size: Vector3, material: Material) -> MeshInstance3D:
	Kit.collider(body, at, size)
	return Kit.box_at(body, at, size, material)


static func gable_ends(roof: Node3D, width: float, depth: float, height: float, rise: float, siding: Material) -> void:
	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	for end in [-1.0, 1.0]:
		var z: float = end * depth
		var points := PackedVector3Array([Vector3(-width, height - .04, z),
			Vector3(0, height + rise, z), Vector3(width, height - .04, z)])
		for i in 3:
			surface.set_normal(Vector3.BACK * end)
			surface.add_vertex(points[i if end > 0 else 2 - i])
	Kit.mesh_at(roof, surface.commit(), Vector3.ZERO, siding)
