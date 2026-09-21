extends CharacterBody2D
## Player: movement + world presence + owned loadout (Stage 2 + equipment
## integration). Owns an InventoryManager and an EquipmentManager and mediates
## the pickup → equip → stats flow; rules stay inside those managers and
## math stays inside StatCalculator. Combat/talents arrive separately —
## this script delegates, never absorbs systems.

const InventoryManager = preload("res://scripts/inventory/InventoryManager.gd")
const EquipmentManager = preload("res://scripts/equipment/EquipmentManager.gd")
const DamageCalculator = preload("res://scripts/combat/DamageCalculator.gd")
const TalentManager = preload("res://scripts/talents/TalentManager.gd")
const SkillManager = preload("res://scripts/skills/SkillManager.gd")
const PetCollectionManager = preload("res://scripts/pets/PetCollectionManager.gd")

var stats: Node
var inventory: RefCounted
var equipment: RefCounted
var talents: RefCounted
var skills: RefCounted
var collection: RefCounted
var _move_base := 200.0
var _facing := Vector2.RIGHT
var _attack_cd := 0.0


func _ready() -> void:
	stats = $CharacterStats
	var dm := get_node_or_null("/root/DataManager")
	if dm != null:
		var table: Dictionary = dm.get_table("player_balance")
		var rule: Dictionary = table.get("move_speed", {})
		_move_base = float(rule.get("base_px_per_sec", _move_base))
		inventory = InventoryManager.new(dm)
		equipment = EquipmentManager.new(dm)
		talents = TalentManager.new(dm)
		skills = SkillManager.new(dm)
		collection = PetCollectionManager.new()
	else:
		push_warning("Player: DataManager missing, loadout managers unavailable.")
	refresh_stats()


func _physics_process(_delta: float) -> void:
	# InputMap actions only — no hard-coded keys (spec #65).
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_facing = dir.normalized()
	_attack_cd = maxf(_attack_cd - _delta, 0.0)
	velocity = dir * current_speed()
	move_and_slide()
	if Input.is_action_just_pressed("attack"):
		try_attack()


func set_facing(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		_facing = dir.normalized()


## Basic melee swing: hits enemies (layer 2) within range in facing arc.
## Returns per-enemy DamageResults ({} when on cooldown). Skill/weapon
## execution integration arrives later; this is the basic attack only.
func try_attack() -> Array:
	var dm := get_node_or_null("/root/DataManager")
	if dm == null or stats == null:
		return []
	var bal: Dictionary = dm.get_table("combat_balance")
	var basic: Dictionary = bal.get("player_basic", {})
	if _attack_cd > 0.0:
		return []
	_attack_cd = float(basic.get("cooldown_sec", 0.5))
	var shape := CircleShape2D.new()
	shape.radius = float(basic.get("range_px", 48.0))
	var params := PhysicsShapeQueryParameters2D.new()
	params.shape = shape
	params.collision_mask = 2
	params.exclude = [get_rid()]
	params.transform = Transform2D(0.0, global_position + _facing * shape.radius * 0.5)
	var hits: Array = get_world_2d().direct_space_state.intersect_shape(params)
	var rng := get_node_or_null("/root/RNGManager")
	var base: float = float(basic.get("base_damage", 10.0)) + stats.get_stat("str") * float(basic.get("str_mult", 2.0))
	var out: Array = []
	for hit in hits:
		var collider: Variant = (hit as Dictionary).get("collider")
		if collider is Node and (collider as Node).is_in_group("enemies") and (collider as Node).has_method("take_hit"):
			var req := {
				"base_damage": base, "damage_type": "physical",
				"crit_chance_pct": stats.get_stat("critical_chance"),
				"crit_damage_pct": stats.get_stat("critical_damage"),
				"crit_roll": rng.random_float(0.0, 1.0) if rng != null else 1.0,
				"variance_roll": rng.random_float(0.0, 1.0) if rng != null else 0.5,
				"source": "player",
			}
			out.append((collider as Node).call("take_hit", req))
	return out


func current_speed() -> float:
	var bonus := 0.0
	if stats != null:
		bonus = stats.get_stat("move_speed")
	return _move_base * (1.0 + bonus / 100.0)


## Push equipped + talent modifiers into stats. Active talent tree follows
## the equipped main-hand (bow equipped → bow tree); empty-handed → none.
func refresh_stats() -> void:
	if stats == null or equipment == null:
		return
	stats.set_contributors("equipment", equipment.to_modifiers())
	if talents != null:
		talents.set_active_family(_active_weapon_family())
		stats.set_contributors("talents", talents.to_modifiers())
	if collection != null:
		stats.set_contributors("pet", collection.active_modifiers())


## Weapon id driving talents/skills (base_type of main-hand, "" if none).
func _active_weapon_family() -> String:
	var main: Dictionary = equipment.get_equipped("main_hand")
	if main.is_empty():
		return ""
	return str(main.get("base_type", ""))


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
