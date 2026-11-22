extends StaticBody3D

const Kit = preload("res://scenery.gd")
const Voice = preload("res://shannon_voice.gd")
const Marina = preload("res://marina_art.gd")
const STAND_OFFSET := Vector2(4.8, 9)
const TALK_DISTANCE := 2.8
const OPENING: Array[String] = [
	"Since Josh left, I've been stuck with these",
	"dipshits.",
	"Look at this!",
]
const GREETING: Array[String] = [
	"How's she goin', bud?",
	"Jesus Murphy, look at the state of this lawn.",
	"You lookin' for a bit of work or what?",
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
	"There's yer five bucks. Don't spend it all in one place.",
]

enum Status { AVAILABLE, CUTTING, RETURNING }

var game: Node3D
var mower: AnimatableBody3D
var voice := Voice.new()
var name_tag: Label3D
var progress: Label
var markers: Node3D
var tuft_cells: Dictionary = {}
var guides: Dictionary = {}
var guide_paint := Kit.paint(Color("#f1c454"))
var guides_dirty := false
var cut_count := 0
var status := Status.AVAILABLE
var greeted := false
var introduced := false
var encouragement := 0


func setup(fishing_game: Node3D) -> void:
	game = fishing_game
	mower = game.mower
	name = "Shannon"
	var park: Array = game.river.meta.marina.pavilion
	var origin := Vector2(park[0], park[1])
	global_position = on_ground(origin + STAND_OFFSET)
	rotation.y = -PI * .5
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
	progress.offset_top = 106
	progress.hide()
	build_lawn(origin)
	mower.grass_trimmed.connect(grass_trimmed)


func on_ground(at: Vector2) -> Vector3:
	return Vector3(at.x, game.river.ground_height(at.x, at.y), at.y)


func build_model() -> void:
	var skin := Kit.paint(Color("#d6a18b"))
	var red := Kit.paint(Color("#a92928"))
	var flannel := Kit.paint(Color("#777254"))
	var denim := Kit.paint(Color("#344958"))
	var leather := Kit.paint(Color("#3c342d"))
	var hair := Kit.paint(Color("#978879"))
	Kit.box_at(self, Vector3(0, 1.05, 0), Vector3(.65, .69, .46), flannel)
	Kit.box_at(self, Vector3(0, .77, .02), Vector3(.54, .21, .38), denim)
	Kit.box_at(self, Vector3(0, 1.43, -.027), Vector3(.23, .27, .23), skin)
	Kit.box_at(self, Vector3(0, 1.58, -.025), Vector3(.30, .31, .28), skin)
	Kit.box_at(self, Vector3(0, 1.72, -.021), Vector3(.33, .126, .31), red)
	Kit.box_at(self, Vector3(0, 1.68, -.20), Vector3(.317, .036, .13), red)
	Kit.box_at(self, Vector3(0, 1.695, -.177), Vector3(.072, .043, .008), Kit.paint(Color("#ded1ae")))
	Kit.box_at(self, Vector3(0, 1.53, -.169), Vector3(.12, .031, .018), hair)
	for side: float in [-1.0, 1.0]:
		Kit.box_at(self, Vector3(side * .15, .41, .028), Vector3(.22, .68, .29), denim)
		Kit.box_at(self, Vector3(side * .15, .095, -.039), Vector3(.23, .19, .39), leather)
		Kit.box_at(self, Vector3(side * .371, 1.18, -.012), Vector3(.177, .31, .23), flannel)
		Kit.box_at(self, Vector3(side * .383, .94, -.027), Vector3(.142, .27, .155), skin)
		Kit.box_at(self, Vector3(side * .065, 1.605, -.167), Vector3(.034, .018, .008), leather)
	Kit.collider(self, Vector3(0, .83, 0), Vector3(.60, 1.61, .44))
	name_tag = Label3D.new()
	name_tag.text = "Shannon"
	name_tag.position.y = 2.01
	name_tag.font_size = 29
	name_tag.pixel_size = .0038
	name_tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	name_tag.hide()
	add_child(name_tag)


func build_lawn(origin: Vector2) -> void:
	var grass: MultiMeshInstance3D = mower.grass
	if not is_instance_valid(grass):
		return
	var instances := grass.multimesh
	markers = Node3D.new()
	markers.name = "JobLawnMarkers"
	game.add_child(markers)
	var lawn := PackedVector2Array(Marina.MOWING_LAWN)
	var bounds := Marina.mowing_lawn_bounds()
	var orange := Kit.paint(Color("#de913b"), .53)
	var wood := Kit.paint(Color("#635140"))
	for edge in lawn.size():
		var start := lawn[edge]
		var finish := lawn[(edge + 1) % lawn.size()]
		var steps := maxi(1, ceili(start.distance_to(finish) / 5.0))
		for step in steps:
			var foot := on_ground(origin + start.lerp(finish, float(step) / steps))
			Kit.box_at(markers, foot + Vector3.UP * .22, Vector3(.065, .44, .065), wood)
			Kit.box_at(markers, foot + Vector3.UP * .40, Vector3(.16, .12, .065), orange)
	for index in instances.instance_count:
		var at := grass.to_global(instances.get_instance_transform(index).origin)
		var point := Vector2(at.x, at.z) - origin
		if not bounds.has_point(point) or not Geometry2D.is_point_in_polygon(point, lawn):
			continue
		var relative := point - bounds.position
		tuft_cells[index] = Vector2i(floori(relative.x), floori(relative.y))
	markers.hide()


func in_range() -> bool:
	return game.player.global_position.distance_squared_to(global_position) <= TALK_DISTANCE * TALK_DISTANCE


func prompt() -> String:
	match status:
		Status.CUTTING: return "E  Talk to Shannon"
		Status.RETURNING: return "E  Collect $5 from Shannon"
		_: return "E  Talk to Shannon about mowing"


func interact() -> void:
	if game.campaign.crew.is_guest():
		game.notify_angling("Shannon's mowing job is available to the host.", 3.5)
		return
	greeted = true
	var distance: float = game.player.global_position.distance_to(global_position)
	match status:
		Status.AVAILABLE:
			if tuft_cells.is_empty():
				return
			begin_job()
			if introduced:
				voice.say(START, distance)
			else:
				voice.say(START, distance, OPENING)
			introduced = true
		Status.CUTTING:
			var reminder: Array[String] = [WORK[0]]
			voice.say(reminder, distance)
		Status.RETURNING:
			status = Status.AVAILABLE
			progress.hide()
			markers.hide()
			game.campaign.reward_mowing()
			game.notify_angling("Grass cutting  ·  +$5", 4.0)
			voice.say(FINISH, distance)


func begin_job() -> void:
	for marker: Node3D in guides.values():
		marker.queue_free()
	guides.clear()
	guides_dirty = false
	mower.regrow_grass(tuft_cells.keys())
	cut_count = 0
	encouragement = 0
	status = Status.CUTTING
	markers.show()
	progress.show()
	update_progress()


func grass_trimmed(index: int) -> void:
	if status != Status.CUTTING or not tuft_cells.has(index):
		return
	cut_count += 1
	if cut_count == tuft_cells.size():
		status = Status.RETURNING
	guides_dirty = cut_count * 100 >= tuft_cells.size() * 80
	update_progress()


func update_guides() -> void:
	guides_dirty = false
	var grass: MultiMeshInstance3D = mower.grass
	var remaining_positions := {}
	for index: int in tuft_cells:
		var cell: Vector2i = tuft_cells[index]
		if not mower.grass_cut[index] and not remaining_positions.has(cell):
			remaining_positions[cell] = grass.to_global(grass.multimesh.get_instance_transform(index).origin)
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
		progress.text = "JOB COMPLETE!\nGrass Cut: 100%  ·  Return to Shannon"
	else:
		progress.text = "Grass Cut: %d%%" % floori(100.0 * cut_count / tuft_cells.size())


func tick(delta: float, can_talk: bool) -> void:
	if guides_dirty:
		update_guides()
	var distance: float = game.player.global_position.distance_to(global_position)
	name_tag.visible = distance < 14.0
	progress.visible = status != Status.AVAILABLE and not game.chart.visible and not game.fish_guide.visible \
		and not game.campaign.controls_blocked()
	var mowing: bool = mower.rider != null and status == Status.CUTTING
	voice.advance(delta, distance, 18.0 if mowing else 9.0)
	if distance > 10.0:
		greeted = false
	if can_talk and introduced and distance < 3.25 and not greeted and status == Status.AVAILABLE:
		greeted = true
		voice.say(GREETING, distance)
	if mowing and distance < 18.0 and not voice.active and encouragement < WORK.size():
		var threshold := .24 if encouragement == 0 else .68
		if cut_count >= tuft_cells.size() * threshold:
			var line: Array[String] = [WORK[encouragement]]
			voice.say(line, distance)
			encouragement += 1
