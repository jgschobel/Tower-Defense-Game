extends Control

## Developer variant picker — user requested a way to compare 30+ AI-
## generated design candidates side by side and mark preferred ones.
##
## Reads variant manifests from `res://assets/variants/<category>/manifest.json`
## (filed when art-request workflow lands variant batches). For each
## category (towers, enemies, ui), shows a grid of all variants with
## thumbnails. Click → mark as "selected". Persisted to user://variants.json.
##
## At runtime, base_tower / base_enemy etc. read these preferences via
## GameManager.get_preferred_variant("towers/lemurius") to pick textures.

const PREFS_PATH := "user://variants.json"

var _prefs: Dictionary = {}


func _ready() -> void:
	# Solid backdrop
	var bg := ColorRect.new()
	bg.color = DesignTokens.COL_BG_DEEPEST
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(bg)
	_load_prefs()
	_build_ui()


func _build_ui() -> void:
	var root := VBoxContainer.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.offset_left = DesignTokens.SP_L
	root.offset_right = -DesignTokens.SP_L
	root.offset_top = DesignTokens.SP_M
	root.offset_bottom = -DesignTokens.SP_M
	root.add_theme_constant_override("separation", DesignTokens.SP_M)
	add_child(root)

	# Header
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", DesignTokens.SP_M)
	root.add_child(header)
	var title := Label.new()
	title.text = "Entwickler — Design Variante"
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

	# Subtitle
	var sub := Label.new()
	sub.text = "Klick uf än Variante zum si als Standard merka. Aagloffe wird's vom Spil über GameManager.get_preferred_variant()."
	sub.autowrap_mode = TextServer.AUTOWRAP_WORD
	DesignTokens.style_label(sub, DesignTokens.FONT_LABEL_SM, true)
	root.add_child(sub)

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	root.add_child(scroll)

	var content := VBoxContainer.new()
	content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	content.add_theme_constant_override("separation", DesignTokens.SP_XL)
	scroll.add_child(content)

	# Build category sections by scanning assets/variants/* directories
	var categories: Array = _discover_categories()
	if categories.is_empty():
		var empty := Label.new()
		empty.text = "(No variants yet — file art-requests to generate them via the Gemini API.)"
		DesignTokens.style_label(empty, DesignTokens.FONT_LABEL, true)
		content.add_child(empty)
		return
	for category in categories:
		content.add_child(_build_category_section(category))


func _discover_categories() -> Array:
	# Look for res://assets/variants/<cat>/<asset_id>/<variant_n>.png
	# Returns Array[Dictionary{name, assets: Array[{id, variants: Array[path]}]}]
	var out: Array = []
	var dir := DirAccess.open("res://assets/variants")
	if dir == null:
		return out
	dir.list_dir_begin()
	var entry := dir.get_next()
	while entry != "":
		if dir.current_is_dir() and not entry.begins_with("."):
			out.append({"name": entry, "assets": _discover_assets("res://assets/variants/%s" % entry)})
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


func _build_category_section(category: Dictionary) -> Control:
	var section := VBoxContainer.new()
	section.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	section.add_theme_constant_override("separation", DesignTokens.SP_S)
	var heading := Label.new()
	heading.text = "▸ " + str(category.name).capitalize()
	DesignTokens.style_heading(heading, DesignTokens.FONT_LABEL_LG)
	section.add_child(heading)
	for asset in category.assets:
		section.add_child(_build_asset_row(category.name, asset))
	return section


func _build_asset_row(category: String, asset: Dictionary) -> Control:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", DesignTokens.SP_S)
	var name_lbl := Label.new()
	name_lbl.text = str(asset.id)
	name_lbl.custom_minimum_size = Vector2(120, 0)
	DesignTokens.style_label(name_lbl, DesignTokens.FONT_LABEL_SM)
	row.add_child(name_lbl)
	var pref_key := "%s/%s" % [category, asset.id]
	var current_pref: String = _prefs.get(pref_key, "")
	for variant_path in asset.variants:
		var thumb := _build_variant_button(pref_key, variant_path, variant_path == current_pref)
		row.add_child(thumb)
	return row


func _build_variant_button(pref_key: String, variant_path: String, is_selected: bool) -> Control:
	var btn := Button.new()
	btn.custom_minimum_size = Vector2(96, 96)
	btn.flat = true
	btn.icon = load(variant_path)
	btn.expand_icon = true
	# Selected = gold border, unselected = faint border
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
		# Rebuild to reflect new selection
		for c in get_children():
			if c.name != "":
				c.queue_free()
		_build_ui())
	return btn


func _load_prefs() -> void:
	if not FileAccess.file_exists(PREFS_PATH):
		return
	var f := FileAccess.open(PREFS_PATH, FileAccess.READ)
	if f == null:
		return
	var raw := f.get_as_text()
	var parsed = JSON.parse_string(raw)
	if parsed is Dictionary:
		_prefs = parsed


func _save_prefs() -> void:
	var f := FileAccess.open(PREFS_PATH, FileAccess.WRITE)
	if f == null:
		return
	f.store_string(JSON.stringify(_prefs))
