extends Resource
class_name AudioConfig

## Central registry of baked audio files (ROADMAP #25 + #35).
##
## sfx_manager.gd consults this before generating procedural audio. If an
## entry has a resolvable file path, the manager loads and plays it; if
## the file is missing or no entry exists, the manager falls back to the
## existing procedural synth. This lets us stream real audio in piece by
## piece — Kenney packs today, AI-generated clips tomorrow — without the
## game ever going silent during the transition.
##
## Keys follow a namespaced id scheme, e.g. "ui.click", "tower.basic.shoot.t0",
## "enemy.boss.hit", "music.level_1". Variants stored as arrays so the
## manager can random-pick between takes for variety.

@export var sfx: Dictionary = {}   # id -> String path (single) OR Array[String] (variants)
@export var music: Dictionary = {} # id -> String path


func get_sfx(id: String) -> String:
	# Returns a resource path to play, or "" if no baked entry. Picks a
	# random variant if the entry is an array.
	if not sfx.has(id):
		return ""
	var entry: Variant = sfx[id]
	if entry is String:
		return entry
	if entry is Array and entry.size() > 0:
		return entry[randi() % entry.size()]
	return ""


func get_music(id: String) -> String:
	if music.has(id):
		var v: Variant = music[id]
		if v is String:
			return v
	return ""
