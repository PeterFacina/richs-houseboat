extends SceneTree

const Saves = preload("res://solo_saves.gd")
const Ledger = preload("res://game_ledger.gd")


func _initialize() -> void:
	exercise.call_deferred()


func exercise() -> void:
	if not "houseboat-xp-slots-" in OS.get_user_data_dir().to_lower() or Saves.has_data(0) or Saves.has_data(1):
		quit(2)
		return
	write_text(Ledger.SAVE, JSON.stringify({"format": 1, "sites": {}, "cash": 71}))
	write_text(Saves.JOURNALS[0], JSON.stringify(["Slot one catch"]))
	write_text(Ledger.CREW_SAVE, JSON.stringify({"format": 1, "sites": {}, "cash": 95}))
	var title = load("res://title_screen.tscn").instantiate()
	root.add_child(title)
	current_scene = title
	title.start.pressed.emit()
	var ok: bool = title.slots.visible and title.slots.play_buttons[0].text == "Continue" \
		and title.slots.play_buttons[1].text == "Start new"
	title.slots.play_buttons[1].pressed.emit()
	var deadline := Time.get_ticks_msec() + 45000
	while (current_scene == title or current_scene == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	var game = current_scene
	if not is_instance_valid(game) or not "solo_slot" in game:
		push_error("Solo selection did not load the game.")
		quit(1)
		return
	ok = ok and game.solo_slot == 1 and game.campaign.ledger.save_path == Saves.CAMPAIGNS[1]
	ok = ok and game.campaign.ledger.state.cash == 28 and game.journal.is_empty()
	game.campaign.ledger.state.cash = 49
	game.catch_type = 0
	game.catch_length = 21
	game.record_catch()
	ok = game.save_trip().is_empty() and ok
	ok = FileAccess.file_exists(Saves.JOURNALS[1]) and ok
	var loaded := Ledger.new()
	loaded.save_path = Saves.CAMPAIGNS[1]
	ok = loaded.load_file() and loaded.state.cash == 49 and ok
	ok = game.leave_trip().is_empty() and ok
	deadline = Time.get_ticks_msec() + 10000
	while (current_scene == game or current_scene == null) and Time.get_ticks_msec() < deadline:
		await process_frame
	title = current_scene
	if not is_instance_valid(title) or not "slots" in title:
		push_error("Leaving the solo slot did not return to the title.")
		quit(1)
		return
	title.open_slots()
	title.slots.ask_reset(1)
	ok = Saves.has_data(1) and ok
	title.slots.confirmation.hide()
	title.slots.confirmation.canceled.emit()
	ok = Saves.has_data(1) and ok
	title.slots.ask_reset(1)
	title.slots.confirmation.hide()
	title.slots.confirmation.confirmed.emit()
	ok = not Saves.has_data(1) and title.slots.play_buttons[1].text == "Start new" and ok
	ok = FileAccess.get_file_as_string(Saves.JOURNALS[0]).contains("Slot one catch") and ok
	ok = FileAccess.get_file_as_string(Ledger.CREW_SAVE).contains("95") and ok
	loaded.save_path = Ledger.SAVE
	ok = loaded.load_file() and loaded.state.cash == 71 and ok
	var backups := DirAccess.get_directories_at("user://solo_save_backups")
	ok = backups.size() == 1 and ok
	if backups.size() == 1:
		var folder := "user://solo_save_backups".path_join(backups[0])
		for path in [Saves.CAMPAIGNS[1], Saves.CAMPAIGNS[1] + ".prev", Saves.JOURNALS[1]]:
			ok = FileAccess.file_exists(folder.path_join(path.get_file())) and ok
	write_text(Saves.JOURNALS[1], JSON.stringify(["Journal without a campaign"]))
	title.slots.refresh()
	ok = title.slots.play_buttons[1].text == "Continue" and not title.slots.play_buttons[1].disabled and ok
	print("Solo slot selection, independent save and journal, confirmed reset and backup: ", ok)
	quit(0 if ok else 1)


func write_text(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
