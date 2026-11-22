extends Control

const SIZE := Vector2i(628, 360)
const HISTORY := 190
const RANGES := [5.0, 10.0, 20.0, 40.0, 70.0]
const PANEL := Color("#101e26")
const PLOT := Color("#09202c")
const INK := Color("#e7f0e9")
const DIM := Color("#92b5b8")
const SOFT := Color("#285058")
const GOLD := Color("#f1b859")

var records: Array[Dictionary] = []
var display_depth := 0.0
var range_m := 10.0
var ground_speed := 0.0
var rpm := 0.0
var ping_time := 0.0
var ping_number := 0
var seen_bottom := false


func update_pings(delta: float, depth: float, speed: float, engine_rpm: float,
		echo_source: Callable, bed_hardness: float) -> void:
	ping_time += delta
	if ping_time < .17:
		return
	ping_time = fmod(ping_time, .17)
	ping_number += 1
	ground_speed = absf(speed)
	rpm = engine_rpm
	seen_bottom = depth >= .28
	display_depth = depth if display_depth <= .0 else lerpf(display_depth, depth, .32)
	if seen_bottom and (display_depth > range_m * .91 or display_depth < range_m * .39):
		for option: float in RANGES:
			range_m = option
			if display_depth < option * .80:
				break
	var echoes: Array[Vector2] = echo_source.call() if seen_bottom else []
	var loss := smoothstep(4.0, 7.0, ground_speed) * .46
	var ping := {"bottom": depth if seen_bottom else -1.0, "school": echoes,
		"prop": smoothstep(1800.0, 5200.0, engine_rpm) * .34, "attenuation": 1.0 - loss,
		"bed": bed_hardness, "index": ping_number}
	records.append(ping)
	if records.size() > HISTORY:
		records.pop_front()
	queue_redraw()


func _draw() -> void:
	var font := ThemeDB.fallback_font
	draw_rect(Rect2(Vector2.ZERO, Vector2(SIZE)), PANEL)
	draw_rect(Rect2(1, 1, SIZE.x - 2, SIZE.y - 2), Color("#314753"), false, 2.0)
	draw_string(font, Vector2(22, 34), "DEPTH", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	var number := "%.1f m" % display_depth if seen_bottom else "— m"
	draw_string(font, Vector2(22, 79), number, HORIZONTAL_ALIGNMENT_LEFT, -1, 43, INK)
	draw_string(font, Vector2(257, 38), "SPEED", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	draw_string(font, Vector2(257, 70), "%.1f km/h" % (ground_speed * 3.6), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
	draw_string(font, Vector2(414, 38), "ENGINE", HORIZONTAL_ALIGNMENT_LEFT, -1, 14, DIM)
	draw_string(font, Vector2(414, 70), "%d rpm" % (roundi(rpm / 10.0) * 10), HORIZONTAL_ALIGNMENT_LEFT, -1, 24, INK)
	draw_circle(Vector2(602, 29), 4.0, Color("#70c89c") if seen_bottom else Color("#687e82"))
	var box := Rect2(24, 106, 536, 214)
	draw_rect(box, PLOT)
	for tick in 5:
		var y := box.position.y + float(tick) / 4.0 * box.size.y
		draw_line(Vector2(box.position.x, y), Vector2(box.end.x, y), SOFT)
		var mark := str(snappedf(range_m * tick / 4.0, .01)) + " m"
		draw_string(font, Vector2(569, y + 5), mark, HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	var spacing := box.size.x / HISTORY
	for index in records.size():
		var ping := records[index]
		var x := box.end.x - float(records.size() - index) * spacing
		if ping.bottom < 0.0:
			continue
		var depth := clampf(ping.bottom / range_m, 0.0, 1.0)
		var y := box.position.y + depth * box.size.y
		var bottom_color := Color("#4d4e55").lerp(Color("#b27447"), ping.bed)
		draw_rect(Rect2(x, y, spacing + .5, maxf(0.0, box.end.y - y)), bottom_color.darkened(.52))
		draw_rect(Rect2(x, y, spacing + .5, minf(box.end.y - y, 2.3 + 3.2 * ping.bed)), bottom_color)
		if depth < .997:
			draw_rect(Rect2(x, y, spacing + .5, 1.6), GOLD.lerp(Color("#f5df92"), ping.bed))
		var clutter: float = .13 + ping.prop * .73
		for bank in 3:
			var modulation := fposmod(float(hash(Vector2i(ping.index, bank))) * .00019, 1.0)
			var surf := clampf((bank * .17 + modulation * clutter) / range_m, 0.0, depth)
			if modulation * 1.2 < .45 + ping.prop:
				draw_rect(Rect2(x, box.position.y + surf * box.size.y, spacing, 1.3), Color("#245a69"))
		for echo: Vector2 in ping.school:
			var take := clampf(echo.x / range_m, .008, 1.0)
			if take >= depth:
				continue
			var strength := clampf(echo.y * ping.attenuation, .12, 1.0)
			var echo_color := Color("#2a7777").lerp(Color("#f9ca61"), smoothstep(.12, .94, strength))
			draw_rect(Rect2(x, box.position.y + take * box.size.y, spacing + .51, 1.6 + strength * 2.8), echo_color)
	draw_line(Vector2(box.end.x, box.position.y), Vector2(box.end.x, box.end.y), Color("#72a1a4"))
	draw_string(font, Vector2(24, 346), "SIMULATED SONAR", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
	draw_string(font, Vector2(441, 346), "AUTO RANGE", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, DIM)
