extends Node
## Central content registry. The ONLY way systems access game content.
## See todoagent.md #54-55.
##
##   DataManager.get_weapon("bow") / get_pet / get_enemy / get_map
##
## Every JSON is validated at startup. Broken data produces a clear
##   DATA ERROR: <file> <id> missing field: <field>
## and is reported via has_errors()/get_errors() — never silently ignored.
## Getters return deep duplicates so callers can never mutate base definitions.

const PATHS := {
	"stats": "res://data/stats/stats.json",
	"weapons": "res://data/weapons/weapons.json",
	"equipment": "res://data/equipment/equipment.json",
	"rarities": "res://data/rarities/rarities.json",
	"affixes": "res://data/affixes/affixes.json",
	"effects": "res://data/effects/buffs.json",
	"balance": "res://data/balance/loot.json",
	"pet_balance": "res://data/balance/pets.json",
	"player_balance": "res://data/balance/player.json",
	"skill_balance": "res://data/balance/skills.json",
	"inventory_balance": "res://data/balance/inventory.json",
	"combat_balance": "res://data/balance/combat.json",
	"pets": "res://data/pets/pets.json",
	"species": "res://data/pets/species.json",
	"skills": "res://data/skills/skills.json",
	"talents": "res://data/talents/talents.json",
	"eggs": "res://data/eggs/eggs.json",
	"enemies": "res://data/enemies/enemies.json",
	"maps": "res://data/maps/maps.json",
	"drops": "res://data/drops/enemy_drops.json",
	"loot_tables": "res://data/drops/loot_tables.json",
}

## Required fields per entry. Content files are JSON objects: { "<id>": {...} }.
const REQUIRED := {
	"stats": ["id"],
	"weapons": ["id", "primary_stat", "family"],
	"equipment": ["id", "name", "base_type", "slot"],
	"rarities": ["weight", "min_affixes", "max_affixes"],
	"affixes": ["id", "stat", "min_value", "max_value"],
	"effects": ["id", "name", "modifiers"],
	"balance": [],
	"pet_balance": [],
	"player_balance": [],
	"skill_balance": [],
	"inventory_balance": [],
	"combat_balance": [],
	"pets": ["id", "rarity", "bonuses"],
	"species": ["id", "name", "wild_pool", "rarity_weights"],
	"skills": ["id", "name", "family", "unlock_level"],
	"talents": ["id", "name", "family"],
	"eggs": ["id", "hatch_time_hours"],
	"enemies": ["id", "tier", "health", "damage"],
	"maps": ["id", "biome"],
	"drops": [],
	"loot_tables": ["id"],
}

## Tables below this line are only required once their stage lands; missing
## files warn instead of erroring so Stage 0/1 boots before pets/maps exist.
const OPTIONAL_TABLES := ["pets", "enemies", "maps"]

const SUPPORTED_SCHEMA_VERSION := 1

var _tables: Dictionary = {}
var _errors: Array[String] = []


func _ready() -> void:
	load_all()


func load_all() -> bool:
	_tables.clear()
	_errors.clear()
	var ok := true
	for table in PATHS.keys():
		if not _load_table(table):
			if table in OPTIONAL_TABLES and _missing_file_only(table):
				continue
			ok = false
	return ok


func has_errors() -> bool:
	return not _errors.is_empty()


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_table(table: String) -> Dictionary:
	return (_tables.get(table, {}) as Dictionary).duplicate(true)


func get_weapon(id: String) -> Dictionary:
	return _get_entry("weapons", id)


func get_equipment(id: String) -> Dictionary:
	return _get_entry("equipment", id)


func get_effect(id: String) -> Dictionary:
	return _get_entry("effects", id)


func get_pet(id: String) -> Dictionary:
	return _get_entry("pets", id)


func get_species(id: String) -> Dictionary:
	return _get_entry("species", id)


func get_skill(id: String) -> Dictionary:
	return _get_entry("skills", id)


func get_talent(id: String) -> Dictionary:
	return _get_entry("talents", id)


func get_egg(id: String) -> Dictionary:
	return _get_entry("eggs", id)


func get_enemy(id: String) -> Dictionary:
	return _get_entry("enemies", id)


func get_map(id: String) -> Dictionary:
	return _get_entry("maps", id)


func get_stat(id: String) -> Dictionary:
	return _get_entry("stats", id)


func get_rarity(id: String) -> Dictionary:
	return _get_entry("rarities", id)


func get_affix(id: String) -> Dictionary:
	return _get_entry("affixes", id)


func _get_entry(table: String, id: String) -> Dictionary:
	var entries: Dictionary = _tables.get(table, {})
	if not entries.has(id):
		push_error("DATA ERROR: %s entry not found: %s" % [table, id])
		return {}
	return (entries[id] as Dictionary).duplicate(true)


## Schema versions (fixme.md §4-5): every content file carries
## `_schema_version`. Missing → warning + assume v1; unsupported → hard error
## so format changes never silently break content. Migrations (v1→v2…)
## will live in a future DataMigration; until then v1 is the only contract.
func _check_schema_version(table: String, path: String, parsed: Dictionary) -> bool:
	var ver: int = int(parsed.get("_schema_version", 0))
	if ver == 0:
		push_warning("DATA WARNING: %s has no _schema_version, assuming v1." % path)
		return true
	if ver != SUPPORTED_SCHEMA_VERSION:
		var msg := "DATA ERROR: %s schema v%d unsupported (this build reads v%d)." % [path, ver, SUPPORTED_SCHEMA_VERSION]
		_errors.append(msg)
		push_error(msg)
		return false
	return true


func _missing_file_only(table: String) -> bool:
	for e in _errors:
		if not e.begins_with("DATA ERROR: %s" % PATHS[table]):
			return false
	return true


func _load_table(table: String) -> bool:
	var path: String = PATHS[table]
	if not FileAccess.file_exists(path):
		var msg := "DATA ERROR: %s missing file (expected table '%s')" % [path, table]
		_errors.append(msg)
		push_warning(msg) if table in OPTIONAL_TABLES else push_error(msg)
		_tables[table] = {}
		return false
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		var msg := "DATA ERROR: %s cannot open file" % path
		_errors.append(msg)
		push_error(msg)
		_tables[table] = {}
		return false
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if typeof(parsed) != TYPE_DICTIONARY:
		var msg := "DATA ERROR: %s root must be a JSON object {\"<id>\": {...}}" % path
		_errors.append(msg)
		push_error(msg)
		_tables[table] = {}
		return false
	if not _check_schema_version(table, path, parsed):
		_tables[table] = {}
		return false
	var clean := {}
	for entry_id in parsed.keys():
		if str(entry_id).begins_with("_"):
			continue # schema metadata, not content (see docs/DATA_SCHEMA.md).
		clean[entry_id] = parsed[entry_id]
	var ok := true
	for entry_id in clean.keys():
		var entry: Variant = parsed[entry_id]
		if typeof(entry) != TYPE_DICTIONARY:
			var msg := "DATA ERROR: %s entry '%s' must be a JSON object" % [path, entry_id]
			_errors.append(msg)
			push_error(msg)
			ok = false
			continue
		for field in REQUIRED.get(table, []):
			if not (entry as Dictionary).has(field):
				var msg := "DATA ERROR: %s entry: %s missing field: %s" % [path, entry_id, field]
				_errors.append(msg)
				push_error(msg)
				ok = false
	_tables[table] = clean
	return ok
