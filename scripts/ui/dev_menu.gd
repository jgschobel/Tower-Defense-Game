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
const TOWER_IDS := ["basic", "sniper", "splash", "cordula", "slow", "farm", "support", "joe", "justus", "seve"]
const TOWER_DISPLAY := {"basic": "Lemurius", "sniper": "Kühne", "splash": "JoJo", "cordula": "Cordula", "slow": "Amösius", "farm": "Banani-Bauer", "support": "Quartier-Chef", "joe": "Joe", "justus": "Justus", "seve": "Seve"}
const ENEMY_IDS := ["basic", "fast", "tank", "healer", "flying", "swarm", "boss", "smoothie_slime", "berserker", "tofu_ninja", "linsen_golem", "cumulus_blob", "camo", "lead", "regrow", "glace_golem"]
const ENEMY_DISPLAY := {"basic": "Brötli", "fast": "Toblerone", "tank": "Cervelat", "healer": "Dr. Rivella", "flying": "Fondue", "swarm": "Tofu", "boss": "M-Tüüfel", "smoothie_slime": "Smoothie-Schleim", "berserker": "Seitän-Berserker", "tofu_ninja": "Tofu-Ninja", "linsen_golem": "Linsen-Golem", "cumulus_blob": "Cumulus-Blob", "camo": "Schatte-Tofu", "lead": "Blei-Würschtli", "regrow": "Regrow-Geist", "glace_golem": "Glacé-Golem"}
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

# Every projectile_style declared in tower .tres files. Used by the
# Projectiles tab to render a swatch + style hint per style.
const PROJECTILE_CATALOG := [
	{"style": "banana",     "tower": "Lemurius",      "color": Color(1.0, 0.92, 0.35), "trail": "khaki",  "note": "piercing — passes through targets at higher tiers"},
	{"style": "pollen",     "tower": "Kühne",          "color": Color(0.95, 0.85, 0.55), "trail": "warm",   "note": "first-strike + camo-detect at higher tiers"},
	{"style": "flask",      "tower": "JoJo",           "color": Color(0.55, 0.85, 0.45), "trail": "acid",   "note": "lingering acid puddle DoT on impact"},
	{"style": "volleyball", "tower": "Cordula",        "color": Color(1.0, 0.95, 0.95), "trail": "white",  "note": "wide-arc cone burst"},
	{"style": "tongue",     "tower": "Amösius",        "color": Color(0.85, 0.45, 0.55), "trail": "pink",   "note": "single-target reel-in pull mechanic"},
	{"style": "formula",    "tower": "Joe",            "color": Color(0.65, 0.85, 1.0),  "trail": "ice",    "note": "freeze chance"},
	{"style": "dumbbell",   "tower": "Justus",         "color": Color(0.6, 0.6, 0.65),   "trail": "gray",   "note": "heavy-hit knockback"},
	{"style": "gear",       "tower": "Seve",           "color": Color(0.85, 0.7, 0.4),   "trail": "bronze", "note": "ricochet between targets"},
]

# Every visual effect EffectPlayer can spawn. Tab gives a button per
# effect that fires it at a fixed map-center position so user can see.
const EFFECT_CATALOG := [
	{"label": "Muzzle flash (banana)",     "fn": "spawn_muzzle_flash",  "args": ["banana"]},
	{"label": "Muzzle flash (pollen)",     "fn": "spawn_muzzle_flash",  "args": ["pollen"]},
	{"label": "Muzzle flash (flask)",      "fn": "spawn_muzzle_flash",  "args": ["flask"]},
	{"label": "Muzzle flash (volleyball)", "fn": "spawn_muzzle_flash",  "args": ["volleyball"]},
	{"label": "Muzzle flash (tongue)",     "fn": "spawn_muzzle_flash",  "args": ["tongue"]},
	{"label": "Impact sparks (warm)",      "fn": "spawn_impact_sparks", "args": [Color(1.0, 0.7, 0.3)]},
	{"label": "Impact sparks (cool)",      "fn": "spawn_impact_sparks", "args": [Color(0.5, 0.85, 1.0)]},
	{"label": "Death poof (small)",        "fn": "spawn_death_poof",    "args": [Color(0.85, 0.7, 0.45)]},
	{"label": "Death poof (boss)",         "fn": "spawn_death_poof",    "args": [Color(0.7, 0.2, 0.2)]},
	{"label": "Place sparkles",            "fn": "spawn_place_sparkles", "args": []},
	{"label": "Step dust",                 "fn": "spawn_step_dust",     "args": []},
]

# Music tracks per level — clicking previews 4-5s of that level's track.
const MUSIC_CATALOG := [
	{"id": 1,  "name": "L1 Migros-Iigang",       "mood": "cheery shop bustle"},
	{"id": 2,  "name": "L2 Tiefchüel-Abteilig",  "mood": "icy ambient"},
	{"id": 3,  "name": "L3 Bäckerei",            "mood": "bakery-organ warmth"},
	{"id": 4,  "name": "L4 Chäsi-Keller",        "mood": "cellar-dub murk"},
	{"id": 5,  "name": "L5 Kasse",               "mood": "boss-intense"},
	{"id": 6,  "name": "L6 Parkhuus",            "mood": "parkhuus-industrial"},
	{"id": 7,  "name": "L7 S'Dach",              "mood": "rooftop-cinematic"},
	{"id": 8,  "name": "L8 Coop-Iibruch",        "mood": "rival-supermarket tense"},
	{"id": 9,  "name": "L9 Cumulus-Punkte-Kern", "mood": "glitchy neon"},
	{"id": 10, "name": "L10 Tüüfel-Äste",        "mood": "finale gauntlet"},
]

# Atmosphere particles per level — cfg comes from game_level._spawn_atmosphere_particles.
const ATMOSPHERE_CATALOG := [
	{"id": 1,  "label": "L1",  "tint": "—",                            "note": "no atmosphere overlay (clean shop floor)"},
	{"id": 2,  "label": "L2",  "tint": "frost (light blue, 35 count)",   "note": "freezer breath — gravity (10, 60)"},
	{"id": 3,  "label": "L3",  "tint": "flour (cream, 28 count)",        "note": "bakery flour drift — gravity (-5, 25)"},
	{"id": 4,  "label": "L4",  "tint": "acid (green bubbles)",           "note": "Chäsi-Keller toxic vapor"},
	{"id": 5,  "label": "L5",  "tint": "cumulus-receipts (paper bits)",  "note": "kasse confetti receipt rain"},
	{"id": 6,  "label": "L6",  "tint": "rain (blue streaks)",            "note": "parkhuus wet floor"},
	{"id": 7,  "label": "L7",  "tint": "wind leaves (orange flecks)",    "note": "rooftop sunset autumn"},
	{"id": 8,  "label": "L8",  "tint": "blue sparks",                    "note": "Coop-security electrical"},
	{"id": 9,  "label": "L9",  "tint": "purple glitch",                  "note": "Cumulus core fragment"},
	{"id": 10, "label": "L10", "tint": "rising embers",                  "note": "Tüüfel-Äste finale"},
]

# Damage-type ruleset — visualizes the armor math base_enemy.take_damage uses.
const DAMAGE_TYPE_CATALOG := [
	{"name": "PHYSICAL", "color": Color(0.85, 0.7, 0.45), "rule": "Full armor reduction. Lead enemies = effective_armor 0 with 15% resistance flat."},
	{"name": "MAGIC",    "color": Color(0.65, 0.45, 1.0), "rule": "Bypasses 70% of armor. Defeats lead enemy 15%-resistance."},
	{"name": "PURE",     "color": Color(1.0, 0.95, 0.85), "rule": "Ignores armor and lead resistance entirely. Rare on towers."},
]

# Difficulty modifier matrix — visualizes how Easy/Normal/Hard scale.
const DIFFICULTY_CATALOG := [
	{"name": "Easy",   "hp": "0.75×", "speed": "0.95×", "count": "0.90×", "gold": "0.80×", "aminos": "0.50×", "stars_max": 2, "color": Color(0.55, 0.85, 0.55)},
	{"name": "Normal", "hp": "1.00×", "speed": "1.00×", "count": "1.00×", "gold": "1.00×", "aminos": "1.00×", "stars_max": 3, "color": Color(0.95, 0.85, 0.45)},
	{"name": "Hard",   "hp": "1.40×", "speed": "1.10×", "count": "1.20×", "gold": "1.35×", "aminos": "1.75×", "stars_max": 3, "color": Color(0.95, 0.4, 0.35)},
]

# Tower synergy/adjacency pairs — buffs visible when both within ~150px.
const SYNERGY_CATALOG := [
	{"a": "Lemurius", "b": "Kühne",      "buff": "+15% range + pierce on bananas"},
	{"a": "Cordula",  "b": "Amösius",    "buff": "+20% atk-speed when Amösius has glued target"},
	{"a": "JoJo",     "b": "Banani-Bauer", "buff": "+1 gold per acid-puddle pop"},
	{"a": "Kühne",    "b": "Quartier-Chef", "buff": "+10% crit chance"},
	{"a": "Banani-Bauer", "b": "Quartier-Chef", "buff": "+25% farm payout"},
]

# Lore character bios — pulled from lore.gd CHARACTER_BIOS.
const LORE_CHARACTER_IDS := ["lemurius", "amosius", "kuehne", "jojo", "cordula", "m_teufel"]

var _prefs: Dictionary = {}
var _content_root: VBoxContainer = null
var _current_tab: String = "monsters"


func _ready() -> void:
	print("[DevMenu] _ready start — vp=", get_viewport().get_visible_rect().size)
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
	# Bright yellow heartbeat — proves the script reached _ready even if
	# every subsequent UI builder fails. User can trust: if THIS is missing,
	# the script didn't load (parse error). If THIS is visible, _ready ran.
	var heartbeat := Label.new()
	heartbeat.text = "DevMenu OK · " + Time.get_time_string_from_system()
	heartbeat.add_theme_font_size_override("font_size", 14)
	heartbeat.add_theme_color_override("font_color", Color(1.0, 0.9, 0.3))
	heartbeat.add_theme_color_override("font_outline_color", Color.BLACK)
	heartbeat.add_theme_constant_override("outline_size", 3)
	heartbeat.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	heartbeat.offset_left = -260
	heartbeat.offset_top = 12
	heartbeat.offset_right = -16
	heartbeat.offset_bottom = 36
	heartbeat.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	add_child(heartbeat)
	_load_prefs()
	_build_shell()
	# Populate the initial tab DIRECTLY — calling _show_tab here would
	# rebuild the shell we just built and leak the _content_root reference.
	_populate_active_tab()
	print("[DevMenu] _ready done — children=", get_child_count(), " size=", size)


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
		"monsters":    _populate_monsters_tab()
		"towers":      _populate_towers_tab()
		"variants":    _populate_variants_tab()
		"maps":        _populate_maps_tab()
		"icons":       _populate_icons_tab()
		"audio":       _populate_audio_tab()
		"palette":     _populate_palette_tab()
		"projectiles": _populate_projectiles_tab()
		"effects":     _populate_effects_tab()
		"music":       _populate_music_tab()
		"waves":       _populate_waves_tab()
		"levels":      _populate_levels_tab()
		"story":       _populate_story_tab()
		"damage":      _populate_damage_tab()
		"difficulty":  _populate_difficulty_tab()
		"synergies":   _populate_synergies_tab()
		"atmosphere":  _populate_atmosphere_tab()
		"lore":        _populate_lore_tab()
		"diagnostics": _populate_diagnostics_tab()
		"mobile":      _populate_mobile_tab()
		"perf":        _populate_perf_tab()
		"build":       _populate_build_tab()


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
		{"id": "monsters",    "label": "Monster"},
		{"id": "towers",      "label": "Türm × Tier"},
		{"id": "projectiles", "label": "Projektile"},
		{"id": "effects",     "label": "Effekt"},
		{"id": "audio",       "label": "Audio"},
		{"id": "music",       "label": "Musik"},
		{"id": "waves",       "label": "Wellä"},
		{"id": "levels",      "label": "Levels"},
		{"id": "maps",        "label": "Maps"},
		{"id": "story",       "label": "Story"},
		{"id": "lore",        "label": "Lore"},
		{"id": "damage",      "label": "Damage"},
		{"id": "difficulty",  "label": "Schwierig."},
		{"id": "synergies",   "label": "Synergie"},
		{"id": "atmosphere",  "label": "Atmo"},
		{"id": "variants",    "label": "Variante"},
		{"id": "icons",       "label": "Icons"},
		{"id": "palette",     "label": "Palette"},
		{"id": "diagnostics", "label": "Diagnose"},
		{"id": "mobile",      "label": "Mobile"},
		{"id": "perf",        "label": "Perf HUD"},
		{"id": "build",       "label": "Build"},
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
	_add_hint("Klick uf en Variante zum si als Standard merka. Turm-Tier-Variante chömed us assets/textures/towers/, Monster-Variante us assets/textures/variants/enemies/. Selektion persistiert i user://variants.json.")
	var categories := _discover_variant_categories()
	if categories.is_empty():
		_add_hint("(Kei Variante gfunde. Turm-Tier-Bilder müend generiert werde — lauf generate_tier_variants.py. Monster-Damage-States bruuched generate_enemy_damage_variants.py.)")
		return
	for category in categories:
		_content_root.add_child(_build_variant_section(category))


func _discover_variant_categories() -> Array:
	var out: Array = []
	# Tower tier variants (*_t1a, *_t2b, *_t3a etc.) live flat in assets/textures/towers/
	var tower_assets := _discover_tower_tier_variants()
	if not tower_assets.is_empty():
		out.append({"name": "towers", "assets": tower_assets})
	# Directory-based scan for API-generated enemy/bg variants
	for r in ["res://assets/textures/variants", "res://assets/variants"]:
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


func _discover_tower_tier_variants() -> Array:
	var dir := DirAccess.open("res://assets/textures/towers")
	if dir == null:
		return []
	var tier_suffixes := ["_t1a", "_t1b", "_t2a", "_t2b", "_t3a", "_t3b"]
	var by_id: Dictionary = {}
	dir.list_dir_begin()
	var fname := dir.get_next()
	while fname != "":
		if fname.ends_with(".png"):
			var base := fname.get_basename()
			for suffix in tier_suffixes:
				if base.ends_with(suffix):
					var tower_id := base.left(base.length() - suffix.length())
					if tower_id not in by_id:
						by_id[tower_id] = []
					by_id[tower_id].append("res://assets/textures/towers/" + fname)
					break
		fname = dir.get_next()
	var ordered: Array = []
	for id in TOWER_IDS:
		if id in by_id:
			ordered.append(id)
	for id in by_id:
		if id not in ordered:
			ordered.append(id)
	var out: Array = []
	for id in ordered:
		var variants: Array = by_id[id]
		variants.sort()
		out.append({"id": id, "variants": variants})
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
	# Color swatch — explicit hardcoded lookup. PREVIOUS BUG: tried
	# DesignTokens.get(name) and `name in DesignTokens` which doesn't work
	# on a class_name (only on instances). Caused script to fail/grey out.
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(64, 64)
	var col_value: Color = _resolve_palette_color(str(entry.name))
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


func _resolve_palette_color(name: String) -> Color:
	# Hardcoded map — class_name consts can't be reflected by .get() so
	# we list them explicitly. Adding a new color? Add it here too.
	match name:
		"COL_BG_DEEPEST":    return DesignTokens.COL_BG_DEEPEST
		"COL_BG_PANEL":      return DesignTokens.COL_BG_PANEL
		"COL_BG_RAISED":     return DesignTokens.COL_BG_RAISED
		"COL_BG_HOVER":      return DesignTokens.COL_BG_HOVER
		"COL_BG_PRESSED":    return DesignTokens.COL_BG_PRESSED
		"COL_STROKE_FAINT":  return DesignTokens.COL_STROKE_FAINT
		"COL_STROKE_NORMAL": return DesignTokens.COL_STROKE_NORMAL
		"COL_STROKE_STRONG": return DesignTokens.COL_STROKE_STRONG
		"COL_STROKE_HOVER":  return DesignTokens.COL_STROKE_HOVER
		"COL_TEXT_PRIMARY":  return DesignTokens.COL_TEXT_PRIMARY
		"COL_TEXT_HEADING":  return DesignTokens.COL_TEXT_HEADING
		"COL_TEXT_MUTED":    return DesignTokens.COL_TEXT_MUTED
		"COL_TEXT_DISABLED": return DesignTokens.COL_TEXT_DISABLED
		"COL_OK":            return DesignTokens.COL_OK
		"COL_WARN":          return DesignTokens.COL_WARN
		"COL_BAD":           return DesignTokens.COL_BAD
		"COL_GOLD":          return DesignTokens.COL_GOLD
		_:                   return Color.MAGENTA


# ---------- Tab: Projectiles ----------

func _populate_projectiles_tab() -> void:
	_add_hint("Alli 8 Projektil-Stil us de tower .tres files. Spalte: Stil-Name, Vorschau-Farb, dezugehöriger Turm, Trail-Farb, Mechanik. Klick uf 'Test Schuss' fürs Muzzle-Flash mit dem Stil aazlöse.")
	var grid := GridContainer.new()
	grid.columns = 1
	grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(grid)
	for entry in PROJECTILE_CATALOG:
		grid.add_child(_build_projectile_card(entry))


func _build_projectile_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 84)
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_M)
	card.add_child(row)
	var swatch := ColorRect.new()
	swatch.custom_minimum_size = Vector2(60, 60)
	swatch.color = entry.color
	row.add_child(swatch)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 2)
	var name_lbl := Label.new()
	name_lbl.text = "%s · %s" % [str(entry.style).capitalize(), entry.tower]
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	info.add_child(name_lbl)
	var note_lbl := Label.new()
	note_lbl.text = "Trail: %s · %s" % [entry.trail, entry.note]
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(note_lbl, DesignTokens.FONT_LABEL_XS, true)
	info.add_child(note_lbl)
	row.add_child(info)
	var test_btn := Button.new()
	test_btn.text = "▶ Test Schuss"
	test_btn.custom_minimum_size = Vector2(120, 36)
	DesignTokens.style_button(test_btn, false, DesignTokens.FONT_LABEL_SM)
	test_btn.pressed.connect(func():
		var center: Vector2 = get_viewport_rect().size * 0.5
		if EffectPlayer and EffectPlayer.has_method("spawn_muzzle_flash"):
			EffectPlayer.spawn_muzzle_flash(center, Vector2.RIGHT, entry.color, entry.style)
		if SfxManager:
			SfxManager.play_shoot(entry.tower.to_lower(), 1))
	row.add_child(test_btn)
	return card


# ---------- Tab: Effects ----------

func _populate_effects_tab() -> void:
	_add_hint("Visueller Effekt aalöse — gnaui Mitti vom Bildschirm. Nützlich zum prüefe öb d'Partikel-Farb, -Anzahl und -Lebensduur stimmt. Bi Bedarf hinder em Knopf de Code i scripts/systems/effect_player.gd.")
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SP_M)
	grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(grid)
	for entry in EFFECT_CATALOG:
		grid.add_child(_build_effect_button(entry))


func _build_effect_button(entry: Dictionary) -> Control:
	var btn := Button.new()
	btn.text = "✦ " + str(entry.label)
	btn.custom_minimum_size = Vector2(0, 44)
	DesignTokens.style_button(btn, false, DesignTokens.FONT_LABEL_SM)
	btn.pressed.connect(func():
		if EffectPlayer == null:
			return
		var center: Vector2 = get_viewport_rect().size * 0.5
		match entry.fn:
			"spawn_muzzle_flash":
				EffectPlayer.spawn_muzzle_flash(center, Vector2.RIGHT, Color(1.0, 0.85, 0.4), entry.args[0])
			"spawn_impact_sparks":
				EffectPlayer.spawn_impact_sparks(center, entry.args[0])
			"spawn_death_poof":
				EffectPlayer.spawn_death_poof(center, entry.args[0])
			"spawn_place_sparkles":
				EffectPlayer.spawn_place_sparkles(center)
			"spawn_step_dust":
				EffectPlayer.spawn_step_dust(center))
	return btn


# ---------- Tab: Music ----------

func _populate_music_tab() -> void:
	_add_hint("Eine Knopf pro Level-Track. Dräuckt MusicManager.set_level_track(N) — d'Musig wechslet sofort. «Stop» hört uf, dass d'Hand-Test-Session ruhig blibt.")
	var stop_row := HBoxContainer.new()
	_content_root.add_child(stop_row)
	var stop_btn := Button.new()
	stop_btn.text = "⏸ Stop"
	stop_btn.custom_minimum_size = Vector2(120, 40)
	DesignTokens.style_button(stop_btn, false, DesignTokens.FONT_LABEL_SM)
	stop_btn.pressed.connect(func():
		if MusicManager and MusicManager.has_method("stop_music"):
			MusicManager.stop_music())
	stop_row.add_child(stop_btn)
	var grid := GridContainer.new()
	grid.columns = 2
	grid.add_theme_constant_override("h_separation", DesignTokens.SP_M)
	grid.add_theme_constant_override("v_separation", DesignTokens.SP_S)
	_content_root.add_child(grid)
	for entry in MUSIC_CATALOG:
		grid.add_child(_build_music_button(entry))


func _build_music_button(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 64)
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var row := HBoxContainer.new()
	card.add_child(row)
	var info := VBoxContainer.new()
	info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	info.add_theme_constant_override("separation", 1)
	var name_lbl := Label.new()
	name_lbl.text = entry.name
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	info.add_child(name_lbl)
	var mood_lbl := Label.new()
	mood_lbl.text = entry.mood
	DesignTokens.style_label(mood_lbl, DesignTokens.FONT_LABEL_XS, true)
	info.add_child(mood_lbl)
	row.add_child(info)
	var play_btn := Button.new()
	play_btn.text = "▶ Spille"
	play_btn.custom_minimum_size = Vector2(120, 40)
	DesignTokens.style_button(play_btn, false, DesignTokens.FONT_LABEL_SM)
	play_btn.pressed.connect(func():
		if MusicManager and MusicManager.has_method("set_level_track"):
			MusicManager.set_level_track(entry.id))
	row.add_child(play_btn)
	return card


# ---------- Tab: Waves ----------

func _populate_waves_tab() -> void:
	_add_hint("Alli 30 Wellä pro Level. Klick es Level zum d'Wellä uufdrücke. Pro Wellä gits «Total Feinde» und d'Compositioä. Use case: Schwierigkeits-Audit, Spawn-Stack-Sucht, BTD5-Vergleich.")
	for level_id in range(1, 11):
		_content_root.add_child(_build_waves_section(level_id))


func _build_waves_section(level_id: int) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", DesignTokens.SP_XS)
	var heading := Button.new()
	heading.text = "▸ L%d — %s" % [level_id, _level_display_name(level_id)]
	heading.custom_minimum_size = Vector2(0, 36)
	DesignTokens.style_button(heading, false, DesignTokens.FONT_LABEL_LG)
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(heading)
	var detail := VBoxContainer.new()
	detail.visible = false
	detail.add_theme_constant_override("separation", 2)
	section.add_child(detail)
	heading.pressed.connect(func():
		detail.visible = not detail.visible
		if detail.visible and detail.get_child_count() == 0:
			_populate_waves_detail(level_id, detail))
	return section


func _populate_waves_detail(level_id: int, parent: VBoxContainer) -> void:
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if not ResourceLoader.exists(path):
		var miss := Label.new()
		miss.text = "(level data missing)"
		parent.add_child(miss)
		return
	var ld = load(path)
	if not (ld and "waves" in ld and ld.waves is Array):
		var miss2 := Label.new()
		miss2.text = "(no waves array)"
		parent.add_child(miss2)
		return
	for i in ld.waves.size():
		var wave: Dictionary = ld.waves[i]
		parent.add_child(_build_wave_row(i + 1, wave))


func _build_wave_row(wave_num: int, wave: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.custom_minimum_size = Vector2(0, 36)
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_XS))
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	card.add_child(row)
	var num_lbl := Label.new()
	num_lbl.text = "W%d" % wave_num
	num_lbl.custom_minimum_size = Vector2(40, 0)
	DesignTokens.style_label(num_lbl, DesignTokens.FONT_LABEL_SM)
	row.add_child(num_lbl)
	var groups: Array = wave.get("groups", [])
	var total: int = 0
	var summary_parts: Array = []
	for g in groups:
		var c: int = int(g.get("count", 0))
		total += c
		summary_parts.append("%d×%s" % [c, g.get("enemy_id", "?")])
	var total_lbl := Label.new()
	total_lbl.text = "%d total" % total
	total_lbl.custom_minimum_size = Vector2(80, 0)
	DesignTokens.style_label(total_lbl, DesignTokens.FONT_LABEL_SM, true)
	row.add_child(total_lbl)
	var summary_lbl := Label.new()
	summary_lbl.text = " · ".join(summary_parts)
	summary_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	summary_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(summary_lbl, DesignTokens.FONT_LABEL_XS)
	row.add_child(summary_lbl)
	return card


# ---------- Tab: Levels ----------

func _populate_levels_tab() -> void:
	_add_hint("Alli 10 Level-Daten uf eim Blick — Name, Beschribig, Start-Gold/Lives, Wellä-Anzahl, Total-Feinde. Use case: Balancing-Audit über alli Level.")
	for level_id in range(1, 11):
		_content_root.add_child(_build_level_summary_card(level_id))


func _build_level_summary_card(level_id: int) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var path := "res://resources/level_data/level_%d.tres" % level_id
	if not ResourceLoader.exists(path):
		var miss := Label.new()
		miss.text = "L%d — (level_data missing)" % level_id
		col.add_child(miss)
		return card
	var ld = load(path)
	var heading := Label.new()
	heading.text = "L%d — %s" % [level_id, ld.level_name if "level_name" in ld else "?"]
	DesignTokens.style_label(heading, DesignTokens.FONT_LABEL_LG)
	col.add_child(heading)
	var desc := Label.new()
	desc.text = ld.description if "description" in ld else ""
	desc.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(desc, DesignTokens.FONT_LABEL_XS, true)
	col.add_child(desc)
	var total_enemies: int = 0
	var bosses: int = 0
	if "waves" in ld and ld.waves is Array:
		for w in ld.waves:
			for g in w.get("groups", []):
				var c: int = int(g.get("count", 0))
				total_enemies += c
				if g.get("enemy_id", "") == "boss":
					bosses += c
	var stats := Label.new()
	stats.text = "Wellä: %d · Start-Gold: %d · Liebe: %d · Total Feinde: %d · Bosse: %d" % [
		(ld.waves.size() if "waves" in ld and ld.waves else 0),
		(ld.starting_gold if "starting_gold" in ld else 0),
		(ld.starting_lives if "starting_lives" in ld else 0),
		total_enemies, bosses
	]
	DesignTokens.style_label(stats, DesignTokens.FONT_LABEL_SM)
	col.add_child(stats)
	return card


# ---------- Tab: Story ----------

func _populate_story_tab() -> void:
	_add_hint("Lore-Iitritts-Pages pro Level. Lis durä, gimmer Feedback ob d'Sproch passt, ob d'Diktion stimmt, ob es zu lang isch.")
	for level_id in range(1, 11):
		_content_root.add_child(_build_story_section(level_id))


func _build_story_section(level_id: int) -> Control:
	var section := VBoxContainer.new()
	section.add_theme_constant_override("separation", 4)
	var heading := Button.new()
	heading.text = "▸ L%d — %s" % [level_id, _level_display_name(level_id)]
	heading.custom_minimum_size = Vector2(0, 36)
	DesignTokens.style_button(heading, false, DesignTokens.FONT_LABEL_LG)
	heading.alignment = HORIZONTAL_ALIGNMENT_LEFT
	section.add_child(heading)
	var detail := VBoxContainer.new()
	detail.visible = false
	detail.add_theme_constant_override("separation", DesignTokens.SP_S)
	section.add_child(detail)
	heading.pressed.connect(func():
		detail.visible = not detail.visible
		if detail.visible and detail.get_child_count() == 0:
			_populate_story_detail(level_id, detail))
	return section


func _populate_story_detail(level_id: int, parent: VBoxContainer) -> void:
	if not ClassDB.class_exists("Lore"):
		# Fall back to direct call. Lore is a static class via class_name.
		pass
	var pages: Array = []
	if Engine.has_singleton("Lore"):
		pages = Engine.get_singleton("Lore").get_level_pages(level_id)
	else:
		# Lore is not an autoload — call statically through a known reference.
		var lore_script = load("res://scripts/systems/lore.gd")
		if lore_script and lore_script.has_method("get_level_pages"):
			pages = lore_script.get_level_pages(level_id)
	if pages.is_empty():
		var miss := Label.new()
		miss.text = "(no pages)"
		parent.add_child(miss)
		return
	for i in pages.size():
		var page = pages[i]
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
		var col := VBoxContainer.new()
		col.add_theme_constant_override("separation", 2)
		card.add_child(col)
		var speaker_lbl := Label.new()
		var speaker: String = page.get("speaker", "?") if page is Dictionary else "?"
		speaker_lbl.text = "Page %d · %s" % [i + 1, speaker]
		DesignTokens.style_label(speaker_lbl, DesignTokens.FONT_LABEL_SM)
		col.add_child(speaker_lbl)
		var text_lbl := Label.new()
		text_lbl.text = page.get("text", "") if page is Dictionary else str(page)
		text_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
		DesignTokens.style_label(text_lbl, DesignTokens.FONT_LABEL)
		col.add_child(text_lbl)
		parent.add_child(card)


# ---------- Tab: Damage Types ----------

func _populate_damage_tab() -> void:
	_add_hint("Damage-Type Regeln us base_enemy.take_damage. Wichtig: lead-Feinde wende d'15%-Resistenz statt em normale Armor — magische und reine Schäde gönd dur.")
	for entry in DAMAGE_TYPE_CATALOG:
		_content_root.add_child(_build_damage_type_card(entry))


func _build_damage_type_card(entry: Dictionary) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(entry.color, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 4)
	card.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = str(entry.name)
	name_lbl.add_theme_color_override("font_color", entry.color)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_LG)
	col.add_child(name_lbl)
	var rule_lbl := Label.new()
	rule_lbl.text = entry.rule
	rule_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(rule_lbl, DesignTokens.FONT_LABEL_SM)
	col.add_child(rule_lbl)
	return card


# ---------- Tab: Difficulty ----------

func _populate_difficulty_tab() -> void:
	_add_hint("Multiplikatore pro Schwierigkeits-Stufe. Quelle: GameManager.DIFFICULTY_*. Use case: prüefe öb «Hard» wirklich härter isch und «Easy» nöd langwilig.")
	_content_root.add_child(_build_grid_header(["Mode", "HP", "Speed", "Anzahl", "Gold", "Aminos", "Max Stärn"]))
	for entry in DIFFICULTY_CATALOG:
		_content_root.add_child(_build_difficulty_row(entry))


func _build_difficulty_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var name_lbl := Label.new()
	name_lbl.text = str(entry.name)
	name_lbl.custom_minimum_size = Vector2(120, 36)
	name_lbl.add_theme_color_override("font_color", entry.color)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	row.add_child(name_lbl)
	for key in ["hp", "speed", "count", "gold", "aminos"]:
		var lbl := Label.new()
		lbl.text = str(entry[key])
		lbl.custom_minimum_size = Vector2(96, 36)
		lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		DesignTokens.style_label(lbl, DesignTokens.FONT_LABEL_SM)
		row.add_child(lbl)
	var stars_lbl := Label.new()
	stars_lbl.text = str(entry.stars_max)
	stars_lbl.custom_minimum_size = Vector2(96, 36)
	stars_lbl.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DesignTokens.style_label(stars_lbl, DesignTokens.FONT_LABEL_SM)
	row.add_child(stars_lbl)
	return row


# ---------- Tab: Synergies ----------

func _populate_synergies_tab() -> void:
	_add_hint("Adjazenz-Buffs (~150px Radius). Zwei Türm gnueg nahe = sichtbarä Bonus + es feines goldigs Liini zwüsche ihne.")
	_content_root.add_child(_build_grid_header(["Turm A", "Turm B", "Bonus"]))
	for entry in SYNERGY_CATALOG:
		_content_root.add_child(_build_synergy_row(entry))


func _build_synergy_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var a_lbl := Label.new()
	a_lbl.text = entry.a
	a_lbl.custom_minimum_size = Vector2(160, 36)
	DesignTokens.style_label(a_lbl, DesignTokens.FONT_LABEL)
	row.add_child(a_lbl)
	var plus := Label.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(20, 36)
	plus.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	DesignTokens.style_label(plus, DesignTokens.FONT_LABEL, true)
	row.add_child(plus)
	var b_lbl := Label.new()
	b_lbl.text = entry.b
	b_lbl.custom_minimum_size = Vector2(160, 36)
	DesignTokens.style_label(b_lbl, DesignTokens.FONT_LABEL)
	row.add_child(b_lbl)
	var buff_lbl := Label.new()
	buff_lbl.text = entry.buff
	buff_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	buff_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(buff_lbl, DesignTokens.FONT_LABEL_SM)
	row.add_child(buff_lbl)
	return row


# ---------- Tab: Atmosphere particles ----------

func _populate_atmosphere_tab() -> void:
	_add_hint("Pro Level d'Hintergrund-Partikel. Quelle: game_level._spawn_atmosphere_particles. Wenn dir öppis kalt vorchunt obwohl's heiss sii sött, hie aapasse.")
	_content_root.add_child(_build_grid_header(["Level", "Tint / cfg", "Notiz"]))
	for entry in ATMOSPHERE_CATALOG:
		_content_root.add_child(_build_atmosphere_row(entry))


func _build_atmosphere_row(entry: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var lvl_lbl := Label.new()
	lvl_lbl.text = entry.label
	lvl_lbl.custom_minimum_size = Vector2(80, 36)
	DesignTokens.style_label(lvl_lbl, DesignTokens.FONT_LABEL)
	row.add_child(lvl_lbl)
	var tint_lbl := Label.new()
	tint_lbl.text = entry.tint
	tint_lbl.custom_minimum_size = Vector2(260, 36)
	DesignTokens.style_label(tint_lbl, DesignTokens.FONT_LABEL_SM)
	row.add_child(tint_lbl)
	var note_lbl := Label.new()
	note_lbl.text = entry.note
	note_lbl.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	note_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(note_lbl, DesignTokens.FONT_LABEL_XS, true)
	row.add_child(note_lbl)
	return row


# ---------- Tab: Lore (character bios + enemy lore) ----------

func _populate_lore_tab() -> void:
	_add_hint("Charakter-Biografie + Feind-Lore us scripts/systems/lore.gd. Lis durä — wenn d'Wortwahl irgendwo eng-deutsch tönt anstatt Schwiizerdütsch, säg's.")
	var lore_script = load("res://scripts/systems/lore.gd")
	if lore_script == null:
		_add_hint("(lore.gd konnt nöd glade werde)")
		return
	# CHARACTER_BIOS section
	var heading_a := Label.new()
	heading_a.text = "▸ Charakter-Biografie"
	DesignTokens.style_heading(heading_a, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(heading_a)
	if "CHARACTER_BIOS" in lore_script:
		var bios: Dictionary = lore_script.CHARACTER_BIOS
		for char_id in bios.keys():
			_content_root.add_child(_build_lore_card(str(char_id), bios[char_id]))
	# ENEMY_LORE section
	var heading_b := Label.new()
	heading_b.text = "▸ Feind-Lore"
	DesignTokens.style_heading(heading_b, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(heading_b)
	if "ENEMY_LORE" in lore_script:
		var enemies: Dictionary = lore_script.ENEMY_LORE
		for enemy_id in enemies.keys():
			_content_root.add_child(_build_enemy_lore_card(str(enemy_id), str(enemies[enemy_id])))


func _build_lore_card(char_id: String, bio) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var name_lbl := Label.new()
	if bio is Dictionary and "name" in bio:
		name_lbl.text = "%s · %s" % [char_id, bio["name"]]
	else:
		name_lbl.text = char_id
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_LG)
	col.add_child(name_lbl)
	if bio is Dictionary:
		for key in bio.keys():
			if key == "name":
				continue
			var line := Label.new()
			line.text = "%s: %s" % [str(key), str(bio[key])]
			line.autowrap_mode = TextServer.AUTOWRAP_WORD
			DesignTokens.style_label(line, DesignTokens.FONT_LABEL_SM)
			col.add_child(line)
	return card


func _build_enemy_lore_card(enemy_id: String, lore: String) -> Control:
	var card := PanelContainer.new()
	card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var col := VBoxContainer.new()
	col.add_theme_constant_override("separation", 2)
	card.add_child(col)
	var name_lbl := Label.new()
	name_lbl.text = ENEMY_DISPLAY.get(enemy_id, enemy_id)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL)
	col.add_child(name_lbl)
	var lore_lbl := Label.new()
	lore_lbl.text = lore
	lore_lbl.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(lore_lbl, DesignTokens.FONT_LABEL_SM, true)
	col.add_child(lore_lbl)
	return card


# ---------- Tab: Diagnostics (runtime debug stats) ----------

func _populate_diagnostics_tab() -> void:
	_add_hint("Live-Diagnose: Engine-FPS, Memory-Druck, Pool-Stand, autoloadi-Status. Use case: bevor Du Bug meldsch, hie luege ob öppis offensichtlich nöd stimmt.")
	# Engine info
	var engine_card := PanelContainer.new()
	engine_card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_S))
	var engine_col := VBoxContainer.new()
	engine_card.add_child(engine_col)
	_add_kv(engine_col, "Engine", Engine.get_version_info().get("string", "?"))
	_add_kv(engine_col, "FPS",          str(int(Engine.get_frames_per_second())))
	_add_kv(engine_col, "Physics FPS",  str(Engine.physics_ticks_per_second))
	_add_kv(engine_col, "Time scale",   "%.2f" % Engine.time_scale)
	_add_kv(engine_col, "Viewport",     "%dx%d" % [int(get_viewport_rect().size.x), int(get_viewport_rect().size.y)])
	_add_kv(engine_col, "OS",           OS.get_name() + " · " + OS.get_distribution_name())
	_content_root.add_child(engine_card)
	# Autoload status
	var auto_heading := Label.new()
	auto_heading.text = "▸ Autoload-Status"
	DesignTokens.style_heading(auto_heading, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(auto_heading)
	for autoload_name in ["GameManager", "CurrencyManager", "AminosManager", "ComboTracker", "MusicManager", "SfxManager", "AutoPlaytest", "WaveSimulator", "ProjectilePool", "EnemyPool", "EffectPlayer"]:
		var card := PanelContainer.new()
		card.add_theme_stylebox_override("panel", DesignTokens.panel_box(DesignTokens.COL_STROKE_FAINT, DesignTokens.RADIUS_S, DesignTokens.SP_XS))
		var row := HBoxContainer.new()
		card.add_child(row)
		var ok: bool = get_node_or_null("/root/" + autoload_name) != null
		var name_lbl := Label.new()
		name_lbl.text = autoload_name
		name_lbl.custom_minimum_size = Vector2(220, 28)
		DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_SM)
		row.add_child(name_lbl)
		var status_lbl := Label.new()
		status_lbl.text = "✓ OK" if ok else "✕ MISSING"
		status_lbl.add_theme_color_override("font_color", DesignTokens.COL_OK if ok else DesignTokens.COL_BAD)
		DesignTokens.style_label(status_lbl, DesignTokens.FONT_LABEL_SM)
		row.add_child(status_lbl)
		_content_root.add_child(card)
	# Pool status
	var pool_heading := Label.new()
	pool_heading.text = "▸ Pool-Status"
	DesignTokens.style_heading(pool_heading, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(pool_heading)
	if EnemyPool and EnemyPool.has_method("stats"):
		var es: Dictionary = EnemyPool.stats()
		_add_kv(_content_root, "EnemyPool",       JSON.stringify(es))
	if ProjectilePool and ProjectilePool.has_method("stats"):
		var ps: Dictionary = ProjectilePool.stats()
		_add_kv(_content_root, "ProjectilePool",  JSON.stringify(ps))
	# Counts
	var counts_heading := Label.new()
	counts_heading.text = "▸ Asset-Aazahl"
	DesignTokens.style_heading(counts_heading, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(counts_heading)
	_add_kv(_content_root, "Türm",       str(_count_files("res://resources/tower_data/")))
	_add_kv(_content_root, "Feinde",     str(_count_files("res://resources/enemy_data/")))
	_add_kv(_content_root, "Levels",     str(_count_files("res://resources/level_data/")))
	# Refresh
	var refresh := Button.new()
	refresh.text = "↻ Diagnose neu laade"
	refresh.custom_minimum_size = Vector2(220, 40)
	DesignTokens.style_button(refresh, false, DesignTokens.FONT_LABEL_SM)
	refresh.pressed.connect(_show_tab.bind("diagnostics"))
	_content_root.add_child(refresh)


func _add_kv(parent: Container, key: String, value: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_M)
	var k := Label.new()
	k.text = key
	k.custom_minimum_size = Vector2(220, 24)
	DesignTokens.style_label(k, DesignTokens.FONT_LABEL_SM, true)
	row.add_child(k)
	var v := Label.new()
	v.text = value
	v.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	DesignTokens.style_label(v, DesignTokens.FONT_LABEL_SM)
	row.add_child(v)
	parent.add_child(row)


func _count_files(dir_path: String) -> int:
	var dir := DirAccess.open(dir_path)
	if dir == null:
		return 0
	var n: int = 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".tres"):
			n += 1
		entry = dir.get_next()
	return n


# ---------- Tab: Mobile Frame Check ----------

func _populate_mobile_tab() -> void:
	_add_hint("1280×720 viewport overlay mit Touch-Target-Rechteck (44×44 px Min). Hilft Tap-UX z'verifiziere uf em Telefon.")
	var info := Label.new()
	var vp_size: Vector2 = get_viewport().get_visible_rect().size
	info.text = "Viewport: %d × %d  ·  Target: 1280 × 720" % [int(vp_size.x), int(vp_size.y)]
	DesignTokens.style_label(info, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(info)

	var safe_lbl := Label.new()
	if DisplayServer.has_method("get_display_safe_area"):
		var safe: Rect2i = DisplayServer.get_display_safe_area()
		safe_lbl.text = "Safe area: x=%d y=%d w=%d h=%d" % [safe.position.x, safe.position.y, safe.size.x, safe.size.y]
	else:
		safe_lbl.text = "Safe area: (unbekannt — DisplayServer API fehlt)"
	DesignTokens.style_label(safe_lbl, DesignTokens.FONT_LABEL_SM)
	_content_root.add_child(safe_lbl)

	var tip := Label.new()
	tip.text = "↓ Tap-Zone Checkliste:"
	DesignTokens.style_heading(tip, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(tip)
	for entry in [
		{"name": "PauseButton",        "min_size": "60×60",  "ok": true},
		{"name": "Shop tower buttons", "min_size": "52×52",  "ok": true},
		{"name": "Wave start button",  "min_size": "60×40",  "ok": true},
		{"name": "Sell button",        "min_size": "52×40",  "ok": true},
		{"name": "Upgrade A / B",      "min_size": "60×40",  "ok": true},
		{"name": "Range circle drag",  "min_size": "60+ px", "ok": true},
		{"name": "Tower-info close X", "min_size": "44×44",  "ok": true},
	]:
		var row := HBoxContainer.new()
		var ok := Label.new()
		ok.text = "✓" if entry.ok else "✗"
		ok.add_theme_color_override("font_color", DesignTokens.COL_OK if entry.ok else DesignTokens.COL_BAD)
		ok.custom_minimum_size = Vector2(20, 0)
		row.add_child(ok)
		var n := Label.new()
		n.text = "%s · min %s" % [entry.name, entry.min_size]
		DesignTokens.style_label(n, DesignTokens.FONT_LABEL_SM)
		row.add_child(n)
		_content_root.add_child(row)


# ---------- Tab: Perf HUD ----------

func _populate_perf_tab() -> void:
	_add_hint("Live FPS + Node-Count + Speicher. Aktualisiert sich while du druff luegsch.")
	var fps_lbl := Label.new()
	fps_lbl.name = "PerfFPS"
	DesignTokens.style_heading(fps_lbl, DesignTokens.FONT_HEADING)
	_content_root.add_child(fps_lbl)

	var nodes_lbl := Label.new()
	nodes_lbl.name = "PerfNodes"
	DesignTokens.style_label(nodes_lbl, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(nodes_lbl)

	var mem_lbl := Label.new()
	mem_lbl.name = "PerfMem"
	DesignTokens.style_label(mem_lbl, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(mem_lbl)

	var draw_lbl := Label.new()
	draw_lbl.name = "PerfDraw"
	DesignTokens.style_label(draw_lbl, DesignTokens.FONT_LABEL_LG)
	_content_root.add_child(draw_lbl)

	# Self-refreshing tween that ticks each second
	var refresh := Timer.new()
	refresh.wait_time = 0.5
	refresh.autostart = true
	_content_root.add_child(refresh)
	refresh.timeout.connect(func():
		if not is_instance_valid(fps_lbl): return
		var fps: int = Engine.get_frames_per_second()
		var col: Color = DesignTokens.COL_OK if fps >= 50 else (DesignTokens.COL_WARN if fps >= 30 else DesignTokens.COL_BAD)
		fps_lbl.add_theme_color_override("font_color", col)
		fps_lbl.text = "FPS: %d" % fps
		nodes_lbl.text = "Nodes (tree): %d" % get_tree().get_node_count()
		mem_lbl.text = "Static memory: %.1f MB" % (OS.get_static_memory_usage() / 1048576.0)
		draw_lbl.text = "Draw calls: %d  ·  Vertices: %d" % [
			Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME),
			Performance.get_monitor(Performance.RENDER_TOTAL_PRIMITIVES_IN_FRAME),
		])


# ---------- Tab: Build Info ----------

func _populate_build_tab() -> void:
	_add_hint("Was isch deployed? Build-info, asset-counts, version pin. Phone-checkbar.")
	var rows: Array = [
		["Godot version", Engine.get_version_info().get("string", "?")],
		["Pin file",      _read_text_file("res://.github/godot-version.txt").strip_edges()],
		["MAX_LEVELS",    str(GameManager.MAX_LEVELS) if GameManager else "?"],
		["Tower count",   str(_count_tres("res://resources/tower_data"))],
		["Enemy count",   str(_count_tres("res://resources/enemy_data"))],
		["Level count",   str(_count_tres("res://resources/level_data"))],
		["Variants in /assets/textures/variants", str(_count_pngs_recursive("res://assets/textures/variants"))],
		["Tower base PNGs", str(_count_pngs("res://assets/textures/towers"))],
		["Enemy base PNGs", str(_count_pngs("res://assets/textures/enemies"))],
		["Level maps",    str(_count_pngs("res://assets/textures/maps_v3"))],
	]
	for r in rows:
		var row := HBoxContainer.new()
		var k := Label.new()
		k.text = str(r[0]) + ":"
		k.custom_minimum_size = Vector2(220, 0)
		DesignTokens.style_label(k, DesignTokens.FONT_LABEL_SM)
		row.add_child(k)
		var v := Label.new()
		v.text = str(r[1])
		DesignTokens.style_label(v, DesignTokens.FONT_LABEL_LG)
		v.add_theme_color_override("font_color", DesignTokens.COL_GOLD)
		row.add_child(v)
		_content_root.add_child(row)


func _count_pngs_recursive(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var n := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			n += _count_pngs_recursive(path + "/" + entry)
		elif entry.ends_with(".png"):
			n += 1
		entry = dir.get_next()
	return n


func _count_tres(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var n := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".tres"):
			n += 1
		entry = dir.get_next()
	return n


func _count_pngs(path: String) -> int:
	var dir := DirAccess.open(path)
	if dir == null:
		return 0
	var n := 0
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if entry.ends_with(".png"):
			n += 1
		entry = dir.get_next()
	return n


func _read_text_file(path: String) -> String:
	if not ResourceLoader.exists(path):
		var f := FileAccess.open(path, FileAccess.READ)
		if f == null:
			return "?"
		var t: String = f.get_as_text()
		f.close()
		return t
	return "?"
