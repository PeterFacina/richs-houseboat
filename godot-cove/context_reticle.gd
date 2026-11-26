extends Control

const PATHS := {
	"door": [[-5,7,-5,-7,5,-7,5,7,-5,7],[2,0,3,0]],
	"vehicle": [[-8,4,-8,0,-5,-4,5,-4,8,0,8,4,-8,4],[-5,4,-5,6],[5,4,5,6],[-8,0,8,0]],
	"dialogue": [[-7,-5,7,-5,7,4,0,4,-4,8,-4,4,-7,4,-7,-5],[-4,0,4,0]],
	"fishing": [[1,-7,1,4,-1,7,-5,7,-7,4,-7,1,-4,3],[1,-7,5,-7]],
	"equipment": [[-6,7,4,-3,3,-7,5,-8,6,-4,9,-4,8,-1,4,0,-4,9,-6,7]],
	"storage": [[-7,-4,7,-4,7,6,-7,6,-7,-4],[-7,0,7,0],[-2,0,-2,3,2,3,2,0]],
	"shop": [[-7,-3,7,-3,8,7,-8,7,-7,-3],[-3,-3,-3,-7,3,-7,3,-3]],
	"pickup": [[-6,1,-4,0,-2,2,-2,-7,0,-7,0,-2,2,-4,4,-4,6,-2,6,3,3,8,-2,8,-6,1]],
	"disabled": [[-5,-5,5,5],[5,-5,-5,5]],
}

var kind := ""
var prompt: Label
var debug := false
var debug_target := ""
var emphasis := 1.0


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt = Label.new()
	prompt.mouse_filter = Control.MOUSE_FILTER_IGNORE
	prompt.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt.add_theme_font_size_override("font_size", 15)
	prompt.add_theme_color_override("font_outline_color", Color("#192a32"))
	prompt.add_theme_constant_override("outline_size", 6)
	add_child(prompt)
	prompt.position = Vector2(-230, 15)
	prompt.custom_minimum_size.x = 460


static func binding(action: StringName) -> String:
	var events := InputMap.action_get_events(action)
	if events.is_empty():
		return ""
	var event := events[0]
	if event is InputEventKey and event.physical_keycode != KEY_NONE:
		var key: Key = event.physical_keycode
		if DisplayServer.get_name() != "headless":
			key = DisplayServer.keyboard_get_keycode_from_physical(key)
		return OS.get_keycode_string(key)
	return event.as_text()


func present(next: String, action: StringName = &"interact", title := "", hold := false) -> void:
	if kind != next:
		kind = next
		emphasis = .48
		queue_redraw()
	var key := binding(action) if not title.is_empty() else ""
	var line := "[%s] %s" % [key, title] if not key.is_empty() else ""
	if hold and not line.is_empty():
		line = "Hold " + line
	if debug:
		line += ("\n" if not line.is_empty() else "") + "Focus: " + ("none" if kind.is_empty() else kind) + "\n" + debug_target
	prompt.text = line


func _process(delta: float) -> void:
	if emphasis < .995:
		emphasis = lerpf(emphasis, 1.0, 1.0 - exp(-delta * 18.0))
		queue_redraw()


func _draw() -> void:
	var ink := Color(1, 1, 1, emphasis)
	var shadow := Color(.08, .13, .16, emphasis * .85)
	if kind.is_empty():
		draw_circle(Vector2.ZERO, 2.65, shadow, true, -1, true)
		draw_circle(Vector2.ZERO, 1.5, ink, true, -1, true)
		return
	if kind == "disabled":
		ink = Color(.65, .70, .72, emphasis)
	for path: Array in PATHS[kind]:
		var vertices := PackedVector2Array()
		for i in range(0, path.size(), 2):
			vertices.append(Vector2(path[i], path[i + 1]))
		draw_polyline(vertices, shadow, 4.0, true)
		draw_polyline(vertices, ink, 1.6, true)
