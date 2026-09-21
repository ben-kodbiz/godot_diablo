extends Node
## Feature flags for unfinished systems. MVP keeps crafting/quests/sets
## stubbed off. See todoagent.md #53.
## Usage: FeatureManager.is_enabled("crafting")

const PATH := "res://data/config/features.json"

var _flags: Dictionary = {}


func _ready() -> void:
	_load()


func _load() -> void:
	if not FileAccess.file_exists(PATH):
		push_warning("FeatureManager: missing %s, using defaults." % PATH)
		_flags = _defaults()
		return
	var file := FileAccess.open(PATH, FileAccess.READ)
	if file == null:
		push_error("FeatureManager: cannot open %s" % PATH)
		_flags = _defaults()
		return
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("FeatureManager: %s is not a JSON object." % PATH)
		_flags = _defaults()
		return
	_flags = _defaults()
	for key in parsed.keys():
		if str(key).begins_with("_"):
			continue # schema metadata, not a flag.
		_flags[key] = bool(parsed[key])


func _defaults() -> Dictionary:
	return {
		"pets": true,
		"crafting": false,
		"quests": false,
		"bosses": true,
		"legendary_items": true,
		"procedural_maps": true,
	}


func is_enabled(feature: String) -> bool:
	return bool(_flags.get(feature, false))


func all_flags() -> Dictionary:
	return _flags.duplicate()
