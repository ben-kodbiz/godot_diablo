extends RefCounted
## EquipmentManager: owns equipped item instances (fixme.md §33).
## 7 slots (spec §8): main_hand, off_hand, armor, helmet,
## accessory_1, accessory_2, pet. Items declare `slot` + optional `occupies`
## (two-handed rule lives in DATA, never in code — §34). Generic
## `requirements[]` gate equipping (§35). Emits modifiers stamped
## source_type "equipment" for StatCalculator; Pet slot reserves Stage 8.
## State serializes via serialize()/deserialize() (save contract §30).
## Depends on DataManager + a level/stats reader (CharacterStats) only.

const SLOTS := [
	"main_hand", "off_hand", "armor", "helmet",
	"accessory_1", "accessory_2", "pet",
]

var _data: Node
var _equipped := {} # slot -> item dict


func _init(data: Node) -> void:
	_data = data
	for slot in SLOTS:
		_equipped[slot] = {}


func get_equipped(slot: String) -> Dictionary:
	return (_equipped.get(slot, {}) as Dictionary).duplicate(true)


func all_equipped() -> Dictionary:
	return (_equipped as Dictionary).duplicate(true)


## Resolve which concrete slot an item goes to ("accessory" → first free).
## Returns "" when no slot fits.
func resolve_slot(item: Dictionary) -> String:
	var slot := str(item.get("slot", ""))
	if slot in SLOTS and slot != "pet":
		return slot
	if slot == "accessory":
		for acc in ["accessory_1", "accessory_2"]:
			if (_equipped.get(acc, {}) as Dictionary).is_empty():
				return acc
		return ""
	return ""


## Full slot footprint: primary + occupies (default: primary alone).
func footprint(item: Dictionary, primary: String) -> Array:
	var out: Array = [primary]
	for extra in (item.get("occupies", []) as Array):
		var s := str(extra)
		if s in SLOTS and s not in out:
			out.append(s)
	return out


## Requirement check vs a CharacterStats-like (needs level + get_stat()).
## Returns "" when equippable, else a human reason.
func requirement_error(item: Dictionary, stats: Node) -> String:
	var base: Dictionary = _data.get_equipment(str(item.get("base_id", "")))
	if base.is_empty():
		return "Unknown base item '%s'." % item.get("base_id", "")
	var need_level := int(base.get("required_level", 1))
	var char_level := 1
	if stats != null and "level" in stats:
		char_level = int(stats.level)
	if char_level < need_level:
		return "Requires level %d." % need_level
	for req in (base.get("requirements", []) as Array):
		var rd := req as Dictionary
		var err := _check_requirement(rd, stats)
		if err != "":
			return err
	return ""


func _check_requirement(req: Dictionary, stats: Node) -> String:
	match str(req.get("type", "")):
		"level":
			var char_level := 1
			if stats != null and "level" in stats:
				char_level = int(stats.level)
			if char_level < int(req.get("value", 1)):
				return "Requires level %d." % int(req.get("value", 1))
		"stat":
			var have := 0.0
			if stats != null and stats.has_method("get_stat"):
				have = float(stats.get_stat(str(req.get("stat", "?"))))
			if have < float(req.get("value", 0)):
				return "Requires %s %s." % [req.get("value", 0), req.get("stat", "?")]
		_:
			return "Unknown requirement type '%s'." % req.get("type", "")
	return ""


## Read-only preview of occupants that equipping would displace.
## Returns [] when the item has no fitting slot.
func preview_displaced(item: Dictionary) -> Array:
	var primary := resolve_slot(item)
	if primary == "":
		return []
	var new_fp := footprint(item, primary)
	var out: Array = []
	for slot in SLOTS:
		var occupant := _equipped.get(slot, {}) as Dictionary
		if occupant.is_empty():
			continue
		for s in new_fp:
			if str(s) in footprint(occupant, slot):
				out.append(occupant.duplicate(true))
				break
	return out


## Equip an item. Returns {ok, reason, displaced[]} — displaced occupants
## go back to inventory (caller-owned, never destroyed here).
func equip(item: Dictionary, stats: Node) -> Dictionary:
	if str(item.get("slot", "")) == "pet":
		return {"ok": false, "reason": "Pet slot holds pets, not items.", "displaced": []}
	var primary := resolve_slot(item)
	if primary == "":
		return {"ok": false, "reason": "No free slot for '%s'." % item.get("slot", "?"), "displaced": []}
	var req_err := requirement_error(item, stats)
	if req_err != "":
		return {"ok": false, "reason": req_err, "displaced": []}
	# Displace every occupant whose footprint intersects the new one — so a
	# two-hander clears off-hand AND equipping a shield clears a two-hander.
	var new_fp := footprint(item, primary)
	var displaced: Array = []
	for slot in SLOTS:
		var occupant := _equipped.get(slot, {}) as Dictionary
		if occupant.is_empty():
			continue
		var clash := false
		for s in new_fp:
			if str(s) in footprint(occupant, slot):
				clash = true
				break
		if clash:
			displaced.append(occupant.duplicate(true))
			_equipped[slot] = {}
	_equipped[primary] = (item as Dictionary).duplicate(true)
	return {"ok": true, "reason": "", "displaced": displaced}


func unequip(slot: String) -> Dictionary:
	if not _equipped.has(slot):
		return {}
	var item := _equipped[slot] as Dictionary
	_equipped[slot] = {}
	return item


## StatCalculator-ready modifiers for ALL equipped items: base stats (flat)
## + affix lines (flat/pct) + buff modifiers, re-stamped source_type
## "equipment" (original stamp kept in "via") so the breakdown shows one
## Equipment line with full provenance.
func to_modifiers() -> Array:
	var out: Array = []
	for slot in SLOTS:
		var item := _equipped.get(slot, {}) as Dictionary
		if item.is_empty():
			continue
		var uid := str(item.get("unique_id", "?"))
		for stat in (item.get("base_stats", {}) as Dictionary).keys():
			out.append({
				"stat": str(stat), "value": (item["base_stats"] as Dictionary)[stat],
				"is_percent": false, "source_type": "equipment", "source_id": uid,
			})
		for a in (item.get("affixes", []) as Array):
			var ad := a as Dictionary
			out.append({
				"stat": str(ad.get("stat", "?")), "value": ad.get("value", 0),
				"is_percent": bool(ad.get("is_percent", false)),
				"source_type": "equipment", "source_id": uid,
				"via": "%s:%s" % [ad.get("source_type", "?"), ad.get("id", "?")],
			})
		for b in (item.get("buffs", []) as Array):
			var bd := b as Dictionary
			for m in (bd.get("modifiers", []) as Array):
				var md := m as Dictionary
				out.append({
					"stat": str(md.get("stat", "?")), "value": md.get("value", 0),
					"is_percent": bool(md.get("is_percent", false)),
					"source_type": "equipment", "source_id": uid,
					"via": "buff:%s" % bd.get("id", "?"),
				})
	return out


func serialize() -> Dictionary:
	var slots := {}
	for slot in SLOTS:
		var item := _equipped.get(slot, {}) as Dictionary
		if not item.is_empty():
			slots[slot] = item.duplicate(true)
	return {"slots": slots}


func deserialize(data: Dictionary) -> bool:
	var slots: Variant = data.get("slots", null)
	if typeof(slots) != TYPE_DICTIONARY:
		push_error("EquipmentManager: save data missing 'slots' object.")
		return false
	for slot in (slots as Dictionary).keys():
		if str(slot) not in SLOTS:
			push_error("EquipmentManager: unknown slot '%s' in save data." % slot)
			return false
		var item := (slots as Dictionary)[slot] as Dictionary
		if not item.has("unique_id") or not item.has("base_id"):
			push_error("EquipmentManager: slot '%s' holds a non-item." % slot)
			return false
	for slot in SLOTS:
		_equipped[slot] = {}
	for slot in (slots as Dictionary).keys():
		_equipped[str(slot)] = ((slots as Dictionary)[slot] as Dictionary).duplicate(true)
	return true
