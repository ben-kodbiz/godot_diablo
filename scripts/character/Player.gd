extends CharacterBody2D
## Player: movement + world presence + owned loadout (Stage 2 + equipment
## integration). Owns an InventoryManager and an EquipmentManager and mediates
## the pickup → equip → stats flow; rules stay inside those managers and
## math stays inside StatCalculator. Combat/talents arrive separately —
## this script delegates, never absorbs systems.

const InventoryManager = preload("res://scripts/inventory/InventoryManager.gd")
const EquipmentManager = preload("res://scripts/equipment/EquipmentManager.gd")

var stats: Node
var inventory: RefCounted
var equipment: RefCounted
var _move_base := 200.0


func _ready() -> void:
	stats = $CharacterStats
	var dm := get_node_or_null("/root/DataManager")
	if dm != null:
		var table: Dictionary = dm.get_table("player_balance")
		var rule: Dictionary = table.get("move_speed", {})
		_move_base = float(rule.get("base_px_per_sec", _move_base))
		inventory = InventoryManager.new(dm)
		equipment = EquipmentManager.new(dm)
	else:
		push_warning("Player: DataManager missing, loadout managers unavailable.")
	refresh_stats()


func _physics_process(_delta: float) -> void:
	# InputMap actions only — no hard-coded keys (spec #65).
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	velocity = dir * current_speed()
	move_and_slide()


func current_speed() -> float:
	var bonus := 0.0
	if stats != null:
		bonus = stats.get_stat("move_speed")
	return _move_base * (1.0 + bonus / 100.0)


## Push equipped modifiers into stats. Called after every loadout change.
func refresh_stats() -> void:
	if stats == null or equipment == null:
		return
	stats.set_contributors("equipment", equipment.to_modifiers())


## Loot pickup → inventory. Returns InventoryManager.add() result.
func pickup_item(item: Dictionary) -> Dictionary:
	if inventory == null:
		return {"ok": false, "slot": -1, "reason": "No inventory."}
	return inventory.add(item)


## Equip an item held in inventory. Displaced occupants return to inventory;
## if inventory is full they stay equipped and the swap is refused.
func equip_item(unique_id: String) -> Dictionary:
	if inventory == null or equipment == null:
		return {"ok": false, "reason": "No loadout.", "displaced": []}
	var slot_index: int = inventory.find_slot(unique_id)
	if slot_index < 0:
		return {"ok": false, "reason": "Item not in inventory.", "displaced": []}
	var held: Dictionary = inventory.remove(unique_id)
	# Capacity pre-check: displaced occupants must fit back in inventory.
	var incoming: Array = equipment.preview_displaced(held)
	if incoming.size() > inventory.count_free():
		inventory.add(held)
		return {"ok": false, "reason": "Inventory full for displaced items.", "displaced": []}
	var res: Dictionary = equipment.equip(held, stats)
	if not bool(res.get("ok", false)):
		inventory.add(held)
		return res
	for displaced in (res.get("displaced", []) as Array):
		inventory.add(displaced) # room guaranteed by pre-check above.
	refresh_stats()
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.item_equipped.emit(str(held.get("unique_id", "")), str(held.get("slot", "")))
	return {"ok": true, "reason": "", "displaced": res.get("displaced", [])}


## Unequip a slot back into inventory.
func unequip_slot(slot: String) -> Dictionary:
	if inventory == null or equipment == null:
		return {"ok": false, "reason": "No loadout."}
	var item: Dictionary = equipment.get_equipped(slot)
	if item.is_empty():
		return {"ok": false, "reason": "Slot empty."}
	var back: Dictionary = inventory.add(item)
	if not bool(back.get("ok", false)):
		return {"ok": false, "reason": "Inventory full."}
	equipment.unequip(slot)
	refresh_stats()
	return {"ok": true, "reason": ""}
