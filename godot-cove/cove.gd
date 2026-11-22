extends Node3D

const Kit = preload("res://scenery.gd")
const Boat = preload("res://houseboat.gd")
const Swell = preload("res://swell.gd")
const CRATE_MOOR := Vector3(3.4, 0.0, 1.05)
const BUOY_MOOR := Vector3(5.0, 0.0, -23.0)
const START := Vector3(-5.30, 0.76, 12.98)
const LINE_RANGE := 10.4

var vessel: AnimatableBody3D
var player: CharacterBody3D
var spawn_point := START
var eye: Camera3D
var crate: Node3D
var buoy: Node3D
var rope: MeshInstance3D
var water: ShaderMaterial
var clock := 0.0
var yaw := -1.30
var pitch := -0.107
var driving := false
var walk_multiplier := 1.0
var mouse_sensitivity := .0022
var boarded := false
var pulled := false
var landed := false
var hauling := false
var haul_progress := 0.0
var cast_origin: Vector3
var objective: Label
var instruction: Label
var marker: Label
var fps: Label
var progress: ProgressBar
var hud: Control


func _ready() -> void:
	Kit.new().build(self)
	build_water()
	vessel = Boat.new()
	add_child(vessel)
	build_cargo()
	build_player()
	build_hud()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func build_water() -> void:
	var plane := PlaneMesh.new()
	plane.size = Vector2(178, 178)
	plane.subdivide_width = 120
	plane.subdivide_depth = 120
	water = ShaderMaterial.new()
	water.shader = preload("res://water.gdshader")
	var river := Kit.mesh_at(self, plane, Vector3(0, 0, -26), water)
	river.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	river.custom_aabb = AABB(Vector3(-90, -0.3, -90), Vector3(180, 0.6, 180))


func build_cargo() -> void:
	crate = Node3D.new()
	add_child(crate)
	var cedar := Kit.paint(Color("#a2703f"))
	var band := Kit.paint(Color("#d09e53"))
	var steel := Kit.paint(Color("#423a33"))
	Kit.box_at(crate, Vector3(0, 0.15, 0), Vector3(0.75, 0.55, 0.60), cedar)
	for x in [-0.27, 0.27]:
		Kit.box_at(crate, Vector3(x, 0.426, 0), Vector3(0.14, 0.055, 0.65), band)
		for z in [-0.309, 0.309]:
			Kit.box_at(crate, Vector3(x, 0.15, z), Vector3(0.14, 0.54, 0.027), band)
	Kit.beam(crate, Vector3(-0.28, -0.04, 0.326), Vector3(0.28, 0.37, 0.326), 0.055, steel)
	Kit.beam(crate, Vector3(0.28, -0.04, -0.326), Vector3(-0.28, 0.37, -0.326), 0.055, steel)
	rope = Kit.box_at(self, Vector3.ZERO, Vector3(0.021, 0.021, 1.0), Kit.paint(Color("#d9bb85")))
	rope.hide()
	buoy = Node3D.new()
	add_child(buoy)
	var ocean_green := Kit.paint(Color("#508d71"))
	var lantern := Kit.paint(Color("#ffdf9e"))
	lantern.emission_enabled = true
	lantern.emission = Color("#f1b771")
	lantern.emission_energy_multiplier = 0.7
	var float_mesh := CylinderMesh.new()
	float_mesh.height = 0.67
	float_mesh.top_radius = 0.44
	float_mesh.bottom_radius = 0.51
	float_mesh.radial_segments = 14
	Kit.mesh_at(buoy, float_mesh, Vector3(0, 0.08, 0), ocean_green)
	Kit.box_at(buoy, Vector3(0, 0.70, 0), Vector3(0.12, 1.08, 0.12), ocean_green)
	Kit.box_at(buoy, Vector3(0, 1.28, 0), Vector3(0.22, 0.21, 0.22), lantern)


func build_player() -> void:
	player = CharacterBody3D.new()
	player.floor_snap_length = 0.27
	player.floor_max_angle = deg_to_rad(53)
	add_child(player)
	player.position = spawn_point
	var capsule := CapsuleShape3D.new()
	capsule.radius = 0.245
	capsule.height = 1.68
	var body := CollisionShape3D.new()
	body.position.y = 0.84
	body.shape = capsule
	player.add_child(body)
	eye = Camera3D.new()
	eye.fov = 78
	eye.near = 0.045
	eye.far = 165
	eye.position.y = 1.58
	player.add_child(eye)
	eye.make_current()
	update_view()


func build_hud() -> void:
	var layer := CanvasLayer.new()
	add_child(layer)
	var ui := Control.new()
	hud = ui
	layer.add_child(ui)
	ui.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	ui.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var framing := VBoxContainer.new()
	framing.position = Vector2(25, 23)
	ui.add_child(framing)
	var title := label("RICH'S HOUSEBOAT", 15, Color("#e2ba84"))
	framing.add_child(title)
	objective = label("Board the houseboat", 29, Color("#fff5de"))
	framing.add_child(objective)
	instruction = label("WASD  Walk onto the deck", 17, Color("#e0e8e3"))
	framing.add_child(instruction)
	progress = ProgressBar.new()
	progress.custom_minimum_size = Vector2(220, 8)
	progress.max_value = 1
	progress.show_percentage = false
	progress.hide()
	framing.add_child(progress)
	marker = label("", 16, Color("#fff0cb"))
	ui.add_child(marker)
	fps = label("", 14, Color("#e0e8e3"))
	fps.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	fps.offset_left = -142
	fps.offset_right = -14
	fps.offset_top = 21
	fps.hide()
	ui.add_child(fps)
	var crosshair := ColorRect.new()
	crosshair.mouse_filter = Control.MOUSE_FILTER_IGNORE
	crosshair.color = Color("#f6e7c9")
	ui.add_child(crosshair)
	crosshair.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	crosshair.offset_left = -2
	crosshair.offset_top = -2
	crosshair.offset_right = 2
	crosshair.offset_bottom = 2


func label(text: String, size: int, color: Color) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size", size)
	result.add_theme_color_override("font_color", color)
	result.add_theme_color_override("font_outline_color", Color("#172b37"))
	result.add_theme_constant_override("outline_size", 6)
	result.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return result


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * mouse_sensitivity
		pitch = clampf(pitch - event.relative.y * mouse_sensitivity, -1.38, 1.38)
		update_view()
	elif event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	elif event is InputEventKey and event.pressed and not event.echo:
		if event.physical_keycode == KEY_ESCAPE:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		elif event.physical_keycode == KEY_E and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			interact()
		elif event.physical_keycode == KEY_F3:
			fps.visible = not fps.visible
		elif event.physical_keycode == KEY_F5:
			get_tree().reload_current_scene()


func update_view() -> void:
	player.rotation.y = yaw
	eye.rotation.x = pitch


func aboard() -> bool:
	return vessel.supports_deck(player.global_position)


func near_wheel() -> bool:
	return aboard() and player.global_position.distance_to(vessel.to_global(vessel.helm_anchor())) < 1.1


func interact() -> void:
	if driving:
		driving = false
		vessel.throttle = 0.0
	elif near_wheel():
		driving = true
		vessel.departed = true
		yaw = vessel.heading
		pitch = -0.095
		player.velocity = Vector3.ZERO
		update_view()


func axis(positive: Key, negative: Key) -> float:
	return float(Input.is_physical_key_pressed(positive)) - float(Input.is_physical_key_pressed(negative))


func _physics_process(delta: float) -> void:
	clock += delta
	var has_input := Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
	move_on_river(delta, has_input)
	update_cargo(delta, has_input and Input.is_physical_key_pressed(KEY_R))
	if pulled and not landed and vessel.center.distance_to(BUOY_MOOR) <= 4.25 and absf(vessel.speed) < 1.4:
		landed = true
		vessel.throttle = 0.0
	water.set_shader_parameter("clock", clock)
	update_hud()


func move_on_river(delta: float, has_input: bool) -> void:
	var rudder := 0.0
	if driving and has_input:
		vessel.throttle = clampf(vessel.throttle + axis(KEY_W, KEY_S) * delta * 0.90, -0.32, 1.0)
		rudder = axis(KEY_D, KEY_A)
	var previous_heading: float = vessel.heading
	step_vessel(delta, rudder)
	if driving:
		player.global_position = vessel.to_global(vessel.helm_anchor())
		yaw += vessel.heading - previous_heading
		update_view()
	else:
		var walk := Vector3.ZERO
		if has_input:
			walk = Vector3(axis(KEY_D, KEY_A), 0, -axis(KEY_W, KEY_S)).normalized().rotated(Vector3.UP, yaw)
		move_on_foot(delta, walk, has_input and Input.is_physical_key_pressed(KEY_SPACE))
	boarded = boarded or aboard()


func move_on_foot(delta: float, walk: Vector3, jump: bool) -> void:
	player.velocity.x = walk.x * 3.75 * walk_multiplier
	player.velocity.z = walk.z * 3.75 * walk_multiplier
	player.velocity.y -= delta * 13.0
	if player.is_on_ceiling() and player.velocity.y > 0:
		player.velocity.y = 0
	if jump and player.is_on_floor():
		player.velocity.y = 4.0
	player.move_and_slide()
	if player.global_position.y < -0.49 and not can_wade_at(player.global_position):
		player.global_position = recover_after_fall()
		player.velocity = Vector3.ZERO


func step_vessel(delta: float, rudder: float) -> void:
	vessel.sail(delta, clock, driving, rudder)


func recover_after_fall() -> Vector3:
	return vessel.to_global(vessel.board_anchor()) if boarded else spawn_point


func can_wade_at(_point: Vector3) -> bool:
	return false


func floating(node: Node3D, location: Vector3) -> void:
	var x := location.x
	var z := location.z
	var height := Swell.height(x, z, clock)
	node.position = Vector3(x, height, z)
	node.rotation.x = (Swell.height(x, z + 0.25, clock) - height) * -3.0
	node.rotation.z = (Swell.height(x + 0.25, z, clock) - height) * 3.0


func can_cast() -> bool:
	if pulled or not aboard():
		return false
	var target := crate.global_position + Vector3.UP * 0.30
	var offset := target - eye.global_position
	if offset.length_squared() > LINE_RANGE * LINE_RANGE or -eye.global_basis.z.dot(offset.normalized()) < 0.956:
		return false
	var cast := PhysicsRayQueryParameters3D.create(eye.global_position, target, 1, [player.get_rid()])
	return get_world_3d().direct_space_state.intersect_ray(cast).is_empty()


func update_cargo(delta: float, held: bool) -> void:
	floating(buoy, BUOY_MOOR)
	if pulled:
		return
	if not hauling:
		floating(crate, CRATE_MOOR + Vector3(sin(clock * 0.42) * 0.37, 0, cos(clock * 0.47) * 0.22))
		if held and can_cast():
			hauling = true
			cast_origin = crate.position
			haul_progress = 0.0
	if not hauling:
		return
	if not aboard() or crate.position.distance_to(player.position) > LINE_RANGE + 4.0:
		haul_progress = 0.0
		hauling = false
		rope.hide()
		return
	haul_progress = clampf(haul_progress + delta * (0.58 if held else -0.25), 0.0, 1.0)
	if haul_progress <= 0.0 and not held:
		hauling = false
		rope.hide()
		return
	var tray: Vector3 = vessel.to_global(Vector3(0.91, 0.75, -2.13))
	var pull := cast_origin.lerp(tray, haul_progress)
	pull.y += sin(haul_progress * PI) * 0.67
	crate.position = pull
	var line_start := eye.global_position + eye.global_basis.x * 0.31 - eye.global_basis.y * 0.34 - eye.global_basis.z * 0.35
	var line_end := crate.position + Vector3.UP * 0.25
	rope.show()
	rope.position = (line_start + line_end) * 0.5
	rope.basis = Basis.looking_at(line_end - line_start).scaled_local(Vector3(1, 1, line_start.distance_to(line_end)))
	if haul_progress >= 1.0:
		pulled = true
		hauling = false
		rope.hide()
		crate.reparent(vessel)
		crate.position = Vector3(0.88, 0.75, -2.10)
		crate.rotation = Vector3(0, -0.14, 0)


func update_hud() -> void:
	var focus: Vector3
	var marker_text: String
	var show_marker := true
	if landed:
		objective.text = "Salvage delivered"
		instruction.text = "F5  Start a fresh trip"
		show_marker = false
	elif not boarded:
		objective.text = "Board the houseboat"
		instruction.text = "WASD  Walk onto the deck"
		focus = vessel.to_global(Vector3(-1.05, 1.14, -1.1))
		marker_text = "Board here"
	elif hauling:
		objective.text = "Pull the crate aboard"
		instruction.text = "Keep holding R"
		show_marker = false
	elif pulled:
		objective.text = "Bring the crate to the green buoy"
		instruction.text = helm_hint("Slow down as you approach")
		focus = buoy.global_position + Vector3.UP * 1.65
		marker_text = "Delivery buoy"
	else:
		objective.text = "Recover the floating crate"
		if eye.global_position.distance_to(crate.global_position) > LINE_RANGE and not driving:
			instruction.text = helm_hint("Walk to the wheel at the front of the cabin")
			focus = vessel.to_global(Boat.HELM + Vector3.UP * 0.70)
			marker_text = "Helm"
		else:
			instruction.text = "Hold R  Haul the crate" if can_cast() else helm_hint("Look at the crate and hold R")
			focus = crate.global_position + Vector3.UP * 0.67
			marker_text = "Salvage"
	if Input.mouse_mode == Input.MOUSE_MODE_VISIBLE and DisplayServer.get_name() != "headless":
		instruction.text = "Click to play  /  WASD to move" if not boarded else "Click to resume  /  F5 to restart"
	progress.visible = hauling
	progress.value = haul_progress
	marker.visible = show_marker and not eye.is_position_behind(focus)
	if marker.visible:
		var point := eye.unproject_position(focus)
		var metres := roundi(eye.global_position.distance_to(focus))
		var screen := get_viewport().get_visible_rect().size
		marker.text = "%s  ·  %d m" % [marker_text, metres]
		marker.position = Vector2(clampf(point.x - 49, 15, screen.x - 151), clampf(point.y - 10, 124, screen.y - 40))
	fps.text = "%d FPS  /  GL" % Engine.get_frames_per_second()


func helm_hint(alt: String) -> String:
	if driving:
		return "W/S  Throttle   A/D  Steer   E  Leave helm"
	if near_wheel():
		return "E  Take the helm"
	return alt
