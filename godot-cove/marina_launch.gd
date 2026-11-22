extends RefCounted

const Kit = preload("res://scenery.gd")

var head := Vector2.ZERO
var axis := Vector2.ZERO
var across := Vector2.ZERO
var length := 0.0
var width := 0.0
var crest := 0.0
var elevations: Array
var bounds := Rect2()


func build(parent: Node3D, plan: Dictionary, ground: Callable, concrete: Texture2D) -> void:
	head = Vector2(plan.head[0], plan.head[1])
	var toe := Vector2(plan.toe[0], plan.toe[1])
	var line := toe - head
	length = line.length()
	axis = line / length
	across = Vector2(-axis.y, axis.x)
	width = float(plan.width)
	crest = length * float(plan.crest_fraction)
	elevations = plan.elevations
	var edge := across * width * .5
	bounds = Rect2(head - edge, Vector2.ZERO).expand(head + edge).expand(toe - edge).expand(toe + edge)

	var surface := SurfaceTool.new()
	surface.begin(Mesh.PRIMITIVE_TRIANGLES)
	var left := -width * .5
	var right := width * .5
	var approach := -1.35
	var west := head + axis * approach - edge
	var east := head + axis * approach + edge
	var left_height: float = ground.call(west.x, west.y) + .014
	var right_height: float = ground.call(east.x, east.y) + .014
	var start := float(elevations[0])
	quad(surface, [
		[Vector2(left, approach), left_height], [Vector2(left, 0), start],
		[Vector2(right, approach), right_height], [Vector2(right, 0), start],
	])
	for span in [Vector2(0, crest), Vector2(crest, length)]:
		var high := height_at(span.x)
		var low := height_at(span.y)
		quad(surface, [
			[Vector2(left, span.x), high], [Vector2(left, span.y), low],
			[Vector2(right, span.x), high], [Vector2(right, span.y), low],
		])

	var material := ShaderMaterial.new()
	material.shader = preload("res://marina_wharf.gdshader")
	material.set_shader_parameter("concrete", concrete)
	material.set_shader_parameter("launch_ramp", true)
	var ramp := Kit.mesh_at(parent, surface.commit(), Vector3.ZERO, material)
	ramp.name = "ConcreteBoatLaunch"
	ramp.create_trimesh_collision()


func quad(surface: SurfaceTool, corners: Array) -> void:
	var points: Array[Vector3] = []
	for corner: Array in corners:
		var uv: Vector2 = corner[0]
		var position := head + across * uv.x + axis * uv.y
		points.append(Vector3(position.x, corner[1], position.y))
	for indices: Array in [[0, 1, 2], [2, 1, 3]]:
		var a: Vector3 = points[indices[0]]
		var b: Vector3 = points[indices[1]]
		var c: Vector3 = points[indices[2]]
		surface.set_normal((c - a).cross(b - a).normalized())
		for index: int in indices:
			surface.set_uv(corners[index][0])
			surface.add_vertex(points[index])


func height_at(run: float) -> float:
	if run < crest:
		return lerpf(elevations[0], elevations[1], run / crest)
	return lerpf(elevations[1], elevations[2], (run - crest) / (length - crest))


func floor_at(point: Vector3) -> float:
	var p := Vector2(point.x, point.z)
	if not bounds.has_point(p):
		return -INF
	var offset := p - head
	var run := offset.dot(axis)
	if run < 0.0 or run > length or absf(offset.dot(across)) > width * .5:
		return -INF
	return height_at(run)


func bind_water(material: ShaderMaterial, concrete: Texture2D) -> void:
	if length > 0.0:
		material.set_shader_parameter("ramp_axes", Vector4(head.x, head.y, axis.x, axis.y))
		material.set_shader_parameter("ramp_size", Vector2(length, width))
		material.set_shader_parameter("ramp_concrete", concrete)
