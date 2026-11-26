extends Node3D

const Data = preload("res://game_campaign_data.gd")
const Ledger = preload("res://game_ledger.gd")
const Landings = preload("res://river_landings.gd")
const Deck = preload("res://river_deck.gd")
const Sub = preload("res://river_submersible.gd")
const Board = preload("res://river_board.gd")
const Crew = preload("res://multiplayer_session.gd")
const Boat = preload("res://houseboat.gd")
const Kit = preload("res://scenery.gd")
const CrewPlay = preload("res://crew_play.gd")
const Rich = preload("res://rich_npc.gd")
const Story = preload("res://rich_story.gd")
const BoatsMenu = preload("res://marina_boats_menu.gd")
const Princecraft = preload("res://princecraft.gd")
const PrincecraftScene = preload("res://princecraft.tscn")
const GasBar = preload("res://marina_gas_bar.gd")
const LAUNCH_ASHORE := -4
const LAUNCH_READY := -5
const LAUNCH_REFUSED := -6
const Amenities = preload("res://boat_amenities.gd")

var game: Node3D
const XP = preload("res://progression.gd")
const ReaperQuest = preload("res://roach_reaper_quest.gd")
const DayCycle = preload("res://river_day_cycle.gd")

var ledger := Ledger.new()
var landings := Landings.new()
var deck := Deck.new()
var dive := Sub.new()
var crew := Crew.new()
var crewplay := CrewPlay.new()
var rich := Rich.new()
var story := Story.new()
const STORY_ARRIVAL := -30
const STORY_ENGINE_TEST := -38
var amenities := Amenities.new()
var board: Board
var boats_menu := BoatsMenu.new()
var marina_fuel: GasBar
var houseboat: Boat
var skiff: Boat
var princecraft: Princecraft
var princecraft_lines: Array[String] = []
var princecraft_line_wait := 0.0
var princecraft_had_crew := false
var princecraft_first_speed := false
var princecraft_was_moving := false
var info: Label
var message := ""
const Mooring = preload("res://river_mooring.gd")

var mooring := Mooring.new()
var dock := -1
var captain := 0
var revision := 0
var remote_ship: Dictionary = {}
var remote_throttle := 0.0
var remote_rudder := 0.0
var remote_center_wheel := false
var remote_age := 99.0
var requested_dock := false
var requested_dive := false
var guest_captain := 0
var last_guest_revision := -1
var guide_site := -1
var job_targets: Dictionary = {}
var lift_amount := 0.0
var lifting_peer := 0
var diver := 0
var save_elapsed := 0.0
var ghost: MeshInstance3D
var ghost_paint: StandardMaterial3D
var preview_id := ""
var preview_site := -1
var preview_angle := 0.0
var preview_pose := Transform3D.IDENTITY
var preview_good := false
var place_requested := false
var route_map: Node2D
var route_map_version := ""
var rich_underway := false
var rich_high_bilge := false
var rich_chat_requests := {}
var reaper := ReaperQuest.new()


func load_trip(game_world: Node3D) -> bool:
	if game_world.multiplayer_trip:
		ledger.save_path = Ledger.CREW_SAVE
	else:
		ledger.save_path = game_world.SoloSaves.CAMPAIGNS[game_world.solo_slot]
	return not ledger.load_file()


func setup(game_world: Node3D, new_game: bool) -> void:
	game = game_world
	name = "RiverCampaign"
	marina_fuel = game.river.waterfront.gas_bar
	marina_fuel.bind(game, self)
	houseboat = game.vessel as Boat
	houseboat.set_modern_design(ledger.state.modern_houseboat)
	crew.name = "Crew"
	crew.local_profile = ledger.profile_id()
	crew.progression_secret = ledger.profile_id("user://ottawa_progression_id.txt")
	add_child(crew)
	crew.boat = game.vessel
	crew.requested.connect(remote_request)
	crew.state_received.connect(sync_guest)
	crew.ship_received.connect(receive_ship)
	crew.weather_received.connect(receive_weather)
	crew.command_received.connect(receive_helm)
	crew.result_received.connect(receive_result)
	crew.member_left.connect(member_left)
	crew.changed.connect(refresh_board)
	crew.stopped.connect(clear_shared_seats)
	add_child(landings)
	landings.setup(game.river, ledger)
	var waterfront = game.river.waterfront
	mooring.setup(landings.sites, waterfront.docks.cleats, waterfront.wharf.wharf_cleats,
		waterfront.wharf.launch_cleat_indices)
	houseboat.water_check = houseboat_route
	add_child(deck)
	deck.fit(houseboat)
	crewplay.name = "DeckActions"
	add_child(crewplay)
	crewplay.setup(game, self)
	add_child(amenities)
	amenities.setup(game, self)
	rich.setup(houseboat, game.hud)
	crew.rich_heard.connect(rich.play)
	rich.spoken.connect(share_rich_line)
	story.setup(self, new_game)
	add_child(reaper)
	reaper.setup(game, self)
	add_child(dive)
	dive.setup(game.river, game.eye)
	var page := CanvasLayer.new()
	page.layer = 4
	add_child(page)
	board = Board.new()
	page.add_child(board)
	board.chosen.connect(button_selected)
	board.dismissed.connect(close_board)
	page.add_child(boats_menu)
	boats_menu.spawn_requested.connect(func(boat_id: String): request("marina_launch", boat_id))
	info = game.label("", 15, Color("#f6e6c5"))
	game.hud.add_child(info)
	info.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	info.offset_left = -482
	info.offset_right = -26
	info.offset_top = 108
	info.add_theme_stylebox_override("normal", preload("res://game_menu_theme.gd").box(Color("#182f40d6"), Color("#dfb78499"), 8, 10))
	info.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	info.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	ghost_paint = Kit.paint(Color(.46, .88, .69, .35))
	ghost_paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ghost_paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	ghost = Kit.mesh_at(self, BoxMesh.new(), Vector3.ZERO, ghost_paint)
	ghost.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	ghost.hide()
	route_map = game.chart.routes
	game.chart.map_resized.connect(reposition_routes)
	for index in Data.WORK.size():
		var job: Dictionary = Data.WORK[index]
		if job.has("offset"):
			var origin: Vector3 = landings.sites[job.home].berth + Vector3(job.offset.x, 0, job.offset.y)
			job_targets[index] = closest_water(origin, 4.8 if job.kind == "dive" else 2.15)
	dock = clampi(int(ledger.state.last_dock), -1, Data.SITES.size() - 1)
	if dock >= 0:
		select_craft(str(ledger.state.craft), dock)
		set_moored(dock)
		move_person(dock, false)
	elif ledger.state.craft == "princecraft":
		select_craft("princecraft", 0)
		princecraft.berth_at(houseboat.center, houseboat.heading)
		if not story.shore_arrival():
			keep_player_on_deck(princecraft, princecraft.board_anchor())
	elif new_game:
		var wharf = game.river.waterfront.wharf
		var berth: Vector3 = wharf.launch_center(houseboat.launch_half_beam())
		if houseboat.can_place(berth, wharf.launch_heading):
			houseboat.berth_at(berth, wharf.launch_heading)
			rig_at_public_launch(houseboat)
	if dock < 0 and story.restore_boat_pose():
		if at_launch_berth(game.vessel):
			rig_at_public_launch(game.vessel)
		if not story.shore_arrival():
			keep_player_on_deck(game.vessel, game.vessel.board_anchor())
	update_target()
	update_route_map()


func closest_water(center: Vector3, minimum_depth: float) -> Vector3:
	for ring in 14:
		for direction in (1 if ring == 0 else 12):
			var angle := float(direction) * TAU / 12.0
			var sample := center + Vector3(sin(angle), 0, cos(angle)) * (ring * 12.0)
			if game.river.can_sail(sample) and game.river.depth_at(sample) >= minimum_depth:
				return sample
	return center


func actor(peer: int) -> Dictionary:
	if peer == crew.my_id():
		return {"at": game.player.global_position, "onboard": game.aboard(), "yaw": game.yaw, "pitch": game.pitch}
	if captain == peer:
		return {"at": game.vessel.to_global(game.vessel.helm_anchor()), "onboard": true}
	return crew.last_pose(peer)


func local_site() -> int:
	return actor_site(actor(crew.my_id()))


func at_plot(person: Dictionary, site: int) -> bool:
	return site >= 0 and not person.onboard and landings.site_range(person.at, 14.0, false) == site


func actor_site(person: Dictionary) -> int:
	if person.is_empty():
		return -1
	if person.onboard:
		return dock
	var shore_site := landings.site_range(person.at, 19.5, false)
	if shore_site >= 0:
		return shore_site
	return dock if dock >= 0 and \
		landings.footprint(Vector2(8, 38), Transform3D(Basis(Vector3.UP, landings.sites[dock].heading),
			landings.sites[dock].transfer.lerp(landings.sites[dock].stand, .5))).has_point(Vector2(person.at.x, person.at.z)) else -1


func can_fish_from_shore() -> bool:
	return not dive.active and shore_fishing_at(game.player.global_position)


func shore_fishing_at(at: Vector3) -> bool:
	return at.y < 6.0 and (landings.site_range(at, 86.0, false) >= 0 or landings.site_range(at, 55.0, true) >= 0 \
		or (at.y > .3 and game.river.waterfront.docks.blocks(at)))


func controls_blocked() -> bool:
	return board.visible or boats_menu.visible or dive.active


func open_board(page := "River") -> void:
	game.release_line()
	game.chart.hide()
	game.fish_guide.hide()
	game.sonar_overlay.hide()
	cancel_preview(false)
	board.active_page = page
	board.show()
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	refresh_board()
	board.focus_page()


func close_board() -> void:
	board.hide()
	if DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func handle_modal(event: InputEventKey, key: Key) -> bool:
	if board.visible:
		if key == KEY_ESCAPE or (not get_viewport().gui_get_focus_owner() is LineEdit and key == KEY_B):
			close_board()
			return true
		return false
	if dive.active:
		if key == KEY_V or key == KEY_ESCAPE:
			requested_dive = true
		elif event.is_action_pressed(&"interact"):
			if not dive.take():
				game.notify_angling("Bring the sub within 1.5 m of the recorder.", 3.2)
		return true
	if key == KEY_B and not game.cabin.busy():
		var place := local_site()
		if place >= 0 and not game.aboard():
			open_board("Build")
		else:
			game.open_notebook()
		return true
	return false


func handle_world(event: InputEvent) -> bool:
	if game.helicopter.input(event): return true
	if amenities.input(event): return true
	if board.visible:
		return true
	if dive.active:
		if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			dive.steer(event.relative)
		return true
	if preview_id != "" and event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_LEFT:
			place_requested = true
		elif event.button_index == MOUSE_BUTTON_RIGHT:
			cancel_preview()
		return true
	if event is InputEventKey and event.pressed and not event.echo:
		match event.physical_keycode:
			KEY_L:
				requested_dock = true
				return true
			KEY_V:
				requested_dive = true
				return true
			KEY_Q:
				if preview_id != "":
					preview_angle += PI * .5
					return true
	return false


func run_shortcuts(has_input: bool) -> void:
	if requested_dock:
		requested_dock = false
		if has_input and not game.cabin.busy():
			request("dock", null)
	if requested_dive:
		requested_dive = false
		if dive.active:
			var completed := dive.retrieved
			dive.stow()
			request("finish_dive", completed)
		elif has_input and not game.cabin.busy():
			try_dive()
	if place_requested:
		place_requested = false
		if preview_good and has_input:
			request("build", [preview_site, preview_id, preview_pose.origin, preview_angle])
			cancel_preview(false)


func local_interact() -> bool:
	if game.properties.interact(): return true
	if game.helicopter.interact(): return true
	if story.interact(): return true
	var line_action := mooring_focus()
	if not line_action.is_empty():
		request("ground_tackle", line_action.slice(0, 3))
		return true
	if amenities.interact(): return true
	var launch_action := launch_interaction()
	if launch_action != "":
		match launch_action:
			"Boats": boats_menu.open("princecraft" if game.vessel == princecraft else (
				"panorama" if houseboat.modern_design else "classic"))
			"Step ashore": request("marina_ashore", null)
			"Board boat": board_at_launch()
		return true
	if at_rich():
		request("rich_talk", null)
		return true
	if crewplay.interact():
		return true
	if not game.aboard():
		if game.river.lamure.at_swim_ladder(game.player.global_position, game.eye):
			game.river.lamure.climb_float(game.player)
			return true
		var door := landings.aimed_door(game.eye)
		if door != null:
			request("door", door.get_meta("door_id"))
			return true
		var board_target := aimed_landing_board()
		if not board_target.is_empty():
			open_board(board_target)
			return true
		return false
	if not game.driving:
		var engine_at := deck.pump.to_global(Vector3(.13, .23, 0))
		if aiming(engine_at, 1.45, .92) and deck.pump.visible:
			request("pump", null)
			return true
		var task := ledger.active_job()
		var ship: Boat = game.vessel
		if not task.is_empty() and ledger.state.stage == "travel" and task.has("offset") \
				and ship.center.distance_to(target_for_job()) < work_radius(task.kind):
			if task.kind == "dive":
				try_dive()
			else:
				request("work", null)
			return true
	return false


func aimed_landing_board() -> String:
	var site := local_site()
	if site < 0:
		return ""
	var shop := ledger.building(site, "workshop")
	if not shop.is_empty() and aiming(landings.read_pose(shop) * Vector3(0, 1.2, -1.36), 2.8, .83):
		return "Workshop"
	return "Jobs" if aiming(landings.sites[site].sign, 3.1, .78) else ""


func mooring_focus() -> Array:
	var peer := crew.my_id()
	if game.driving or game.swimming or game.flying or game.in_aircraft() or amenities.seated() \
			or marina_fuel.held_by(peer) != null or not crewplay.held_by(peer).is_empty() \
			or not crewplay.held_fish(peer).is_empty():
		return []
	var boat: Boat = game.vessel
	if not boat.visible:
		return []
	var onboard: bool = game.aboard()
	if onboard and game.near_wheel() and aiming(boat.helm_wheel.global_position, 2.2, .95):
		return []
	if not onboard and launch_interaction() == "Board boat" and aiming(boarding_target(boat), 5.5, .94):
		return []
	return mooring.focus(boat, peer, onboard, game.player.global_position, game.eye)


func dock_ladder() -> Dictionary:
	if not game.swimming:
		return {}
	return game.river.waterfront.docks.aimed_ladder(game.player.global_position, game.eye)


func climb_dock_ladder() -> bool:
	var ladder := dock_ladder()
	if ladder.is_empty():
		return false
	game.player.global_position = ladder.top
	game.player.velocity = Vector3.ZERO
	game.player.reset_physics_interpolation()
	game.set_swimming(false)
	return true


func aiming(point: Vector3, radius: float, cone: float, target: CollisionObject3D = null) -> bool:
	var eye: Camera3D = game.eye
	var ray := point - eye.global_position
	return ray.length_squared() <= radius * radius and ray.normalized().dot(-eye.global_basis.z) > cone \
		and preload("res://interaction_sight.gd").clear(eye, point, target)


func launch_interaction() -> String:
	if game.driving:
		return ""
	var wharf = game.river.waterfront.wharf
	var feet: Vector3 = game.player.global_position
	var boat: Boat = game.vessel
	if not boat.visible:
		return ""
	var alongside := at_launch_berth(boat)
	if game.aboard():
		if alongside and mooring.at_launch(boat) \
				and feet.distance_to(boat.to_global(boat.board_anchor())) < 1.75 \
				and aiming(wharf.launch_mark, 5.5, .84) and (not rich.seated or not at_rich()):
			return "Step ashore"
	elif wharf.at_launch_station(feet):
		var aims_at_boat := alongside and aiming(boarding_target(boat), 5.5, .62)
		if story.managed() and not story.owns_houseboat() and aims_at_boat:
			return "Board boat"
		if aiming(wharf.launch_mark, 3.65, .87):
			return "Boats"
		if aims_at_boat:
			return "Board boat"
	return ""


func boarding_target(boat: Boat) -> Vector3:
	return boat.to_global(boat.board_anchor()) + Vector3.UP * .8


func at_launch_berth(boat: Boat) -> bool:
	var wharf = game.river.waterfront.wharf
	var offset: Vector3 = boat.center - wharf.launch_center(boat.launch_half_beam())
	return absf(boat.speed) <= .58 and absf(offset.dot(wharf.launch_side)) <= .85 \
		and absf(offset.dot(wharf.launch_forward)) <= 2.65 \
		and absf(cos(boat.heading - wharf.launch_heading)) >= .96


func board_at_launch() -> void:
	var boat: Boat = game.vessel
	game.release_line()
	keep_player_on_deck(boat, boat.board_anchor())
	game.boarded = true
	game.yaw = boat.heading
	game.pitch = -.10
	game.update_view()


func step_ashore_at_launch(peer: int, person: Dictionary) -> void:
	var boat: Boat = game.vessel
	if captain == 0 and person.onboard and at_launch_berth(boat) \
			and mooring.at_launch(boat) \
			and Vector3(person.at).distance_to(boat.to_global(boat.board_anchor())) < 1.75:
		story.docked(peer, 0)
		changed()
		tell(peer, "Ashore at the launch dock.", LAUNCH_ASHORE)


func spawn_at_marina(peer: int, person: Dictionary, choice: String) -> void:
	if story.managed() and not story.owns_houseboat():
		tell(peer, "Rich manages the boat loans and restoration from his yard.", LAUNCH_REFUSED)
		return
	var wharf = game.river.waterfront.wharf
	if not BoatsMenu.BOATS.has(choice) or person.onboard or not wharf.at_launch_station(person.at):
		tell(peer, "Choose a boat at the launch dock sign.", LAUNCH_REFUSED)
		return
	var current: Boat = game.vessel
	if captain != 0 or diver > 0 or lifting_peer > 0 or absf(current.speed) > .58 \
			or actor(crew.my_id()).onboard or not amenities.occupants.is_empty():
		tell(peer, "Stop the boat and bring everyone ashore first.", LAUNCH_REFUSED)
		return
	var craft := "princecraft" if choice == "princecraft" else "houseboat"
	var boat: Boat = craft_for(craft, 0)
	var berth: Vector3 = wharf.launch_center(boat.launch_half_beam())
	var turn: float = wharf.launch_heading
	var footprint := boat.waterline(berth, turn)
	# An empty shared boat already tied up here can be replaced by the selection.
	var obstructed := not at_launch_berth(current) and not Geometry2D.intersect_polygons(
		footprint, current.waterline(current.center, current.heading)).is_empty()
	if obstructed or not boat.can_place(berth, turn):
		tell(peer, "The launch berth is occupied or obstructed.", LAUNCH_REFUSED)
		return
	for member: int in crew.people:
		var occupant := actor(member)
		if occupant.is_empty() or occupant.onboard:
			tell(peer, "Wait until everyone is ashore.", LAUNCH_REFUSED)
			return
		var feet: Vector3 = occupant.at
		if Geometry2D.is_point_in_polygon(Vector2(feet.x, feet.z), footprint):
			tell(peer, "Someone is in the launch berth.", LAUNCH_REFUSED)
			return
	stop_captain()
	dock = -1
	ledger.state.craft = craft
	marina_fuel.disconnect_fillers()
	if craft == "houseboat":
		ledger.state.modern_houseboat = choice == "panorama"
	else:
		ledger.state.tow = false
	boat.berth_at(berth, turn)
	rig_at_public_launch(boat)
	select_craft(craft, 0)
	if boat == princecraft:
		reset_princecraft_dialogue()
	revision += 1
	changed()
	if crew.on_server() and crew.people.size() > 1:
		send_ship()
	tell(peer, "%s ready alongside. Look at it and press E to board." % BoatsMenu.BOATS[choice], LAUNCH_READY)


func rig_at_public_launch(boat: Boat) -> void:
	mooring.seed_launch(boat)
	boat.departed = boat.mooring.secured()


func place_story_craft(craft: String) -> bool:
	var wharf = game.river.waterfront.wharf
	var boat := craft_for(craft, 0)
	var berth: Vector3 = wharf.launch_center(boat.launch_half_beam())
	if captain != 0 or not boat.can_place(berth, wharf.launch_heading):
		return false
	dock = -1
	ledger.state.last_dock = -1
	ledger.state.craft = craft
	ledger.state.tow = false
	marina_fuel.disconnect_fillers()
	boat.berth_at(berth, wharf.launch_heading)
	rig_at_public_launch(boat)
	select_craft(craft, 0)
	revision += 1
	return true


func return_story_princecraft() -> void:
	stop_captain()
	dock = -1
	ledger.state.last_dock = -1
	ledger.state.craft = "houseboat"
	ledger.state.rich_story.erase("boat_pose")
	select_craft("houseboat", 0)
	revision += 1


func at_rich() -> bool:
	return rich.hull == game.vessel and game.aboard() and (rich.seated or not game.driving) \
		and rich.focused(game.eye, game.player)


func share_rich_line(line_id: String, toward: Vector3) -> void:
	if crew.on_server() and crew.people.size() > 1:
		crew.rich_line.rpc(line_id, toward)


func start_rich_chat(peer: int) -> bool:
	var person := actor(peer)
	if rich.hull == story.yard.rich_stand:
		if not story.npc_in_reach(person):
			return false
		rich.talk(rich.hull.to_local(person.at) + Vector3.UP * 1.57)
		return true
	if rich.hull != game.vessel or (peer == captain and not rich.seated) \
			or not person.get("onboard", false) or not rich.close_enough(person.at):
		return false
	var height: float = game.vessel.helm_eye_height() if peer == captain else 1.57
	rich.talk(rich.hull.to_local(person.at) + Vector3.UP * height)
	return true


func tick_rich(delta: float) -> void:
	var author := not crew.is_guest()
	if author:
		for peer: int in rich_chat_requests.keys():
			if game.clock >= rich_chat_requests[peer] or not crew.people.has(peer) or start_rich_chat(peer):
				rich_chat_requests.erase(peer)
	var rich_aboard: bool = game.vessel == rich.hull
	if author and rich_aboard:
		var moving := absf(game.vessel.speed) > 2.15
		var knee_deep: bool = ledger.state.bilge > (.48 if rich_high_bilge else .66)
		var toward: Vector3 = game.vessel.helm_anchor() + Vector3.UP * game.vessel.helm_eye_height()
		if knee_deep and not rich_high_bilge:
			rich.react("bilge", toward)
		elif game.vessel != princecraft and moving and not rich_underway:
			rich.react("underway", toward)
		rich_underway = moving
		rich_high_bilge = knee_deep
	var see_subtitles: bool = rich.visible and (rich_aboard or rich.hull == story.yard.rich_stand) \
		and world_hud_available() and not dive.active
	var on_deck: Array[Vector3] = []
	if author and rich_aboard:
		if game.aboard():
			on_deck.append(rich.hull.to_local(game.player.global_position))
		for peer: int in crew.people:
			if peer != crew.my_id():
				var person := actor(peer)
				if person.get("onboard", false):
					on_deck.append(rich.hull.to_local(person.at))
		if game.vessel == princecraft:
			tick_princecraft_dialogue(delta, on_deck)
	rich.tick(delta, game.clock, game.eye, see_subtitles, author and rich_aboard, on_deck, author,
		game.weather_fx.sample.y * game.weather.gameplay_strength)


func begin_preview(id: String) -> void:
	preview_id = id
	preview_site = local_site()
	preview_angle = float(landings.sites[preview_site].heading) + PI
	preview_good = false
	close_board()


func cancel_preview(announce := true) -> void:
	if preview_id.is_empty():
		return
	preview_id = ""
	ghost.hide()
	if announce:
		game.notify_angling("Building cancelled.", 2.0)


func reset_princecraft_dialogue() -> void:
	princecraft_lines.clear()
	princecraft_line_wait = 0.0
	princecraft_had_crew = false
	princecraft_first_speed = false
	princecraft_was_moving = false


func tick_princecraft_dialogue(delta: float, on_deck: Array[Vector3]) -> void:
	princecraft_line_wait = maxf(0.0, princecraft_line_wait - delta)
	if on_deck.is_empty():
		princecraft_had_crew = false
		princecraft_was_moving = false
		princecraft_lines.clear()
		return
	if not princecraft_had_crew:
		princecraft_lines.append("princecraft_board")
		princecraft_had_crew = true
	if absf(princecraft.speed) > 2.15:
		princecraft_was_moving = true
		if not princecraft_first_speed:
			princecraft_lines.append("princecraft_speed")
			princecraft_first_speed = true
	elif princecraft_was_moving and absf(princecraft.speed) < .55 and absf(princecraft.throttle) < .045:
		princecraft_lines.append("princecraft_idle")
		princecraft_was_moving = false
	if princecraft_line_wait <= 0.0 and not princecraft_lines.is_empty() and rich.speaking_id.is_empty() \
			and rich.pending_topic.is_empty():
		rich.say(princecraft_lines.pop_front(), on_deck.front() + Vector3.UP * 1.45)
		princecraft_line_wait = 5.0


func tick_preview() -> void:
	if preview_id.is_empty():
		return
	if preview_site != local_site() or game.aboard():
		cancel_preview(false)
		return
	var eye: Camera3D = game.eye
	var point: Vector3 = landings.sites[preview_site].plot
	var ray := PhysicsRayQueryParameters3D.create(eye.global_position,
		eye.global_position - eye.global_basis.z * 30.0, 1, [game.player.get_rid()])
	var hit: Dictionary = game.get_world_3d().direct_space_state.intersect_ray(ray)
	if not hit.is_empty():
		point = hit.position
	preview_pose = landings.build_pose(preview_site, preview_id, point, preview_angle)
	preview_good = landings.allowed_pose(preview_site, preview_id, preview_pose)
	var size: Vector2 = Data.BUILDINGS[preview_id].size
	var height := .16 if preview_id in ["dock", "porch", "turbine"] else 2.45
	(ghost.mesh as BoxMesh).size = Vector3(size.x, height, size.y)
	ghost.global_transform = preview_pose.translated_local(Vector3.UP * (height * .5 + .017))
	ghost_paint.albedo_color = Color(.40, .77, .58, .37) if preview_good else Color(.91, .38, .28, .38)
	ghost.show()


func set_moored(index: int) -> void:
	var vessel: Boat = game.vessel
	var data: Dictionary = landings.sites[index]
	var space: float = -.22 if vessel.skiff else 0.0
	vessel.berth_at(data.berth + data.right * space, float(data.heading))
	mooring.seed_landing(vessel, index)
	vessel.departed = true
	if dock != index and vessel == rich.hull and not crew.is_guest():
		rich.react("dock", vessel.helm_anchor() + Vector3.UP * vessel.helm_eye_height())
	dock = index


func move_person(site: int, onto_boat: bool) -> void:
	var there: Dictionary = landings.sites[site]
	var mark: Vector3 = there.transfer
	game.release_line()
	game.player.global_position = game.vessel.to_global(game.vessel.board_anchor()) if onto_boat else mark
	game.player.reset_physics_interpolation()
	game.player.velocity = Vector3.ZERO
	game.yaw = float(there.heading) + (0.0 if onto_boat else PI)
	game.pitch = -.12
	game.update_view()


func keep_player_on_deck(boat: Boat, relative: Vector3) -> void:
	if game.player.global_position.distance_squared_to(boat.to_global(relative)) > 9.0:
		game.camera_motion.previous_feet = Vector3.INF
	game.player.global_position = boat.to_global(relative)
	game.player.reset_physics_interpolation()
	game.player.velocity = Vector3.ZERO


func craft_for(requested: String, index: int) -> Boat:
	if requested == "skiff":
		if not is_instance_valid(skiff):
			skiff = Boat.new()
			skiff.skiff = true
			prepare_compact_boat(skiff, index)
		if ledger.has_upgrade("foil"):
			skiff.add_foil()
		return skiff
	if requested == "princecraft":
		if not is_instance_valid(princecraft):
			princecraft = PrincecraftScene.instantiate() as Princecraft
			prepare_compact_boat(princecraft, index)
		return princecraft
	return houseboat


func prepare_compact_boat(boat: Boat, index: int) -> void:
	boat.center = landings.sites[index].berth
	boat.water_check = shallow_route
	boat.marina_check = game.river.marina_hull_clear
	boat.water_flow = game.river.boat_flow
	boat.wave_sampler = game.river.wave_height.bind(boat.get_instance_id())
	boat.river_engine = true
	boat.collision_layer = 0
	boat.hide()
	add_child(boat)


func select_craft(requested: String, index: int) -> void:
	var chosen := craft_for(requested, index)
	var previous: Boat = game.vessel
	if chosen == previous:
		return
	if not crew.is_guest():
		marina_fuel.disconnect_fillers()
	if chosen != houseboat and not amenities.occupants.is_empty():
		amenities.occupants.clear()
		amenities.publish()
	previous.hide()
	previous.collision_layer = 0
	previous.reset_ignition()
	chosen.show()
	chosen.collision_layer = 1
	game.vessel = chosen
	crew.boat = chosen
	deck.fit(chosen)
	crewplay.fit(chosen)
	if chosen == princecraft:
		reset_princecraft_dialogue()
	story.sync_world()
	rich_underway = false
	rich_high_bilge = false


func shallow_route(at: Vector3) -> bool:
	return game.river.can_sail(at, .49) and landings.pier_clear(at)


func houseboat_route(at: Vector3) -> bool:
	return game.river.can_sail(at) and landings.pier_clear(at)


func stop_captain() -> void:
	captain = 0
	guest_captain = 0
	crew.set_meta("captain", 0)
	game.driving = false
	game.vessel.clear_helm()
	remote_throttle = 0.0
	remote_rudder = 0.0
	remote_center_wheel = false
	remote_age = 99.0


func helm() -> void:
	request("helm", null)


func relinquish_helm() -> void:
	if crew.is_guest():
		if captain == crew.my_id():
			helm()
		game.driving = false
	else:
		stop_captain()
		changed(false)


func after_fall() -> Vector3:
	# Return swimmers near shore to the landing where they can wait for the crew.
	var shore := landings.site_range(game.player.global_position, 64.0, false)
	return landings.sites[shore].stand + Vector3.UP * .12 if shore >= 0 else \
		game.vessel.to_global(game.vessel.board_anchor())


func capacity() -> float:
	return 1.8 if ledger.has_upgrade("battery") else .46


func step_boat(delta: float, rudder: float) -> void:
	var vessel: Boat = game.vessel
	if crew.is_guest():
		tick_client_ship(delta)
		return
	if story.restrict_boat() and vessel == houseboat:
		return
	vessel.mooring.tick_anchor(delta)
	var secured := vessel.mooring.secured()
	if secured:
		vessel.throttle = 0.0
	if captain > 1:
		remote_age += delta
		vessel.throttle = remote_throttle if remote_age < .7 and not secured else 0.0
		rudder = remote_rudder if remote_age < .7 and not secured else 0.0
	var center_wheel: bool = remote_age < .7 and remote_center_wheel if captain > 1 else (
		game.driving and game.play_input() and Input.is_physical_key_pressed(KEY_X))
	if captain != 0 or game.driving:
		vessel.advance_steering(delta, rudder, center_wheel)
	vessel.tick_ignition(delta)
	if vessel.ignition != Boat.Ignition.RUN:
		vessel.throttle = 0.0
	elif captain == crew.my_id() and game.driving and not secured:
		vessel.throttle = vessel.requested_throttle
	consume_power(delta)
	var limiting: float = ledger.state.charge if vessel.uses_battery() else ledger.state.fuel
	vessel.throttle_cap = (.18 if limiting < .015 else 1.0) * lerpf(1.0, .52, smoothstep(.48, 1.0, ledger.state.bilge))
	var rebuilt_engine := vessel == houseboat and Story.Parts.upgrade_installed(story.state(), "outboard")
	vessel.top_speed = vessel.speed_limit(ledger.state.tow) * (1.18 if rebuilt_engine else 1.0)
	var before := vessel.center
	vessel.sail(delta, game.clock, captain != 0 or game.driving, rudder * (1.0 + skill_effect(captain, "experienced_captain") / 100.0))
	if dock < 0 and absf(vessel.throttle) > .1 and absf(vessel.speed) > .3:
		var distance := before.distance_to(vessel.center)
		travel_progress(captain, "boat", distance, 20.0 * delta)
		story.powered_distance(captain, distance, delta)
	var active := ledger.active_job()
	if not active.is_empty() and active.kind == "freight" and absf(vessel.throttle) > .21:
		ledger.state.freight_run += before.distance_to(vessel.center)
		if captain > 0 and before.distance_to(vessel.center) <= 20.0 * delta:
			var sailor := progression_for(captain)
			if int(sailor.get("freight_job", -1)) != ledger.state.job_serial:
				sailor.freight_job = ledger.state.job_serial
				sailor.freight_meters = 0.0
			sailor.freight_meters += before.distance_to(vessel.center)
			if sailor.freight_meters >= 25.0:
				sailor.worked_job = ledger.state.job_serial
	if dock >= 0 and vessel.skiff:
		vessel.position.y += .09


func consume_power(delta: float) -> void:
	var vessel: Boat = game.vessel
	var state := ledger.state
	var load := absf(vessel.throttle) if dock < 0 else 0.0
	if dock >= 0:
		var current: Vector3 = game.river.downstream(vessel.center, game.clock)
		var main_feed := ledger.power_at(dock, current.length())
		state.charge = minf(capacity(), state.charge + delta * (.004 + main_feed * .021))
		if ledger.has_at(dock, "boathouse"):
			state.fuel = minf(Ledger.FUEL_CAPACITY, state.fuel + delta * 1.8)
	elif vessel.uses_battery():
		state.charge = maxf(0.0, state.charge - delta * load * (.014 + vessel.foil_lift * .010))
	else:
		var companion_use := 1.0 - Story.FUEL_SAVING if story.companion_aboard() else 1.0
		state.fuel = maxf(0.0, state.fuel - delta * load * .040 * companion_use * (1.0 - skill_effect(captain, "fuel_conservation") / 100.0))
		state.charge = minf(capacity(), state.charge + delta * load * .0035)
	if vessel == houseboat and Story.Parts.upgrade_installed(story.state(), "solar") and game.river.solar_energy > .2:
		state.charge = minf(capacity(), state.charge + delta * .0028)
	if load > .2:
		var motion := absf(vessel.wave_pose.y) + absf(vessel.wave_pose.z)
		state.bilge = minf(1.0, state.bilge + delta * load * (.002 + motion * .022 * (1.0 - skill_effect(captain, "smooth_sailing") / 100.0)))
	if state.pump_on and ledger.has_upgrade("pump") and state.charge > .025 and state.bilge > 0:
		state.bilge = maxf(0.0, state.bilge - delta * .087)
		state.charge = maxf(0.0, state.charge - delta * .008)
	if diver > 0:
		state.charge = maxf(0.0, state.charge - delta * .002)
	if crewplay.lamp_on:
		state.charge = maxf(0.0, state.charge - delta * .0019)


func update_target() -> void:
	var task := ledger.active_job()
	if not task.is_empty() and task.has("offset") and ledger.state.stage == "travel":
		deck.set_target(task.kind, target_for_job(), task.name)
	else:
		deck.set_target("", Vector3.ZERO, "")


func target_for_job() -> Vector3:
	return job_targets.get(int(ledger.state.job), Vector3.ZERO)


func work_radius(kind: String) -> float:
	if kind == "survey":
		return 17.5 if ledger.has_upgrade("sonar") else 11.0
	return 15.5 if kind == "dive" else 9.2


func tick(delta: float, has_input: bool) -> void:
	var vessel: Boat = game.vessel
	story.tick_work()
	tick_preview()
	tick_lift(delta)
	if dive.active and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		var up: float = game.axis(KEY_SPACE, KEY_CTRL)
		dive.advance(delta, Vector3(game.axis(KEY_D, KEY_A), up, -game.axis(KEY_W, KEY_S)))
	var target := target_for_job()
	var wave: float = game.river.wave_height(target, game.clock)
	deck.animate(delta, wave, ledger, target, lift_amount, game.clock)
	for slot in vessel.mooring.lines.size():
		var holder := int(vessel.mooring.lines[slot].get("holder", 0))
		if holder <= 0 or crew.is_guest():
			continue
		var person := actor(holder)
		var coil := vessel.to_global(vessel.mooring.stations[slot])
		if person.is_empty() or Vector3(person.at).distance_to(coil) > 7.0:
			vessel.mooring.lines[slot] = {}
	deck.draw_mooring(actor, delta)
	landings.animate(delta, game.clock)
	marina_fuel.tick(delta, has_input and game.can_use_fuel())
	if crew.tick(delta, game.player, game.aboard(), game.yaw, game.capture_crew_pose, game.clock, game.eye.global_position):
		if crew.on_server():
			send_ship()
		elif game.driving:
			crew.steer.rpc_id(1, vessel.requested_throttle, float(game.axis(KEY_D, KEY_A)) if has_input else 0.0,
				has_input and Input.is_physical_key_pressed(KEY_X))
	crewplay.tick(delta)
	amenities.tick(delta)
	tick_rich(delta)
	reaper.tick(delta)
	if not crew.is_guest() and dock >= 0:
		save_elapsed += delta
		if save_elapsed >= 30.0:
			save_elapsed = 0.0
			story.save_vehicle_poses()
			ledger.save_file()
	update_info()


func request(action: String, value: Variant) -> void:
	if crew.mode == "guest":
		crew.order.rpc_id(1, action, value)
	elif not crew.is_guest():
		perform(crew.my_id(), action, value)


func remote_request(peer: int, action: String, value: Variant) -> void:
	if action == "connected":
		crew.share_state.rpc_id(peer, snapshot_for(peer), dock, captain, revision)
		crewplay.welcome(peer)
		amenities.welcome(peer)
		game.helicopter.welcome(peer)
		if story.shore_arrival():
			crew.result.rpc_id(peer, "Welcome to Deep River Marina. B opens the notebook.", STORY_ARRIVAL - story.use_guest_slot(peer), false)
		else:
			crew.result.rpc_id(peer, "Welcome aboard. B opens the notebook.", dock, actor_site(actor(1)) < 0)
		crew.enter_river.rpc_id(peer, initial_ship_packet())
		return
	if crew.started:
		perform(peer, action, value)


func tell(peer: int, text: String, at_site := -2, to_boat := false) -> void:
	if peer != crew.my_id():
		crew.result.rpc_id(peer, text, at_site, to_boat)
	else:
		receive_result(text, at_site, to_boat)


func receive_result(text: String, at_site: int, to_boat: bool) -> void:
	if at_site == game.properties.RESULT:
		game.properties.report(text)
		return
	if at_site == LAUNCH_REFUSED:
		boats_menu.report(text, false)
		return
	if at_site == LAUNCH_READY:
		boats_menu.report(text, true)
	elif at_site == STORY_ENGINE_TEST:
		story.test_sound.play()
	elif at_site == LAUNCH_ASHORE:
		var wharf = game.river.waterfront.wharf
		game.release_line()
		game.player.global_position = wharf.boarding_step + Vector3.UP * .045
		game.player.reset_physics_interpolation()
		game.player.velocity = Vector3.ZERO
		game.yaw = wharf.launch_heading + PI
		game.pitch = -.10
		game.update_view()
	elif at_site <= STORY_ARRIVAL and at_site > STORY_ARRIVAL - story.yard.arrivals.size():
		story.arrive(STORY_ARRIVAL - at_site)
	elif at_site == -3:
		begin_dive()
	elif at_site >= 0:
		move_person(at_site, to_boat)
	elif at_site == -1 and to_boat:
		keep_player_on_deck(game.vessel, game.vessel.board_anchor())
	if not text.is_empty():
		message = text
		if board.visible:
			board.set_message(text)
		else:
			game.notify_angling(text, 4.4)


func changed(persist := true) -> void:
	houseboat.set_modern_design(ledger.state.get("modern_houseboat", false))
	story.sync_world()
	if persist and not crew.is_guest():
		story.save_vehicle_poses()
		ledger.save_file()
		if not ledger.error.is_empty():
			message = ledger.error
	landings.sync_structures()
	update_target()
	update_route_map()
	if crew.on_server() and crew.people.size() > 1:
		for peer: int in crew.people:
			if peer != crew.my_id():
				crew.share_state.rpc_id(peer, snapshot_for(peer), dock, captain, revision)
	refresh_board()


func profile_key(peer: int) -> String:
	if peer == crew.my_id():
		return crew.progression_secret.sha256_text()
	return str(crew.progression_keys.get(peer, ""))


func progression_for(peer: int) -> Dictionary:
	var id := "self" if crew.is_guest() else profile_key(peer)
	if id.is_empty():
		return {}
	if crew.is_guest():
		return ledger.state.progression.get("self", {})
	if not ledger.state.progression.has(id):
		ledger.state.progression[id] = {"version": 1}
	return ledger.state.progression[id]


func skill_effect(peer: int, id: String) -> float:
	return XP.effect(progression_for(peer), id) if peer > 0 else 0.0


func rank_for(peer: int, skill: String) -> int:
	if peer <= 0:
		return 0
	return int(progression_for(peer).get("ranks", {}).get(skill, 0))


func travel_progress(peer: int, kind: String, distance: float, maximum: float) -> void:
	if peer <= 0 or distance <= 0 or distance > maximum:
		return
	var profile := progression_for(peer)
	var meter_key := kind + "_meters"
	var serial_key := kind + "_serial"
	var meters := float(profile.get(meter_key, 0)) + distance
	if meters >= 500.0:
		profile[serial_key] = int(profile.get(serial_key, 0)) + 1
		XP.award(profile, kind, "%s:%d" % [kind, profile[serial_key]])
		meters -= 500.0
		profile[meter_key] = meters
		changed()
	else:
		profile[meter_key] = meters


func snapshot_for(peer: int) -> Dictionary:
	var snapshot := ledger.state.duplicate(false)
	snapshot.erase("player_position")
	snapshot.dab_pen = game.dab_pen.snapshot_for(peer)
	var personal := progression_for(peer).duplicate(false)
	personal.erase("events")
	snapshot.progression = {"self": personal}
	return snapshot


func mowing_pay(amount: int) -> int:
	return roundi(amount * (1.0 + skill_effect(crew.my_id(), "lawn_professional") / 100.0))


func reward_mowing(day: int, amount: int, commercial: bool) -> int:
	if crew.is_guest() or day < 0 or amount <= 0:
		return 0
	var completion_key := "last_commercial_day" if commercial else "last_mowing_day"
	if day <= int(ledger.state[completion_key]):
		return 0
	var profile := progression_for(crew.my_id())
	XP.award(profile, "commercial" if commercial else "route", "mow:%d:%d" % [day, int(commercial)])
	var paid := mowing_pay(amount)
	ledger.state[completion_key] = day
	ledger.state.cash += paid
	changed()
	return paid


func add_test_cash() -> void:
	if crew.mode == "solo":
		ledger.state.cash += 100
		changed()
		tell(crew.my_id(), "Added $100.00 test cash. Wallet $%.2f." % (ledger.wallet_cents() / 100.0))


func perform(peer: int, action: String, value: Variant) -> void:
	if action == game.properties.ACTION:
		game.properties.perform(peer, value)
		return
	if action == "purchase_skill":
		if value is Array and value.size() == 2 and value[0] is String and value[1] is int:
			var profile := progression_for(peer)
			if int(profile.get("ranks", {}).get(value[0], 0)) == value[1] and XP.buy(profile, value[0]):
				changed()
		return
	if action in ["fuel_nozzle", "fuel_trigger"]:
		marina_fuel.action(peer, action, value, actor(peer))
		return
	if action == "boat_anchor":
		if captain == peer:
			toggle_anchor(peer)
		return
	if action == "boat_ignition":
		if captain == peer:
			var vessel: Boat = game.vessel
			match value:
				"start":
					if vessel.ignition == Boat.Ignition.OFF:
						vessel.set_ignition(Boat.Ignition.START)
				"cancel":
					if vessel.ignition == Boat.Ignition.START:
						vessel.set_ignition(Boat.Ignition.OFF)
				"finish":
					if vessel.ignition == Boat.Ignition.START:
						vessel.crank_confirmed = true
				"stop":
					if vessel.ignition == Boat.Ignition.RUN:
						vessel.set_ignition(Boat.Ignition.OFF)
						remote_throttle = 0.0
		return
	if action.begins_with("aircraft_"):
		game.helicopter.act(peer, action, value)
		return
	if action.begins_with("amenity_"):
		amenities.act(peer, action, value)
		return
	if action == "rich_talk":
		if not start_rich_chat(peer) and peer != crew.my_id() and not rich_chat_requests.has(peer):
			# The reliable request can reach the host before the next deck position packet.
			rich_chat_requests[peer] = game.clock + 2.0
		return
	var person := actor(peer)
	if person.is_empty():
		tell(peer, "Move a step so the host can see where you are.", LAUNCH_REFUSED if action == "marina_launch" else -2)
		return
	if action == Story.ACTION:
		story.perform(peer, value, person)
		return
	if action == game.dab_pen.ACTION:
		game.dab_pen.perform(peer, value, person)
		return
	if action == ReaperQuest.ID:
		reaper.perform(peer, value)
		return
	if action.begins_with("crew_"):
		crewplay.act(peer, action, value, person)
		return
	var place := actor_site(person)
	match action:
		"rich_lost":
			if person.onboard and game.vessel == rich.hull:
				rich.react("lost", rich.hull.to_local(person.at) + Vector3.UP * 1.57)
		"dock":
			use_dock(peer, person, place)
		"ground_tackle":
			use_ground_tackle(peer, person, value)
		"marina_launch":
			spawn_at_marina(peer, person, str(value))
		"marina_ashore":
			step_ashore_at_launch(peer, person)
		"helm":
			use_helm(peer, person)
		"travel":
			if value is int and value >= 0 and value < Data.SITES.size():
				travel(peer, value, place)
		"claim":
			if at_plot(person, place):
				claim(peer, place)
		"build":
			if at_plot(person, place):
				build(peer, place, value)
		"door":
			if value is String and not person.onboard:
				for hinge: AnimatableBody3D in landings.doors:
					if is_instance_valid(hinge) and hinge.get_meta("door_id") == value and \
							hinge.global_position.distance_to(person.at) < 3.2:
						ledger.state.doors[value] = not ledger.state.doors.get(value, false)
						changed(false)
						break
		"fabricate":
			if value is String and Data.UPGRADES.has(value):
				fabricate(peer, place, value)
		"launch":
			if value is String:
				launch(peer, place, value)
		"supply":
			if place >= 0 and value is String:
				resupply(peer, place, value)
		"route":
			if value is int and value >= 0 and value < Data.SITES.size():
				commission_route(peer, place, value)
		"lift":
			if place >= 0 and ledger.has_at(place, "drydock") and ledger.has_at(place, "turbine"):
				var up: bool = not ledger.state.lifts.get(str(place), false)
				ledger.state.lifts[str(place)] = up
				changed()
				tell(peer, "Raising the inspection cradle." if up else "Lowering the inspection cradle.")
		"pump":
			if person.onboard and ledger.has_upgrade("pump"):
				ledger.state.pump_on = not ledger.state.pump_on
				changed()
				tell(peer, "Automatic bilge pump on." if ledger.state.pump_on else "Automatic bilge pump off.")
				if ledger.state.pump_on and game.vessel == rich.hull:
					rich.react("pump", rich.hull.to_local(person.at) + Vector3.UP * 1.57)
		"manual":
			if person.onboard or place >= 0:
				ledger.state.bilge = 0.0
				changed()
				tell(peer, "You pumped the bilge dry by hand.")
		"accept":
			if value is int and value >= 0 and value < Data.WORK.size():
				accept_job(peer, place, value)
		"deliver":
			deliver(peer, place)
		"abandon":
			if not ledger.active_job().is_empty() and place >= 0 and lifting_peer == 0 and diver == 0:
				clear_job()
				changed()
				tell(peer, "Job put back on the board.")
		"work":
			work_at_buoy(peer, person)
		"catch":
			if not value is Array or value.size() != 2 or not value[0] is String or not value[1] is int:
				return
			if person.onboard or place >= 0:
				count_catch(peer, String(value[0]).substr(0, 42), clampi(value[1], 2, 200), person.at)
				if person.onboard and game.vessel == rich.hull:
					rich.react("catch", rich.hull.to_local(person.at) + Vector3.UP * 1.57)
		"start_dive":
			if can_dive(person):
				diver = peer
				changed(false)
				if peer == crew.my_id():
					begin_dive()
				else:
					crew.result.rpc_id(peer, "", -3, false)
			else:
				tell(peer, "Stop within 15 m of the recorder buoy with the survey sub fitted.")
		"finish_dive":
			if diver == peer:
				diver = 0
				if value == true and not ledger.active_job().is_empty() and ledger.active_job().kind == "dive":
					ledger.state.stage = "return"
					if peer == crew.my_id():
						progression_for(peer).worked_job = ledger.state.job_serial
					changed()
					tell(peer, "Recorder aboard. Bring it back to Chalk River.")
				else:
					changed(false)


func use_dock(peer: int, person: Dictionary, place: int) -> void:
	if diver > 0 or lifting_peer > 0:
		tell(peer, "Stow the equipment before going ashore.")
		return
	if dock < 0:
		tell(peer, "Tie the bow and stern lines at a landing to use this shortcut.")
	elif person.onboard:
		tell(peer, "Ashore at %s. Follow the pier and press B at the cabin plot." % Data.dock_name(dock), dock)
	elif place == dock:
		tell(peer, "Aboard at %s. Untie both lines before leaving." % Data.dock_name(dock), dock, true)
	else:
		tell(peer, "Your boat is tied up at %s." % Data.dock_name(dock))


func use_ground_tackle(peer: int, person: Dictionary, value: Variant) -> void:
	if diver > 0 or lifting_peer > 0 or peer == captain or not value is Array or value.size() != 3:
		return
	if not value[0] is String or not value[1] is int or not value[2] is int:
		return
	if marina_fuel.held_by(peer) != null or not crewplay.held_by(peer).is_empty() or not crewplay.held_fish(peer).is_empty():
		return
	var boat: Boat = game.vessel
	var was_at_launch := mooring.at_launch(boat)
	var result := mooring.act(boat, peer, person, value)
	if result.is_empty():
		return
	var berth := mooring.site_for(boat)
	if value[0] == "tie" and value[1] >= 0 and value[1] < boat.mooring.lines.size() and boat.mooring.attached(value[1]) and captain != 0:
		stop_captain()
		changed(false)
	if berth != dock:
		dock = berth
		if dock >= 0:
			if boat == rich.hull:
				rich.react("dock", boat.helm_anchor() + Vector3.UP * boat.helm_eye_height())
			XP.award(progression_for(peer), "discovery", "berth:%d" % dock)
			story.docked(peer, dock)
			save_berth(dock)
			result += " Tied up at %s. L goes ashore or boards." % Data.dock_name(dock)
		else:
			changed(false)
	if story.managed() and not was_at_launch and mooring.at_launch(boat):
		story.docked(peer, 0)
		changed()
	if crew.on_server() and crew.people.size() > 1:
		send_ship()
	tell(peer, result)


func toggle_anchor(peer: int) -> void:
	var boat: Boat = game.vessel
	var tackle := boat.mooring
	if tackle.anchor.is_finite():
		if not tackle.anchor_down:
			return
		tackle.anchor_down = false
	else:
		var selected := remote_throttle if captain > 1 else boat.requested_throttle
		var level := boat.center + Basis(Vector3.UP, boat.heading) * tackle.anchor_lead()
		var depth: float = game.river.depth_at(level)
		if tackle.tied() or absf(boat.speed) > Mooring.MAX_SPEED or absf(selected) > .02 or depth <= .45:
			tell(peer, "Shift to neutral and slow down in open water to lower the anchor.")
			return
		tackle.anchor = Vector3(level.x, -depth, level.z)
		tackle.anchor_down = true
		boat.departed = true
	boat.neutral_throttle()
	remote_throttle = 0.0
	if crew.on_server() and crew.people.size() > 1:
		send_ship()


func use_helm(peer: int, person: Dictionary) -> void:
	if captain != 0 and captain != peer:
		tell(peer, "%s is at the wheel." % crew.person(captain).get("name", "Another crew member"))
		return
	if captain == peer:
		stop_captain()
		changed(false)
		return
	if not person.onboard or diver > 0 or lifting_peer > 0:
		return
	if marina_fuel.held_by(peer) != null:
		tell(peer, "Return the fuel nozzle before taking the helm.")
		return
	if not crewplay.held_by(peer).is_empty() or not crewplay.held_fish(peer).is_empty() or crewplay.lamp_operator == peer:
		tell(peer, "Set down the gear or release the light before taking the wheel.")
		return
	var boat: Boat = game.vessel
	if story.restrict_boat() and boat == houseboat:
		return
	if Vector3(person.at).distance_to(boat.to_global(boat.helm_anchor())) > 1.33:
		return
	if boat.mooring.tied():
		tell(peer, "Untie the dock lines before leaving.")
		return
	if boat.mooring.held_by(peer) >= 0:
		tell(peer, "Put down the dock line before taking the wheel.")
		return
	dock = -1
	boat.departed = true
	if story.managed():
		ledger.state.last_dock = -1
	captain = peer
	crew.set_meta("captain", captain)
	if peer == crew.my_id():
		game.interact()
	changed(false)


func save_berth(index: int) -> void:
	ledger.state.player_position.clear()
	ledger.state.last_dock = index
	if not ledger.state.visited.has(index) and not ledger.state.visited.has(float(index)):
		ledger.state.visited.append(index)
	changed()


func ferry_open(index: int) -> bool:
	return index < 3 or ledger.state.surveys.has("0") or \
		ledger.state.visited.has(index) or ledger.state.visited.has(float(index))


func ferry_distance() -> bool:
	return dock >= 0 or (game.aboard() and captain == 0 and absf(game.vessel.speed) < .7 and \
		game.vessel.center.distance_to(game.river.point(1)) < 240.0)


func travel(peer: int, destination: int, place: int, evening_trip := false) -> bool:
	var person := actor(peer)
	var original_spawn: bool = dock < 0 and person.onboard and captain == 0 \
		and absf(game.vessel.speed) < .7 and game.vessel.center.distance_to(game.river.point(1)) < 240.0
	if (place != dock or dock < 0) and not original_spawn:
		tell(peer, "Travel from a landing while the boat is tied up.")
		return false
	if not ferry_open(destination) or (original_spawn and destination != 0 and not evening_trip):
		tell(peer, "Tie up at the marina first. Survey the channel to open the regional ferry.")
		return false
	if diver > 0 or lifting_peer > 0:
		tell(peer, "Finish or put away the equipment first.")
		return false
	for id: int in crew.people:
		var other := actor(id)
		if not other.is_empty() and not other.onboard and actor_site(other) != dock:
			tell(peer, "Wait until the entire crew is back at this landing.")
			return false
	var fee := 12 if destination >= 3 and destination != dock and not ledger.connected(dock, destination) else 0
	if ledger.state.cash < fee:
		tell(peer, "This crossing costs $%d." % fee)
		return false
	var local_comes: bool = game.aboard() or local_site() == dock
	ledger.state.cash -= fee
	stop_captain()
	set_moored(destination)
	revision += 1
	if local_comes and peer != crew.my_id():
		move_person(destination, false)
	save_berth(destination)
	tell(peer, "Arrived at %s. L boards the boat." % Data.dock_name(destination), destination)
	return true


func claim(peer: int, place: int) -> void:
	if not ledger.site(place).is_empty():
		tell(peer, "This plot already belongs to a member of the crew.")
		return
	var who := crew.person(peer)
	var count := 0
	for other: Dictionary in ledger.state.sites.values():
		if other.get("owner") == who.profile:
			count += 1
	var price := 45 if count > 0 else 0
	if ledger.state.cash < price:
		tell(peer, "An additional plot costs $45.")
		return
	ledger.state.cash -= price
	ledger.state.sites[str(place)] = {"owner": who.profile, "name": who.name, "buildings": {}, "deliveries": 0}
	changed()
	tell(peer, "Plot claimed at %s. Choose a cabin or workshop." % Data.dock_name(place))


func may_build(place: int, id: String) -> String:
	if ledger.site(place).is_empty():
		return "Claim the plot first."
	if ledger.has_at(place, id):
		return "Already built."
	var plan: Dictionary = Data.BUILDINGS[id]
	if not ledger.affordable(plan):
		return "You need more supplies."
	if not Data.requirement(str(plan.get("needs", "")), ledger.state.equipment):
		return "Requires %s." % Data.UPGRADES[plan.needs].name
	if id == "porch" and not ledger.has_at(place, "cabin"):
		return "Build the cabin first."
	return ""


func build(peer: int, place: int, args: Variant) -> void:
	if not (args is Array and args.size() == 4 and args[0] == place and args[1] is String and Data.BUILDINGS.has(args[1]) \
			and args[2] is Vector3 and args[2].is_finite() and (args[3] is float or args[3] is int) and is_finite(args[3])):
		return
	var id: String = args[1]
	var disallowed := may_build(place, id)
	if not disallowed.is_empty():
		tell(peer, disallowed)
		return
	var pose := landings.build_pose(place, id, args[2], args[3])
	if not landings.allowed_pose(place, id, pose):
		tell(peer, "Choose a level spot with room around it.")
		return
	ledger.spend(Data.BUILDINGS[id])
	ledger.site(place).buildings[id] = landings.record(pose)
	changed()
	tell(peer, "%s built at %s." % [Data.BUILDINGS[id].name, Data.dock_name(place)])


func may_make(place: int, id: String) -> String:
	if ledger.has_upgrade(id):
		return "Installed."
	if place < 0 or not ledger.has_at(place, "workshop"):
		return "Use a workshop at a claimed landing."
	var item: Dictionary = Data.UPGRADES[id]
	if not Data.requirement(str(item.get("needs", "")), ledger.state.equipment):
		return "Requires %s." % Data.UPGRADES[item.needs].name
	if ledger.state.surveys.size() < item.get("surveys", 0):
		return "Complete a depth survey first."
	if item.get("drydock", false) and (not ledger.has_at(place, "drydock") or not ledger.has_at(place, "turbine")):
		return "Requires a dry dock and current turbine here."
	if not ledger.affordable(item):
		return "Earn more supplies from jobs."
	return ""


func fabricate(peer: int, place: int, id: String) -> void:
	var reason := may_make(place, id)
	if not reason.is_empty():
		tell(peer, reason)
		return
	ledger.spend(Data.UPGRADES[id])
	ledger.state.equipment[id] = true
	if id == "battery":
		ledger.state.charge = capacity()
	if id == "foil" and is_instance_valid(skiff):
		skiff.add_foil()
	changed()
	tell(peer, "%s ready." % Data.UPGRADES[id].name)


func launch(peer: int, place: int, value: String) -> void:
	if place < 0 or place != dock or diver > 0 or lifting_peer > 0:
		tell(peer, "Tie up at a landing before switching boats or fittings.")
		return
	var person := actor(peer)
	if value == "barge":
		if not ledger.has_upgrade("barge") or game.vessel.skiff:
			tell(peer, "The crane barge hitches to the houseboat.")
			return
		ledger.state.tow = not ledger.state.tow
		changed()
		tell(peer, "Crane barge hitched." if ledger.state.tow else "Crane barge tied up.")
		return
	if value not in ["houseboat", "skiff"] or (value == "skiff" and not ledger.has_upgrade("skiff")):
		return
	var was_aboard: bool = game.aboard()
	ledger.state.craft = value
	ledger.state.tow = false
	stop_captain()
	select_craft(value, place)
	set_moored(place)
	revision += 1
	if was_aboard and peer != crew.my_id():
		move_person(place, true)
	save_berth(place)
	tell(peer, "Electric skiff launched." if game.vessel.skiff else "Rich's houseboat ready.", place, person.onboard)


func resupply(peer: int, place: int, supply: String) -> void:
	var cost := 8 if ledger.has_at(place, "boathouse") else 14
	var available: String = Data.SITES[place].supply
	match supply:
		"fuel":
			if ledger.has_at(place, "boathouse"):
				cost = 0
		"wood", "parts":
			if supply == available:
				cost = 10
		_:
			return
	if cost > 0 and ledger.dock_network(place):
		cost -= 3
	if ledger.state.cash < cost:
		tell(peer, "You need $%d." % cost)
		return
	ledger.state.cash -= cost
	match supply:
		"fuel":
			ledger.state.fuel = Ledger.FUEL_CAPACITY
			ledger.state.charge = capacity()
		"wood":
			ledger.state.wood += 10
		"parts":
			ledger.state.parts += 5
	changed()
	tell(peer, "Resupplied at %s." % Data.dock_name(place))


func can_connect(a: int, b: int) -> bool:
	return a >= 0 and a != b and not ledger.connected(a, b) and ferry_open(b) \
		and ledger.has_at(a, "cabin") and ledger.has_at(b, "cabin")


func commission_route(peer: int, a: int, b: int) -> void:
	if not can_connect(a, b) or ledger.state.cash < 25:
		tell(peer, "Build a cabin at both landings and set aside $25 for the route.")
		return
	ledger.state.cash -= 25
	ledger.state.routes[ledger.route_key(a, b)] = {"a": a, "b": b, "shipments": 0}
	changed()
	tell(peer, "Supply line open between %s and %s." % [Data.dock_name(a), Data.dock_name(b)])


func reposition_routes() -> void:
	route_map_version = ""
	update_route_map()


func update_route_map() -> void:
	var key := "%s/%s" % [str(ledger.state.routes.keys()), str(ledger.state.sites.keys())]
	if key == route_map_version:
		return
	route_map_version = key
	for child in route_map.get_children():
		route_map.remove_child(child)
		child.queue_free()
	for connection: Dictionary in ledger.state.routes.values():
		var path := Line2D.new()
		path.width = 2.5
		path.antialiased = true
		path.default_color = Color("#875621d9")
		path.add_point(game.chart.map_point(landings.sites[int(connection.a)].berth))
		path.add_point(game.chart.map_point(landings.sites[int(connection.b)].berth))
		route_map.add_child(path)
	for i in landings.sites.size():
		var shape := Polygon2D.new()
		shape.position = game.chart.map_point(landings.sites[i].berth)
		shape.polygon = PackedVector2Array([Vector2(0, -5), Vector2(4, 0), Vector2(0, 5), Vector2(-4, 0)])
		shape.color = Color("#a96728") if not ledger.site(i).is_empty() else Color("#527162")
		route_map.add_child(shape)


func accept_job(peer: int, place: int, index: int) -> void:
	var plan: Dictionary = Data.WORK[index]
	if not ledger.active_job().is_empty() or place != int(plan.home):
		tell(peer, "Meet the job at its listed landing. The crew can run one job at a time.")
		return
	if plan.has("skill") and rank_for(peer, plan.skill) < 1:
		return
	if not Data.requirement(str(plan.get("needs", "")), ledger.state.equipment):
		tell(peer, "Requires %s." % Data.UPGRADES[plan.needs].name)
		return
	ledger.state.verified_job_fish = 0
	ledger.state.job_serial += 1
	ledger.state.job = index
	ledger.state.job_fish = []
	ledger.state.freight_run = 0.0
	ledger.state.stage = "return" if plan.kind == "freight" else "travel"
	changed()
	tell(peer, "Job accepted. %s" % plan.detail)


func work_at_buoy(peer: int, person: Dictionary) -> void:
	var job := ledger.active_job()
	if job.is_empty() or ledger.state.stage != "travel" or not job.has("offset") or not person.onboard:
		return
	if not at_work_target(job.kind):
		tell(peer, "Stop the boat beside the marker.")
		return
	match job.kind:
		"survey":
			var center: Vector3 = game.vessel.center
			var depth: float = game.river.depth_at(center)
			var current: Vector3 = game.river.downstream(center, game.clock)
			ledger.state.surveys[str(job.home)] = {"depth": snappedf(depth, .01 if ledger.has_upgrade("sonar") else .1),
				"current": snappedf(current.length(), .01)}
			ledger.state.stage = "return"
			progression_for(peer).worked_job = ledger.state.job_serial
			changed()
			tell(peer, "Sounding logged. %.1f m deep, %.2f m/s current. Return to %s." % [depth, current.length(), Data.dock_name(job.home)])
		"rescue":
			if game.vessel.skiff:
				tell(peer, "Bring Rich's houseboat for the tow.")
				return
			ledger.state.stage = "return"
			progression_for(peer).worked_job = ledger.state.job_serial
			changed()
			tell(peer, "Towline secured. Take the angler back to the marina.")
		"salvage":
			if job.get("needs") == "barge" and not ledger.state.tow:
				tell(peer, "Hitch the crane barge before coming back here.")
			elif ledger.state.charge < .10:
				tell(peer, "Charge the battery before lifting.")
			elif lifting_peer == 0:
				lifting_peer = peer
				tell(peer, "Cable connected. Stay alongside while it lifts.")


func at_work_target(kind: String) -> bool:
	return absf(game.vessel.speed) < .98 and game.vessel.center.distance_to(target_for_job()) <= work_radius(kind)


func tick_lift(delta: float) -> void:
	if lifting_peer == 0 or crew.is_guest():
		return
	if not at_work_target("salvage") or ledger.state.charge <= .015:
		tell(lifting_peer, "Lift stopped. Return beside the marker with a charged battery.")
		lift_amount = 0.0
		lifting_peer = 0
		return
	lift_amount += delta * (.23 if ledger.state.tow else .17)
	ledger.state.charge = maxf(0.0, ledger.state.charge - delta * .014)
	if lift_amount >= 1.0:
		ledger.state.stage = "return"
		progression_for(lifting_peer).worked_job = ledger.state.job_serial
		var worker := lifting_peer
		lifting_peer = 0
		lift_amount = 0.0
		changed()
		tell(worker, "Crate secured aboard. Return to %s." % Data.dock_name(ledger.active_job().home))


func count_catch(peer: int, species: String, length: int, at: Vector3) -> void:
	story.record_catch(peer, at)
	var previous: Dictionary = ledger.state.records.get(species, {})
	var worthy := int(previous.get("length", 0)) < length
	if worthy:
		ledger.state.records[species] = {"length": length, "name": crew.person(peer).name}
	var job := ledger.active_job()
	if not job.is_empty() and job.kind == "fish" and ledger.state.stage == "travel" \
			and (job.home == 0 or Vector3(landings.sites[job.home].berth).distance_to(at) < 430.0):
		if job.home == 0 or not ledger.state.job_fish.has(species):
			if peer == crew.my_id():
				ledger.state.verified_job_fish += 1
				progression_for(peer).worked_job = ledger.state.job_serial
			ledger.state.job_fish.append(species)
			if ledger.state.job_fish.size() >= 2:
				ledger.state.stage = "return"
				tell(peer, "Both fish logged. Check in at %s for the reward." % Data.dock_name(job.home))
			changed()
			return
	if worthy:
		changed()


func deliver(peer: int, place: int) -> void:
	var job := ledger.active_job()
	if job.is_empty() or ledger.state.stage != "return" or place != job.get("dest", job.home):
		tell(peer, "Reach the listed landing after finishing the job.")
		return
	var member := crew.person(peer)
	var reward: Array = job.reward.duplicate()
	if job.kind == "freight":
		var origin: Vector3 = landings.sites[job.home].berth
		if ledger.state.freight_run >= origin.distance_to(landings.sites[place].berth) * .78:
			reward[0] += roundi(float(job.reward[0]) * .20)
		var line: Dictionary = ledger.state.routes.get(ledger.route_key(job.home, place), {})
		if not line.is_empty():
			reward[0] += roundi(float(job.reward[0]) * .12)
			reward[2] += 2
			line.shipments += 1
	var profile := progression_for(peer)
	var eligible: bool = job.kind != "fish" or int(ledger.state.get("verified_job_fish", 0)) >= 2
	if job.kind == "freight":
		var run_required: float = landings.sites[job.home].berth.distance_to(landings.sites[place].berth) * .78
		eligible = ledger.state.freight_run >= run_required
	var history: Dictionary = profile.get("contract_completions", {})
	var completed := int(history.get(job.kind, 0))
	var bonus := XP.effect(profile, "better_negotiator")
	if eligible and int(profile.get("worked_job", -1)) == ledger.state.job_serial:
		bonus += mini(3, completed / 4) * 5
	if eligible:
		for contributor: Dictionary in ledger.state.progression.values():
			if int(contributor.get("worked_job", -1)) == ledger.state.job_serial:
				XP.award(contributor, "fish_delivery" if job.kind == "fish" else "delivery", "job:%d" % ledger.state.job_serial)
				var record: Dictionary = contributor.get("contract_completions", {})
				record[job.kind] = int(record.get(job.kind, 0)) + 1
				contributor.contract_completions = record
	if job.kind == "freight":
		bonus += XP.effect(profile, "delivery_specialist")
	reward[0] = roundi(float(reward[0]) * (1.0 + bonus / 100.0))
	ledger.award(member.profile, member.name, reward[0], reward[1], reward[2], place)
	clear_job()
	changed()
	tell(peer, "Job finished. +$%d, +%d timber, +%d parts." % [reward[0], reward[1], reward[2]])


func clear_job() -> void:
	ledger.state.job = -1
	ledger.state.stage = ""
	ledger.state.job_fish = []
	ledger.state.freight_run = 0.0


func can_dive(person: Dictionary) -> bool:
	var plan := ledger.active_job()
	return diver == 0 and person.onboard and captain == 0 and ledger.has_upgrade("rov") \
		and ledger.state.charge >= .06 and not plan.is_empty() and plan.kind == "dive" \
		and ledger.state.stage == "travel" and at_work_target("dive") \
		and game.river.depth_at(game.vessel.center) >= 1.65


func try_dive() -> void:
	request("start_dive", null)


func begin_dive() -> void:
	game.release_line()
	game.sonar_overlay.hide()
	dive.deploy(game.vessel.center, target_for_job())


func member_left(peer: int) -> void:
	reaper.inside.erase(peer)
	story.guest_slots.erase(peer)
	story.work.erase(peer)
	story.equipped_tools.erase(peer)
	if not crew.started:
		return
	game.helicopter.remove_peer(peer)
	amenities.remove_peer(peer)
	crewplay.leave(peer)
	var boat: Boat = game.vessel
	var held := boat.mooring.held_by(peer)
	if held >= 0:
		boat.mooring.lines[held] = {}
	if captain == peer:
		stop_captain()
	if diver == peer:
		diver = 0
	marina_fuel.rack_peer(peer)
	changed(false)


func clear_shared_seats() -> void:
	marina_fuel.rack_all()
	var boat: Boat = game.vessel
	for slot in boat.mooring.lines.size():
		if boat.mooring.lines[slot].has("holder"):
			boat.mooring.lines[slot] = {}
	if not is_instance_valid(game.helicopter):
		return
	game.helicopter.seats.clear()
	game.helicopter.apply_local_seat()
	amenities.occupants.clear()
	amenities.apply_local_seat()
	amenities.tv_on = false
	amenities.last_sound = -1


func receive_helm(throttle: float, rudder: float, center_wheel := false) -> void:
	remote_throttle = throttle
	remote_rudder = rudder
	remote_center_wheel = center_wheel
	remote_age = 0.0


func advance_to_minute(minute: float) -> void:
	if crew.is_guest():
		return
	var current := float(ledger.state.work_minutes)
	var elapsed := fposmod(minute - current, DayCycle.DAY_MINUTES)
	ledger.state.work_minutes = current + elapsed
	game.weather.advance(ledger.state.weather, ledger.state.work_minutes, elapsed, game.player.global_position)
	game.river.update_day_cycle(ledger.state.work_minutes)
	changed()
	if crew.on_server():
		send_ship()
		send_weather()


func ship_packet() -> Dictionary:
	var boat: Boat = game.vessel
	return {"center": boat.center, "pose": boat.global_transform, "speed": boat.speed, "heading": boat.heading,
		"throttle": boat.throttle, "throttle_cap": boat.throttle_cap, "foil": boat.foil_lift, "clock": game.clock,
		"revision": revision, "lift": lift_amount, "bilge": ledger.state.bilge,
		"work_minutes": ledger.state.work_minutes,
		"charge": ledger.state.charge, "fuel": ledger.state.fuel, "deck": crewplay.moving_parts(),
		"wallet": ledger.wallet_cents(), "pumps": marina_fuel.packet(),
		"rich": rich.patrol_packet(), "ignition": boat.ignition, "wheel": boat.wheel_angle,
		"mooring": boat.mooring.packet(), "departed": boat.departed,
		"wakes": game.river.wakes.encode(false)}


func initial_ship_packet() -> Dictionary:
	var packet := ship_packet()
	packet.weather = ledger.state.get("weather", {})
	packet.wakes = game.river.wakes.encode(true)
	return packet


var remote_weather: Dictionary = {}
var remote_weather_minute := -1.0
var weather_send_in := 0.0
var weather_sent_epoch := Vector2.INF


func receive_weather(record: Dictionary, minute: float) -> void:
	if crew.is_guest() and minute >= remote_weather_minute:
		remote_weather = record
		remote_weather_minute = minute


func send_weather() -> void:
	if crew.on_server() and crew.started and crew.people.size() > 1:
		crew.share_weather.rpc(ledger.state.weather, float(ledger.state.work_minutes))
		weather_send_in = 1.0
		weather_sent_epoch = Vector2(ledger.state.weather.get("start", 0.0), ledger.state.weather.get("lightning", 0))


func send_ship() -> void:
	crew.share_ship.rpc(ship_packet())


func receive_ship(packet: Dictionary) -> void:
	if crew.mode == "guest" and int(packet.revision) >= last_guest_revision:
		game.river.wakes.receive(packet.get("wakes", PackedVector4Array()), float(packet.clock))
		marina_fuel.receive(packet.get("pumps", []), not remote_ship.has("pumps"))
		remote_ship = packet
		crewplay.update_moving_parts(packet.get("deck", {}))
		rich.remote_patrol = packet.get("rich", [])


func sync_guest(data: Dictionary, new_dock: int, new_captain: int, change: int) -> void:
	if crew.mode != "guest":
		return
	var old_dock := dock
	var first := last_guest_revision < 0
	var moved := change > last_guest_revision
	var was_aboard: bool = game.aboard()
	var was_local := not first and old_dock >= 0 and local_site() == old_dock
	var previous: Boat = game.vessel
	if not first:
		data.work_minutes = maxf(float(data.work_minutes), float(ledger.state.work_minutes))
	if not data.has("weather"):
		data.weather = {}
	if not data.has("dab_pen"):
		data.dab_pen = {}
	ledger.state = data
	story.normalize()
	select_craft(data.craft, maxi(new_dock, 0))
	var switching: bool = previous != game.vessel
	dock = new_dock
	captain = new_captain
	last_guest_revision = change
	if dock >= 0 and moved:
		set_moored(dock)
		if was_aboard or was_local or first:
			move_person(dock, was_aboard and not first)
	elif first:
		if not remote_ship.is_empty():
			tick_client_ship(1.0)
		keep_player_on_deck(game.vessel, game.vessel.board_anchor())
	if switching and was_aboard and dock >= 0:
		move_person(dock, true)
	if crew.my_id() == captain and guest_captain != captain:
		game.vessel.clear_helm()
		game.interact()
	if crew.my_id() != captain:
		if guest_captain == crew.my_id():
			game.vessel.clear_helm()
		game.driving = false
	guest_captain = captain
	game.dab_pen.refresh()
	changed(false)


func tick_client_ship(delta: float) -> void:
	if remote_ship.is_empty() or int(remote_ship.revision) < last_guest_revision:
		return
	var boat: Boat = game.vessel
	var tackle: Array = remote_ship.get("mooring", [])
	if not tackle.is_empty():
		boat.mooring.receive(tackle)
	boat.departed = bool(remote_ship.get("departed", boat.departed))
	var target: Transform3D = remote_ship.pose
	var local: Vector3 = boat.to_local(game.player.global_position)
	var was_riding: bool = game.aboard()
	var factor := 1.0 - exp(-delta * 13.0)
	if boat.global_position.distance_squared_to(target.origin) > 16.0:
		boat.global_transform = target
		boat.center = remote_ship.center
		boat.heading = float(remote_ship.heading)
		boat.speed = float(remote_ship.speed)
		if was_riding:
			keep_player_on_deck(boat, local)
	else:
		boat.global_transform = boat.global_transform.interpolate_with(target, factor)
		boat.center = boat.center.lerp(remote_ship.center, factor)
	boat.heading = lerp_angle(boat.heading, float(remote_ship.heading), factor)
	boat.speed = lerpf(boat.speed, float(remote_ship.speed), factor)
	boat.foil_lift = float(remote_ship.foil)
	lift_amount = float(remote_ship.lift)
	ledger.state.bilge = remote_ship.bilge
	ledger.state.charge = remote_ship.charge
	ledger.state.fuel = remote_ship.fuel
	if remote_ship.has("wallet"):
		ledger.set_wallet_cents(int(remote_ship.wallet))
	game.clock = lerpf(game.clock, float(remote_ship.clock), factor)
	boat.set_ignition(int(remote_ship.get("ignition", Boat.Ignition.OFF)))
	boat.throttle = float(remote_ship.throttle)
	boat.throttle_cap = float(remote_ship.get("throttle_cap", 1.0))
	boat.wheel_angle = float(remote_ship.get("wheel", 0.0))
	boat.update_motor(delta)
	if boat.mooring.secured() and game.driving:
		boat.neutral_throttle()
	boat.helm_console.update_instruments(boat.speed, boat.requested_throttle if game.driving else boat.throttle)


func button_selected(action: String, value: Variant) -> void:
	match action:
		"page":
			refresh_board()
		"preview":
			if local_site() >= 0:
				begin_preview(value)
		"pin":
			guide_site = int(value)
			close_board()
		"chart", "catch_journal":
			close_board()
			game.open_chart(action == "catch_journal")
		"fish_guide":
			close_board()
			game.open_fish_guide(board.active_page)
		"leave":
			var error: String = game.leave_trip()
			if not error.is_empty():
				message = error
				refresh_board()
		"dock", "travel", "launch", "crew_evening_trip":
			close_board()
			request(action, value)
		_:
			request(action, value)


func add(rows: Array[Dictionary], name: String, detail: String, button := "", action := "", value: Variant = null,
		disabled := false, primary := false) -> void:
	rows.append({"name": name, "detail": detail, "button": button, "action": action,
		"value": value, "disabled": disabled, "primary": primary})


func cost_string(item: Dictionary) -> String:
	var items := PackedStringArray()
	if item.get("wood", 0) > 0:
		items.append("%d timber" % item.wood)
	if item.get("parts", 0) > 0:
		items.append("%d parts" % item.parts)
	if item.get("cash", 0) > 0:
		items.append("$%d" % item.cash)
	return "  •  ".join(items)


func refresh_board() -> void:
	if not is_instance_valid(board) or not board.visible:
		return
	var site := local_site()
	var boat: Boat = game.vessel
	var data := {"heading": Data.dock_name(site) if site >= 0 else "Aboard Rich’s Boat" if game.aboard() else "On the riverbank",
		"inventory": "%d timber   •   %d parts   •   $%.2f   |   %s" % [
			ledger.state.wood, ledger.state.parts, ledger.wallet_cents() / 100.0,
			"Charge %d%%" % roundi(100 * ledger.state.charge / capacity()) if boat.uses_battery() else "%.0f L fuel" % ledger.state.fuel],
		"message": message}
	var rows: Array[Dictionary] = []
	match board.active_page:
		"River":
			river_page(rows, data, site)
		"Jobs":
			jobs_page(rows, data, site)
		"Build":
			build_page(rows, data, site)
		"Workshop":
			workshop_page(rows, data, site)
		"Crew":
			crew_page(rows, data)
	data.rows = rows
	board.show_data(data)


func river_page(rows: Array[Dictionary], data: Dictionary, site: int) -> void:
	data.title = "Landings"
	data.detail = "Use E to tie both dock lines at a landing. L boards or goes ashore once tied. The ferry can take you between landings."
	if (dock >= 0 and site == dock) or (dock < 0 and ferry_distance()):
		add(rows, "Evening at Pine Reach", "Fish off the pier, practice with the net and cook your catch at the shore camp.",
			"Go at dusk", "crew_evening_trip", null, false, true)
	if dock < 0 and ferry_distance():
		add(rows, "Go ashore at the marina", "The cabin plot is at the shore end of the pier.",
			"Go to landing", "travel", 0, false, true)
	elif dock >= 0 and site == dock:
		add(rows, "Tied up at " + Data.dock_name(dock), "Walk the pier or use L to move between boat and landing.",
			"Step ashore" if game.aboard() else "Board the boat", "dock", null, false, true)
	for index in Data.SITES.size():
		var location: Dictionary = Data.SITES[index]
		var meters: float = game.vessel.center.distance_to(landings.sites[index].berth)
		var plot := ledger.site(index)
		var distance := "%.1f km" % (meters / 1000.0) if meters >= 1000.0 else "%d m" % roundi(meters)
		var detail: String = "%s  •  %s" % [distance, location.service]
		if not plot.is_empty():
			detail += "  •  %s's plot" % plot.name
		if site >= 0 and ledger.connected(site, index):
			detail += "  •  Supply line"
		var at_dock := dock >= 0 and site == dock and index != dock
		if at_dock and ferry_open(index):
			var toll := index >= 3 and not ledger.connected(dock, index)
			add(rows, location.name, detail, "Take ferry · $12" if toll else "Take ferry", "travel", index, toll and ledger.state.cash < 12)
		else:
			if not ferry_open(index):
				detail += "  •  Survey the channel to open the regional ferry."
			add(rows, location.name, detail, "Mark landing", "pin", index)
		if can_connect(site, index):
			add(rows, "Connect " + location.name, "Linked landings get lower supply prices, free crossings and better freight pay.",
				"Connect · $25", "route", index, ledger.state.cash < 25)
	if site >= 0:
		var localized := str(Data.SITES[site].supply)
		var discount := 3 if ledger.dock_network(site) else 0
		var refuel := "Refill free" if ledger.has_at(site, "boathouse") else "Refill · $%d" % (14 - discount)
		add(rows, "Fuel and shore power", "Refill the tank and charge the batteries.", refuel, "supply", "fuel")
		add(rows, "Landing store", "Buy %s for $%d." % ["ten timber" if localized == "wood" else "five parts", 10 - discount],
			"Buy timber" if localized == "wood" else "Buy parts", "supply", localized)
	add(rows, "River map and catches", "See the full river and your fishing journal.", "Open map", "chart")


func jobs_page(rows: Array[Dictionary], data: Dictionary, site: int) -> void:
	data.title = "Jobs along the river"
	data.detail = "Pick a job at its landing. Take as long as you want, then check in for supplies and cash."
	var active := ledger.active_job()
	if not active.is_empty():
		var complete: bool = ledger.state.stage == "return"
		var destination: int = active.get("dest", active.home)
		var subtitle: String = "Check in at %s." % Data.dock_name(destination) if complete else active.detail
		if not complete and active.kind == "fish":
			subtitle += "  %d of 2 logged." % ledger.state.job_fish.size()
		elif active.kind == "freight":
			subtitle += "  Earn a 20% cash bonus if you run the trip under your own power."
		add(rows, active.name, subtitle, "Check in" if complete else "", "deliver", null, site != destination, true)
		if active.has("offset") and not complete:
			add(rows, "On the water", "Your buoy or skiff is marked in the world while this job is active.")
		add(rows, "Put the job back on the board", "You can pick it up again at its original landing.",
			"Drop job", "abandon", null, site < 0)
		return
	var offers := range(Data.WORK.size())
	offers.sort_custom(func(a: int, b: int) -> bool: return Data.WORK[a].reward[0] < Data.WORK[b].reward[0])
	for index: int in offers:
		var job: Dictionary = Data.WORK[index]
		if job.has("skill") and rank_for(crew.my_id(), job.skill) < 1:
			continue
		var prize: Array = job.reward
		var location: String = Data.dock_name(job.home)
		var requirement := str(job.get("needs", ""))
		var tier := "Local" if int(prize[0]) < 35 else ("Regional" if int(prize[0]) < 80 else "Specialist")
		var detail: String = "%s contract · %s  •  %s\nPays $%d, %d timber, %d parts" % [tier, location, job.detail, prize[0], prize[1], prize[2]]
		var history: Dictionary = progression_for(crew.my_id()).get("contract_completions", {})
		var completed := int(history.get(job.kind, 0))
		detail += "\n%s experience: %d finished · %d%% repeat-work bonus" % [str(job.kind).capitalize(), completed, mini(3, completed / 4) * 5]
		var ready := Data.requirement(requirement, ledger.state.equipment)
		if not ready:
			detail += "  •  Needs %s" % Data.UPGRADES[requirement].name
		add(rows, job.name, detail, "Take job", "accept", index, int(job.home) != site or not ready, int(job.home) == site and ready)


func build_page(rows: Array[Dictionary], data: Dictionary, site: int) -> void:
	data.title = "Build a place on shore"
	if site < 0 or game.aboard():
		data.detail = "Step off the boat and walk up to a cabin plot before building."
		add(rows, "Find a landing", "Every landing has a marked parcel for a cabin and a workshop.",
			"Show landings", "page", "River")
		return
	if not at_plot(actor(crew.my_id()), site):
		data.detail = "Follow the pier ashore to the Cabin plot sign, then press B."
		return
	var plot := ledger.site(site)
	if plot.is_empty():
		data.detail = "Your first plot is free. Crew members can help build on claimed plots."
		add(rows, "Claim this plot", "Start with a cedar cabin or a workshop.", "Claim plot", "claim", null, false, true)
		return
	data.detail = "Look at the ground to move the outline. Q rotates, left click builds, and right click cancels."
	for id: String in Data.BUILDINGS:
		var plan: Dictionary = Data.BUILDINGS[id]
		var reason := may_build(site, id)
		add(rows, plan.name, "%s  •  %s%s" % [plan.detail, cost_string(plan), "  •  " + reason if not reason.is_empty() else ""],
			"Built" if ledger.has_at(site, id) else "Place", "preview", id, not reason.is_empty(), id == "cabin")


func workshop_page(rows: Array[Dictionary], data: Dictionary, site: int) -> void:
	data.title = "Boat and workshop"
	var at_shop := site >= 0 and ledger.has_at(site, "workshop")
	data.detail = "Start with a bilge pump and a battery. Use jobs to fund equipment for the sort of trips you want."
	if at_shop:
		var flow: Vector3 = game.river.downstream(landings.sites[site].berth, game.clock)
		var feed := ledger.power_at(site, flow.length())
		if feed > 0:
			data.detail = "The current turbine is supplying %.2f kW to this landing." % feed
		elif ledger.has_at(site, "drydock"):
			data.detail = "The dry dock needs a turbine before it can run its lift or build advanced equipment."
	if site >= 0 and ledger.has_at(site, "drydock"):
		var raised: bool = ledger.state.lifts.get(str(site), false)
		add(rows, "Dry dock lift", "Raise the cradle for inspection.",
			"Lower cradle" if raised else "Raise cradle", "lift", null, not ledger.has_at(site, "turbine"))
	if site >= 0 and dock == site:
		if ledger.has_upgrade("skiff"):
			var switch_to := "houseboat" if game.vessel.uses_battery() else "skiff"
			add(rows, "Houseboat and skiff", "The skiff uses battery power and can run in shallower water.",
				"Board houseboat" if switch_to == "houseboat" else "Launch skiff", "launch", switch_to)
		if ledger.has_upgrade("barge") and not game.vessel.skiff:
			add(rows, "Crane barge", "Tows behind the houseboat and lifts machinery.",
				"Unhitch" if ledger.state.tow else "Hitch barge", "launch", "barge")
	if game.aboard() or site >= 0:
		add(rows, "Bilge and batteries", "Bilge %.0f L  •  charge %d%%" % [
			float(ledger.state.bilge) * 90.0, roundi(100 * ledger.state.charge / capacity())],
			"Pump by hand", "manual", null, ledger.state.bilge < .005)
	for id: String in Data.UPGRADES:
		var design: Dictionary = Data.UPGRADES[id]
		var blocked := may_make(site, id)
		add(rows, design.name, "%s  •  %s%s" % [design.detail, cost_string(design), "  •  " + blocked if not blocked.is_empty() else ""],
			"Installed" if ledger.has_upgrade(id) else "Fabricate", "fabricate", id, not blocked.is_empty())


func crew_page(rows: Array[Dictionary], data: Dictionary) -> void:
	data.title = "Crew"
	data.detail = "Camp supplies, job totals and river records."
	add(rows, "Ice chest and shore camp", "%d fish in the chest  •  %d shared meals at Pine Reach" %
		[ledger.state.ice_chest.size(), ledger.state.meals])
	if crew.started:
		var notice := "Your crew world will be saved and the session will end." if crew.on_server() else "Return to the title screen."
		add(rows, "Multiplayer session", notice, "Save & end" if crew.on_server() else "Leave session", "leave")
		for peer: int in crew.people:
			add(rows, crew.people[peer].name, "At the wheel" if peer == captain else "On the crew")
	if not ledger.state.scores.is_empty():
		var totals: Array = ledger.state.scores.values()
		totals.sort_custom(func(a: Dictionary, b: Dictionary): return int(a.jobs) > int(b.jobs))
		for score: Dictionary in totals:
			add(rows, str(score.name), "%d jobs delivered" % score.jobs)
	if not ledger.state.records.is_empty():
		var catches: Array = ledger.state.records.keys()
		catches.sort_custom(func(a: String, b: String): return int(ledger.state.records[a].length) > int(ledger.state.records[b].length))
		for i in mini(6, catches.size()):
			var record: Dictionary = ledger.state.records[catches[i]]
			add(rows, "%s  •  %d cm" % [catches[i], record.length], "River record held by %s" % record.name)


func action_hint() -> String:
	if preview_id != "":
		return "Left click to build  •  Q rotate  •  Right click cancel" if preview_good else \
			"Look at a level spot within the plot  •  Q rotate"
	if dive.active:
		return dive.status_text()
	var story_hint := story.hint(false)
	if not story_hint.is_empty():
		return story_hint
	var line_action := mooring_focus()
	if not line_action.is_empty():
		return line_action[3]
	var launch_action := launch_interaction()
	if launch_action != "":
		return "E  " + launch_action
	if at_rich():
		return "E  Talk to Rich" if rich.speaking_id.is_empty() else "Rich is talking"
	var gear_prompt := crewplay.prompt()
	if not gear_prompt.is_empty():
		return gear_prompt
	var boat: Boat = game.vessel
	var held := boat.mooring.held_by(crew.my_id())
	if held >= 0:
		return "Aim at a nearby cleat to tie the %s line" % boat.mooring.labels[held].to_lower()
	if not game.aboard():
		if game.river.lamure.at_swim_ladder(game.player.global_position, game.eye):
			return "E  Climb onto the swim float"
		if landings.aimed_door(game.eye) != null:
			return "E  Open or close the door"
		var board_target := aimed_landing_board()
		if not board_target.is_empty():
			return "E  Open " + board_target
		var place := local_site()
		if at_plot(actor(crew.my_id()), place):
			return "B  Build here   •   L  Board from the landing"
		if place >= 0:
			return "Follow the pier to the Cabin plot sign   •   L  Board"
	elif dock >= 0:
		return "L  Go ashore   •   Untie both lines to depart"
	elif boat.mooring.anchor.is_finite():
		return boat.mooring.anchor_hint() if game.driving else "Anchor down   •   Take the helm to raise it"
	elif boat.mooring.secured():
		return "Untie the dock lines to depart"
	var job := ledger.active_job()
	if not job.is_empty() and ledger.state.stage == "travel" and job.has("offset") and boat.center.distance_to(target_for_job()) < work_radius(job.kind):
		return "Stop and leave the wheel. E uses the marker."
	return story.hint()


func world_hud_available() -> bool:
	return not boats_menu.visible and not board.visible and not game.notebook.visible and not game.backpack.inventory.visible


func update_info() -> void:
	var job := ledger.active_job()
	var guiding := guide_site >= 0 and guide_site != dock
	info.visible = world_hud_available() and (dive.active or not job.is_empty() or guiding)
	if not info.visible:
		return
	if dive.active:
		info.text = dive.status_text()
		return
	info.text = ""
	if not job.is_empty():
		var destination := int(job.get("dest", job.home))
		var landing: String = Data.dock_name(destination)
		var ready: bool = ledger.state.stage == "return"
		var action: String = {"survey":"Take a sounding at the buoy", "rescue":"Secure the towline", "salvage":"Lift the marked crate", "dive":"Retrieve the submerged recorder", "fish":"Log two fish", "freight":"Sail to " + landing}.get(job.kind, job.detail)
		var distance: float = game.player.global_position.distance_to(landings.sites[destination].berth)
		if job.kind == "fish" and not ready:
			action += " (%d/2)" % ledger.state.job_fish.size()
		elif job.has("offset") and not ready:
			action += " · %d m" % roundi(game.vessel.center.distance_to(target_for_job()))
		if job.kind == "freight":
			ready = dock == destination
		info.text = "%s\n✓  Contract accepted\n%s  %s\n%s  Check in at %s · %d m" % [job.name, "✓" if ready else "→", action, "→" if ready else "□", landing, roundi(distance)]
	if guiding and job.is_empty():
		var destination := "%s  ·  %.2f km" % [Data.dock_name(guide_site), game.player.global_position.distance_to(landings.sites[guide_site].berth) / 1000.0]
		info.text = destination if job.is_empty() else "%s   /   %s" % [info.text, destination]


func mark_world() -> void:
	if not world_hud_available() or dive.active:
		return
	var target := Vector3.INF
	var hint := ""
	var job := ledger.active_job()
	if not job.is_empty() and ledger.state.stage == "return":
		var destination := int(job.get("dest", job.home))
		target = landings.sites[destination].berth + Vector3.UP * 2.5
		hint = Data.dock_name(destination)
	elif job.is_empty() and guide_site >= 0 and guide_site != dock:
		target = landings.sites[guide_site].berth + Vector3.UP * 2.5
		hint = Data.dock_name(guide_site)
	elif not job.is_empty() and job.has("offset") and ledger.state.stage == "travel":
		target = target_for_job() + Vector3.UP * 2.15
		hint = job.name
	elif dock < 0 and (rank_for(crew.my_id(), "marine_navigator") > 0 or rank_for(crew.my_id(), "local_knowledge") > 0):
		var nearest: float = 1200 if rank_for(crew.my_id(), "marine_navigator") > 0 else 300
		for i in landings.sites.size():
			var berth: Vector3 = landings.sites[i].berth
			var distance: float = game.player.global_position.distance_to(berth)
			if distance < nearest:
				nearest = distance
				target = berth + Vector3.UP * 2.35
				hint = Data.dock_name(i)
	elif dock < 0 and game.vessel.center.distance_to(landings.sites[0].berth) < 230.0:
		target = landings.sites[0].berth + Vector3.UP * 2.35
		hint = "Marina Landing"
	if not target.is_finite() or game.eye.is_position_behind(target):
		return
	var rect: Vector2 = get_viewport().get_visible_rect().size
	var line: Vector2 = game.eye.unproject_position(target)
	var distance: float = game.player.global_position.distance_to(target)
	game.marker.text = "%s  ·  %.0f m" % [hint, distance]
	game.marker.position = Vector2(clampf(line.x - 60, 24, rect.x - 246), clampf(line.y - 23, 130, rect.y - 118))
	game.marker.show()
