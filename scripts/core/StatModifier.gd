extends RefCounted
## StatModifier: the ONE modifier contract (fixme.md §9-11). Every system that
## feeds StatCalculator — equipment, talents, pets, buffs, debuffs — produces
## dicts shaped by make(). Extra keys are ignored by the math but MUST NOT
## invent parallel formats (no pet_bonus / equipment_bonus dialects).
## source_type enables the stat-breakdown debug view (BASE/Lvl/Equip/…).

const SOURCE_TYPES := [
	"base", "level", "equipment", "talent", "pet", "buff", "debuff",
	"temporary", "unknown",
]

const ItemInstance = preload("res://scripts/loot/ItemInstance.gd")


static func make(stat: String, value: Variant, is_percent: bool = false, source_type: String = "unknown", source_id: String = "") -> Dictionary:
	return {
		"stat": stat, "value": value, "is_percent": is_percent,
		"source_type": source_type, "source_id": source_id,
	}


## Strict: full runtime contract (stamped modifiers).
static func is_valid(mod: Variant) -> bool:
	if typeof(mod) != TYPE_DICTIONARY:
		return false
	var md := mod as Dictionary
	if not (md.get("stat", "") is String) or str(md.get("stat", "")) == "":
		return false
	var v: Variant = md.get("value", null)
	if not (v is int or v is float):
		return false
	if not (md.get("is_percent", false) is bool):
		return false
	return str(md.get("source_type", "unknown")) in SOURCE_TYPES


## Loose: raw template data (effects.json etc.) before build-time stamping.
static func is_valid_loose(mod: Variant) -> bool:
	if typeof(mod) != TYPE_DICTIONARY:
		return false
	var md := mod as Dictionary
	if not (md.get("stat", "") is String) or str(md.get("stat", "")) == "":
		return false
	var v: Variant = md.get("value", null)
	return v is int or v is float


static func source_of(mod: Dictionary) -> String:
	var st := str(mod.get("source_type", "unknown"))
	return st if st in SOURCE_TYPES else "unknown"


static func describe(mod: Dictionary) -> String:
	var label: String = ItemInstance.stat_label(str(mod.get("stat", "?")))
	var v: Variant = mod.get("value", 0)
	if v is float and v == floor(v):
		v = int(v)
	var text := "+%s%% %s" % [str(v), label] if bool(mod.get("is_percent", false)) else "+%s %s" % [str(v), label]
	return "%s [%s:%s]" % [text, source_of(mod), str(mod.get("source_id", "?"))]
