extends Control

signal dismissed
signal chosen(npc: String, quest: String, action: String)

const Style = preload("res://notebook_theme.gd")

var npc_id := ""
var quest_id := ""
var primary_action := ""
var npc_name: Label
var title: Label
var progress: Label
var description: Label
var objectives: Label
var rewards: Label
var primary: Button
var decline: Button
var secondary: Button
var secondary_action := ""
var frame: PanelContainer
var close: Button


func _ready() -> void:
	name = "NpcQuestOffer"
	theme = Style.skin()
	set_anchors_and_offsets_preset(PRESET_FULL_RECT)
	mouse_filter = MOUSE_FILTER_STOP
	frame = PanelContainer.new()
	frame.add_theme_stylebox_override(&"panel", Style.box(Style.NAVY, Color("#091a2e"), 10, 4))
	add_child(frame)
	var stack := VBoxContainer.new()
	stack.add_theme_constant_override(&"separation", 8)
	frame.add_child(stack)
	var head := HBoxContainer.new()
	stack.add_child(head)
	npc_name = Style.label("", 23, Style.PAPER)
	npc_name.size_flags_horizontal = SIZE_EXPAND_FILL
	head.add_child(npc_name)
	close = Style.button("Close  Esc", 34)
	close.pressed.connect(func(): dismissed.emit())
	head.add_child(close)
	var body := Style.page(stack, 19)
	title = Style.label("", 24, Style.OLIVE)
	progress = Style.label("", 14, Style.OLIVE)
	description = Style.label("")
	objectives = Style.label("")
	rewards = Style.label("")
	for entry in [title, progress, description, HSeparator.new(), objectives, rewards]:
		body.add_child(entry)
	var actions := HBoxContainer.new()
	actions.add_theme_constant_override(&"separation", 8)
	stack.add_child(actions)
	primary = Style.button("")
	primary.add_theme_stylebox_override(&"normal", Style.box(Style.YELLOW, Style.EDGE, 8))
	primary.size_flags_horizontal = SIZE_EXPAND_FILL
	primary.pressed.connect(func(): chosen.emit(npc_id, quest_id, primary_action))
	actions.add_child(primary)
	decline = Style.button("Decline")
	decline.pressed.connect(func(): dismissed.emit())
	actions.add_child(decline)
	secondary = Style.button("")
	secondary.pressed.connect(func(): chosen.emit(npc_id, quest_id, secondary_action))
	stack.add_child(secondary)
	resized.connect(layout_offer)
	hide()


func present(data: Dictionary) -> void:
	var opening := not visible
	npc_id = data.npc
	quest_id = data.get("id", "")
	primary_action = data.get("action", "")
	secondary_action = data.get("secondary_action", "")
	secondary.visible = not secondary_action.is_empty()
	secondary.text = data.get("secondary_button", "")
	npc_name.text = data.name
	title.text = data.title
	progress.text = data.get("status", "")
	progress.visible = not progress.text.is_empty()
	description.text = data.get("description", "")
	objectives.text = data.get("objectives", "")
	objectives.visible = not objectives.text.is_empty()
	rewards.text = data.get("rewards", "")
	rewards.visible = not rewards.text.is_empty()
	primary.visible = not primary_action.is_empty()
	primary.text = data.get("button", "")
	decline.visible = primary_action == "accept"
	show()
	layout_offer()
	if opening:
		close.grab_focus(true)


func layout_offer() -> void:
	frame.size = Vector2(minf(510.0, size.x * .44), minf(454.0, size.y - 82.0))
	frame.position = Vector2(38, maxf(30.0, (size.y - frame.size.y) * .5 - 24.0))
