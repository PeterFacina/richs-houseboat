extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const Catalog = preload("res://fish_species.gd")
const Fish = preload("res://river_fish.gd")
const Marina = preload("res://marina_art.gd")
const Ledger = preload("res://game_ledger.gd")

var stove: Node3D
var lanterns: Array[OmniLight3D] = []
var fire: OmniLight3D
var live_coals: StandardMaterial3D
var griddle: Node3D
var speaker: AudioStreamPlayer3D
var notice: Label3D
var plate: Node3D
var food: Fish
var grill_sound: AudioStreamWAV
var turned := false
var cooking := false
var cook_until := 0.0
var course: Dictionary = {}
var servings := 0
var last_phase := ""
var transfer_until := 0.0
var cabin_photo: StandardMaterial3D


func build_at(river: Node3D, site: Dictionary) -> void:
	var position_offset: Vector3 = site.plot + site.right * 14.2 + site.forward * 1.25
	position_offset.y = river.ground_height(position_offset.x, position_offset.z)
	global_position = position_offset
	rotation.y = site.heading
	var boards := timber(Color("#976f50"))
	var fascia := timber(Color("#cbb28e"))
	var burnt := Kit.paint(Color("#473d30"), .93)
	var rock := Kit.paint(Color("#716d61"), .97)
	var steel := Kit.paint(Color("#454e4b"), .60, .31)
	var ash := Kit.paint(Color("#45372b"), .98)
	var roof := Kit.paint(Color("#454f51"), .74, .24)
	var mat := Kit.paint(Color("#b3a58a"), .86)
	var floor_height := .1
	for offset: Vector3 in [Vector3(-2.65, .0, -1.70), Vector3(2.65, 0, -1.70),
			Vector3(-2.65, 0, 1.7), Vector3(2.65, 0, 1.7)]:
		var world := to_global(offset)
		floor_height = maxf(floor_height, river.ground_height(world.x, world.z) - global_position.y + .14)
	var shelter := StaticBody3D.new()
	add_child(shelter)
	shelter.position = Vector3(0, floor_height, 1.74)
	Kit.collider(shelter, Vector3(0, -.062, 0), Vector3(5.75, .123, 3.48))
	for strip in 19:
		Kit.box_at(shelter, Vector3(0, -.067, (strip - 9) * .181),
			Vector3(5.75, .127, .177), boards if strip % 4 > 1 else fascia)
	for post_x: float in [-2.59, 2.59]:
		for post_z: float in [-1.48, 1.47]:
			var tip := 2.56 if post_z < 0.0 else 2.22
			Kit.box_at(shelter, Vector3(post_x, tip * .5 - .09, post_z), Vector3(.18, tip + .18, .18), boards)
			var foot := shelter.to_global(Vector3(post_x, -.10, post_z))
			var depth: float = maxf(.24, foot.y - river.ground_height(foot.x, foot.z) + .12)
			Kit.box_at(shelter, Vector3(post_x, -.12 - depth * .45, post_z), Vector3(.27, depth, .27), burnt)
			Kit.beam(shelter, Vector3(post_x, tip - .73, post_z),
				Vector3(post_x - signf(post_x) * .63, tip - .15, post_z), .104, fascia)
	for band in 8:
		var rail := Kit.box_at(shelter, Vector3(-2.61 + band * .75, 2.46, 0), Vector3(.750, .109, 3.81), roof)
		rail.rotation.x = .095
		Kit.box_at(rail, Vector3(-.366, .062, 0), Vector3(.024, .025, 3.81), steel)
	for edge: float in [-1.87, 1.87]:
		Kit.box_at(shelter, Vector3(0, 2.46 - edge * .095, edge), Vector3(6.02, .145, .104), fascia)
	for row in 12:
		Kit.box_at(shelter, Vector3(0, .11 + row * .147, 1.49), Vector3(5.16, .142, .104),
			boards if row % 2 == 0 else fascia)
	bunk(shelter, Vector3(-1.61, 0, .84), 1.52, boards, burnt)
	bunk(shelter, Vector3(.53, 0, .84), 1.52, boards, burnt)
	Kit.box_at(shelter, Vector3(1.83, .743, .45), Vector3(1.27, .075, .65), fascia)
	for x: float in [1.30, 2.36]:
		Kit.box_at(shelter, Vector3(x, .355, .46), Vector3(.13, .71, .54), boards)
	Kit.box_at(shelter, Vector3(0, 2.124, -1.43), Vector3(1.56, .41, .065), burnt)
	var nameplate := sign_label(shelter, "PINE REACH", Vector3(0, 2.20, -1.47), .0038, Color("#f2cd93"))
	nameplate.rotation.y = PI
	var motto := sign_label(shelter, "SHORE CAMP", Vector3(0, 2.045, -1.47), .0027, Color("#efdbc2"))
	motto.rotation.y = PI
	var board := Kit.box_at(shelter, Vector3(.0, 1.42, 1.42), Vector3(1.48, .88, .078), burnt)
	cabin_photo = Kit.paint(Color("#404f4f"), .85)
	Kit.box_at(board, Vector3(0, 0, -.049), Vector3(1.29, .73, .024), cabin_photo)
	lantern(shelter, Vector3(-2.52, 1.72, -.89), steel)
	lantern(shelter, Vector3(2.52, 1.72, -.89), steel)
	var trail_start: Vector3 = site.stand + site.right * 2.18
	var trail_end := to_global(Vector3(-3.18, 0, -3.84))
	for index in 3:
		var world := trail_start.lerp(trail_end, float(index) / 2.6)
		world.y = river.ground_height(world.x, world.z)
		var post := to_local(world)
		Kit.box_at(self, post + Vector3.UP * .57, Vector3(.105, 1.14, .105), boards)
		Kit.beam(self, post + Vector3.UP * 1.08, post + Vector3(.31, 1.08, 0), .058, boards)
		lantern(self, post + Vector3(.29, .89, 0), steel)
	var waymark := to_local(trail_start)
	waymark.y = river.ground_height(trail_start.x, trail_start.z) - global_position.y
	Kit.box_at(self, waymark + Vector3(0, 1.26, 0), Vector3(1.22, .256, .075), burnt)
	var direction := sign_label(self, "←  SHORE CAMP", waymark + Vector3(0, 1.26, -.043), .0028, Color("#f1ddae"))
	direction.rotation.y = PI
	var step := StaticBody3D.new()
	shelter.add_child(step)
	var entry := shelter.to_global(Vector3(0, 0, -2.17))
	var rise: float = maxf(.11, entry.y - river.ground_height(entry.x, entry.z))
	for index in clampi(ceili(rise / .16), 1, 6):
		var depth := maxf(.07, rise - index * .16)
		var at := Vector3(0, -rise + depth * .5, -1.81 - index * .234)
		Kit.box_at(step, at, Vector3(1.65, depth, .256), fascia)
		Kit.collider(step, at, Vector3(1.65, depth, .256))
	stove = Node3D.new()
	add_child(stove)
	stove.position = Vector3(-.51, 0, -3.37)
	stove.global_position.y = river.ground_height(stove.global_position.x, stove.global_position.z)
	var random := RandomNumberGenerator.new()
	random.seed = 82819
	for stone in 16:
		var angle := TAU * stone / 16.0
		var at := Vector3(cos(angle) * .67, .132, sin(angle) * .67)
		var boulder := Tools.shell(stove, at, Vector3(.292, random.randf_range(.22, .42), .297), rock)
		boulder.rotation = Vector3(random.randf_range(-.19, .20), angle, .12)
	var bed := CylinderMesh.new()
	bed.height = .051
	bed.top_radius = .641
	bed.bottom_radius = .62
	bed.radial_segments = 18
	Kit.mesh_at(stove, bed, Vector3(0, .067, 0), ash)
	live_coals = Kit.paint(Color("#652c1c"), .94)
	live_coals.emission_enabled = true
	live_coals.emission = Color("#ff5428")
	live_coals.emission_energy_multiplier = .28
	for ember in 21:
		var orbit := random.randf_range(0, TAU)
		var range := random.randf_range(.05, .49)
		Tools.shell(stove, Vector3(sin(orbit) * range, .15, cos(orbit) * range),
			Vector3(.17, random.randf_range(.049, .121), .151), live_coals)
	for split in 4:
		var pil := Kit.box_at(stove, Vector3(0, .15 + (split % 2) * .095, 0),
			Vector3(.81 - split * .073, .111, .122), burnt)
		pil.rotation.y = split * .88
	griddle = Node3D.new()
	stove.add_child(griddle)
	griddle.position.y = .526
	for x: float in [-.485, .485]:
		for z: float in [-.341, .341]:
			Tools.tube(griddle, Vector3(x, -.43, z), Vector3(x, -.013, z), .017, .022, steel)
	Kit.beam(griddle, Vector3(-.48, 0, -.34), Vector3(-.48, 0, .34), .019, steel)
	Kit.beam(griddle, Vector3(.48, 0, -.34), Vector3(.48, 0, .34), .019, steel)
	for grid in 13:
		var at := -.35 + grid * .058
		Kit.beam(griddle, Vector3(-.48, .0, at), Vector3(.48, .0, at), .016, steel)
	notice = sign_label(griddle, "", Vector3(0, .55, 0), .0039, Color("#ffe0ae"))
	notice.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	fire = OmniLight3D.new()
	fire.position.y = .24
	fire.light_color = Color("#ffad64")
	fire.omni_range = 8.3
	fire.light_energy = .74
	stove.add_child(fire)
	build_flames(stove)
	for bench_x: float in [-2.58, 1.66]:
		var seat := Node3D.new()
		add_child(seat)
		seat.position = stove.position + Vector3(bench_x, 0, .10)
		seat.global_position.y = river.ground_height(seat.global_position.x, seat.global_position.z)
		seat.rotation.y = PI / 2.0
		bunk(seat, Vector3.ZERO, 1.69, boards, burnt)
	plate = Node3D.new()
	griddle.add_child(plate)
	plate.position = Vector3(-.36, .055, .02)
	var tray := CylinderMesh.new()
	tray.height = .034
	tray.top_radius = .23
	tray.bottom_radius = .179
	tray.radial_segments = 22
	Kit.mesh_at(plate, tray, Vector3.ZERO, mat)
	plate.hide()
	speaker = AudioStreamPlayer3D.new()
	speaker.bus = &"Ambience"
	speaker.stream = crackle()
	speaker.max_distance = 18.0
	speaker.unit_size = 1.27
	speaker.volume_db = -25
	stove.add_child(speaker)
	speaker.play()
	grill_sound = sizzle()
	scatter_camp(river, random)
	load_photo()


func timber(color: Color) -> Material:
	var shade := ShaderMaterial.new()
	shade.shader = preload("res://boat_finish.gdshader")
	shade.set_shader_parameter("coat", color)
	shade.set_shader_parameter("timber", true)
	return shade


func bunk(parent: Node3D, at: Vector3, size: float, top: Material, foot: Material) -> void:
	Kit.box_at(parent, at + Vector3(0, .43, 0), Vector3(size, .14, .44), top)
	for x in [-.37, .37]:
		Kit.box_at(parent, at + Vector3(x * size, .18, 0), Vector3(.23, .36, .38), foot)


func sign_label(parent: Node3D, words: String, at: Vector3, pixel: float, color: Color) -> Label3D:
	var caption := Label3D.new()
	caption.text = words
	caption.modulate = color
	caption.pixel_size = pixel
	caption.font_size = 47
	caption.outline_size = 4
	parent.add_child(caption)
	caption.position = at
	return caption


func lantern(parent: Node3D, at: Vector3, steel: Material) -> void:
	Tools.tube(parent, at, at + Vector3.UP * .45, .011, .011, steel)
	Tools.tube(parent, at - Vector3.UP * .218, at - Vector3.UP * .183, .128, .123, steel)
	Tools.tube(parent, at + Vector3.UP * .012, at + Vector3.UP * .054, .131, .119, steel)
	var honey := Kit.paint(Color("#ffd5a3"), .26)
	honey.emission_enabled = true
	honey.emission = Color("#ffd0a0")
	honey.emission_energy_multiplier = .71
	Tools.tube(parent, at - Vector3.UP * .191, at + Vector3.UP * .014, .087, .088, honey)
	for index in 4:
		var point := at + Vector3(cos(index * PI / 2.0), 0, sin(index * PI / 2.0)) * .101
		Tools.tube(parent, point - Vector3.UP * .19, point + Vector3.UP * .018, .008, .008, steel)
	var pulse := OmniLight3D.new()
	pulse.position = at - Vector3.UP * .061
	pulse.light_color = Color("#ffd0a1")
	pulse.light_energy = .80
	pulse.omni_range = 9.8
	parent.add_child(pulse)
	lanterns.append(pulse)


func build_flames(parent: Node3D) -> void:
	var warm := ShaderMaterial.new()
	warm.shader = preload("res://camp_flame.gdshader")
	for angle: float in [0.0, 1.047, 2.094]:
		var plane := QuadMesh.new()
		plane.size = Vector2(.77, .68)
		var flare := Kit.mesh_at(parent, plane, Vector3(0, .457, 0), warm)
		flare.rotation.y = angle
		flare.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF


func scatter_camp(river: Node3D, random: RandomNumberGenerator) -> void:
	var tufts: Array[Transform3D] = []
	var stones: Array[Transform3D] = []
	for i in 162:
		var x := random.randf_range(-13.6, 17.3)
		var z := random.randf_range(-16.8, 12.1)
		if x < -6.0 and z > -5.1:
			continue
		if Vector2(x, z - 1.74).length() < 4.6 or Vector2(x + .51, z + 3.37).length() < 3.15:
			continue
		var pos := to_global(Vector3(x, 0, z))
		pos.y = river.ground_height(pos.x, pos.z)
		if pos.y > 3.9 or pos.y < -.085:
			continue
		var axis := Basis(Vector3.UP, random.randf_range(0.0, TAU))
		if i % 6 == 0:
			var width := random.randf_range(.37, 1.36)
			stones.append(Transform3D(axis.scaled_local(Vector3(width, width * .43, width * .87)), to_local(pos)))
		else:
			tufts.append(Transform3D(axis.scaled_local(Vector3(.82, random.randf_range(.34, .79), .86)), to_local(pos)))
	var mesh := SphereMesh.new()
	mesh.radial_segments = 10
	mesh.rings = 5
	if not stones.is_empty():
		Kit.new().scatter(self, mesh, stones, Kit.paint(Color("#706e62"), .97))
	if not tufts.is_empty():
		var grass := ShaderMaterial.new()
		grass.shader = preload("res://river_reeds.gdshader")
		Kit.new().scatter(self, Marina.new().reed_mesh(random), tufts, grass)


func instructions(_ledger: Ledger, clock: float) -> String:
	if not cooking:
		return "Take a fish out of the nearby ice chest, then E to place it on the grill"
	if clock < cook_until:
		return "Let it sizzle"
	return "E  Serve the fish" if turned else "E  Turn the fish"


func use(ledger: Ledger, clock: float) -> String:
	if not cooking:
		return "Take a fish out of the ice chest first."
	if clock < cook_until:
		return "Give that side a moment to brown."
	if not turned:
		turned = true
		cook_until = clock + 3.3
		return "Turned it over. The other side is browning."
	cooking = false
	servings += 1
	ledger.state.meals += 1
	return "%s served at Pine Reach. Meal %d for the crew." % [Catalog.profile(course.species).name, ledger.state.meals]


func animate(clock: float, dusk: float) -> void:
	for lantern_light in lanterns:
		var shimmer := 1.0 + sin(clock * 4.24) * .025 + sin(clock * 9.1) * .017
		lantern_light.light_energy = lerpf(.47, 1.42, dusk) * shimmer
	fire.light_energy = lerpf(.64, 1.6, dusk) * (1.0 + sin(clock * 7.1) * .10 + sin(clock * 12.2) * .06)
	var phase := "flip" if turned else "grill"
	if not cooking:
		phase = "served" if servings > 0 else ""
	if phase != last_phase:
		if not course.is_empty() and phase != "":
			if not is_instance_valid(food):
				food = Fish.new()
				griddle.add_child(food)
			food.select_species(int(course.species), clampi(int(course.length), 12, 45))
			food.show()
			if cooking:
				var sound := AudioStreamPlayer3D.new()
				sound.bus = &"Ambience"
				sound.stream = grill_sound
				sound.volume_db = -16
				sound.unit_size = 1.3
				sound.max_distance = 18
				griddle.add_child(sound)
				sound.finished.connect(sound.queue_free)
				sound.play()
		last_phase = phase
	if is_instance_valid(food) and phase != "":
		var elapsed := maxf(0, 3.3 - (cook_until - clock))
		var lift := .13 * sin(clampf(elapsed / .50, 0, 1) * PI) if turned and cooking else 0.0
		var at := griddle.to_global(Vector3(-.17, .045 + lift, -.10))
		food.visible = clock >= transfer_until
		food.pose(at, Vector3.RIGHT, PI * .5 + (PI * smoothstep(.0, .50, elapsed) if turned else 0.0), 0.0, 0.0)
	var plate_ready := phase == "served"
	plate.visible = plate_ready
	notice.text = "READY TO TURN" if cooking and not turned and clock >= cook_until else "READY TO SERVE" if cooking and turned and clock >= cook_until else ""


func pack() -> Dictionary:
	return {"cooking": cooking, "turned": turned, "until": cook_until, "fish": course, "servings": servings}


func unpack(data: Dictionary) -> void:
	cooking = data.cooking
	turned = data.turned
	cook_until = data.until
	course = data.fish
	servings = data.servings


func clear() -> void:
	cooking = false
	turned = false
	servings = 0
	course = {}
	last_phase = ""
	if is_instance_valid(food):
		food.hide()


func load_photo() -> void:
	var folder := "user://river_album"
	if not DirAccess.dir_exists_absolute(ProjectSettings.globalize_path(folder)):
		return
	var photos := DirAccess.get_files_at(folder)
	for index in range(photos.size() - 1, -1, -1):
		if photos[index].begins_with("River ") and photos[index].ends_with(".png"):
			var picture := Image.load_from_file(folder.path_join(photos[index]))
			if not picture.is_empty():
				picture.resize(640, 360, Image.INTERPOLATE_LANCZOS)
				cabin_photo.albedo_texture = ImageTexture.create_from_image(picture)
				cabin_photo.albedo_color = Color.WHITE
				return


func crackle() -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 6452
	var pcm := PackedByteArray()
	pcm.resize(88200)
	var filtered := 0.0
	var pop := 0.0
	for index in 44100:
		var noise := random.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, .15)
		pop *= .983
		if index % 191 == 0 and random.randf() > .66:
			pop = random.randf_range(.12, .57)
		pcm.encode_s16(index * 2, int((filtered * .21 + noise * pop) * 15200))
	return audio(pcm, true)


func sizzle() -> AudioStreamWAV:
	var random := RandomNumberGenerator.new()
	random.seed = 883
	var pcm := PackedByteArray()
	pcm.resize(35360)
	var filtered := 0.0
	for i in 17680:
		var noise := random.randf_range(-1.0, 1.0)
		filtered = lerpf(filtered, noise, .22)
		var volume := smoothstep(0.0, 900.0, i) * exp(-i / 4880.0)
		pcm.encode_s16(i * 2, int((noise - filtered) * volume * 9800))
	return audio(pcm, false)


func audio(pcm: PackedByteArray, repeat: bool) -> AudioStreamWAV:
	var sound := AudioStreamWAV.new()
	sound.format = AudioStreamWAV.FORMAT_16_BITS
	sound.mix_rate = 22050
	sound.data = pcm
	if repeat:
		sound.loop_mode = AudioStreamWAV.LOOP_FORWARD
		sound.loop_end = pcm.size() / 2
	return sound


func place_fish(fish: Dictionary, clock: float) -> bool:
	if cooking or fish.is_empty():
		return false
	course = fish.duplicate(true)
	cooking = true
	turned = false
	cook_until = clock + 3.5
	return true
