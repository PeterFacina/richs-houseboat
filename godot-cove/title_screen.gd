extends Node3D

const Kit = preload("res://scenery.gd")
const Boat = preload("res://houseboat.gd")
const Rich = preload("res://rich_model.gd")
const MenuTheme = preload("res://river_menu_theme.gd")
const Settings = preload("res://river_pause.gd")
const PLAY_SCENE := "res://fishing.tscn"

@onready var shore = $Shore
@onready var menu_layer: CanvasLayer = $Menu

var boat: Boat
var rich: Rich
var beer: Node3D
var beer_mount: Basis
var clock := 0.0
var menu: VBoxContainer
var start: Button
var multiplayer_button: Button
var settings_button: Button
var status: Label
var settings: Settings
var loading := false
var open_lobby := false
var arrival_message := ""


func _ready() -> void:
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	shore.build()
	build_crash()
	build_rich()
	var camera := Camera3D.new()
	add_child(camera)
	camera.position = Vector3(-10.3, 4.25, 7.60)
	camera.look_at(Vector3(-2.0, 1.75, -2.0))
	camera.fov = 43.0
	camera.far = 190.0
	camera.current = true
	build_menu()
	animate_rich(.5)


func build_crash() -> void:
	boat = Boat.new()
	boat.center = Vector3(0, .86, 0)
	boat.river_engine = true
	boat.hull_name = "RICH'S"
	add_child(boat)
	# Only the motor is stepped in the title scene. The hull stays fixed in the sod.
	boat.rotation_degrees = Vector3(16, 0, -3.0)
	boat.motor.rpm = 1850.0
	shore.set_prop_wash(boat.motor.prop.global_position, boat.motor.wash_direction())
	var chair := Node3D.new()
	chair.name = "TippedDeckChair"
	boat.add_child(chair)
	chair.position = Vector3(-.92, .80, -2.13)
	chair.rotation = Vector3(-.07, -.29, .67)
	var aluminum := Kit.paint(Color("#c4c4b6"), .38, .54)
	var canvas := Kit.paint(Color("#c47948"), .91)
	for x: float in [-.225, .225]:
		var front := Vector3(x, .01, .24)
		var back := Vector3(x, .01, -.23)
		Kit.beam(chair, front, Vector3(x, .44, -.22), .027, aluminum)
		Kit.beam(chair, back, Vector3(x, .45, .18), .027, aluminum)
		Kit.beam(chair, Vector3(x, .40, -.18), Vector3(x, .87, -.32), .027, aluminum)
	Kit.beam(chair, Vector3(-.24, .87, -.32), Vector3(.24, .87, -.32), .027, aluminum)
	Kit.box_at(chair, Vector3(0, .43, -.015), Vector3(.43, .024, .38), canvas)
	Kit.box_at(chair, Vector3(0, .70, -.27), Vector3(.43, .31, .021), canvas).rotation.x = -.28


func build_rich() -> void:
	rich = Rich.new()
	rich.name = "Rich"
	add_child(rich)
	var spot := Vector2(-3.47, -2.36)
	rich.position = Vector3(spot.x, shore.ground_height(spot.x, spot.y), spot.y)
	rich.rotation.y = .72
	rich.build()
	rich.wrists[0].get_node("BoxEndWrench").hide()
	beer = rich.wrists[1].get_node("BeerCan")
	beer.reparent(rich.wrists[0], false)
	beer.position = Vector3(.029, -.065, .036)
	beer.rotation.z = -.20
	beer_mount = beer.basis


func _process(delta: float) -> void:
	clock += delta
	boat.motor.run(delta, .16, 0.0, true, 0.0)
	animate_rich(delta)
	if loading:
		finish_loading()


func animate_rich(delta: float) -> void:
	var beat := fposmod(clock, 10.8)
	var sip := smoothstep(2.6, 4.1, beat) * (1.0 - smoothstep(5.2, 6.8, beat))
	rich.pose(delta, clock, .61 - .12 * sip, .20 + .035 * sip, "", 0.0, 0.0)
	rich.torso.position.x = -.043
	rich.torso.rotation.z += .055
	rich.legs[0].position = Vector3(-.106, .016, .032)
	rich.legs[1].position = Vector3(.154, -.017, -.075)
	rich.legs[1].rotation = Vector3(-.046, .26, .062)

	var can_rest := rich.to_global(Vector3(-.294, .89 + .013 * sin(clock * 1.55), .205))
	var sip_axis := rich.head.global_basis.orthonormalized()
	var can_basis := rich.global_basis * Basis(Vector3.RIGHT, lerpf(.10, -.97, sip))
	var lip := rich.head.to_global(Vector3(-.015, .073, .078))
	var can_at_mouth := lip + sip_axis.z * .015 - can_basis.y * .055
	var wrist_basis := can_basis * beer_mount.inverse()
	var wrist_target := can_rest.lerp(can_at_mouth, sip) - wrist_basis * beer.position
	pose_beer_arm(wrist_target, wrist_basis)


func pose_beer_arm(target: Vector3, wrist_basis: Basis) -> void:
	var upper := rich.upper_arms[0]
	var elbow := rich.elbows[0]
	var wrist := rich.wrists[0]
	var shoulder := upper.global_position
	var upper_length := absf(elbow.position.y)
	var lower_length := wrist.position.length()
	var reach := target - shoulder
	var direction := reach.normalized()
	var distance := clampf(reach.length(), .10, upper_length + lower_length - .001)
	var along := (distance * distance + upper_length * upper_length - lower_length * lower_length) / (2.0 * distance)
	var outward := (-rich.global_basis.x * .79 - rich.global_basis.y * .61).slide(direction).normalized()
	var to_elbow := direction * along + outward * sqrt(maxf(0.0, upper_length * upper_length - along * along))
	var forearm := direction * distance - to_elbow
	var up := -to_elbow.normalized()
	var front := forearm.slide(up).normalized()
	upper.global_basis = Basis(up.cross(front), up, front)
	elbow.rotation.x = -to_elbow.angle_to(forearm)
	rich.arm_surfaces[0].set_shader_parameter("elbow_angle", elbow.rotation.x)
	wrist.global_basis = wrist_basis


func build_menu() -> void:
	var gradient := Gradient.new()
	gradient.offsets = PackedFloat32Array([0.0, .40, 1.0])
	gradient.colors = PackedColorArray([Color("#101d25f2"), Color("#101d25aa"), Color("#101d2500")])
	var shade := GradientTexture2D.new()
	shade.gradient = gradient
	var scrim := TextureRect.new()
	scrim.texture = shade
	scrim.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	scrim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	menu_layer.add_child(scrim)
	scrim.set_anchors_and_offsets_preset(Control.PRESET_LEFT_WIDE)
	scrim.offset_right = 570

	menu = VBoxContainer.new()
	menu.theme = MenuTheme.get_theme()
	menu.position = Vector2(MenuTheme.MARGIN, 59)
	menu.add_theme_constant_override("separation", 15)
	menu_layer.add_child(menu)
	var heading := VBoxContainer.new()
	heading.add_theme_constant_override("separation", -17)
	menu.add_child(heading)
	for line in [MenuTheme.text("RICH’S", 69, MenuTheme.GOLD, true), MenuTheme.text("HOUSEBOAT", 62, MenuTheme.CREAM, true)]:
		line.add_theme_color_override("font_shadow_color", Color("#132027ad"))
		line.add_theme_constant_override("shadow_offset_y", 3)
		heading.add_child(line)

	var actions := VBoxContainer.new()
	actions.add_theme_constant_override("separation", MenuTheme.GAP)
	actions.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	menu.add_child(actions)
	start = add_action(actions, "Play Solo", true, func(): launch(false))
	var has_multiplayer := ClassDB.class_exists("ENetMultiplayerPeer")
	var crew_text := "Multiplayer" if has_multiplayer else "Multiplayer  ·  Coming Soon"
	multiplayer_button = add_action(actions, crew_text, false, func(): launch(true))
	multiplayer_button.disabled = not has_multiplayer
	settings = Settings.new()
	menu_layer.add_child(settings)
	settings.setup()
	settings_button = add_action(actions, "Settings", false, settings.open)
	settings.visibility_changed.connect(func():
		menu.visible = not settings.visible
		if menu.visible and is_instance_valid(settings_button):
			settings_button.grab_focus())
	status = MenuTheme.text("", 15, MenuTheme.CREAM)
	status.text = arrival_message
	status.visible = not arrival_message.is_empty()
	menu.add_child(status)
	start.grab_focus()


func add_action(parent: VBoxContainer, caption: String, primary: bool, action: Callable) -> Button:
	var button := MenuTheme.button(caption, &"TitleStart" if primary else &"TitleAction")
	button.custom_minimum_size.x = 249
	button.alignment = HORIZONTAL_ALIGNMENT_LEFT
	button.add_theme_font_size_override("font_size", 18)
	button.pressed.connect(action)
	parent.add_child(button)
	return button


func launch(multiplayer_trip: bool) -> void:
	if start.disabled:
		return
	var error := ResourceLoader.load_threaded_request(PLAY_SCENE, "PackedScene")
	if error != OK:
		launch_failed(error)
		return
	open_lobby = multiplayer_trip
	status.text = "Opening lobby…" if open_lobby else "Launching…"
	status.show()
	start.disabled = true
	multiplayer_button.disabled = true
	settings_button.disabled = true
	# Draw the loading state before the river's main-thread scene setup.
	await get_tree().process_frame
	await get_tree().process_frame
	loading = true


func finish_loading() -> void:
	var progress := ResourceLoader.load_threaded_get_status(PLAY_SCENE)
	if progress == ResourceLoader.THREAD_LOAD_IN_PROGRESS:
		return
	loading = false
	if progress != ResourceLoader.THREAD_LOAD_LOADED:
		launch_failed(ERR_CANT_OPEN)
		return
	var packed := ResourceLoader.load_threaded_get(PLAY_SCENE) as PackedScene
	var game := packed.instantiate()
	game.multiplayer_trip = open_lobby
	var error := get_tree().change_scene_to_node(game)
	if error != OK:
		game.free()
		launch_failed(error)


func launch_failed(error: Error) -> void:
	status.text = "Couldn’t open the river. " + error_string(error)
	status.show()
	start.disabled = false
	multiplayer_button.disabled = not ClassDB.class_exists("ENetMultiplayerPeer")
	settings_button.disabled = false
	start.grab_focus()
