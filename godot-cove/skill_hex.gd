extends Button

var tint := Color.SKY_BLUE
var chosen := false

func _draw() -> void:
	var w := size.x
	var h := size.y
	var points := PackedVector2Array([Vector2(12,1), Vector2(w-12,1), Vector2(w-1,h/2), Vector2(w-12,h-1), Vector2(12,h-1), Vector2(1,h/2)])
	draw_colored_polygon(points, Color(tint, .14))
	points.append(points[0])
	draw_polyline(points, tint, 3 if chosen or has_focus() else 1.5, true)
