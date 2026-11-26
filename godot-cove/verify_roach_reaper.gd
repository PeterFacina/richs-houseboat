extends SceneTree

const Crew = preload("res://multiplayer_session.gd")
const Ledger = preload("res://game_ledger.gd")
const Quest = preload("res://roach_reaper_quest.gd")

var game
var campaign
var quest: Quest
var snapshots := {}
var failed := false


func _initialize() -> void:
	call_deferred("exercise")


func check(condition: bool, detail: String) -> void:
	if not condition:
		push_error(detail)
		failed = true


func look_at_site(at: Vector3, target: Vector3) -> void:
	game.player.global_position = at
	game.eye.look_at(target)


func state() -> Dictionary:
	return quest.state(1)


func collect_locally(index: int) -> void:
	var pickup := quest.pickups[index]
	var at := pickup.global_position
	look_at_site(at + Vector3.BACK * 1.15, at + Vector3.UP * .04)
	check(quest.focus() == index and quest.interact(), "A pickup could not be collected by looking at it: %d" % index)
	quest.tick(0.0)


func exercise_solo() -> void:
	var at := quest.npc.global_position
	var axis := quest.street[0].direction_to(quest.street[1])
	var verge := axis.orthogonal()
	var approach := Vector3(verge.x, 0, verge.y)
	var outside := at + approach * 14
	game.boarded = false
	game.cabin.high_until = 0
	game.player.global_position = at
	quest.tick(0.0)
	check(state().is_empty() and not quest.npc.visible, "Sober entry disclosed the quest")
	game.cabin.high_until = game.clock + 60
	quest.tick(0.0)
	check(state().is_empty(), "Quest was revealed without a new street entry")
	game.player.global_position = outside
	quest.tick(0.0)
	check(state().is_empty(), "Quest appeared off Silvie Street")
	var talk_at := at - approach * 1.5
	look_at_site(talk_at, at + Vector3.UP * .63)
	quest.tick(0.0)
	check(not state().is_empty() and quest.npc.visible and quest.interact(), "High street entry or NPC interaction failed")
	check(game.story_offer.primary_action == "accept", "Quest did not use the existing offer")
	var saved_clock: float = campaign.ledger.state.work_minutes
	game.story_offer.primary.pressed.emit()
	check(state().get("accepted", false) and is_equal_approx(state().get("deadline", 0.0), saved_clock + 360.0), "Incorrect quest deadline")
	game.close_story_offer()
	game.cabin.high_until = 0.0
	quest.tick(0.0)
	game.open_notebook()
	game.notebook.side_row.pressed.emit()
	check(game.notebook.quest_status.text == "0 / 10 · 6h 00m left", "Initial notebook progress or timer is wrong")
	campaign.ledger.state.work_minutes += 61.0
	quest.tick(0.0)
	check(game.notebook.quest_status.text == "0 / 10 · 4h 59m left", "Open notebook countdown did not update")
	game.close_notebook()
	campaign.request(Quest.ID, ["pickup", 9])
	campaign.request(Quest.ID, ["complete", Quest.ID])
	check(state().progress == 0 and campaign.progression_for(1).get("xp", 0) == 0, "Distant pickup or early turn-in was accepted")
	var active_save := Ledger.new()
	var secret: String = campaign.crew.progression_secret.sha256_text()
	check(quest.pickups.size() == 12, "Expected twelve pickup locations")
	var route := [0, 10, 2, 3, 11, 4, 5, 6, 7, 8]
	for step in route.size():
		var index: int = route[step]
		collect_locally(index)
		if index == 0:
			check(active_save.load_file(), "Partial quest did not save")
			campaign.ledger.state.progression[secret] = active_save.state.progression[secret]
			quest.tick(0.0)
		campaign.request(Quest.ID, ["pickup", index])
		check(state().progress == step + 1 and not quest.pickups[index].visible, "Pickup duplicated or remained available")
	var unused := quest.pickups[1]
	game.player.global_position = unused.global_position
	campaign.request(Quest.ID, ["pickup", 1])
	check(state().progress == Quest.TARGET and state().picked.size() == Quest.TARGET
		and not unused.visible and not quest.pickups[9].visible, "Extra pickups remained available after reaching ten")
	check(game.backpack.quest_items.visible and game.backpack.quest_items.text.ends_with("10"), "Backpack count missing")
	check(active_save.load_file(), "Active quest did not save")
	var saved: Dictionary = active_save.state.progression[secret][Quest.ID]
	check(saved.picked.size() == 10 and is_equal_approx(saved.deadline, state().deadline), "Active quest did not reload")
	look_at_site(talk_at, at + Vector3.UP * .63)
	check(quest.interact() and game.story_offer.primary_action == "complete", "Turn-in offer missing")
	game.story_offer.primary.pressed.emit()
	check(game.story_offer.description.text == Quest.THANKS, "Completion dialogue missing")
	game.close_story_offer()
	quest.tick(.01)
	check(quest.npc.joint.visible and not quest.npc.phone.visible, "Smoking did not start after dialogue")
	quest.tick(3.10)
	quest.tick(.01)
	check(quest.npc.smoke.emitting and quest.npc.ember.material_override.emission_enabled, "Smoke or ember missing")
	quest.tick(3)
	quest.tick(0)
	check(not quest.npc.visible and not game.backpack.quest_items.visible, "NPC or inventory remained after completion")
	campaign.request(Quest.ID, ["complete", Quest.ID])
	check(campaign.progression_for(1).xp == 250, "Expected exactly one 250 XP reward")
	check(active_save.load_file() and active_save.state.progression[secret][Quest.ID].step == 1, "Completion did not reload")
	campaign.crew.progression_secret = "failure-test-identity"
	game.player.global_position = outside
	quest.tick(0.0)
	game.cabin.high_until = game.clock + 60
	game.player.global_position = talk_at
	quest.tick(0.0)
	campaign.request(Quest.ID, ["accept", Quest.ID])
	quest.tick(0.0)
	collect_locally(0)
	campaign.ledger.state.work_minutes = state().deadline
	quest.tick(0.0)
	check(state().failed and not game.backpack.quest_items.visible and not quest.npc.visible, "Expiry did not clear and permanently fail the quest")
	campaign.request(Quest.ID, ["accept", Quest.ID])
	check(state().failed and campaign.progression_for(1).get("xp", 0) == 0, "Failed quest restarted or paid XP")
	var failed_key: String = campaign.crew.progression_secret.sha256_text()
	check(active_save.load_file() and active_save.state.progression[failed_key][Quest.ID].failed, "Failure did not reload")
	print("Roach Reaper solo encounter, notebook, inventory, turn-in, animation state, timeout and ledger checked.")


func endpoint(id: String) -> Crew:
	var group := Node.new()
	group.name = id
	root.add_child(group)
	var api := SceneMultiplayer.new()
	api.root_path = group.get_path()
	set_multiplayer(api, group.get_path())
	var crew := Crew.new()
	crew.name = "Crew"
	crew.boat = game.vessel
	crew.local_profile = id.md5_text()
	crew.progression_secret = (id + "private").md5_text()
	group.add_child(crew)
	return crew


func until(condition: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while not condition.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return condition.call()


func guest_state(name: String) -> Dictionary:
	return snapshots.get(name, {})


func send_pose(guest: Crew, at: Vector3, high: bool) -> bool:
	var peer := guest.my_id()
	campaign.crew.poses.erase(peer)
	guest.pose.rpc_id(1, at, 0.0, false, {"roach_on_foot": true, "cabin_high": high})
	return await until(func(): return campaign.crew.poses.has(peer))


func exercise_network() -> void:
	var original: Crew = campaign.crew
	var host := endpoint("Host")
	campaign.crew = host
	host.requested.connect(func(peer: int, action: String, value: Variant):
		if action == "connected":
			host.share_state.rpc_id(peer, campaign.snapshot_for(peer), campaign.dock, 0, 1)
		else:
			campaign.remote_request(peer, action, value))
	host.host("Host")
	host.start_session()
	var guest := endpoint("Guest")
	var other := endpoint("Other")
	for client: Crew in [guest, other]:
		var key := str(client.get_parent().name)
		client.state_received.connect(func(data, _dock, _captain, _revision): snapshots[key] = data.progression.self)
		client.join(key, "127.0.0.1")
	var ready := await until(func(): return snapshots.size() == 2)
	check(ready, "ENet guests failed to receive initial snapshots")
	if ready:
		var at := quest.npc.global_position
		var peer := guest.my_id()
		check(await send_pose(guest, at, true), "High guest pose did not reach host")
		quest.tick(0.0)
		check(await until(func(): return guest_state("Guest").has(Quest.ID)), "Guest discovery did not replicate")
		check(not guest_state("Other").has(Quest.ID), "Another guest received private quest state")
		guest.order.rpc_id(1, Quest.ID, ["accept", Quest.ID])
		check(await until(func(): return guest_state("Guest").get(Quest.ID, {}).get("accepted", false)), "Guest acceptance did not replicate")
		for index in Quest.TARGET:
			check(await send_pose(guest, quest.pickups[index].global_position, false), "Guest pickup pose missing")
			guest.order.rpc_id(1, Quest.ID, ["pickup", index])
			guest.order.rpc_id(1, Quest.ID, ["pickup", index])
			check(await until(func(): return int(quest.state(peer).get("progress", 0)) >= index + 1), "Guest pickup was not credited")
		check(await send_pose(guest, at, false), "Guest turn-in pose missing")
		guest.order.rpc_id(1, Quest.ID, ["complete", Quest.ID])
		guest.order.rpc_id(1, Quest.ID, ["complete", Quest.ID])
		check(await until(func(): return guest_state("Guest").get("xp", 0) == 250), "Guest completion did not award XP")
		guest.stop()
		check(await until(func(): return not host.people.has(peer)), "Guest did not disconnect")
		snapshots.erase("Guest")
		guest.join("Guest", "127.0.0.1")
		check(await until(func(): return snapshots.has("Guest")), "Guest reconnect snapshot missing")
		check(guest_state("Guest").get("xp", 0) == 250 and guest_state("Guest").get(Quest.ID, {}).get("step", 0) == 1,
			"Completion or deduplicated XP was lost on reconnect")
		check(not guest_state("Other").has(Quest.ID) and guest_state("Other").get("xp", 0) == 0, "Guest reward leaked to another profile")
	guest.stop()
	other.stop()
	host.stop()
	campaign.crew = original
	print("Roach Reaper ENet host, two guests, private snapshots, duplicate requests and reconnect checked.")


func exercise() -> void:
	if not "houseboat-reaper-" in OS.get_user_data_dir().to_lower() or FileAccess.file_exists(Ledger.SAVE):
		quit(2)
		return
	game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	campaign = game.campaign
	quest = campaign.reaper
	await physics_frame
	await process_frame
	game.process_mode = Node.PROCESS_MODE_DISABLED
	exercise_solo()
	await exercise_network()
	game.free()
	quit(1 if failed else 0)
