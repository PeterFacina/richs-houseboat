extends Node3D

const PANEL_SIZE := Vector2(.72, .28)
const CANVAS_SIZE := Vector2i(760, 296)
const RPM_CENTER := Vector2(184, 162)
const SWEEP_START := deg_to_rad(-210.0)
const SWEEP_END := deg_to_rad(30.0)
const FACE := Color("#142628")
const RIM := Color("#526865")
const INK := Color("#fff3d8")
const SOFT := Color("#b8cfca")
const AMBER := Color("#ffc76b")
const GREEN := Color("#84e5b7")

var viewport: SubViewport
var face: Control
var rpm_percent := -1
var airspeed_kmh := -1
var altitude_m := -1
var ready_light := false


func _ready() -> void:
	viewport = SubViewport.new()
	viewport.size = CANVAS_SIZE
	viewport.disable_3d = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE
	add_child(viewport)
	face = Control.new()
	face.size = CANVAS_SIZE
	face.draw.connect(draw_gauges)
	viewport.add_child(face)
	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_texture = viewport.get_texture()
	var quad := QuadMesh.new()
	quad.size = PANEL_SIZE
	var display := MeshInstance3D.new()
	display.mesh = quad
	display.material_override = material
	display.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	add_child(display)
	update_readings(0.0, 0.0, 0.0, false)


func update_readings(rotor_speed: float, speed: float, clearance: float, running_at_flight_rpm: bool) -> void:
	var rpm := clampi(floori(rotor_speed * 100.0), 0, 100)
	var kmh := roundi(speed * 3.6)
	var metres := maxi(0, roundi(clearance))
	if rpm == rpm_percent and kmh == airspeed_kmh and metres == altitude_m and running_at_flight_rpm == ready_light:
		return
	rpm_percent = rpm
	airspeed_kmh = kmh
	altitude_m = metres
	ready_light = running_at_flight_rpm
	face.queue_redraw()
	viewport.render_target_update_mode = SubViewport.UPDATE_ONCE


func draw_gauges() -> void:
	face.draw_rect(Rect2(Vector2.ZERO, CANVAS_SIZE), Color("#0a1517"))
	draw_bezel(Rect2(8, 8, 354, 280))
	draw_rotor_gauge()
	draw_number_gauge(Rect2(370, 8, 187, 280), "AIRSPEED", airspeed_kmh, "km/h")
	draw_number_gauge(Rect2(565, 8, 187, 280), "ALTITUDE", altitude_m, "m AGL")


func draw_bezel(bounds: Rect2) -> void:
	face.draw_rect(bounds, RIM)
	face.draw_rect(bounds.grow(-3), FACE)


func draw_rotor_gauge() -> void:
	var radius := 94.0
	centered_text("ROTOR RPM", RPM_CENTER.x, 52, 28, SOFT)
	face.draw_arc(RPM_CENTER, radius, SWEEP_START, SWEEP_END, 48, RIM, 10, true)
	if rpm_percent > 0:
		var reading := lerpf(SWEEP_START, SWEEP_END, rpm_percent / 100.0)
		face.draw_arc(RPM_CENTER, radius, SWEEP_START, reading, 48, GREEN if ready_light else AMBER, 10, true)
	for step in 11:
		var angle := lerpf(SWEEP_START, SWEEP_END, step / 10.0)
		var along := Vector2.from_angle(angle)
		var major := step >= 9
		var ink := (AMBER if step == 9 else GREEN) if major else SOFT
		face.draw_line(RPM_CENTER + along * 102, RPM_CENTER + along * (113 if major else 108), ink, 3.0, true)
	centered_text("90%", 324, 183, 24, AMBER)
	centered_text("100%", 309, 234, 24, GREEN)
	centered_text("%d%%" % rpm_percent, RPM_CENTER.x, 181, 66, INK)
	face.draw_circle(Vector2(132, 249), 9, GREEN if ready_light else RIM, true, -1.0, true)
	centered_text("READY", 185.0, 257, 25, GREEN if ready_light else SOFT)


func draw_number_gauge(bounds: Rect2, title: String, value: int, unit: String) -> void:
	draw_bezel(bounds)
	var center := bounds.get_center().x
	centered_text(title, center, 73, 24, SOFT)
	face.draw_line(Vector2(bounds.position.x + 24, 92), Vector2(bounds.end.x - 24, 92), RIM, 2.0)
	centered_text(str(value), center, 167, 64, INK)
	centered_text(unit, center, 214, 29, SOFT)


func centered_text(value: String, x: float, baseline: float, font_size: int, color: Color) -> void:
	var font := ThemeDB.fallback_font
	var width := font.get_string_size(value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	face.draw_string(font, Vector2(x - width * .5, baseline), value, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, color)
