extends SceneTree
const XP = preload("res://progression.gd")
const Ledger = preload("res://river_ledger.gd")

func _initialize() -> void:
	call_deferred("exercise")

func exercise() -> void:
	if not "houseboat-xp-" in OS.get_user_data_dir().to_lower():
		push_error("Use an isolated APPDATA directory named houseboat-xp-test.")
		quit(2)
		return
	if FileAccess.file_exists(Ledger.SAVE):
		quit(2)
		return
	var legacy := FileAccess.open(Ledger.SAVE, FileAccess.WRITE)
	legacy.store_string(JSON.stringify({"format": 1, "sites": {}, "cash": 71}))
	legacy.close()
	var game = load("res://fishing.tscn").instantiate()
	root.add_child(game)
	var screen = game.skill_screen
	var campaign = game.campaign
	var p: Dictionary = campaign.progression_for(campaign.crew.my_id())
	XP.award(p, "route", "test-route")
	var shortcut := InputEventKey.new()
	shortcut.physical_keycode = KEY_K
	shortcut.pressed = true
	game._input(shortcut)
	var passed: bool = screen.panel.visible and campaign.ledger.state.cash == 71
	for category in screen.COLORS:
		screen.show_branch(category)
		passed = passed and screen.graph.buttons.size() == 7 and not campaign.board.visible
	screen.show_branch("Business")
	screen.select_skill("hard_worker")
	screen.purchase.pressed.emit()
	passed = passed and int(p.get("ranks", {}).get("hard_worker", 0)) == 1
	game._input(shortcut)
	passed = passed and not screen.panel.visible
	campaign.open_board("River")
	passed = passed and not campaign.board.page_buttons.has("Skill Tree")
	game._input(shortcut)
	passed = passed and screen.panel.visible and not campaign.board.visible
	game._input(shortcut)
	campaign.open_board("Crew")
	passed = passed and not screen.panel.is_visible_in_tree()
	campaign.button_selected("fish_guide", null)
	var guide = game.fish_guide
	guide.show_fish(0)
	passed = passed and guide.heading.text == "Unidentified fish" and not guide.image.visible
	guide.fill_list("Perca")
	passed = passed and guide.buttons.is_empty()
	game.close_guide()
	passed = passed and campaign.board.visible and campaign.board.active_page == "Crew"
	campaign.close_board()
	var previous := int(p.xp)
	campaign.travel_progress(1, "boat", 0, 20)
	campaign.travel_progress(1, "boat", 5000, 20)
	passed = passed and p.xp == previous
	for i in range(50):
		campaign.travel_progress(1, "boat", 10, 20)
	passed = passed and p.xp == previous + 20
	var saved := Ledger.new()
	saved.load_file()
	passed = passed and saved.state.progression == JSON.parse_string(JSON.stringify(campaign.ledger.state.progression))
	campaign.crew.progression_keys[234] = "test-client"
	XP.award(campaign.progression_for(234), "delivery", "test-job")
	var remote: Dictionary = campaign.snapshot_for(234).progression
	passed = passed and remote.size() == 1 and remote.self.xp == 100 and not remote.self.has("events") and p.xp == 270
	var job = game.shannon_job
	job.interact()
	job.interact()
	passed = passed and job.status == job.Status.CUTTING
	var route: Dictionary = game.river.waterfront.mowing_routes[job.job_day % job.Routes.DAYS.size()]
	var expected_tufts := {}
	for zone: PackedVector2Array in route.zones:
		var bounds: Rect2 = job.Routes.bounds(zone)
		for index in job.mower.grass_transforms.size():
			var at: Vector3 = job.mower.grass_point(index)
			var point := Vector2(at.x, at.z)
			if bounds.has_point(point) and Geometry2D.is_point_in_polygon(point, zone):
				expected_tufts[index] = Vector2i(floori(at.x), floori(at.z))
	passed = passed and expected_tufts == job.tuft_cells
	var first_target: int = job.target_tuft
	passed = passed and expected_tufts.has(first_target) and job.markers.get_child_count() == 1
	if first_target >= 0:
		var target_point: Vector3 = job.mower.grass_point(first_target)
		var deck_pose := Transform3D(Basis.IDENTITY, target_point - job.mower.CUT_DECK)
		passed = (int(job.mower.trim_at(deck_pose)) > 0) and passed
		passed = (int(job.mower.trim_at(deck_pose)) == 0) and passed
		job.update_navigation()
		passed = passed and job.target_tuft >= 0 and job.target_tuft != first_target
		if job.target_tuft >= 0:
			passed = passed and not job.mower.grass_cut[job.target_tuft]
	game.mower.rider = game.player
	job.update_navigation()
	var outbound: bool = job.road_guide.visible and job.road_guide.mesh != null
	var lawn: Vector3 = job.mower.grass_point(job.target_tuft)
	var trail: PackedVector2Array = job.road_guide.route(game.mower.global_position, lawn, game.public_works)
	outbound = outbound and trail.size() > 100 and trail[-1].is_equal_approx(Vector2(lawn.x, lawn.z))
	print("Mowing road to lawn: ", outbound)
	passed = passed and outbound and job.waypoint.no_depth_test
	game.mower.rider = null
	for index in job.tuft_cells.keys():
		var point: Vector3 = job.mower.grass_point(index)
		job.mower.trim_at(Transform3D(Basis.IDENTITY, point - job.mower.CUT_DECK))
	passed = passed and job.status == job.Status.RETURNING
	var parked_pose: Transform3D = game.mower.global_transform
	game.mower.global_position = job.mower.grass_point(first_target)
	game.mower.rider = game.player
	job.update_navigation()
	var inbound: bool = job.road_guide.visible and job.waypoint.text.contains("Park zero-turn")
	print("Mowing road to parking: ", inbound)
	passed = passed and inbound
	game.mower.global_transform = parked_pose
	game.mower.rider = null
	job.update_navigation()
	passed = passed and not job.markers.visible and job.waypoint.text.contains("Return to Shannon") and not job.road_guide.visible
	var before_turn_in := int(p.xp)
	var cash_before_turn_in: int = campaign.ledger.state.cash
	var earned_cash: int = campaign.mowing_pay(job.PAY)
	job.interact()
	passed = passed and p.xp - before_turn_in == roundi(250 * 1.05)
	passed = passed and int(campaign.ledger.state.cash) == cash_before_turn_in + earned_cash
	var paid_day: int = campaign.ledger.state.last_mowing_day
	passed = passed and paid_day >= 0 and campaign.reward_mowing(paid_day, job.PAY, false) == 0
	job.interact()
	passed = passed and p.xp == before_turn_in + roundi(250 * 1.05)
	passed = passed and int(campaign.ledger.state.cash) == cash_before_turn_in + earned_cash
	game.catch_type = 0
	game.catch_length = 21
	game.record_catch()
	for i in range(26):
		game.catch_type = 1
		game.record_catch()
	game.journal.clear()
	game.discovered_species.clear()
	game.read_journal()
	game.open_fish_guide()
	guide.show_fish(0)
	passed = passed and game.journal.size() == 25 and guide.heading.text == game.Species.profile(0).name and guide.image.visible
	print("Notebook, fish discovery persistence, purchases, travel and mowing: ", passed)
	quit(0 if passed else 1)
