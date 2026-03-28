extends Control

## UI for assigning friend photos to tower/enemy characters.
## Lets the player pick images from their device gallery.

signal photo_assigned(character_id: String, path: String)

@onready var character_list: VBoxContainer = $Panel/VBox/ScrollContainer/CharacterList
@onready var back_button: Button = $Panel/VBox/BackButton

# All character slots that can have friend photos
var _character_slots: Dictionary = {
	# Towers
	"friend_1": "Shooter Tower",
	"friend_2": "Sniper Tower",
	"friend_3": "Bomber Tower",
	"friend_4": "Freezer Tower",
	"friend_5": "DJ Booth Tower",
	# Enemies
	"enemy_1": "Grunt Enemy",
	"enemy_2": "Sprinter Enemy",
	"enemy_3": "Beefy Boy Enemy",
	"enemy_4": "Medic Enemy",
	"enemy_5": "Drone Enemy",
	"enemy_boss": "The Big One (Boss)",
}


func _ready() -> void:
	_populate_list()


func _populate_list() -> void:
	for child in character_list.get_children():
		child.queue_free()

	for char_id: String in _character_slots:
		var hbox := HBoxContainer.new()
		hbox.custom_minimum_size.y = 70

		var label := Label.new()
		label.text = _character_slots[char_id]
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		hbox.add_child(label)

		# Show current photo or placeholder
		var tex_rect := TextureRect.new()
		tex_rect.custom_minimum_size = Vector2(60, 60)
		tex_rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		var photo := GameManager.get_friend_photo(char_id)
		if photo:
			tex_rect.texture = photo
		hbox.add_child(tex_rect)

		var btn := Button.new()
		btn.text = "Pick Photo"
		btn.pressed.connect(_on_pick_photo.bind(char_id))
		hbox.add_child(btn)

		character_list.add_child(hbox)


func _on_pick_photo(character_id: String) -> void:
	# Open native file dialog to pick an image
	var dialog := FileDialog.new()
	dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	dialog.filters = PackedStringArray(["*.png", "*.jpg", "*.jpeg", "*.webp"])
	dialog.access = FileDialog.ACCESS_FILESYSTEM
	dialog.file_selected.connect(_on_file_selected.bind(character_id))
	add_child(dialog)
	dialog.popup_centered(Vector2i(600, 400))


func _on_file_selected(path: String, character_id: String) -> void:
	# Copy to user:// for persistence
	var dest_path := "user://photos/%s%s" % [character_id, path.get_extension()]
	DirAccess.make_dir_recursive_absolute("user://photos")

	var image := Image.load_from_file(path)
	if not image:
		return

	# Resize to reasonable size for mobile
	if image.get_width() > 256 or image.get_height() > 256:
		image.resize(256, 256, Image.INTERPOLATE_BILINEAR)

	image.save_png(dest_path)
	GameManager.assign_friend_photo(character_id, dest_path)
	photo_assigned.emit(character_id, dest_path)
	_populate_list()


func _on_back_button_pressed() -> void:
	visible = false
