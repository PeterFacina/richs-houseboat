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
	screen.toggle()
	var passed: bool = screen.panel.visible and campaign.ledger.state.cash == 71
	for category in screen.COLORS:
		screen.show_branch(category)
		passed = passed and screen.graph.get_connection_list().size() > 0
	screen.show_branch("Business")
	screen.select_skill("hard_worker")
	screen.purchase.pressed.emit()
	passed = passed and int(p.get("ranks", {}).get("hard_worker", 0)) == 1
	screen.toggle()
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
	for index in job.tuft_cells.keys():
		var point: Vector3 = job.mower.grass_point(index)
		job.mower.trim_at(Transform3D(Basis.IDENTITY, point - job.mower.CUT_DECK))
	passed = passed and job.status == job.Status.RETURNING
	var before_turn_in := int(p.xp)
	job.interact()
	passed = passed and p.xp - before_turn_in == roundi(250 * 1.05)
	job.interact()
	passed = passed and p.xp == before_turn_in + roundi(250 * 1.05)
	print("Game UI, purchase, migration, persistence, travel checks and mowing: ", passed)
	quit(0 if passed else 1)
