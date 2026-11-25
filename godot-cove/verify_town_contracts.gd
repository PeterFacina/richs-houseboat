extends SceneTree

func _initialize() -> void:
	call_deferred("run_checks")

func run_checks() -> void:
	if not "houseboat-xp-" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	var map = game.river
	var signs := get_nodes_in_group(&"town_roadside_signs")
	var passed := signs.size() > 10
	for sign in signs:
		var at: Vector3 = sign.global_position
		if not map.road_at_sign(Vector2(at.x, at.z), sign.get_meta(&"sign_span")).is_empty():
			push_error("Sign overlaps road at %s" % at)
			passed = false
	var samples := 0
	for key in ["pier_approach", "promenade", "beach_link"]:
		var points: Array = map.meta.riverbank[key]
		for i in range(1, points.size()):
			var a := Vector2(points[i-1][0], points[i-1][1])
			var b := Vector2(points[i][0], points[i][1])
			var steps := maxi(1, ceili(a.distance_to(b) / .5))
			for step in range(steps + 1):
				var point := a.lerp(b, float(step) / steps)
				samples += 1
				if not map.road_at_sign(point, 1.86).is_empty():
					push_error("Path overlaps road at %s" % point)
					passed = false
					break
	var campaign = game.campaign
	campaign.accept_job(1, 0, 0)
	campaign.update_info()
	passed = passed and campaign.info.text.contains("0/2")
	campaign.count_catch(1, "Perch", 28, game.player.global_position)
	campaign.count_catch(1, "Bass", 34, game.player.global_position)
	campaign.update_info()
	passed = passed and campaign.info.text.contains("Check in")
	var cash := int(campaign.ledger.state.cash)
	campaign.deliver(1, 0)
	passed = passed and campaign.ledger.state.cash - cash == 12
	passed = passed and campaign.progression_for(1).contract_completions.fish == 1
	print("Town and contract checks: ", passed, " (", signs.size(), " signs, ", samples, " trail samples)")
	quit(0 if passed else 1)
