extends RefCounted
## PetInstance: assembles a unique pet dict from a pet definition.
## Mirrors ItemInstance: bases are never mutated, rarity presentation and
## bonus formatting live here so simulator, Pet UI, and StatCalculator
## (Stage 2 consumer) all agree. See todoagent.md #23-24, #28.

const ItemInstance = preload("res://scripts/loot/ItemInstance.gd")

const RARITY_LABELS := {
	"common": "Common",
	"rare": "Rare",
	"epic": "Epic",
	"legendary": "Legendary",
}

const RARITY_COLORS := {
	"common": Color(0.62, 0.64, 0.69),
	"rare": Color(0.38, 0.65, 0.98),
	"epic": Color(0.75, 0.52, 0.99),
	"legendary": Color(0.98, 0.57, 0.24),
}


static func make_id(rng: Node) -> String:
	var n: int = rng.random_int(0, 0x7FFFFFFF)
	return "pet_%08x" % n


static func rarity_label(rarity_id: String) -> String:
	return str(RARITY_LABELS.get(rarity_id, rarity_id))


static func rarity_color(rarity_id: String) -> Color:
	return RARITY_COLORS.get(rarity_id, Color.WHITE)


static func format_bonus(bonus: Dictionary) -> String:
	var label: String = ItemInstance.stat_label(str(bonus.get("stat", "?")))
	var v: Variant = bonus.get("value", 0)
	if v is float and v == floor(v):
		v = int(v)
	if bool(bonus.get("is_percent", false)):
		return "+%s%% %s" % [str(v), label]
	return "+%s %s" % [str(v), label]


## Flat level-1 bonuses straight from the definition. Pet leveling curves
## (Stage 8) multiply these — keep the hook here, not scattered in UI.
static func build(pet_def: Dictionary, egg_id: String, unique_id: String) -> Dictionary:
	var bonuses: Array = []
	for b in (pet_def.get("bonuses", []) as Array):
		bonuses.append((b as Dictionary).duplicate())
	return {
		"unique_id": unique_id,
		"pet_id": str(pet_def.get("id", "?")),
		"name": str(pet_def.get("name", "?")),
		"rarity": str(pet_def.get("rarity", "common")),
		"level": 1,
		"bonuses": bonuses,
		"egg_source": egg_id,
	}


static func tooltip(pet: Dictionary) -> String:
	var lines: Array[String] = []
	lines.append(str(pet.get("name", "?")))
	lines.append("%s Pet · Level %d" % [rarity_label(str(pet.get("rarity", "?"))), int(pet.get("level", 1))])
	lines.append("---")
	for b in (pet.get("bonuses", []) as Array):
		lines.append(format_bonus(b))
	lines.append("Hatched from: %s" % str(pet.get("egg_source", "?")))
	lines.append(str(pet.get("unique_id", "")))
	return "\n".join(lines)
