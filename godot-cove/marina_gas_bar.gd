extends StaticBody3D

const Kit = preload("res://scenery.gd")
const Pump = preload("res://marina_fuel.gd")
const Attendant = preload("res://marina_attendant.gd")
const PAD_LENGTH := 5.7
const PAD_DEPTH := 1.60
const TALK_DISTANCE := 3.1

var pumps: Array[Pump] = []
var attendant: Attendant
var game: Node3D
var campaign: Node3D
var gesture := ""
var gesture_started := -10.0
var next_line_at := -1.0
var caption: PanelContainer
var caption_text: Label
var caption_until := 0.0


func build(concrete: Texture2D) -> void:
	collision_mask = 0
	var cement := Kit.paint(Color("#dddacf"), .91)
	cement.albedo_texture = concrete
	cement.uv1_triplanar = true
	var iron := Kit.paint(Color("#293736"), .72, .23)
	var trim := Kit.paint(Color("#52706a"), .65)
	Kit.box_at(self, Vector3.DOWN * .115, Vector3(PAD_LENGTH, .23, PAD_DEPTH), cement)
	Kit.collider(self, Vector3.DOWN * .115, Vector3(PAD_LENGTH, .23, PAD_DEPTH))
	Kit.box_at(self, Vector3(0, -.33, 0), Vector3(PAD_LENGTH - .12, .21, PAD_DEPTH - .14), iron)
	Kit.box_at(self, Vector3(0, -.138, -PAD_DEPTH * .50), Vector3(PAD_LENGTH, .15, .09), iron)
	for index in 2:
		var pump := Pump.new()
		pump.pump_number = index + 1
		pump.name = "Pump%d" % pump.pump_number
		pump.collision_mask = 0
		add_child(pump)
		pump.position = Vector3(-1.52 + index * 1.57, 0, .32)
		pump.build(pump.pump_number)
		pumps.append(pump)
	build_attendant(trim, iron)


func build_attendant(trim: Material, iron: Material) -> void:
	var stand_x := 2.05
	Kit.box_at(self, Vector3(stand_x, .469, .36), Vector3(.68, .938, .38), trim)
	Kit.box_at(self, Vector3(stand_x, .958, .36), Vector3(.78, .057, .45), iron)
	Kit.collider(self, Vector3(stand_x, .49, .36), Vector3(.73, .98, .40))
	stand_sign(Vector3(stand_x, .68, .555), 0.0)
	var post := Vector3(2.59, .70, -.68)
	Kit.box_at(self, post, Vector3(.052, 1.4, .052), iron)
	Kit.box_at(self, post + Vector3(-.22, .47, 0), Vector3(.57, .28, .065), trim)
	stand_sign(post + Vector3(-.22, .47, -.039), PI)
	attendant = Attendant.new()
	attendant.name = "MarinaAttendant"
	add_child(attendant)
	attendant.position = Vector3(stand_x, 0, -.30)
	attendant.build()
	attendant.pose(1.0, 0.0, attendant.to_global(Attendant.TALK_POINT), "", 0.0)
	Kit.collider(self, Vector3(stand_x, .74, -.31), Vector3(.54, 1.48, .39))


func stand_sign(at: Vector3, facing: float) -> void:
	var sign := Label3D.new()
	sign.text = "GAS BAR"
	sign.font_size = 35
	sign.pixel_size = .00325
	sign.outline_size = 0
	sign.modulate = Color("#f0ead2")
	sign.position = at
	sign.rotation.y = facing
	add_child(sign)


func bind(fishing: Node3D, river_campaign: Node3D) -> void:
	game = fishing
	campaign = river_campaign
	for pump in pumps:
		pump.bind(fishing, river_campaign)
	build_captions()


func build_captions() -> void:
	caption = PanelContainer.new()
	caption.name = "MarinaAttendantSubtitles"
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(.075, .12, .12, .93)
	style.set_corner_radius_all(10)
	style.content_margin_left = 16
	style.content_margin_right = 16
	style.content_margin_top = 9
	style.content_margin_bottom = 9
	caption.add_theme_stylebox_override("panel", style)
	game.hud.add_child(caption)
	caption.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	caption.offset_left = -340
	caption.offset_right = 340
	caption.offset_top = -163
	caption.offset_bottom = -96
	var rows := VBoxContainer.new()
	rows.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.add_child(rows)
	var speaker: Label = game.label(Attendant.NAME, 15, Color("#eac58c"))
	speaker.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rows.add_child(speaker)
	caption_text = game.label("", 17, Color("#fff3db"))
	caption_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	rows.add_child(caption_text)
	caption.hide()


func attendant_line(text: String, seconds: float) -> void:
	caption_text.text = text
	caption_until = game.clock + seconds


func held_by(peer: int) -> Pump:
	if peer <= 0:
		return null
	for pump in pumps:
		if pump.holder == peer:
			return pump
	return null


func is_local_holder() -> bool:
	return held_by(campaign.crew.my_id()) != null


func filler_in_use() -> bool:
	for pump in pumps:
		if pump.connected:
			return true
	return false


func attendant_at() -> Vector3:
	return attendant.to_global(Attendant.TALK_POINT)


func attendant_focused() -> bool:
	return campaign.aiming(attendant_at(), TALK_DISTANCE, .96)


func hint() -> String:
	var held := held_by(campaign.crew.my_id())
	if held != null:
		return held.hint()
	for pump in pumps:
		var prompt := pump.hint()
		if not prompt.is_empty():
			return prompt
	return "E  Talk to Marina Attendant" if attendant_focused() else ""


func interact() -> bool:
	var held := held_by(campaign.crew.my_id())
	if held != null:
		return held.interact()
	for pump in pumps:
		if pump.interact():
			return true
	if attendant_focused():
		if next_line_at < 0.0 and game.clock > gesture_started + 3.4:
			gesture = "greet"
			gesture_started = game.clock
			next_line_at = game.clock + 2.05
			attendant_line("Welcome to Deep River!", 2.05)
		return true
	return false


func action(peer: int, event: String, value: Variant, person: Dictionary) -> void:
	if not (value is Array and value.size() == 2 and value[0] is int and value[0] >= 1 and value[0] <= pumps.size()):
		return
	var pump := pumps[value[0] - 1]
	var command: Variant = value[1]
	if event == "fuel_trigger" and command is bool:
		pump.trigger(peer, command)
	elif event == "fuel_nozzle" and command is String:
		if command == "pickup" and held_by(peer) != null:
			return
		if command == "insert" and not pump.connected and pump.holder == peer and filler_in_use():
			campaign.tell(peer, "That filler already has a nozzle connected.")
			return
		pump.action(peer, command, person)


func tick(delta: float, usable: bool) -> void:
	for pump in pumps:
		pump.tick(delta, usable)
	if next_line_at >= 0.0 and game.clock >= next_line_at:
		next_line_at = -1.0
		gesture = "point"
		gesture_started = game.clock
		if game.player.global_position.distance_to(attendant_at()) < 8.0:
			attendant_line("Take a hose from either pump. Press E at your boat's filler, then hold left mouse.", 5.2)
	caption.visible = game.clock < caption_until and game.play_input() \
		and game.player.global_position.distance_squared_to(attendant_at()) < 64.0
	if game.player.global_position.distance_squared_to(global_position) < 70.0 * 70.0:
		var age: float = game.clock - gesture_started
		attendant.pose(delta, game.clock, game.eye.global_position, gesture if age < 1.65 else "", age)
	else:
		attendant.name_tag.hide()


func disconnect_fillers() -> void:
	for pump in pumps:
		if pump.connected:
			pump.disconnect_filler()


func rack_peer(peer: int) -> void:
	var held := held_by(peer)
	if held != null:
		held.rack()


func rack_all() -> void:
	for pump in pumps:
		pump.rack()


func packet() -> Array:
	var data := []
	for pump in pumps:
		data.append(pump.packet())
	return data


func receive(data: Array, first: bool) -> void:
	if data.size() != pumps.size():
		return
	for index in pumps.size():
		pumps[index].receive(data[index], first)
