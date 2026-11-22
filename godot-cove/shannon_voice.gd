extends Node

const MASCULINE_NAMES := ["liam", "richard", "david", "mark", "george", "james", "ryan", "guy", "daniel", "male", "william"]
const SPEAKER := "Shannon Larping"
const FALLBACK_PREFERENCE := ["david", "mark", "guy"]
const OPENING_PITCH := [.76, .70, .79]
const OPENING_RATE := [.86, .83, .90]
const OPENING_GAIN := [0, 9, 3]

var panel: PanelContainer
var caption: Label
var lines: Array[String] = []
var voice := ""
var utterance := 0
var active := false
var playing := false
var wait := 0.0
var opening_parts := 0


func setup(hud: Control) -> void:
	if ProjectSettings.get_setting("audio/general/text_to_speech", false) \
			and DisplayServer.has_feature(DisplayServer.FEATURE_TEXT_TO_SPEECH):
		voice = select_voice(DisplayServer.tts_get_voices())
		if not voice.is_empty():
			DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_ENDED, line_finished)
			DisplayServer.tts_set_utterance_callback(DisplayServer.TTS_UTTERANCE_CANCELED, line_finished)
	panel = PanelContainer.new()
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	hud.add_child(panel)
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	panel.offset_left = -330
	panel.offset_right = 330
	panel.offset_top = -165
	panel.offset_bottom = -94
	var style := StyleBoxFlat.new()
	style.bg_color = Color("#18241eea")
	style.set_corner_radius_all(7)
	style.set_content_margin_all(12)
	panel.add_theme_stylebox_override("panel", style)
	caption = Label.new()
	caption.mouse_filter = Control.MOUSE_FILTER_IGNORE
	caption.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	caption.add_theme_font_size_override("font_size", 19)
	panel.add_child(caption)
	panel.hide()


static func select_voice(options: Array) -> String:
	var selected := ""
	var best_score := -1
	for option: Dictionary in options:
		var locale := str(option.language).to_lower().replace("-", "_")
		if locale != "en" and not locale.begins_with("en_"):
			continue
		var name_words := str(option.name).to_lower().replace(",", " ").split(" ", false)
		var score := 18 if locale == "en_ca" else 0
		for name_word: String in name_words:
			if name_word in MASCULINE_NAMES:
				score += 100
				break
		if locale == "en_us":
			for index in FALLBACK_PREFERENCE.size():
				if FALLBACK_PREFERENCE[index] in name_words:
					score += (FALLBACK_PREFERENCE.size() - index) * 4
					break
		if score > best_score:
			best_score = score
			selected = option.id
	return selected


func say(dialogue: Array[String], distance: float, opening: Array[String] = []) -> void:
	stop()
	lines.assign(opening)
	lines.append_array(dialogue)
	opening_parts = opening.size()
	if opening_parts > 0:
		caption.text = SPEAKER + "\n" + " ".join(opening)
	active = true
	next_line(distance)


func next_line(distance: float) -> void:
	var text: String = lines.pop_front()
	var is_opening := opening_parts > 0
	if is_opening:
		opening_parts -= 1
	else:
		caption.text = SPEAKER + "\n" + text
	panel.show()
	wait = maxf(2.0, text.length() * .074)
	if not voice.is_empty():
		playing = true
		utterance += 1
		wait = maxf(8.0, wait * 2.5)
		var opening_index := OPENING_PITCH.size() - opening_parts - 1
		var gain: int = OPENING_GAIN[opening_index] if is_opening else 0
		var volume := roundi((85 + gain) * clampf(1.0 - distance / 24.0, .38, 1.0))
		var pitch: float = OPENING_PITCH[opening_index] if is_opening else .66
		var rate: float = OPENING_RATE[opening_index] if is_opening else .80
		DisplayServer.tts_speak(text, voice, volume, pitch, rate, utterance)


func line_finished(id: int) -> void:
	if id != utterance or not playing:
		return
	playing = false
	match opening_parts:
		2: wait = .08
		1: wait = .32
		_: wait = .4


func advance(delta: float, distance: float, range_limit: float) -> void:
	if not active:
		return
	if distance > range_limit:
		stop()
		return
	wait -= delta
	if wait > 0.0:
		return
	if playing:
		stop_native()
	if lines.is_empty():
		stop()
	else:
		next_line(distance)


func stop_native() -> void:
	if playing:
		playing = false
		DisplayServer.tts_stop()


func stop() -> void:
	stop_native()
	lines.clear()
	active = false
	panel.hide()


func _exit_tree() -> void:
	stop_native()
