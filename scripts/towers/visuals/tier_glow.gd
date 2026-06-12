extends Node2D

func _draw() -> void:
	var r: float = get_meta("radius", 40.0)
	var c: Color = get_meta("ring_color", Color.YELLOW)
	var a: float = get_meta("alpha", 0.4)
	draw_arc(Vector2.ZERO, r * 0.88, 0.0, TAU, 20, Color(c.r, c.g, c.b, a * 0.72), 5.0, true)
	draw_arc(Vector2.ZERO, r * 1.12, 0.0, TAU, 20, Color(c.r, c.g, c.b, a * 0.28), 3.5, true)
