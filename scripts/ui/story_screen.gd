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
var _pages: Array[String] = []
var _current_page: int = 0
var _char_index: int = 0
var _typing: bool = false
var _chars_per_second: float = 60.0


func _ready() -> void:
	_level_id = GameManager.current_level
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
	}
	var bg_path: String = bg_paths.get(_level_id, "res://assets/textures/ui/story_bg.png")
	if bg and ResourceLoader.exists(bg_path):
		bg.texture = load(bg_path)

	var lemurius_path := "res://assets/textures/towers/lemurius.png"
	var amosius_path := "res://assets/textures/towers/amosius.png"
	if left_portrait and ResourceLoader.exists(lemurius_path):
		left_portrait.texture = load(lemurius_path)
	if right_portrait and ResourceLoader.exists(amosius_path):
		right_portrait.texture = load(amosius_path)

	if title_label:
		title_label.text = intro.title
	if subtitle_label:
		subtitle_label.text = intro.subtitle
	if enemy_label:
		enemy_label.text = "Feind: %s" % intro.enemy_preview

	# Split the intro text into pages on double-newline. Each paragraph is
	# its own page — user reads at their own pace, taps to advance.
	var raw_text: String = intro.text
	_pages.clear()
	for para in raw_text.split("\n\n"):
		var trimmed := (para as String).strip_edges()
		if trimmed.length() > 0:
			_pages.append(trimmed)
	if _pages.is_empty():
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


func _update_page_indicator() -> void:
	if page_indicator:
		page_indicator.text = "%d / %d" % [_current_page + 1, _pages.size()]


func _process(delta: float) -> void:
	if not _typing:
		return
	_char_index += int(_chars_per_second * delta)
	var current_text: String = _pages[_current_page]
	if _char_index >= current_text.length():
		_char_index = current_text.length()
		_typing = false
		if _current_page >= _pages.size() - 1:
			continue_button.text = "LOS GAHT'S!"
		else:
			continue_button.text = "Wiiter ›"
	if story_label:
		story_label.text = current_text.left(_char_index)


func _on_continue_button_pressed() -> void:
	SfxManager.play_click()
	if _typing:
		# Tap during typewriter: finish current page immediately.
		_typing = false
		_char_index = _pages[_current_page].length()
		if story_label:
			story_label.text = _pages[_current_page]
		if _current_page >= _pages.size() - 1:
			continue_button.text = "LOS GAHT'S!"
		else:
			continue_button.text = "Wiiter ›"
		return

	if _current_page < _pages.size() - 1:
		_current_page += 1
		_start_page()
	else:
		var level_path := "res://scenes/game/level_%d.tscn" % _level_id
		if ResourceLoader.exists(level_path):
			get_tree().change_scene_to_file(level_path)
		else:
			get_tree().change_scene_to_file("res://scenes/game/game.tscn")
