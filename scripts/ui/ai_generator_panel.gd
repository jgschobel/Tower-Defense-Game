extends Control

## In-game panel for generating AI images for towers/enemies.
## Access from the settings/main menu.

@onready var api_key_input: LineEdit = $Panel/VBox/APIKeyInput
@onready var prompt_input: LineEdit = $Panel/VBox/PromptInput
@onready var generate_button: Button = $Panel/VBox/GenerateButton
@onready var status_label: Label = $Panel/VBox/StatusLabel
@onready var preview: TextureRect = $Panel/VBox/Preview
@onready var presets_container: HBoxContainer = $Panel/VBox/Presets
@onready var save_as_option: OptionButton = $Panel/VBox/SaveAsOption
@onready var save_button: Button = $Panel/VBox/SaveButton
@onready var close_button: Button = $Panel/VBox/CloseButton

var _generator: AIImageGenerator
var _last_generated_texture: ImageTexture = null

# Quick prompt presets
var _presets := {
	"Tower": "cute cartoon tower defense character, chibi style, game sprite, colorful, transparent background, top-down view",
	"Enemy": "angry cartoon enemy creature, chibi style, game sprite, menacing, colorful, transparent background",
	"Boss": "giant cartoon boss monster, intimidating, game sprite, detailed, colorful, transparent background",
	"Item": "shiny cartoon game item icon, simple, clean, colorful, transparent background",
	"Funny": "hilarious cartoon character, exaggerated features, goofy expression, game sprite, colorful, transparent background",
}

# Where to save generated images
var _save_targets := {
	"Tower Texture": "res://assets/textures/towers/",
	"Enemy Texture": "res://assets/textures/enemies/",
	"Projectile": "res://assets/textures/projectiles/",
	"UI Icon": "res://assets/textures/ui/",
}


func _ready() -> void:
	_generator = AIImageGenerator.new()
	add_child(_generator)
	_generator.image_generated.connect(_on_image_generated)
	_generator.generation_failed.connect(_on_generation_failed)

	# Load saved API key
	if _generator.api_key != "":
		api_key_input.text = _generator.api_key
		api_key_input.placeholder_text = "Key loaded!"

	# Build preset buttons
	for preset_name in _presets:
		var btn := Button.new()
		btn.text = preset_name
		btn.pressed.connect(_on_preset_pressed.bind(preset_name))
		presets_container.add_child(btn)

	# Build save target dropdown
	for target_name in _save_targets:
		save_as_option.add_item(target_name)

	save_button.disabled = true


func _on_preset_pressed(preset_name: String) -> void:
	prompt_input.text = _presets[preset_name]


func _on_generate_button_pressed() -> void:
	var key := api_key_input.text.strip_edges()
	if key != "":
		_generator.set_api_key(key)

	var prompt := prompt_input.text.strip_edges()
	if prompt == "":
		status_label.text = "Enter a prompt first!"
		return

	status_label.text = "Generating..."
	generate_button.disabled = true
	_generator.generate(prompt)


func _on_image_generated(texture: ImageTexture, prompt: String) -> void:
	_last_generated_texture = texture
	preview.texture = texture
	status_label.text = "Done! Click Save to use in-game."
	generate_button.disabled = false
	save_button.disabled = false


func _on_generation_failed(error: String) -> void:
	status_label.text = "Error: %s" % error
	generate_button.disabled = false


func _on_save_button_pressed() -> void:
	if _last_generated_texture == null:
		return

	var target_idx := save_as_option.selected
	var target_name: String = save_as_option.get_item_text(target_idx)
	var target_dir: String = _save_targets[target_name]

	var filename := "ai_%d.png" % (Time.get_unix_time_from_system() * 1000)
	var save_path := target_dir + filename

	var image := _last_generated_texture.get_image()
	image.save_png(save_path)
	status_label.text = "Saved to %s" % save_path


func _on_close_button_pressed() -> void:
	visible = false
