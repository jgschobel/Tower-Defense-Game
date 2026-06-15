class_name WaveReceipt
extends Control

## Migros-style receipt overlay shown between waves.
## Slides up from the bottom-left corner (above the bottom panel, clear of the
## right-anchored SideShop). Tap or wave_started to dismiss.

const RECEIPT_W: float = 268.0
const RECEIPT_H: float = 336.0
const MARGIN: float = 14.0
# Height of the bottom HUD panel — receipt slides to just above it so it never
# covers the NextWaveButton and doesn't compete with the right-anchored shop.
const BOTTOM_PANEL_H: float = 76.0

var _is_dismissed: bool = false

# Data set before adding to scene via configure()
var _wave_num: int = 0
var _tower_stats: Array = []   # [{name, dmg, kills}] sorted desc by dmg
var _gold: int = 0
var _cumulus: int = 0
var _lives: int = 0
var _enemies: int = 0


func configure(wave_num: int, towers: Array, gold: int, cumulus: int, lives: int, enemies: int) -> void:
	_wave_num = wave_num
	_tower_stats = []
	for t in towers:
		if not ("wave_damage_dealt" in t) or not ("data" in t) or t.data == null:
			continue
		var nm: String = ""
		if "display_name" in t.data and t.data.display_name != "":
			nm = t.data.display_name
		else:
			nm = "Turm"
		_tower_stats.append({
			"name": nm,
			"dmg": t.wave_damage_dealt,
			"kills": t.wave_kill_count if "wave_kill_count" in t else 0
		})
	_tower_stats.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return a["dmg"] > b["dmg"])
	_gold = gold
	_cumulus = cumulus
	_lives = lives
	_enemies = enemies


func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(RECEIPT_W, RECEIPT_H)
	size = Vector2(RECEIPT_W, RECEIPT_H)
	var vp_size := get_viewport_rect().size
	# Bottom-left corner: keeps clear of the right-anchored SideShop so the
	# player can still see and tap shop buttons while reading the receipt.
	position = Vector2(MARGIN, vp_size.y)
	_build_panel()
	_start_slide_in()


func _build_panel() -> void:
	var panel := PanelContainer.new()
	panel.size = Vector2(RECEIPT_W, RECEIPT_H)
	panel.size_flags_vertical = Control.SIZE_EXPAND_FILL

	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.975, 0.975, 0.955)
	style.border_color = Color(0.82, 0.05, 0.12)
	style.border_width_left = 3
	style.border_width_right = 3
	style.border_width_top = 3
	style.border_width_bottom = 3
	style.corner_radius_top_left = 5
	style.corner_radius_top_right = 5
	style.corner_radius_bottom_left = 5
	style.corner_radius_bottom_right = 5
	style.content_margin_left = 14
	style.content_margin_right = 14
	style.content_margin_top = 12
	style.content_margin_bottom = 12
	panel.add_theme_stylebox_override("panel", style)
	add_child(panel)

	var label := RichTextLabel.new()
	label.bbcode_enabled = true
	label.fit_content = true
	label.scroll_active = false
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	label.size_flags_vertical = Control.SIZE_EXPAND_FILL
	label.add_theme_font_size_override("normal_font_size", 14)
	label.add_theme_font_size_override("bold_font_size", 14)
	label.add_theme_color_override("default_color", Color(0.12, 0.12, 0.12))
	label.text = _build_text()
	panel.add_child(label)


func _build_text() -> String:
	var div: String = "- - - - - - - - - - - -"
	var t: String = ""
	t += "[center][b]— MIGROS AFFOLTERN —[/b][/center]\n"
	t += "[center]Wälle %d abgschlosse[/center]\n" % _wave_num
	t += "[center]%s[/center]\n" % div

	var active_towers: Array = []
	for ts in _tower_stats:
		if (ts["dmg"] as float) > 0.0:
			active_towers.append(ts)

	if active_towers.size() > 0:
		t += "\n[b]Turm-Helden:[/b]\n"
		var medals: Array = ["🥇", "🥈", "🥉"]
		for i in mini(3, active_towers.size()):
			var ts: Dictionary = active_towers[i]
			var medal: String = medals[i] if i < medals.size() else " "
			var nm: String = ts["name"]
			var dmg_val: int = int(ts["dmg"] as float)
			var kills_val: int = int(ts["kills"])
			var kills_str: String = " / %d K.O." % kills_val if kills_val > 0 else ""
			t += "%s %s — %d Schade%s\n" % [medal, nm, dmg_val, kills_str]
	else:
		t += "\n[i](Kei Turm het gschossen)[/i]\n"

	t += "\n[center]%s[/center]\n" % div
	t += "K.O.s:       [b]%d[/b] Feinde\n" % _enemies
	t += "Gwünne:   [b]%d[/b] Gold\n" % _gold
	t += "Cumulus:   [b]%d ★[/b]\n" % _cumulus
	t += "[center]%s[/center]\n" % div
	t += "Läbe übrig: [b]%d ♥[/b]\n" % _lives
	t += "\n[center][i]Danke vil mal! 🇨🇭[/i][/center]\n"
	t += "[center][color=#aaaaaa]✂  ✂  ✂[/color][/center]"
	return t


func _start_slide_in() -> void:
	var vp_size := get_viewport_rect().size
	# Park above the bottom panel so the NextWaveButton stays reachable.
	var target_y := vp_size.y - BOTTOM_PANEL_H - RECEIPT_H - MARGIN
	var tween := create_tween().set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "position:y", target_y, 0.45)


func dismiss() -> void:
	if _is_dismissed:
		return
	_is_dismissed = true
	var vp_size := get_viewport_rect().size
	var off_y := vp_size.y + RECEIPT_H + 20.0
	var tween := create_tween().set_trans(Tween.TRANS_EXPO).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "position:y", off_y, 0.22)
	tween.tween_callback(queue_free)


func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch and event.pressed:
		dismiss()
	elif event is InputEventMouseButton and event.pressed:
		dismiss()
