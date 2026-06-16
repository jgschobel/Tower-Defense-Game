extends Node2D

func _draw() -> void:
	var r: float = get_meta("radius", 40.0)
	var c: Color = get_meta("ring_color", Color.YELLOW)
	var a: float = get_meta("alpha", 0.4)
	# Inner ring: slightly inside the sprite edge — creates a coloured rim overlay.
	# Outer ring: halos just beyond the sprite perimeter.
	# Arc alphas dialled back from 0.72/0.28 to 0.55/0.22 so the ring reads
	# clearly when drawn in front (z=1) without fully masking the portrait (#965).
	draw_arc(Vector2.ZERO, r * 0.88, 0.0, TAU, 24, Color(c.r, c.g, c.b, a * 0.55), 5.0, true)
	draw_arc(Vector2.ZERO, r * 1.12, 0.0, TAU, 24, Color(c.r, c.g, c.b, a * 0.22), 3.5, true)
