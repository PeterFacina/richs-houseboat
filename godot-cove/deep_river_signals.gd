extends Node3D

const Kit = preload("res://scenery.gd")
const JUNCTION := Vector2(17552.5626, 13729.1083)
const DEEP_RIVER_ROAD := 9
const AMBER := 1
const RED := 0
const GREEN := 2
const CYCLE := 42.0
const INACTIVE := Color("#273334")
const TINTS := [Color("#ff2b26"), Color("#ffc044"), Color("#4dff71")]
const APPROACHES := [
	{"road": 2, "node": 0, "highway": true, "width": 5.65},
	{"road": 8, "node": 1, "highway": true, "width": 5.65},
	{"road": DEEP_RIVER_ROAD, "node": 1, "highway": false, "width": 3.4},
]

var elapsed := 0.0
var last_phase := Vector2i(-1, -1)
var heads: Array[Dictionary] = []
var dark: StandardMaterial3D
var live: Array[StandardMaterial3D] = []


static func phase(at: float) -> Vector2i:
	var t := fposmod(at, CYCLE)
	if t < 22.0:
		return Vector2i(GREEN, RED)
	if t < 25.0:
		return Vector2i(AMBER, RED)
	if t < 27.0:
		return Vector2i(RED, RED)
	if t < 37.0:
		return Vector2i(RED, GREEN)
	if t < 40.0:
		return Vector2i(RED, AMBER)
	return Vector2i(RED, RED)


func build(streets: Array, elevation: Callable) -> void:
	name = "Highway17Signals"
	var steel := Kit.paint(Color("#7e8788"), .57, .46)
	var shell := Kit.paint(Color("#252a2b"))
	var frame := Kit.paint(Color("#ddb353"))
	var white := Kit.paint(Color("#e9e4d8"))
	dark = Kit.paint(INACTIVE, .27)
	for tint: Color in TINTS:
		var lens := Kit.paint(tint, .27)
		lens.emission_enabled = true
		lens.emission = tint
		lens.emission_energy_multiplier = 1.65
		live.append(lens)
	for approach in APPROACHES:
		var point: Array = streets[approach.road][approach.node]
		var outward := (Vector2(point[0], point[1]) - JUNCTION).normalized()
		var right := Vector2(outward.y, -outward.x)
		var pole_at := JUNCTION - outward * 8.6 + right * 8.4
		var y: float = elevation.call(pole_at.x, pole_at.y)
		var pole := Vector3(pole_at.x, y, pole_at.y)
		var long_axis := Vector3(right.x, 0, right.y)
		var heading := atan2(outward.x, outward.y)
		Kit.box_at(self, pole + Vector3.UP * .13, Vector3(.82, .26, .82), steel)
		Kit.beam(self, pole, pole + Vector3.UP * 6.45, .215, steel)
		Kit.beam(self, pole + Vector3.UP * 6.3, pole + Vector3.UP * 6.3 - long_axis * 6.95, .134, steel)
		Kit.beam(self, pole + Vector3.UP * 5.72, pole + Vector3.UP * 6.3 - long_axis * 1.80, .075, steel)
		add_head(pole + Vector3.UP * 5.71 - long_axis * 6.06, heading, approach.highway, shell, frame)
		add_head(pole + Vector3.UP * 3.55 - long_axis * .49, heading, approach.highway, shell, frame)
		add_road_name(pole + Vector3.UP * 5.97 - long_axis * 2.6, heading, approach.highway)
		var width: float = approach.width
		for i in 8:
			var at := JUNCTION + outward * 9.8 + right * (i + .5) * (width - .18) / 8.0
			var bar := Kit.box_at(self, Vector3(at.x, elevation.call(at.x, at.y) + .143, at.y),
				Vector3((width - .18) / 8.0 + .006, .012, .31), white)
			bar.rotation.y = heading
	update_heads()


func add_road_name(at: Vector3, heading: float, highway_approach: bool) -> void:
	var sign := Label3D.new()
	add_child(sign)
	sign.position = at
	sign.rotation.y = heading
	sign.text = "DEEP RIVER RD" if highway_approach else "HIGHWAY 17"
	sign.font_size = 44
	sign.pixel_size = .009
	sign.outline_size = 0
	sign.double_sided = false
	var board := Kit.box_at(sign, Vector3(0, 0, -.055), Vector3(2.86, .47, .09), Kit.paint(Color("#255841")))
	board.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func add_head(at: Vector3, heading: float, highway: bool, shell: Material, frame: Material) -> void:
	var head := Node3D.new()
	add_child(head)
	head.position = at
	head.rotation.y = heading
	Kit.box_at(head, Vector3.ZERO, Vector3(.51, 1.23, .22), frame)
	Kit.box_at(head, Vector3(0, 0, .11), Vector3(.419, 1.105, .13), shell)
	var lenses: Array[MeshInstance3D] = []
	for i in 3:
		var y := .345 - i * .345
		var glass := CylinderMesh.new()
		glass.top_radius = .141
		glass.bottom_radius = .141
		glass.height = .028
		glass.radial_segments = 18
		var lens := Kit.mesh_at(head, glass, Vector3(0, y, .188), dark)
		lens.rotation.x = PI * .5
		lenses.append(lens)
		Kit.box_at(head, Vector3(0, y + .158, .246), Vector3(.301, .034, .184), shell)
	heads.append({"lenses": lenses, "highway": highway})


func _process(delta: float) -> void:
	elapsed = fposmod(elapsed + delta, CYCLE)
	update_heads()


func update_heads() -> void:
	var current := phase(elapsed)
	if current == last_phase:
		return
	last_phase = current
	for head in heads:
		var lit := current.x if head.highway else current.y
		for i in 3:
			head.lenses[i].material_override = live[i] if i == lit else dark
