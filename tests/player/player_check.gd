extends SceneTree
## Headless player check (Stage 2 acceptance: move, level, stats).
## Usage: --script res://tests/player/player_check.gd
## Validates StatCalculator math pure, then a live Player instance:
## movement via InputMap, XP/level-up (+ EventBus signal), HP rules.

const StatCalculator = preload("res://scripts/character/StatCalculator.gd")


func _init() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []
	_check_calculator(failures)
	await physics_frame
	await physics_frame
	await physics_frame
	await _check_player(failures)
	Input.action_release("move_right")
	if failures.is_empty():
		print("PLAYER CHECK: PASS")
		quit(0)
	else:
		printerr("PLAYER CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)


func _check_calculator(failures: Array) -> void:
	var base := {"str": 10.0, "vit": 10.0}
	var growth := {"str": 2.0, "vit": 3.0}
	var r: Dictionary = StatCalculator.calculate(base, 1, growth, [])
	if not is_equal_approx(float(r["str"]), 10.0):
		failures.append("base stat wrong: %s" % r["str"])
	r = StatCalculator.calculate(base, 3, growth, [])
	if not is_equal_approx(float(r["str"]), 14.0):
		failures.append("level growth wrong: %s" % r["str"])
	r = StatCalculator.calculate(base, 1, growth, [{"stat": "str", "value": 5.0}])
	if not is_equal_approx(float(r["str"]), 15.0):
		failures.append("flat contributor wrong: %s" % r["str"])
	r = StatCalculator.calculate(base, 1, growth, [{"stat": "str", "value": 50.0, "is_percent": true}])
	if not is_equal_approx(float(r["str"]), 15.0):
		failures.append("percent contributor wrong: %s" % r["str"])
	r = StatCalculator.calculate(base, 1, growth, [
		{"stat": "str", "value": 5.0},
		{"stat": "str", "value": 50.0, "is_percent": true},
	])
	if not is_equal_approx(float(r["str"]), 22.5):
		failures.append("flat+percent order wrong: %s" % r["str"])
	if StatCalculator.xp_for_level(1, 100.0, 1.5) != 100:
		failures.append("xp curve L1 wrong")
	if StatCalculator.xp_for_level(2, 100.0, 1.5) != 150:
		failures.append("xp curve L2 wrong")
	if StatCalculator.xp_for_level(3, 100.0, 1.5) != 225:
		failures.append("xp curve L3 wrong")


func _check_player(failures: Array) -> void:
	var scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player := scene.instantiate()
	root.add_child(player)
	await physics_frame
	player.position = Vector2(100, 100)
	var stats = player.get_node("CharacterStats")
	if stats.level != 1:
		failures.append("fresh player not level 1")
	if stats.max_hp() != 100:
		failures.append("L1 max_hp %d, want 100" % stats.max_hp())
	if stats.current_hp != stats.max_hp():
		failures.append("fresh player HP not full")
	# Movement through InputMap only.
	var x0: float = player.position.x
	Input.action_press("move_right")
	for i in 30:
		await physics_frame
	Input.action_release("move_right")
	if player.position.x < x0 + 50.0:
		failures.append("player did not move right (dx=%.1f)" % (player.position.x - x0))
	# XP / level-up / signal.
	var level_ups := [0]
	var bus = root.get_node("EventBus")
	bus.player_level_up.connect(func(_lvl: int) -> void: level_ups[0] += 1)
	stats.add_xp(stats.xp_next)
	if stats.level != 2:
		failures.append("level-up failed (lvl %d)" % stats.level)
	if level_ups[0] != 1:
		failures.append("player_level_up emitted %d times" % level_ups[0])
	if not is_equal_approx(stats.get_stat("str"), 12.0):
		failures.append("L2 str %.1f, want 12" % stats.get_stat("str"))
	# HP rules + contributor hook.
	stats.take_damage(30)
	if stats.current_hp != stats.max_hp() - 30:
		failures.append("damage wrong: %d" % stats.current_hp)
	stats.take_damage(9999)
	if stats.is_alive() or stats.current_hp != 0:
		failures.append("death/clamp wrong")
	stats.heal(50)
	if stats.current_hp != 50:
		failures.append("heal wrong: %d" % stats.current_hp)
	stats.heal(9999)
	if stats.current_hp != stats.max_hp():
		failures.append("overheal not clamped")
	stats.set_contributors("test_gear", [{"stat": "vit", "value": 10.0}])
	# L2 vit 13 + 10 gear = 23 → 50 + 23*5 + 1*10 = 175.
	if stats.max_hp() != 175:
		failures.append("contributor HP %d, want 175" % stats.max_hp())
	player.queue_free()
