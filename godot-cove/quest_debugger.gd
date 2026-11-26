extends CanvasLayer

const Story = preload("res://rich_story.gd")
const Parts = preload("res://houseboat_restoration.gd")

var game: Node3D
var campaign
var story
var original_ledger: Dictionary
var panel: PanelContainer
var quest_picker: OptionButton
var stage_picker: OptionButton
var details: RichTextLabel
var location_toggle: CheckBox
var session_active := false
var selected_quest := 0
var selected_stage := 0


func setup(owner: Node3D, river_campaign: Node3D) -> void:
	game = owner
	campaign = river_campaign
	story = campaign.story
	layer = 30
	build_panel()


func build_panel() -> void:
	var root := Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	panel = PanelContainer.new()
	panel.set_anchors_preset(Control.PRESET_CENTER)
	panel.position = Vector2(-340, -280)
	panel.size = Vector2(680, 560)
	panel.custom_minimum_size = Vector2(680, 560)
	panel.add_theme_stylebox_override("panel", preload("res://game_menu_theme.gd").box(Color("#152b38f5"), Color("#e0b878"), 10, 18))
	root.add_child(panel)
	var body := VBoxContainer.new()
	body.add_theme_constant_override("separation", 10)
	panel.add_child(body)
	var heading := Label.new()
	heading.text = "DEVELOPER QUEST TESTING"
	heading.add_theme_font_size_override("font_size", 24)
	heading.add_theme_color_override("font_color", Color("#f2d59b"))
	body.add_child(heading)
	var intro := Label.new()
	intro.text = "F8 toggles this tool. Tests run in a temporary campaign copy until you leave the game; the copy is never saved."
	intro.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.add_child(intro)
	var selectors := HBoxContainer.new()
	body.add_child(selectors)
	quest_picker = OptionButton.new()
	quest_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	quest_picker.item_selected.connect(_quest_selected)
	selectors.add_child(quest_picker)
	stage_picker = OptionButton.new()
	stage_picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	stage_picker.item_selected.connect(_stage_selected)
	selectors.add_child(stage_picker)
	location_toggle = CheckBox.new()
	location_toggle.text = "Teleport to yard"
	location_toggle.button_pressed = true
	body.add_child(location_toggle)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	add_button(actions, "Start / restart", start_selected)
	add_button(actions, "Jump to stage", jump_to_stage)
	add_button(actions, "Complete quest", complete_selected)
	add_button(actions, "Skip quest", skip_selected)
	add_button(actions, "Reset chain", reset_chain)
	details = RichTextLabel.new()
	details.bbcode_enabled = true
	details.fit_content = true
	details.scroll_active = true
	details.size_flags_vertical = Control.SIZE_EXPAND_FILL
	body.add_child(details)
	var footer := Label.new()
	footer.text = "F8 or Esc: close this menu. Test changes last until you leave the game. Host only in multiplayer."
	footer.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	body.add_child(footer)
	panel.hide()
	populate_quests()


func add_button(parent: HBoxContainer, title: String, action: Callable) -> void:
	var button := Button.new()
	button.text = title
	button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button.pressed.connect(action)
	parent.add_child(button)


func populate_quests() -> void:
	quest_picker.clear()
	for quest: Dictionary in Story.QUESTS:
		quest_picker.add_item(str(quest.title))
	quest_picker.select(clampi(selected_quest, 0, Story.QUESTS.size() - 1))
	populate_stages()


func populate_stages() -> void:
	stage_picker.clear()
	var quest: Dictionary = Story.QUESTS[selected_quest]
	for index in quest.steps.size():
		var objective: Array = quest.steps[index]
		stage_picker.add_item("%02d · %s" % [index + 1, objective[1]])
	stage_picker.select(clampi(selected_stage, 0, quest.steps.size() - 1))
	refresh_details()


func _quest_selected(index: int) -> void:
	selected_quest = index
	selected_stage = 0
	populate_stages()


func _stage_selected(index: int) -> void:
	selected_stage = index
	refresh_details()


func begin_session() -> bool:
	if session_active:
		return true
	if campaign.crew.is_guest():
		game.notify_angling("Only the host can use the quest debugger.", 3.0)
		return false
	original_ledger = campaign.ledger.state
	campaign.ledger.state = original_ledger.duplicate(true)
	campaign.debug_testing = true
	session_active = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	return true


func close_panel() -> void:
	panel.hide()
	if game.is_inside_tree() and DisplayServer.get_name() != "headless":
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func handle_input(event: InputEvent) -> bool:
	if not event is InputEventKey or not event.pressed or event.echo:
		return false
	var key: Key = event.physical_keycode if event.physical_keycode != 0 else event.keycode
	if key == KEY_F8:
		if panel.visible:
			close_panel()
		else:
			if begin_session():
				selected_quest = clampi(int(story.state().get("step", 0)), 0, Story.QUESTS.size() - 1)
				selected_stage = clampi(int(story.state().get("progress", 0.0)), 0, Story.QUESTS[selected_quest].steps.size() - 1)
				panel.show()
				populate_quests()
		get_viewport().set_input_as_handled()
		return true
	if panel.visible and key == KEY_ESCAPE:
		close_panel()
		get_viewport().set_input_as_handled()
		return true
	return false


func selected_definition() -> Dictionary:
	return Story.QUESTS[selected_quest]


func prepare(stage_index: int) -> void:
	var saved: Dictionary = story.state()
	saved.step = selected_quest
	saved.accepted = true
	saved.progress = 0.0
	saved.flags = {}
	saved.loans = {}
	saved.components = {}
	saved.fish = 0
	saved.metres = 0.0
	saved.managed = true
	saved.launched = false
	saved.companion = false
	for key: String in ["borrow_boat", "borrow_car", "bench", "fuel_pickup"]:
		saved.flags.erase(key)
	var quest := selected_definition()
	for index in mini(stage_index, quest.steps.size()):
		var objective: Array = quest.steps[index]
		var id: String = objective[0]
		if Parts.COMPONENTS.has(id):
			Parts.install(saved, id)
		elif id == "fish":
			saved.fish = 3 if quest.id == "story_fish" else 1
		else:
			saved.flags[id] = true
	if quest.id == "story_parts":
		saved.flags.borrow_car = true
		saved.loans.transport = true
	elif quest.id in ["story_repair", "story_engine", "story_electrical"]:
		saved.flags.bench = true
		saved.loans["welder" if quest.id == "story_repair" else ("wrench" if quest.id == "story_engine" else "strippers")] = true
	elif quest.id == "story_fuel":
		saved.flags.fuel_pickup = true
		saved.loans.fuel_can = true
	if quest.id == "story_fish":
		saved.flags.borrow_boat = true
		saved.loans.princecraft = true
		saved.loans.rod = true
		saved.rod_owned = true
	if quest.id == "story_voyage" and stage_index > 0:
		saved.launched = true
	if quest.id == "story_retire":
		saved.launched = true
	saved.progress = float(stage_index)
	story.normalize()
	# Later objectives assume the loaned/restored craft is already at the public launch.
	# Put the matching craft there as the normal quest actions would before syncing the world.
	if quest.id == "story_fish" and stage_index > 0:
		campaign.place_story_craft("princecraft")
	elif quest.id == "story_voyage" and stage_index > 0:
		campaign.place_story_craft("houseboat")
	if location_toggle.button_pressed:
		story.arrive(0)
	story.sync_world()
	campaign.changed(false)
	refresh_details()


func start_selected() -> void:
	if begin_session():
		prepare(0)


func jump_to_stage() -> void:
	if begin_session():
		prepare(selected_stage)


func complete_selected() -> void:
	if begin_session():
		prepare(selected_definition().steps.size() - 1)
		story.state().progress = float(selected_definition().target)
		story.complete_for_debug(campaign.crew.my_id(), selected_definition().id)
		story.sync_world()
		campaign.changed(false)
		refresh_details()


func skip_selected() -> void:
	if begin_session():
		var saved: Dictionary = story.state()
		saved.step = mini(selected_quest + 1, Story.QUESTS.size())
		saved.accepted = false
		saved.progress = 0.0
		story.normalize()
		story.sync_world()
		campaign.changed(false)
		refresh_details()


func reset_chain() -> void:
	if begin_session():
		var saved: Dictionary = story.state()
		saved.clear()
		saved.version = Story.VERSION
		saved.managed = true
		story.normalize()
		story.sync_world()
		campaign.changed(false)
		refresh_details()


func objective_done(saved: Dictionary, quest: Dictionary, id: String) -> bool:
	if Parts.COMPONENTS.has(id):
		return Parts.repaired(saved, id)
	if id == "fish":
		return int(saved.get("fish", 0)) >= (3 if quest.id == "story_fish" else 1)
	return saved.get("flags", {}).get(id, false) == true


func refresh_details() -> void:
	if not is_instance_valid(details):
		return
	var quest := selected_definition()
	var saved: Dictionary = story.state()
	var flags := PackedStringArray()
	for flag: Variant in saved.get("flags", {}).keys():
		if saved.flags[flag]: flags.append(str(flag))
	var stages := PackedStringArray()
	for index in quest.steps.size():
		var objective: Array = quest.steps[index]
		var completed := selected_quest < int(saved.get("step", 0)) or (selected_quest == int(saved.get("step", 0)) and objective_done(saved, quest, objective[0]))
		var active: bool = selected_quest == int(saved.get("step", 0)) and saved.get("accepted", false) and index == int(saved.get("progress", 0.0))
		stages.append(("[color=#8fe0bb]✓[/color] " if completed else ("[color=#f3d184]▶[/color] " if active else "○ ")) + str(objective[1]))
	details.text = "[b]Questline:[/b] Big Rich's introductory restoration chain\n[b]Selected:[/b] %s · stage %d/%d\n[b]Live state:[/b] %s\n[b]Active objective:[/b] %s\n[b]Progress:[/b] %.0f / %.0f\n[b]Flags:[/b] %s\n[b]Houseboat restoration:[/b] %s\n\n%s" % [quest.title, selected_stage + 1, quest.steps.size(), "temporary test copy" if session_active else "saved campaign (read only)", story.progress_text() if session_active else "Debugger closed", float(saved.get("progress", 0.0)), quest.target, ", ".join(flags) if not flags.is_empty() else "none", "complete" if Parts.all_repaired(saved) else "in progress", "\n".join(stages)]
