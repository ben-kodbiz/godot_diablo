extends RefCounted
## LootGenerator: the full roll pipeline (todoagent.md #17).
##   1 base item → 2 item level → 3 rarity → 4 affix count → 5 affix pool →
##   6 roll affixes → 7 roll values → 8 level scaling → 9 rarity multiplier →
##   10 buff/effect → 11 display name → 12 unique id → item dict.
##
## Data-driven: counts + weights from rarities.json, pools from affixes.json
## (allowed_slots), buffs from effects.json (min_rarity + allowed_slots),
## scaling from balance/loot.json. No balance numbers live here.
## Depends only on RNGManager + DataManager passed in _init, so it runs
## identically in-game, headless, and in the simulators.

const ItemInstance = preload("res://scripts/loot/ItemInstance.gd")

const RANKS := ["normal", "uncommon", "rare", "epic", "legendary"]

## Item slot → affix/buff pool categories it may draw from.
const SLOT_CATEGORIES := {
	"main_hand": ["weapon"],
	"off_hand": ["weapon", "armor"],
	"armor": ["armor"],
	"helmet": ["armor"],
	"accessory": ["accessory"],
}

var _rng: Node
var _data: Node


func _init(rng: Node, data: Node) -> void:
	_rng = rng
	_data = data


func generate_item(base_id: String, item_level: int, rarity_override: String = "") -> Dictionary:
	var base: Dictionary = _data.get_equipment(base_id)
	if base.is_empty():
		push_error("LootGenerator: unknown base item '%s'." % base_id)
		return {}
	var rarity_id := rarity_override if rarity_override != "" else roll_rarity()
	var rarity: Dictionary = _data.get_rarity(rarity_id)
	var count := _roll_count(rarity)
	var slot := str(base.get("slot", "main_hand"))
	var affixes := roll_affixes(slot, count, item_level, _rarity_mult(rarity_id))
	var buff_count := int(rarity.get("bonus_buffs", 0))
	var buffs := roll_buffs(slot, rarity_id, buff_count)
	var item_id := ItemInstance.make_id(_rng)
	var display_name := build_name(str(base.get("name", base_id)), affixes, buffs)
	return ItemInstance.build(base, item_level, rarity_id, affixes, buffs, display_name, item_id)


## Weighted rarity roll. `luck_bonus` shifts weight toward rarer tiers.
func roll_rarity(luck_bonus: float = 0.0) -> String:
	var weights := PackedFloat32Array()
	var table: Dictionary = _data.get_table("rarities")
	for i in RANKS.size():
		var entry: Dictionary = table.get(RANKS[i], {})
		var w := float(entry.get("weight", 0))
		if i > 0:
			w *= 1.0 + luck_bonus * float(i) / float(RANKS.size())
		weights.append(w)
	var idx: int = _rng.weighted_choice(weights)
	if idx < 0:
		return "normal"
	return RANKS[idx]


func roll_affixes(slot: String, count: int, item_level: int, mult: float) -> Array:
	var pool := affix_pool(slot)
	pool.shuffle()
	var out: Array = []
	var per_level := _level_scaling()
	for i in mini(count, pool.size()):
		var def := pool[i] as Dictionary
		var raw := float(_rng.random_int(int(def.get("min_value", 1)), int(def.get("max_value", 1))))
		var is_pct := bool(def.get("is_percent", false))
		out.append({
			"id": str(def.get("id", "")),
			"stat": str(def.get("stat", "?")),
			"value": scale_value(raw, item_level, mult, per_level, is_pct),
			"is_percent": is_pct,
			"prefix": str(def.get("prefix", "")),
			"suffix": str(def.get("suffix", "")),
		})
	return out


func roll_buffs(slot: String, rarity_id: String, count: int) -> Array:
	var pool := buff_pool(slot, rarity_id)
	pool.shuffle()
	var out: Array = []
	for i in mini(count, pool.size()):
		out.append((pool[i] as Dictionary).duplicate(true))
	return out


func affix_pool(slot: String) -> Array:
	var cats: Array = SLOT_CATEGORIES.get(slot, ["weapon"])
	var table: Dictionary = _data.get_table("affixes")
	var out: Array = []
	for key in table.keys():
		var def := table[key] as Dictionary
		for allowed in (def.get("allowed_slots", []) as Array):
			if str(allowed) in cats:
				out.append(def)
				break
	return out


func buff_pool(slot: String, rarity_id: String) -> Array:
	var cats: Array = SLOT_CATEGORIES.get(slot, ["weapon"])
	var rank := RANKS.find(rarity_id)
	var table: Dictionary = _data.get_table("effects")
	var out: Array = []
	for key in table.keys():
		var def := table[key] as Dictionary
		var min_rank := RANKS.find(str(def.get("min_rarity", "normal")))
		if min_rank < 0:
			min_rank = 0
		if min_rank > rank:
			continue
		if not def.has("allowed_slots"):
			out.append(def)
			continue
		for allowed in (def.get("allowed_slots", []) as Array):
			if str(allowed) in cats:
				out.append(def)
				break
	return out


func build_name(base_name: String, affixes: Array, buffs: Array) -> String:
	for b in buffs:
		var bd := b as Dictionary
		if bd.has("grants_name"):
			return str(bd["grants_name"])
	var prefix := ""
	var suffix := ""
	if affixes.size() >= 1:
		prefix = str((affixes[0] as Dictionary).get("prefix", ""))
	if affixes.size() >= 2:
		suffix = str((affixes[1] as Dictionary).get("suffix", ""))
	elif affixes.size() == 1:
		suffix = str((affixes[0] as Dictionary).get("suffix", ""))
	var text := base_name
	if prefix != "":
		text = prefix + " " + text
	if suffix != "":
		text = text + " " + suffix
	return text


static func scale_value(raw: float, item_level: int, mult: float, per_level: float, is_percent: bool) -> Variant:
	var v := raw * (1.0 + float(maxi(item_level - 1, 0)) * per_level) * mult
	if is_percent:
		return snappedf(v, 0.1)
	return int(round(v))


func _roll_count(rarity: Dictionary) -> int:
	var lo := int(rarity.get("min_affixes", 0))
	var hi := int(rarity.get("max_affixes", lo))
	if hi < lo:
		hi = lo
	return _rng.random_int(lo, hi)


func _rarity_mult(rarity_id: String) -> float:
	var balance: Dictionary = _data.get_table("balance")
	var mults: Dictionary = balance.get("rarity_multipliers", {})
	return float(mults.get(rarity_id, 1.0))


func _level_scaling() -> float:
	var balance: Dictionary = _data.get_table("balance")
	var scaling: Dictionary = balance.get("scaling", {})
	return float(scaling.get("value_per_level", 0.08))
