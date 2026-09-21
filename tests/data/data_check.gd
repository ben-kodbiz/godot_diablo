extends SceneTree
## Headless data gate (fixme.md §46, TASK 01 acceptance).
## Usage: --script res://tests/data/data_check.gd -- --check
## Runs DataValidator over ALL production JSON (semantic + cross-reference),
## then negative self-tests with synthetic bad tables to prove detection works.
## Prints DATA CHECK: PASS only when everything is clean.

const DataScript = preload("res://scripts/core/DataManager.gd")
const ValidatorScript = preload("res://scripts/core/DataValidator.gd")


func _init() -> void:
	var data: Node = DataScript.new()
	data.load_all()
	if data.has_errors():
		for e in data.get_errors():
			printerr(e)
		data.free()
		quit(2)
		return
	var validator: RefCounted = ValidatorScript.new(data)
	var ok: bool = validator.validate_all(_load_features())
	for w in validator.get_warnings():
		print(w)
	for e in validator.get_errors():
		printerr(e)
	var self_ok := _run_self_tests(validator)
	data.free()
	if ok and self_ok:
		print("DATA CHECK: PASS")
		quit(0)
	else:
		printerr("DATA CHECK: FAIL")
		quit(1)


func _load_features() -> Dictionary:
	var path := "res://data/config/features.json"
	if not FileAccess.file_exists(path):
		return {}
	var parsed: Variant = JSON.parse_string(FileAccess.open(path, FileAccess.READ).get_as_text())
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Synthetic bad tables MUST fail; minimal good tables MUST pass.
func _run_self_tests(v: RefCounted) -> bool:
	var failures: Array[String] = []
	var weapons := {"bow": {"id": "bow", "name": "Bow", "family": "ranged",
		"primary_stat": "dex", "talent_tree": "bow", "slots": ["main_hand"]}}
	# 1. Unknown weapon family reference.
	var bad_equip := {"x": {"id": "x", "name": "X", "base_type": "nope",
		"slot": "main_hand", "required_level": 1, "base_stats": {}}}
	if v.validate_equipment(bad_equip, weapons):
		failures.append("unknown base_type not detected")
	# 2. Unknown pet reference in egg.
	var bad_egg := {"e": {"id": "e", "name": "E", "hatch_time_hours": 1,
		"min_map_level": 1,
		"possible_pets": [{"pet": "forest_dragon", "weight": 10}], "wild_rolls": []}}
	if v.validate_eggs(bad_egg, {}, {}):
		failures.append("unknown pet not detected")
	# 3. Boss pointer at a non-boss enemy.
	var enemies := {"g": {"id": "g", "name": "G", "tier": "normal", "health": 10,
		"damage": 1, "base_level": 1, "loot_table": "t"}}
	var bad_map := {"m": {"id": "m", "name": "M", "biome": "forest",
		"minimum_level": 1, "maximum_level": 5, "room_count_min": 1,
		"room_count_max": 2, "enemies": ["g"], "elites": [], "boss": "g"}}
	if v.validate_maps(bad_map, enemies):
		failures.append("wrong-tier boss not detected")
	# 4. Invalid numeric range.
	var bad_rar := {"r": {"weight": 1, "min_affixes": 3, "max_affixes": 1, "bonus_buffs": 0}}
	if v.validate_rarities(bad_rar):
		failures.append("min>max affixes not detected")
	# 5. Invalid enum.
	var bad_skill := {"s": {"id": "s", "name": "S", "family": "gun",
		"unlock_level": 1, "max_rank": 1,
		"base": {"damage_flat": 1, "damage_pct": 0}, "per_rank": {"damage_flat": 1, "damage_pct": 0}}}
	if v.validate_skills(bad_skill, weapons, {}):
		failures.append("unknown skill family not detected")
	# 6. Key/id mismatch (duplicate-ID class).
	var bad_pet := {"a": {"id": "b", "name": "B", "rarity": "common",
		"egg_type": "e", "bonuses": [{"stat": "str", "value": 1}]}}
	if v.validate_pets(bad_pet, {"e": {}}):
		failures.append("key/id mismatch not detected")
	# 7. Minimal good tables pass.
	var good_equip := {"b": {"id": "b", "name": "B", "base_type": "bow",
		"slot": "main_hand", "required_level": 1, "base_stats": {"dex": 2}}}
	if not v.validate_equipment(good_equip, weapons):
		failures.append("valid equipment rejected")
	var good_egg := {"e": {"id": "e", "name": "E", "hatch_time_hours": 1,
		"min_map_level": 1,
		"possible_pets": [{"pet": "p", "weight": 10}], "wild_rolls": []}}
	var good_pets := {"p": {"id": "p", "name": "P", "rarity": "common",
		"egg_type": "e", "bonuses": [{"stat": "str", "value": 1}]}}
	if not v.validate_eggs(good_egg, good_pets, {}):
		failures.append("valid egg rejected")
	if not v.validate_pets(good_pets, {"e": {}}):
		failures.append("valid pet rejected")
	if failures.is_empty():
		print("SELF-TESTS: PASS (9 cases)")
		return true
	for f in failures:
		printerr("SELF-TEST FAIL: " + f)
	return false
