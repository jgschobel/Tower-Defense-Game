class_name AIImageGenerator
extends Node

## Generates images using Stability AI's API (Stable Diffusion).
## Get a free API key at https://platform.stability.ai/account/keys
##
## Usage:
##   var gen = AIImageGenerator.new()
##   add_child(gen)
##   gen.image_generated.connect(_on_image_ready)
##   gen.generate("cute cartoon gecko tower defense character, chibi style, transparent bg")

signal image_generated(texture: ImageTexture, prompt: String)
signal generation_failed(error: String)

const API_URL := "https://api.stability.ai/v2beta/stable-image/generate/sd3"
const SAVE_DIR := "user://generated_images/"

## Set your API key here or via set_api_key()
var api_key: String = ""

var _http: HTTPRequest
var _current_prompt: String = ""


func _ready() -> void:
	_http = HTTPRequest.new()
	_http.request_completed.connect(_on_request_completed)
	add_child(_http)
	DirAccess.make_dir_recursive_absolute(SAVE_DIR)

	# Try to load saved API key
	var key_path := "user://stability_api_key.txt"
	if FileAccess.file_exists(key_path):
		var f := FileAccess.open(key_path, FileAccess.READ)
		if f:
			api_key = f.get_as_text().strip_edges()


func set_api_key(key: String) -> void:
	api_key = key
	# Persist the key
	var f := FileAccess.open("user://stability_api_key.txt", FileAccess.WRITE)
	if f:
		f.store_string(key)


func generate(prompt: String, style_preset: String = "comic-book") -> void:
	if api_key == "":
		generation_failed.emit("No API key set. Get one at https://platform.stability.ai/account/keys")
		return

	_current_prompt = prompt

	# Build multipart form data
	var boundary := "----GodotBoundary%d" % randi()
	var body := PackedByteArray()

	# Add prompt field
	body.append_array(_multipart_field(boundary, "prompt", prompt))
	# Add negative prompt
	body.append_array(_multipart_field(boundary, "negative_prompt", "blurry, ugly, deformed, realistic photo, text, watermark"))
	# Output format
	body.append_array(_multipart_field(boundary, "output_format", "png"))
	# Model
	body.append_array(_multipart_field(boundary, "model", "sd3-turbo"))
	# Aspect ratio (square for game icons)
	body.append_array(_multipart_field(boundary, "aspect_ratio", "1:1"))

	# Close boundary
	body.append_array(("--%s--\r\n" % boundary).to_utf8_buffer())

	var headers := [
		"Authorization: Bearer %s" % api_key,
		"Content-Type: multipart/form-data; boundary=%s" % boundary,
		"Accept: image/*",
	]

	var err := _http.request_raw(API_URL, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		generation_failed.emit("HTTP request failed: %s" % str(err))


func _multipart_field(boundary: String, name: String, value: String) -> PackedByteArray:
	var part := "--%s\r\nContent-Disposition: form-data; name=\"%s\"\r\n\r\n%s\r\n" % [boundary, name, value]
	return part.to_utf8_buffer()


func _on_request_completed(result: int, response_code: int, headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS:
		generation_failed.emit("Request failed (result: %d)" % result)
		return

	if response_code != 200:
		# Try to parse error message
		var error_text := body.get_string_from_utf8()
		generation_failed.emit("API error %d: %s" % [response_code, error_text.left(200)])
		return

	# Body is raw PNG data
	var image := Image.new()
	var err := image.load_png_from_buffer(body)
	if err != OK:
		generation_failed.emit("Failed to decode image from response")
		return

	# Save to disk
	var filename := "gen_%d.png" % (Time.get_unix_time_from_system() * 1000)
	var save_path := SAVE_DIR + filename
	image.save_png(save_path)

	var texture := ImageTexture.create_from_image(image)
	image_generated.emit(texture, _current_prompt)
	print("AI Image generated: %s -> %s" % [_current_prompt, save_path])
