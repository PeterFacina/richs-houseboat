extends SceneTree

const Crew = preload("res://multiplayer_session.gd")
const Story = preload("res://rich_story.gd")

var failures := 0
var received_stories: Array[Dictionary] = []


func _initialize() -> void:
	call_deferred("run")


func check(result: bool, label: String) -> void:
	print("CHECK ", label, ": ", result)
	if not result:
		failures += 1


func key_event(key: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.keycode = key
	event.physical_keycode = key
	return event


func endpoint(id: String) -> Node:
	var group := Node.new()
	group.name = id
	root.add_child(group)
	var api := SceneMultiplayer.new()
	api.root_path = group.get_path()
	set_multiplayer(api, group.get_path())
	var crew := Crew.new()
	crew.name = "Crew"
	crew.local_profile = id.md5_text()
	crew.progression_secret = (id + "private").md5_text()
	group.add_child(crew)
	return crew


func until(check_value: Callable) -> bool:
	var deadline := Time.get_ticks_msec() + 5000
	while not check_value.call() and Time.get_ticks_msec() < deadline:
		await process_frame
	return check_value.call()


func received_story_matches(step: int, progress: int, component := "") -> bool:
	if received_stories.is_empty():
		return false
	var state: Dictionary = received_stories.back()
	return int(state.get("step", -1)) == step and int(state.get("progress", -1)) == progress \
		and (component.is_empty() or state.get("components", {}).has(component))


func run() -> void:
	if not "quest-debugger-test" in OS.get_user_data_dir().to_lower():
		push_error("Run with a fresh APPDATA directory containing quest-debugger-test.")
		quit(2)
		return
	if not OS.is_debug_build():
		push_error("The quest debugger is only available in a debug build.")
		quit(2)
		return
	var game = load("res://game_world.tscn").instantiate()
	root.add_child(game)
	game.set_process(false)
	game.set_physics_process(false)
	await process_frame
	var campaign = game.campaign
	var debugger = game.quest_debugger
	var story = campaign.story
	var saved_ledger: Dictionary = campaign.ledger.state
	var original_crew = campaign.crew
	var host = endpoint("QuestHost")
	campaign.crew = host
	host.boat = game.vessel
	host.requested.connect(func(peer: int, action: String, _value: Variant) -> void:
		if action == "connected":
			host.share_state.rpc_id(peer, campaign.snapshot_for(peer), campaign.dock, campaign.captain, campaign.revision))
	host.member_left.connect(campaign.member_left)
	host.command_received.connect(campaign.receive_helm)
	host.host("Quest host")
	host.start_session()
	var guest = endpoint("QuestGuest")
	guest.state_received.connect(func(data: Dictionary, _dock: int, _captain: int, _revision: int) -> void:
		received_stories.append(data.get("rich_story", {}).duplicate(true)))
	guest.join("Quest guest", "127.0.0.1")
	var initial_sync := await until(func() -> bool: return not received_stories.is_empty())
	if not initial_sync:
		print("SKIP multiplayer RPC assertions: host=%s guest=%s" % [host.status, guest.status])
	else:
		check(true, "multiplayer guest receives the host's initial campaign snapshot")
	check(is_instance_valid(debugger), "debug build creates the F8 quest debugger")
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
	var gameplay_mouse_mode := Input.mouse_mode
	get_root().get_tree().paused = true
	debugger.handle_input(key_event(KEY_F8))
	check(not debugger.panel.visible and Input.mouse_mode == gameplay_mouse_mode, "F8 does not open over a paused menu or disturb its mouse mode")
	get_root().get_tree().paused = false
	check(debugger.handle_input(key_event(KEY_F8)) and debugger.panel.visible, "F8 opens the debugger")
	check(debugger.session_active and campaign.debug_testing, "opening F8 starts an isolated test session")
	check(debugger.menu_root.visible and debugger.menu_root.mouse_filter == Control.MOUSE_FILTER_STOP, "visible F8 root captures menu clicks while hidden state cannot intercept gameplay")
	check(debugger.details.scroll_active and not debugger.details.fit_content, "quest details stay wrapped inside a scrollable panel")
	check(Input.mouse_mode == Input.MOUSE_MODE_VISIBLE, "opening F8 exposes the mouse for UI interaction")

	debugger._quest_selected(4)
	debugger._stage_selected(2)
	debugger.location_toggle.button_pressed = false
	check(debugger.handle_input(key_event(KEY_F8)) and not debugger.panel.visible, "F8 closes the debugger")
	check(not debugger.menu_root.visible, "closed F8 root no longer covers gameplay input")
	check(debugger.previous_mouse_mode == gameplay_mouse_mode and (DisplayServer.get_name() == "headless" or Input.mouse_mode == gameplay_mouse_mode), "F8 close restores the prior gameplay mouse mode")
	check(debugger.handle_input(key_event(KEY_F8)) and debugger.panel.visible, "F8 reopens the same debugger instance")
	check(debugger.selected_quest == 4 and debugger.selected_stage == 2 and not debugger.location_toggle.button_pressed, "quest, stage and teleport preference persist before applying")
	debugger.quest_picker.get_popup().show()
	check(debugger.handle_input(key_event(KEY_ESCAPE)) and debugger.panel.visible and not debugger.quest_picker.get_popup().visible, "Escape closes an open picker before closing the debugger")
	debugger.jump_to_stage()
	check(story.current().id == "story_electrical" and int(story.state().progress) == 2, "jump applies the selected active quest to the campaign story state")
	if initial_sync:
		check(await until(func() -> bool: return received_story_matches(4, 2)), "multiplayer guest receives the selected host quest and stage")
	check(story.flag("bench") and story.flag("supplies") and story.state().loans.has("strippers"), "selected stage grants its required prerequisites and tool loan")
	check(story.Parts.repaired(story.state(), "pontoons") and story.Parts.repaired(story.state(), "engine"), "earlier restoration prerequisites stay complete")
	check(int(saved_ledger.rich_story.get("step", 0)) == 0, "temporary quest changes leave the saved ledger snapshot untouched")

	check(debugger.handle_input(key_event(KEY_ESCAPE)) and not debugger.panel.visible, "Escape closes the debugger panel")
	check(debugger.previous_mouse_mode == gameplay_mouse_mode and (DisplayServer.get_name() == "headless" or Input.mouse_mode == gameplay_mouse_mode), "Escape close restores the prior gameplay mouse mode")
	check(debugger.session_active and campaign.debug_testing and story.current().id == "story_electrical", "closing F8 keeps the temporary authoritative quest session active")
	var person := {"at": story.yard.points.wiring - Vector3.UP * 1.40, "onboard": false}
	game.player.global_position = person.at
	campaign.request("rich_story", [story.NPC_ID, "story_electrical", "tool:strippers"])
	campaign.request("rich_story", [story.NPC_ID, "story_electrical", "start:wiring"])
	game.clock += story.work_time("wiring")
	campaign.request("rich_story", [story.NPC_ID, "story_electrical", "finish:wiring"])
	check(story.Parts.repaired(story.state(), "wiring") and int(story.state().progress) == 3, "normal quest work completes wiring and advances to the battery objective")
	if initial_sync:
		check(await until(func() -> bool: return received_story_matches(4, 3, "wiring")), "multiplayer guest receives the normal objective completion")
	check(debugger.handle_input(key_event(KEY_F8)) and debugger.panel.visible, "F8 reopens the same debugger session")
	check(debugger.selected_quest == 4 and debugger.selected_stage == 3, "reopened debugger selects the authoritative quest and stage")
	check(debugger.details.text.to_lower().contains("battery"), "reopened debugger displays the current battery objective")
	check(story.Parts.repaired(story.state(), "wiring") and story.flag("bench") and story.flag("supplies"), "reopening preserves completed prerequisites and world state")
	check(campaign.debug_testing and not FileAccess.file_exists(campaign.ledger.save_path), "debug progression remains isolated from normal campaign saves")
	check(game.save_trip().contains("isolated"), "manual campaign save is blocked for the temporary test copy")
	for iteration in 10:
		var quest_index := iteration % Story.QUESTS.size()
		var stage_index := mini(1, Story.QUESTS[quest_index].steps.size() - 1)
		debugger._quest_selected(quest_index)
		debugger._stage_selected(stage_index)
		debugger.jump_to_stage()
		check(story.current().id == Story.QUESTS[quest_index].id, "repeated cycle %d applies the selected quest" % (iteration + 1))
		check(debugger.handle_input(key_event(KEY_F8)) and not debugger.panel.visible, "repeated cycle %d closes with F8" % (iteration + 1))
		check(debugger.previous_mouse_mode == gameplay_mouse_mode and (DisplayServer.get_name() == "headless" or Input.mouse_mode == gameplay_mouse_mode), "repeated cycle %d restores gameplay input mode" % (iteration + 1))
		check(debugger.handle_input(key_event(KEY_F8)) and debugger.panel.visible, "repeated cycle %d reopens with F8" % (iteration + 1))
		check(debugger.selected_quest == quest_index and debugger.selected_stage == stage_index, "repeated cycle %d preserves the selected state" % (iteration + 1))
	debugger.handle_input(key_event(KEY_ESCAPE))
	guest.stop()
	host.stop()
	campaign.crew = original_crew
	game.free()
	print("Quest debugger persistence checks failed: ", failures)
	quit(0 if failures == 0 else 1)
