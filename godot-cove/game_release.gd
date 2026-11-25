extends RefCounted

const MenuTheme = preload("res://game_menu_theme.gd")
const NOTES_DIR := "res://release-notes"


static func latest_release() -> Dictionary:
	var history := release_history()
	return history.back() if not history.is_empty() else {}


static func release_history() -> Array[Dictionary]:
	var releases: Array[Dictionary] = []
	for file_name in DirAccess.get_files_at(NOTES_DIR):
		if not file_name.ends_with(".json"):
			continue
		var file := FileAccess.open(NOTES_DIR.path_join(file_name), FileAccess.READ)
		if file == null:
			continue
		var parsed: Variant = JSON.parse_string(file.get_as_text())
		if parsed is Dictionary and parsed.get("player_facing", false) and int(parsed.get("pr", 0)) > 0:
			releases.append(parsed)
	releases.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("pr", 0)) < int(b.get("pr", 0)))
	return releases


static func version_text(release: Dictionary = {}) -> String:
	var data := release if not release.is_empty() else latest_release()
	var number := int(data.get("pr", 0))
	return "Game PR #%d" % number if number > 0 else "Game PR #—"


static func show_popup(parent: Node) -> void:
	var release := latest_release()
	if release.is_empty():
		return
	var overlay := Control.new()
	overlay.name = "GameReleasePopup"
	overlay.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.process_mode = Node.PROCESS_MODE_ALWAYS
	parent.add_child(overlay)
	var shade := ColorRect.new()
	shade.color = MenuTheme.SCRIM
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(shade)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	overlay.add_child(center)
	var frame := PanelContainer.new()
	frame.custom_minimum_size = Vector2(540, 0)
	frame.add_theme_stylebox_override("panel", MenuTheme.box(MenuTheme.CREAM, MenuTheme.SAND, 15, 24))
	center.add_child(frame)
	var content := VBoxContainer.new()
	content.add_theme_constant_override("separation", 15)
	frame.add_child(content)
	content.add_child(MenuTheme.text("RICH’S HOUSEBOAT  ·  %s" % version_text(release), 15, MenuTheme.ORANGE, true))
	content.add_child(MenuTheme.text("What’s Been Added?", 34, MenuTheme.NAVY, true))
	content.add_child(HSeparator.new())
	var history := ScrollContainer.new()
	history.custom_minimum_size = Vector2(490, 300)
	history.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	content.add_child(history)
	var entries := VBoxContainer.new()
	entries.add_theme_constant_override("separation", 10)
	history.add_child(entries)
	for entry in release_history():
		entries.add_child(MenuTheme.text(version_text(entry), 16, MenuTheme.ORANGE, true))
		for item in entry.get("bullets", []):
			var line := Label.new()
			line.text = "•  " + str(item)
			line.add_theme_font_size_override("font_size", 18)
			line.add_theme_color_override("font_color", MenuTheme.NAVY)
			line.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			entries.add_child(line)
	var button := MenuTheme.button("Continue", &"MainAction", "play", 50)
	content.add_child(button)
	button.pressed.connect(func(): overlay.queue_free())
	button.call_deferred("grab_focus")
