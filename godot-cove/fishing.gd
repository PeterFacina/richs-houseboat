extends "res://cove.gd"

const Ottawa = preload("res://ottawa_map.gd")
const Rig = preload("res://fishing_rig.gd")
const WaterFX = preload("res://fishing_water_fx.gd")
const Fish = preload("res://river_fish.gd")
const Species = preload("res://fish_species.gd")
const Stock = preload("res://river_stock.gd")
const Finder = preload("res://fish_finder.gd")
const Guide = preload("res://fish_guide.gd")
const Cabin = preload("res://cabin_life.gd")
const Trophy = preload("res://trophy_muskie.gd")
const Campaign = preload("res://river_campaign.gd")
const MarinaCars = preload("res://marina_cars.gd")
const Wharf = preload("res://marina_wharf.gd")
const Backpack = preload("res://river_backpack.gd")
const Cheats = preload("res://river_cheats.gd")
const LawnMower = preload("res://lawn_mower.gd")
const ShannonJob = preload("res://shannon_job.gd")
const PublicWorks = preload("res://public_works.gd")
const PauseMenu = preload("res://river_pause.gd")
const Safety = preload("res://river_safety.gd")
const RiverChart = preload("res://river_chart.gd")
const MenuTheme = preload("res://river_menu_theme.gd")
const Lobby = preload("res://river_lobby.gd")
const AircraftSteering = preload("res://aircraft_steering.gd")
const Regions = preload("res://river_regions.gd")
const Helicopter = preload("res://river_helicopter.gd")
const SoloSaves = preload("res://solo_saves.gd")
const CREW_JOURNAL := "user://ottawa_multiplayer_catches.json"
const BITE_WINDOW := 2.27
const WINDUP := 0.19
const SWIM_ENTRY_DEPTH := 1.16
const SWIM_EXIT_DEPTH := .95
const SWIM_FEET_DEPTH := 1.22
enum Fishing { READY, CASTING, WAITING, BITE, FIGHT, RETRIEVING, NET_READY, LANDING, DISPLAY, RELEASING }
enum ChartDestination { MARINA, SWISHA, CHALK_RIVER, LAMURE, BOAT, PINE, BIRCH, CAMP, HELIPAD, CEMETERY, SKI }
const TELEPORT_NAMES := {
	ChartDestination.MARINA: "Deep River Marina",
	ChartDestination.SWISHA: "Swisha Dam",
	ChartDestination.CHALK_RIVER: "Chalk River Labs",
	ChartDestination.LAMURE: "Lamure Beach",
	ChartDestination.PINE: "Pine Beach / Pine Reach",
	ChartDestination.BIRCH: "Birch Beach / Birch Point",
	ChartDestination.CAMP: "Pine Reach campfire",
	ChartDestination.BOAT: "Return to boat",
	ChartDestination.HELIPAD: "McAnulty Road helipad",
	ChartDestination.CEMETERY: "Deep River Cemetery",
	ChartDestination.SKI: "Mount Martin / ski trail",
}

@export_group("On-Foot Movement")
@export_range(3.76, 12.0, .05) var sprint_speed := 7.1
@export_range(.25, 3.75, .05) var crouch_speed := 1.65
@export_range(.6, 1.6, .01) var crouch_height := 1.13
@export_range(.05, .8, .01) var sprint_acceleration_time := .23
@export_range(.05, .8, .01) var sprint_deceleration_time := .18
@export_range(.05, .8, .01) var crouch_transition_time := .20

const MAX_STEP_HEIGHT := .24

var step_eye_offset := 0.0
var crouched := false
var crouch_camera_blend := 0.0
var sprint_blend := 0.0
var grounded_motion := false
var ground_motion := Vector3.ZERO
var stand_query := PhysicsShapeQueryParameters3D.new()

var river: Ottawa
var regions: Regions
var helicopter: Helicopter
var aircraft_steering := AircraftSteering.new()
var rig: Rig
var effects: WaterFX
var fish: Fish
var stock: Stock
var sonar: Finder
var sonar_overlay: TextureRect
var fish_guide: Guide
var cabin: Cabin
var trophy: Trophy
var properties := preload("res://property_management.gd").new()
var skill_screen := preload("res://progression_screen.tscn").instantiate()
var campaign: Campaign
var marina_cars: MarinaCars
var backpack: Backpack
var cheats: Cheats
var cheat_mouse_mode := Input.MOUSE_MODE_VISIBLE
var backpack_mouse_mode := Input.MOUSE_MODE_VISIBLE
var rig_slot := 0
var strike_depth := .45
var fight_profile: Dictionary = {}
var fishing := Fishing.READY
var cast_site: Vector3
var float_site: Vector3
var line_end: Vector3
var hooked_head: Vector3
var hooked_motion := Vector3.ZERO
var swim_heading := Vector3.FORWARD
var net_site: Vector3
var state_age := 0.0
var flight_time := 0.65
var bite_at := 0.0
var tap_at := 0.0
var tap_done := false
var drag_setting := 0.61
var line_out := 0.0
var line_tension := 0.0
var strain := 0.0
var slack_seconds := 0.0
var fight_age := 0.0
var run_start := 0.0
var run_end := 1.0
var run_turn := 1.0
var jump_at := -10.0
var jumps := 0
var on_top := false
var reel_rate := 0.0
var payout := 0.0
var hook_motion := 0.0
var catch_type := 0
var catch_length := 0
var catch_weight := 0.0
var hook_id := 0
var crew_scoop_helper := 0
var crew_scoop_name := ""
var catch_count := 0
var catch_note := ""
var note_until := 0.0
var live_label: Label
var tension_fill: StyleBoxFlat
var random := RandomNumberGenerator.new()
var journal: Array = []
var discovered_species := {}
var guide_book_page := ""
var chart := RiverChart.new()
var graphics := preload("res://river_graphics.gd").new()
var teleport_dialog: ConfirmationDialog
var teleport_destination: ChartDestination
var can_return_to_boat := false
var swimming := false
var target_index := -1
var rod_pressed := false
var interact_pressed := false
var ignition_hold := -1.0
var ignition_prompt: Label
var ignition_ring: IgnitionRing
var mower := LawnMower.new()
var spare_mower := LawnMower.new()
var shannon_job := ShannonJob.new()
var public_works := PublicWorks.new()
var flying := false
var pause_menu := PauseMenu.new()
var safety := Safety.new()
var jump_was_held := false
var multiplayer_trip := false
var solo_slot := 0
var lobby: Lobby
var leaving_trip := false
@export var launch_boat_scene: PackedScene = preload("res://launch_houseboat.tscn")


class IgnitionRing extends Control:
	var progress := 0.0:
		set(value):
			if progress != value:
				progress = value
				queue_redraw()

	func _draw() -> void:
		if progress <= 0.0:
			return
		var start := -PI * .5
		var end := start + TAU * progress
		var points := maxi(3, ceili(progress * 48.0))
		draw_arc(Vector2.ZERO, 13.0, start, end, points, Color(0, 0, 0, .65), 4.0, true)
		draw_arc(Vector2.ZERO, 13.0, start, end, points, Color.WHITE, 2.0, true)


func _ready() -> void:
	random.randomize()
	river = Ottawa.new()
	add_child(river)
	river.build()
	vessel = launch_boat_scene.instantiate() as Boat
	vessel.center = river.point(1)
	vessel.top_speed = 6.5
	vessel.water_check = river.can_sail
	vessel.marina_check = river.marina_hull_clear
	vessel.water_flow = river.downstream
	vessel.wave_sampler = river.wave_height
	vessel.river_engine = true
	vessel.hull_name = "RICH'S"
	vessel.heading = 0.0
	add_child(vessel)
	spawn_point = vessel.to_global(Vector3(-0.31, 0.81, -2.62))
	yaw = 1.07
	pitch = -0.27
	build_player()
	stand_query.shape = player_collision.shape.duplicate()
	stand_query.collision_mask = player.collision_mask
	stand_query.exclude = [player.get_rid()]
	eye.near = .070
	graphics.load_setting()
	boarded = true
	rig = Rig.new()
	eye.add_child(rig)
	rig.build_fists(eye)
	rig.hide()
	effects = WaterFX.new()
	effects.wave_sampler = river.wave_height
	add_child(effects)
	fish = Fish.new()
	add_child(fish)
	fish.hide()
	build_hud()
	build_ignition_prompt()
	fps.offset_left = -228
	fps.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	build_tension_display()
	backpack = Backpack.new()
	hud.add_child(backpack)
	backpack.equip_requested.connect(equip_gear)
	backpack.open_requested.connect(open_backpack)
	backpack.dismissed.connect(close_backpack)
	trophy = Trophy.new(river)
	cabin = Cabin.new()
	add_child(cabin)
	cabin.setup(vessel as Boat, player, eye, river, effects, rig, hud)
	cabin.occupied.connect(release_line)
	cabin.went_under.connect(pass_out)
	cabin.spill_overboard.connect(register_slick)
	cabin.message.connect(notify_angling)
	read_journal()
	make_chart()
	stock = Stock.new(river)
	stock.update(vessel.center)
	build_fish_finder()
	fish_guide = Guide.new()
	fish_guide.hide()
	hud.add_child(fish_guide)
	fish_guide.closed.connect(close_guide)
	campaign = Campaign.new()
	add_child(campaign)
	campaign.setup(self)
	add_child(properties)
	properties.setup(self)
	for site: Node3D in river.property_sites:
		properties.register_site(site)
	if not multiplayer_trip:
		for species_name: String in campaign.ledger.state.records:
			discovered_species["Muskellunge" if species_name == "Trophy muskellunge" else species_name] = true
	add_child(skill_screen)
	skill_screen.setup(self)
	regions = Regions.new()
	add_child(regions)
	regions.setup(self)
	make_waypoints()
	chart.setup_sections(regions.NAMES, regions.section_bounds())
	chart.set_highway(river.meta.streets)
	graphics.apply(river, eye)
	marina_cars = MarinaCars.new()
	marina_cars.name = "MarinaCars"
	add_child(marina_cars)
	marina_cars.setup(self, river, campaign.crew)
	var cheat_center := CenterContainer.new()
	cheat_center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(cheat_center)
	cheat_center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	cheats = Cheats.new()
	cheat_center.add_child(cheats)
	cheats.dismissed.connect(close_cheats)
	cheats.test_cash_requested.connect(campaign.add_test_cash)
	add_child(public_works)
	public_works.build(river)
	add_child(mower)
	mower.setup(river, public_works.at_ground(PublicWorks.PARKING[0]), PublicWorks.HEADING + PI)
	add_child(spare_mower)
	spare_mower.setup(river, public_works.at_ground(PublicWorks.PARKING[1]), PublicWorks.HEADING + PI, mower)
	add_child(shannon_job)
	shannon_job.setup(self, mower, public_works.to_global(Vector3(PublicWorks.SHANNON.x, public_works.office_floor, PublicWorks.SHANNON.y)),
		PublicWorks.HEADING, public_works.monitor_focus)
	safety.setup(self)
	hud.add_child(pause_menu)
	pause_menu.setup(self)
	for menu in [pause_menu, chart, campaign.board, campaign.boats_menu]:
		menu.visibility_changed.connect(update_menu_hud)
	helicopter = Helicopter.new()
	add_child(helicopter)
	helicopter.setup(self)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	if multiplayer_trip:
		open_multiplayer_lobby()


func open_multiplayer_lobby() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 20
	add_child(layer)
	lobby = Lobby.new()
	layer.add_child(lobby)
	lobby.setup(campaign.crew)
	lobby.dismissed.connect(return_to_title.bind(""))
	campaign.crew.changed.connect(session_changed)
	hud.hide()
	get_tree().paused = true


func session_changed() -> void:
	if is_instance_valid(lobby):
		if campaign.crew.started:
			if campaign.crew.is_guest():
				campaign.tick_client_ship(1.0)
			lobby.get_parent().queue_free()
			lobby = null
			hud.show()
			get_tree().paused = false
	elif campaign.crew.mode == "solo" and not leaving_trip:
		return_to_title(campaign.crew.status)


func save_trip() -> String:
	pause_menu.persist()
	if campaign.crew.is_guest():
		return ""
	campaign.ledger.save_file()
	return campaign.ledger.error


func leave_trip() -> String:
	if leaving_trip:
		return ""
	var error := save_trip()
	if error.is_empty():
		return_to_title("")
	return error


func return_to_title(message: String) -> void:
	if leaving_trip:
		return
	leaving_trip = true
	finish_return_to_title.call_deferred(message)


func finish_return_to_title(message: String) -> void:
	campaign.crew.stop()
	get_tree().paused = false
	var title := (load("res://title_screen.tscn") as PackedScene).instantiate()
	title.arrival_message = message
	get_tree().change_scene_to_node(title)


func update_menu_hud() -> void:
	var piloting := is_instance_valid(helicopter) and helicopter.my_seat() == 0
	crosshair.visible = not piloting
	var show_hud: bool = not (piloting or pause_menu.visible or chart.visible or campaign.board.visible or campaign.boats_menu.visible)
	(objective.get_parent() as Control).visible = show_hud
	marker.self_modulate.a = 1.0 if show_hud else 0.0
	campaign.info.self_modulate.a = marker.self_modulate.a
	var ambient_alpha := 0.0 if piloting else 1.0
	regions.region_label.self_modulate.a = ambient_alpha
	shannon_job.calendar.self_modulate.a = ambient_alpha
	fps.self_modulate.a = ambient_alpha
	(skill_screen.heading.get_parent() as Control).visible = not piloting
	skill_screen.banner.self_modulate.a = ambient_alpha


func build_tension_display() -> void:
	tension_fill = StyleBoxFlat.new()
	tension_fill.bg_color = Color("#71b69b")
	tension_fill.set_corner_radius_all(4)
	var back := StyleBoxFlat.new()
	back.bg_color = Color("#233638d8")
	back.set_corner_radius_all(4)
	progress.add_theme_stylebox_override("background", back)
	progress.add_theme_stylebox_override("fill", tension_fill)
	progress.custom_minimum_size = Vector2(250, 8)
	live_label = label("", 14, Color("#dddcd0"))
	progress.get_parent().add_child(live_label)
	live_label.hide()


func _input(event: InputEvent) -> void:
	if properties.panel.visible:
		properties.build_input(event)
		return
	if is_instance_valid(campaign) and campaign.boats_menu.visible:
		if event.is_action_pressed(&"ui_cancel"):
			campaign.boats_menu.close()
			get_viewport().set_input_as_handled()
		return
	if skill_screen.is_inside_tree() and not get_tree().paused:
		if campaign.board.visible and event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_K:
			campaign.close_board()
			skill_screen.toggle()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventJoypadButton and event.pressed and ((event.button_index == JOY_BUTTON_BACK and (skill_screen.panel.visible or not menu_blocks_play())) or (event.button_index == JOY_BUTTON_B and skill_screen.panel.visible)):
			skill_screen.toggle()
			get_viewport().set_input_as_handled()
			return
		if event is InputEventKey and event.pressed and not event.echo and ((event.physical_keycode == KEY_K and (skill_screen.panel.visible or not menu_blocks_play())) or (event.physical_keycode in [KEY_ESCAPE, KEY_B] and skill_screen.panel.visible)):
			skill_screen.toggle()
			get_viewport().set_input_as_handled()
			return
		if skill_screen.panel.visible:
			return
	if pause_menu.visible:
		return
	if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_ESCAPE \
			and not teleport_dialog.visible and not menu_blocks_play():
		pause_menu.open()
		get_viewport().set_input_as_handled()
		return
	if teleport_dialog.visible:
		return
	if not event is InputEventKey or not event.pressed or event.echo:
		return
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if cheats.visible:
		if key == KEY_F2 or key == KEY_ESCAPE:
			close_cheats()
			get_viewport().set_input_as_handled()
		return
	if key == KEY_F2 and not chart.visible and not fish_guide.visible and not backpack.inventory.visible \
			and not campaign.controls_blocked() and not cabin.busy() and marina_cars.active < 0 and mower.rider == null:
		if campaign.crew.mode == "solo":
			cheat_mouse_mode = Input.mouse_mode
			sonar_overlay.hide()
			cheats.show()
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			notify_angling("Cheats are available in solo play.", 3.0)
		get_viewport().set_input_as_handled()
		return
	if backpack.inventory.visible:
		if key == KEY_I or key == KEY_ESCAPE:
			close_backpack()
			get_viewport().set_input_as_handled()
		return
	if key == KEY_I and not chart.visible and not fish_guide.visible and not campaign.controls_blocked():
		open_backpack()
		get_viewport().set_input_as_handled()
		return
	if mower.rider != null:
		if key == KEY_E and play_input():
			interact_pressed = true
		elif key == KEY_X and play_input():
			mower.blades = not mower.blades
			if mower.blades:
				mower.last_cut = Vector3.INF
		elif key == KEY_C and play_input():
			mower.chase_view = not mower.chase_view
		elif key in [KEY_Q, KEY_R] and play_input():
			mower.shift_throttle(1 if key == KEY_R else -1)
		elif key in [KEY_ESCAPE, KEY_F3, KEY_F4, KEY_F5]:
			return
		get_viewport().set_input_as_handled()
		return
	if marina_cars.active >= 0:
		return
	if campaign.handle_modal(event, key):
		get_viewport().set_input_as_handled()
		return
	if campaign.controls_blocked():
		return
	if cabin.busy() and (key == KEY_J or key == KEY_TAB or key == KEY_M):
		get_viewport().set_input_as_handled()
		return
	if key == KEY_J and not (fish_guide.visible and get_viewport().gui_get_focus_owner() is LineEdit):
		if fish_guide.visible:
			close_guide()
		else:
			open_fish_guide()
		get_viewport().set_input_as_handled()
		return
	if fish_guide.visible:
		if key == KEY_ESCAPE:
			close_guide()
			get_viewport().set_input_as_handled()
		return
	if key == KEY_TAB or key == KEY_M or (key == KEY_ESCAPE and chart.visible):
		if chart.visible:
			close_chart()
		else:
			open_chart()
		get_viewport().set_input_as_handled()


func _unhandled_input(event: InputEvent) -> void:
	if properties.panel.visible:
		return
	if skill_screen.panel.visible or campaign.boats_menu.visible or pause_menu.visible or fish_guide.visible \
			or teleport_dialog.visible or backpack.inventory.visible or cheats.visible:
		return
	if flying or mower.rider != null:
		if event is InputEventKey and event.pressed and not event.echo and event.physical_keycode == KEY_F4:
			change_draw_distance()
		elif not flying or not event is InputEventKey or event.physical_keycode in [KEY_ESCAPE, KEY_F3, KEY_F5]:
			super._unhandled_input(event)
		return
	if marina_cars.active >= 0:
		if event is InputEventMouseMotion and play_input():
			marina_cars.orbit(event.relative)
			return
		if event is InputEventKey and event.pressed and not event.echo:
			match event.physical_keycode:
				KEY_E:
					interact_pressed = play_input()
					return
				KEY_H:
					if play_input():
						marina_cars.toggle_lights()
					return
				KEY_C:
					if play_input():
						marina_cars.cycle_camera()
					return
				KEY_F4:
					change_draw_distance()
					return
				KEY_ESCAPE, KEY_F3, KEY_F5:
					super._unhandled_input(event)
			return
		if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
			super._unhandled_input(event)
		return
	if (not chart.visible or campaign.controls_blocked()) and campaign.handle_world(event):
		return
	if not chart.visible and campaign.crewplay.input(event):
		return
	if event is InputEventKey and event.pressed and not event.echo:
		var hotbar_slot := Backpack.HOTBAR_KEYS.find(event.physical_keycode)
		if hotbar_slot >= 0 and not chart.visible:
			backpack.flash_slot(hotbar_slot)
			var gear := backpack.shortcuts[hotbar_slot]
			equip_gear(Backpack.NONE if gear == backpack.equipped else gear)
			return
		match event.physical_keycode:
			KEY_F4:
				change_draw_distance()
				return
			KEY_1, KEY_2, KEY_3, KEY_4:
				var place := int(event.physical_keycode - KEY_1)
				if chart.visible and place < river.meta.places.size():
					target_index = place
				return
			KEY_R:
				if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not chart.visible:
					if driving:
						if play_input():
							vessel.nudge_throttle(1.0)
					else:
						rod_pressed = true
				return
			KEY_F:
				if driving:
					if play_input():
						vessel.nudge_throttle(-1.0)
				elif aboard() and not chart.visible:
					sonar_overlay.visible = not sonar_overlay.visible
				return
			KEY_E:
				interact_pressed = Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not chart.visible
				return
	if chart.visible and (event is InputEventMouseButton or event is InputEventMouseMotion):
		return
	if event is InputEventMouseButton and event.pressed and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if event.button_index == MOUSE_BUTTON_LEFT and campaign.marina_fuel.is_local_holder():
			return
		if event.button_index == MOUSE_BUTTON_LEFT and fists_available():
			rig.punch()
			return
		if not driving and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var amount := .055 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -.055
			drag_setting = clampf(drag_setting + amount, .28, .96)
			if fishing == Fishing.READY:
				notify_angling("Drag set to %d%%" % roundi(drag_setting * 100.0), 1.7)
			return
	super._unhandled_input(event)


func change_draw_distance() -> void:
	graphics.advance()
	graphics.apply(river, eye)
	notify_angling("Draw distance · " + graphics.description(), 3.0)


func _physics_process(delta: float) -> void:
	clock += delta
	var wants_flight := campaign.crew.mode == "solo" and cheats.flight.button_pressed and not in_aircraft()
	if wants_flight and marina_cars.active >= 0:
		cheats.flight.button_pressed = false
		wants_flight = false
	if flying != wants_flight:
		update_flight_mode(wants_flight)
	var has_input := play_input()
	campaign.run_shortcuts(has_input and not flying and mower.rider == null and marina_cars.active < 0)
	has_input = play_input()
	update_ignition(delta, has_input)
	var use_cabin: bool = has_input and not flying and mower.rider == null and marina_cars.active < 0 and aboard() and not vessel.skiff and not driving and absf(vessel.speed) <= 1.20
	use_cabin = use_cabin and not campaign.marina_fuel.is_local_holder()
	use_cabin = use_cabin and not campaign.crewplay.hands_busy()
	use_cabin = use_cabin and not campaign.amenities.seated()
	use_cabin = use_cabin and not in_aircraft()
	var fuel_press: bool = interact_pressed and has_input and can_use_fuel() and campaign.marina_fuel.interact()
	var reserved_press := fuel_press or (interact_pressed and has_input and campaign.launch_interaction() != "")
	var did_use := cabin.update(delta, clock, use_cabin, interact_pressed and not reserved_press,
		Input.is_physical_key_pressed(KEY_E) and not reserved_press)
	var can_use_yard := interact_pressed and has_input and can_talk_to_shannon()
	var office_leaf := public_works.office_handle(eye) if can_use_yard else -1
	var bay := public_works.nearby_door(eye) if can_use_yard else null
	public_works.advance(delta, player, mower, spare_mower)
	if interact_pressed and has_input and not fuel_press and not did_use and not cabin.busy():
		if marina_cars.active >= 0:
			marina_cars.interact()
		elif mower.rider != null:
			if not mower.dismount():
				notify_angling("Move to clear, level ground to get off the mower.", 2.4)
		elif office_leaf >= 0:
			public_works.toggle_office(office_leaf, eye)
		elif can_talk_to_shannon() and shannon_job.in_range():
			shannon_job.interact()
		elif bay != null:
			bay.toggle()
		elif can_mount_mower():
			if not mower.near(player, eye):
				var previous := mower
				mower = spare_mower
				spare_mower = previous
			release_line()
			sonar_overlay.hide()
			mower.mount(player)
			yaw = mower.yaw
			pitch = -.10
			update_view()
		elif can_board_from_water():
			campaign.keep_player_on_deck(vessel, vessel.board_anchor())
			set_swimming(false)
		elif not marina_cars.interact() and not campaign.local_interact() and (driving or near_wheel()):
			release_line()
			campaign.helm()
	interact_pressed = false
	has_input = play_input()
	walk_multiplier = cabin.walk_scale() * campaign.crewplay.movement_scale()
	helicopter.tick(delta, has_input and get_window().has_focus() and not cabin.busy())
	grounded_motion = false
	if flying or in_aircraft() or campaign.amenities.seated() or marina_cars.active >= 0 \
			or mower.rider != null or driving or campaign.dive.active:
		reset_foot_stance()
	if flying:
		fly(delta, has_input)
	elif in_aircraft():
		step_vessel(delta, 0.0)
	elif campaign.amenities.seated():
		step_vessel(delta, 0.0)
	elif marina_cars.active >= 0:
		step_vessel(delta, 0.0)
	elif mower.rider != null:
		step_vessel(delta, 0.0)
		var throttle := axis(KEY_W, KEY_S) if has_input else 0.0
		var steering := axis(KEY_A, KEY_D) if has_input else 0.0
		mower.cut_width = .71 * (1.0 + campaign.skill_effect(campaign.crew.my_id(), "sharp_blades") / 100.0)
		yaw += mower.drive(delta, throttle, steering)
		update_view()
	else:
		move_on_river(delta, (has_input or properties.aiming) and not cabin.busy())
	if mower.rider != null:
		eye.rotation.x = pitch
		mower.update_rider_camera(eye)
	elif marina_cars.active < 0 and not in_aircraft():
		eye.rotation.x = pitch + cabin.camera_pitch
		if driving:
			eye.position.y = vessel.helm_eye_height()
	campaign.amenities.pin_local()
	marina_cars.step(delta, axis(KEY_W, KEY_S), axis(KEY_D, KEY_A), Input.is_physical_key_pressed(KEY_SPACE),
		has_input and not cabin.busy())
	var viewpoint: Vector3 = vessel.center if aboard() else player.global_position
	river.update_water(viewpoint, clock)
	var wake: Vector3 = vessel.global_basis.z.slide(Vector3.UP).normalized()
	if vessel.speed < -.13:
		wake = -wake
	river.set_wake(vessel.motor.prop.global_position, wake, absf(vessel.speed), vessel.motor.thrust,
		vessel.motor.wash_direction(), vessel.wake_spread, vessel.wake_peak_speed)
	if trophy.update(delta, clock) and viewpoint.distance_squared_to(trophy.slick) < 48.0 * 48.0:
		var roll := trophy.circling(clock)
		effects.break_surface(effects.on_water(roll, clock), .94, "splash")
		notify_angling("A big fish rolled by the slick. Cast near the ripples.", 7.1)
	stock.update(viewpoint)
	update_fish_finder(delta)
	var free_hands := has_input and hands_available()
	if rod_pressed:
		rod_pressed = false
		if free_hands:
			use_rod()
	var lift := free_hands and Input.is_mouse_button_pressed(MOUSE_BUTTON_RIGHT) and fishing == Fishing.FIGHT
	tick_fishing(delta, free_hands and Input.is_physical_key_pressed(KEY_R), lift)
	render_fishing(delta, lift)
	campaign.tick(delta, has_input)
	marina_cars.hide_drivers()
	shannon_job.tick(delta, play_input() and can_talk_to_shannon())
	update_hud()
	campaign.mark_world()
	regions.tick(delta)
	safety.tick(delta)


func play_input() -> bool:
	return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not menu_blocks_play()


func _process(delta: float) -> void:
	if not is_instance_valid(campaign) or not is_instance_valid(rig.fists):
		return
	var fists_raised := fists_available()
	var empty_handed := backpack.equipped == Backpack.NONE and not menu_blocks_play() and hands_available()
	var visual_clock := clock + Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second)
	var pace := ground_motion.length() if grounded_motion else 0.0
	rig.update_hands(delta, visual_clock, empty_handed or fists_raised, fists_raised,
		pace, sprint_blend, smoothstep(0, 1, crouch_camera_blend))


func menu_blocks_play() -> bool:
	return properties.panel.visible or skill_screen.panel.visible or pause_menu.visible or chart.visible or fish_guide.visible or backpack.inventory.visible or cheats.visible or campaign.controls_blocked()


func close_cheats() -> void:
	cheats.hide()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = cheat_mouse_mode


func open_backpack() -> void:
	if flying or mower.rider != null or marina_cars.active >= 0:
		return
	if chart.visible or fish_guide.visible or campaign.controls_blocked() or backpack.inventory.visible:
		return
	if fishing != Fishing.READY:
		notify_angling("Press the equipped slot again to stow the rod and clear the line.", 3.8)
		return
	if cabin.busy() or not campaign.preview_id.is_empty():
		return
	backpack_mouse_mode = Input.mouse_mode
	if backpack.equipped != Backpack.NONE:
		backpack.select_gear(backpack.equipped)
	sonar_overlay.hide()
	backpack.inventory.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_backpack() -> void:
	backpack.inventory.hide()
	backpack.reveal_hotbar()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = backpack_mouse_mode


func equip_gear(gear: int) -> void:
	if gear == backpack.equipped:
		return
	if fishing != Fishing.READY:
		if gear != Backpack.NONE:
			notify_angling("Stow the rod before switching gear.", 3.2)
			return
		release_line()
	backpack.set_equipped(gear)


func fists_available() -> bool:
	return backpack.equipped == Backpack.FISTS and play_input() and hands_available()


func stow_for_fueling() -> void:
	release_line()
	equip_gear(Backpack.NONE)


func hands_available() -> bool:
	return can_use_fuel() and not campaign.marina_fuel.is_local_holder()


func can_use_fuel() -> bool:
	return not flying and mower.rider == null and marina_cars.active < 0 and not swimming and not driving and not cabin.hands_in_use() and not campaign.dive.active \
		and campaign.preview_id.is_empty() and not campaign.crewplay.hands_busy() and not campaign.amenities.seated() and not in_aircraft()


func move_on_foot(delta: float, walk: Vector3, jump: bool) -> void:
	if campaign.crew.mode != "solo":
		cheats.flight.button_pressed = false
		cheats.speed.button_pressed = false
	var boost := cheats.multiplier()
	if cheats.flight.button_pressed:
		set_swimming(false)
		player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING
		var climb := axis(KEY_SPACE, KEY_CTRL) if play_input() and not cabin.busy() else 0.0
		player.velocity = (walk + Vector3.UP * climb).limit_length(1.0) * 9.0 * boost
		player.move_and_slide()
		return
	if not swimming:
		player.motion_mode = CharacterBody3D.MOTION_MODE_GROUNDED
	walk *= boost
	var at := player.global_position
	var depth := river.depth_at(at) if at.y < .12 else 0.0
	if swimming:
		if depth <= SWIM_EXIT_DEPTH:
			set_swimming(false)
	elif at.y < -.46 and depth >= SWIM_ENTRY_DEPTH:
		set_swimming(true)
	if not swimming:
		if campaign.dive.active:
			super.move_on_foot(delta, walk, jump and not jump_was_held)
			jump_was_held = jump
			return
		if depth > 0.0:
			walk *= lerpf(1.0, .46, smoothstep(.04, .96, -at.y))
		var jump_pressed := jump and not jump_was_held
		jump_was_held = jump
		walk_on_ground(delta, walk, jump_pressed)
		return
	reset_foot_stance()
	var current := river.downstream(at, clock) * .35
	var speed := 2.05 * walk_multiplier
	var surface := river.wave_height(at, clock)
	var height := maxf(surface - SWIM_FEET_DEPTH, -depth + .14)
	var velocity := walk * speed + current
	velocity.y = clampf((height - at.y) * 7.0, -2.8, 3.5)
	player.velocity = player.velocity.lerp(velocity, 1.0 - exp(-delta * 9.0))
	player.move_and_slide()


func walk_on_ground(delta: float, walk: Vector3, jump_pressed: bool) -> void:
	var has_input := play_input() and not cabin.busy()
	if has_input:
		var wants_crouch := Input.is_action_pressed("crouch")
		if pause_menu.preferences.toggle_crouch:
			wants_crouch = crouched
			if player.is_on_floor() and Input.is_action_just_pressed("crouch"):
				wants_crouch = not crouched
		if wants_crouch and not crouched and player.is_on_floor():
			set_crouched(true)
		elif not wants_crouch and crouched and can_stand():
			set_crouched(false)
	var jump := jump_pressed and not crouched
	var wants_sprint := has_input and not crouched and player.is_on_floor() and not jump \
		and not walk.is_zero_approx() and Input.is_action_pressed("sprint")
	var was_sprinting := sprint_blend > 0.0
	if crouched or not player.is_on_floor() or jump:
		sprint_blend = 0.0
	else:
		var duration := sprint_acceleration_time if wants_sprint else sprint_deceleration_time
		sprint_blend = move_toward(sprint_blend, float(wants_sprint), delta / duration)
	var speed := crouch_speed if crouched else lerpf(WALK_SPEED, sprint_speed, sprint_blend)
	var input_motion := walk * speed / WALK_SPEED
	if not crouched and was_sprinting and walk.is_zero_approx() and has_input and player.is_on_floor():
		var previous := Vector3(player.velocity.x, 0, player.velocity.z)
		var scale := WALK_SPEED * maxf(walk_multiplier, .01)
		input_motion = previous.move_toward(Vector3.ZERO, sprint_speed * delta / sprint_deceleration_time) / scale
	var before := player.global_position
	var may_step := player.is_on_floor() and not jump
	super.move_on_foot(delta, input_motion, jump)
	var stepped := false
	if may_step:
		var desired := input_motion * WALK_SPEED * walk_multiplier * delta
		var travelled := (player.global_position - before).slide(Vector3.UP)
		if travelled.dot(desired.normalized()) < desired.length() * .55:
			stepped = try_walk_step(desired)
	grounded_motion = player.is_on_floor()
	if grounded_motion:
		var velocity := (player.global_position - before) / delta if stepped else player.get_real_velocity()
		ground_motion = (velocity - player.get_platform_velocity()).slide(Vector3.UP)
	else:
		sprint_blend = 0.0
	update_stance_camera(delta)


func try_walk_step(desired: Vector3) -> bool:
	if desired.length_squared() < .00001:
		return false
	var start := player.global_transform
	var lift := Vector3.UP * MAX_STEP_HEIGHT
	var forward := desired.normalized() * maxf(desired.length() + .025, .12)
	if not player.test_move(start, forward):
		return false
	if player.test_move(start, lift):
		return false
	var raised := start.translated(lift)
	if player.test_move(raised, forward):
		return false
	raised.origin += forward
	var landing := KinematicCollision3D.new()
	if not player.test_move(raised, -lift * 1.1, landing):
		return false
	if landing.get_normal().dot(Vector3.UP) < cos(player.floor_max_angle):
		return false
	var feet := raised.origin + landing.get_travel()
	var rise := feet.y - start.origin.y
	if rise < .025 or rise > MAX_STEP_HEIGHT:
		return false
	player.global_position = feet
	player.apply_floor_snap()
	step_eye_offset = minf(step_eye_offset + rise, MAX_STEP_HEIGHT)
	return true


func can_stand() -> bool:
	# Lift the query off the floor by the collision margin. A slightly conservative
	# ceiling check also leaves room for the standing camera's near plane.
	stand_query.transform = Transform3D(Basis.IDENTITY,
		player.global_position + Vector3.UP * (STANDING_HEIGHT * .5 + player.safe_margin))
	return get_world_3d().direct_space_state.intersect_shape(stand_query, 1).is_empty()


func set_crouched(active: bool) -> void:
	crouched = active
	var capsule := player_collision.shape as CapsuleShape3D
	capsule.height = crouch_height if active else STANDING_HEIGHT
	player_collision.position.y = capsule.height * .5


func update_stance_camera(delta: float) -> void:
	crouch_camera_blend = move_toward(crouch_camera_blend, float(crouched), delta / crouch_transition_time)
	var eye_height := lerpf(STANDING_EYE, crouch_height - .10, smoothstep(0, 1, crouch_camera_blend))
	if crouched and crouch_camera_blend < 1.0:
		var origin := player.global_position + Vector3.UP * (crouch_height - .10)
		var clearance := PhysicsRayQueryParameters3D.create(origin,
			player.global_position + Vector3.UP * (eye_height + eye.near), player.collision_mask, stand_query.exclude)
		var hit := get_world_3d().direct_space_state.intersect_ray(clearance)
		if not hit.is_empty():
			eye_height = minf(eye_height, hit.position.y - player.global_position.y - eye.near)
	step_eye_offset = move_toward(step_eye_offset, 0.0, delta * 1.85)
	eye.position.y = eye_height - step_eye_offset


func reset_foot_stance() -> void:
	sprint_blend = 0.0
	if crouched:
		set_crouched(false)
	if crouch_camera_blend > 0.0 or step_eye_offset > 0.0:
		crouch_camera_blend = 0.0
		step_eye_offset = 0.0
		if marina_cars.active < 0 and not in_aircraft() and not campaign.amenities.seated():
			eye.position.y = STANDING_EYE


func set_swimming(active: bool) -> void:
	if swimming == active:
		return
	swimming = active
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if active else CharacterBody3D.MOTION_MODE_GROUNDED
	if active:
		release_line()
		effects.break_surface(effects.on_water(player.global_position, clock), .45, "splash")


func can_board_from_water() -> bool:
	if flying or mower.rider != null or marina_cars.active >= 0:
		return false
	if not swimming or absf(vessel.speed) > 1.2:
		return false
	var entry: Vector3 = vessel.to_global(vessel.board_anchor())
	var gap := entry - player.global_position
	return Vector2(gap.x, gap.z).length_squared() <= 2.15 * 2.15


func step_vessel(delta: float, rudder: float) -> void:
	campaign.step_boat(delta, rudder)


func interact() -> void:
	super.interact()
	if driving:
		pitch = vessel.helm_view_pitch
		update_view()


func update_helm_throttle(delta: float, has_input: bool) -> void:
	vessel.hold_throttle(delta, axis(KEY_R, KEY_F) if has_input else 0.0, axis(KEY_W, KEY_S) if has_input else 0.0)


func at_ignition_key() -> bool:
	return driving and vessel.key_focused(eye)


func update_ignition(delta: float, has_input: bool) -> void:
	var focused := has_input and at_ignition_key()
	if focused and vessel.ignition == Boat.Ignition.RUN:
		ignition_hold = -1.0
		if interact_pressed:
			interact_pressed = false
			campaign.request("boat_ignition", "stop")
		return
	if focused and interact_pressed:
		interact_pressed = false
		if ignition_hold < 0.0:
			ignition_hold = 0.0
			campaign.request("boat_ignition", "start")
	if ignition_hold < 0.0:
		return
	var duration := Boat.START_TIME
	if not focused or not Input.is_physical_key_pressed(KEY_E):
		if ignition_hold < duration:
			campaign.request("boat_ignition", "cancel")
		ignition_hold = -1.0
	elif ignition_hold < duration:
		ignition_hold = minf(duration, ignition_hold + delta)
		if ignition_hold >= duration:
			campaign.request("boat_ignition", "finish")


func build_ignition_prompt() -> void:
	ignition_ring = IgnitionRing.new()
	ignition_ring.name = "IgnitionRing"
	ignition_ring.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ignition_ring)
	ignition_ring.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ignition_ring.hide()
	ignition_prompt = label("", 16, Color.WHITE)
	ignition_prompt.name = "IgnitionPrompt"
	ignition_prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(ignition_prompt)
	ignition_prompt.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
	ignition_prompt.offset_left = 23.0
	ignition_prompt.offset_right = 180.0
	ignition_prompt.offset_top = -13.0
	ignition_prompt.offset_bottom = 13.0
	ignition_prompt.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	ignition_prompt.hide()


func recover_after_fall() -> Vector3:
	if river.lamure.blocks_swim_area(player.global_position):
		var beach := river.point(3)
		beach.y = river.ground_height(beach.x, beach.z) + .10
		return beach
	return campaign.after_fall()


func can_wade_at(point: Vector3) -> bool:
	return river.depth_at(point) > 0.0


func close_guide() -> void:
	fish_guide.hide()
	if not guide_book_page.is_empty():
		campaign.open_board(guide_book_page)
		guide_book_page = ""
		return
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func pass_out() -> void:
	if driving:
		campaign.relinquish_helm()
	vessel.throttle = 0.0
	chart.hide()
	sonar_overlay.hide()
	fish_guide.hide()
	backpack.inventory.hide()
	release_line()


func register_slick(at: Vector3) -> void:
	trophy.start_slick(at, clock)
	if trophy.attracted:
		notify_angling("Over the side. Something might come up to the slick.", 4.8)


func build_fish_finder() -> void:
	var view := SubViewport.new()
	view.size = Finder.SIZE
	view.disable_3d = true
	view.render_target_update_mode = SubViewport.UPDATE_WHEN_VISIBLE
	add_child(view)
	sonar = Finder.new()
	view.add_child(sonar)
	var mount := Node3D.new()
	vessel.add_child(mount)
	mount.name = "HelmFishFinder"
	mount.position = Vector3(.63, 1.66, -2.36)
	mount.rotation = Vector3(-.36, -.17, .0)
	var dark := Kit.paint(Color("#273238"), .66)
	Kit.box_at(vessel, Vector3(.63, 1.14, -2.36), Vector3(.084, .76, .101), dark)
	Kit.box_at(mount, Vector3.ZERO, Vector3(.42, .255, .086), dark)
	var glass := QuadMesh.new()
	glass.size = Vector2(.379, .218)
	var active := StandardMaterial3D.new()
	active.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	active.albedo_texture = view.get_texture()
	Kit.mesh_at(mount, glass, Vector3(0, .005, .045), active)
	var transducer := Kit.box_at(vessel, Vector3(-.66, -.36, 3.31), Vector3(.17, .096, .235), dark)
	transducer.name = "Transducer"
	sonar_overlay = TextureRect.new()
	sonar_overlay.texture = view.get_texture()
	sonar_overlay.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	sonar_overlay.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	sonar_overlay.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(sonar_overlay)
	sonar_overlay.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	sonar_overlay.offset_left = -501.0
	sonar_overlay.offset_right = -23.0
	sonar_overlay.offset_top = 26.0
	sonar_overlay.offset_bottom = 300.0
	sonar_overlay.hide()


func update_fish_finder(delta: float) -> void:
	var source: Vector3 = vessel.to_global(Vector3(-.40, -.30, 2.12) if vessel.skiff else Vector3(-.66, -.36, 3.39))
	var surface := river.wave_height(source, clock)
	var water_column := river.depth_at(source)
	var depth := water_column + surface if surface > source.y and water_column > .25 else 0.0
	var bottom := clampf(.56 + .25 * sin(source.x * .027) * cos(source.z * .026), .05, .95)
	var current_speed: Vector3 = river.downstream(vessel.center, clock) * (.78 if vessel.departed else 0.0)
	var movement: Vector3 = -vessel.global_basis.z.slide(Vector3.UP).normalized() * vessel.speed + current_speed
	var read_echoes := func() -> Array[Vector2]:
		var echoes := stock.school_returns(source, clock, .51 + campaign.skill_effect(campaign.crew.my_id(), "fish_finder"))
		var draft := maxf(0.0, surface - source.y)
		for index in echoes.size():
			echoes[index].x += draft
		var large_echo := trophy.echo(source, clock, draft)
		if large_echo.y > 0.0:
			echoes.append(large_echo)
		return echoes
	sonar.update_pings(delta, depth, movement.length(), vessel.motor.rpm, read_echoes, bottom)


func notify_angling(message: String, length: float) -> void:
	catch_note = message
	note_until = clock + length


func change_state(next: Fishing) -> void:
	fishing = next
	state_age = 0.0


func release_line() -> void:
	change_state(Fishing.READY)
	line_tension = 0.0
	reel_rate = 0.0
	payout = 0.0
	effects.bobber.hide()
	effects.line.hide()
	effects.crank_sounds(0.0, 0.0)
	rig.net.hide()
	fish.hide()
	crew_scoop_helper = 0
	crew_scoop_name = ""
	river.clear_fish_shadow()
	trophy.hooked = false


func cast_position() -> Vector3:
	var direction := -eye.global_basis.z
	if direction.y > -0.038:
		return Vector3.INF
	var distance := (0.05 - eye.global_position.y) / direction.y
	if distance < 2.7 or distance > 37.0:
		return Vector3.INF
	var target := eye.global_position + direction * distance
	if not river.can_fish(target):
		return Vector3.INF
	var ray := PhysicsRayQueryParameters3D.create(eye.global_position, target, 1, [player.get_rid()])
	if not get_world_3d().direct_space_state.intersect_ray(ray).is_empty():
		return Vector3.INF
	return target


func rod_in_hand() -> bool:
	return backpack.equipped == Backpack.ROD and hands_available()


func can_use_rod() -> bool:
	return rod_in_hand() and (absf(vessel.speed) <= 1.45 if aboard() else campaign.can_fish_from_shore())


func use_rod() -> void:
	if not can_use_rod():
		return
	match fishing:
		Fishing.READY:
			var target := cast_position()
			if not target.is_finite():
				notify_angling("Aim the dot at open water.", 2.5)
				return
			cast_site = target
			flight_time = clampf(rig.tip.global_position.distance_to(target) / 15.0, .43, 1.24)
			change_state(Fishing.CASTING)
			effects.play_sound(rig.tip.global_position, "cast", -13.0)
		Fishing.WAITING:
			cast_origin = float_site
			change_state(Fishing.RETRIEVING)
		Fishing.BITE:
			set_hook()
		Fishing.NET_READY:
			change_state(Fishing.LANDING)
		Fishing.DISPLAY:
			change_state(Fishing.RELEASING)


func tick_fishing(delta: float, held: bool, lift := false) -> void:
	state_age += delta
	reel_rate = 0.0
	payout = 0.0
	hook_motion = minf(1, hook_motion + delta * 3.1)
	if fishing == Fishing.READY:
		return
	if not can_use_rod():
		release_line()
		return
	match fishing:
		Fishing.CASTING:
			tick_cast()
		Fishing.WAITING, Fishing.BITE:
			tick_float(delta)
		Fishing.RETRIEVING:
			var target := landing_position(cast_site)
			var seconds := clampf(cast_origin.distance_to(target) / 12.0, .42, 2.15)
			float_site = cast_origin.lerp(target, clampf(state_age / seconds, 0, 1))
			reel_rate = .95
			if state_age >= seconds:
				notify_angling("Line in. Tap R to cast again.", 1.6)
				release_line()
		Fishing.FIGHT:
			tick_fight(delta, held, lift)
		Fishing.NET_READY:
			var wave := river.wave_height(net_site, clock)
			hooked_head = hooked_head.lerp(Vector3(net_site.x, wave - .045, net_site.z), minf(1, delta * 4.5))
			if state_age > 11.0:
				notify_angling("The fish shook the hook.", 3.8)
				release_line()
		Fishing.LANDING:
			if state_age >= 1.06:
				record_catch()
				change_state(Fishing.DISPLAY)
		Fishing.RELEASING:
			if state_age >= .77 and state_age - delta < .77:
				effects.break_surface(effects.on_water(net_site, clock), .68, "splash")
			if state_age >= 1.44:
				notify_angling("Released  ·  %s" % Species.profile(catch_type).name, 3.2)
				release_line()


func tick_cast() -> void:
	if state_age < WINDUP:
		return
	if not effects.bobber.visible:
		cast_origin = rig.tip.global_position
		effects.bobber.show()
	var t := clampf((state_age - WINDUP) / flight_time, 0.0, 1.0)
	var water_y := river.wave_height(cast_site, clock)
	float_site = cast_origin.lerp(Vector3(cast_site.x, water_y, cast_site.z), t)
	float_site.y += 4.0 * t * (1.0 - t) * (0.58 + flight_time * 1.18)
	if t >= 1.0:
		effects.break_surface(float_site, .59, "splash")
		var depth := river.depth_at(cast_site)
		bite_at = clock + random.randf_range(5.0, 12.5) + Species.leader(rig_slot, depth) * .17
		if trophy.draws_bait(cast_site, clock):
			bite_at = maxf(clock + 2.6, trophy.ready_at + 1.1)
		tap_at = bite_at - random.randf_range(.70, 1.75)
		tap_done = false
		change_state(Fishing.WAITING)


func tick_float(delta: float) -> void:
	var flow := river_drift(float_site)
	var next := float_site + flow * delta
	if river.can_fish(next) and next.distance_to(cast_site) < 6.1:
		float_site = next
	if not tap_done and clock >= tap_at:
		tap_done = true
		effects.break_surface(effects.on_water(float_site, clock), .18)
	if fishing == Fishing.WAITING and clock >= bite_at:
		change_state(Fishing.BITE)
		effects.break_surface(effects.on_water(float_site, clock), .60, "bite")
	elif fishing == Fishing.BITE and state_age >= BITE_WINDOW:
		notify_angling("Missed the bite. Strike when the float goes under.", 3.8)
		change_state(Fishing.WAITING)
		bite_at = clock + random.randf_range(6.0, 12.0)
		tap_at = bite_at - 1.25
		tap_done = false


func river_drift(point: Vector3) -> Vector3:
	return river.downstream(point, clock)


func floating(node: Node3D, location: Vector3) -> void:
	var height := river.wave_height(location, clock)
	node.position = Vector3(location.x, height, location.z)
	node.rotation.x = (river.wave_height(location + Vector3.BACK * .25, clock) - height) * -3.0
	node.rotation.z = (river.wave_height(location + Vector3.RIGHT * .25, clock) - height) * 3.0


func choose_species() -> int:
	return stock.pick_for_bait(float_site, rig_slot, clock, random, campaign.skill_effect(campaign.crew.my_id(), "lucky_catch") / 100.0)


func landing_position(at: Vector3) -> Vector3:
	if not aboard():
		var feet := player.global_position
		feet.y = 0
		var toward := (Vector3(at.x, 0, at.z) - feet).normalized()
		for i in 18:
			var target := feet + toward * (.85 + i * .40)
			if river.can_fish(target):
				return target
		return at
	var outside: Vector3 = vessel.to_local(at)
	var deck: Vector3 = vessel.to_local(player.global_position)
	var edge := Vector3(signf(outside.x) * 1.68, 0, clampf(deck.z, -2.7, 2.8))
	if outside.z < -3.6 and absf(outside.x) < 2.5:
		edge = Vector3(clampf(outside.x * .20, -.64, .64), 0, -4.10)
	if vessel.skiff:
		edge = Vector3(signf(outside.x) * 1.18, 0, clampf(deck.z, -1.6, 1.6))
	var waterline: Vector3 = vessel.to_global(edge)
	waterline.y = 0.0
	return waterline


func set_hook() -> void:
	hook_id += 1
	if not campaign.crew.is_guest():
		campaign.ledger.state.catch_serial += 1
	var hooked_trophy := trophy.hook(random.randf()) if trophy.can_bite(float_site, clock) else -1
	catch_type = hooked_trophy if hooked_trophy >= 0 else choose_species()
	fight_profile = Species.profile(catch_type)
	var limits: Array = fight_profile.length_cm
	var sample := (random.randf() + random.randf()) * .5
	catch_length = roundi(lerpf(limits[0], limits[1], sample))
	if trophy.hooked:
		catch_length = random.randi_range(128, 141)
	catch_weight = Species.typical_weight(fight_profile, catch_length) * random.randf_range(.87, 1.12)
	fish.select_species(catch_type, catch_length)
	fish.show()
	change_state(Fishing.FIGHT)
	net_site = landing_position(float_site)
	strike_depth = Species.leader(rig_slot, river.depth_at(float_site))
	hooked_head = effects.on_water(float_site, clock) - Vector3.UP * strike_depth
	swim_heading = (hooked_head - net_site).slide(Vector3.UP).normalized()
	hooked_motion = swim_heading * .38
	line_out = rig.tip.global_position.distance_to(hooked_head) - .09
	line_tension = .12
	strain = 0.0
	slack_seconds = 0.0
	fight_age = 0.0
	run_start = 0.0
	run_end = 1.47
	run_turn = -1.0 if random.randf() < .5 else 1.0
	hook_motion = 0.0
	jump_at = -10.0
	jumps = 0
	on_top = false
	if trophy.hooked:
		notify_angling("Trophy muskie on the line. Let it run when the drag starts clicking.", 5.2)
	effects.break_surface(effects.on_water(float_site, clock), 1.08 if trophy.hooked else .75, "splash")


func tick_fight(delta: float, held: bool, lifting: bool) -> void:
	fight_age += delta
	var limits: Array = fight_profile.length_cm
	var percent_size := clampf(inverse_lerp(float(limits[0]), float(limits[1]), float(catch_length)), 0.0, 1.0)
	var endurance := lerpf(1.0, .46, smoothstep(8, 35, fight_age))
	if fight_age >= run_end + 1.29:
		run_start = fight_age
		run_end = fight_age + lerpf(.69, 1.75, smoothstep(7.0, 94.0, catch_length)) * random.randf_range(.79, 1.24)
		run_turn *= -1
		if jumps < 2 and fight_profile.form in ["bass", "esox", "salmonid", "gar"] and line_tension > .24 and -hooked_head.y < 2.2:
			jump_at = fight_age + .31
			jumps += 1
	var burst := smoothstep(run_start, run_start + .28, fight_age) * (1.0 - smoothstep(run_end - .35, run_end, fight_age))
	var final_run := fight_age - Trophy.LAST_RUN
	if trophy.hooked and final_run >= 0.0 and final_run < Trophy.RUN_SECONDS:
		burst = maxf(burst, smoothstep(0.0, .30, final_run) * (1.0 - smoothstep(.96, Trophy.RUN_SECONDS, final_run)))
		if final_run < delta:
			notify_angling("The muskie turned for one last run.", 3.4)
			effects.break_surface(effects.on_water(hooked_head, clock), 1.06, "splash")
	var separation := hooked_head - rig.tip.global_position
	var reach := separation.length()
	var spring := maxf(0.0, (reach - line_out) * .88)
	line_tension = lerpf(line_tension, clampf((spring + burst * .075) / (1.0 + campaign.skill_effect(campaign.crew.my_id(), "steady_hands") / 100.0), 0, 1.30), 1.0 - exp(-delta * 15.0))
	line_tension = maxf(line_tension, trophy.strain_floor(fight_age))
	payout = maxf(0.0, line_tension - drag_setting) * (5.7 + burst * 1.7)
	line_out += payout * delta
	var can_crank := held and payout < .39
	if can_crank:
		reel_rate = 1.0 - smoothstep(.58, .92, line_tension) * .61
		line_out = maxf(1.0, line_out - reel_rate * delta * (1.0 + campaign.skill_effect(campaign.crew.my_id(), "quick_reel") / 100.0) * (1.67 if lifting else 2.55))

	var radial := (hooked_head - net_site).slide(Vector3.UP)
	var outward := radial.normalized()
	var lateral := outward.cross(Vector3.UP)
	var thrust := (.23 + .29 * percent_size + burst * Species.burst(fight_profile, catch_length)) * endurance
	if trophy.hooked and not trophy.can_net(fight_age):
		thrust += .22 + .45 * burst
	var swimming := outward * thrust + lateral * (run_turn * burst * .91 + sin(fight_age * 3.4) * .18)
	var pulling := maxf(0.0, line_tension - .025) * (4.05 if lifting else 3.65)
	var rod_heading := separation.slide(Vector3.UP).normalized()
	var net_lead := 1.0 - smoothstep(1.45, 4.0, radial.length())
	var toward := rod_heading.lerp(outward, net_lead).normalized()
	var desired := swimming - toward * pulling + river_drift(hooked_head)
	if radial.length() < 1.85 and held:
		desired -= outward * .53
	hooked_motion = hooked_motion.lerp(desired, 1.0 - exp(-delta * 7.8))
	var candidate := hooked_head + hooked_motion * delta
	if river.can_fish(candidate):
		hooked_head = candidate
	else:
		run_turn *= -1
		hooked_motion *= -.15

	var jump := fight_age - jump_at
	var leaping := jump >= 0 and jump < .73
	var initial_depth := lerpf(strike_depth, minf(strike_depth, 1.57), smoothstep(0.0, 6.0, fight_age) * smoothstep(.09, .72, line_tension))
	var target_depth := lerpf(initial_depth + burst * .36, .027, 1.0 - smoothstep(.6, 5.8, radial.length()))
	target_depth = minf(target_depth, maxf(.063, river.depth_at(hooked_head) - .16))
	var water_y := river.wave_height(hooked_head, clock)
	if leaping:
		hooked_head.y = water_y + sin(jump / .73 * PI) * (.43 + percent_size * .15)
		if not on_top:
			effects.break_surface(effects.on_water(hooked_head, clock), .49, "splash")
	elif on_top:
		effects.break_surface(effects.on_water(hooked_head, clock), .76, "splash")
		hooked_head.y = water_y - .06
	else:
		hooked_head.y = lerpf(hooked_head.y, water_y - target_depth, 1.0 - exp(-delta * 4.6))
	on_top = leaping
	if hooked_motion.length_squared() > .05:
		swim_heading = swim_heading.lerp(hooked_motion.normalized(), 1.0 - exp(-delta * 8.0)).normalized()
	if line_tension > .99:
		strain += delta * (line_tension * 2.3 - 1.63)
	else:
		strain = maxf(0.0, strain - delta * .79)
	slack_seconds = slack_seconds + delta if reach < line_out - .34 else maxf(0, slack_seconds - delta * 2.6)
	if strain > .21:
		effects.play_sound(rig.tip.global_position, "snap", -5.5)
		var lost := "The muskie’s last run snapped your line." if trophy.strain_floor(fight_age) > 0.0 else "Line snapped. Back off the drag or let the fish run."
		notify_angling(lost, 4.9)
		campaign.request("rich_lost", null)
		release_line()
	elif slack_seconds > 4.3:
		notify_angling("The fish shook the hook. Reel in slack to keep tension.", 4.1)
		release_line()
	elif radial.length() <= .91 and line_tension < .94 and not leaping and trophy.can_net(fight_age):
		effects.break_surface(effects.on_water(hooked_head, clock), .35)
		change_state(Fishing.NET_READY)


func render_fishing(delta: float, lift: bool) -> void:
	rig.visible = rod_in_hand()
	if not trophy.hooked and trophy.attracted and clock >= trophy.ready_at and fishing < Fishing.FIGHT:
		var roll := trophy.circling(clock)
		var heading := (trophy.circling(clock + .15) - roll).slide(Vector3.UP).normalized()
		river.set_fish_shadow(roll, heading, maxf(0.0, river.wave_height(roll, clock) - roll.y), 1.34)
	elif fishing < Fishing.FIGHT:
		river.clear_fish_shadow()
	var cast_amount := state_age / WINDUP if fishing == Fishing.CASTING else -1.0
	var net_amount := clampf(state_age / 1.06, 0, 1) if fishing == Fishing.LANDING else (1.0 if fishing == Fishing.DISPLAY else 0.0)
	if fishing == Fishing.RELEASING:
		net_amount = 1.0 - smoothstep(0.0, .80, state_age)
	var bend_side := 0.0
	if fishing == Fishing.FIGHT or fishing == Fishing.NET_READY:
		var apparent := (hooked_head - eye.global_position).normalized()
		bend_side = eye.global_basis.x.dot(apparent)
	rig.pose_rod(delta, clock, line_tension, bend_side, cast_amount, hook_motion, lift, reel_rate, payout, net_amount)
	effects.crank_sounds(reel_rate, payout)
	effects.tick(delta, clock, eye.global_position)
	match fishing:
		Fishing.CASTING:
			if not effects.bobber.visible:
				return
			effects.bobber.global_position = float_site
			effects.bobber.rotation = Vector3(state_age * 6.5, state_age * 4.4, -.24)
			line_end = float_site
		Fishing.WAITING, Fishing.BITE, Fishing.RETRIEVING:
			floating(effects.bobber, float_site)
			var nibble := maxf(0, 1.0 - (clock - tap_at) * 2.1) if tap_done else 0.0
			effects.bobber.position.y -= .025 * nibble
			if fishing == Fishing.BITE:
				effects.bobber.position.y -= smoothstep(0.0, .31, state_age) * .189 + sin(state_age * 14.0) * .017
				effects.bobber.rotation.x += .49 * smoothstep(0.0, .16, state_age)
			line_end = effects.bobber.global_position + Vector3.UP * .047
		Fishing.FIGHT, Fishing.NET_READY:
			var wave := river.wave_height(hooked_head, clock)
			if fishing == Fishing.NET_READY:
				line_tension = move_toward(line_tension, .27, delta * .56)
			var attitude := -.26 * sin(clock * 7.5) if not on_top else sin(clampf((fight_age - jump_at) / .73, 0, 1) * PI * 2.0) * .54
			var heading := (swim_heading + Vector3.UP * attitude).normalized()
			fish.pose(hooked_head, heading, sin(clock * 10.7) * .24,
				.08 + .11 * minf(1, hooked_motion.length() / 2.15), clock * lerpf(16.0, 9.5, smoothstep(5.0, 94.0, catch_length)))
			river.set_fish_shadow(hooked_head, swim_heading, maxf(0, wave - hooked_head.y), fish.metres)
			line_end = hooked_head
		Fishing.LANDING, Fishing.DISPLAY, Fishing.RELEASING:
			effects.bobber.hide()
			effects.line.hide()
			river.clear_fish_shadow()
			rig.reel_hand.hide()
			var reach := effects.on_water(net_site, clock) if fishing == Fishing.RELEASING else hooked_head
			if fishing != Fishing.RELEASING and crew_scoop_helper != 0 and campaign.crew.avatars.has(crew_scoop_helper) \
					and campaign.crewplay.gear.net.owner == crew_scoop_helper:
				var holder: Transform3D = campaign.crew.avatars[crew_scoop_helper].tool_grip
				var in_net := holder * Vector3(0, -.15, -1.06)
				var display := reach.lerp(in_net, smoothstep(.17, .97, net_amount))
				fish.pose(display, -holder.basis.x, .25, .06, clock * 12.0)
				rig.net.hide()
				return
			rig.net.scale = Vector3.ONE * clampf(fish.metres / .73, 1.0, 1.83 if trophy.hooked else 1.52)
			rig.show_net(reach, net_amount)
			if fishing == Fishing.RELEASING and state_age >= .77:
				var reference: Vector3 = vessel.center if aboard() else player.global_position
				var heading := (net_site - reference).slide(Vector3.UP).normalized()
				var dart := state_age - .77
				var swim: Vector3 = net_site + heading * dart * 1.54
				var wave := river.wave_height(swim, clock)
				var depth := .045 + dart * .72
				swim.y = wave - depth
				fish.pose(swim, heading + Vector3.DOWN * .21, sin(dart * 8.0) * .16, .15, clock * 18.0)
				river.set_fish_shadow(swim, heading, depth, fish.metres)
				return
			var angle := rig.net.global_basis.orthonormalized()
			var nose: Vector3 = rig.net.to_global(Vector3(-minf(.38, fish.metres * .44 / rig.net.scale.x), -.085, -.021))
			fish.pose(nose, -angle.x, .29 + sin(clock * 9.3) * .08,
				.047 if fishing == Fishing.DISPLAY else .12, clock * 15.0)
			return
		_:
			return
	var slack := (.18 if fishing == Fishing.WAITING else .085)
	var leader := 0.0
	if fishing == Fishing.FIGHT or fishing == Fishing.NET_READY:
		slack = clampf(line_out - rig.tip.global_position.distance_to(line_end), 0.025, .94)
		leader = clampf(minf(strike_depth, -hooked_head.y * .46 + .54), .18, 2.4)
	effects.draw_line(rig.tip.global_position, line_end, eye.global_position, slack, clock, leader)


func capture_crew_pose() -> Dictionary:
	var data := campaign.crewplay.style()
	data.move = ground_motion if grounded_motion else player.velocity
	data.sprint = sprint_blend if grounded_motion else 0.0
	data.crouch = smoothstep(0, 1, crouch_camera_blend)
	data.eye_drop = clampf(STANDING_EYE - eye.position.y, 0, 1) if crouch_camera_blend > 0 else 0.0
	data.pitch = pitch
	data.seat = campaign.amenities.seat_kind(campaign.crew.my_id())
	if in_aircraft(): data.seat = "heli"
	data.merge(cabin.visual_packet(), true)
	data.merge(campaign.crewplay.hand_packet(), true)
	if rig.visible:
		data.rod_pose = eye.global_transform.affine_inverse() * rig.rod.global_transform
		data.rod_crank = rig.reel_angle
		data.rod_rotor = rig.rotor.rotation.z
	data.view_roll = eye.rotation.z
	data.stage = int(fishing)
	data.age = state_age
	data.rod = rig.visible
	data.tension = line_tension
	data.reel = reel_rate
	data.line = effects.line.visible
	data.float = effects.bobber.visible
	data.hook_id = hook_id
	if data.line or data.float:
		data.end = line_end
	if fish.visible:
		data.fish = fish.global_position
		data.direction = -fish.global_basis.z.normalized()
		data.species = catch_type
		data.length = catch_length
	return data


func accept_crew_scoop(serial: int, helper: int, display_name: String) -> void:
	if serial == hook_id and fishing == Fishing.NET_READY:
		crew_scoop_helper = helper
		crew_scoop_name = display_name
		change_state(Fishing.LANDING)
		effects.break_surface(effects.on_water(hooked_head, clock), .61, "splash")


func read_journal() -> void:
	var path: String = CREW_JOURNAL if multiplayer_trip else SoloSaves.JOURNALS[solo_slot]
	var saved: Variant = JSON.parse_string(FileAccess.get_file_as_string(path)) if FileAccess.file_exists(path) else null
	if saved is Dictionary:
		var collection: Variant = saved.get("species", [])
		if collection is Array:
			for species: Variant in collection:
				if species is String:
					discovered_species[species] = true
		saved = saved.get("journal", [])
	if saved is Array:
		for entry: Variant in saved:
			if entry is String:
				journal.append(entry)
				var species_name: String = entry.get_slice("  ·  ", 0)
				discovered_species["Muskellunge" if species_name == "Trophy muskellunge" else species_name] = true


func record_catch() -> void:
	var weight := "%d g" % roundi(catch_weight * 1000.0) if catch_weight < .12 else "%.2f kg" % catch_weight
	var name_in_journal: String = "Trophy muskellunge" if trophy.hooked else Species.profile(catch_type).name
	var landed_with := "  ·  Netted by " + crew_scoop_name if not crew_scoop_name.is_empty() else ""
	notify_angling("%s  ·  %d cm  ·  %s%s" % [name_in_journal, catch_length, weight, landed_with], 5.0)
	if not campaign.crew.is_guest():
		var reward := "trophy" if trophy.hooked else ("small_fish" if catch_length < 25 else "fish")
		campaign.XP.award(campaign.progression_for(campaign.crew.my_id()), reward, "catch:%d" % campaign.ledger.state.catch_serial)
		if crew_scoop_helper > 1 and campaign.crew.people.has(crew_scoop_helper):
			campaign.XP.award(campaign.progression_for(crew_scoop_helper), reward, "catch:%d" % campaign.ledger.state.catch_serial)
		campaign.changed()
	catch_count += 1
	discovered_species[Species.profile(catch_type).name] = true
	journal.push_front(catch_note)
	if journal.size() > 25:
		journal.resize(25)
	var file := FileAccess.open(CREW_JOURNAL if multiplayer_trip else SoloSaves.JOURNALS[solo_slot], FileAccess.WRITE)
	if file:
		file.store_string(JSON.stringify({"format": 2, "species": discovered_species.keys(), "journal": journal}))
	refresh_journal()
	campaign.request("catch", [name_in_journal, catch_length])


func make_chart() -> void:
	var layer := CanvasLayer.new()
	layer.layer = 2
	add_child(layer)
	layer.add_child(chart)
	chart.setup(river.chart_texture, river.extent)
	chart.travel_requested.connect(ask_to_teleport)
	chart.close_requested.connect(close_chart)
	chart.guide_requested.connect(open_fish_guide)
	teleport_dialog = ConfirmationDialog.new()
	teleport_dialog.title = "Confirm teleport"
	teleport_dialog.ok_button_text = "Yes"
	teleport_dialog.cancel_button_text = "No"
	MenuTheme.style_confirmation(teleport_dialog)
	teleport_dialog.confirmed.connect(teleport_from_chart)
	teleport_dialog.canceled.connect(func():
		if chart.visible:
			chart.travel_button.grab_focus())
	chart.add_child(teleport_dialog)
	refresh_journal()


func make_waypoints() -> void:
	chart.add_waypoint(ChartDestination.SWISHA, "Swisha Dam", "Swisha / Des Joachims Dam",
		"Swisha / Des Joachims Dam", "Arrive at the tailwater landing near the dam access road.",
		river.point(0), Vector2(16, -44), Color("#bd512d"), false, 2)
	chart.add_waypoint(ChartDestination.PINE, "Pine Beach / Pine Reach", "Pine Beach",
		"Pine Beach / Pine Reach", "Arrive on shore at Pine Reach.",
		campaign.landings.sites[1].stand, Vector2(-143, -59), Color("#417440"))
	chart.add_waypoint(ChartDestination.CAMP, "Pine Reach Campfire", "Campfire",
		"Pine Reach Campfire", "Arrive by the stove at the fishing camp.",
		campaign.crewplay.camp.stove.global_position, Vector2(-110, 25), Color("#ac5923"))
	chart.add_waypoint(ChartDestination.MARINA, "Deep River Marina", "Deep River Marina",
		"Deep River Marina", "Arrive on the public wharf.",
		river.point(1), Vector2(27, -78), Color("#215d8e"))
	if river.meta.has("lamure"):
		chart.add_waypoint(ChartDestination.LAMURE, "Lamure Beach", "Lamure Beach",
			"Lamure Beach", "Arrive on the beach near the swim raft.",
			river.point(3), Vector2(-60, 66), Color("#247d76"))
	chart.add_waypoint(ChartDestination.BIRCH, "Birch Beach / Birch Point", "Birch Point",
		"Birch Beach / Birch Point", "Arrive on shore at Birch Point.",
		campaign.landings.sites[2].stand, Vector2(95, 18), Color("#75569b"))
	chart.add_waypoint(ChartDestination.CHALK_RIVER, "Chalk River Labs", "Chalk River Labs",
		"Chalk River Labs", "Arrive near the research landing and lookout trail.",
		river.point(2), Vector2(-129, 36), Color("#a44864"), false, 3)
	chart.add_waypoint(ChartDestination.HELIPAD, "McAnulty Road helipad", "Helipad",
		"McAnulty Road helipad", "Arrive beside the four-seat survey helicopter.",
		regions.helipad, Vector2(-176, -48), Color("#705589"))
	chart.add_waypoint(ChartDestination.CEMETERY, "Deep River Cemetery", "Cemetery",
		"Deep River Cemetery", "Arrive near the cemetery grounds off McAnulty Road.",
		regions.cemetery, Vector2(-168, -6), Color("#6e7356"))
	chart.add_waypoint(ChartDestination.SKI, "Mount Martin / ski trail", "Mount Martin",
		"Mount Martin / ski trail", "Arrive at the trail toward Grouse Park.",
		regions.ski, Vector2(-166, 41), Color("#526d4d"))
	chart.add_waypoint(ChartDestination.BOAT, "Return to boat", "Boat",
		"Return to boat", "Rejoin the boat at its current position.",
		vessel.center, Vector2.ZERO, MenuTheme.BLUE, true)


func open_chart(show_catches := false) -> void:
	sonar_overlay.hide()
	release_line()
	chart.set_status("")
	chart.set_return_available(can_return_to_boat and not aboard())
	chart.update_boat(vessel.center)
	chart.open(show_catches)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func close_chart() -> void:
	teleport_dialog.hide()
	chart.hide()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func open_fish_guide(book_page := "") -> void:
	guide_book_page = book_page
	chart.hide()
	sonar_overlay.hide()
	release_line()
	fish_guide.set_catches(discovered_species)
	fish_guide.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE


func teleport_blocker() -> String:
	if in_aircraft(): return "Land and leave the helicopter before travelling."
	if campaign.amenities.seated():
		return "Get up before travelling."
	if mower.rider != null or marina_cars.active >= 0:
		return "Leave the vehicle before teleporting."
	if driving or campaign.captain == campaign.crew.my_id():
		return "Leave the helm before teleporting."
	if cabin.busy() or cabin.hands_in_use() or campaign.crewplay.hands_busy():
		return "Put away your gear before teleporting."
	if campaign.preview_id != "":
		return "Finish or cancel building before teleporting."
	if campaign.crew.mode == "joining":
		return "Wait for the crew connection before teleporting."
	return ""


func ask_to_teleport(destination: ChartDestination) -> void:
	var blocker := teleport_blocker()
	chart.set_status(blocker)
	if not blocker.is_empty():
		return
	teleport_destination = destination
	if destination == ChartDestination.BOAT:
		teleport_dialog.dialog_text = "Teleport back to the boat?"
	else:
		teleport_dialog.dialog_text = "Teleport to %s?\nThe boat will stay where it is." % TELEPORT_NAMES[destination]
	teleport_dialog.popup_centered(Vector2i(380, 140))
	teleport_dialog.get_cancel_button().grab_focus()


func teleport_from_chart() -> void:
	if not chart.visible or campaign.controls_blocked():
		return
	var blocker := teleport_blocker()
	chart.set_status(blocker)
	if not blocker.is_empty():
		return
	release_line()
	set_swimming(false)
	if teleport_destination == ChartDestination.BOAT:
		campaign.keep_player_on_deck(vessel, vessel.board_anchor())
		yaw = vessel.heading
		can_return_to_boat = false
	else:
		var arrival: Vector3
		var view_target: Vector3
		match teleport_destination:
			ChartDestination.HELIPAD:
				arrival = regions.helipad + Vector3(4.0, .1, 0)
				view_target = regions.helipad
			ChartDestination.CEMETERY:
				arrival = regions.cemetery + Vector3(38, 0, 0)
				view_target = regions.cemetery
			ChartDestination.SKI:
				arrival = regions.ski
				view_target = arrival + Vector3(0, 0, 30)
			ChartDestination.MARINA:
				# Open space on the public wharf, clear of the rails and lamppost.
				arrival = Vector3(18077.0, Wharf.DECK_HEIGHT, 12638.0)
				view_target = river.point(1)
			ChartDestination.SWISHA:
				arrival = campaign.landings.sites[3].transfer
				view_target = river.measured("dam")
			ChartDestination.CHALK_RIVER:
				arrival = campaign.landings.sites[4].transfer
				view_target = river.measured("cnl")
			ChartDestination.LAMURE:
				arrival = river.point(3)
				arrival.y = river.ground_height(arrival.x, arrival.z)
				view_target = river.lamure.raft_anchor
			ChartDestination.PINE, ChartDestination.BIRCH:
				var index := 1 if teleport_destination == ChartDestination.PINE else 2
				arrival = campaign.landings.sites[index].stand
				view_target = campaign.landings.sites[index].berth
			ChartDestination.CAMP:
				arrival = campaign.crewplay.camp.stove.global_position + campaign.landings.sites[1].right * 2.3
				view_target = campaign.crewplay.camp.stove.global_position
		var safe := safety.find_near(arrival, 4.0)
		if not safe.is_finite():
			chart.set_status("No clear arrival point. Try another waypoint.")
			return
		player.global_position = safe
		player.velocity = Vector3.ZERO
		player.reset_physics_interpolation()
		yaw = atan2(arrival.x - view_target.x, arrival.z - view_target.z)
		can_return_to_boat = true
	pitch = -.12
	update_view()
	close_chart()


func refresh_journal() -> void:
	var entries := PackedStringArray()
	for i in mini(9, journal.size()):
		entries.append(journal[i])
	chart.journal_label.text = "\n\n".join(entries) if not entries.is_empty() else "No catches yet."


func update_hud() -> void:
	var piloting := helicopter.my_seat() == 0
	ignition_prompt.visible = play_input() and at_ignition_key()
	var engine_running: bool = ignition_prompt.visible and vessel.ignition == Boat.Ignition.RUN
	if ignition_prompt.visible:
		ignition_prompt.text = "Press E to stop" if engine_running else "Hold E to start"
	ignition_ring.visible = ignition_prompt.visible and not engine_running and ignition_hold > 0.0
	ignition_ring.progress = clampf(ignition_hold / Boat.START_TIME, 0.0, 1.0) if ignition_ring.visible else 0.0
	backpack.update_throttle(mower.throttle_index if mower.rider != null and play_input() else -1, mower.throttle_label())
	backpack.hud_available = not piloting and not campaign.crewplay.hands_busy() and not cabin.hands_in_use() and not chart.visible and not fish_guide.visible and not cheats.visible \
		and not campaign.controls_blocked() and not cabin.busy() and not campaign.marina_fuel.is_local_holder()
	var location := "Ottawa River"
	var at: Vector3 = vessel.center if aboard() else player.global_position
	if river.meta.has("lamure") and at.distance_squared_to(river.point(3)) < 175.0 * 175.0:
		location = "Lamure Beach"
	else:
		for index in 3:
			if at.distance_squared_to(river.point(index)) < 650.0 * 650.0:
				location = river.meta.places[index].name
				break
	objective.text = location
	instruction.text = ""
	var on_line := fishing == Fishing.FIGHT
	progress.visible = on_line
	live_label.visible = on_line
	if on_line:
		progress.value = clampf(line_tension, 0, 1)
		tension_fill.bg_color = Color("#77b19e").lerp(Color("#deba73"), smoothstep(.37, .78, line_tension))
		tension_fill.bg_color = tension_fill.bg_color.lerp(Color("#ef8661"), smoothstep(.75, 1.03, line_tension))
		live_label.text = "Tension %d%%     Drag %d%%  ·  Mouse wheel" % [
			roundi(line_tension * 100), roundi(drag_setting * 100)]
	marker.visible = false
	fps.text = "%d FPS\n%s   [F4]" % [Engine.get_frames_per_second(), graphics.description()]
	if marina_cars.active >= 0:
		var car: MarinaCars.RoadCar = marina_cars.cars[marina_cars.active]
		var reverse := "   ·   REVERSE" if car.speed < -.08 else ""
		objective.text = "%s   ·   %d km/h%s" % [car.details.label, roundi(absf(car.speed) * 3.6), reverse]
		instruction.text = "W  Accelerate    S  Brake / reverse    A/D  Steer    Space  Handbrake"
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			instruction.text = "Click to resume driving"
		if clock < note_until:
			instruction.text += "\n" + catch_note
		else:
			instruction.text += "\nE  Exit when stopped    C  Camera    H  Headlights    F4  Draw distance"
		campaign.info.hide()
		return
	if chart.visible:
		chart.update_boat(vessel.center)
	if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
		instruction.text = "Click to play  ·  Hold F1 for controls"
	elif cabin.hands_in_use() or cabin.focus >= 0:
		instruction.text = ""
	elif driving:
		instruction.text = "Hold W/S  Drive/reverse   R/F  Set throttle   A/D  Steer   X  Center wheel"
		if not ignition_prompt.visible:
			instruction.text += "   E  Leave helm"
	elif fishing == Fishing.CASTING:
		instruction.text = "Casting…"
	elif fishing == Fishing.WAITING:
		instruction.text = catch_note if clock < note_until else "Watch for the float to go under. R reels it in early."
	elif fishing == Fishing.BITE:
		objective.text = "Fish on the bait  ·  %.1f s" % maxf(0.0, BITE_WINDOW - state_age)
		instruction.text = "Tap R now to set the hook."
	elif fishing == Fishing.FIGHT:
		objective.text = "Trophy muskie" if trophy.hooked else "Fish on"
		instruction.text = "Let go of R and let the fish run." if payout > .25 or line_tension > .78 else "Hold R to reel  ·  Right mouse lifts the rod"
	elif fishing == Fishing.RETRIEVING:
		instruction.text = "Reeling in…"
	elif fishing == Fishing.NET_READY:
		objective.text = "Within net range"
		instruction.text = "Ask your crew for the net, or tap R to land it." if campaign.crew.people.size() > 1 else "Tap R to scoop it into the net."
	elif fishing == Fishing.LANDING:
		objective.text = "Landing the fish"
		instruction.text = "Lifting the net…"
	elif fishing == Fishing.DISPLAY:
		objective.text = catch_note
		instruction.text = "R  Release    •    H  Hold fish   ·   E at ice chest to store"
	elif fishing == Fishing.RELEASING:
		instruction.text = "Lowering it back into the river…"
	elif clock < note_until:
		instruction.text = catch_note
	elif rod_in_hand() and aboard() and absf(vessel.speed) > 1.3:
		instruction.text = "Wait for the boat to slow before casting"
	elif near_wheel():
		instruction.text = "E  Take the helm"
	elif aboard() and not vessel.skiff and vessel.to_local(player.global_position).z > -.30:
		instruction.text = "Aim at the fridge or a galley item and press E."
	var action := campaign.action_hint()
	if not action.is_empty() and fishing == Fishing.READY and clock >= note_until and not cabin.hands_in_use() \
			and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED and not campaign.dive.active:
		instruction.text = action
	if swimming and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		if can_board_from_water():
			instruction.text = "E  Climb aboard at the bow"
		elif river.lamure.at_swim_ladder(player.global_position, eye):
			instruction.text = "E  Climb onto the swim float"
		else:
			instruction.text = "WASD  Swim   ·   Head for shore or the boat’s bow"
	if campaign.dive.active:
		objective.text = "Survey submersible"
		instruction.text = ""
	if play_input() and not flying and mower.rider == null and marina_cars.focused >= 0 and clock >= note_until \
			and not campaign.controls_blocked() and campaign.preview_id.is_empty():
		var which := marina_cars.focused
		var car_label: String = marina_cars.cars[which].details.label
		instruction.text = "E  Drive " + car_label if marina_cars.drivers[which] == 0 else car_label + "  ·  In use"
	if play_input():
		if flying:
			instruction.text = "WASD  Fly   ·   Space  Up   ·   Ctrl/Shift  Down   ·   F2  Cheats"
		elif mower.rider != null and clock >= note_until:
			instruction.text = "W/S  Drive   ·   A/D  Turn   ·   Q/R  Throttle   ·   X  Blades %s   ·   C  View   ·   E  Dismount" % ("on" if mower.blades else "off")
		elif can_talk_to_shannon():
			var office_leaf := public_works.office_handle(eye)
			var bay := public_works.nearby_door(eye)
			if office_leaf >= 0:
				instruction.text = public_works.office_prompt(office_leaf, eye)
			elif shannon_job.in_range() and clock >= note_until:
				instruction.text = shannon_job.prompt()
			elif bay != null:
				instruction.text = bay.prompt()
			elif can_mount_mower():
				instruction.text = "E  Mount lawn mower"
	if play_input() and clock >= note_until and mower.rider == null and marina_cars.active < 0:
		var property_hint: String = properties.hint()
		if not property_hint.is_empty():
			instruction.text = property_hint
	if play_input() and can_use_fuel() and clock >= note_until:
		var fuel_hint: String = campaign.marina_fuel.hint()
		if not fuel_hint.is_empty():
			instruction.text = fuel_hint
	backpack.waypoint.visible = target_index >= 0 and not piloting
	if backpack.waypoint.visible:
		var target: Vector3 = river.point(target_index)
		var distance := at.distance_to(target)
		var waypoint_text := "%s  ·  %.1f km" % [river.meta.places[target_index].name, distance / 1000.0]
		backpack.waypoint.text = waypoint_text
		if not eye.is_position_behind(target + Vector3.UP * 1.5):
			var projected := eye.unproject_position(target + Vector3.UP * 1.5)
			marker.text = waypoint_text
			marker.position = Vector2(clampf(projected.x - 68, 20, 1080), clampf(projected.y - 25, 128, 585))
			marker.show()


func update_flight_mode(enabled: bool) -> void:
	flying = enabled
	interact_pressed = false
	rod_pressed = false
	player.velocity = Vector3.ZERO
	set_swimming(false)
	player.motion_mode = CharacterBody3D.MOTION_MODE_FLOATING if flying else CharacterBody3D.MOTION_MODE_GROUNDED
	if not flying:
		return
	release_line()
	sonar_overlay.hide()
	if driving:
		campaign.relinquish_helm()
	if mower.rider != null:
		mower.leave_for_flight()
	if not campaign.preview_id.is_empty():
		campaign.cancel_preview(false)
	if campaign.dive.active:
		campaign.requested_dive = true


func aboard() -> bool:
	return not flying and not in_aircraft() and super.aboard()


func in_aircraft() -> bool:
	return is_instance_valid(helicopter) and helicopter.mounted()


func fly(delta: float, has_input: bool) -> void:
	step_vessel(delta, 0.0)
	if not has_input:
		player.velocity = Vector3.ZERO
		return
	var descent := Input.is_physical_key_pressed(KEY_CTRL) or Input.is_physical_key_pressed(KEY_SHIFT)
	var direction := Vector3(axis(KEY_D, KEY_A), float(Input.is_physical_key_pressed(KEY_SPACE)) - float(descent), -axis(KEY_W, KEY_S))
	var boost := cheats.multiplier()
	var target := direction.limit_length().rotated(Vector3.UP, yaw) * 15.0 * boost
	player.velocity = player.velocity.move_toward(target, delta * 66.0 * boost)
	if not player.velocity.is_zero_approx():
		player.move_and_slide()


func can_mount_mower() -> bool:
	return not flying and not swimming and marina_cars.active < 0 and mower.rider == null and not aboard() and not driving \
		and not cabin.busy() and not campaign.dive.active and campaign.preview_id.is_empty() \
		and not campaign.crewplay.hands_busy() and (mower.near(player, eye) or spare_mower.near(player, eye))


func can_talk_to_shannon() -> bool:
	return mower.rider == null and not flying and not swimming and marina_cars.active < 0 and not aboard() and not driving \
		and not cabin.busy() and not campaign.dive.active and campaign.preview_id.is_empty()


func unstuck() -> void:
	if is_instance_valid(helicopter): helicopter.escape()
	campaign.amenities.escape()
	release_line()
	interact_pressed = false
	rod_pressed = false
	cheats.flight.button_pressed = false
	if flying:
		update_flight_mode(false)
	if mower.rider != null:
		mower.leave_for_flight()
	if campaign.dive.active:
		campaign.dive.stow()
	if driving:
		campaign.relinquish_helm()
	if cabin.active >= 0:
		cabin.finish_use()
	cabin.clean_target = null
	campaign.cancel_preview(false)
	set_swimming(false)
	if marina_cars.active >= 0:
		marina_cars.request_rescue()
		return
	safety.rescue()
