extends RefCounted
## TalentManager: weapon-tree passive progression (fixme.md §36, TASK 15).
## Talent = progression node (passive stat effects feeding StatCalculator).
## Skill (SkillManager) = executable ability. Separate systems, separate
## economies: talents grant lifetime_points(level) = level (universal talent
## points, spec §12); spending is gated by the ACTIVE weapon family
## (bow equipped → bow tree), set from the equipped main-hand by Player.
## Costs cost_per_rank per rank (default 1) up to max_rank. `_ranks` is
## plain save data. Depends only on DataManager passed in _init.

var _data: Node
var _ranks := {}
var _active_family := ""


func _init(data: Node) -> void:
	_data = data


func set_active_family(family: String) -> void:
	_active_family = family


func get_active_family() -> String:
	return _active_family


func lifetime_points(level: int) -> int:
	return maxi(level, 1)


func spent_points() -> int:
	var total := 0
	for key in _ranks.keys():
		total += int(_ranks[key]) * _cost(str(key))
	return total


func spendable_points(level: int) -> int:
	return maxi(lifetime_points(level) - spent_points(), 0)


func _cost(talent_id: String) -> int:
	var def: Dictionary = _data.get_talent(talent_id)
	return maxi(int(def.get("cost_per_rank", 1)), 1)


func _cap() -> int:
	var balance: Dictionary = _data.get_table("skill_balance")
	return int((balance.get("caps", {}) as Dictionary).get("max_talents_per_tree", 10))


func family_talents(family: String) -> Array:
	var table: Dictionary = _data.get_table("talents")
	var out: Array = []
	for key in table.keys():
		var def := table[key] as Dictionary
		if str(def.get("family", "")) == family:
			out.append(def)
	return out.slice(0, _cap())


func get_rank(talent_id: String) -> int:
	return int(_ranks.get(talent_id, 0))


func get_def(talent_id: String) -> Dictionary:
	return _data.get_talent(talent_id)


func _max_rank(def: Dictionary) -> int:
	return maxi(int(def.get("max_rank", 1)), 1)


func can_unlock(talent_id: String, level: int) -> bool:
	var def: Dictionary = _data.get_talent(talent_id)
	if def.is_empty():
		return false
	if _active_family == "" or str(def.get("family", "")) != _active_family:
		return false
	if get_rank(talent_id) > 0:
		return false
	return spendable_points(level) >= _cost(talent_id)


func unlock(talent_id: String, level: int) -> bool:
	if not can_unlock(talent_id, level):
		return false
	_ranks[talent_id] = 1
	return true


func can_upgrade(talent_id: String, level: int) -> bool:
	var def: Dictionary = _data.get_talent(talent_id)
	if def.is_empty():
		return false
	var rank := get_rank(talent_id)
	if rank < 1 or rank >= _max_rank(def):
		return false
	return spendable_points(level) >= _cost(talent_id)


func upgrade(talent_id: String, level: int) -> bool:
	if not can_upgrade(talent_id, level):
		return false
	_ranks[talent_id] = get_rank(talent_id) + 1
	return true


func reset() -> void:
	_ranks.clear()


## StatCalculator-ready modifiers: effect value × rank, stamped
## source_type "talent" for the breakdown view.
func to_modifiers() -> Array:
	var out: Array = []
	for talent_id in _ranks.keys():
		var rank := int(_ranks[talent_id])
		if rank < 1:
			continue
		var def: Dictionary = _data.get_talent(str(talent_id))
		if def.is_empty():
			continue
		for fx in (def.get("effects", []) as Array):
			var fd := fx as Dictionary
			out.append({
				"stat": str(fd.get("stat", "?")),
				"value": float(fd.get("value_per_rank", 0)) * rank,
				"is_percent": bool(fd.get("is_percent", false)),
				"source_type": "talent",
				"source_id": str(talent_id),
			})
	return out


## Full UI view for one tree: def + rank + affordability.
func family_view(family: String, level: int) -> Array:
	var out: Array = []
	for def in family_talents(family):
		var dd := def as Dictionary
		var tid := str(dd.get("id", ""))
		out.append({
			"id": tid,
			"name": str(dd.get("name", tid)),
			"rank": get_rank(tid),
			"max_rank": _max_rank(dd),
			"cost": _cost(tid),
			"active": family == _active_family,
			"can_unlock": can_unlock(tid, level),
			"can_upgrade": can_upgrade(tid, level),
		})
	return out
