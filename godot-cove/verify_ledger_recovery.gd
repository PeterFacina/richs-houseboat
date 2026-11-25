extends SceneTree

const Ledger = preload("res://game_ledger.gd")
const PATH := "user://ledger_recovery_fixture.json"


func _initialize() -> void:
	if not "houseboat-xp-" in OS.get_user_data_dir().to_lower():
		quit(2)
		return
	for suffix in ["", ".prev", ".new"]:
		if FileAccess.file_exists(PATH + suffix):
			quit(2)
			return
	var ledger := Ledger.new()
	ledger.save_path = PATH
	var original := JSON.stringify({
		"format": 1, "sites": {}, "cash": 71, "work_minutes": 999,
		"held_fish": {"one": {"length": 38}, "bad": "damaged"},
	})
	write_fixture(PATH, "{")
	write_fixture(PATH + ".prev", original)

	ledger.load_file()
	var recovered: bool = ledger.state.cash == 71 and ledger.state.work_minutes == 999.0
	recovered = recovered and ledger.state.held_fish.is_empty() and ledger.state.ice_chest == [{"length": 38.0}]
	ledger.state.cash = 82
	ledger.save_file()
	var saved: bool = ledger.error.is_empty() and FileAccess.get_file_as_string(PATH + ".prev") == original
	ledger.load_file()
	saved = saved and ledger.state.cash == 82 and ledger.state.ice_chest.size() == 1

	ledger.state.cash = 91
	ledger.save_file()
	write_fixture(PATH, "{")
	ledger.load_file()
	var rotated: bool = ledger.state.cash == 82
	print("Recovery, backup preservation and normal rotation: ", recovered, ", ", saved, ", ", rotated)
	quit(0 if recovered and saved and rotated else 1)


func write_fixture(path: String, contents: String) -> void:
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(contents)
	file.close()
