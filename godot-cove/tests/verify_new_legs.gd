extends SceneTree

var failures := 0

func _initialize() -> void:
	call_deferred("run")

func check(result: bool, label: String) -> void:
	print("CHECK ", label, ": ", result)
	if not result:
		failures += 1

func route_length(path: PackedVector2Array) -> float:
	var distance := 0.0
	for i in range(1, path.size()):
		distance += path[i - 1].distance_to(path[i])
	return distance

func run() -> void:
	if not "houseboat-issue-108" in OS.get_user_data_dir().to_lower():
		push_error("Run this check with a fresh APPDATA directory named houseboat-issue-108-test.")
		quit(2)
		return
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	game.set_physics_process(false)
	game.set_process(false)
	await physics_frame
	var campaign = game.campaign
	var story = campaign.story
	var fleet = game.marina_cars
	var car = fleet.cars[fleet.ENVOY]
	var initial_position: Vector3 = car.global_position
	check(fleet.cars[0].details.label == "Mazda5" and car.details.label == "GMC Envoy", "kept car indices and added Envoy")
	var actor := {"at": story.yard.points.bench - Vector3.UP * 1.4, "onboard": false}
	var state: Dictionary = story.state()
	state.step = 1
	state.accepted = true
	state.flags.clear()
	state.loans.clear()
	state.erase("envoy_pose")
	state.components.clear()
	story.normalize()
	check(not fleet.can_drive(fleet.ENVOY), "loan locks Envoy")
	story.perform(1, [story.NPC_ID, "story_parts", "borrow_car"], actor)
	check(story.transport_loaned() and fleet.can_drive(fleet.ENVOY), "workbench lends Envoy")
	fleet.assign_driver(1, fleet.ENVOY)
	check(fleet.active == fleet.ENVOY and fleet.drivers[fleet.ENVOY] == 1, "normal driver seat")
	story.tick_transport(.5, true)
	var outbound: PackedVector2Array = story.road_guide.points
	var length := route_length(outbound)
	print("Outbound route distance in metres: ", length, " | points: ", outbound.size())
	check(length > 3100.0 and length < 6500.0 and story.road_guide.visible, "route draws from the marina to the workshop")
	story.tick_transport(.1, false)
	check(not story.road_guide.visible, "route hides when controls blocked")
	fleet.active = -1
	fleet.drivers[fleet.ENVOY] = 0
	var workshop = story.yard.workshop
	var seller: Vector3 = workshop.seller_point
	actor.at = seller - Vector3.UP * 1.4
	story.perform(1, [story.NPC_ID, "story_parts", "pontoon_pickup"], actor)
	check(not story.flag("pontoon_pickup"), "Cal refuses without parked Envoy")
	var heading: float = workshop.rotation.y + PI
	check(fleet.park_envoy(workshop.parking, heading), "clear and drivable gravel parking")
	story.perform(1, [story.NPC_ID, "story_parts", "pontoon_pickup"], actor)
	check(story.flag("pontoon_pickup") and car.model.pontoons.visible and car.model.hatch.rotation.x < -1.0, "seller loads pontoons and opens hatch")
	check(not workshop.rack.visible and not car.model.interior.rear_bench.visible, "rack and cabin visuals update")
	var saved: Dictionary = campaign.snapshot_for(1).rich_story
	check(saved.flags.get("pontoon_pickup", false) and saved.has("envoy_pose"), "campaign snapshot includes cargo state and solo checkpoint")
	var ledger = campaign.Ledger.new()
	ledger.load_file()
	check(ledger.state.rich_story.get("flags", {}).get("pontoon_pickup", false), "cargo flags survive disk save")
	check(fleet.park_envoy(initial_position, fleet.LOT_ANGLE), "clear marina bay")
	story.restore_envoy_pose()
	check(car.global_position.distance_to(workshop.parking) < .8, "loaded Envoy returns to its saved pose")
	fleet.active = fleet.ENVOY
	story.tick_transport(.5, true)
	var inbound: PackedVector2Array = story.road_guide.points
	check(route_length(inbound) > 3100.0 and story.road_guide.visible, "return GPS heads to drop-off")
	fleet.active = -1
	actor.at = story.yard.points.unload - Vector3.UP * 1.40
	story.perform(1, [story.NPC_ID, "story_parts", "unload"], actor)
	check(not story.flag("unload"), "distant Envoy cannot unload")
	var dropoff: Vector3 = story.yard.points.unload + Vector3(-2.0, 0, 8.0)
	car.global_position = dropoff
	story.perform(1, [story.NPC_ID, "story_parts", "unload"], actor)
	check(story.flag("unload") and not car.model.pontoons.visible and is_zero_approx(car.model.hatch.rotation.x) and story.yard.delivery.visible, "drop-off clears load and closes hatch")
	var quest := "story_parts"
	actor.at = story.yard.points.pontoons - Vector3.UP * 1.40
	story.perform(1, [story.NPC_ID, quest, "start:pontoons"], actor)
	game.clock += story.work_time("pontoons")
	story.perform(1, [story.NPC_ID, quest, "finish:pontoons"], actor)
	check(story.Parts.repaired(state, "pontoons"), "existing installation repairs the hull")
	var cash: int = campaign.ledger.state.cash
	story.turn_in(1, story.current())
	check(state.step == 2 and story.current().id == "story_repair" and campaign.ledger.state.cash == cash + 16 and not fleet.can_drive(fleet.ENVOY), "check-in advances to Safety Third and returns loan")
	state.step = 1
	state.accepted = true
	state.flags = {"borrow_car": true, "pontoon_pickup": true}
	state.loans = {}
	state.components = {}
	story.normalize()
	story.sync_world()
	check(story.transport_loaned() and car.model.pontoons.visible and story.road_destination().is_equal_approx(story.yard.points.unload), "legacy in-progress pickup resumes at delivery")
	state.flags.unload = true
	story.normalize()
	story.sync_world()
	check(not car.model.pontoons.visible and story.yard.delivery.visible, "legacy dropped-off cargo stays at the yard")
	game.free()
	quit(0 if failures == 0 else 1)
