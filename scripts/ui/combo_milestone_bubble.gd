class_name ComboMilestoneBubble
extends Control

## Banani-Lawine — centered pill bubble that pops when ComboTracker crosses
## named kill-streak thresholds (10 / 25 / 50 / 75 / 100 / 150).
## Added to the HUD CanvasLayer once per level by game_level._ready();
## persists until the scene exits, reuses itself across multiple milestones.

const PILL_W: float = 360.0
const PILL_H: float = 78.0

const _THRESHOLDS := [10, 25, 50, 75, 100, 150]
const _NAMES: Dictionary = {
	10:  "Banani-Schwarm!",
	25:  "Migros-Massaker!",
	50:  "Cumulus-Combo!",
	75:  "Aff-oltere-Apoteke!",
	100: "Bani-Apokalypse!",
	150: "DE TÜÜFEL CHUNT!",
}

var _fired: Dictionary = {}
var _panel: PanelContainer
var _label: Label
var _sb: StyleBoxFlat
var _tween: Tween


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	var vp := get_viewport_rect().size
	size = vp
	position = Vector2.ZERO
	_build_pill(vp)
	visible = false
	ComboTracker.combo_changed.connect(_on_combo_changed)


func _build_pill(vp: Vector2) -> void:
	_panel = PanelContainer.new()
	_panel.custom_minimum_size = Vector2(PILL_W, PILL_H)
	_panel.size = Vector2(PILL_W, PILL_H)
	_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Centered on screen; pivot at pill midpoint so scale pops from center.
	_panel.position = Vector2((vp.x - PILL_W) * 0.5, (vp.y - PILL_H) * 0.5)
	_panel.pivot_offset = Vector2(PILL_W * 0.5, PILL_H * 0.5)

	_sb = StyleBoxFlat.new()
	_sb.bg_color = Color(0.10, 0.07, 0.04, 0.92)
	_sb.border_color = Color(1.0, 0.82, 0.25, 1.0)
	_sb.border_width_left = 3
	_sb.border_width_right = 3
	_sb.border_width_top = 3
	_sb.border_width_bottom = 3
	_sb.corner_radius_top_left = 39
	_sb.corner_radius_top_right = 39
	_sb.corner_radius_bottom_left = 39
	_sb.corner_radius_bottom_right = 39
	_sb.content_margin_left = 24.0
	_sb.content_margin_right = 24.0
	_sb.content_margin_top = 12.0
	_sb.content_margin_bottom = 12.0
	_panel.add_theme_stylebox_override("panel", _sb)
	add_child(_panel)

	_label = Label.new()
	_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_panel.add_child(_label)


func reset_for_level() -> void:
	_fired.clear()
	if _tween:
		_tween.kill()
		_tween = null
	visible = false
	modulate.a = 1.0
	_panel.scale = Vector2.ONE


func _on_combo_changed(counter: int, _mult: float) -> void:
	# Descending so the highest unshown threshold wins if multiple are crossed.
	for t in [150, 100, 75, 50, 25, 10]:
		if counter >= t and not _fired.has(t):
			_fired[t] = true
			_show_milestone(t)
			return


func _show_milestone(threshold: int) -> void:
	var big: bool = threshold > 50
	_label.text = _NAMES[threshold]
	_label.add_theme_font_size_override("font_size", 32 if big else 26)
	_label.add_theme_color_override("font_color", Color.WHITE)
	_sb.border_color = Color(0.88, 0.08, 0.12, 1.0) if big else Color(1.0, 0.82, 0.25, 1.0)

	modulate.a = 1.0
	_panel.scale = Vector2.ONE
	visible = true

	if _tween:
		_tween.kill()
	_tween = create_tween()
	_tween.tween_property(_panel, "scale", Vector2(1.18, 1.18), 0.18) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_BACK)
	_tween.tween_property(_panel, "scale", Vector2(1.0, 1.0), 0.08) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SPRING)
	_tween.tween_interval(0.6)
	_tween.tween_property(self, "modulate:a", 0.0, 0.6) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	_tween.tween_callback(_on_bubble_done)

	var tier: int = _THRESHOLDS.find(threshold)
	SfxManager.play_combo_milestone(tier)


func _on_bubble_done() -> void:
	visible = false
	modulate.a = 1.0
	_panel.scale = Vector2.ONE
