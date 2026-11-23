extends Node3D

const Kit = preload("res://scenery.gd")
const COLUMNS := 11
const ROWS := 6
const CELL := 2.6

const GOODS := {
	"rack": {"name": "Storage rack", "short": "Rack", "cost": 40, "size": Vector2i(2, 1), "description": "Adds 6 units of product storage."},
	"bench": {"name": "Worktable", "short": "Table", "cost": 25, "size": Vector2i(2, 1), "description": "Furnishes the warehouse with a work surface."},
	"crate": {"name": "Utility crate", "short": "Crate", "cost": 10, "size": Vector2i(1, 1), "description": "A compact wooden utility crate."},
	"pot": {"name": "Cannabis planter", "short": "Pot", "cost": 35, "size": Vector2i(1, 1), "description": "Runs one simulated cannabis batch at a time."},
}
const BATCH_COST := 8
const BATCH_MINUTES := 20.0
const BATCH_YIELD := 3
const SALE_PRICE := 18
const BASE_CAPACITY := 6

# A future location supplies its own shell, coordinates and ownership visuals.
signal ownership_changed(owned: bool)

var property_id := ""
var property_name := ""
var price := 0
var floor_bounds := Rect2()
var sale_position := Vector3.ZERO
var furnishings := Node3D.new()
var rendered_items := {}
var last_owned := false


func _ready() -> void:
	add_child(furnishings)


func inside(at: Vector3) -> bool:
	var p := to_local(at)
	return floor_bounds.has_point(Vector2(p.x, p.z)) and p.y >= -.5 and p.y < 3.0


func at_sale_post(at: Vector3) -> bool:
	var p := to_local(at)
	return not inside(at) and p.distance_to(sale_position) < 4.0

static func footprint(type: String, turned: bool) -> Vector2i:
	var size: Vector2i = GOODS[type].size
	return Vector2i(size.y, size.x) if turned else size


static func tile_bounds(item: Dictionary) -> Rect2i:
	return Rect2i(Vector2i(int(item.x), int(item.z)), footprint(item.type, bool(item.turned)))


static func tile_center(area: Rect2i) -> Vector3:
	var center := (Vector2(area.position) + Vector2(area.size) * .5 - Vector2(COLUMNS, ROWS) * .5) * CELL
	return Vector3(center.x, 0, center.y)


static func item_at(items: Dictionary, cell: Vector2i) -> String:
	for id: String in items:
		if tile_bounds(items[id]).has_point(cell):
			return id
	return ""


static func capacity(items: Dictionary) -> int:
	var total := BASE_CAPACITY
	for item: Dictionary in items.values():
		if item.type == "rack":
			total += 6
	return total


func sync(state: Dictionary) -> void:
	var owned := bool(state.get("owned", false))
	if owned != last_owned:
		last_owned = owned
		ownership_changed.emit(owned)
	var items: Dictionary = state.get("items", {})
	for id: String in rendered_items.keys():
		if not items.has(id) or model_key(items[id]) != rendered_items[id].key:
			rendered_items[id].node.queue_free()
			rendered_items.erase(id)
	for id: String in items:
		if not rendered_items.has(id):
			var item: Dictionary = items[id]
			rendered_items[id] = {"key": model_key(item), "node": build_item(item)}


static func model_key(item: Dictionary) -> Array:
	return [item.type, item.x, item.z, item.turned, item.get("ready_at", 0)]


func build_item(item: Dictionary) -> StaticBody3D:
	var prop := StaticBody3D.new()
	furnishings.add_child(prop)
	prop.position = tile_center(tile_bounds(item))
	prop.rotation.y = PI * .5 if item.turned else 0.0
	var timber := Kit.paint(Color("#ac8053"))
	var steel := Kit.paint(Color("#3d555d"), .5, .32)
	match item.type:
		"rack":
			for x in [-1.65, 1.65]:
				for z in [-.405, .405]:
					Kit.box_at(prop, Vector3(x, 1.03, z), Vector3(.085, 2.06, .085), steel)
			for y in [.22, .78, 1.35, 1.92]:
				Kit.box_at(prop, Vector3(0, y, 0), Vector3(3.4, .085, .90), timber)
			Kit.collider(prop, Vector3(0, 1.03, 0), Vector3(3.4, 2.06, .9))
		"bench":
			for x in [-1.5, 1.5]:
				for z in [-.35, .35]:
					Kit.box_at(prop, Vector3(x, .45, z), Vector3(.12, .9, .12), steel)
			Kit.box_at(prop, Vector3(0, .93, 0), Vector3(3.3, .14, 1.0), timber)
			Kit.collider(prop, Vector3(0, .5, 0), Vector3(3.3, 1.0, 1.0))
		"crate":
			Kit.box_at(prop, Vector3(0, .34, 0), Vector3(.95, .68, .75), timber)
			Kit.collider(prop, Vector3(0, .34, 0), Vector3(.95, .68, .75))
			for z in [-.23, .23]:
				Kit.box_at(prop, Vector3(0, .36, z), Vector3(.98, .72, .08), steel)
		"pot":
			var pot := CylinderMesh.new()
			pot.top_radius = .44
			pot.bottom_radius = .30
			pot.height = .55
			pot.radial_segments = 14
			Kit.mesh_at(prop, pot, Vector3.UP * .275, Kit.paint(Color("#41433e")))
			var soil := CylinderMesh.new()
			soil.top_radius = .397
			soil.bottom_radius = .395
			soil.height = .018
			Kit.mesh_at(prop, soil, Vector3.UP * .553, Kit.paint(Color("#42362a")))
			Kit.collider(prop, Vector3.UP * .275, Vector3(.86, .55, .86))
			if float(item.get("ready_at", 0)) > 0:
				var leaves := Kit.paint(Color("#4e7746"))
				Kit.box_at(prop, Vector3.UP * .91, Vector3(.045, .74, .045), leaves)
				for i in 5:
					var leaf := BoxMesh.new()
					leaf.size = Vector3(.62, .045, .19)
					var sprig := Kit.mesh_at(prop, leaf, Vector3.UP * (.69 + i * .125), leaves)
					sprig.rotation = Vector3(.16, i * 2.4, .17)
	return prop
