extends Control

signal dismissed

const MenuTheme = preload("res://game_menu_theme.gd")
const Crew = preload("res://multiplayer_session.gd")

var crew: Crew
var connection_fields: VBoxContainer
var name_field: LineEdit
var address: LineEdit
var roster: VBoxContainer
var status: Label
var start_button: Button
var disconnect: Button
var back: Button
var previous_mode := ""


func setup(session: Crew) -> void:
	crew = session
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	theme = MenuTheme.get_theme()

	var shade := ColorRect.new()
	shade.color = Color("#101d25d9")
	add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var center := CenterContainer.new()
	add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	var margin := MenuTheme.panel(center, MenuTheme.CREAM, MenuTheme.SAND, 15, 24)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 684
	column.add_theme_constant_override("separation", 16)
	margin.add_child(column)
	column.add_child(MenuTheme.text("RICH’S HOUSEBOAT", 14, MenuTheme.ORANGE, true))
	column.add_child(MenuTheme.text("Multiplayer Lobby", 42, MenuTheme.NAVY, true))

	var body := HBoxContainer.new()
	body.add_theme_constant_override("separation", 16)
	column.add_child(body)
	var left := VBoxContainer.new()
	left.custom_minimum_size.x = 340
	left.add_theme_constant_override("separation", MenuTheme.GAP)
	body.add_child(left)
	connection_fields = VBoxContainer.new()
	connection_fields.add_theme_constant_override("separation", MenuTheme.GAP)
	left.add_child(connection_fields)
	connection_fields.add_child(MenuTheme.text("Display name", 15, MenuTheme.NAVY, true))
	name_field = LineEdit.new()
	name_field.text = crew.local_name
	name_field.max_length = 18
	name_field.custom_minimum_size.y = 38
	connection_fields.add_child(name_field)
	var host := MenuTheme.button("Host", &"MainAction", "crew", 40)
	host.pressed.connect(func(): crew.host(name_field.text))
	connection_fields.add_child(host)
	connection_fields.add_child(MenuTheme.text("Host’s LAN or Tailscale IP", 15, MenuTheme.NAVY, true))
	var join_row := HBoxContainer.new()
	join_row.add_theme_constant_override("separation", MenuTheme.GAP)
	connection_fields.add_child(join_row)
	address = LineEdit.new()
	address.placeholder_text = "Host IP address"
	address.max_length = 64
	address.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	join_row.add_child(address)
	var join := MenuTheme.button("Join", &"Button", "", 38)
	join.pressed.connect(join_room)
	address.text_submitted.connect(func(_value: String): join_room())
	join_row.add_child(join)

	status = MenuTheme.text("", 16, MenuTheme.BLUE)
	status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	left.add_child(status)
	var roster_margin := MenuTheme.panel(body, MenuTheme.PAPER, MenuTheme.SAND, 10, 14)
	(roster_margin.get_parent() as Control).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roster = VBoxContainer.new()
	roster.custom_minimum_size.y = 205
	roster.add_theme_constant_override("separation", 8)
	roster_margin.add_child(roster)

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", MenuTheme.GAP)
	column.add_child(footer)
	back = MenuTheme.button("Back to Title", &"QuietAction", "back")
	back.pressed.connect(func(): dismissed.emit())
	footer.add_child(back)
	disconnect = MenuTheme.button("Disconnect")
	disconnect.pressed.connect(func(): crew.stop())
	footer.add_child(disconnect)
	footer.add_spacer(false)
	start_button = MenuTheme.button("Start Trip", &"MainAction", "play")
	start_button.pressed.connect(crew.start_session)
	footer.add_child(start_button)
	crew.changed.connect(refresh)
	refresh()
	host.grab_focus()


func join_room() -> void:
	crew.join(name_field.text, address.text)


func refresh() -> void:
	connection_fields.visible = crew.mode == "solo"
	start_button.visible = crew.on_server()
	disconnect.visible = crew.mode != "solo"
	disconnect.text = "Cancel connection" if crew.mode == "joining" else "Leave lobby"
	status.text = crew.status
	if crew.mode == "guest" and not crew.started:
		status.text += "\nWaiting for the host to start."
	for child in roster.get_children():
		roster.remove_child(child)
		child.queue_free()
	roster.add_child(MenuTheme.text("Connected crew  %d / %d" % [crew.people.size(), Crew.MAX_GUESTS + 1],
		18, MenuTheme.NAVY, true))
	if crew.people.is_empty():
		roster.add_child(MenuTheme.text("No players connected", 15, MenuTheme.MUTED))
	for peer: int in crew.people:
		var card := MenuTheme.panel(roster, MenuTheme.MIST, MenuTheme.MIST, 6, 8)
		var row := HBoxContainer.new()
		card.add_child(row)
		var player_name := str(crew.people[peer].name)
		if peer == crew.my_id():
			player_name += " (you)"
		var label := MenuTheme.text(player_name, 16, MenuTheme.NAVY, true)
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(label)
		row.add_child(MenuTheme.text("Host" if peer == 1 else "Guest", 14, MenuTheme.BLUE))
	if previous_mode != crew.mode:
		if crew.on_server():
			start_button.grab_focus()
		elif crew.mode == "solo":
			name_field.grab_focus()
		else:
			disconnect.grab_focus()
	previous_mode = crew.mode


func _unhandled_key_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		get_viewport().set_input_as_handled()
		dismissed.emit()
