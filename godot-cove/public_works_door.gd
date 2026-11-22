extends Node3D

const Kit = preload("res://scenery.gd")
const HEIGHT := 5.25
const WIDTH := 5.15
const SECTIONS := 10
const RADIUS := .72
const ARC := RADIUS * PI * .5

var panels: Array[AnimatableBody3D] = []
var links: Array[MeshInstance3D] = []
var travel := 0.0
var speed := 0.0
var target := 0.0
var chain_feed := 0.0
var bay: int
var chain: Vector3


func build(number: int) -> void:
	bay = number
	name = "Bay%d" % bay
	chain = Vector3(WIDTH * .5 + .51, 1.55, .30)
	var galvanized := Kit.paint(Color("#a4aaa6"), .55, .46)
	var relief := Kit.paint(Color("#757f7b"), .61, .35)
	var rubber := Kit.paint(Color("#292d2b"))
	var rail := Kit.paint(Color("#434947"), .55, .44)
	var step := HEIGHT / SECTIONS
	for index in SECTIONS:
		var panel := AnimatableBody3D.new()
		panel.sync_to_physics = false
		add_child(panel)
		Kit.box_at(panel, Vector3.ZERO, Vector3(WIDTH, step - .018, .115), galvanized)
		Kit.collider(panel, Vector3.ZERO, Vector3(WIDTH, step, .13))
		for offset: float in [-.15, .05, .15]:
			Kit.box_at(panel, Vector3(0, offset, .066), Vector3(WIDTH, .023, .023), relief)
		if index == 0:
			Kit.box_at(panel, Vector3(0, -.245, 0), Vector3(WIDTH, .043, .135), rubber)
		panels.append(panel)
	for side: float in [-1, 1]:
		var x := side * (WIDTH * .5 + .07)
		var previous := path(0)
		for i in 14:
			var next := path((HEIGHT + ARC + HEIGHT) * (i + 1) / 14.0)
			Kit.beam(self, previous + Vector3.RIGHT * x, next + Vector3.RIGHT * x, .072, rail)
			previous = next
	var ring := TorusMesh.new()
	ring.inner_radius = .022
	ring.outer_radius = .033
	ring.rings = 12
	ring.ring_segments = 6
	for index in 92:
		var link := Kit.mesh_at(self, ring, Vector3.ZERO, rail)
		link.scale.z = 1.9
		link.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		links.append(link)
	layout()


func path(at: float) -> Vector3:
	if at <= HEIGHT:
		return Vector3(0, at, 0)
	var angle := minf((at - HEIGHT) / RADIUS, PI * .5)
	return Vector3(0, HEIGHT + RADIUS * sin(angle),
		RADIUS * (cos(angle) - 1.0) - maxf(0.0, at - HEIGHT - ARC))


func layout() -> void:
	var step := HEIGHT / SECTIONS
	for index in panels.size():
		var a := path(travel + index * step)
		var b := path(travel + (index + 1) * step)
		panels[index].position = (a + b) * .5
		panels[index].rotation.x = atan2(b.z - a.z, b.y - a.y)
	var bottom := .81
	var top := HEIGHT + .62
	var vertical := top - bottom
	var perimeter := 2.0 * vertical + TAU * .067
	for i in links.size():
		var at := fposmod(i * perimeter / links.size() + chain_feed, perimeter)
		var point := Vector2.ZERO
		if at < vertical:
			point = Vector2(.067, bottom + at)
		elif at < vertical + PI * .067:
			var angle := (at - vertical) / .067
			point = Vector2(cos(angle) * .067, top + sin(angle) * .067)
		elif at < 2.0 * vertical + PI * .067:
			point = Vector2(-.067, top - (at - vertical - PI * .067))
		else:
			var angle := PI + (at - 2.0 * vertical - PI * .067) / .067
			point = Vector2(cos(angle) * .067, bottom + sin(angle) * .067)
		links[i].position = Vector3(chain.x + point.x, point.y, chain.z)
		links[i].rotation = Vector3(PI * .5, (i % 2) * PI * .5, 0)


func toggle() -> void:
	target = HEIGHT + ARC if is_zero_approx(target) else 0.0


func advance(delta: float, occupants: Array[Node3D]) -> void:
	if travel == target:
		return
	if target < travel:
		for occupant in occupants:
			var at := to_local(occupant.global_position)
			var radius := .27 if occupant is CharacterBody3D else .77
			if absf(at.x) < WIDTH * .5 + radius and absf(at.z) < 1.4 and at.y < HEIGHT:
				target = HEIGHT + ARC
				break
	var remaining := target - travel
	var desired := signf(remaining) * minf(2.45, sqrt(2.0 * 4.1 * absf(remaining)))
	speed = move_toward(speed, desired, 4.1 * delta)
	var next := travel + speed * delta
	if (target - next) * remaining <= 0.0:
		next = target
		speed = 0.0
	next = clampf(next, 0.0, HEIGHT + ARC)
	chain_feed += (next - travel) * 1.82
	travel = next
	layout()


func prompt() -> String:
	return "E  Pull chain to %s bay %d" % ["open" if is_zero_approx(target) else "close", bay]
