extends Node3D

signal occupied
signal went_under
signal spill_overboard(at: Vector3)
signal message(text: String, seconds: float)

const Kit = preload("res://scenery.gd")
const Boat = preload("res://houseboat.gd")
const Map = preload("res://deep_river_map.gd")
const WaterFX = preload("res://fishing_water_fx.gd")
const Rig = preload("res://fishing_rig.gd")
const Hands = preload("res://river_hands.gd")
const Actions = preload("res://river_hand_actions.gd")
const Props = preload("res://cabin_props.gd")
const HIGH_SECONDS := 96.0
const GRAVITY := 11.8
const BLACKOUT_SECONDS := 7.5
const CLEAN_SECONDS := 2.15
const FRIDGE := 4
const SPILL := 5
const DURATION := [5.34, 3.29, 3.02, 3.02]

class Impact:
	var due := 0.0
	var point := Vector3.ZERO
	var normal := Vector3.UP
	var boat := false
	var water := false


var vessel: Boat
var river: Map
var eye: Camera3D
var player: CharacterBody3D
var effects: WaterFX
var random := RandomNumberGenerator.new()
var clock := 0.0
var fridge_open := false
var fridge_door: Node3D
var handle: Node3D
var fridge_lamp: OmniLight3D
var supplies: Array[Node3D] = []
var hand_items: Array[Node3D] = []
var spills: Array[MeshInstance3D] = []
var spray: Array[Impact] = []
var focus := -1
var focused_spill: MeshInstance3D
var clean_target: MeshInstance3D
var clean_time := 0.0
var holding: Node3D
var right_hand: Node3D
var left_hand: Node3D
var sleeves: Array[MeshInstance3D] = []
var lighter: Node3D
var bud: MeshInstance3D
var towel: MeshInstance3D
var active := -1
var action_age := 0.0
var action_serial := 0
var pen_in_hand := false
var rig_model: Rig
var reach := Vector3.ZERO
var high_from := -100.0
var high_until := 0.0
var alcohol := 0.0
var pending_alcohol := 0.0
var drinks := 0
var sick_at := INF
var vomit_until := 0.0
var blackout_at := INF
var blackout_until := 0.0
var hangover_until := 0.0
var camera_roll := 0.0
var camera_pitch := 0.0
var vision: ColorRect
var vision_paint: ShaderMaterial
var shade: ColorRect
var shade_label: Label
var hint: Label
var status: Label
var mist_mesh: QuadMesh
var liquid_mesh: SphereMesh


func setup(boat: Boat, character: CharacterBody3D, camera: Camera3D, map: Map,
		water_fx: WaterFX, rig: Rig, hud: Control) -> void:
	rig_model = rig
	vessel = boat
	player = character
	eye = camera
	river = map
	effects = water_fx
	random.randomize()
	build_galley()
	build_viewmodel(rig)
	build_hud(hud)
	mist_mesh = smoke_card()
	liquid_mesh = SphereMesh.new()
	liquid_mesh.radius = .014
	liquid_mesh.height = .034
	liquid_mesh.radial_segments = 8
	liquid_mesh.rings = 4
	liquid_mesh.material = Kit.paint(Color("#81734b"), .34)


func build_galley() -> void:
	var timber := vessel.finish(Color("#7c6954"), .78, true)
	var joints := Kit.paint(Color("#555249"), .64)
	var steel := Kit.paint(Color("#a6aba1"), .48, .33)
	var cream := Kit.paint(Color("#d5d7c8"), .42)
	var rubber := Kit.paint(Color("#3c4544"), .75)
	var shelf := Node3D.new()
	shelf.name = "Galley"
	vessel.add_child(shelf)
	shelf.position = Vector3(-.635, .756, .69)
	Kit.box_at(shelf, Vector3(-.018, .345, 0), Vector3(.48, .69, .93), joints)
	Kit.box_at(shelf, Vector3(.0, .704, 0), Vector3(.57, .060, 1.015), timber)
	Kit.box_at(shelf, Vector3(.236, .391, 0), Vector3(.051, .62, .876), timber)
	Kit.box_at(shelf, Vector3(.27, .529, .0), Vector3(.038, .034, .23), steel)
	Kit.collider(vessel, Vector3(-.647, 1.11, .69), Vector3(.52, .72, 1.015))
	var tray := Kit.box_at(shelf, Vector3(.042, .742, .19), Vector3(.21, .016, .27), steel)
	tray.name = "GalleyTray"
	var pipe := Props.make(shelf, Props.Item.BONG, Vector3(.034, .735, -.204))
	pipe.name = "Bong"
	supplies.append(pipe)
	var pen := Props.make(shelf, Props.Item.PEN, Vector3(.078, .764, .104))
	pen.rotation.x = PI / 2.0
	pen.name = "DabPen"
	supplies.append(pen)
	var cabin_lamp := OmniLight3D.new()
	cabin_lamp.position = Vector3(-.22, 1.52, -.06)
	cabin_lamp.light_color = Color("#f1d7ac")
	cabin_lamp.light_energy = .51
	cabin_lamp.light_specular = 0.0
	cabin_lamp.omni_range = 2.1
	shelf.add_child(cabin_lamp)

	var fridge := Node3D.new()
	fridge.name = "BeerFridge"
	vessel.add_child(fridge)
	fridge.position = Vector3(-.880, .754, 1.787)
	Kit.box_at(fridge, Vector3(.035, .39, 0), Vector3(.12, .78, .64), cream)
	for side in [-1.0, 1.0]:
		Kit.box_at(fridge, Vector3(.285, .38, side * .30), Vector3(.46, .77, .049), cream)
	for y in [.039, .338, .746]:
		Kit.box_at(fridge, Vector3(.289, y, 0), Vector3(.47, .044, .55), cream)
	Kit.collider(vessel, Vector3(-.607, 1.14, 1.787), Vector3(.52, .77, .648))
	fridge_door = Node3D.new()
	fridge_door.position = Vector3(.526, 0, .306)
	fridge.add_child(fridge_door)
	Kit.box_at(fridge_door, Vector3(.022, .401, -.306), Vector3(.079, .749, .631), cream)
	Kit.box_at(fridge_door, Vector3(-.026, .401, -.306), Vector3(.020, .700, .586), rubber)
	Kit.box_at(fridge_door, Vector3(-.042, .402, -.306), Vector3(.018, .646, .535), cream)
	handle = Kit.box_at(fridge_door, Vector3(.075, .496, -.555), Vector3(.049, .206, .038), steel)
	fridge_lamp = OmniLight3D.new()
	fridge_lamp.position = Vector3(.426, .70, -.03)
	fridge_lamp.light_color = Color("#cce9e6")
	fridge_lamp.light_energy = .52
	fridge_lamp.light_specular = 0.0
	fridge_lamp.omni_range = .86
	fridge.add_child(fridge_lamp)
	fridge_lamp.hide()
	for item in [Props.Item.MOLSON, Props.Item.MILLER]:
		var slot := -.148 if item == Props.Item.MOLSON else .119
		var can := Props.make(fridge, item, Vector3(.413, .364, slot))
		can.rotation.y = PI * .5
		supplies.append(can)
		Props.make(fridge, item, Vector3(.248, .364, slot)).rotation.y = PI * .5


func build_viewmodel(rig: Rig) -> void:
	holding = Node3D.new()
	holding.name = "CabinHands"
	eye.add_child(holding)
	for item in Props.NAMES.size():
		var prop := Props.make(holding, item, Vector3.ZERO)
		hand_items.append(prop)
		prop.hide()
	right_hand = rig.glove(1.0, false)
	right_hand.reparent(holding, false)
	left_hand = rig.glove(-1.0, false)
	left_hand.reparent(holding, false)
	lighter = Props.make_lighter(holding)
	var shape := SphereMesh.new()
	shape.radial_segments = 8
	shape.rings = 4
	shape.radius = .014
	shape.height = .026
	bud = Kit.mesh_at(holding, shape, Vector3.ZERO, Kit.paint(Color("#667348"), .82))
	towel = Kit.box_at(holding, Vector3.ZERO, Vector3(.141, .022, .115), Kit.paint(Color("#bbad7b"), .88))
	var fabric := Kit.paint(Color("#4a5549"), .93)
	for _side in 2:
		sleeves.append(rig.make_sleeve(holding))
	for prop in holding.find_children("*", "GeometryInstance3D", true, false):
		prop.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	holding.hide()


func build_hud(hud: Control) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 0
	add_child(layer)
	vision = ColorRect.new()
	vision.mouse_filter = Control.MOUSE_FILTER_IGNORE
	layer.add_child(vision)
	vision.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	vision_paint = ShaderMaterial.new()
	vision_paint.shader = preload("res://cabin_vision.gdshader")
	vision.material = vision_paint
	vision.hide()
	hint = text_label(hud, 19, Control.PRESET_CENTER, Vector4(-280, 46, 280, 78), HORIZONTAL_ALIGNMENT_CENTER)
	status = text_label(hud, 16, Control.PRESET_BOTTOM_RIGHT, Vector4(-442, -84, -24, -35), HORIZONTAL_ALIGNMENT_RIGHT)
	shade = ColorRect.new()
	shade.color = Color.BLACK
	shade.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(shade)
	shade.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	shade_label = text_label(shade, 28, Control.PRESET_CENTER, Vector4(-240, -31, 240, 31), HORIZONTAL_ALIGNMENT_CENTER)
	shade.hide()


func text_label(parent: Control, font: int, anchor: Control.LayoutPreset, offsets: Vector4,
		align: HorizontalAlignment) -> Label:
	var text := Label.new()
	text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	text.horizontal_alignment = align
	text.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	text.add_theme_font_size_override("font_size", font)
	text.add_theme_color_override("font_color", Color("#f2e5be"))
	text.add_theme_color_override("font_outline_color", Color("#14242b"))
	text.add_theme_constant_override("outline_size", 6)
	parent.add_child(text)
	text.set_anchors_and_offsets_preset(anchor)
	text.offset_left = offsets.x
	text.offset_top = offsets.y
	text.offset_right = offsets.z
	text.offset_bottom = offsets.w
	return text


func busy() -> bool:
	return active >= 0 or blackout_until > clock or vomit_until > clock


func hands_in_use() -> bool:
	return busy() or clean_target != null


func walk_scale() -> float:
	return 1.0 - .20 * smoothstep(.55, 5.35, alcohol) - (.11 if hangover_until > clock else 0.0)


func update(delta: float, now: float, on_deck: bool, press: bool, held: bool) -> bool:
	clock = now
	var angle := -1.76 if fridge_open else 0.0
	fridge_door.rotation.y = lerpf(fridge_door.rotation.y, angle, 1.0 - exp(-delta * 11.0))
	fridge_lamp.visible = absf(fridge_door.rotation.y) > .18
	update_condition(delta)
	update_impacts()
	update_focus(on_deck and not busy())
	var used := press and on_deck and use_focus()
	update_cleaning(delta, on_deck and held and not busy())
	update_action(delta)
	update_sleeves()
	update_camera()
	update_feedback(on_deck)
	return used


func update_focus(ready: bool) -> void:
	focus = -1
	focused_spill = null
	if not ready:
		return
	var nearest := 1.0
	for spill in spills:
		var score := sight(spill.global_position, .27, 2.45)
		if score < nearest:
			nearest = score
			focused_spill = spill
			focus = SPILL
	for index in supplies.size():
		if index == Props.Item.PEN:
			continue
		if index >= Props.Item.MOLSON and absf(fridge_door.rotation.y) < 1.13:
			continue
		var at := supplies[index].global_position
		at.y += .118 if index == Props.Item.BONG else .062
		var score := sight(at, .139 if index < Props.Item.MOLSON else .129, 2.6)
		if score < nearest:
			nearest = score
			focus = index
	if focus < 0 and sight(handle.global_position, .46 if not fridge_open else .19, 2.55) < 1.0:
		focus = FRIDGE


func sight(at: Vector3, radius: float, range_m: float) -> float:
	var offset := at - eye.global_position
	var along := offset.dot(-eye.global_basis.z)
	if along < .12 or offset.length_squared() > range_m * range_m:
		return INF
	return (offset + eye.global_basis.z * along).length() / radius + along * .041


func use_focus() -> bool:
	if focus < 0:
		return busy()
	if focus == FRIDGE:
		fridge_open = not fridge_open
		effects.play_sound(handle.global_position, "door_latch", -5.5)
		return true
	if focus == SPILL:
		return true
	active = focus
	action_serial += 1
	action_age = 0.0
	reach = eye.to_local(supplies[active].global_position)
	reach.x = clampf(reach.x, -.65, .65)
	reach.y = clampf(reach.y, -.49, -.14)
	reach.z = clampf(reach.z, -1.41, -.25)
	emit_signal("occupied")
	return true


func use_pen() -> void:
	if hands_in_use() or not pen_in_hand:
		return
	active = Props.Item.PEN
	action_serial += 1
	action_age = 0.0
	reach = Actions.prop_pose(active, .52, Vector3.ZERO).origin
	emit_signal("occupied")


func update_idle_pen() -> void:
	var pen := hand_items[Props.Item.PEN]
	pen.visible = pen_in_hand
	holding.visible = pen_in_hand
	if not pen_in_hand:
		return
	pen.transform = Actions.prop_pose(Props.Item.PEN, .52, Vector3.ZERO)
	pen.get_node("Indicator").hide()
	right_hand.show()
	left_hand.hide()
	lighter.hide()
	bud.hide()
	towel.hide()
	Actions.attach_smoking_grip(right_hand, pen.transform, Actions.right_grip(Props.Item.PEN), "pinch", 1.0)


func update_action(delta: float) -> void:
	if active < 0:
		if clean_target == null:
			update_idle_pen()
		return
	var previous := action_age
	action_age += delta
	if action_age >= DURATION[active]:
		finish_use()
		return
	var item := hand_items[active]
	var retrieve := smoothstep(.16, .55, action_age)
	var cradle := Vector3(.154, -.267, -.474)
	var lower := smoothstep(DURATION[active] - .61, DURATION[active], action_age)
	var base := Vector3(.20, -.56, -.48).lerp(reach, smoothstep(0.0, .33, action_age))
	base = base.lerp(cradle, retrieve) + Vector3.DOWN * lower * .31
	item.position = base
	item.rotation = Vector3(-.12, -.16, -.085)
	holding.visible = blackout_until <= clock
	item.visible = active == Props.Item.PEN or action_age >= .30
	if active != Props.Item.PEN:
		supplies[active].visible = action_age < .30
	right_hand.show()
	left_hand.hide()
	bud.hide()
	lighter.hide()
	towel.hide()
	match active:
		Props.Item.BONG:
			animate_bong(item, previous)
		Props.Item.PEN:
			animate_pen(item, previous)
		_:
			animate_beer(item, previous)
	pose_action(action_age)


func animate_bong(item: Node3D, previous: float) -> void:
	var lit := Actions.bong_lit(action_age)
	var drawing := lit or (action_age >= Actions.BONG_LIGHT_OFF and action_age < 3.36)
	bud.visible = action_age >= .59 and action_age < 1.25
	var flame: MeshInstance3D = lighter.get_node("Flame")
	flame.visible = lit
	flame.scale = Vector3(1.0, .86 + .14 * sin(action_age * 21.0), 1.0)
	var charge: MeshInstance3D = item.get_node("BowlFill")
	charge.visible = action_age >= 1.25
	charge.material_override.emission_energy_multiplier = .84 if lit else 0.0
	for i in 3:
		var bubble: MeshInstance3D = item.get_node("Bubble%d" % i)
		bubble.visible = drawing
		bubble.position.y = .047 + fposmod(action_age * .26 + i * .032, .052)
	if crossed(previous, Actions.BONG_LIGHT_ON):
		sound_at_mouth("lighter", -5.0)
	if crossed(previous, 2.58):
		sound_at_mouth("bubble", -2.5)
	if crossed(previous, 4.02):
		exhale(1.0)


func animate_pen(item: Node3D, previous: float) -> void:
	var drawn := Actions.inhale(Props.Item.PEN, action_age)
	item.get_node("Indicator").visible = drawn > .56
	if crossed(previous, .95):
		sound_at_mouth("draw", -7.0)
	if crossed(previous, 2.34):
		exhale(.65)


func animate_beer(item: Node3D, previous: float) -> void:
	var opening := smoothstep(.58, .85, action_age) * (1.0 - smoothstep(1.02, 1.23, action_age))
	var sip := smoothstep(1.08, 1.53, action_age) * (1.0 - smoothstep(2.16, 2.63, action_age))
	item.position += Vector3(-.072, .128, .152) * sip
	item.rotation.x = -.13 + sip * 1.24
	item.rotation.z = -.17 + sip * .25
	item.get_node("OpenedCan").visible = action_age > .93
	if opening > .0:
		left_hand.position = Vector3(-.33, -.56, -.44).lerp(item.transform * Vector3(-.043, .115, .030), opening)
		left_hand.rotation = Vector3(-.74, .16, .31)
		left_hand.show()
	if crossed(previous, .91):
		sound_at_mouth("can_open", -3.8)
	if crossed(previous, 1.71):
		sound_at_mouth("sip", -6.0)


func update_sleeves() -> void:
	if not holding.visible:
		return
	for index in sleeves.size():
		var side := 1.0 if index == 0 else -1.0
		var hand := right_hand if index == 0 else left_hand
		var sleeve := sleeves[index]
		sleeve.visible = hand.visible
		if sleeve.visible:
			var wrist: Vector3 = hand.transform * hand.get("wrist_anchor")
			var shoulder := Vector3(side * .38, -.655, -.165)
			rig_model.fit_cylinder(sleeve, wrist, shoulder)


func crossed(previous: float, point: float) -> bool:
	return previous < point and action_age >= point


func finish_use() -> void:
	var item := active
	if item != Props.Item.PEN:
		supplies[item].show()
	hand_items[item].hide()
	holding.hide()
	active = -1
	if item == Props.Item.BONG or item == Props.Item.PEN:
		high_from = clock
		high_until = clock + HIGH_SECONDS
		return
	drinks += 1
	pending_alcohol = minf(7.0 - alcohol, pending_alcohol + 1.0)
	var total := alcohol + pending_alcohol
	var upset := .33 + .57 * smoothstep(2.65, 5.55, total)
	if sick_at == INF and total >= 2.67 and (total > 5.25 or random.randf() < upset):
		sick_at = clock + random.randf_range(4.1, 5.4)
	var faint := .14 + smoothstep(4.25, 6.3, total) * .68
	if blackout_at == INF and total > 4.35 and (total >= 6.45 or random.randf() < faint):
		blackout_at = maxf(clock + 6.8, sick_at + 1.5 if sick_at != INF else clock)
	emit_signal("message", "Finished a %s" % Props.NAMES[item], 2.1)


func update_condition(delta: float) -> void:
	var absorbed := minf(pending_alcohol, delta * .23)
	pending_alcohol -= absorbed
	alcohol = clampf(alcohol + absorbed - delta * .0105, 0, 7.0)
	if clock >= sick_at and active < 0 and blackout_until <= clock:
		sick_at = INF
		throw_up()
	if clock >= blackout_at and active < 0 and vomit_until <= clock:
		blackout_at = INF
		sick_at = INF
		blackout_until = clock + BLACKOUT_SECONDS
		hangover_until = blackout_until + 75.0
		high_until = minf(high_until, clock)
		alcohol = minf(alcohol, 1.05)
		pending_alcohol = 0.0
		emit_signal("went_under")


func update_camera() -> void:
	var high := high_amount()
	var drunk := drink_amount()
	var headache := smoothstep(0.0, 19.0, hangover_until - clock) if blackout_until <= clock else 0.0
	var sick := clampf((vomit_until - clock) / 1.18, 0.0, 1.0)
	var faint := blackout_alpha()
	eye.v_offset = (sin(clock * 1.41) * .024 * drunk + sin(clock * 1.13) * .010 * high) - faint * .53
	eye.h_offset = sin(clock * 1.14) * .025 * drunk
	camera_pitch = sin(clock * 1.99) * .019 * drunk - sin(sick * PI) * .15
	camera_roll = sin(clock * 1.36) * (.052 * drunk + .009 * high) - faint * .19
	eye.rotation.z = camera_roll
	vision.visible = high + drunk + headache > .009
	if vision.visible:
		vision_paint.set_shader_parameter("high", high)
		vision_paint.set_shader_parameter("drunk", drunk)
		vision_paint.set_shader_parameter("hangover", headache)
		vision_paint.set_shader_parameter("clock", clock)
	shade.visible = faint > .0
	shade.color.a = faint
	shade_label.text = "Passed out" if blackout_until - clock > 1.5 else "Coming around…"
	shade_label.modulate.a = smoothstep(.48, .92, faint)


func high_amount() -> float:
	return smoothstep(0.0, 6.0, clock - high_from) * smoothstep(0.0, 13.0, high_until - clock)


func drink_amount() -> float:
	return smoothstep(.13, 6.20, alcohol)


func blackout_alpha() -> float:
	var remains := blackout_until - clock
	return smoothstep(0.0, .75, BLACKOUT_SECONDS - remains) * smoothstep(0.0, 1.29, remains)


func update_feedback(on_deck: bool) -> void:
	hint.text = ""
	if on_deck:
		match focus:
			FRIDGE:
				hint.text = "E  Close the fridge" if fridge_open else "E  Open the beer fridge"
			SPILL:
				hint.text = "Hold E  Wipe up the spill" if clean_time <= .0 else "Wiping  %d%%" % roundi(100 * clean_time / CLEAN_SECONDS)
			Props.Item.BONG:
				hint.text = "E  Use the bong"
			Props.Item.MOLSON, Props.Item.MILLER:
				hint.text = "E  Grab a %s" % Props.NAMES[focus]
	var effects_text := PackedStringArray()
	if sick_at != INF:
		effects_text.append("Feeling sick  ·  Face over the rail or toward the deck")
	elif vomit_until > clock:
		effects_text.append("Feeling sick…")
	if high_until > clock:
		var seconds := ceili(high_until - clock)
		effects_text.append("High  %d:%02d" % [seconds / 60, seconds % 60])
	if hangover_until > clock and blackout_until <= clock:
		effects_text.append("Hungover")
	elif alcohol > .29:
		var buzz := "Buzzed" if alcohol < 1.7 else ("Drunk" if alcohol < 3.18 else "Very drunk")
		effects_text.append("%s  ·  %d %s" % [buzz, drinks, "beer" if drinks == 1 else "beers"])
	status.text = "\n".join(effects_text)


func update_cleaning(delta: float, held: bool) -> void:
	var target := focused_spill if held and focus == SPILL else null
	if target != clean_target:
		if clean_target != null:
			clean_target.material_override.set_shader_parameter("remaining", 1.0)
		clean_time = 0.0
		clean_target = target
		if clean_target != null:
			emit_signal("occupied")
	if clean_target == null:
		return
	var previous := clean_time
	clean_time += delta
	if clean_time >= CLEAN_SECONDS:
		spills.erase(clean_target)
		clean_target.queue_free()
		clean_target = null
		focused_spill = null
		clean_time = 0.0
		emit_signal("message", "Spill cleaned up", 2.4)
		return
	if floori(previous * 2.9) != floori(clean_time * 2.9):
		effects.play_sound(clean_target.global_position, "wipe", -7.0)
	clean_target.material_override.set_shader_parameter("remaining", 1.0 - clean_time / CLEAN_SECONDS)
	holding.show()
	right_hand.show()
	left_hand.hide()
	bud.hide()
	lighter.hide()
	towel.show()
	towel.position = Vector3(sin(clean_time * 13.2) * .15, -.342 + cos(clean_time * 10.0) * .014, -.44)
	towel.rotation = Vector3(-.17, cos(clean_time * 13.2) * .22, -.10)
	right_hand.position = towel.position + Vector3(.040, .025, .055)
	right_hand.rotation = Vector3(-.84, -.13, -.10)


func throw_up() -> void:
	vomit_until = clock + 1.18
	emit_signal("occupied")
	sound_at_mouth("retch", -2.5)
	var aim := -eye.global_basis.z
	var start := eye.global_position + aim * .22 - eye.global_basis.y * .192
	for i in 2:
		var direction := (aim + eye.global_basis.x * (-.082 if i == 0 else .11)).normalized()
		var velocity := direction * (4.0 + i * .34) + Vector3.UP * .12
		var hit := trace_fluid(start, velocity)
		if hit.boat or hit.water:
			spray.append(hit)
		emit_particles(liquid_mesh, start, velocity, maxf(.10, hit.due - clock), false)


func trace_fluid(start: Vector3, velocity: Vector3) -> Impact:
	var hit := Impact.new()
	var last := start
	const SLICE := .0375
	for tick in range(1, 26):
		var t := tick * SLICE
		var next := start + velocity * t + Vector3.DOWN * (.5 * GRAVITY * t * t)
		var query := PhysicsRayQueryParameters3D.create(last, next, 1, [player.get_rid()])
		var collision := eye.get_world_3d().direct_space_state.intersect_ray(query)
		if not collision.is_empty():
			hit.due = clock + t
			hit.boat = collision.collider == vessel
			if hit.boat:
				hit.point = vessel.to_local(collision.position)
				hit.normal = vessel.global_basis.inverse() * collision.normal
			return hit
		var surf := river.wave_height(next, clock + t)
		if next.y < surf and last.y >= surf and river.depth_at(next) > .24:
			hit.due = clock + t
			hit.point = next
			hit.point.y = surf
			hit.water = true
			return hit
		last = next
	hit.due = clock + .82
	return hit


func update_impacts() -> void:
	var chum := Vector3.INF
	for i in range(spray.size() - 1, -1, -1):
		var hit := spray[i]
		if clock < hit.due:
			continue
		spray.remove_at(i)
		if hit.water:
			effects.break_surface(effects.on_water(hit.point, clock), .51, "splash")
			chum = hit.point
		elif hit.boat:
			leave_spill(hit.point, hit.normal)
	if chum.is_finite():
		emit_signal("spill_overboard", chum)


func leave_spill(at: Vector3, normal: Vector3) -> void:
	if spills.size() >= 10:
		var old := spills.pop_front() as MeshInstance3D
		if clean_target == old:
			clean_target = null
			clean_time = 0.0
		old.queue_free()
	var mat := ShaderMaterial.new()
	mat.shader = preload("res://boat_spill.gdshader")
	mat.set_shader_parameter("seed", random.randf_range(-18.0, 29.0))
	var shape := QuadMesh.new()
	shape.size = Vector2(random.randf_range(.36, .55), random.randf_range(.25, .45))
	var patch := Kit.mesh_at(vessel, shape, at + normal * .009, mat)
	patch.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var up := Vector3.FORWARD if absf(normal.y) > .94 else Vector3.UP
	patch.basis = Basis.looking_at(-normal, up).rotated(normal, random.randf_range(0.0, TAU))
	spills.append(patch)
	effects.play_sound(patch.global_position, "spill", -5.8)


func sound_at_mouth(tag: String, volume: float) -> void:
	effects.play_sound(eye.global_position - eye.global_basis.z * .26, tag, volume)


func exhale(size: float) -> void:
	sound_at_mouth("exhale", -6.2)
	var forward := -eye.global_basis.z
	var start := eye.global_position + forward * .34 - Vector3.UP * .115
	var wind := river.downstream(start, clock) * .42 + forward * (1.27 * size)
	emit_particles(mist_mesh, start, wind, 1.57, true)


func emit_particles(mesh: Mesh, start: Vector3, force: Vector3, lifetime: float, smoke: bool) -> void:
	var stream := CPUParticles3D.new()
	stream.mesh = mesh
	stream.amount = 35 if smoke else 28
	stream.lifetime = lifetime
	stream.one_shot = true
	stream.explosiveness = .42 if smoke else .88
	stream.emitting = false
	stream.direction = force.normalized()
	stream.spread = 18.0 if smoke else 9.0
	stream.initial_velocity_min = force.length() * .67
	stream.initial_velocity_max = force.length() * 1.13
	stream.gravity = Vector3.UP * .255 if smoke else Vector3.DOWN * GRAVITY
	stream.scale_amount_min = .61
	stream.scale_amount_max = 1.31
	var color := Gradient.new()
	color.offsets = PackedFloat32Array([0.0, .18, .72, 1.0])
	var opacity := .29 if smoke else 1.0
	color.colors = PackedColorArray([Color(1, 1, 1, 0), Color(1, 1, 1, opacity),
		Color(1, 1, 1, opacity * .36), Color(1, 1, 1, 0)])
	stream.color_ramp = color
	if smoke:
		var grow := Curve.new()
		grow.add_point(Vector2(0, .21))
		grow.add_point(Vector2(.38, .72))
		grow.add_point(Vector2(1, 1.0))
		stream.scale_amount_curve = grow
	stream.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(stream)
	stream.global_position = start
	stream.finished.connect(stream.queue_free)
	stream.emitting = true


func smoke_card() -> QuadMesh:
	var image := Image.create_empty(56, 56, false, Image.FORMAT_RGBA8)
	for y in 56:
		for x in 56:
			var p := Vector2(x - 27.5, y - 27.5) / 27.5
			var ridge := .58 + .22 * cos(p.x * 8.9 - p.y * 3.7) + .18 * sin(p.y * 12.0 + p.x * 7.1)
			var opacity := pow(maxf(0.0, 1.0 - p.length_squared()), 2.2) * ridge
			image.set_pixel(x, y, Color(.82, .86, .84, opacity))
	var paint := ShaderMaterial.new()
	paint.shader = preload("res://cabin_smoke.gdshader")
	paint.set_shader_parameter("vapor", ImageTexture.create_from_image(image))
	var mesh := QuadMesh.new()
	mesh.material = paint
	mesh.size = Vector2(.48, .39)
	return mesh


func pose_action(age: float) -> void:
	if active < 0 or not holding.visible:
		return
	var item := hand_items[active]
	item.transform = Actions.prop_pose(active, age, reach)
	right_hand.show()
	left_hand.hide()
	if active == Props.Item.BONG:
		pose_bong_hands(item.transform, age)
	elif active == Props.Item.PEN:
		Actions.attach_smoking_grip(right_hand, item.transform, Actions.right_grip(active), Actions.right_pose(active), 1.0)
	else:
		Actions.attach(right_hand, item.transform, Actions.right_grip(active), Actions.right_pose(active))
		if age >= .58 and age < 1.23:
			Actions.attach(left_hand, item.transform, Vector3(0, .125, -.004), "pinch")
			left_hand.show()
	update_sleeves()


func pose_bong_hands(item: Transform3D, age: float) -> void:
	Actions.attach_bong_grip(left_hand, item)
	left_hand.show()
	right_hand.hide()
	var bowl := item * Actions.BONG_BOWL
	var right_rest := Vector3(.34, -.52, -.38)
	var packing := smoothstep(.59, .89, age) * (1.0 - smoothstep(1.30, 1.52, age))
	if packing > 0.0:
		var pinch := right_rest.lerp(bowl + Vector3(.018, .035, 0), packing)
		Hands.align(right_hand, pinch, Basis.from_euler(Vector3(.3, .2, .2)), "pinch")
		right_hand.show()
		bud.position = pinch + Vector3(-.018, -.010, 0)
	var lighting := smoothstep(2.04, 2.40, age) * (1.0 - smoothstep(Actions.BONG_LIGHT_OFF, 3.44, age))
	lighter.visible = lighting > 0.0
	if lighter.visible:
		lighter.basis = Basis.from_euler(Vector3(.20, 0, .55))
		var flame_tip := lighter.basis * Vector3(.003, .076, 0)
		lighter.position = right_rest.lerp(bowl + Vector3.UP * .008 - flame_tip, lighting)
		Actions.attach_smoking_grip(right_hand, lighter.transform, Vector3(0, .025, 0), "pinch", 1.0)
		right_hand.show()


func _process(_delta: float) -> void:
	if active >= 0:
		pose_action(action_age + Engine.get_physics_interpolation_fraction() / float(Engine.physics_ticks_per_second))


func visual_packet() -> Dictionary:
	if not holding.visible:
		return {"use_item": -1}
	if active < 0:
		return {"use_item": Props.Item.PEN, "use_age": -1.0, "use_prop": hand_items[Props.Item.PEN].transform} \
			if pen_in_hand else {"use_item": -1}
	var prop_pose := hand_items[active].transform
	var lighter_pose := lighter.transform
	var offset := Actions.world_offset(active, action_age)
	prop_pose.origin += offset
	lighter_pose.origin += offset
	return {"use_item": active, "use_age": action_age, "use_serial": action_serial,
		"use_prop": prop_pose, "use_lighter": lighter_pose,
		"lighter_visible": lighter.visible, "use_smoke": active in [Props.Item.BONG, Props.Item.PEN]}
