extends Node3D

const Kit = preload("res://scenery.gd")
const DeepRiverMap = preload("res://deep_river_map.gd")
const TETHER := 26.0

var river: DeepRiverMap
var surface_camera: Camera3D
var camera: Camera3D
var vehicle: Node3D
var recorder: Node3D
var target_indicator: Label3D
var active := false
var retrieved := false
var tether_anchor := Vector3.ZERO
var destination := Vector3.ZERO
var aim := Vector2.ZERO
var velocity := Vector3.ZERO


func setup(map: DeepRiverMap, eye: Camera3D) -> void:
	river = map
	surface_camera = eye
	vehicle = Node3D.new()
	add_child(vehicle)
	var alloy := Kit.paint(Color("#937345"), .49, .26)
	var polymer := Kit.paint(Color("#2d474e"), .68)
	for side in [-1.0, 1.0]:
		Kit.box_at(vehicle, Vector3(side * .31, 0, .10), Vector3(.19, .38, .82), polymer)
		Kit.box_at(vehicle, Vector3(side * .31, .17, .20), Vector3(.197, .06, .72), alloy)
		Kit.box_at(vehicle, Vector3(side * .38, -.23, -.23), Vector3(.10, .12, .13), alloy)
	Kit.box_at(vehicle, Vector3(0, -.04, .14), Vector3(.48, .28, .57), alloy)
	camera = Camera3D.new()
	camera.near = .055
	camera.far = 82.0
	camera.fov = 81.0
	vehicle.add_child(camera)
	camera.position = Vector3(0, .04, -.43)
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color("#1a3938")
	environment.fog_enabled = true
	environment.fog_light_color = Color("#243d37")
	environment.fog_density = .097
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color("#739a82")
	environment.ambient_light_energy = .38
	camera.environment = environment
	var lantern := SpotLight3D.new()
	lantern.light_color = Color("#e4f2d1")
	lantern.light_energy = 3.5
	lantern.spot_range = 13.6
	lantern.spot_angle = 53.5
	vehicle.add_child(lantern)
	lantern.position = Vector3(0, -.17, -.46)
	recorder = Node3D.new()
	add_child(recorder)
	Kit.box_at(recorder, Vector3.ZERO, Vector3(.52, .29, .46), alloy)
	Kit.box_at(recorder, Vector3(0, .176, .065), Vector3(.40, .08, .15), polymer)
	var light := Kit.paint(Color("#c8eabd"))
	light.emission_enabled = true
	light.emission = Color("#c8eabd")
	Kit.box_at(recorder, Vector3(.08, .149, -.074), Vector3(.045, .025, .05), light)
	target_indicator = Label3D.new()
	target_indicator.text = "SURVEY RECORDER"
	target_indicator.font_size = 34
	target_indicator.pixel_size = .005
	target_indicator.modulate = Color("#dbf2c0")
	target_indicator.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	target_indicator.position.y = .6
	recorder.add_child(target_indicator)
	hide()


func deploy(boat: Vector3, site: Vector3) -> void:
	active = true
	retrieved = false
	tether_anchor = boat
	destination = site
	destination.y = -river.depth_at(site) + .24
	var heading := site - boat
	var angle := atan2(-heading.x, -heading.z)
	aim = Vector2(angle, -.27)
	vehicle.global_position = Vector3(boat.x, -.62, boat.z)
	recorder.global_position = destination
	recorder.show()
	velocity = Vector3.ZERO
	update_view()
	show()
	camera.make_current()


func steer(mouse_delta: Vector2) -> void:
	aim.x -= mouse_delta.x * .0026
	aim.y = clampf(aim.y - mouse_delta.y * .0026, -1.19, 1.03)
	update_view()


func update_view() -> void:
	vehicle.rotation.y = aim.x
	camera.rotation.x = aim.y


func advance(delta: float, course: Vector3) -> void:
	if not active:
		return
	var heading := course.normalized().rotated(Vector3.UP, aim.x)
	velocity = velocity.lerp(heading * 2.0, 1.0 - exp(-delta * 4.2))
	var current := river.downstream(vehicle.global_position, 0.0)
	var candidate := vehicle.global_position + (velocity + current * .17) * delta
	var from_anchor := candidate - tether_anchor
	if from_anchor.length() > TETHER:
		candidate = tether_anchor + from_anchor.limit_length(TETHER)
	var depth := river.depth_at(candidate)
	if depth < 1.2:
		velocity *= .33
		return
	candidate.y = clampf(candidate.y, -depth + .34, -.64)
	vehicle.global_position = candidate
	recorder.visible = not retrieved
	target_indicator.visible = vehicle.global_position.distance_squared_to(destination) < 13.0 * 13.0


func take() -> bool:
	if not active or retrieved or vehicle.global_position.distance_to(destination) > 1.55:
		return false
	retrieved = true
	recorder.hide()
	return true


func stow() -> void:
	active = false
	surface_camera.make_current()
	hide()


func status_text() -> String:
	var at := vehicle.global_position
	var floor_depth := river.depth_at(at)
	return "Depth %.1f m   •   %.1f m above bottom   •   Tether %.1f / %.0f m\n%s" % [
		-at.y, maxf(0.0, floor_depth + at.y), at.distance_to(tether_anchor), TETHER,
		"Recorder secured. V to return to the boat." if retrieved else
		"Recorder %.1f m away   •   WASD steer   Space / Ctrl depth   E collect   V return" % at.distance_to(destination)]
