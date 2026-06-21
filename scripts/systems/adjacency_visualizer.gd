extends Node2D
class_name AdjacencyVisualizer

## Renders faint gold lines between towers within each other's buff
## range to make ROADMAP #41 synergies visible. Refreshes on
## tower_placed / tower_sold via the placement system.

const LINE_COLOR: Color = Color(1.0, 0.85, 0.2, 0.5)
const LINE_WIDTH: float = 3.0
const LINE_DASH_PX: float = 8.0
const LINE_GAP_PX: float = 4.0


func _ready() -> void:
	z_index = 8  # above path layers (z=2–5), below enemies (z=15) + towers (z=20)


func refresh() -> void:
	queue_redraw()


func _draw() -> void:
	var towers: Array = get_tree().get_nodes_in_group("towers") if get_tree() else []
	# Only draw each pair once.
	for i in towers.size():
		var a: Node2D = towers[i]
		if not is_instance_valid(a) or not ("data" in a) or a.data == null:
			continue
		for j in range(i + 1, towers.size()):
			var b: Node2D = towers[j]
			if not is_instance_valid(b) or not ("data" in b) or b.data == null:
				continue
			var radius: float = max(a.data.buff_range, b.data.buff_range)
			if radius <= 0.0:
				continue
			var dist: float = a.global_position.distance_to(b.global_position)
			if dist <= radius:
				_draw_dashed_line(a.global_position, b.global_position)


func _draw_dashed_line(from: Vector2, to: Vector2) -> void:
	var dir: Vector2 = (to - from)
	var length: float = dir.length()
	if length <= 0.0:
		return
	var step: float = LINE_DASH_PX + LINE_GAP_PX
	var normal: Vector2 = dir / length
	var pos: float = 0.0
	while pos < length:
		var end_pos: float = min(pos + LINE_DASH_PX, length)
		draw_line(from + normal * pos, from + normal * end_pos, LINE_COLOR, LINE_WIDTH)
		pos += step
