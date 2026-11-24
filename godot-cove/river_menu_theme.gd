extends RefCounted

const NAVY := Color("#182f40")
const MUTED := Color("#496373")
const CREAM := Color("#f5ead7")
const PAPER := Color("#fff8e9")
const SAND := Color("#d9c5a6")
const GOLD := Color("#dfb784")
const BLUE := Color("#1c5673")
const MIST := Color("#deedf0")
const ORANGE := Color("#b84b23")
const SCRIM := Color("#101d25a0")
const MARGIN := 62
const GAP := 8
const BUTTON_HEIGHT := 46

# Monochrome, 20-pixel menu symbols share the text tint of their button.
const ICONS := {
	"play": "<path d='m6 3 11 7-11 7z'/>",
	"settings": "<path d='M3 5h14M3 10h14M3 15h14M7 3v4m6 1v4m-6 1v4'/>",
	"save": "<path d='M3 3h11l3 3v11H3zM6 3v5h7V3m-7 14v-5h8v5'/>",
	"pack": "<path d='M7 5V4a3 3 0 0 1 6 0v1M4 17V8q0-3 3-3h6q3 0 3 3v9zM4 11h12m-6 0v3'/>",
	"chart": "<path d='m2 5 5-2 6 2 5-2v12l-5 2-6-2-5 2zm5-2v12m6-10v12'/>",
	"journal": "<rect x='4' y='3' width='13' height='14' rx='2'/><path d='M7 3v14m3-10h4m-4 4h4'/>",
	"fish": "<path d='M3 10c3-5 8-6 12-2l3-2v8l-3-2c-4 4-9 3-12-2z'/><circle cx='7' cy='9.5' r='.55'/>",
	"crew": "<circle cx='7' cy='6' r='2.5'/><path d='M2 16v-1a5 5 0 0 1 10 0v1m1-12a2.5 2.5 0 0 1 0 5m1 2a4 4 0 0 1 4 4v1'/>",
	"river": "<path d='M2 6q2-3 5 0t5 0 6 0M2 10q2-3 5 0t5 0 6 0M2 14q2-3 5 0t5 0 6 0'/>",
	"jobs": "<rect x='4' y='5' width='12' height='12' rx='2'/><path d='M7 5V3h6v2m-6 5h6m-6 3h6'/>",
	"build": "<path d='m2 9 8-6 8 6M4 8v9h12V8m-8 9v-5h4v5'/>",
	"tools": "<path d='M17 3l-3 3 1 2 3-1a5 5 0 0 1-6 5l-5 5a2 2 0 0 1-3-3l5-5a5 5 0 0 1 5-6z'/>",
	"back": "<path d='m8 5-5 5 5 5m-5-5h14'/>",
	"reset": "<path d='M3 5v5h5M3 10a7 7 0 1 1 3 6'/>",
	"exit": "<path d='M10 17H3V3h7m1 7h7m-3-3 3 3-3 3'/>",
}

static var shared_theme: Theme
static var bold_font: FontVariation
static var icons: Dictionary = {}


static func get_theme() -> Theme:
	if shared_theme != null:
		return shared_theme
	shared_theme = Theme.new()
	shared_theme.default_font_size = 17
	shared_theme.set_color("font_color", "Label", NAVY)
	for kind in [&"Button", &"CheckButton", &"OptionButton"]:
		set_theme_button(kind, PAPER, MIST, Color("#b8dce5"), NAVY, SAND)
	shared_theme.set_type_variation(&"MainAction", &"Button")
	set_theme_button(&"MainAction", BLUE, Color("#256c89"), Color("#16445b"), Color.WHITE, BLUE)
	shared_theme.set_type_variation(&"QuietAction", &"Button")
	set_theme_button(&"QuietAction", CREAM, PAPER, MIST, MUTED, SAND)
	shared_theme.set_type_variation(&"TitleStart", &"Button")
	set_theme_button(&"TitleStart", Color("#e5bd87"), Color("#f7d49e"), GOLD, NAVY, Color("#e9cda4"))
	shared_theme.set_type_variation(&"TitleAction", &"Button")
	set_theme_button(&"TitleAction", Color("#344c4d"), Color("#476561"), Color("#2c4144"), CREAM, Color("#697d73"))
	for kind in [&"TitleStart", &"TitleAction"]:
		shared_theme.set_stylebox("disabled", kind, box(Color("#273438"), Color("#37484b"), 7))
		shared_theme.set_color("font_disabled_color", kind, Color("#9aadaa"))
	shared_theme.set_stylebox("normal", "LineEdit", box(PAPER, SAND, 7))
	shared_theme.set_stylebox("focus", "LineEdit", focus_box())
	shared_theme.set_color("font_color", "LineEdit", NAVY)
	shared_theme.set_color("font_placeholder_color", "LineEdit", MUTED)
	shared_theme.set_color("caret_color", "LineEdit", NAVY)
	var rule := box(SAND, SAND, 0, 0)
	rule.content_margin_bottom = 1
	shared_theme.set_stylebox("separator", "HSeparator", rule)
	shared_theme.set_constant("separation", "HSeparator", 1)
	shared_theme.set_stylebox("slider", "HSlider", box(SAND, SAND, 4, 3))
	shared_theme.set_stylebox("grabber_area", "HSlider", box(BLUE, BLUE, 4, 3))
	shared_theme.set_stylebox("grabber_area_highlight", "HSlider", box(BLUE, BLUE, 4, 3))
	shared_theme.set_icon("grabber", "HSlider", dot_texture(BLUE, 18))
	shared_theme.set_icon("grabber_highlight", "HSlider", dot_texture(ORANGE, 18))
	shared_theme.set_stylebox("panel", "AcceptDialog", box(CREAM, SAND, 10, 20))
	return shared_theme


static func set_theme_button(kind: StringName, fill: Color, hover: Color, pressed: Color, ink: Color, border: Color) -> void:
	shared_theme.set_stylebox("normal", kind, box(fill, border, 7))
	shared_theme.set_stylebox("hover", kind, box(hover, border, 7))
	shared_theme.set_stylebox("pressed", kind, box(pressed, border, 7))
	shared_theme.set_stylebox("hover_pressed", kind, box(pressed.lightened(.08), border, 7))
	shared_theme.set_stylebox("focus", kind, focus_box())
	shared_theme.set_stylebox("disabled", kind, box(Color("#e5ded1"), SAND, 7))
	for state in ["font_color", "font_hover_color", "font_pressed_color", "font_hover_pressed_color", "font_focus_color",
			"icon_normal_color", "icon_hover_color", "icon_pressed_color", "icon_hover_pressed_color", "icon_focus_color"]:
		shared_theme.set_color(state, kind, ink)
	shared_theme.set_color("font_disabled_color", kind, MUTED)
	shared_theme.set_constant("h_separation", kind, GAP)


static func box(fill: Color, border: Color, radius: int, padding := 13) -> StyleBoxFlat:
	var style := StyleBoxFlat.new()
	style.bg_color = fill
	style.border_color = border
	style.set_border_width_all(1)
	style.set_corner_radius_all(radius)
	style.set_content_margin_all(padding)
	style.content_margin_top = minf(padding, 6)
	style.content_margin_bottom = minf(padding, 6)
	return style


static func focus_box(radius := 7) -> StyleBoxFlat:
	var style := box(Color.TRANSPARENT, ORANGE, radius, 0)
	style.set_border_width_all(2)
	return style


static func panel(parent: Node, fill := CREAM, border := SAND, radius := 14, padding := 20) -> MarginContainer:
	var frame := PanelContainer.new()
	frame.add_theme_stylebox_override("panel", box(fill, border, radius, 0))
	parent.add_child(frame)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, padding)
	frame.add_child(margin)
	return margin


static func text(words: String, size: int, color := NAVY, bold := false) -> Label:
	var label := Label.new()
	label.text = words
	label.add_theme_font_size_override("font_size", size)
	label.add_theme_color_override("font_color", color)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if bold:
		label.add_theme_font_override("font", get_bold_font())
	return label


static func get_bold_font() -> FontVariation:
	if bold_font == null:
		bold_font = FontVariation.new()
		bold_font.base_font = ThemeDB.fallback_font
		bold_font.variation_embolden = .74
	return bold_font


static func button(caption: String, style: StringName = &"Button", icon_name := "", height := BUTTON_HEIGHT) -> Button:
	var control := Button.new()
	control.text = caption
	control.theme_type_variation = style
	control.custom_minimum_size.y = height
	control.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND
	if not icon_name.is_empty():
		control.icon = icon(icon_name)
		control.add_theme_constant_override("icon_max_width", 20)
	animate_press(control)
	return control


static func icon(icon_name: String) -> Texture2D:
	if not icons.has(icon_name):
		var source := "<svg xmlns='http://www.w3.org/2000/svg' width='20' height='20' viewBox='0 0 20 20'><g fill='none' stroke='white' stroke-width='1.6' stroke-linejoin='round' stroke-linecap='round'>%s</g></svg>"
		var bitmap := Image.new()
		bitmap.load_svg_from_string(source % ICONS[icon_name], 2.0)
		icons[icon_name] = ImageTexture.create_from_image(bitmap)
	return icons[icon_name]


static func dot_texture(tint: Color, width: int) -> Texture2D:
	var bitmap := Image.create_empty(width, width, false, Image.FORMAT_RGBA8)
	var center := Vector2.ONE * (width - 1) / 2.0
	for x in width:
		for y in width:
			var distance := Vector2(x, y).distance_to(center)
			bitmap.set_pixel(x, y, Color(tint, clampf(center.x - distance, 0, 1)))
	return ImageTexture.create_from_image(bitmap)


static func style_confirmation(dialog: ConfirmationDialog) -> void:
	dialog.theme = get_theme()
	var confirm := dialog.get_ok_button()
	var cancel := dialog.get_cancel_button()
	for button in [confirm, cancel]:
		animate_press(button)
		var other := cancel if button == confirm else confirm
		button.focus_neighbor_left = button.get_path_to(other)
		button.focus_neighbor_right = button.focus_neighbor_left


static func animate_press(control: BaseButton) -> void:
	var animate := func(target: Vector2, duration: float):
		if control.has_meta("press_tween"):
			var old: Tween = control.get_meta("press_tween")
			old.kill()
		control.pivot_offset = control.size * .5
		var tween := control.create_tween().set_pause_mode(Tween.TWEEN_PAUSE_PROCESS)
		tween.tween_property(control, "scale", target, duration).set_trans(Tween.TRANS_QUAD)
		control.set_meta("press_tween", tween)
	control.button_down.connect(animate.bind(Vector2(.97, .94), .055))
	control.button_up.connect(animate.bind(Vector2.ONE, .11))
	control.visibility_changed.connect(func():
		if not control.is_visible_in_tree() and control.has_meta("press_tween"):
			var tween: Tween = control.get_meta("press_tween")
			tween.kill()
			control.scale = Vector2.ONE)
