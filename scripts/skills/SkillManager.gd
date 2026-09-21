extends RefCounted
## SkillManager: weapon-family skill unlocks + rank upgrades (spec #10-12,
## skills feed weapon identity; combat consumes skill_power later).
##
## Economy (data/balance/skills.json): 1 skill point every 3 player levels
## (levels 1, 4, 7, …). Unlocking costs 1 point (rank 1); each upgrade +1 rank
## costs 1 point, up to per-skill max_rank. Max 10 skills per weapon family.
## `_ranks` is plain data — SaveManager persists it in a later stage.
## Depends only on DataManager passed in _init (headless-testable).

var _data: Node
var _ranks := {}


func _init(data: Node) -> void:
	_data = data


func _economy() -> Dictionary:
	var balance: Dictionary = _data.get_table("skill_balance")
	return balance.get("economy", {"unlock_every_levels": 3, "points_per_unlock": 1})


func _caps() -> Dictionary:
	var balance: Dictionary = _data.get_table("skill_balance")
	return balance.get("caps", {"max_skills_per_weapon": 10, "max_skill_rank": 5})


## Lifetime points earned by a player level (level 1 starts with 1).
func lifetime_points(level: int) -> int:
	var every := int(_economy().get("unlock_every_levels", 3))
	var per := int(_economy().get("points_per_unlock", 1))
	return (maxi(level - 1, 0) / maxi(every, 1) + 1) * per


func spent_points() -> int:
	var total := 0
	for key in _ranks.keys():
		total += int(_ranks[key])
	return total


func spendable_points(level: int) -> int:
	return maxi(lifetime_points(level) - spent_points(), 0)


## Skill defs of one weapon family, unlock order, capped at 10.
func family_skills(family: String) -> Array:
	var cap := int(_caps().get("max_skills_per_weapon", 10))
	var table: Dictionary = _data.get_table("skills")
	var out: Array = []
	for key in table.keys():
		var def := table[key] as Dictionary
		if str(def.get("family", "")) == family:
			out.append(def)
	out.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a.get("unlock_level", 99)) < int(b.get("unlock_level", 99)))
	return out.slice(0, cap)


## Family skills whose unlock_level the player level has reached.
func unlocked_skills(family: String, level: int) -> Array:
	var out: Array = []
	for def in family_skills(family):
		if int((def as Dictionary).get("unlock_level", 99)) <= level:
			out.append(def)
	return out


func get_rank(skill_id: String) -> int:
	return int(_ranks.get(skill_id, 0))


func _max_rank(def: Dictionary) -> int:
	return mini(int(def.get("max_rank", 1)), int(_caps().get("max_skill_rank", 5)))


func can_unlock(skill_id: String, family: String, level: int) -> bool:
	var def: Dictionary = _data.get_skill(skill_id)
	if def.is_empty() or str(def.get("family", "")) != family:
		return false
	if int(def.get("unlock_level", 99)) > level:
		return false
	if get_rank(skill_id) > 0:
		return false
	return spendable_points(level) >= 1


func unlock(skill_id: String, family: String, level: int) -> bool:
	if not can_unlock(skill_id, family, level):
		return false
	_ranks[skill_id] = 1
	return true


func can_upgrade(skill_id: String, level: int) -> bool:
	var def: Dictionary = _data.get_skill(skill_id)
	if def.is_empty():
		return false
	var rank := get_rank(skill_id)
	if rank < 1 or rank >= _max_rank(def):
		return false
	return spendable_points(level) >= 1


func upgrade(skill_id: String, level: int) -> bool:
	if not can_upgrade(skill_id, level):
		return false
	_ranks[skill_id] = get_rank(skill_id) + 1
	return true


func reset() -> void:
	_ranks.clear()


## Combat-ready numbers for one skill at its current rank.
## flat = base_flat + per_flat*(rank-1); pct likewise; cooldown/mana fixed.
func skill_power(skill_id: String) -> Dictionary:
	var def: Dictionary = _data.get_skill(skill_id)
	if def.is_empty():
		return {}
	var rank := get_rank(skill_id)
	var steps := maxi(rank - 1, 0)
	var base: Dictionary = def.get("base", {})
	var per: Dictionary = def.get("per_rank", {})
	return {
		"skill_id": skill_id,
		"rank": rank,
		"max_rank": _max_rank(def),
		"damage_flat": float(base.get("damage_flat", 0)) + float(per.get("damage_flat", 0)) * steps,
		"damage_pct": float(base.get("damage_pct", 0)) + float(per.get("damage_pct", 0)) * steps,
		"cooldown_sec": float(base.get("cooldown_sec", 0)),
		"mana_cost": float(base.get("mana_cost", 0)),
	}


## Full UI/simulator view: def + rank + power + affordability per skill.
func family_view(family: String, level: int) -> Array:
	var out: Array = []
	for def in family_skills(family):
		var dd := def as Dictionary
		var sid := str(dd.get("id", ""))
		var power := skill_power(sid)
		power["name"] = str(dd.get("name", sid))
		power["unlock_level"] = int(dd.get("unlock_level", 99))
		power["unlocked"] = int(dd.get("unlock_level", 99)) <= level
		power["can_unlock"] = can_unlock(sid, family, level)
		power["can_upgrade"] = can_upgrade(sid, level)
		out.append(power)
	return out
