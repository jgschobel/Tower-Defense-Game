extends Node2D

## Draws a semi-transparent range circle with an animated dashed border (D30).

var circle_radius: float = 150.0
var circle_color: Color = Color(0.3, 0.6, 1.0, 0.16)
var border_color: Color = Color(0.5, 0.8, 1.0, 0.92)

# Dash animation — offset increments each frame to make the dashes march.
var _dash_offset: float = 0.0
const DASH_LEN: float = 18.0   # arc-length of each dash in pixels
const GAP_LEN: float  = 10.0   # gap between dashes
const MARCH_SPEED: float = 25.0  # px/s that dashes travel clockwise


func set_radius(r: float) -> void:
	circle_radius = r
	queue_redraw()


func set_tint(c: Color) -> void:
	# Per-tower tint — keeps range visualizations distinguishable when
	# multiple towers' ranges overlap.
	circle_color = Color(c.r, c.g, c.b, 0.18)
	border_color = Color(c.r, c.g, c.b, 0.92)
	queue_redraw()


func _process(delta: float) -> void:
	if not visible:
		return
	_dash_offset = fmod(_dash_offset + MARCH_SPEED * delta, DASH_LEN + GAP_LEN)
	queue_redraw()


func _draw() -> void:
	# Filled semi-transparent interior
	draw_circle(Vector2.ZERO, circle_radius, circle_color)

	# Animated dashed border
	var circumference: float = TAU * circle_radius
	var period: float = DASH_LEN + GAP_LEN
	var seg_count: int = 8  # points per dash segment for smooth curves
	var arc_pos: float = -_dash_offset
	while arc_pos < circumference:
		var dash_start: float = arc_pos
		var dash_end: float   = arc_pos + DASH_LEN
		# Clamp to valid range
		dash_start = clampf(dash_start, 0.0, circumference)
		dash_end   = clampf(dash_end,   0.0, circumference)
		if dash_end > dash_start:
			var a_start: float = (dash_start / circumference) * TAU
			var a_end: float   = (dash_end   / circumference) * TAU
			var pts := PackedVector2Array()
			for j in seg_count + 1:
				var t: float = float(j) / float(seg_count)
				var angle: float = a_start + t * (a_end - a_start)
				pts.append(Vector2(cos(angle), sin(angle)) * circle_radius)
			for j in seg_count:
				draw_line(pts[j], pts[j + 1], border_color, 3.0, true)
		arc_pos += period
