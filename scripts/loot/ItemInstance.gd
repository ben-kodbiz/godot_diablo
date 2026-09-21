extends RefCounted
## ItemInstance: assembles a unique item dict from a base definition plus
## rolled affixes/buffs. Never mutates base definitions — everything is
## duplicated in. Also owns rarity presentation + tooltip text so the
## simulator, HUD tooltip, and compare view all render identically.
## See todoagent.md #18-19, #105.

const RARITY_LABELS := {
	"normal": "Normal",
	"uncommon": "Uncommon (green)",
	"rare": "Rare (blue)",
	"epic": "Epic (purple)",
	"legendary": "Legendary",
}

const RARITY_COLORS := {
	"normal": Color(0.62, 0.64, 0.69),
	"uncommon": Color(0.29, 0.87, 0.5),
	"rare": Color(0.38, 0.65, 0.98),
	"epic": Color(0.75, 0.52, 0.99),
	"legendary": Color(0.98, 0.57, 0.24),
}

const STAT_LABELS := {
	"str": "STR", "dex": "DEX", "int": "INT", "vit": "VIT", "luck": "LUCK",
	"attack_speed": "Attack Speed", "critical_chance": "Critical Chance",
	"critical_damage": "Critical Damage", "armor": "Armor", "health": "Health",
	"mana": "Mana", "move_speed": "Move Speed", "damage": "Damage",
	"skill_power": "Skill Power", "block": "Block",
	"physical_damage": "Physical Damage", "ranged_damage": "Ranged Damage",
	"magic_damage": "Magic Damage",
}


static func make_id(rng: Node) -> String:
	var n: int = rng.random_int(0, 0x7FFFFFFF)
	return "itm_%08x" % n


static func rarity_label(rarity_id: String) -> String:
	return str(RARITY_LABELS.get(rarity_id, rarity_id))


static func rarity_color(rarity_id: String) -> Color:
	return RARITY_COLORS.get(rarity_id, Color.WHITE)


static func stat_label(stat: String) -> String:
	if STAT_LABELS.has(stat):
		return str(STAT_LABELS[stat])
	return stat.capitalize()


static func format_stat(stat: String, value: Variant, is_percent: bool) -> String:
	var label := stat_label(stat)
	var v: Variant = value
	if v is float and v == floor(v):
		v = int(v)
	if is_percent:
		return "+%s%% %s" % [str(v), label]
	return "+%s %s" % [str(v), label]


static func format_modifier(mod: Dictionary) -> String:
	return format_stat(
		str(mod.get("stat", "?")),
		mod.get("value", 0),
		bool(mod.get("is_percent", false))
	)


## Assembles the final item. `affixes`: [{id,stat,value,is_percent}],
## `buffs`: full effect definitions (id,name,description,modifiers,trigger?).
static func build(
	base: Dictionary, item_level: int, rarity_id: String,
	affixes: Array, buffs: Array, display_name: String, unique_id: String
) -> Dictionary:
	var stats := {}
	for key in (base.get("base_stats", {}) as Dictionary).keys():
		stats[key] = (base.get("base_stats", {}) as Dictionary)[key]
	var affix_lines: Array = []
	for a in affixes:
		var ad := a as Dictionary
		var stat := str(ad.get("stat", "?"))
		var value: Variant = ad.get("value", 0)
		var current: Variant = stats.get(stat, 0)
		if current is int and value is int:
			stats[stat] = int(current) + int(value)
		elif current is float or value is float:
			stats[stat] = float(current) + float(value)
		else:
			stats[stat] = value
		affix_lines.append({
			"id": str(ad.get("id", "")),
			"stat": stat, "value": value,
			"is_percent": bool(ad.get("is_percent", false)),
		})
	var stored_buffs: Array = []
	var legendary_effect := {}
	for b in buffs:
		var bd := (b as Dictionary).duplicate(true)
		stored_buffs.append(bd)
		if (bd as Dictionary).has("trigger") and legendary_effect.is_empty():
			legendary_effect = (bd as Dictionary).duplicate(true)
	return {
		"unique_id": unique_id,
		"base_id": str(base.get("id", "?")),
		"name": display_name,
		"item_level": item_level,
		"rarity": rarity_id,
		"slot": str(base.get("slot", "?")),
		"base_type": str(base.get("base_type", "?")),
		"required_level": int(base.get("required_level", 1)),
		"stats": stats,
		"affixes": affix_lines,
		"buffs": stored_buffs,
		"legendary_effect": legendary_effect,
	}


static func tooltip(item: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(str(item.get("name", "?")))
	lines.append("%s · Level %d · %s" % [
		rarity_label(str(item.get("rarity", "?"))),
		int(item.get("item_level", 1)),
		stat_label(str(item.get("slot", "?"))),
	])
	lines.append("---")
	var stats: Dictionary = item.get("stats", {})
	for stat in stats.keys():
		var is_pct := false
		for a in (item.get("affixes", []) as Array):
			var ad := a as Dictionary
			if str(ad.get("stat", "")) == str(stat) and bool(ad.get("is_percent", false)):
				is_pct = true
		lines.append(format_stat(str(stat), stats[stat], is_pct))
	for b in (item.get("buffs", []) as Array):
		var bd := b as Dictionary
		var mods: Array = []
		for m in (bd.get("modifiers", []) as Array):
			mods.append(format_modifier(m))
		var mods_text := ", ".join(mods) if not mods.is_empty() else str(bd.get("description", ""))
		lines.append("Buff: %s (%s)" % [str(bd.get("name", "?")), mods_text])
	if not (item.get("legendary_effect", {}) as Dictionary).is_empty():
		var le: Dictionary = item.get("legendary_effect", {})
		lines.append("Legendary: %s — %s" % [str(le.get("name", "?")), str(le.get("description", ""))])
	lines.append(str(item.get("unique_id", "")))
	return "\n".join(lines)
