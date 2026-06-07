extends Control

## Story cutscene with paginated dialogue — big fonts for mobile.
## Splits intro.text on double newlines into pages. Each page typewrites
## then waits for tap. Last page tap starts the level.

@onready var bg: TextureRect = $Background
@onready var title_label: Label = $Panel/VBox/TitleLabel
@onready var subtitle_label: Label = $Panel/VBox/SubtitleLabel
@onready var left_portrait: TextureRect = $Panel/VBox/PortraitRow/LeftPortrait
@onready var right_portrait: TextureRect = $Panel/VBox/PortraitRow/RightPortrait
@onready var story_label: Label = $Panel/VBox/StoryScroll/StoryLabel
@onready var enemy_label: Label = $Panel/VBox/EnemyLabel
@onready var continue_button: Button = $Panel/VBox/ContinueButton
@onready var page_indicator: Label = $Panel/VBox/PageIndicator

var _level_id: int = 1
# Pages can be plain strings (legacy) OR {"speaker", "text"} dicts
# (ROADMAP #47 multi-character dialogue).
var _pages: Array = []
var _current_page: int = 0
var _char_index: int = 0
var _typing: bool = false
var _last_tick_char: int = -1  # last _char_index at which a typewriter tick played
var _chars_per_second: float = 60.0
# Path used for async preload — resolved in _ready() so the level scene is
# already in memory by the time the player taps through all dialogue pages.
var _preload_path: String = ""


func _current_page_text() -> String:
	if _current_page < 0 or _current_page >= _pages.size():
		return ""
	var p: Variant = _pages[_current_page]
	if p is Dictionary:
		return p.get("text", "")
	return str(p)


func _current_page_speaker() -> String:
	if _current_page < 0 or _current_page >= _pages.size():
		return ""
	var p: Variant = _pages[_current_page]
	if p is Dictionary:
		return p.get("speaker", "")
	return ""


func _ready() -> void:
	_level_id = GameManager.current_level
	# Kick off background scene load immediately — player reads dialogue for
	# several seconds, giving the thread enough time to finish before tap.
	_preload_path = "res://scenes/game/level_%d.tscn" % _level_id
	if not ResourceLoader.exists(_preload_path):
		_preload_path = "res://scenes/game/game.tscn"
	ResourceLoader.load_threaded_request(_preload_path)
	var intro := Lore.get_level_intro(_level_id)

	var bg_paths := {
		1: "res://assets/textures/maps/migros_entrance.png",
		2: "res://assets/textures/maps/level2_bg.png",
		3: "res://assets/textures/maps/level3_bg.png",
		# L4/L5 don't have dedicated art yet — reuse thematic closest:
		# L4 "D'Chäsi-Keller" → cold-storage bg (level2)
		# L5 "D'Kasse" → Migros entrance (cash register area)
		4: "res://assets/textures/maps/level2_bg.png",
		5: "res://assets/textures/maps/migros_entrance.png",
		# L6 "Parkhuus" — reuse cold storage bg (industrial vibe)
		6: "res://assets/textures/maps/level2_bg.png",
		# L7 "S'Dach" — use level1_bg (daylight sky vibe) as closest
		7: "res://assets/textures/maps/level1_bg.png",
		# L8 "Coop-Einbruch" — rival store, reuse migros_entrance (similar layout)
		8: "res://assets/textures/maps/migros_entrance.png",
		# L9 "Cumulus-Punkte-Kern" — digital/dark, reuse cold-storage bg
		9: "res://assets/textures/maps/level2_bg.png",
		# L10 "Finale" — back where it began, full circle
		10: "res://assets/textures/maps/migros_entrance.png",
	}
	var bg_path: String = bg_paths.get(_level_id, "res://assets/textures/ui/story_bg.png")
	if bg and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)

	var lemurius_path := "res://assets/textures/towers/lemurius.png"
	if left_portrait and ResourceLoader.exists(lemurius_path):
		left_portrait.texture = load(lemurius_path)
	# Right portrait: show the level's main enemy (VS-style matchup)
	var enemy_textures: Dictionary = {
		1: "res://assets/textures/enemies/brotli_clean.png",
		2: "res://assets/textures/enemies/toblerone_clean.png",
		3: "res://assets/textures/enemies/cervelat_clean.png",
		4: "res://assets/textures/enemies/rivella_clean.png",
		5: "res://assets/textures/enemies/mteufel_clean.png",
		6: "res://assets/textures/enemies/fondue_clean.png",
		7: "res://assets/textures/enemies/mteufel_clean.png",
		8: "res://assets/textures/enemies/cervelat_clean.png",
		9: "res://assets/textures/enemies/rivella_clean.png",
		10: "res://assets/textures/enemies/mteufel_clean.png",
	}
	var enemy_path: String = enemy_textures.get(_level_id, "res://assets/textures/enemies/brotli_clean.png")
	if right_portrait and ResourceLoader.exists(enemy_path):
		right_portrait.texture = load(enemy_path)
	elif right_portrait:
		var fallback := "res://assets/textures/enemies/brotli_clean.png"
		if ResourceLoader.exists(fallback):
			right_portrait.texture = load(fallback)

	if title_label:
		title_label.text = intro.title
	if subtitle_label:
		subtitle_label.text = intro.subtitle
	if enemy_label:
		enemy_label.text = "Feind: %s" % intro.enemy_preview

	# Prefer the new multi-character `pages` array (ROADMAP #47) if the
	# level defines one. Falls back to the legacy \n\n split on
	# intro.text so levels can migrate incrementally.
	_pages.clear()
	var structured: Array = Lore.get_level_pages(_level_id)
	if structured.size() > 0 and structured[0] is Dictionary:
		_pages = structured
	else:
		var raw_text: String = intro.get("text", "")
		for para in raw_text.split("\n\n"):
			var trimmed := (para as String).strip_edges()
			if trimmed.length() > 0:
				_pages.append(trimmed)
		if _pages.is_empty() and raw_text != "":
			_pages.append(raw_text)

	_current_page = 0
	_start_page()


func _start_page() -> void:
	_char_index = 0
	_typing = true
	if story_label:
		story_label.text = ""
	continue_button.text = "Tippä zum wiiterläse…"
	_update_page_indicator()
	_update_speaker_highlight()


# D20: highlight the speaking portrait, dim the other.
# Left = odd-numbered friends (Lemurius, Kühne, JoJo).
# Right = even (Amösius, Cordula) + unknown speakers.
const _LEFT_SPEAKERS: Array = ["Lemurius", "Kühne", "JoJo"]
func _update_speaker_highlight() -> void:
	if not left_portrait or not right_portrait:
		return
	var speaker: String = _current_page_speaker()
	if speaker == "":
		left_portrait.modulate = Color.WHITE
		right_portrait.modulate = Color.WHITE
		return
	var left_active: bool = speaker in _LEFT_SPEAKERS
	left_portrait.modulate = Color.WHITE if left_active else Color(1, 1, 1, 0.35)
	right_portrait.modulate = Color(1, 1, 1, 0.35) if left_active else Color.WHITE


func _update_page_indicator() -> void:
	if page_indicator:
		page_indicator.text = "%d / %d" % [_current_page + 1, _pages.size()]


func _process(delta: float) -> void:
	if not _typing:
		return
	var prev_char: int = _char_index
	_char_index += int(_chars_per_second * delta)
	var current_text: String = _current_page_text()
	# D21: quiet typewriter tick every 3 chars so it's rhythmic not spammy
	var tick_interval: int = 3
	if _char_index / tick_interval != prev_char / tick_interval:
		if SfxManager and SfxManager.has_method("play_soft_pluck"):
			SfxManager.play_soft_pluck()
	if _char_index >= current_text.length():
		_char_index = current_text.length()
		_typing = false
		if _current_page >= _pages.size() - 1:
			continue_button.text = "LOS GAHT'S!"
		else:
			continue_button.text = "Wiiter ›"
	if story_label:
		var speaker: String = _current_page_speaker()
		var rendered: String = current_text.left(_char_index)
		if speaker != "":
			story_label.text = "[%s] %s" % [speaker, rendered]
		else:
			story_label.text = rendered


func _on_continue_button_pressed() -> void:
	SfxManager.play_click()
	if _typing:
		# Tap during typewriter: finish current page immediately.
		var full: String = _current_page_text()
		_typing = false
		_char_index = full.length()
		if story_label:
			var speaker: String = _current_page_speaker()
			story_label.text = ("[%s] %s" % [speaker, full]) if speaker != "" else full
		if _current_page >= _pages.size() - 1:
			continue_button.text = "LOS GAHT'S!"
		else:
			continue_button.text = "Wiiter ›"
		return

	if _current_page < _pages.size() - 1:
		# D23: brief fade-to-black between pages so the background can shift.
		if story_label:
			var fade_out := story_label.create_tween()
			fade_out.tween_property(story_label, "modulate:a", 0.0, 0.12)
			await fade_out.finished
		_current_page += 1
		_start_page()
		if story_label:
			story_label.modulate.a = 0.0
			var fade_in := story_label.create_tween()
			fade_in.tween_property(story_label, "modulate:a", 1.0, 0.18)
	else:
		# Background preload warmed the cache; always use change_scene_to_file()
		# here. Using change_scene_to_packed() with a background-thread-loaded
		# PackedScene causes GDScript nodes to instantiate with null scripts in
		# headless Godot 4 — towers fire "permanently broken" projectiles and
		# deal 0 damage (issue #728). change_scene_to_file() reads from the warm
		# cache so there is no disk-read hitch either way.
		if _preload_path != "" and \
				ResourceLoader.load_threaded_get_status(_preload_path) == ResourceLoader.THREAD_LOAD_LOADED:
			ResourceLoader.load_threaded_get(_preload_path)  # consume to free pending slot
		var level_path := "res://scenes/game/level_%d.tscn" % _level_id
		if ResourceLoader.exists(level_path):
			get_tree().change_scene_to_file(level_path)
		else:
			get_tree().change_scene_to_file("res://scenes/game/game.tscn")
