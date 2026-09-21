extends Node
## CharacterStats: level/XP/HP + total-stat ownership for one character.
## Totals always flow through StatCalculator; future contributors plug in via
## set_contributors(source, mods) — equipment/talents/pets/buffs each own one
## source key, so nothing ever patches stats ad hoc (spec #29-30).

const StatCalculator = preload("res://scripts/character/StatCalculator.gd")

var level := 1
var xp := 0
var xp_next := 100
var max_level := 20
var current_hp := 1
var current_mana := 1

var _base := {"str": 10.0, "dex": 10.0, "int": 10.0, "vit": 10.0, "luck": 5.0}
var _per_level := {"str": 2.0, "dex": 2.0, "int": 2.0, "vit": 3.0, "luck": 1.0}
var _hp_rule := {"base_hp": 50.0, "hp_per_vit": 5.0, "hp_per_level": 10.0}
var _mana_rule := {"base_mana": 20.0, "mana_per_int": 3.0}
var _xp_curve := {"base": 100.0, "growth": 1.5}
var _sources := {} # source name -> Array of {stat, value, is_percent}


func _ready() -> void:
	_load_balance()
	xp_next = StatCalculator.xp_for_level(level, _xp_curve["base"], _xp_curve["growth"])
	current_hp = max_hp()
	current_mana = max_mana()


func _load_balance() -> void:
	if not has_node("/root/DataManager"):
		push_warning("CharacterStats: DataManager missing, using fallback numbers.")
		return
	var dm := get_node("/root/DataManager")
	var table: Dictionary = dm.get_table("player_balance")
	if table.is_empty():
		push_warning("CharacterStats: player_balance empty, using fallback numbers.")
		return
	_base = _num_dict(table.get("base_stats", _base))
	_per_level = _num_dict(table.get("per_level", _per_level))
	_hp_rule = _num_dict(table.get("health", _hp_rule))
	_mana_rule = _num_dict(table.get("mana", _mana_rule))
	_xp_curve = _num_dict(table.get("xp_curve", _xp_curve))
	max_level = int((table.get("xp_curve", {}) as Dictionary).get("max_level", max_level))


func _num_dict(d: Variant) -> Dictionary:
	var out := {}
	for k in (d as Dictionary).keys():
		out[k] = float((d as Dictionary)[k])
	return out


## Replace ALL modifiers from one contributor (equipment, talents, …).
func set_contributors(source: String, mods: Array) -> void:
	_sources[source] = mods


func all_contributors() -> Array:
	var out: Array = []
	for key in _sources.keys():
		out.append_array(_sources[key])
	return out


func total_stats() -> Dictionary:
	return StatCalculator.calculate(_base, level, _per_level, all_contributors())


func get_stat(stat: String) -> float:
	return float(total_stats().get(stat, 0.0))


func max_hp() -> int:
	return int(round(float(_hp_rule["base_hp"]) + get_stat("vit") * float(_hp_rule["hp_per_vit"]) + float(level - 1) * float(_hp_rule["hp_per_level"])))


func max_mana() -> int:
	return int(round(float(_mana_rule["base_mana"]) + get_stat("int") * float(_mana_rule["mana_per_int"])))


func add_xp(amount: int) -> void:
	if amount <= 0 or level >= max_level:
		return
	xp += amount
	while xp >= xp_next and level < max_level:
		xp -= xp_next
		level += 1
		if level >= max_level:
			xp = 0
			xp_next = 0
		else:
			xp_next = StatCalculator.xp_for_level(level, _xp_curve["base"], _xp_curve["growth"])
		current_hp = max_hp()
		if is_inside_tree():
			var bus := get_node_or_null("/root/EventBus")
			if bus != null:
				bus.player_level_up.emit(level)


func take_damage(amount: float) -> void:
	current_hp = maxi(current_hp - int(round(amount)), 0)


func heal(amount: float) -> void:
	current_hp = mini(current_hp + int(round(amount)), max_hp())


func is_alive() -> bool:
	return current_hp > 0
