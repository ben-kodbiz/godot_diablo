extends CharacterBody2D
## Player: movement + world presence only (Stage 2 per todoagent.md §76).
## Combat, equipment, and talents arrive as separate components/systems —
## this script never grows into a god object. Stats live in $CharacterStats.

var stats: Node
var _move_base := 200.0


func _ready() -> void:
	stats = $CharacterStats
	if has_node("/root/DataManager"):
		var table: Dictionary = get_node("/root/DataManager").get_table("player_balance")
		var rule: Dictionary = table.get("move_speed", {})
		_move_base = float(rule.get("base_px_per_sec", _move_base))


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
