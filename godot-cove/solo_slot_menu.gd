extends Control

signal selected(slot: int)
signal closed

const Atlas = preload("res://river_menu_theme.gd")
const Saves = preload("res://solo_saves.gd")
const Ledger = preload("res://river_ledger.gd")

var play_buttons: Array[Button] = []
var reset_buttons: Array[Button] = []
var summaries: Array[Label] = []
var confirmation := ConfirmationDialog.new()
var notice: Label
var pending_slot := -1


func _ready() -> void:
	theme = Atlas.get_theme()
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var shade := ColorRect.new()
	shade.color = Atlas.SCRIM
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var frame := Atlas.panel(center, Atlas.CREAM, Atlas.SAND, 16, 24)
	var layout := VBoxContainer.new()
	layout.custom_minimum_size.x = 460
	layout.add_theme_constant_override("separation", 13)
	frame.add_child(layout)
	layout.add_child(Atlas.text("Solo saves", 33, Atlas.NAVY, true))
	for slot in Saves.CAMPAIGNS.size():
		var card := Atlas.panel(layout, Atlas.PAPER, Atlas.SAND, 10, 14)
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		card.add_child(row)
		var details := VBoxContainer.new()
		details.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(details)
		details.add_child(Atlas.text("Slot %d" % (slot + 1), 20, Atlas.NAVY, true))
		var summary := Atlas.text("", 15, Atlas.MUTED)
		details.add_child(summary)
		summaries.append(summary)
		var play := Atlas.button("", &"MainAction", "play", 40)
		play.pressed.connect(func(): selected.emit(slot))
		row.add_child(play)
		play_buttons.append(play)
		var reset := Atlas.button("Reset", &"QuietAction", "reset", 40)
		reset.pressed.connect(ask_reset.bind(slot))
		row.add_child(reset)
		reset_buttons.append(reset)
	notice = Atlas.text("", 15, Atlas.MUTED)
	notice.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	notice.hide()
	layout.add_child(notice)
	var back := Atlas.button("Back", &"QuietAction", "back", 38)
	back.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
	back.pressed.connect(close)
	layout.add_child(back)
	add_child(confirmation)
	confirmation.ok_button_text = "Reset slot"
	Atlas.style_confirmation(confirmation)
	confirmation.confirmed.connect(reset_selected)
	confirmation.canceled.connect(func(): pending_slot = -1)
	hide()


func open() -> void:
	notice.hide()
	pending_slot = -1
	refresh()
	show()
	play_buttons[0].grab_focus()


func close() -> void:
	hide()
	closed.emit()


func _unhandled_input(event: InputEvent) -> void:
	if visible and event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		close()


func refresh() -> void:
	for slot in Saves.CAMPAIGNS.size():
		var ledger := Ledger.new()
		ledger.save_path = Saves.CAMPAIGNS[slot]
		var saved := ledger.load_file()
		var occupied := Saves.has_data(slot)
		var journal_only := occupied and FileAccess.file_exists(Saves.JOURNALS[slot]) \
			and not FileAccess.file_exists(ledger.save_path) and not FileAccess.file_exists(ledger.save_path + ".prev") \
			and not FileAccess.file_exists(ledger.save_path + ".new")
		play_buttons[slot].text = "Continue" if saved or journal_only else "Start new"
		play_buttons[slot].disabled = occupied and not saved and not journal_only
		reset_buttons[slot].disabled = not occupied
		if saved:
			summaries[slot].text = "Wallet $%.2f" % (ledger.wallet_cents() / 100.0)
		elif journal_only:
			summaries[slot].text = "Catch journal"
		else:
			summaries[slot].text = "Saved data needs reset" if occupied else "Empty slot"


func ask_reset(slot: int) -> void:
	pending_slot = slot
	confirmation.title = "Reset Slot %d?" % (slot + 1)
	confirmation.dialog_text = "Start this slot over? Its progress and catch journal will be moved to a backup on this device."
	confirmation.popup_centered(Vector2i(430, 0))
	confirmation.get_cancel_button().grab_focus.call_deferred()


func reset_selected() -> void:
	var slot := pending_slot
	pending_slot = -1
	if slot < 0:
		return
	var error := Saves.reset(slot)
	notice.text = "Slot %d is ready for a new game." % (slot + 1) if error.is_empty() else error
	notice.show()
	refresh()
	if not play_buttons[slot].disabled:
		play_buttons[slot].grab_focus()
