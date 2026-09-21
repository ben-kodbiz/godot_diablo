extends CharacterBody2D
## Enemy: generic definition-driven foe (spec §31). setup() loads its JSON
## definition + level scaling (data/balance/combat.json); the scene never
## hard-codes a species. take_hit() runs DamageCalculator with own armor;
## die() emits died + EventBus.enemy_killed. Basic chase/contact AI only —
## BehaviorController strategies arrive with the enemy stage.
## Instance state (level, HP, position) is runtime; the definition is read-only.

signal died(enemy: Node)

const DamageCalculator = preload("res://scripts/combat/DamageCalculator.gd")

var enemy_id := ""
var tier := "normal"
var level := 1
var max_hp := 1
var current_hp := 1
var damage := 0.0
var armor := 0.0
var xp_reward := 0

var _contact_cd := 0.0
var _ai := {"move_speed": 60.0, "aggro_range": 300.0, "hit_range": 30.0, "contact_cooldown": 1.0}


func setup(def_id: String, at_level: int) -> bool:
	var dm := get_node_or_null("/root/DataManager")
	if dm == null:
		push_error("Enemy: DataManager missing.")
		return false
	var def: Dictionary = dm.get_enemy(def_id)
	if def.is_empty():
		return false
	var bal: Dictionary = dm.get_table("combat_balance")
	var scaling: Dictionary = bal.get("enemy_scaling", {})
	var steps := maxi(at_level - int(def.get("base_level", 1)), 0)
	enemy_id = def_id
	tier = str(def.get("tier", "normal"))
	level = maxi(at_level, 1)
	max_hp = int(round(float(def.get("health", 10)) * (1.0 + float(scaling.get("hp_per_level", 0.15)) * steps)))
	current_hp = max_hp
	damage = float(def.get("damage", 1)) * (1.0 + float(scaling.get("dmg_per_level", 0.08)) * steps)
	armor = float(def.get("armor", 0))
	xp_reward = int(round(float(def.get("xp", 0)) * (1.0 + float(scaling.get("xp_per_level", 0.1)) * steps)))
	_ai = (bal.get("enemy_ai", _ai) as Dictionary).duplicate()
	var tint: Array = def.get("tint", [0.9, 0.3, 0.3])
	if tint.size() == 3 and has_node("Sprite2D"):
		($Sprite2D as Sprite2D).modulate = Color(float(tint[0]), float(tint[1]), float(tint[2]))
	add_to_group("enemies")
	return true


func _physics_process(delta: float) -> void:
	_contact_cd = maxf(_contact_cd - delta, 0.0)
	var player := _find_player()
	if player == null:
		return
	var to: Vector2 = (player as Node2D).global_position - global_position
	if to.length() > float(_ai.get("aggro_range", 300.0)):
		velocity = Vector2.ZERO
		move_and_slide()
		return
	if to.length() > float(_ai.get("hit_range", 30.0)):
		velocity = to.normalized() * float(_ai.get("move_speed", 60.0))
	else:
		velocity = Vector2.ZERO
		_try_contact(player)
	move_and_slide()


func _find_player() -> Node:
	var players := get_tree().get_nodes_in_group("player")
	return players[0] if not players.is_empty() else null


## Attacker passes a partial DamageRequest (base/skill/crit/rolls/source);
## armor, damage_type default, and target are filled here.
func take_hit(request: Dictionary) -> Dictionary:
	var dm := get_node_or_null("/root/DataManager")
	var bal := (dm.get_table("combat_balance") as Dictionary) if dm != null else {}
	var req := (request as Dictionary).duplicate()
	req["armor"] = armor
	req["target"] = enemy_id
	var result: Dictionary = DamageCalculator.calculate(req, bal)
	current_hp = maxi(current_hp - int(result["amount"]), 0)
	if current_hp <= 0:
		die()
	return result


func _try_contact(player: Node) -> void:
	if _contact_cd > 0.0:
		return
	_contact_cd = float(_ai.get("contact_cooldown", 1.0))
	var stats = (player as Node).get_node_or_null("CharacterStats")
	if stats == null:
		return
	var rng := get_node_or_null("/root/RNGManager")
	var req := {
		"base_damage": damage, "damage_type": "physical",
		"crit_chance_pct": 0.0, "crit_roll": 1.0,
		"variance_roll": rng.random_float(0.0, 1.0) if rng != null else 0.5,
		"armor": float(stats.get_stat("armor")),
		"source": enemy_id, "target": "player",
	}
	var dm := get_node_or_null("/root/DataManager")
	var bal := (dm.get_table("combat_balance") as Dictionary) if dm != null else {}
	var result: Dictionary = DamageCalculator.calculate(req, bal)
	stats.take_damage(float(result["amount"]))


func die() -> void:
	var bus := get_node_or_null("/root/EventBus")
	if bus != null:
		bus.enemy_killed.emit(enemy_id, level)
	died.emit(self)
	queue_free()


func is_alive() -> bool:
	return current_hp > 0
