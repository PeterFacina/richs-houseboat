extends StaticBody3D

const Kit = preload("res://scenery.gd")
const Voice = preload("res://shannon_voice.gd")
const Routes = preload("res://mowing_routes.gd")
const Model = preload("res://shannon_model.gd")
const RoadGuide = preload("res://mowing_road_guide.gd")
const Works = preload("res://public_works.gd")
const TALK_DISTANCE := 2.8
const PAY := 20
const GUIDE_REFRESH := .18
const DESTINATION_ICON = preload("res://mowing_destination.svg")
const DESTINATION_GLOW = preload("res://mowing_destination_glow.svg")
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
	"See ya next shift.",
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
var waypoint: Node3D
var waypoint_distance: Label3D
var road_guide: RoadGuide
var target_tuft := -1
var target_origin := Vector3.INF
var guide_timer := 0.0
var cut_count := 0
var status := Status.AVAILABLE
var model := Model.new()
var speech_age := 0.0
var monitor_focus: Vector3
var reminder_index := 0
var encouragement := 0


func setup(game_world: Node3D, grass_owner: AnimatableBody3D, station: Vector3, heading: float, screen: Vector3) -> void:
	game = game_world
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
	road_guide = RoadGuide.new()
	game.add_child(road_guide)
	road_guide.setup(game.river)
	calendar = game.label("", 17, Color("#fff2c5"))
	calendar.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	calendar.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var top_right_hud := game.hud.get_node("top_right_hud") as Control
	top_right_hud.add_child(calendar)
	top_right_hud.move_child(calendar, 0)
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
	if is_instance_valid(waypoint):
		waypoint.queue_free()
	waypoint = null
	tuft_cells.clear()
	target_tuft = -1
	target_origin = Vector3.INF
	guide_timer = 0.0
	road_guide.reset()
	status = Status.AVAILABLE
	progress.hide()


func build_lawn(route: Dictionary) -> void:
	var grass: MultiMeshInstance3D = mower.grass
	if not is_instance_valid(grass):
		return
	markers = Node3D.new()
	markers.name = "JobLawnMarkers"
	game.add_child(markers)
	var ribbon := SurfaceTool.new()
	ribbon.begin(Mesh.PRIMITIVE_TRIANGLES)
	for lawn: PackedVector2Array in route.zones:
		var bounds := Routes.bounds(lawn)
		for edge in lawn.size():
			var start := lawn[edge]
			var finish := lawn[(edge + 1) % lawn.size()]
			var steps := maxi(1, ceili(start.distance_to(finish) / .65))
			var foot := on_ground(start) + Vector3.UP * .05
			for step in steps:
				var next := on_ground(start.lerp(finish, float(step + 1) / steps)) + Vector3.UP * .05
				ribbon_segment(ribbon, foot, next)
				foot = next
		for z in range(floori(bounds.position.y), ceili(bounds.end.y)):
			for x in range(floori(bounds.position.x), ceili(bounds.end.x)):
				var cell := Vector2i(x, z)
				for index: int in mower.grass_cells.get(cell, []):
					var at: Vector3 = mower.grass_point(index)
					var point := Vector2(at.x, at.z)
					if bounds.has_point(point) and Geometry2D.is_point_in_polygon(point, lawn):
						tuft_cells[index] = cell
	var boundary := MeshInstance3D.new()
	boundary.name = "TranslucentRouteBoundary"
	boundary.mesh = ribbon.commit()
	boundary.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var paint := StandardMaterial3D.new()
	paint.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	paint.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	paint.cull_mode = BaseMaterial3D.CULL_DISABLED
	paint.vertex_color_use_as_albedo = true
	boundary.material_override = paint
	markers.add_child(boundary)
	build_waypoint()


func build_waypoint() -> void:
	waypoint = Node3D.new()
	waypoint.name = "MowingDestination"
	game.add_child(waypoint)
	waypoint.hide()

	var glow := Sprite3D.new()
	glow.texture = DESTINATION_GLOW
	glow.axis = Vector3.AXIS_Y
	glow.pixel_size = .022
	glow.position.y = .19
	waypoint.add_child(glow)

	var pin := Sprite3D.new()
	pin.texture = DESTINATION_ICON
	pin.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	pin.fixed_size = true
	pin.pixel_size = .00135
	pin.offset.y = 29.0
	pin.position.y = 3.1
	waypoint.add_child(pin)

	waypoint_distance = Label3D.new()
	waypoint_distance.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	waypoint_distance.font_size = 26
	waypoint_distance.outline_size = 6
	waypoint_distance.pixel_size = pin.pixel_size
	waypoint_distance.fixed_size = true
	waypoint_distance.modulate = Color("#fff4dc")
	waypoint_distance.outline_modulate = Color("#422803")
	waypoint_distance.position.y = pin.position.y
	waypoint_distance.offset.y = -20.0
	waypoint.add_child(waypoint_distance)


func ribbon_segment(ribbon: SurfaceTool, start: Vector3, finish: Vector3) -> void:
	var top := Vector3.UP * .48
	for vertex: Vector3 in [start, finish, finish + top, start, finish + top, start + top]:
		var faded := vertex == finish + top or vertex == start + top
		ribbon.set_color(Color(.30, 1.0, .66, 0.0 if faded else .82))
		ribbon.add_vertex(vertex)


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
				return "E  Ask for a commercial route" if commercial_available() else "Today's route is finished. Next route opens at midnight."
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
			var paid: int = 0
			if is_same(job_state, game.campaign.ledger.state):
				paid = game.campaign.reward_mowing(job_day, PAY * (3 if commercial else 1), commercial)
			clear_job()
			if paid == 0:
				return
			game.notify_angling("Grass cutting  ·  +$%d" % paid, 4.0)
			voice.say(FINISH, distance)


func begin_job() -> void:
	mower.regrow_grass(tuft_cells.keys())
	cut_count = 0
	encouragement = 0
	status = Status.CUTTING
	markers.show()
	progress.show()
	update_navigation()
	game.notify_angling(route_name, 3.0)
	update_progress()


func grass_trimmed(index: int) -> void:
	if status != Status.CUTTING or not tuft_cells.has(index):
		return
	cut_count += 1
	if cut_count % 100 == 0:
		var campaign = game.campaign
		if campaign.XP.award(campaign.progression_for(campaign.crew.my_id()), "grass", "grass:%d:%d:%d" % [job_day, int(commercial), cut_count]) > 0:
			campaign.changed()
	if cut_count >= required_cuts():
		status = Status.RETURNING
		markers.hide()
	if index == target_tuft or status == Status.RETURNING:
		guide_timer = 0.0
	update_progress()


func next_uncut_tuft(origin: Vector3) -> int:
	var best := -1
	var distance := INF
	for index: int in tuft_cells:
		if mower.grass_cut[index]:
			continue
		var candidate: float = origin.distance_squared_to(mower.grass_point(index))
		if candidate < distance:
			best = index
			distance = candidate
	return best


func update_navigation() -> void:
	if not is_instance_valid(waypoint):
		return
	var active_mower: Node3D = game.mower
	var mounted: bool = active_mower.rider != null
	var origin: Vector3 = active_mower.to_global(active_mower.CUT_DECK) if mounted else game.player.global_position
	var returning := status == Status.RETURNING
	var bay := 0 if active_mower.shared_grass == null else 1
	var parking: Vector3 = game.public_works.at_ground(Works.PARKING[bay])
	var parked := not mounted and active_mower.global_position.distance_squared_to(parking) < 3.0 * 3.0
	var destination := global_position if parked else parking
	if not returning:
		if target_tuft < 0 or mower.grass_cut[target_tuft] \
				or (origin.distance_squared_to(target_origin) > 6.0 * 6.0 \
				and origin.distance_squared_to(mower.grass_point(target_tuft)) > 16.0 * 16.0):
			target_tuft = next_uncut_tuft(origin)
			target_origin = origin
		if target_tuft < 0:
			waypoint.hide()
			road_guide.reset()
			return
		destination = mower.grass_point(target_tuft)
	var meters := roundi(Vector2(destination.x - origin.x, destination.z - origin.z).length())
	waypoint.global_position = destination
	waypoint_distance.text = "%d m" % meters
	var clear: bool = not game.chart.visible and not game.fish_guide.visible and not game.campaign.controls_blocked()
	waypoint.visible = clear
	if not clear or not mounted or meters < 2:
		road_guide.reset()
	else:
		road_guide.navigate(origin, destination, game.public_works)


func required_cuts() -> int:
	var precision: float = game.campaign.skill_effect(game.campaign.crew.my_id(), "precision_cutting")
	return maxi(1, ceili(tuft_cells.size() * (1.0 - .01 * precision)))


func update_progress() -> void:
	if status == Status.RETURNING:
		progress.text = "JOB COMPLETE!\nPark the zero-turn, then return to Shannon"
	else:
		progress.text = "%s\nRoute progress: %d%%\nThen return to Shannon" % [route_name, floori(100.0 * cut_count / required_cuts())]
		if game.campaign.rank_for(game.campaign.crew.my_id(), "route_planner") > 0:
			progress.text += "\n%d cuts left" % (required_cuts() - cut_count)


func tick(delta: float, can_talk: bool) -> void:
	update_clock(delta)
	if status != Status.AVAILABLE and (game.campaign.crew.is_guest() or not is_same(job_state, game.campaign.ledger.state)):
		clear_job()
	guide_timer -= delta
	if guide_timer <= 0.0 and status in [Status.CUTTING, Status.RETURNING]:
		update_navigation()
		guide_timer = GUIDE_REFRESH
	if road_guide.visible:
		road_guide.update_paint(game.mower.to_global(game.mower.CUT_DECK))
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
