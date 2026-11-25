extends RefCounted

const Ledger = preload("res://game_ledger.gd")
const CAMPAIGNS := [Ledger.SAVE, "user://ottawa_river_campaign_2.json"]
const JOURNALS := ["user://ottawa_catches.json", "user://ottawa_catches_2.json"]


static func files(slot: int) -> PackedStringArray:
	var campaign: String = CAMPAIGNS[slot]
	return PackedStringArray([campaign, campaign + ".prev", campaign + ".new", JOURNALS[slot]])


static func has_data(slot: int) -> bool:
	for path in files(slot):
		if FileAccess.file_exists(path):
			return true
	return false


static func reset(slot: int) -> String:
	if not has_data(slot):
		return ""
	var folder := "user://solo_save_backups/slot-%d-%s" % [slot + 1, Crypto.new().generate_random_bytes(8).hex_encode()]
	var backup := ProjectSettings.globalize_path(folder)
	if DirAccess.make_dir_recursive_absolute(backup) != OK:
		return "Could not create a backup for this slot."
	var moved: PackedStringArray = []
	for path in files(slot):
		if not FileAccess.file_exists(path):
			continue
		var original := ProjectSettings.globalize_path(path)
		if DirAccess.rename_absolute(original, backup.path_join(path.get_file())) != OK:
			var restored := true
			for item in moved:
				if DirAccess.rename_absolute(backup.path_join(item.get_file()), ProjectSettings.globalize_path(item)) != OK:
					restored = false
			if not restored:
				return "Could not reset or fully restore this slot. Check " + folder
			DirAccess.remove_absolute(backup)
			return "Could not reset this slot. Its files were restored."
		moved.append(path)
	return ""
