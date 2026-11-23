extends Node3D

const Kit = preload("res://scenery.gd")
const Warehouse = preload("res://warehouse_property.gd")

var site: Node3D
var highlight: MeshInstance3D
var highlight_material: StandardMaterial3D
var ghost: StaticBody3D
var ghost_type := ""
var ghost_material: StandardMaterial3D
var occupied: Dictionary = {}


func setup(property: Node3D, cells: Vector2i, cell: float) -> void:
	site = property
	var half := Vector2(cells) * cell * .5
	var lines := overlay_material(Color("#34768b"))
	var filled := overlay_material(Color("#467c9ba8"))
	for x in cells.x + 1:
		Kit.box_at(self, Vector3(x * cell - half.x, .021, 0), Vector3(.050, .012, half.y * 2), lines)
	for z in cells.y + 1:
		Kit.box_at(self, Vector3(0, .021, z * cell - half.y), Vector3(half.x * 2, .012, .050), lines)
	for z in cells.y:
		for x in cells.x:
			var tile := Vector2i(x, z)
			var center: Vector3 = site.tile_center(Rect2i(tile, Vector2i.ONE))
			var pad := Kit.box_at(self, center + Vector3.UP * .015, Vector3(cell - .095, .009, cell - .095), filled)
			pad.hide()
			occupied[tile] = pad
	highlight_material = overlay_material(Color("#f5b64dbb"))
	highlight = Kit.box_at(self, Vector3.ZERO, Vector3.ONE, highlight_material)
	ghost_material = overlay_material(Color("#f5b64d66"))
	hide()


func enter() -> void:
	show()
	highlight.hide()


func leave() -> void:
	hide()
	if is_instance_valid(ghost):
		ghost.hide()


func preview(type: String, area: Rect2i, turned: bool, legal: bool) -> void:
	if type.is_empty() or not highlight.visible:
		if is_instance_valid(ghost):
			ghost.hide()
		return
	if type != ghost_type:
		if is_instance_valid(ghost):
			ghost.hide()
			ghost.queue_free()
		ghost_type = type
		ghost = site.build_item({"type": type, "x": 0, "z": 0, "turned": false}, self)
		ghost.collision_layer = 0
		ghost.collision_mask = 0
		for mesh: MeshInstance3D in ghost.find_children("*", "MeshInstance3D", true, false):
			mesh.material_override = ghost_material
			mesh.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost_material.albedo_color = Color("#f5b64d66") if legal else Color("#ee735966")
	ghost.position = site.tile_center(area) + Vector3.UP * .035
	ghost.rotation.y = PI * .5 if turned else 0.0
	ghost.show()


func mark(area: Rect2i, legal: bool, cell: float) -> void:
	highlight.visible = area.position.x >= 0 and area.position.y >= 0
	if highlight.visible:
		highlight.position = site.tile_center(area) + Vector3.UP * .023
		highlight.scale = Vector3(area.size.x * cell - .09, .015, area.size.y * cell - .09)
		highlight_material.albedo_color = Color("#f5b64dbb") if legal else Color("#ee7359bb")


func tile_under(screen: Vector2, tiles: Vector2i, cell: float) -> Vector2i:
	var camera := get_viewport().get_camera_3d()
	if not visible or camera == null:
		return Vector2i(-1, -1)
	var start := camera.project_ray_origin(screen)
	var direction := camera.project_ray_normal(screen)
	if not site.rendered_items.is_empty():
		var ray := PhysicsRayQueryParameters3D.create(start, start + direction * 15.0)
		if camera.get_parent() is CollisionObject3D:
			ray.exclude = [camera.get_parent().get_rid()]
		var hit := get_world_3d().direct_space_state.intersect_ray(ray)
		if not hit.is_empty() and site.furnishings.is_ancestor_of(hit.collider) and hit.collider.has_meta("warehouse_tile"):
			return hit.collider.get_meta("warehouse_tile")
	var world = Plane(Vector3.UP, site.global_position.y).intersects_ray(start, direction)
	if world == null or start.distance_squared_to(world) > 225.0:
		return Vector2i(-1, -1)
	var at: Vector3 = site.to_local(world)
	var raw := (Vector2(at.x, at.z) / cell + Vector2(tiles) * .5).floor()
	return Vector2i(raw)


func show_occupied(items: Dictionary) -> void:
	for tile: Vector2i in occupied:
		occupied[tile].visible = not Warehouse.item_at(items, tile).is_empty()


static func overlay_material(tint: Color) -> StandardMaterial3D:
	var material := Kit.paint(tint)
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	return material
