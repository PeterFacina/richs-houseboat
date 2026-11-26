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
var visor: ArrayMesh


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
	var steel := Kit.paint(Color("#a0a5a5"), .46, .44)
	var housing := Kit.paint(Color("#e2a421"), .61)
	var backplate := Kit.paint(Color("#393329"))
	var white := Kit.paint(Color("#e9e4d8"))
	dark = Kit.paint(INACTIVE, .27)
	visor = make_visor()
	for tint in TINTS:
		var lens := Kit.paint(tint, .27)
		lens.emission_enabled = true
		lens.emission = tint
		lens.emission_energy_multiplier = 1.65
		live.append(lens)

	var axes: Array[Vector2] = []
	for approach in APPROACHES:
		var point: Array = streets[approach.road][approach.node]
		var outward := (Vector2(point[0], point[1]) - JUNCTION).normalized()
		axes.append(outward)
		add_stop_bar(outward, approach.width, elevation, white)

	# Both masts stand on the plaza side. The longer arm reaches the far highway lane.
	var along := axes[0]
	var away := Vector2(-along.y, along.x)
	var junction_y: float = elevation.call(JUNCTION.x, JUNCTION.y)
	var head_y := junction_y + 5.8
	var left := add_mast(JUNCTION - along * 10.3 - away * 8.2, head_y, elevation, steel)
	var right := add_mast(JUNCTION + along * 10.1 - away * 8.3, head_y, elevation, steel)
	for mount in [
		{"mast": left, "tip": Vector2(-10.3, -2.85), "approach": 0},
		{"mast": left, "tip": Vector2(-4.3, -8.2), "approach": 2},
		{"mast": right, "tip": Vector2(10.1, 2.85), "approach": 1},
		{"mast": right, "tip": Vector2(3.3, -8.3), "approach": 2},
	]:
		var tip: Vector2 = mount.tip
		var at := JUNCTION + along * tip.x + away * tip.y
		var end := Vector3(at.x, head_y + .61, at.y)
		var arm_start: Vector3 = mount.mast
		tube(arm_start, end, .115, .058, steel)
		var arm_support := arm_start.lerp(end, .34)
		tube(arm_start - Vector3.UP * .33, arm_support, .035, .026, steel)
		var approach_index: int = mount.approach
		var axis := axes[approach_index]
		add_head(end - Vector3.UP * .62, atan2(axis.x, axis.y), APPROACHES[approach_index].highway, backplate, housing)

	for i in 2:
		var top := left if i == 0 else right
		var axis := axes[i]
		var sign_height := top - Vector3.UP * .12
		var hanger := Vector3(away.x, 0, away.y) * .35
		var repeater := top - Vector3.UP * 2.6 + hanger
		tube(top - Vector3.UP * 2.33, repeater + Vector3.UP * .12, .054, .04, steel)
		add_head(repeater, atan2(axis.x, axis.y), true, backplate, housing)
		add_road_name(sign_height + Vector3(away.x, 0, away.y) * 2.1, atan2(axis.x, axis.y), true)
	add_road_name(right - Vector3(along.x, .19, along.y) * 2.25, atan2(axes[2].x, axes[2].y), false)
	update_heads()


func add_stop_bar(outward: Vector2, width: float, elevation: Callable, white: Material) -> void:
	var right := Vector2(outward.y, -outward.x)
	for i in 8:
		var at := JUNCTION + outward * 9.8 + right * (i + .5) * (width - .18) / 8.0
		var bar := Kit.box_at(self, Vector3(at.x, elevation.call(at.x, at.y) + .143, at.y),
			Vector3((width - .18) / 8.0 + .006, .012, .31), white)
		bar.rotation.y = atan2(outward.x, outward.y)


func add_mast(at: Vector2, head_y: float, elevation: Callable, steel: Material) -> Vector3:
	var foot := Vector3(at.x, elevation.call(at.x, at.y), at.y)
	var top := Vector3(at.x, head_y + .92, at.y)
	Kit.box_at(self, foot + Vector3.UP * .13, Vector3(.69, .28, .69), steel)
	tube(foot + Vector3.UP * .12, top, .17, .093, steel)
	return top - Vector3.UP * .64


func tube(a: Vector3, b: Vector3, bottom: float, top: float, steel: Material) -> void:
	var cylinder := CylinderMesh.new()
	cylinder.bottom_radius = bottom
	cylinder.top_radius = top
	cylinder.height = a.distance_to(b)
	cylinder.radial_segments = 10
	var instance := Kit.mesh_at(self, cylinder, (a + b) * .5, steel)
	instance.quaternion = Quaternion(Vector3.UP, (b - a).normalized())

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
	var bracket := Vector3(0, .61, -.10)
	Kit.box_at(head, bracket, Vector3(.095, .29, .14), frame)
	Kit.box_at(head, Vector3.ZERO, Vector3(.46, 1.14, .25), frame)
	Kit.box_at(head, Vector3(0, 0, .135), Vector3(.416, 1.085, .08), shell)
	var lenses: Array[MeshInstance3D] = []
	for i in 3:
		var y := .345 - i * .345
		var glass := CylinderMesh.new()
		glass.top_radius = .135
		glass.bottom_radius = .135
		glass.height = .028
		glass.radial_segments = 18
		var lens := Kit.mesh_at(head, glass, Vector3(0, y, .181), dark)
		lens.rotation.x = PI * .5
		lenses.append(lens)
		Kit.mesh_at(head, visor, Vector3(0, y, 0), shell)
	heads.append({"lenses": lenses, "highway": highway})


func make_visor() -> ArrayMesh:
	var mesh := SurfaceTool.new()
	mesh.begin(Mesh.PRIMITIVE_TRIANGLES)
	for i in 7:
		var a := Vector2.from_angle(float(i) / 7 * PI) * .156
		var b := Vector2.from_angle(float(i + 1) / 7 * PI) * .156
		var rear_a := Vector3(a.x, a.y, .167)
		var rear_b := Vector3(b.x, b.y, .167)
		var tip_a := Vector3(a.x, a.y, .26 + a.y * .91)
		var tip_b := Vector3(b.x, b.y, .26 + b.y * .91)
		for p in [rear_a, rear_b, tip_a, rear_b, tip_b, tip_a]:
			mesh.add_vertex(p)
	mesh.generate_normals()
	return mesh.commit()

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
