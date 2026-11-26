extends Control

signal dismissed
signal page_selected(page: int)
signal services_requested
signal tracker_changed

const Style = preload("res://notebook_theme.gd")
const Story = preload("res://rich_story.gd")
const XP = preload("res://progression.gd")
const ReaperQuest = preload("res://roach_reaper_quest.gd")
enum Page { QUESTS, FISH, CHART, LOCALS, CATCH_LOG }
const PAGE_NAMES := ["Quests", "Fish Index", "River Chart", "The Locals", "Catch Log"]
const LOCALS := ["Big Rich", "Shannon", "Marina Attendant"]

var active_page := Page.QUESTS
var track_quest := true
var pages: Array[Control] = []
var tabs: Array[Button] = []
var quest_rows: Array[Button] = []
var quest_selected := 0
var side_row: Button
var side_selected := false
var side_status := ""
var local_selected := 0
var quest_heading: Label
var quest_status: Label
var quest_description: Label
var quest_objective: Label
var quest_rewards: Label
var restoration_status: Label
var local_heading: Label
var local_description: Label
var reputation: ProgressBar
var unlocks: Label
var log_page: VBoxContainer


func _ready() -> void:
	name = "RiverNotebook"
	theme = Style.Menu.get_theme()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	var scrim := ColorRect.new()
	scrim.color = Style.SCRIM
	add_child(scrim)
	scrim.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var cover := PanelContainer.new()
	add_child(cover)
	cover.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	cover.offset_left = 36
	cover.offset_top = 34
	cover.offset_right = -36
	cover.offset_bottom = -34
	cover.add_theme_stylebox_override(&"panel", Style.box(Style.NAVY, Style.Menu.BLUE, 15, 12))
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 10)
	cover.add_child(layout)
	var heading := HBoxContainer.new()
	layout.add_child(heading)
	var title := Style.label("River Notebook", 27, Style.PAPER)
	title.size_flags_horizontal = SIZE_EXPAND_FILL
	heading.add_child(title)
	var close := Style.button("Close  Esc", 38)
	close.pressed.connect(func(): dismissed.emit())
	heading.add_child(close)
	var body := HBoxContainer.new()
	body.add_theme_constant_override(&"separation", 0)
	body.size_flags_vertical = SIZE_EXPAND_FILL
	layout.add_child(body)
	var section_tabs := VBoxContainer.new()
	section_tabs.custom_minimum_size.x = 152
	section_tabs.add_theme_constant_override(&"separation", 7)
	body.add_child(section_tabs)
	for index in PAGE_NAMES.size():
		var tab := Style.button(PAGE_NAMES[index], 48)
		tab.alignment = HORIZONTAL_ALIGNMENT_LEFT
		tab.toggle_mode = true
		tab.pressed.connect(func(): page_selected.emit(index))
		section_tabs.add_child(tab)
		tabs.append(tab)
	var sheets := Control.new()
	sheets.size_flags_horizontal = SIZE_EXPAND_FILL
	sheets.clip_contents = true
	body.add_child(sheets)
	for index in PAGE_NAMES.size():
		var page := Control.new()
		sheets.add_child(page)
		page.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
		pages.append(page)
	build_quests()
	build_locals()
	var log := spread(Page.CATCH_LOG)
	log[0].add_child(Style.label("Catch Log", 27, Style.OLIVE))
	log[0].add_child(Style.label("Your last 25 landed fish appear here."))
	log_page = log[1]
	hide()


func spread(page: Page) -> Array[VBoxContainer]:
	var layout := HBoxContainer.new()
	layout.add_theme_constant_override(&"separation", 0)
	pages[page].add_child(layout)
	layout.set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	var left := Style.page(layout)
	layout.add_child(Style.Binding.new())
	return [left, Style.page(layout)]


func build_quests() -> void:
	var sheets := spread(Page.QUESTS)
	var left := sheets[0]
	var right := sheets[1]
	left.add_child(Style.label("Quests", 27, Style.OLIVE))
	restoration_status = Style.label("", 14, Style.OLIVE)
	left.add_child(restoration_status)
	for index in Story.QUESTS.size():
		var row := Style.button(Story.QUESTS[index].title, 34)
		row.toggle_mode = true
		row.alignment = HORIZONTAL_ALIGNMENT_LEFT
		row.pressed.connect(func():
			side_selected = false
			quest_selected = index
			refresh_quest_details())
		left.add_child(row)
		quest_rows.append(row)
	side_row = Style.button(ReaperQuest.TITLE, 34)
	side_row.toggle_mode = true
	side_row.alignment = HORIZONTAL_ALIGNMENT_LEFT
	side_row.pressed.connect(func():
		side_selected = true
		refresh_quest_details())
	left.add_child(side_row)
	side_row.hide()
	var tracker := CheckButton.new()
	tracker.text = "Track current quest"
	tracker.button_pressed = track_quest
	tracker.toggled.connect(func(enabled: bool):
		track_quest = enabled
		tracker_changed.emit())
	left.add_child(tracker)
	var services := Style.button("Boat Services")
	services.pressed.connect(func(): services_requested.emit())
	left.add_child(services)

	quest_heading = Style.label("", 25, Style.OLIVE)
	quest_status = Style.label("", 15, Style.OLIVE)
	quest_description = Style.label("")
	quest_objective = Style.label("")
	quest_rewards = Style.label("")
	for label in [quest_heading, quest_status, quest_description]:
		right.add_child(label)
	right.add_child(HSeparator.new())
	right.add_child(Style.label("Objectives", 18, Style.OLIVE))
	right.add_child(quest_objective)
	right.add_child(Style.label("Rewards", 18, Style.OLIVE))
	right.add_child(quest_rewards)


func build_locals() -> void:
	var sheets := spread(Page.LOCALS)
	sheets[0].add_child(Style.label("The Locals", 27, Style.OLIVE))
	var local_tabs := ButtonGroup.new()
	for index in LOCALS.size():
		var contact := Style.button(LOCALS[index])
		contact.alignment = HORIZONTAL_ALIGNMENT_LEFT
		contact.toggle_mode = true
		contact.button_group = local_tabs
		contact.set_pressed_no_signal(index == 0)
		contact.pressed.connect(func():
			local_selected = index
			refresh_locals())
		sheets[0].add_child(contact)
	var page := sheets[1]
	local_heading = Style.label("", 25, Style.OLIVE)
	local_description = Style.label("")
	reputation = ProgressBar.new()
	reputation.max_value = Story.QUESTS.size()
	reputation.show_percentage = false
	reputation.custom_minimum_size.y = 16
	unlocks = Style.label("")
	for element in [local_heading, local_description, reputation, unlocks]:
		page.add_child(element)


func attach_catch_log(entries: VBoxContainer) -> void:
	entries.reparent(log_page, false)
	entries.size_flags_horizontal = SIZE_EXPAND_FILL


func select_page(index: int, story: Story) -> void:
	active_page = index as Page
	for candidate in pages.size():
		pages[candidate].visible = candidate == index
		tabs[candidate].set_pressed_no_signal(candidate == index)
	if active_page == Page.QUESTS:
		quest_selected = mini(int(story.state().step), Story.QUESTS.size() - 1)
	refresh(story)
	show()
	tabs[index].grab_focus(true)


var current_story: Story


func refresh(story: Story) -> void:
	current_story = story
	var stage := int(story.state().step)
	restoration_status.text = "%d / %d components installed%s" % [
		story.state().components.size(), Story.Parts.COMPONENTS.size(),
		"  ·  Afloat" if story.state().launched else "  ·  On blocks"]
	for index in quest_rows.size():
		var indicator := "✓" if index < stage else ("!" if index == stage else "·")
		if index == stage and story.status() != Story.Chain.Status.AVAILABLE:
			indicator = "?"
		quest_rows[index].text = "%s  %s" % [indicator, Story.QUESTS[index].title]
	refresh_quest_details()
	refresh_locals()


func refresh_quest_details() -> void:
	if current_story == null:
		return
	side_row.set_pressed_no_signal(side_selected)
	for index in quest_rows.size():
		quest_rows[index].set_pressed_no_signal(not side_selected and index == quest_selected)
	if side_selected:
		quest_heading.text = ReaperQuest.TITLE
		quest_status.text = side_status
		quest_description.text = ReaperQuest.INTRO
		quest_objective.text = ReaperQuest.OBJECTIVE
		quest_rewards.text = "Rare · %d XP" % XP.REWARDS[ReaperQuest.ID]
		return
	var stage := int(current_story.state().step)
	var quest: Dictionary = Story.QUESTS[quest_selected]
	quest_heading.text = quest.title
	quest_status.text = "Completed" if quest_selected < stage else (current_story.progress_text() if quest_selected == stage else "Locked")
	quest_description.text = Story.RETIREMENT if current_story.owns_houseboat() and quest_selected == Story.QUESTS.size() - 1 else quest.text
	quest_objective.text = current_story.objectives_text(quest)
	quest_rewards.text = "$%d crew cash  ·  %d XP" % [quest.cash, XP.REWARDS[quest.id]]
	if quest.id == "story_fish":
		quest_rewards.text += "\nBig Rich’s Old Fishing Rod"
	elif quest.id == "story_retire":
		quest_rewards.text += "\nHouseboat ownership, companion and optional upgrades"


func set_side_quest(quest: Dictionary, text: String) -> void:
	side_row.visible = not quest.is_empty()
	side_status = text
	if side_selected and quest.is_empty():
		side_selected = false
		refresh_quest_details()
	elif side_selected:
		quest_status.text = side_status


func refresh_locals() -> void:
	if current_story == null:
		return
	local_heading.text = LOCALS[local_selected]
	reputation.visible = local_selected == 0
	unlocks.visible = local_selected == 0
	match local_selected:
		0:
			var milestones := int(current_story.state().step)
			reputation.value = milestones
			local_description.text = "Houseboat restoration\n%d of %d quests completed\n\nReputation  %d%%" % [
				milestones, Story.QUESTS.size(), roundi(100.0 * milestones / Story.QUESTS.size())]
			var repaired: int = current_story.state().components.size()
			local_description.text += "\n\n%d / %d components installed" % [repaired, Story.Parts.COMPONENTS.size()]
			unlocks.text = "Finish Rich’s Retirement Plan to take ownership and unlock Big Rich as a companion."
			if current_story.owns_houseboat():
				var company := "Aboard" if current_story.companion_aboard() else "At the marina yard"
				unlocks.text = "Your crew owns the houseboat.\n\nBig Rich  ·  %s\n15%% higher bite rate and 10%% less fuel use aboard." % company
		1:
			local_description.text = "Public Works\nOffers daily mowing routes at the Cedar Road yard."
		2:
			local_description.text = "Visitor Dock\nExplains the marina pumps and refuelling."
