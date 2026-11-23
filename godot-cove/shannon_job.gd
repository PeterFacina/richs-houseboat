extends StaticBody3D

const Kit = preload("res://scenery.gd")
const Voice = preload("res://shannon_voice.gd")
const Routes = preload("res://mowing_routes.gd")
const Model = preload("res://shannon_model.gd")
const TALK_DISTANCE := 2.8
const PAY := 20
const OFFER: Array[String] = ["Do you want this job today, lil man?"]
const REMINDERS: Array[String] = [
	"We gonna put you into the ringer, son.",
	"These kids couldn't tell a mower from their cock.",
	"You better not be caught dogfuckin' by no townies.",
]
const START: Array[String] = [
	"Alright, fire that bastard up and give 'er.",
]
const WORK: Array[String] = [
	"Don't be leavin' patches everywhere, fer Christ's sake.",
	"Atta boy! Now yer gettin' somewhere!",
]
const FINISH: Array[String] = [
	"Well, shit. Ya actually did a decent job.",
	"There's yer seventy-five bucks. See ya next shift.",
]

enum Status { AVAILABLE, CUTTING, RETURNING, OFFERED }

var game: Node3D
var mower: AnimatableBody3D
var voice := Voice.new()
var name_tag: Label3D
var progress: Label
var calendar: Label
var route_name := ""
var commercial := false
var job_day := -1
var job_state: Dictionary
var markers: Node3D
var tuft_cells: Dictionary = {}
var guides: Dictionary = {}
var guide_paint := Kit.paint(Color("#68db87"))
var guides_dirty := false
var cut_count := 0
var status := Status.AVAILABLE
var model := Model.new()
var speech_age := 0.0
var monitor_focus: Vector3
var reminder_index := 0
var encouragement := 0


func setup(fishing_game: Node3D, grass_owner: AnimatableBody3D, station: Vector3, heading: float, screen: Vector3) -> void:
	game = fishing_game
	mower = grass_owner
	name = "ShannonLarping"
	monitor_focus = screen
	global_position = station
	rotation.y = heading - .92
	build_model()
	add_child(voice)
	voice.setup(game.hud)
	progress = game.label("", 18, Color("#fff2c5"))
	progress.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	progress.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(progress)
	progress.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	progress.offset_left = -380
	progress.offset_right = -28
	progress.offset_top = 245
	progress.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	progress.hide()
	calendar = game.label("", 17, Color("#fff2c5"))
	calendar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	calendar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	game.hud.add_child(calendar)
	calendar.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	calendar.offset_left = -250
	calendar.offset_right = -26
	calendar.offset_top = 77
	mower.grass_trimmed.connect(grass_trimmed)
	update_clock(0.0)


func on_ground(at: Vector2) -> Vector3:
	return Vector3(at.x, game.river.ground_height(at.x, at.y), at.y)


func build_model() -> void:
	add_child(model)
	model.build(true)
	Kit.collider(self, Vector3(0, .65, .08), Vector3(.57, 1.29, .57))
	name_tag = Label3D.new()
	name_tag.text = Voice.SPEAKER
	name_tag.position.y = 1.68
	name_tag.font_size = 29
	name_tag.pixel_size = .0038
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.hide()
	add_child(name_tag)
	model.pose_at_desk(1.0, 0.0, -.61, -.08, false, 0.0, 0.0)


func current_day() -> int:
	return floori(float(game.campaign.ledger.state.work_minutes) / Routes.MINUTES_PER_DAY)


func update_clock(delta: float) -> void:
	var state: Dictionary = game.campaign.ledger.state
	state.work_minutes += delta * Routes.MINUTES_PER_SECOND
	var today := current_day()
	var minute := posmod(floori(state.work_minutes), Routes.MINUTES_PER_DAY)
	calendar.text = "%s  %02d:%02d" % [Routes.DAYS[today % Routes.DAYS.size()], floori(minute / 60.0), minute % 60]
	calendar.visible = not game.chart.visible and not game.fish_guide.visible \
		and not game.sonar_overlay.visible and not game.campaign.controls_blocked()


func clear_job() -> void:
	if is_instance_valid(markers):
		markers.queue_free()
	markers = null
	tuft_cells.clear()
	guides.clear()
	guides_dirty = false
	status = Status.AVAILABLE
	progress.hide()


func build_lawn(route: Dictionary) -> void:
	var grass: MultiMeshInstance3D = mower.grass
	if not is_instance_valid(grass):
		return
	markers = Node3D.new()
	markers.name = "JobLawnMarkers"
	game.add_child(markers)
	var green := Kit.paint(Color("#65ce78"), .53)
	var wood := Kit.paint(Color("#635140"))
	for lawn: PackedVector2Array in route.zones:
		var bounds := Routes.bounds(lawn)
		for edge in lawn.size():
			var start := lawn[edge]
			var finish := lawn[(edge + 1) % lawn.size()]
			var steps := maxi(1, ceili(start.distance_to(finish) / 5.0))
			for step in steps:
				var foot := on_ground(start.lerp(finish, float(step) / steps))
				Kit.box_at(markers, foot + Vector3.UP * .22, Vector3(.065, .44, .065), wood)
				Kit.box_at(markers, foot + Vector3.UP * .40, Vector3(.16, .12, .065), green)
		for index in mower.grass_transforms.size():
			var at: Vector3 = mower.grass_point(index)
			var point := Vector2(at.x, at.z)
			if bounds.has_point(point) and Geometry2D.is_point_in_polygon(point, lawn):
				tuft_cells[index] = Vector2i(floori(point.x), floori(point.y))
		var destination := Label3D.new()
		destination.text = route_name
		destination.billboard = BaseMaterial3D.BILLBOARD_ENABLED
		destination.no_depth_test = true
		destination.font_size = 30
		destination.outline_size = 5
		destination.pixel_size = .00115
		destination.fixed_size = true
		destination.modulate = Color("#7beb9b")
		destination.outline_modulate = Color("#163321")
		markers.add_child(destination)
		destination.position = on_ground(bounds.get_center()) + Vector3.UP * 2.5


func in_range() -> bool:
	return game.player.global_position.distance_squared_to(global_position) <= TALK_DISTANCE * TALK_DISTANCE


func commercial_available() -> bool:
	var campaign = game.campaign
	return campaign.rank_for(campaign.crew.my_id(), "commercial_contractor") > 0 and int(campaign.ledger.state.last_commercial_day) != current_day()


func prompt() -> String:
	match status:
		Status.CUTTING: return "E  Talk to " + Voice.SPEAKER
		Status.RETURNING: return "E  Collect $%d from %s" % [game.campaign.mowing_pay(PAY * (3 if commercial else 1)), Voice.SPEAKER]
		Status.OFFERED: return "E  Accept today's mowing route"
		_:
			if int(game.campaign.ledger.state.last_mowing_day) == current_day():
				return "E  Ask for a commercial route" if commercial_available() else "Today's mowing route is finished"
			return "E  Ask %s for today's mowing route" % Voice.SPEAKER


func interact() -> void:
	if game.campaign.crew.is_guest():
		game.notify_angling("Shannon's mowing job is available to the host.", 3.5)
		return
	speech_age = 0.0
	var distance: float = game.player.global_position.distance_to(global_position)
	match status:
		Status.AVAILABLE:
			commercial = int(game.campaign.ledger.state.last_mowing_day) == current_day()
			if commercial and not commercial_available():
				game.notify_angling("The next mowing route opens at midnight.", 4.0)
				return
			job_day = current_day()
			job_state = game.campaign.ledger.state
			status = Status.OFFERED
			voice.say(OFFER, distance)
		Status.OFFERED:
			if current_day() != job_day or not is_same(job_state, game.campaign.ledger.state):
				clear_job()
				interact()
				return
			var route: Dictionary = game.river.waterfront.mowing_routes[job_day % Routes.DAYS.size()]
			if commercial:
				route = route.duplicate(true)
				route.zones.append_array(game.river.waterfront.mowing_routes[(job_day + 1) % Routes.DAYS.size()].zones)
				route.name = "Commercial • " + str(route.name)
			route_name = route.name
			build_lawn(route)
			if tuft_cells.is_empty():
				clear_job()
				game.notify_angling("No mowable grass was found on today's route.", 4.0)
				return
			begin_job()
			reminder_index = 0
			voice.say(START, distance)
		Status.CUTTING:
			var reminder: Array[String] = [REMINDERS[reminder_index]]
			reminder_index = (reminder_index + 1) % REMINDERS.size()
			voice.say(reminder, distance)
		Status.RETURNING:
			if commercial:
				job_state.last_commercial_day = job_day
			else:
				job_state.last_mowing_day = job_day
			clear_job()
			var paid: int = game.campaign.reward_mowing(PAY * (3 if commercial else 1), commercial)
			game.notify_angling("Grass cutting  ·  +$%d" % paid, 4.0)
			voice.say(FINISH, distance)


func begin_job() -> void:
	mower.regrow_grass(tuft_cells.keys())
	cut_count = 0
	encouragement = 0
	status = Status.CUTTING
	markers.show()
	progress.show()
	game.notify_angling("%s: %s. Follow the route marker." % [Routes.DAYS[job_day % Routes.DAYS.size()], route_name], 5.0)
	update_progress()


func grass_trimmed(index: int) -> void:
	if status != Status.CUTTING or not tuft_cells.has(index):
		return
	cut_count += 1
	if cut_count % 100 == 0:
		var campaign = game.campaign
		if campaign.XP.award(campaign.progression_for(campaign.crew.my_id()), "grass", "grass:%d:%d:%d" % [job_day, int(commercial), cut_count]) > 0:
			campaign.changed()
	var precision: float = game.campaign.skill_effect(game.campaign.crew.my_id(), "precision_cutting")
	if cut_count >= ceili(tuft_cells.size() * (1.0 - .01 * precision)):
		status = Status.RETURNING
		markers.hide()
	guides_dirty = cut_count * 100 >= tuft_cells.size() * 80 or game.campaign.rank_for(game.campaign.crew.my_id(), "route_planner") > 0
	update_progress()


func update_guides() -> void:
	guides_dirty = false
	var remaining_positions := {}
	for index: int in tuft_cells:
		var cell: Vector2i = tuft_cells[index]
		if not mower.grass_cut[index] and not remaining_positions.has(cell):
			remaining_positions[cell] = mower.grass_point(index)
	for cell: Vector2i in guides.keys():
		if not remaining_positions.has(cell):
			guides[cell].queue_free()
			guides.erase(cell)
	for cell: Vector2i in remaining_positions:
		var point: Vector3 = remaining_positions[cell] + Vector3.UP * .39
		if not guides.has(cell):
			guides[cell] = Kit.box_at(markers, point, Vector3(.065, .19, .065), guide_paint)
		else:
			guides[cell].position = point


func update_progress() -> void:
	if status == Status.RETURNING:
		progress.text = "JOB COMPLETE!\nRoute requirement met  ·  Return to Shannon Larping"
	else:
		progress.text = "%s\n✓ Route accepted   •   Cut grass: %d%%\nThen return to Shannon" % [route_name, floori(100.0 * cut_count / tuft_cells.size())]


func tick(delta: float, can_talk: bool) -> void:
	update_clock(delta)
	if status != Status.AVAILABLE and (game.campaign.crew.is_guest() or not is_same(job_state, game.campaign.ledger.state)):
		clear_job()
	if guides_dirty:
		update_guides()
	var distance: float = game.player.global_position.distance_to(global_position)
	name_tag.visible = distance < 14.0
	progress.visible = status in [Status.CUTTING, Status.RETURNING] and not game.chart.visible and not game.fish_guide.visible \
		and not game.campaign.controls_blocked()
	var mowing: bool = game.mower.rider != null and status == Status.CUTTING
	voice.advance(delta, distance, 18.0 if mowing else 9.0)
	if distance > 8.0 and status == Status.OFFERED:
		clear_job()
	if distance < 22.0:
		speech_age += delta
		var looking_at_player := can_talk and distance < TALK_DISTANCE and voice.active
		var gaze := to_local(game.eye.global_position if looking_at_player else monitor_focus) - Vector3.UP * 1.28
		var look_yaw := atan2(gaze.x, gaze.z)
		var mouth := (.35 + .30 * sin(speech_age * 18.0) + .18 * sin(speech_age * 29.0)) if voice.active else 0.0
		model.pose_at_desk(delta, game.clock, look_yaw, atan2(gaze.y, Vector2(gaze.x, gaze.z).length()),
			looking_at_player, speech_age, mouth)
	if mowing and distance < 18.0 and not voice.active and encouragement < WORK.size():
		var threshold := .24 if encouragement == 0 else .68
		if cut_count >= tuft_cells.size() * threshold:
			var line: Array[String] = [WORK[encouragement]]
			voice.say(line, distance)
			encouragement += 1
