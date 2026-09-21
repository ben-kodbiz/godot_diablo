extends RefCounted
## Semantic data validation (fixme.md §2-3). DataManager checks structure
## (files parse, required fields exist); this checks MEANING: field types,
## allowed enum values, numeric ranges, key/id consistency, and cross-file
## references (equipment→family, egg→pet, map→enemy/boss, skill→family…).
##
## Error format follows the FIXME contract:
##   DATA ERROR:\n\nFile: <path>\nEntry: <id>\nField: <field>\n<message>
## Warnings (recoverable) use DATA WARNING and do not fail validation.
## Every validator takes explicit tables — production via validate_all(),
## synthetic tables in data_check self-tests. Nothing here reads files
## except through the DataManager passed in _init.

const DM = preload("res://scripts/core/DataManager.gd")
const StatModifier = preload("res://scripts/core/StatModifier.gd")

const WEAPON_FAMILIES := ["ranged", "magic", "melee", "defensive"]
const ITEM_SLOTS := ["main_hand", "off_hand", "armor", "helmet", "accessory"]
const POOL_SLOTS := ["weapon", "armor", "accessory"]
const ENEMY_TIERS := ["normal", "elite", "boss"]
const PET_RARITIES := ["common", "rare", "epic", "legendary"]
## Closed stat vocabulary: stats.json keys + derived combat stats.
## New stats MUST be added here (domain invariant, fixme.md §51).
const DERIVED_STATS := [
	"attack_speed", "critical_chance", "critical_damage", "armor", "health",
	"mana", "move_speed", "damage", "skill_power", "block",
	"physical_damage", "ranged_damage", "magic_damage",
]

var _data: Node
var _errors: Array[String] = []
var _warnings: Array[String] = []


func _init(data: Node) -> void:
	_data = data


func get_errors() -> Array[String]:
	return _errors.duplicate()


func get_warnings() -> Array[String]:
	return _warnings.duplicate()


func validate_all(features: Dictionary = {}) -> bool:
	_errors.clear()
	_warnings.clear()
	var weapons: Dictionary = _data.get_table("weapons")
	var equipment: Dictionary = _data.get_table("equipment")
	var rarities: Dictionary = _data.get_table("rarities")
	var affixes: Dictionary = _data.get_table("affixes")
	var effects: Dictionary = _data.get_table("effects")
	var pets: Dictionary = _data.get_table("pets")
	var species: Dictionary = _data.get_table("species")
	var skills: Dictionary = _data.get_table("skills")
	var eggs: Dictionary = _data.get_table("eggs")
	var enemies: Dictionary = _data.get_table("enemies")
	var maps: Dictionary = _data.get_table("maps")
	var drops: Dictionary = _data.get_table("drops")
	var loot_tables: Dictionary = _data.get_table("loot_tables")
	var stats: Dictionary = _data.get_table("stats")
	var bal_loot: Dictionary = _data.get_table("balance")
	var bal_pets: Dictionary = _data.get_table("pet_balance")
	var bal_player: Dictionary = _data.get_table("player_balance")
	var bal_skills: Dictionary = _data.get_table("skill_balance")
	validate_stats(stats)
	validate_weapons(weapons)
	validate_equipment(equipment, weapons)
	validate_rarities(rarities)
	validate_affixes(affixes)
	validate_effects(effects, rarities)
	validate_pets(pets, eggs)
	validate_species(species, eggs)
	validate_skills(skills, weapons, bal_skills)
	validate_eggs(eggs, pets, species)
	validate_enemies(enemies, loot_tables)
	validate_maps(maps, enemies)
	validate_drops(drops, eggs)
	validate_loot_tables(loot_tables)
	validate_balance_loot(bal_loot, rarities)
	validate_balance_pets(bal_pets)
	validate_balance_player(bal_player, stats)
	validate_balance_skills(bal_skills, bal_player)
	validate_talents(_data.get_table("talents"), weapons, stats, bal_skills)
	validate_balance_inventory(_data.get_table("inventory_balance"))
	validate_balance_combat(_data.get_table("combat_balance"))
	if not features.is_empty():
		validate_features(features)
	return _errors.is_empty()


# --- helpers -------------------------------------------------------------

func _path(table: String) -> String:
	return str(DM.PATHS.get(table, table))


func _err(table: String, entry: String, field: String, msg: String) -> void:
	var text := "DATA ERROR:\n\nFile: %s\nEntry: %s\nField: %s\n%s" % [_path(table), entry, field, msg]
	_errors.append(text)
	push_error(text)


func _warn(table: String, entry: String, field: String, msg: String) -> void:
	var text := "DATA WARNING:\n\nFile: %s\nEntry: %s\nField: %s\n%s" % [_path(table), entry, field, msg]
	_warnings.append(text)
	push_warning(text)


func _is_num(v: Variant) -> bool:
	return v is int or v is float


func _is_int_like(v: Variant) -> bool:
	if v is int:
		return true
	if v is float and v == floor(v):
		return true
	return false


func _is_text(v: Variant) -> bool:
	return v is String and str(v) != ""


func _check_key_id(table: String, key: String, entry: Dictionary) -> void:
	if str(entry.get("id", key)) != key:
		_err(table, key, "id", "Key/id mismatch: key '%s' but id '%s'. IDs must match their keys." % [key, entry.get("id", "")])


func _valid_stat(stat: String, stats: Dictionary) -> bool:
	return stats.has(stat) or stat in DERIVED_STATS


# --- domains -------------------------------------------------------------

func validate_stats(table: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("stats", str(key), e)
		if not _is_text(e.get("name", "")):
			_err("stats", str(key), "name", "Must be a non-empty string.")
		if typeof(e.get("effects", [])) != TYPE_ARRAY:
			_err("stats", str(key), "effects", "Must be an array of stat keys.")
	return _errors.size() == before


func validate_weapons(table: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("weapons", str(key), e)
		if str(e.get("family", "")) not in WEAPON_FAMILIES:
			_err("weapons", str(key), "family", "Unknown family '%s'. Allowed: %s." % [e.get("family", ""), ", ".join(WEAPON_FAMILIES)])
		if not _is_text(e.get("primary_stat", "")):
			_err("weapons", str(key), "primary_stat", "Must be a non-empty stat id.")
		if not _is_text(e.get("talent_tree", "")):
			_err("weapons", str(key), "talent_tree", "Must be a non-empty tree id.")
		for slot in (e.get("slots", []) as Array):
			if str(slot) not in ITEM_SLOTS:
				_err("weapons", str(key), "slots", "Unknown slot '%s'." % slot)
	return _errors.size() == before


func validate_equipment(table: Dictionary, weapons: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("equipment", str(key), e)
		var slot := str(e.get("slot", ""))
		if slot not in ITEM_SLOTS:
			_err("equipment", str(key), "slot", "Unknown slot '%s'. Allowed: %s." % [slot, ", ".join(ITEM_SLOTS)])
		if not _is_int_like(e.get("required_level", 0)) or int(e.get("required_level", 0)) < 1:
			_err("equipment", str(key), "required_level", "Must be an integer >= 1.")
		var base_type := str(e.get("base_type", ""))
		if slot in ["main_hand", "off_hand"]:
			if not weapons.has(base_type):
				_err("equipment", str(key), "base_type", "Unknown weapon family '%s'. Referenced object does not exist." % base_type)
		elif base_type == "":
			_err("equipment", str(key), "base_type", "Must be a non-empty type id.")
		for stat in (e.get("base_stats", {}) as Dictionary).keys():
			var v: Variant = (e.get("base_stats", {}) as Dictionary)[stat]
			if not _is_num(v) or float(v) < 0.0:
				_err("equipment", str(key), "base_stats.%s" % stat, "Must be a number >= 0.")
		for extra in (e.get("occupies", []) as Array):
			if str(extra) not in ITEM_SLOTS:
				_err("equipment", str(key), "occupies", "Unknown slot '%s'." % extra)
		for req in (e.get("requirements", []) as Array):
			var rd := req as Dictionary
			if str(rd.get("type", "")) not in ["level", "stat"]:
				_err("equipment", str(key), "requirements", "Unknown requirement type '%s'." % rd.get("type", ""))
			elif str(rd.get("type", "")) == "stat" and not _is_text(rd.get("stat", "")):
				_err("equipment", str(key), "requirements", "Stat requirement needs a stat id.")
			elif not _is_num(rd.get("value", "")):
				_err("equipment", str(key), "requirements", "Requirement needs a numeric value.")
	return _errors.size() == before


func validate_rarities(table: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		if not _is_num(e.get("weight", -1)) or float(e.get("weight", -1)) < 0.0:
			_err("rarities", str(key), "weight", "Must be a number >= 0.")
		for field in ["min_affixes", "max_affixes", "bonus_buffs"]:
			if not _is_int_like(e.get(field, -1)) or int(e.get(field, -1)) < 0:
				_err("rarities", str(key), field, "Must be an integer >= 0.")
		if int(e.get("min_affixes", 0)) > int(e.get("max_affixes", 0)):
			_err("rarities", str(key), "min_affixes", "min_affixes exceeds max_affixes.")
		if int(e.get("max_affixes", 0)) > 10:
			_err("rarities", str(key), "max_affixes", "Exceeds sane maximum 10.")
	return _errors.size() == before


func validate_affixes(table: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("affixes", str(key), e)
		if not _is_num(e.get("min_value", "")) or not _is_num(e.get("max_value", "")):
			_err("affixes", str(key), "min_value/max_value", "Must be numbers.")
		elif float(e.get("min_value", 0)) < 0.0 or float(e.get("min_value", 0)) > float(e.get("max_value", 0)):
			_err("affixes", str(key), "min_value/max_value", "Require 0 <= min <= max.")
		if e.has("is_percent") and typeof(e["is_percent"]) != TYPE_BOOL:
			_err("affixes", str(key), "is_percent", "Must be a bool.")
		var slots: Array = e.get("allowed_slots", [])
		if slots.is_empty():
			_err("affixes", str(key), "allowed_slots", "Must list at least one pool slot.")
		for slot in slots:
			if str(slot) not in POOL_SLOTS:
				_err("affixes", str(key), "allowed_slots", "Unknown pool slot '%s'." % slot)
	return _errors.size() == before


func validate_effects(table: Dictionary, rarities: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("effects", str(key), e)
		if not _is_text(e.get("name", "")):
			_err("effects", str(key), "name", "Must be a non-empty string.")
		if typeof(e.get("modifiers", [])) != TYPE_ARRAY:
			_err("effects", str(key), "modifiers", "Must be an array.")
		else:
			for m in (e.get("modifiers", []) as Array):
				var md := m as Dictionary
				if not StatModifier.is_valid_loose(md):
					_err("effects", str(key), "modifiers", "Invalid modifier %s (need stat + numeric value)." % str(md))
		if not rarities.has(str(e.get("min_rarity", ""))):
			_err("effects", str(key), "min_rarity", "Unknown rarity '%s'. Referenced object does not exist." % e.get("min_rarity", ""))
		for slot in (e.get("allowed_slots", []) as Array):
			if str(slot) not in POOL_SLOTS:
				_err("effects", str(key), "allowed_slots", "Unknown pool slot '%s'." % slot)
		if e.has("trigger") and not ((e["trigger"] as Dictionary).has("type")):
			_err("effects", str(key), "trigger", "Trigger must define a type.")
	return _errors.size() == before


func validate_pets(table: Dictionary, eggs: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("pets", str(key), e)
		if str(e.get("rarity", "")) not in PET_RARITIES:
			_err("pets", str(key), "rarity", "Unknown rarity '%s'. Allowed: %s." % [e.get("rarity", ""), ", ".join(PET_RARITIES)])
		if not eggs.has(str(e.get("egg_type", ""))):
			_err("pets", str(key), "egg_type", "Unknown egg '%s'. Referenced object does not exist." % e.get("egg_type", ""))
		if typeof(e.get("bonuses", [])) != TYPE_ARRAY or (e.get("bonuses", []) as Array).is_empty():
			_err("pets", str(key), "bonuses", "Must be a non-empty array.")
	return _errors.size() == before


func validate_species(table: Dictionary, eggs: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("species", str(key), e)
		if not eggs.has(str(e.get("egg_type", ""))):
			_err("species", str(key), "egg_type", "Unknown egg '%s'. Referenced object does not exist." % e.get("egg_type", ""))
		var rw: Dictionary = e.get("rarity_weights", {})
		if rw.is_empty():
			_err("species", str(key), "rarity_weights", "Must define at least one rarity weight.")
		var positive := false
		for r in rw.keys():
			if str(r) not in PET_RARITIES:
				_err("species", str(key), "rarity_weights", "Unknown rarity '%s'." % r)
			if float(rw[r]) > 0.0:
				positive = true
		if not positive:
			_err("species", str(key), "rarity_weights", "No positive weight — species can never hatch.")
		var pool: Array = e.get("wild_pool", [])
		if pool.is_empty():
			_err("species", str(key), "wild_pool", "Must list at least one bonus entry.")
		for entry in pool:
			var ed := entry as Dictionary
			if not _is_num(ed.get("min", "")) or not _is_num(ed.get("max", "")):
				_err("species", str(key), "wild_pool", "Entry needs numeric min/max.")
			elif float(ed.get("min", 0)) < 0.0 or float(ed.get("min", 0)) > float(ed.get("max", 0)):
				_err("species", str(key), "wild_pool", "Require 0 <= min <= max.")
	return _errors.size() == before


func validate_skills(table: Dictionary, weapons: Dictionary, bal_skills: Dictionary) -> bool:
	var before := _errors.size()
	var cap := 10
	var caps: Dictionary = bal_skills.get("caps", {})
	if not caps.is_empty():
		cap = int(caps.get("max_skills_per_weapon", 10))
	var per_family := {}
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("skills", str(key), e)
		var family := str(e.get("family", ""))
		if not weapons.has(family):
			_err("skills", str(key), "family", "Unknown weapon family '%s'. Referenced object does not exist." % family)
		per_family[family] = int(per_family.get(family, 0)) + 1
		if not _is_int_like(e.get("unlock_level", 0)) or int(e.get("unlock_level", 0)) < 1 or int(e.get("unlock_level", 0)) > 20:
			_err("skills", str(key), "unlock_level", "Must be an integer in 1..20.")
		if not _is_int_like(e.get("max_rank", 0)) or int(e.get("max_rank", 0)) < 1:
			_err("skills", str(key), "max_rank", "Must be an integer >= 1.")
		for section in ["base", "per_rank"]:
			var sd: Dictionary = e.get(section, {})
			for field in ["damage_flat", "damage_pct"]:
				if not _is_num(sd.get(field, "")):
					_err("skills", str(key), "%s.%s" % [section, field], "Must be a number.")
	for family in per_family.keys():
		if int(per_family[family]) > cap:
			_err("skills", str(family), "family", "Family defines %d skills (max %d)." % [per_family[family], cap])
	return _errors.size() == before


func validate_talents(table: Dictionary, weapons: Dictionary, stats: Dictionary, bal_skills: Dictionary) -> bool:
	var before := _errors.size()
	var cap := 10
	var caps: Dictionary = bal_skills.get("caps", {})
	if not caps.is_empty():
		cap = int(caps.get("max_talents_per_tree", 10))
	var per_family := {}
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("talents", str(key), e)
		var family := str(e.get("family", ""))
		if not weapons.has(family):
			_err("talents", str(key), "family", "Unknown weapon family '%s'. Referenced object does not exist." % family)
		per_family[family] = int(per_family.get(family, 0)) + 1
		if not _is_int_like(e.get("max_rank", 0)) or int(e.get("max_rank", 0)) < 1:
			_err("talents", str(key), "max_rank", "Must be an integer >= 1.")
		if e.has("cost_per_rank") and (not _is_int_like(e["cost_per_rank"]) or int(e["cost_per_rank"]) < 1):
			_err("talents", str(key), "cost_per_rank", "Must be an integer >= 1.")
		var effects: Array = e.get("effects", [])
		if effects.is_empty():
			_err("talents", str(key), "effects", "Must list at least one effect.")
		for fx in effects:
			var fd := fx as Dictionary
			if not stats.has(str(fd.get("stat", ""))) and str(fd.get("stat", "")) not in DERIVED_STATS:
				_err("talents", str(key), "effects", "Unknown stat '%s'." % fd.get("stat", ""))
			if not _is_num(fd.get("value_per_rank", "")):
				_err("talents", str(key), "effects", "Effect needs a numeric value_per_rank.")
			if fd.has("is_percent") and typeof(fd["is_percent"]) != TYPE_BOOL:
				_err("talents", str(key), "effects", "is_percent must be a bool.")
	for family in per_family.keys():
		if int(per_family[family]) > cap:
			_err("talents", str(family), "family", "Tree defines %d talents (max %d)." % [per_family[family], cap])
	return _errors.size() == before


func validate_eggs(table: Dictionary, pets: Dictionary, species: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("eggs", str(key), e)
		if not _is_num(e.get("hatch_time_hours", 0)) or float(e.get("hatch_time_hours", 0)) <= 0.0:
			_err("eggs", str(key), "hatch_time_hours", "Must be a number > 0.")
		if not _is_int_like(e.get("min_map_level", 0)) or int(e.get("min_map_level", 0)) < 1:
			_err("eggs", str(key), "min_map_level", "Must be an integer >= 1.")
		var options := 0
		for opt in (e.get("possible_pets", []) as Array):
			var od := opt as Dictionary
			options += 1
			if not pets.has(str(od.get("pet", ""))):
				_err("eggs", str(key), "possible_pets", "Unknown pet '%s'. Referenced object does not exist." % od.get("pet", ""))
			if not _is_num(od.get("weight", 0)) or float(od.get("weight", 0)) <= 0.0:
				_err("eggs", str(key), "possible_pets", "Weight for '%s' must be > 0." % od.get("pet", ""))
		for opt in (e.get("wild_rolls", []) as Array):
			var od := opt as Dictionary
			options += 1
			if not species.has(str(od.get("species", ""))):
				_err("eggs", str(key), "wild_rolls", "Unknown species '%s'. Referenced object does not exist." % od.get("species", ""))
			if not _is_num(od.get("weight", 0)) or float(od.get("weight", 0)) <= 0.0:
				_err("eggs", str(key), "wild_rolls", "Weight for '%s' must be > 0." % od.get("species", ""))
		if options == 0:
			_err("eggs", str(key), "possible_pets/wild_rolls", "Egg has no hatch options.")
	return _errors.size() == before


func validate_enemies(table: Dictionary, loot_tables: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("enemies", str(key), e)
		if str(e.get("tier", "")) not in ENEMY_TIERS:
			_err("enemies", str(key), "tier", "Unknown tier '%s'. Allowed: %s." % [e.get("tier", ""), ", ".join(ENEMY_TIERS)])
		if not _is_num(e.get("health", 0)) or float(e.get("health", 0)) <= 0.0:
			_err("enemies", str(key), "health", "Must be a number > 0.")
		if not _is_num(e.get("damage", -1)) or float(e.get("damage", -1)) < 0.0:
			_err("enemies", str(key), "damage", "Must be a number >= 0.")
		if not _is_int_like(e.get("base_level", 0)) or int(e.get("base_level", 0)) < 1:
			_err("enemies", str(key), "base_level", "Must be an integer >= 1.")
		if not loot_tables.has(str(e.get("loot_table", ""))):
			_err("enemies", str(key), "loot_table", "Unknown loot table '%s'. Referenced object does not exist." % e.get("loot_table", ""))
		for phase in (e.get("phases", []) as Array):
			var pd := phase as Dictionary
			if not _is_num(pd.get("health_threshold", -1)) or float(pd.get("health_threshold", -1)) < 0.0 or float(pd.get("health_threshold", -1)) > 100.0:
				_err("enemies", str(key), "phases", "health_threshold must be within 0..100.")
		if e.has("tint"):
			var tint: Array = e.get("tint", [])
			if tint.size() != 3:
				_err("enemies", str(key), "tint", "Must be [r, g, b].")
			for c in tint:
				if not _is_num(c) or float(c) < 0.0 or float(c) > 1.0:
					_err("enemies", str(key), "tint", "Channels must be within 0..1.")
	return _errors.size() == before


func validate_maps(table: Dictionary, enemies: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("maps", str(key), e)
		if not _is_int_like(e.get("minimum_level", 0)) or int(e.get("minimum_level", 0)) < 1:
			_err("maps", str(key), "minimum_level", "Must be an integer >= 1.")
		if int(e.get("maximum_level", 0)) < int(e.get("minimum_level", 1)):
			_err("maps", str(key), "maximum_level", "Must be >= minimum_level.")
		if int(e.get("room_count_min", 1)) < 1 or int(e.get("room_count_min", 1)) > int(e.get("room_count_max", 1)):
			_err("maps", str(key), "room_count_min/max", "Require 1 <= min <= max.")
		var normals: Array = e.get("enemies", [])
		if normals.is_empty():
			_err("maps", str(key), "enemies", "Must list at least one normal enemy.")
		for id in normals:
			_check_map_enemy(str(key), str(id), enemies, "normal")
		for id in (e.get("elites", []) as Array):
			_check_map_enemy(str(key), str(id), enemies, "elite")
		var boss := str(e.get("boss", ""))
		if boss != "":
			if not enemies.has(boss):
				_err("maps", str(key), "boss", "Unknown enemy '%s'. Referenced object does not exist." % boss)
			elif str((enemies[boss] as Dictionary).get("tier", "")) != "boss":
				_err("maps", str(key), "boss", "'%s' is tier '%s', not boss." % [boss, (enemies[boss] as Dictionary).get("tier", "")])
		var gen: Dictionary = e.get("gen", {})
		if not gen.is_empty():
			for field in ["grid_width", "grid_height", "room_min_size", "room_max_size",
					"max_place_tries", "max_retries", "pack_min", "pack_max",
					"level_variance", "elite_level_bonus", "boss_level_bonus"]:
				if not _is_int_like(gen.get(field, -1)) or int(gen.get(field, -1)) < 0:
					_err("maps", str(key), "gen.%s" % field, "Must be an integer >= 0.")
			if int(gen.get("room_min_size", 1)) > int(gen.get("room_max_size", 1)):
				_err("maps", str(key), "gen", "room_min_size exceeds room_max_size.")
			if int(gen.get("pack_min", 1)) > int(gen.get("pack_max", 1)):
				_err("maps", str(key), "gen", "pack_min exceeds pack_max.")
	return _errors.size() == before


func _check_map_enemy(map_id: String, enemy_id: String, enemies: Dictionary, want_tier: String) -> void:
	var field := "enemies" if want_tier == "normal" else "elites"
	if not enemies.has(enemy_id):
		_err("maps", map_id, field, "Unknown enemy '%s'. Referenced object does not exist." % enemy_id)
	elif str((enemies[enemy_id] as Dictionary).get("tier", "")) != want_tier:
		_err("maps", map_id, field, "'%s' is tier '%s', expected '%s'." % [enemy_id, (enemies[enemy_id] as Dictionary).get("tier", ""), want_tier])


func validate_drops(table: Dictionary, eggs: Dictionary) -> bool:
	var before := _errors.size()
	var tiers: Dictionary = table.get("tiers", {})
	if tiers.is_empty():
		_err("drops", "(root)", "tiers", "Must define per-tier drop rules.")
	for tier in tiers.keys():
		if str(tier) not in ENEMY_TIERS:
			_err("drops", str(tier), "tier", "Unknown enemy tier '%s'." % tier)
			continue
		var td := tiers[tier] as Dictionary
		if not _is_num(td.get("egg_chance", -1)) or float(td.get("egg_chance", -1)) < 0.0 or float(td.get("egg_chance", -1)) > 100.0:
			_err("drops", str(tier), "egg_chance", "Must be within 0..100.")
		var pool: Dictionary = td.get("egg_pool", {})
		if pool.is_empty():
			_err("drops", str(tier), "egg_pool", "Must list at least one egg.")
		for egg_id in pool.keys():
			if not eggs.has(str(egg_id)):
				_err("drops", str(tier), "egg_pool", "Unknown egg '%s'. Referenced object does not exist." % egg_id)
			elif not _is_num(pool[egg_id]) or float(pool[egg_id]) <= 0.0:
				_err("drops", str(tier), "egg_pool", "Weight for '%s' must be > 0." % egg_id)
	return _errors.size() == before


func validate_loot_tables(table: Dictionary) -> bool:
	var before := _errors.size()
	for key in table.keys():
		var e := table[key] as Dictionary
		_check_key_id("loot_tables", str(key), e)
	return _errors.size() == before


func validate_balance_loot(table: Dictionary, rarities: Dictionary) -> bool:
	var before := _errors.size()
	var scaling: Dictionary = table.get("scaling", {})
	if not _is_num(scaling.get("value_per_level", -1)) or float(scaling.get("value_per_level", -1)) < 0.0 or float(scaling.get("value_per_level", -1)) > 1.0:
		_err("balance", "scaling", "value_per_level", "Must be within 0..1.")
	var mults: Dictionary = table.get("rarity_multipliers", {})
	for key in rarities.keys():
		if not mults.has(key):
			_err("balance", "rarity_multipliers", str(key), "Missing multiplier for rarity '%s'." % key)
		elif not _is_num(mults[key]) or float(mults[key]) <= 0.0:
			_err("balance", "rarity_multipliers", str(key), "Must be > 0.")
	for key in mults.keys():
		if not rarities.has(key):
			_err("balance", "rarity_multipliers", str(key), "Unknown rarity '%s'." % key)
	return _errors.size() == before


func validate_balance_pets(table: Dictionary) -> bool:
	var before := _errors.size()
	var scaling: Dictionary = table.get("rarity_scaling", {})
	if scaling.is_empty():
		_err("pet_balance", "(root)", "rarity_scaling", "Must define per-rarity scaling.")
	for key in scaling.keys():
		if str(key) not in PET_RARITIES:
			_err("pet_balance", str(key), "rarity", "Unknown pet rarity '%s'." % key)
			continue
		var rule := scaling[key] as Dictionary
		if not _is_int_like(rule.get("bonus_lines", 0)) or int(rule.get("bonus_lines", 0)) < 1 or int(rule.get("bonus_lines", 0)) > 10:
			_err("pet_balance", str(key), "bonus_lines", "Must be an integer in 1..10.")
		if not _is_num(rule.get("value_mult", 0)) or float(rule.get("value_mult", 0)) <= 0.0:
			_err("pet_balance", str(key), "value_mult", "Must be > 0.")
	return _errors.size() == before


func validate_balance_player(table: Dictionary, stats: Dictionary) -> bool:
	var before := _errors.size()
	var base: Dictionary = table.get("base_stats", {})
	var growth: Dictionary = table.get("per_level", {})
	for stat in base.keys():
		if not stats.has(str(stat)):
			_err("player_balance", "base_stats", str(stat), "Unknown stat '%s'." % stat)
		elif not _is_num(base[stat]):
			_err("player_balance", "base_stats", str(stat), "Must be a number.")
	for stat in growth.keys():
		if not base.has(stat):
			_err("player_balance", "per_level", str(stat), "Growth for unknown base stat '%s'." % stat)
	var curve: Dictionary = table.get("xp_curve", {})
	if not _is_num(curve.get("base", 0)) or float(curve.get("base", 0)) <= 0.0:
		_err("player_balance", "xp_curve", "base", "Must be > 0.")
	if not _is_num(curve.get("growth", 0)) or float(curve.get("growth", 0)) <= 0.0:
		_err("player_balance", "xp_curve", "growth", "Must be > 0.")
	if not _is_int_like(curve.get("max_level", 0)) or int(curve.get("max_level", 0)) < 1 or int(curve.get("max_level", 0)) > 99:
		_err("player_balance", "xp_curve", "max_level", "Must be an integer in 1..99.")
	for section in ["health", "mana", "move_speed"]:
		var sd: Dictionary = table.get(section, {})
		if sd.is_empty():
			_err("player_balance", "(root)", section, "Section missing.")
		for field in sd.keys():
			if not _is_num(sd[field]) or float(sd[field]) < 0.0:
				_err("player_balance", section, str(field), "Must be a number >= 0.")
	return _errors.size() == before


func validate_balance_skills(table: Dictionary, bal_player: Dictionary) -> bool:
	var before := _errors.size()
	var economy: Dictionary = table.get("economy", {})
	if not _is_int_like(economy.get("unlock_every_levels", 0)) or int(economy.get("unlock_every_levels", 0)) < 1:
		_err("skill_balance", "economy", "unlock_every_levels", "Must be an integer >= 1.")
	if not _is_int_like(economy.get("points_per_unlock", 0)) or int(economy.get("points_per_unlock", 0)) < 1:
		_err("skill_balance", "economy", "points_per_unlock", "Must be an integer >= 1.")
	var caps: Dictionary = table.get("caps", {})
	for field in ["max_skills_per_weapon", "max_skill_rank", "max_player_level"]:
		if not _is_int_like(caps.get(field, 0)) or int(caps.get(field, 0)) < 1:
			_err("skill_balance", "caps", field, "Must be an integer >= 1.")
	var player_curve: Dictionary = bal_player.get("xp_curve", {})
	if int(caps.get("max_player_level", 0)) != int(player_curve.get("max_level", 0)):
		_err("skill_balance", "caps", "max_player_level", "Mismatch with player xp_curve.max_level (%s)." % player_curve.get("max_level", "?"))
	return _errors.size() == before


func validate_balance_inventory(table: Dictionary) -> bool:
	var before := _errors.size()
	var grid: Dictionary = table.get("grid", {})
	for field in ["width", "height"]:
		if not _is_int_like(grid.get(field, 0)) or int(grid.get(field, 0)) < 1:
			_err("inventory_balance", "grid", field, "Must be an integer >= 1.")
	var stacking: Dictionary = table.get("stacking", {})
	if not _is_int_like(stacking.get("max_stack", 0)) or int(stacking.get("max_stack", 0)) < 1:
		_err("inventory_balance", "stacking", "max_stack", "Must be an integer >= 1.")
	return _errors.size() == before


func validate_balance_combat(table: Dictionary) -> bool:
	var before := _errors.size()
	var crit: Dictionary = table.get("crit", {})
	if not _is_num(crit.get("base_mult", 0)) or float(crit.get("base_mult", 0)) < 1.0:
		_err("combat_balance", "crit", "base_mult", "Must be >= 1.0.")
	var armor: Dictionary = table.get("armor", {})
	if not _is_num(armor.get("constant", 0)) or float(armor.get("constant", 0)) <= 0.0:
		_err("combat_balance", "armor", "constant", "Must be > 0.")
	var variance: Dictionary = table.get("variance", {})
	if not _is_num(variance.get("range", -1)) or float(variance.get("range", -1)) < 0.0 or float(variance.get("range", -1)) > 1.0:
		_err("combat_balance", "variance", "range", "Must be within 0..1.")
	var limits: Dictionary = table.get("limits", {})
	if not _is_int_like(limits.get("min_damage", 0)) or int(limits.get("min_damage", 0)) < 1:
		_err("combat_balance", "limits", "min_damage", "Must be an integer >= 1.")
	for section in ["player_basic", "enemy_scaling", "enemy_ai"]:
		var sd: Dictionary = table.get(section, {})
		if sd.is_empty():
			_err("combat_balance", "(root)", section, "Section missing.")
		for field in sd.keys():
			if not _is_num(sd[field]) or float(sd[field]) < 0.0:
				_err("combat_balance", section, str(field), "Must be a number >= 0.")
	return _errors.size() == before


func validate_features(flags: Dictionary) -> bool:
	var before := _errors.size()
	for key in flags.keys():
		if str(key).begins_with("_"):
			continue
		if typeof(flags[key]) != TYPE_BOOL:
			_err("config/features", str(key), "flag", "Must be a bool.")
	return _errors.size() == before
