extends Control

## Developer design review hub.
##
## Tabs:
##   • Monster   — every enemy in 4 damage states + stats
##   • Türm      — every tower across path × tier matrix + stats
##   • Variante  — variant picker (assets/textures/variants/...)
##   • Maps      — every level background (all 10) with path overlay preview
##   • Icons     — every emoji + UI glyph rendered side-by-side
##   • Audio     — SFX preview (click any to play)
##   • Palette   — DesignTokens color swatches with hex + use-cases
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

# Every emoji / glyph the game currently uses anywhere in UI strings.
# Listed here so user can see at a glance which render properly via
# the Noto Emoji fallback and which still tofu-out.
const EMOJI_CATALOG := [
	{"glyph": "★", "name": "star_filled",     "where": "main menu Sterne, lock cap"},
	{"glyph": "☆", "name": "star_empty",      "where": "level select rating"},
	{"glyph": "✦", "name": "sparkle_4",       "where": "Bereit prefix, gold floater"},
	{"glyph": "✨", "name": "sparkle_3",       "where": "Aminos title"},
	{"glyph": "✓", "name": "check_thin",      "where": "placement valid"},
	{"glyph": "✕", "name": "x_thin",          "where": "placement invalid"},
	{"glyph": "✖", "name": "x_heavy",         "where": "sell confirm"},
	{"glyph": "✅", "name": "check_box",       "where": "Aminos owned"},
	{"glyph": "🔒", "name": "lock",            "where": "shop locked towers"},
	{"glyph": "🔓", "name": "unlock",          "where": "(unused, planned)"},
	{"glyph": "🪙", "name": "coin",            "where": "sell button"},
	{"glyph": "💰", "name": "money_bag",       "where": "Aminos gold node"},
	{"glyph": "❤", "name": "heart",            "where": "Aminos life node"},
	{"glyph": "❤️", "name": "heart_emoji",     "where": "alt heart"},
	{"glyph": "⚔", "name": "swords",           "where": "Kills counter"},
	{"glyph": "⚠", "name": "warn",             "where": "BOSS warning, threat"},
	{"glyph": "🛒", "name": "cart",             "where": "Aminos discount"},
	{"glyph": "⚡", "name": "lightning",        "where": "Aminos upgrade"},
	{"glyph": "🌾", "name": "wheat",            "where": "Aminos farm"},
	{"glyph": "🎯", "name": "target",           "where": "Aminos crit"},
	{"glyph": "🍌", "name": "banana",           "where": "Aminos pierce"},
	{"glyph": "🏰", "name": "castle",           "where": "shop TÜRM header"},
	{"glyph": "🚨", "name": "rotating_light",   "where": "(planned: emergency)"},
	{"glyph": "💎", "name": "gem",              "where": "(planned: rare drops)"},
	{"glyph": "🔥", "name": "fire",             "where": "(planned: burn DoT)"},
	{"glyph": "❄", "name": "snowflake",         "where": "(planned: freeze)"},
	{"glyph": "💀", "name": "skull",            "where": "(planned: death)"},
	{"glyph": "🎮", "name": "controller",       "where": "(planned: input hints)"},
	{"glyph": "▶", "name": "play_triangle",    "where": "(planned: speed up)"},
	{"glyph": "⏸", "name": "pause_two_bars",   "where": "(planned: pause)"},
]

# All SFX exposed by SfxManager — Audio tab renders one button per entry.
const SFX_CATALOG := [
	{"label": "Shoot (basic / Lemurius t0)", "fn": "play_shoot", "args": ["basic", 0]},
	{"label": "Shoot (sniper / Kühne t2)",   "fn": "play_shoot", "args": ["sniper", 2]},
	{"label": "Shoot (splash / JoJo t1)",    "fn": "play_shoot", "args": ["splash", 1]},
	{"label": "Generic hit",                 "fn": "play_hit",   "args": []},
	{"label": "Enemy hit (Brötli)",          "fn": "play_enemy_hit", "args": ["basic"]},
	{"label": "Enemy hit (Cervelat)",        "fn": "play_enemy_hit", "args": ["tank"]},
	{"label": "Enemy hit (Boss)",            "fn": "play_enemy_hit", "args": ["boss"]},
	{"label": "Death (small)",               "fn": "play_death", "args": [50.0]},
	{"label": "Death (huge)",                "fn": "play_death", "args": [800.0]},
	{"label": "Wave start",                  "fn": "play_wave_start", "args": []},
	{"label": "Upgrade",                     "fn": "play_upgrade", "args": []},
	{"label": "Click (UI)",                  "fn": "play_click", "args": []},
	{"label": "Soft pluck (typewriter)",     "fn": "play_soft_pluck", "args": []},
	{"label": "Sell",                        "fn": "play_sell", "args": []},
	{"label": "Place",                       "fn": "play_place", "args": []},
	{"label": "Boss roar",                   "fn": "play_boss_roar", "args": []},
	{"label": "Life lost",                   "fn": "play_life_lost", "args": []},
]

# Every named color in DesignTokens with use-case for review.
const PALETTE_CATALOG := [
	{"name": "COL_BG_DEEPEST",    "where": "full-screen backdrop"},
	{"name": "COL_BG_PANEL",      "where": "tower-info, pause, aminos panels"},
	{"name": "COL_BG_RAISED",     "where": "buttons (default state)"},
	{"name": "COL_BG_HOVER",      "where": "buttons (hover state)"},
	{"name": "COL_BG_PRESSED",    "where": "buttons (pressed state)"},
	{"name": "COL_STROKE_FAINT",  "where": "subtle dividers"},
	{"name": "COL_STROKE_NORMAL", "where": "secondary borders"},
	{"name": "COL_STROKE_STRONG", "where": "primary CTA borders (gold)"},
	{"name": "COL_STROKE_HOVER",  "where": "hover border highlight"},
	{"name": "COL_TEXT_PRIMARY",  "where": "body text"},
	{"name": "COL_TEXT_HEADING",  "where": "headings, titles"},
	{"name": "COL_TEXT_MUTED",    "where": "secondary text"},
	{"name": "COL_TEXT_DISABLED", "where": "disabled labels"},
	{"name": "COL_OK",            "where": "success states"},
	{"name": "COL_WARN",          "where": "warnings"},
	{"name": "COL_BAD",           "where": "errors / damage"},
	{"name": "COL_GOLD",          "where": "currency, accents"},
]

var _prefs: Dictionary = {}
var _content_root: VBoxContainer = null
var _current_tab: String = "monsters"


func _ready() -> void:
	# Force-fit to viewport — when DevMenu is the current scene, the
	# root Control should be 1280×720 but anchors-only sizing can
	# collapse to 0×0 in some Godot versions, which is what the user
	# saw ("grey screen with nothing"). Explicit size kills the bug.
	_fit_viewport()
	get_viewport().size_changed.connect(_fit_viewport)
	var bg := ColorRect.new()
	bg.color = DesignTokens.COL_BG_DEEPEST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(bg)
	# Emergency fallback button — always visible top-left so the user can
	# escape even if the rest of the build fails to render. Was: grey
	# screen with no way out. This guarantees AT LEAST a back button.
	var emergency_back := Button.new()
	emergency_back.text = "← Zrugg (emergency)"
	emergency_back.set_anchors_and_offsets_preset(Control.PRESET_TOP_LEFT)
	emergency_back.offset_left = 10
	emergency_back.offset_top = 10
	emergency_back.offset_right = 220
	emergency_back.offset_bottom = 50
	emergency_back.pressed.connect(func():
		get_tree().change_scene_to_file("res://scenes/ui/main_menu.tscn"))
	add_child(emergency_back)
	_load_prefs()
	_build_shell()
	# Populate the initial tab DIRECTLY — calling _show_tab here would
	# rebuild the shell we just built and leak the _content_root reference.
	_populate_active_tab()


func _fit_viewport() -> void:
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	size = vp_size
	position = Vector2.ZERO


func _populate_active_tab() -> void:
	if _content_root == null:
		return
	for c in _content_root.get_children():
		c.queue_free()
	match _current_tab:
		"monsters": _populate_monsters_tab()
		"towers":   _populate_towers_tab()
		"variants": _populate_variants_tab()
		"maps":     _populate_maps_tab()
		"icons":    _populate_icons_tab()
		"audio":    _populate_audio_tab()
		"palette":  _populate_palette_tab()


# ---------- Shell ----------

func _build_shell() -> void:
	var root := VBoxContainer.new()
	root.name = "Shell"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = DesignTokens.SP_L
	root.offset_right = -DesignTokens.SP_L
	root.offset_top = DesignTokens.SP_M
	root.offset_bottom = -DesignTokens.SP_M
	root.add_theme_constant_override("separation", DesignTokens.SP_M)
	add_child(root)

	# Header — title + back
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DesignTokens.SP_M)
	root.add_child(header)
	var title := Label.new()
	title.text = "DEV — Design Review Hub"
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

	# Tab strip — wraps so all 7 tabs fit on phone
	var tabs := HFlowContainer.new()
	tabs.add_theme_constant_override("h_separation", DesignTokens.SP_S)
	tabs.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	root.add_child(tabs)
	for cfg in [
		{"id": "monsters", "label": "Monster"},
		{"id": "towers",   "label": "Türm × Tier"},
		{"id": "variants", "label": "Variante"},
		{"id": "maps",     "label": "Maps"},
		{"id": "icons",    "label": "Icons & Emoji"},
		{"id": "audio",    "label": "Audio"},
		{"id": "palette",  "label": "Palette"},
	]:
		var tab_btn := Button.new()
		tab_btn.text = cfg.label
		tab_btn.custom_minimum_size = Vector2(140, 36)
		DesignTokens.style_button(tab_btn, cfg.id == _current_tab, DesignTokens.FONT_LABEL_SM)
		tab_btn.pressed.connect(_show_tab.bind(cfg.id))
		tabs.add_child(tab_btn)

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
	# Rebuild shell to refresh active-tab button styling. queue_free is
	# deferred — the freshly-built Shell stays valid until end of frame.
	# We rebuild Shell AND then re-populate via _populate_active_tab so
	# _content_root always points at the current Shell's content node.
	for c in get_children():
		if c.name == "Shell":
			c.queue_free()
	_build_shell()
	_populate_active_tab()


# ---------- Tab: Monster ----------

func _populate_monsters_tab() -> void:
	_add_hint("Jede Reihe = ein Monster i de 4 Damage-States. Bilder mit Farb-Tönt sind Platzhalter bis Art-Request #257 land. Drunder zeigt's HP / Speed / Gold-Reward us em .tres.")
	_content_root.add_child(_build_grid_header(["Monster", "100%", "66%", "33%", "10%", "Stats"]))
	for enemy_id in ENEMY_IDS:
		_content_root.add_child(_build_monster_row(enemy_id))


func _build_monster_row(enemy_id: String) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var name_lbl := Label.new()
	name_lbl.text = ENEMY_DISPLAY.get(enemy_id, enemy_id)
	name_lbl.custom_minimum_size = Vector2(120, 96)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	row.add_child(name_lbl)
	var base_tex := _load_enemy_base_texture(enemy_id)
	for i in DAMAGE_STATES.size():
		var state: String = DAMAGE_STATES[i]
		var variant_path := "res://assets/textures/variants/enemies/%s/%s_state%d_%s.png" % [enemy_id, enemy_id, i, state]
		var has_variant := ResourceLoader.exists(variant_path)
		var thumb := _build_thumb(
			load(variant_path) if has_variant else base_tex,
			DAMAGE_TINTS[i] if not has_variant else Color.WHITE
		)
		row.add_child(thumb)
	# Stats column (read from .tres)
	var stats_lbl := Label.new()
	var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
	if ResourceLoader.exists(data_path):
		var ed = load(data_path)
		stats_lbl.text = "HP %d · Spd %d · G %d" % [int(ed.max_health), int(ed.move_speed), int(ed.gold_reward)]
	else:
		stats_lbl.text = "(no data)"
	stats_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_lbl.custom_minimum_size = Vector2(180, 96)
	DesignTokens.style_label(stats_lbl, DesignTokens.FONT_LABEL_SM, true)
	row.add_child(stats_lbl)
	return row


func _load_enemy_base_texture(enemy_id: String) -> Texture2D:
	var data_path := "res://resources/enemy_data/%s.tres" % enemy_id
	if not ResourceLoader.exists(data_path):
		return null
	var ed = load(data_path)
	if ed and "custom_texture" in ed and ed.custom_texture is Texture2D:
		return ed.custom_texture
	return null


# ---------- Tab: Türm × Tier ----------

func _populate_towers_tab() -> void:
	_add_hint("Jede Reihe = ein Turm. Spalten: Base / A1 / A2 / A3 / B1 / B2 / B3 + Stats. T0-T2 sind Tint-Vorschau bis Art #263 land. Variante wähle = «Variante» Tab.")
	_content_root.add_child(_build_grid_header(["Turm", "Base", "A1", "A2", "A3", "B1", "B2", "B3", "Stats"]))
	for tower_id in TOWER_IDS:
		_content_root.add_child(_build_tower_row(tower_id))


func _build_tower_row(tower_id: String) -> Control:
	var data_path := "res://resources/tower_data/%s.tres" % tower_id
	if not ResourceLoader.exists(data_path):
		return Control.new()
	var td = load(data_path)
	var base_tex: Texture2D = td.custom_texture if "custom_texture" in td else null
	var path_a_tint: Color = td.path_a_tint if "path_a_tint" in td else Color.WHITE
	var path_b_tint: Color = td.path_b_tint if "path_b_tint" in td else Color.WHITE
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var name_lbl := Label.new()
	name_lbl.text = TOWER_DISPLAY.get(tower_id, tower_id)
	name_lbl.custom_minimum_size = Vector2(120, 96)
	name_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	row.add_child(name_lbl)
	row.add_child(_build_thumb(base_tex, Color.WHITE))
	for tier in [1, 2, 3]:
		row.add_child(_build_tower_tier_thumb(tower_id, "a", tier, base_tex, path_a_tint))
	for tier in [1, 2, 3]:
		row.add_child(_build_tower_tier_thumb(tower_id, "b", tier, base_tex, path_b_tint))
	# Stats
	var stats_lbl := Label.new()
	stats_lbl.text = "%d G · DMG %d · RNG %d" % [int(td.buy_cost), int(td.damage), int(td.attack_range)]
	stats_lbl.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	stats_lbl.custom_minimum_size = Vector2(180, 96)
	DesignTokens.style_label(stats_lbl, DesignTokens.FONT_LABEL_SM, true)
	row.add_child(stats_lbl)
	return row


func _build_tower_tier_thumb(tower_id: String, path: String, tier: int, base_tex: Texture2D, tint: Color) -> Control:
	var tier_path := "res://assets/textures/towers/%s_t%d%s.png" % [tower_id, tier, path]
	var has_real := ResourceLoader.exists(tier_path)
	var tex: Texture2D = load(tier_path) if has_real else base_tex
	var apply_tint: Color = Color.WHITE if has_real else tint
	return _build_thumb(tex, apply_tint, "%s%d" % [path.to_upper(), tier])


# ---------- Tab: Variants picker ----------

func _populate_variants_tab() -> void:
	_add_hint("Klick uf en Variante zum si als Standard merka. Variante chömed vom Gemini Art-Request #258. Selektion persistiert i user://variants.json.")
	var categories := _discover_variant_categories()
	if categories.is_empty():
		_add_hint("(Kei Variante im Repo. Wart bis art-request workflow d'Bilder gschickt het.)")
		return
	for category in categories:
		_content_root.add_child(_build_variant_section(category))


func _discover_variant_categories() -> Array:
	var out: Array = []
	var roots := ["res://assets/textures/variants", "res://assets/variants"]
	for r in roots:
		var dir := DirAccess.open(r)
		if dir == null:
			continue
		dir.list_dir_begin()
		var entry := dir.get_next()
		while entry != "":
			if dir.current_is_dir() and not entry.begins_with("."):
				out.append({"name": entry, "assets": _discover_variant_assets(r + "/" + entry)})
			entry = dir.get_next()
	return out


func _discover_variant_assets(category_path: String) -> Array:
	var out: Array = []
	var dir := DirAccess.open(category_path)
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			out.append({"id": entry, "variants": _list_pngs(category_path + "/" + entry)})
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


# ---------- Tab: Maps ----------

func _populate_maps_tab() -> void:
	_add_hint("Alli 10 Level Backgrounds. Klick uf ä Karte zum d'aktuelli .png direkt aafrage. Path-Kurve isch's gelb-orangi Linie überm Bild — mues no ins Art-Generation iibäue (siehe Issue #215-#222).")
	for level_id in range(1, 11):
		_content_root.add_child(_build_map_row(level_id))


func _build_map_row(level_id: int) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", DesignTokens.SP_XS)
	var heading := Label.new()
	heading.text = "Level %d — %s" % [level_id, _level_display_name(level_id)]
	DesignTokens.style_label(heading, DesignTokens.FONT_LABEL_LG)
	section.add_child(heading)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	section.add_child(row)
	# Find the texture used by level_N.tscn (maps_v3 path)
	var bg_paths := [
		"res://assets/textures/maps_v3/level_%d_obst.png" % level_id,
		"res://assets/textures/maps_v3/level_%d_tiefkuehl.png" % level_id,
		"res://assets/textures/maps_v3/level_%d_chemikalien.png" % level_id,
		"res://assets/textures/maps_v3/level_%d_baeckerei.png" % level_id,
		"res://assets/textures/maps_v3/level_%d_metzgerei.png" % level_id,
		"res://assets/textures/maps_v3/level_%d_parkhaus.png" % level_id,
		"res://assets/textures/maps_v3/level_%d_dach.png" % level_id,
	]
	var found_path := ""
	for p in bg_paths:
		if ResourceLoader.exists(p):
			found_path = p
			break
	# Fallback: scan maps_v3 for files matching level_N
	if found_path == "":
		var dir := DirAccess.open("res://assets/textures/maps_v3")
		if dir:
			dir.list_dir_begin()
			var entry := dir.get_next()
			while entry != "":
				if entry.begins_with("level_%d_" % level_id) and entry.ends_with(".png"):
					found_path = "res://assets/textures/maps_v3/" + entry
					break
				entry = dir.get_next()
	# Big preview thumb
	var preview := PanelContainer.new()
	preview.custom_minimum_size = Vector2(360, 200)
	preview.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_XS))
	if found_path != "":
		var tex_rect := TextureRect.new()
		tex_rect.texture = load(found_path)
		tex_rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		preview.add_child(tex_rect)
	else:
		var missing := Label.new()
		missing.text = "(no texture found)"
		preview.add_child(missing)
	row.add_child(preview)
	# Info column
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", DesignTokens.SP_XS)
	var path_lbl := Label.new()
	path_lbl.text = "Texture: %s" % (found_path if found_path != "" else "(missing)")
	DesignTokens.style_label(path_lbl, DesignTokens.FONT_LABEL_SM, true)
	info.add_child(path_lbl)
	var data_path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(data_path):
		var ld = load(data_path)
		var meta := Label.new()
		meta.text = "Waves: %d · Start gold: %d · Lives: %d" % [ld.waves.size() if ld.waves else 0, ld.starting_gold, ld.starting_lives]
		DesignTokens.style_label(meta, DesignTokens.FONT_LABEL_SM)
		info.add_child(meta)
	row.add_child(info)
	return section


func _level_display_name(level_id: int) -> String:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if ResourceLoader.exists(path):
		var ld = load(path)
		return ld.level_name if "level_name" in ld and ld.level_name != "" else "Level %d" % level_id
	return "Level %d" % level_id


# ---------- Tab: Icons & Emoji ----------

func _populate_icons_tab() -> void:
	# Section 1: SVG icon library (the real shipped assets)
	_add_hint("SVG Icons us assets/icons/ — keine Font-Fallback nötig, scaled crisp uf jedi DPI. Diese ersetze d'Emoji im UI.")
	var svg_section := Label.new()
	svg_section.text = "▸ SVG Icon Library (claude-designed, in assets/icons/)"
	DesignTokens.style_heading(svg_section, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(svg_section)
	var svg_grid := GridContainer.new()
	svg_grid.columns = 6
	svg_grid.add_theme_constant_override("h_separation", DesignTokens.SP_M)
	svg_grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(svg_grid)
	for icon_name in IconLibrary.NAMES:
		svg_grid.add_child(_build_svg_icon_card(icon_name))
	# Section 2: legacy emoji catalog
	var emoji_section := Label.new()
	emoji_section.text = "▸ Emoji & Glyphs verwendet im UI (font-rendered)"
	DesignTokens.style_heading(emoji_section, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(emoji_section)
	var grid := GridContainer.new()
	grid.columns = 4
	grid.add_theme_constant_override("h_separation", DesignTokens.SP_M)
	grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(grid)
	for entry in EMOJI_CATALOG:
		grid.add_child(_build_emoji_card(entry))


func _build_svg_icon_card(icon_name: String) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(120, 90)
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var col := VBoxContainer.new()
	col.alignment = BoxContainer.ALIGNMENT_CENTER
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	col.add_child(IconLibrary.make_rect(icon_name, 48))
	var lbl := Label.new()
	lbl.text = icon_name
	lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DesignTokens.style_label(lbl, DesignTokens.FONT_LABEL_XS, true)
	col.add_child(lbl)
	return card


func _build_emoji_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(200, 80)
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", DesignTokens.SP_S)
	card.add_child(inner)
	# Big glyph
	var big := Label.new()
	big.text = str(entry.glyph)
	big.add_theme_font_size_override("font_size", 36)
	big.custom_minimum_size = Vector2(48, 48)
	big.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	inner.add_child(big)
	# Name + where
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = str(entry.name)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_SM)
	col.add_child(name_lbl)
	var where_lbl := Label.new()
	where_lbl.text = str(entry.where)
	where_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(where_lbl, DesignTokens.FONT_LABEL_XS, true)
	col.add_child(where_lbl)
	inner.add_child(col)
	return card


# ---------- Tab: Audio ----------

func _populate_audio_tab() -> void:
	_add_hint("Klick ä Knopf zum dä SFX direkt höre. Falls eine doof tönt, säg's mir und I tausch en us.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SP_M)
	grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(grid)
	for entry in SFX_CATALOG:
		grid.add_child(_build_sfx_button(entry))


func _build_sfx_button(entry: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = "▶ " + str(entry.label)
	btn.custom_minimum_size = Vector2(0, 44)
	DesignTokens.style_button(btn, false, DesignTokens.FONT_LABEL_SM)
	btn.pressed.connect(func():
		if SfxManager and SfxManager.has_method(entry.fn):
			SfxManager.callv(entry.fn, entry.args))
	return btn


# ---------- Tab: Palette ----------

func _populate_palette_tab() -> void:
	_add_hint("Alli Farb-Tokens us scripts/systems/design_tokens.gd. Hex-Wert isch klikbar zum kopiere (Browser).")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SP_M)
	grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(grid)
	for entry in PALETTE_CATALOG:
		grid.add_child(_build_palette_card(entry))


func _build_palette_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(380, 80)
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var inner := HBoxContainer.new()
	inner.add_theme_constant_override("separation", DesignTokens.SP_M)
	card.add_child(inner)
	# Color swatch
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(64, 64)
	var col_value: Color = DesignTokens.get(str(entry.name)) if str(entry.name) in DesignTokens else Color.MAGENTA
	swatch.color = col_value
	inner.add_child(swatch)
	# Info
	var col := VBoxContainer.new()
	col.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	col.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = str(entry.name)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_SM)
	col.add_child(name_lbl)
	var hex_lbl := Label.new()
	hex_lbl.text = "#%s · %s" % [col_value.to_html(false), str(entry.where)]
	DesignTokens.style_label(hex_lbl, DesignTokens.FONT_LABEL_XS, true)
	col.add_child(hex_lbl)
	inner.add_child(col)
	return card


# ---------- Shared widgets ----------

func _add_hint(text: String) -> void:
	var hint := Label.new()
	hint.text = text
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(hint, DesignTokens.FONT_LABEL_SM, true)
	_content_root.add_child(hint)


func _build_grid_header(columns: Array) -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DesignTokens.SP_S)
	for i in columns.size():
		var lbl := Label.new()
		lbl.text = str(columns[i])
		lbl.custom_minimum_size = Vector2(120 if i == 0 else 96, 28)
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
