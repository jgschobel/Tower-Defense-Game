extends Node2D

## Draws a semi-transparent range circle for towers.

var circle_radius: float = 150.0
var circle_color: Color = Color(0.3, 0.6, 1.0, 0.2)
var border_color: Color = Color(0.4, 0.7, 1.0, 0.6)


func set_radius(r: float) -> void:
	circle_radius = r
	queue_redraw()


func _draw() -> void:
	draw_circle(Vector2.ZERO, circle_radius, circle_color)
	# Draw border ring
	var point_count := 64
	var points := PackedVector2Array()
	for i in point_count + 1:
		var angle := (float(i) / float(point_count)) * TAU
		points.append(Vector2(cos(angle), sin(angle)) * circle_radius)
	for i in point_count:
		draw_line(points[i], points[i + 1], border_color, 2.0)
