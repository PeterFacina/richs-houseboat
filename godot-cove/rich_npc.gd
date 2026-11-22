extends Node3D

signal spoken(line_id: String, toward: Vector3)

const Model = preload("res://rich_model.gd")
const BASE := "res://ottawa/rich/"
const STATION := Vector3(.86, .752, -1.59)
const REST_YAW := -1.95
const TALK_RANGE := 3.0
const WALK_SPEED := .55
const DECK_CLEARANCE := .50
const STOPS := [
	[STATION, 1.45, "rail", 10.0],
	[Vector3(.74, .752, -1.83), -2.93, "sonar", 13.0],
	[Vector3(.81, .752, -.84), -1.7, "wrench", 17.0],
	[Vector3(-.78, .752, -.84), -1.48, "", 0.0],
	[Vector3(-.86, .752, -1.62), -1.56, "rail", 15.0],
	[Vector3(-.78, .752, -.84), 1.48, "", 0.0],
	[Vector3(.81, .752, -.84), 1.48, "", 0.0],
]

var model := Model.new()
var voice := AudioStreamPlayer3D.new()
var captions: PanelContainer
var caption_text: Label
var hull: AnimatableBody3D
var lines := {}
var by_topic := {}
var unused := {}
var previous_by_topic := {}
var mouth_data := {}
var random := RandomNumberGenerator.new()
var introduced := false
var topic_wait := 0.0
var auto_cooldown := 48.0
var idle_wait := 100.0
var pending_topic := ""
var pending_view := Vector3.ZERO
var speaking_id := ""
var listening_to := Vector3.ZERO
var lip_motion := PackedByteArray()
var time_spoken := 0.0
var line_length := 0.0
var stand: CollisionShape3D
var stop_index := 0
var patrol_direction := 1
var blocked_for := 0.0
var stop_wait := 14.0
var walking := false
var traveled := 0.0
var stop_age := 0.0
var activity := ""
var remote_patrol: Array = []


func setup(ship: AnimatableBody3D, hud: Control) -> void:
	hull = ship
	name = "Rich"
	hull.add_child(self)
	position = STATION
	rotation.y = REST_YAW
	random.randomize()
	for line: Dictionary in JSON.parse_string(FileAccess.get_file_as_string(BASE + "dialogue.json")):
		lines[line.id] = line
		if not by_topic.has(line.topic):
			by_topic[line.topic] = []
		by_topic[line.topic].append(line.id)
	mouth_data = JSON.parse_string(FileAccess.get_file_as_string(BASE + "mouth_motion.json"))
	add_child(model)
	model.build()
	model.pose(1.0, 0.0, 0.0, 0.0, "", 0.0, 0.0)
	var capsule := CapsuleShape3D.new()
	capsule.radius = .185
	capsule.height = 1.56
	stand = CollisionShape3D.new()
	stand.name = "RichCollision"
	stand.shape = capsule
	hull.add_child(stand)
	stand.position = STATION + Vector3.UP * .790
	voice.name = "Voice"
	voice.position = Vector3(0, 1.48, .06)
	voice.unit_size = 2.35
	voice.max_distance = 13.0
	voice.volume_db = -1.5
	add_child(voice)
	make_captions(hud)


func make_captions(hud: Control) -> void:
	captions = PanelContainer.new()
	captions.name = "RichSubtitles"
	captions.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(captions)
	captions.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	captions.offset_left = -378
	captions.offset_right = 378
	captions.offset_top = -151
	captions.offset_bottom = -86
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color("#172424ec")
	panel.border_color = Color("#607069c8")
	panel.border_width_bottom = 1
	panel.set_corner_radius_all(8)
	panel.content_margin_left = 16
	panel.content_margin_right = 16
	panel.content_margin_top = 10
	panel.content_margin_bottom = 10
	captions.add_theme_stylebox_override("panel", panel)
	var row := HBoxContainer.new()
	row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	row.add_theme_constant_override("separation", 18)
	captions.add_child(row)
	var speaker := Label.new()
	speaker.text = "Rich"
	speaker.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	speaker.add_theme_color_override("font_color", Color("#e4c48f"))
	speaker.add_theme_font_size_override("font_size", 19)
	row.add_child(speaker)
	caption_text = Label.new()
	caption_text.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	caption_text.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption_text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption_text.vertical_alignment = VERTICAL_ALIGNMENT_TOP
	caption_text.add_theme_color_override("font_color", Color("#fff4dd"))
	caption_text.add_theme_font_size_override("font_size", 19)
	row.add_child(caption_text)
	captions.hide()


func close_enough(feet: Vector3) -> bool:
	return feet.distance_squared_to(global_position) <= TALK_RANGE * TALK_RANGE


func focused(camera: Camera3D, player: CharacterBody3D) -> bool:
	var target := to_global(Vector3(0, 1.31, .02))
	var approach := target - camera.global_position
	if not close_enough(player.global_position) or approach.normalized().dot(-camera.global_basis.z) < .94:
		return false
	var query := PhysicsRayQueryParameters3D.create(camera.global_position, target, 1, [player.get_rid()])
	var hit := get_world_3d().direct_space_state.intersect_ray(query)
	return hit.is_empty() or (hit.rid == hull.get_rid() and target.distance_squared_to(hit.position) < .32 * .32)


func talk(toward: Vector3) -> void:
	if not speaking_id.is_empty():
		return
	say("talk" if introduced else "intro", toward)


func react(topic: String, toward: Vector3) -> void:
	if auto_cooldown > 0.0 or not speaking_id.is_empty() or not pending_topic.is_empty():
		return
	pending_topic = topic
	pending_view = toward
	topic_wait = .74


func pick(topic: String) -> String:
	if not unused.has(topic) or unused[topic].is_empty():
		var bag: Array = by_topic[topic].duplicate()
		bag.shuffle()
		if bag.size() > 1 and bag.back() == previous_by_topic.get(topic, ""):
			bag.push_front(bag.pop_back())
		unused[topic] = bag
	var next: String = unused[topic].pop_back()
	previous_by_topic[topic] = next
	return next


func say(topic: String, toward: Vector3) -> void:
	var line := pick(topic)
	if play(line, toward):
		spoken.emit(line, toward)


func play(line_id: String, toward: Vector3) -> bool:
	if not lines.has(line_id):
		return false
	var clip := AudioStreamOggVorbis.load_from_file(BASE + "voice/" + line_id + ".ogg")
	if clip == null:
		return false
	voice.stream = clip
	voice.play()
	speaking_id = line_id
	introduced = introduced or lines[line_id].topic == "intro"
	listening_to = toward
	caption_text.text = lines[line_id].text
	lip_motion = Marshalls.base64_to_raw(mouth_data.get(line_id, ""))
	time_spoken = 0.0
	line_length = clip.get_length()
	pending_topic = ""
	auto_cooldown = random.randf_range(76.0, 105.0)
	idle_wait = random.randf_range(110.0, 170.0)
	return true


func patrol_packet() -> Array:
	return [position, rotation.y, activity, stop_age]


func follow_patrol(delta: float, crew_on_deck: Array[Vector3], aloud: bool) -> void:
	remote_patrol.clear()
	if aloud:
		activity = ""
		return
	if not walking:
		stop_wait -= delta
		var stop: Array = STOPS[stop_index]
		activity = stop[2]
		stop_age += delta
		rotation.y = lerp_angle(rotation.y, float(stop[1]), 1.0 - exp(-delta * 3.0))
		if stop_wait > 0.0:
			return
		walking = true
		stop_index = posmod(stop_index + patrol_direction, STOPS.size())
	var destination: Vector3 = STOPS[stop_index][0]
	var direction := destination - position
	activity = ""
	if direction.length() <= WALK_SPEED * delta:
		position = destination
		stop_wait = float(STOPS[stop_index][3])
		stop_age = 0.0
		walking = false
		return
	var forward := direction.normalized()
	var next := position + forward * WALK_SPEED * delta
	for person in crew_on_deck:
		var from_person := position - person
		from_person.y = 0.0
		var clearance := Vector2(next.x - person.x, next.z - person.z).length()
		if from_person.dot(forward) < 0.0 and clearance < DECK_CLEARANCE:
			blocked_for += delta
			if blocked_for > 5.0:
				stop_index = posmod(stop_index - patrol_direction, STOPS.size())
				patrol_direction *= -1
				blocked_for = 0.0
			return
	blocked_for = 0.0
	var heading := atan2(forward.x, forward.z)
	rotation.y = lerp_angle(rotation.y, heading, 1.0 - exp(-delta * 7.0))
	if absf(wrapf(heading - rotation.y, -PI, PI)) < .65:
		position = next


func tick(delta: float, clock: float, camera: Camera3D, show_subtitles: bool, author: bool,
		crew_on_deck: Array[Vector3]) -> void:
	auto_cooldown = maxf(0.0, auto_cooldown - delta)
	if author and speaking_id.is_empty():
		if not pending_topic.is_empty():
			topic_wait -= delta
			if topic_wait <= 0.0:
				var topic := pending_topic
				pending_topic = ""
				if not crew_on_deck.is_empty():
					say(topic, pending_view)
		elif not crew_on_deck.is_empty():
			idle_wait -= delta
			if idle_wait <= 0.0 and auto_cooldown <= 0.0 and not walking:
				say("idle", crew_on_deck.front() + Vector3.UP * 1.57)
	if not speaking_id.is_empty():
		time_spoken += delta
		if time_spoken > line_length + .08:
			speaking_id = ""
			voice.stop()
	var range_squared := camera.global_position.distance_squared_to(global_position)
	var aloud := not speaking_id.is_empty()
	var previous := position
	if author:
		follow_patrol(delta, crew_on_deck, aloud)
		if aloud:
			var to_listener := listening_to - position
			rotation.y = lerp_angle(rotation.y, atan2(to_listener.x, to_listener.z), 1.0 - exp(-delta * 5.0))
	elif remote_patrol.size() == 4:
		var target: Vector3 = remote_patrol[0]
		position = position.lerp(target, 1.0 - exp(-delta * 13.0))
		rotation.y = lerp_angle(rotation.y, float(remote_patrol[1]), 1.0 - exp(-delta * 13.0))
		activity = str(remote_patrol[2])
		stop_age = float(remote_patrol[3])
	stand.position = position + Vector3.UP * .790
	var distance := position.distance_to(previous)
	traveled += distance
	captions.visible = aloud and show_subtitles and range_squared < 9.0 * 9.0
	if range_squared > 28.0 * 28.0:
		return
	var aim := listening_to if aloud else hull.to_local(camera.global_position)
	var offset := aim - position - Vector3.UP * 1.53
	var diff := wrapf(atan2(offset.x, offset.z) - rotation.y, -PI, PI)
	var glide := clampf(distance / maxf(delta * WALK_SPEED, .0001), 0.0, 1.0)
	var glance := aloud or (activity.is_empty() and range_squared < 2.7 * 2.7 and absf(diff) < 1.55)
	var head_yaw := diff if glance else sin(clock * .49) * .17
	var head_pitch := atan2(offset.y, Vector2(offset.x, offset.z).length()) if glance else -.04
	if activity == "sonar" and not aloud:
		head_pitch = -.36
	var motion := 0.0
	if aloud and not lip_motion.is_empty():
		var voice_at := voice.get_playback_position()
		var sample := clampi(floori(voice_at * 30.0), 0, lip_motion.size() - 1)
		motion = float(lip_motion[sample]) / 255.0
	var gesture: String = lines[speaking_id].gesture if aloud else ""
	model.pose(delta, clock, head_yaw, head_pitch, gesture, time_spoken if aloud else 0.0,
		motion, traveled, glide, activity if not aloud else "", stop_age)
