extends RefCounted
## PetGenerator: egg drops + hatching. Data-driven like LootGenerator.
##
## Two pet kinds (same output shape, same PetInstance assembly):
## - FIXED signature pets (pets.json): hand-tuned bonuses, e.g. Ember Dragon.
##   These stay special forever — the 100+ roster never replaces them.
## - WILD pets (species.json + balance/pets.json): species template × rarity
##   scaling (bonus_lines + value_mult). Adding species/rarities needs no code.
##
## Eggs mix both: possible_pets (fixed ids) + wild_rolls (species ids whose
## rarity is rolled from the species rarity_weights). Drop chances come from
## drops/enemy_drops.json per killer tier, gated by egg min_map_level.
## Depends only on RNGManager + DataManager passed in _init.

const PetInstance = preload("res://scripts/pets/PetInstance.gd")

var _rng: Node
var _data: Node


func _init(rng: Node, data: Node) -> void:
	_rng = rng
	_data = data


## Roll which pet hatches from an egg (fixed + wild options, weighted).
func hatch(egg_id: String) -> Dictionary:
	var egg: Dictionary = _data.get_egg(egg_id)
	if egg.is_empty():
		push_error("PetGenerator: unknown egg '%s'." % egg_id)
		return {}
	var weights := PackedFloat32Array()
	var kinds: Array = [] # [{kind: "fixed"/"wild", id: pet_id/species_id}]
	for opt in (egg.get("possible_pets", []) as Array):
		var od := opt as Dictionary
		weights.append(float(od.get("weight", 0)))
		kinds.append({"kind": "fixed", "id": str(od.get("pet", ""))})
	for opt in (egg.get("wild_rolls", []) as Array):
		var od := opt as Dictionary
		weights.append(float(od.get("weight", 0)))
		kinds.append({"kind": "wild", "id": str(od.get("species", ""))})
	var idx: int = _rng.weighted_choice(weights)
	if idx < 0 or idx >= kinds.size():
		push_error("PetGenerator: egg '%s' has no hatchable pets." % egg_id)
		return {}
	var pick := kinds[idx] as Dictionary
	if str(pick.get("kind", "")) == "wild":
		return hatch_wild(str(pick["id"]), egg_id)
	var pet_def: Dictionary = _data.get_pet(str(pick["id"]))
	if pet_def.is_empty():
		push_error("PetGenerator: egg '%s' references unknown pet '%s'." % [egg_id, pick["id"]])
		return {}
	return PetInstance.build(pet_def, egg_id, PetInstance.make_id(_rng))


## Hatch a wild pet: rarity rolled from species weights, bonuses generated.
func hatch_wild(species_id: String, egg_id: String) -> Dictionary:
	var rarity_id := roll_wild_rarity(species_id)
	if rarity_id == "":
		return {}
	return roll_wild(species_id, rarity_id, egg_id)


## Roll a wild rarity for a species (honors rarity_weights; zero = excluded).
func roll_wild_rarity(species_id: String) -> String:
	var species: Dictionary = _data.get_species(species_id)
	if species.is_empty():
		push_error("PetGenerator: unknown species '%s'." % species_id)
		return ""
	var rw: Dictionary = species.get("rarity_weights", {})
	var order := ["common", "rare", "epic", "legendary"]
	var weights := PackedFloat32Array()
	for r in order:
		weights.append(float(rw.get(r, 0)))
	var idx: int = _rng.weighted_choice(weights)
	if idx < 0:
		push_error("PetGenerator: species '%s' has no available rarities." % species_id)
		return ""
	return order[idx]


## Generate a wild pet of an explicit species + rarity.
## pet_id "ember_fox_epic", name "Epic Ember Fox", bonuses scaled by
## balance/pets.json (bonus_lines + value_mult), capped at pool size.
func roll_wild(species_id: String, rarity_id: String, egg_id: String = "") -> Dictionary:
	var species: Dictionary = _data.get_species(species_id)
	if species.is_empty():
		push_error("PetGenerator: unknown species '%s'." % species_id)
		return {}
	var scaling: Dictionary = _wild_scaling()
	if not scaling.has(rarity_id):
		push_error("PetGenerator: no wild scaling for rarity '%s'." % rarity_id)
		return {}
	var rule := scaling[rarity_id] as Dictionary
	var pool: Array = (species.get("wild_pool", []) as Array).duplicate()
	pool.shuffle()
	var lines: int = mini(int(rule.get("bonus_lines", 1)), pool.size())
	var mult := float(rule.get("value_mult", 1.0))
	var bonuses: Array = []
	for i in lines:
		var entry := pool[i] as Dictionary
		var raw := float(_rng.random_int(int(entry.get("min", 1)), int(entry.get("max", 1))))
		var is_pct := bool(entry.get("is_percent", false))
		var lo := float(entry.get("min", 0)) * mult
		var hi := float(entry.get("max", 0)) * mult
		var v: Variant
		if is_pct:
			v = clampf(snappedf(raw * mult, 0.1), snappedf(lo, 0.1), snappedf(hi, 0.1))
		else:
			v = clampi(int(round(raw * mult)), int(floor(lo)), int(ceil(hi)))
		bonuses.append({"stat": str(entry.get("stat", "?")), "value": v, "is_percent": is_pct})
	var pet_def := {
		"id": "%s_%s" % [species_id, rarity_id],
		"name": "%s %s" % [PetInstance.rarity_label(rarity_id), str(species.get("name", species_id))],
		"rarity": rarity_id,
		"bonuses": bonuses,
	}
	var pet := PetInstance.build(pet_def, egg_id, PetInstance.make_id(_rng))
	pet["wild"] = true
	pet["species"] = species_id
	return pet


## Roll an egg drop for a kill. Returns the egg id or "" (no drop).
## `enemy_tier`: normal/elite/boss. `map_level` gates egg availability.
func roll_egg_drop(enemy_tier: String, map_level: int) -> String:
	var drops: Dictionary = _data.get_table("drops")
	var tiers: Dictionary = drops.get("tiers", {})
	if not tiers.has(enemy_tier):
		push_error("PetGenerator: unknown enemy tier '%s'." % enemy_tier)
		return ""
	var tier_def := tiers[enemy_tier] as Dictionary
	var chance := float(tier_def.get("egg_chance", 0.0))
	if _rng.random_float(0.0, 100.0) >= chance:
		return ""
	var pool: Dictionary = tier_def.get("egg_pool", {})
	var eggs: Dictionary = _data.get_table("eggs")
	var weights := PackedFloat32Array()
	var ids: Array = []
	for egg_id in pool.keys():
		var edef: Dictionary = eggs.get(str(egg_id), {})
		if edef.is_empty():
			continue
		if int(edef.get("min_map_level", 1)) > map_level:
			continue
		weights.append(float(pool[egg_id]))
		ids.append(str(egg_id))
	if ids.is_empty():
		return ""
	var idx: int = _rng.weighted_choice(weights)
	if idx < 0:
		return ""
	return str(ids[idx])


## Hatch-chance summary for an egg, fixed + wild combos:
## [{label, rarity, chance_pct, wild: bool}].
func hatch_odds(egg_id: String) -> Array:
	var egg: Dictionary = _data.get_egg(egg_id)
	var out: Array = []
	var total := 0.0
	for opt in (egg.get("possible_pets", []) as Array):
		total += float((opt as Dictionary).get("weight", 0))
	for opt in (egg.get("wild_rolls", []) as Array):
		total += float((opt as Dictionary).get("weight", 0))
	for opt in (egg.get("possible_pets", []) as Array):
		var od := opt as Dictionary
		var pet_def: Dictionary = _data.get_pet(str(od.get("pet", "")))
		out.append({
			"label": str(pet_def.get("name", "?")), "rarity": str(pet_def.get("rarity", "?")),
			"chance_pct": 100.0 * float(od.get("weight", 0)) / maxf(total, 1.0),
			"wild": false, "ref": str(od.get("pet", "")),
		})
	for opt in (egg.get("wild_rolls", []) as Array):
		var od := opt as Dictionary
		var species: Dictionary = _data.get_species(str(od.get("species", "")))
		var rw: Dictionary = species.get("rarity_weights", {})
		var rw_total := 0.0
		for r in rw.keys():
			rw_total += float(rw[r])
		for r in rw.keys():
			var w := float(rw[r])
			if w <= 0.0:
				continue
			out.append({
				"label": "%s %s (scaled)" % [PetInstance.rarity_label(str(r)), str(species.get("name", "?"))],
				"rarity": str(r),
				"chance_pct": 100.0 * float(od.get("weight", 0)) * w / (maxf(total, 1.0) * maxf(rw_total, 1.0)),
				"wild": true, "ref": str(od.get("species", "")),
			})
	return out


func _wild_scaling() -> Dictionary:
	var balance: Dictionary = _data.get_table("pet_balance")
	return balance.get("rarity_scaling", {})
