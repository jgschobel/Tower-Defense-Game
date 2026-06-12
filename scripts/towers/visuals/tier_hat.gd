extends Node2D

func _draw() -> void:
	var tier: int = get_meta("tier", 1)
	var is_a: bool = get_meta("is_path_a", true)
	var col: Color = get_meta("col_a", Color(1, 0.85, 0.1)) if is_a else get_meta("col_b", Color(0.45, 0.8, 1))
	var s: float = 0.62 + tier * 0.19
	var dark := Color(col.r * 0.35, col.g * 0.35, col.b * 0.35, 1.0)
	if is_a:
		_draw_crown(tier, col, dark, s)
	else:
		_draw_band(tier, col, dark, s)


func _draw_crown(tier: int, col: Color, dark: Color, s: float) -> void:
	var w := 20.0 * s
	var bh := 5.0 * s
	var sh := (8.0 + tier * 3.5) * s
	var ns: int = tier + 2
	var sp := w / ns
	# Base bar with outline
	draw_rect(Rect2(-w * 0.5, -bh, w, bh), dark)
	draw_rect(Rect2(-w * 0.5 + 1.5, -bh + 1.5, w - 3.0, bh - 1.5), col)
	# Spikes
	for i in ns:
		var cx := -w * 0.5 + sp * (i + 0.5)
		var pts := PackedVector2Array([Vector2(cx - sp * 0.36, -bh), Vector2(cx, -bh - sh), Vector2(cx + sp * 0.36, -bh)])
		draw_polygon(pts, PackedColorArray([col, col, col]))
	# Gem on tallest spike (tier 2+)
	if tier >= 2:
		var gy := -bh - sh * 0.8
		draw_circle(Vector2(0.0, gy), 3.2 * s, Color(1.0, 0.2, 0.2, 0.95))
		draw_arc(Vector2(0.0, gy), 3.2 * s, 0.0, TAU, 16, Color(1, 1, 1, 0.85), 1.2)


func _draw_band(tier: int, col: Color, dark: Color, s: float) -> void:
	var w := 22.0 * s
	var h := 6.5 * s
	# Outline then fill
	draw_rect(Rect2(-w * 0.5, -h * 0.5, w, h), dark)
	draw_rect(Rect2(-w * 0.5 + 1.5, -h * 0.5 + 1.5, w - 3.0, h - 3.0), col)
	# Stars: 1 at tier 1, 2 at tier 2, 3 at tier 3
	for i in tier:
		var sx: float = 0.0
		if tier > 1:
			sx = (-0.5 + float(i + 1) / float(tier + 1)) * w * 1.1
		draw_circle(Vector2(sx, 0.0), 3.8 * s, Color(1, 1, 0.65, 0.95))
		draw_circle(Vector2(sx, 0.0), 2.0 * s, Color(1, 0.82, 0.1, 1.0))
