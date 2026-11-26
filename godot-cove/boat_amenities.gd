extends Node3D

const Kit = preload("res://scenery.gd")
const Tools = preload("res://crew_tools.gd")
const BED := Vector3(-.84, 1.35, 5.88)
const TOILET := Vector3(.96, .35, 5.69)
const TV := Vector3(1.25, 1.91, 3.42)
const EXIT := Vector3(.01, .82, 3.45)
const LOOP_SECONDS := 90.0
const CLIP := "res://deep_river/tv/licensed_clip.ogv"
const CLIP_AUDIO := "res://deep_river/tv/licensed_clip.ogg"

var game: Node3D
var campaign: Node3D
var boat: Node3D
var occupants: Dictionary = {}
var tv_on := false
var tv_epoch := 0.0
var sound_serial := 0
var last_sound := -1
var next_flush := 0.0
var local_seat := ""
var focus_kind := ""
var saved_mask := 1
var television: SubViewport
var television_label: Label
var television_progress: ColorRect
var television_audio: AudioStreamPlayer3D
var video: VideoStreamPlayer
var hint: Label
var lamp: OmniLight3D
var sound_bank: Array[AudioStreamWAV] = []
var last_video_sync := -10.0


func setup(scene: Node3D, trip: Node3D) -> void:
	game = scene
	campaign = trip
	boat = campaign.houseboat
	name = "BoatAmenities"
	build_rooms()
	build_tv()
	for index in 20:
		sound_bank.append(make_sound(index))
	hint = Label.new()
	hint.add_theme_font_size_override("font_size", 18)
	hint.add_theme_color_override("font_color", Color("#fff1cc"))
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	game.hud.add_child(hint)
	hint.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_WIDE)
	hint.offset_top = -132
	hint.offset_bottom = -102
	hint.hide()


func solid(at: Vector3, size: Vector3, material: Material) -> void:
	Kit.box_at(boat, at, size, material)
	Kit.collider(boat, at, size)


func build_rooms() -> void:
	var wood: Material = boat.finish(Color("#9b8162"), .88, true)
	var cream: Material = boat.finish(Color("#d7d2bc"), .91)
	var dark := Kit.paint(Color("#34474b"), .76)
	var cloth := Kit.paint(Color("#4e7773"), .97)
	var porcelain := Kit.paint(Color("#e3e6dd"), .38)
	var steel := Kit.paint(Color("#a0aaa5"), .52, .35)
	if not boat.restoration_design:
		build_aft_shell(wood, cream, dark)
	build_aft_furniture(wood, cream, dark, cloth, porcelain, steel)


func build_aft_shell(wood: Material, cream: Material, dark: Material) -> void:
	solid(Vector3(0, .69, 4.64), Vector3(2.82, .12, 3.92), wood)
	for index in 19:
		Kit.box_at(boat, Vector3(0, .755, 2.83 + index * .2), Vector3(2.79, .012, .194), wood)
	for side in [-1.0, 1.0]:
		solid(Vector3(side * 1.35, 1.05, 4.63), Vector3(.12, .60, 3.94), dark)
		solid(Vector3(side * 1.35, 2.47, 4.63), Vector3(.12, .25, 3.94), cream)
		for z in [2.78, 3.7, 4.66, 5.61, 6.54]:
			solid(Vector3(side * 1.35, 1.85, z), Vector3(.12, 1.05, .075), cream)
		var glass := Kit.paint(Color(.39, .58, .61, .24), .24)
		glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		glass.cull_mode = BaseMaterial3D.CULL_DISABLED
		for z in [3.22, 4.18, 5.13, 6.08]:
			Kit.box_at(boat, Vector3(side * 1.35, 1.85, z), Vector3(.018, 1.04, .84), glass)
		# Continuous window collision keeps jumping players inside the cabin.
		Kit.collider(boat, Vector3(side * 1.35, 1.85, 4.65), Vector3(.10, 1.08, 3.94))
		var pontoon := CylinderMesh.new()
		pontoon.top_radius = .34
		pontoon.bottom_radius = .34
		pontoon.height = 3.4
		Kit.mesh_at(boat, pontoon, Vector3(side * .78, .14, 4.7), dark).rotation.x = PI * .5
	solid(Vector3(0, 1.66, 6.56), Vector3(2.82, 1.82, .12), cream)
	solid(Vector3(0, 2.64, 4.65), Vector3(2.96, .16, 4.04), cream)


func build_aft_furniture(wood: Material, cream: Material, dark: Material,
		cloth: Material, porcelain: Material, steel: Material) -> void:
	# Bathroom partition leaves a 0.95 m passage beside the berth.
	solid(Vector3(.50, 1.62, 5.37), Vector3(.075, 1.74, 2.29), cream)
	Kit.box_at(boat, Vector3(.91, .769, 5.36), Vector3(.77, .025, 2.28), dark)
	Kit.box_at(boat, Vector3(-.85, .95, 4.92), Vector3(.76, .36, 2.0), dark)
	solid(Vector3(-.85, 1.12, 4.92), Vector3(.76, .18, 2.0), cloth)
	Tools.shell(boat, Vector3(-.85, 1.24, 4.24), Vector3(.64, .13, .36), cream)
	for z in [4.65, 4.88, 5.11, 5.34, 5.57]:
		Kit.box_at(boat, Vector3(-.85, 1.22, z), Vector3(.77, .025, .025), dark)
	solid(Vector3(-1.04, 1.14, 3.22), Vector3(.48, .76, .62), wood)
	Kit.box_at(boat, Vector3(-1.04, 1.54, 3.22), Vector3(.52, .04, .65), cream)
	Tools.shell(boat, Vector3(.96, .99, 5.83), Vector3(.32, .46, .38), porcelain)
	Kit.collider(boat, Vector3(.96, .99, 5.83), Vector3(.40, .46, .42))
	Tools.shell(boat, Vector3(.96, 1.18, 5.66), Vector3(.45, .22, .59), porcelain)
	var seat := TorusMesh.new()
	seat.inner_radius = .12
	seat.outer_radius = .22
	Kit.mesh_at(boat, seat, Vector3(.96, 1.28, 5.66), cream).scale.z = 1.22
	Kit.box_at(boat, Vector3(.96, 1.43, 6.09), Vector3(.47, .46, .20), porcelain)
	Kit.box_at(boat, Vector3(.96, 1.68, 6.09), Vector3(.49, .04, .23), cream)
	Kit.box_at(boat, Vector3(.75, 1.59, 5.96), Vector3(.08, .03, .035), steel)
	Tools.tube(boat, Vector3(1.27, 1.53, 5.22), Vector3(1.20, 1.53, 5.22), .035, .035, cream)
	for text_at: Array in [["BEDROOM", Vector3(-.78, 2.37, 3.87)], ["BATHROOM", Vector3(.91, 2.37, 4.19)]]:
		var sign := Label3D.new()
		sign.text = text_at[0]
		sign.position = text_at[1]
		sign.rotation.y = PI
		sign.font_size = 24
		sign.pixel_size = .0014
		boat.add_child(sign)
	lamp = OmniLight3D.new()
	boat.add_child(lamp)
	lamp.position = Vector3(0, 2.37, 4.7)
	lamp.light_color = Color("#ffe7bd")
	lamp.light_energy = .55
	lamp.omni_range = 3.8
	Kit.box_at(boat, Vector3(0, 2.54, 4.7), Vector3(.45, .035, .20), porcelain)


func build_tv() -> void:
	television = SubViewport.new()
	television.size = Vector2i(640, 360)
	television.disable_3d = true
	television.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	add_child(television)
	var background := ColorRect.new()
	background.color = Color("#102c3c")
	background.size = television.size
	television.add_child(background)
	television_label = Label.new()
	television_label.position = Vector2(28, 40)
	television_label.size = Vector2(584, 280)
	television_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	television_label.add_theme_font_size_override("font_size", 28)
	television.add_child(television_label)
	television_progress = ColorRect.new()
	television_progress.color = Color("#d59c57")
	television_progress.position = Vector2(24, 330)
	television_progress.size = Vector2(592, 6)
	television.add_child(television_progress)
	video = VideoStreamPlayer.new()
	video.size = television.size
	video.volume = 0
	video.loop = true
	television.add_child(video)
	if ResourceLoader.exists(CLIP):
		video.stream = load(CLIP)
		television_label.hide()
	video.visible = video.stream != null
	var screen := QuadMesh.new()
	screen.size = Vector2(.94, .53)
	var material := StandardMaterial3D.new()
	material.albedo_texture = television.get_texture()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	var display := Kit.mesh_at(boat, screen, TV, material)
	display.rotation.y = -PI * .5
	Kit.box_at(boat, TV + Vector3(.035, 0, 0), Vector3(.055, .60, 1.02), Kit.paint(Color("#111a20"), .6))
	television_audio = AudioStreamPlayer3D.new()
	boat.add_child(television_audio)
	television_audio.position = TV
	television_audio.max_distance = 11
	television_audio.unit_size = 1.5
	television_audio.volume_db = -15
	if ResourceLoader.exists(CLIP_AUDIO):
		television_audio.stream = load(CLIP_AUDIO)
	else:
		television_audio.stream = make_sound(21)
	television_audio.finished.connect(func():
		if tv_on: television_audio.play())


func seat_kind(peer: int) -> String:
	return str(occupants.get(peer, ""))


func seated() -> bool:
	return not seat_kind(campaign.crew.my_id()).is_empty()


func target(kind: String) -> Vector3:
	return boat.to_global(Vector3(-.84, 1.2, 4.92) if kind == "bed" else Vector3(.96, 1.3, 5.65) if kind == "toilet" else TV)


func focused_action() -> String:
	if seated():
		return "exit"
	if game.vessel != boat or game.driving or game.cabin.busy() or campaign.crewplay.hands_busy():
		return ""
	for kind in ["bed", "toilet", "tv"]:
		if campaign.aiming(target(kind), 2.1, .90):
			return "occupied" if occupants.values().has(kind) else kind
	return ""


func action_label(kind: String) -> String:
	match kind:
		"exit": return "Get up"
		"bed": return "Lie down"
		"toilet": return "Sit"
		"tv": return "Turn television " + ("off" if tv_on else "on")
	return ""


func interact() -> bool:
	var kind := focused_action()
	if kind.is_empty():
		return false
	if kind == "exit":
		escape()
	elif kind != "occupied":
		campaign.request("amenity_use", kind)
	return true


func input(event: InputEvent) -> bool:
	if seated() and event is InputEventKey and event.pressed and not event.echo and game.play_input():
		if (event.physical_keycode == KEY_SPACE or event.is_action_pressed(&"interact")):
			escape()
			return true
		if event.physical_keycode == KEY_F and seat_kind(campaign.crew.my_id()) == "toilet":
			campaign.request("amenity_flush", null)
			return true
	return false


func escape() -> void:
	if seated():
		campaign.request("amenity_leave", null)
		# Leaving one's own seat is always permitted; release locally at once.
		occupants.erase(campaign.crew.my_id())
		apply_local_seat()


func act(peer: int, action: String, value: Variant) -> void:
	if action == "amenity_leave":
		occupants.erase(peer)
		publish()
		return
	if action == "amenity_flush":
		if seat_kind(peer) == "toilet" and game.clock >= next_flush:
			next_flush = game.clock + 3
			sound_serial += 1
			var variant := randi() % 20
			play_flush(sound_serial, variant)
			if campaign.crew.on_server(): flush.rpc(sound_serial, variant)
		return
	if action != "amenity_use" or not value is String or value not in ["bed", "toilet", "tv"]: return
	var actor: Dictionary = campaign.actor(peer)
	if actor.is_empty() or game.vessel != boat or campaign.captain == peer \
			or absf(boat.speed) > .5 or Vector3(actor.at).distance_to(target(value)) > 2.6:
		return
	if value == "tv":
		tv_on = not tv_on
		if tv_on: tv_epoch = game.clock
	else:
		if occupants.values().has(value) or not seat_kind(peer).is_empty() or not campaign.crewplay.held_by(peer).is_empty() \
				or not campaign.crewplay.held_fish(peer).is_empty(): return
		occupants[peer] = value
	publish()


func publish() -> void:
	apply_local_seat()
	if campaign.crew.on_server(): state.rpc(occupants, tv_on, maxf(0, game.clock - tv_epoch))


func welcome(peer: int) -> void:
	state.rpc_id(peer, occupants, tv_on, maxf(0, game.clock - tv_epoch))


func remove_peer(peer: int) -> void:
	if occupants.has(peer):
		occupants.erase(peer)
		publish()


@rpc("authority", "call_remote", "reliable")
func state(seats: Dictionary, enabled: bool, elapsed: float) -> void:
	occupants = seats.duplicate()
	tv_on = enabled
	tv_epoch = game.clock - elapsed
	apply_local_seat()


@rpc("authority", "call_remote", "reliable")
func flush(serial: int, variant: int) -> void:
	play_flush(serial, clampi(variant, 0, 19))


func apply_local_seat() -> void:
	var next := seat_kind(campaign.crew.my_id())
	if next == local_seat: return
	if next.is_empty():
		game.player.collision_mask = saved_mask
		game.player.velocity = Vector3.ZERO
		game.player.global_position = boat.to_global(EXIT)
		game.eye.position = Vector3(0, 1.58, 0)
		game.pitch = -.05
		game.update_view()
	else:
		saved_mask = game.player.collision_mask
		game.player.collision_mask = 0
		game.release_line()
		game.sonar_overlay.hide()
		game.yaw = boat.heading + (PI if next == "bed" else 0)
		game.pitch = -.08
	local_seat = next


func pin_local() -> void:
	if not seated(): return
	var kind := seat_kind(campaign.crew.my_id())
	game.player.velocity = Vector3.ZERO
	game.player.global_position = boat.to_global(BED if kind == "bed" else TOILET)
	game.player.rotation.y = game.yaw
	if kind == "bed":
		game.eye.global_position = boat.to_global(Vector3(-.84, 1.50, 4.30))
	else:
		game.eye.position = Vector3(0, 1.58, 0)
	game.eye.global_basis = Basis.from_euler(Vector3(game.pitch, game.yaw, 0))


func tick(_delta: float) -> void:
	apply_local_seat()
	var kind := seat_kind(campaign.crew.my_id())
	focus_kind = focused_action()
	var text := ""
	if not kind.is_empty(): text = "E / Space  Get up" + ("   ·   F  Flush" if kind == "toilet" else "")
	elif focus_kind == "occupied":
		text = "In use"
	hint.text = text
	hint.visible = not text.is_empty() and not game.menu_blocks_play()
	var elapsed := fposmod(game.clock - tv_epoch, LOOP_SECONDS)
	television_label.text = "RIVER NEWS\n\nLICENSED MEDIA PLACEHOLDER\n\nRequested news clip pending\n90-second synchronized loop" if tv_on else "TELEVISION OFF\n\nE  Power"
	television_progress.size.x = 592 * elapsed / LOOP_SECONDS if tv_on else 0
	if tv_on and not television_audio.playing: television_audio.play(elapsed if ResourceLoader.exists(CLIP_AUDIO) else 0)
	elif not tv_on: television_audio.stop()
	if video.stream != null:
		if tv_on and not video.is_playing(): video.play()
		elif not tv_on: video.stop()
		if tv_on and game.clock - last_video_sync > 5:
			last_video_sync = game.clock
			if absf(video.stream_position - elapsed) > .5: video.stream_position = elapsed


func play_flush(serial: int, variant: int) -> void:
	if serial <= last_sound: return
	last_sound = serial
	var sound := AudioStreamPlayer3D.new()
	boat.add_child(sound)
	sound.position = Vector3(.96, 1.2, 5.65)
	sound.max_distance = 15
	sound.unit_size = 2
	sound.volume_db = -9
	sound.stream = sound_bank[variant]
	sound.finished.connect(sound.queue_free)
	sound.play()


func make_sound(index: int) -> AudioStreamWAV:
	# Original procedural assets: no third-party media or unclear rights.
	var rate := 12000
	var length := 2.6 if index < 20 else 2.0
	var count := int(length * rate)
	var bytes := PackedByteArray()
	bytes.resize(count * 2)
	var random := RandomNumberGenerator.new()
	random.seed = 4319 + index * 71
	var filtered := 0.0
	for frame in count:
		var t := float(frame) / rate
		filtered = lerpf(filtered, random.randf_range(-1, 1), .17)
		var signal_value := 0.0
		if index < 20:
			var comic := sin(TAU * (47 + index * 3.7) * t + 5 * sin(t * (9 + index)))
			comic *= pow(maxf(0, 1 - t / 1.0), 2) * (.35 + .20 * sin(t * (31 + index)))
			var flush_noise := filtered * smoothstep(.8, 1.1, t) * (1 - smoothstep(1.8, 2.6, t))
			signal_value = (comic * .42 + flush_noise * .75) * minf(1, t * 40)
		else:
			signal_value = (sin(TAU * 196 * t) + sin(TAU * 293 * t) * .4) * .025
		var value := clampi(int(signal_value * 32767), -32768, 32767)
		bytes.encode_s16(frame * 2, value)
	var stream := AudioStreamWAV.new()
	stream.format = AudioStreamWAV.FORMAT_16_BITS
	stream.mix_rate = rate
	stream.data = bytes
	return stream
