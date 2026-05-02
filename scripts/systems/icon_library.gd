class_name IconLibrary
extends RefCounted

## Central registry for the SVG icon set under assets/icons/.
## Use IconLibrary.get_icon("lock") to fetch a Texture2D — replaces
## the emoji-as-text approach which depended on font fallbacks.
##
## All icons are 64×64 SVG, scale-clean. Godot 4 imports SVG natively.

const ICON_DIR := "res://assets/icons/"

const NAMES := [
	"lock", "coin", "heart", "sword", "star", "sparkle",
	"check", "x", "banana", "flask", "flower", "volleyball",
	"tongue", "gear", "warning", "sausage", "cart", "wheat",
	"target", "lightning",
	"difficulty_easy", "difficulty_normal", "difficulty_hard",
]

static var _cache: Dictionary = {}


## Returns a Texture2D for the named icon, or null if missing.
static func get_icon(name: String) -> Texture2D:
	if name in _cache:
		return _cache[name]
	var path := ICON_DIR + name + ".svg"
	if not ResourceLoader.exists(path):
		return null
	var tex: Texture2D = load(path)
	_cache[name] = tex
	return tex


## Build a TextureRect ready to drop into a layout.
static func make_rect(name: String, size_px: int = 24, tint: Color = Color.WHITE) -> TextureRect:
	var rect := TextureRect.new()
	rect.texture = get_icon(name)
	rect.custom_minimum_size = Vector2(size_px, size_px)
	rect.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
	rect.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	rect.modulate = tint
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	return rect


## Map of "tower id → icon name" for the role icons (banana for
## Lemurius, flask for JoJo, etc). Used by shop / tower-info to
## annotate each tower's specialty.
const TOWER_ROLE_ICONS := {
	"basic":   "banana",       # Lemurius
	"sniper":  "flower",       # Kühne
	"splash":  "flask",        # JoJo
	"cordula": "volleyball",   # Cordula
	"slow":    "tongue",       # Amösius
	"farm":    "wheat",        # Banani-Hof
	"support": "lightning",    # Migros-Villa (buff)
}


static func tower_role_icon(tower_id: String) -> Texture2D:
	var icon_name: String = TOWER_ROLE_ICONS.get(tower_id, "")
	if icon_name == "":
		return null
	return get_icon(icon_name)
