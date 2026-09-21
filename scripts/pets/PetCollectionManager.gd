extends RefCounted
## PetCollectionManager: OWNS pets (fixme.md §25). PetGenerator generates;
## this owns: add/remove, ownership, species/rarity counts, active pet,
## discovery. Active pet bonuses feed StatCalculator via active_modifiers().
## Save-ready via serialize()/deserialize().

var _pets := {} # unique_id -> pet dict
var _active_uid := ""
var _discovered := {} # species key -> true


func add_pet(pet: Dictionary) -> bool:
	var uid := str(pet.get("unique_id", ""))
	if uid == "" or _pets.has(uid):
		return false
	_pets[uid] = (pet as Dictionary).duplicate(true)
	_discovered[_species_key(pet)] = true
	return true


func remove_pet(uid: String) -> Dictionary:
	if not _pets.has(uid):
		return {}
	var pet := _pets[uid] as Dictionary
	_pets.erase(uid)
	if _active_uid == uid:
		_active_uid = ""
	return pet


func owns(uid: String) -> bool:
	return _pets.has(uid)


func get_pet(uid: String) -> Dictionary:
	return (_pets.get(uid, {}) as Dictionary).duplicate(true)


func set_active(uid: String) -> bool:
	if uid != "" and not _pets.has(uid):
		return false
	_active_uid = uid
	return true


func clear_active() -> void:
	_active_uid = ""


func get_active() -> Dictionary:
	return get_pet(_active_uid)


## StatCalculator-ready bonuses of the active pet (stamped at build).
func active_modifiers() -> Array:
	var pet := get_pet(_active_uid)
	if pet.is_empty():
		return []
	return ((pet.get("bonuses", []) as Array).duplicate(true) as Array)


func count_species() -> int:
	return _discovered.size()


func count_rarity(rarity: String) -> int:
	var n := 0
	for uid in _pets.keys():
		if str((_pets[uid] as Dictionary).get("rarity", "")) == rarity:
			n += 1
	return n


func count_total() -> int:
	return _pets.size()


func discovered() -> Array:
	var out: Array = _discovered.keys()
	out.sort()
	return out


func serialize() -> Dictionary:
	var pets: Array = []
	for uid in _pets.keys():
		pets.append((_pets[uid] as Dictionary).duplicate(true))
	return {"pets": pets, "active_uid": _active_uid, "discovered": discovered()}


func deserialize(data: Dictionary) -> bool:
	if typeof(data.get("pets", null)) != TYPE_ARRAY:
		push_error("PetCollectionManager: save data missing pets array.")
		return false
	var seen := {}
	for pet in (data.get("pets", []) as Array):
		var uid := str((pet as Dictionary).get("unique_id", ""))
		if uid == "" or seen.has(uid):
			push_error("PetCollectionManager: pet missing/duplicate unique_id.")
			return false
		if not (pet as Dictionary).has("bonuses"):
			push_error("PetCollectionManager: pet '%s' has no bonuses." % uid)
			return false
		seen[uid] = true
	var active := str(data.get("active_uid", ""))
	if active != "" and not seen.has(active):
		push_error("PetCollectionManager: active pet '%s' not in collection." % active)
		return false
	_pets.clear()
	for pet in (data.get("pets", []) as Array):
		var pd := pet as Dictionary
		_pets[str(pd["unique_id"])] = pd.duplicate(true)
		_discovered[_species_key(pd)] = true
	for species in (data.get("discovered", []) as Array):
		_discovered[str(species)] = true
	_active_uid = active
	return true


func _species_key(pet: Dictionary) -> String:
	if bool(pet.get("wild", false)):
		return str(pet.get("species", pet.get("pet_id", "?")))
	return str(pet.get("pet_id", "?"))
