extends Control

## Developer design viewer + variant picker.
##
## Tabs:
##   • Monster — every enemy in 4 damage states (healthy/hurt/injured/dying)
##   • Türm    — every tower across path × tier matrix (5 towers × 2 paths × 4 tiers)
##   • Variante — 30 alternative tower designs (when art #258 lands) for picking
##
## Variant picks persist to user://variants.json and apply at runtime via
## GameManager.get_preferred_variant("category/asset_id").

const PREFS_PATH := "user://variants.json"
const TOWER_IDS := ["basic", "sniper", "splash", "cordula", "slow"]
const TOWER_DISPLAY := {"basic": "Lemurius", "sniper": "Kühne", "splash": "JoJo", "cordula": "Cordula", "slow": "Amösius"}
const ENEMY_IDS := ["basic", "fast", "tank", "healer", "flying", "swarm", "boss"]
const ENEMY_DISPLAY := {"basic": "Brötli", "fast": "Toblerone", "tank": "Cervelat", "healer": "Dr. Rivella", "flying": "Fondue", "swarm": "Tofu", "boss": "M-Tüüfel"}
const DAMAGE_STATES := ["healthy", "hurt", "injured", "dying"]
const DAMAGE_LABELS := ["100%", "66%", "33%", "10%"]
const DAMAGE_TINTS := [Color.WHITE, Color(0.95, 0.85, 0.80), Color(0.85, 0.65, 0.55), Color(0.70, 0.40, 0.35)]

var _prefs: Dictionary = {}
var _content_root: VBoxContainer = null
var _current_tab: String = "monsters"


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = DesignTokens.COL_BG_DEEPEST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_load_prefs()
	_build_shell()
	_show_tab(_current_tab)


# ---------- Shell (header + tabs + content area) ----------

func _build_shell() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = DesignTokens.SP_L
	root.offset_right = -DesignTokens.SP_L
	root.offset_top = DesignTokens.SP_M
	root.offset_bottom = -DesignTokens.SP_M
	root.add_theme_constant_override("separation", DesignTokens.SP_M)
	add_child(root)

	# Header row: title + back button
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DesignTokens.SP_M)
	root.add_child(header)
	var title := Label.new()
	title.text = "DEV — Design Viewer"
	DesignTokens.style_heading(title, DesignTokens.FONT_HEADING)
	title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(title)
	var back := Button.new()
	back.text = "← Zrugg"
	DesignTokens.style_button(back, false, DesignTokens.FONT_LABEL)
	back.pressed.connect(func():
		SfxManager.play_click()
		_save_prefs()
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	header.add_child(back)

	# Tab strip
	var tabs := HBoxContainer.new()
	tabs.add_theme_constant_override("separation", DesignTokens.SP_S)
	root.add_child(tabs)
	for cfg in [
		{"id": "monsters", "label": "Monster"},
		{"id": "towers",   "label": "Türm (Pfad × Tier)"},
		{"id": "variants", "label": "Variante (Picker)"},
	]:
		var tab_btn := Button.new()
		tab_btn.text = cfg.label
		tab_btn.custom_minimum_size = Vector2(160, 40)
		DesignTokens.style_button(tab_btn, cfg.id == _current_tab, DesignTokens.FONT_LABEL)
		tab_btn.pressed.connect(_show_tab.bind(cfg.id))
		tabs.add_child(tab_btn)

	# Scrollable content area
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)
	_content_root = VBoxContainer.new()
	_content_root.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_content_root.add_theme_constant_override("separation", DesignTokens.SP_XL)
	scroll.add_child(_content_root)


func _show_tab(tab_id: String) -> void:
	if tab_id != _current_tab:
		SfxManager.play_click()
	_current_tab = tab_id
	# Rebuild header tabs to update active state
	for c in get_children():
		if c is VBoxContainer:
			c.queue_free()
	_build_shell()
	# Now populate the chosen tab
	for c in _content_root.get_children():
		c.queue_free()
	match tab_id:
		"monsters": _populate_monsters_tab()
		"towers":   _populate_towers_tab()
		"variants": _populate_variants_tab()


# ---------- Monsters tab ----------

func _populate_monsters_tab() -> void:
	var hint := Label.new()
	hint.text = "Jede Reihe = ein Monster i de 4 Damage-States. Bilder mit Punkt sind Platzhalter (Tint überm Original) bis Art-Request #257 im Repo isch."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(hint, DesignTokens.FONT_LABEL_SM, true)
	_content_root.add_child(hint)
	var grid_header := _build_grid_header(["Monster"] + DAMAGE_LABELS)
	_content_root.add_child(grid_header)
	for enemy_id in ENEMY_IDS:
		_content_root.add_child(_build_monster_row(enemy_id))


func _build_monster_row(enemy_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	# Name column
	var name_lbl := Label.new()
	name_lbl.text = ENEMY_DISPLAY.get(enemy_id, enemy_id)
	name_lbl.custom_minimum_size = Vector2(120, 96)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	row.add_child(name_lbl)
	# Try real variants first, fall back to tinted base sprite
	var base_tex := _load_enemy_base_texture(enemy_id)
	for i in DAMAGE_STATES.size():
		var state := DAMAGE_STATES[i]
		var variant_path := "res://assets/textures/variants/enemies/%s/%s_state%d_%s.png" % [enemy_id, enemy_id, i, state]
		var has_variant := ResourceLoader.exists(variant_path)
		var thumb := _build_thumb(
			load(variant_path) if has_variant else base_tex,
			DAMAGE_TINTS[i] if not has_variant else Color.WHITE
		)
		row.add_child(thumb)
	return row


func _load_enemy_base_texture(enemy_id: String) -> Texture2D:
	var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
	if not ResourceLoader.exists(data_path):
		return null
	var ed = load(data_path)
	if ed and "custom_texture" in ed and ed.custom_texture is Texture2D:
		return ed.custom_texture
	return null


# ---------- Towers tab ----------

func _populate_towers_tab() -> void:
	var hint := Label.new()
	hint.text = "Jede Reihe = ein Turm. Spalten zeigend: Base Icon, Path A Tier 1/2/3, Path B Tier 1/2/3. T3 sind aktuelli Sprites (basic_t3a.png etc.); T0-T2 sind Tint-Vorschau (Engine zeigt Pfad-Tint überm Base-Sprite). Variante wähle = «Variante» Tab."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(hint, DesignTokens.FONT_LABEL_SM, true)
	_content_root.add_child(hint)
	var grid_header := _build_grid_header(["Turm", "Base", "A1", "A2", "A3", "B1", "B2", "B3"])
	_content_root.add_child(grid_header)
	for tower_id in TOWER_IDS:
		_content_root.add_child(_build_tower_row(tower_id))


func _build_tower_row(tower_id: String) -> Control:
	var data_path := "res://resources/tower_data/%s.tres" % tower_id
	if not ResourceLoader.exists(data_path):
		return Control.new()
	var td = load(data_path)
	var base_tex := td.custom_texture if "custom_texture" in td else null
	var path_a_tint: Color = td.path_a_tint if "path_a_tint" in td else Color.WHITE
	var path_b_tint: Color = td.path_b_tint if "path_b_tint" in td else Color.WHITE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	# Name column
	var name_lbl := Label.new()
	name_lbl.text = TOWER_DISPLAY.get(tower_id, tower_id)
	name_lbl.custom_minimum_size = Vector2(120, 96)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	row.add_child(name_lbl)
	# Base column (tier 0)
	row.add_child(_build_thumb(base_tex, Color.WHITE))
	# Path A tiers 1-3
	for tier in [1, 2, 3]:
		var t3_path := "res://assets/textures/towers/%s_t3a.png" % tower_id
		var tier_tex: Texture2D = base_tex
		if tier == 3 and ResourceLoader.exists(t3_path):
			tier_tex = load(t3_path)
		# Tier 1/2 share base texture; tint applied to convey path identity
		var tint: Color = path_a_tint if tier < 3 else Color.WHITE
		row.add_child(_build_thumb(tier_tex, tint, "A%d" % tier))
	# Path B tiers 1-3
	for tier in [1, 2, 3]:
		var t3_path := "res://assets/textures/towers/%s_t3b.png" % tower_id
		var tier_tex: Texture2D = base_tex
		if tier == 3 and ResourceLoader.exists(t3_path):
			tier_tex = load(t3_path)
		var tint: Color = path_b_tint if tier < 3 else Color.WHITE
		row.add_child(_build_thumb(tier_tex, tint, "B%d" % tier))
	return row


# ---------- Variants tab (filesystem-driven 30-design picker) ----------

func _populate_variants_tab() -> void:
	var hint := Label.new()
	hint.text = "Klick uf en Variante zum si als Standard merka. Variante chömed vom Gemini Art-Request #258 (30 Tower-Designs) und werden i de Spil über GameManager.get_preferred_variant() benutzt."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(hint, DesignTokens.FONT_LABEL_SM, true)
	_content_root.add_child(hint)
	var categories := _discover_categories()
	if categories.is_empty():
		var empty := Label.new()
		empty.text = "(Kei Variante im Repo. Wart bis art-request workflow d'Bilder gschickt het oder file zusätzlichi Issues.)"
		DesignTokens.style_label(empty, DesignTokens.FONT_LABEL, true)
		_content_root.add_child(empty)
		return
	for category in categories:
		_content_root.add_child(_build_variant_section(category))


func _discover_categories() -> Array:
	var out: Array = []
	var dir := DirAccess.open("res://assets/textures/variants")
	if dir == null:
		dir = DirAccess.open("res://assets/variants")
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var cat_path := dir.get_current_dir() + "/" + entry
			out.append({"name": entry, "assets": _discover_assets(cat_path)})
		entry = dir.get_next()
	return out


func _discover_assets(category_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(category_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			var asset_path := category_path + "/" + entry
			out.append({"id": entry, "variants": _list_pngs(asset_path)})
		entry = dir.get_next()
	return out


func _list_pngs(folder: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(folder)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".png"):
			out.append(folder + "/" + entry)
		entry = dir.get_next()
	out.sort()
	return out


func _build_variant_section(category: Dictionary) -> Control:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", DesignTokens.SP_S)
	var heading := Label.new()
	heading.text = "▸ " + str(category.name).capitalize()
	DesignTokens.style_heading(heading, DesignTokens.FONT_LABEL_LG)
	section.add_child(heading)
	for asset in category.assets:
		section.add_child(_build_variant_asset_row(category.name, asset))
	return section


func _build_variant_asset_row(category: String, asset: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var name_lbl := Label.new()
	name_lbl.text = TOWER_DISPLAY.get(asset.id, asset.id) if category == "towers" else str(asset.id)
	name_lbl.custom_minimum_size = Vector2(120, 0)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_SM)
	row.add_child(name_lbl)
	var pref_key := "%s/%s" % [category, asset.id]
	var current_pref: String = _prefs.get(pref_key, "")
	for variant_path in asset.variants:
		row.add_child(_build_variant_button(pref_key, variant_path, variant_path == current_pref))
	return row


func _build_variant_button(pref_key: String, variant_path: String, is_selected: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 96)
	btn.flat = true
	btn.icon = load(variant_path)
	btn.expand_icon = true
	var sb := StyleBoxFlat.new()
	sb.bg_color = DesignTokens.COL_BG_RAISED
	sb.border_color = DesignTokens.COL_STROKE_STRONG if is_selected else DesignTokens.COL_STROKE_FAINT
	sb.border_width_left = 3 if is_selected else 1
	sb.border_width_right = 3 if is_selected else 1
	sb.border_width_top = 3 if is_selected else 1
	sb.border_width_bottom = 3 if is_selected else 1
	sb.corner_radius_top_left = DesignTokens.RADIUS_S
	sb.corner_radius_top_right = DesignTokens.RADIUS_S
	sb.corner_radius_bottom_left = DesignTokens.RADIUS_S
	sb.corner_radius_bottom_right = DesignTokens.RADIUS_S
	btn.add_theme_stylebox_override("normal", sb)
	btn.add_theme_stylebox_override("hover", sb)
	btn.add_theme_stylebox_override("pressed", sb)
	btn.tooltip_text = variant_path.get_file()
	btn.pressed.connect(func():
		SfxManager.play_click()
		_prefs[pref_key] = variant_path
		_save_prefs()
		_show_tab(_current_tab))
	return btn


# ---------- Shared widgets ----------

func _build_grid_header(columns: Array) -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DesignTokens.SP_S)
	for i in columns.size():
		var lbl := Label.new()
		lbl.text = str(columns[i])
		lbl.custom_minimum_size = Vector2(120, 28) if i == 0 else Vector2(96, 28)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		DesignTokens.style_label(lbl, DesignTokens.FONT_LABEL_SM, true)
		header.add_child(lbl)
	return header


func _build_thumb(tex: Texture2D, tint: Color = Color.WHITE, badge: String = "") -> Control:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(96, 96)
	panel.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_XS))
	if tex == null:
		var missing := Label.new()
		missing.text = "—"
		missing.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		missing.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
		DesignTokens.style_label(missing, DesignTokens.FONT_LABEL, true)
		panel.add_child(missing)
		return panel
	var frame := Control.new()
	panel.add_child(frame)
	var icon := TextureRect.new()
	icon.texture = tex
	icon.modulate = tint
	icon.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	icon.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	icon.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	icon.mouse_filter = Control.MOUSE_FILTER_IGNORE
	frame.add_child(icon)
	if badge != "":
		var badge_lbl := Label.new()
		badge_lbl.text = badge
		badge_lbl.add_theme_font_size_override("font_size", DesignTokens.FONT_LABEL_XS)
		badge_lbl.add_theme_color_override("font_color", DesignTokens.COL_TEXT_HEADING)
		badge_lbl.add_theme_color_override("font_outline_color", Color.BLACK)
		badge_lbl.add_theme_constant_override("outline_size", 2)
		badge_lbl.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
		badge_lbl.offset_left = 4
		badge_lbl.offset_top = 2
		badge_lbl.mouse_filter = Control.MOUSE_FILTER_IGNORE
		frame.add_child(badge_lbl)
	return panel


func _load_prefs() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var f := FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f == null:
		return
	var parsed = JSON.parse_string(f.get_as_text())
	if parsed is Dictionary:
		_prefs = parsed


func _save_prefs() -> void:
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_prefs))
