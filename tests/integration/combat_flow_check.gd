extends SceneTree
## Headless combat flow check (fixme.md TASK 14 acceptance).
## Usage: --script res://tests/integration/combat_flow_check.gd
## Uses the real Main scene: training dummy → player attacks → HP falls →
## death → enemy_killed signal + XP + recorded drop. Prints COMBAT FLOW: PASS.

func _init() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []
	await physics_frame
	await physics_frame
	await physics_frame
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.get_node_or_null("Player")
	if player == null:
		printerr("COMBAT FLOW: FAIL")
		printerr("  no Player in Main")
		quit(1)
		return
	var stats = player.get_node("CharacterStats")
	var dummies := []
	for child in main.get_children():
		if child.is_in_group("enemies"):
			dummies.append(child)
	if dummies.is_empty():
		failures.append("no training dummy spawned")
		_finish(main, failures)
		return
	var dummy = dummies[0]
	var kills := [0]
	root.get_node("EventBus").enemy_killed.connect(func(_id: String, _lvl: int) -> void: kills[0] += 1)
	var xp0: int = stats.xp
	# Walk up and swing until it dies (cooldown forced for speed).
	player.position = (dummy as Node2D).position + Vector2(-40, 0)
	player.set_facing(Vector2.RIGHT)
	var swings := 0
	while is_instance_valid(dummy) and swings < 200:
		player._attack_cd = 0.0
		player.try_attack()
		swings += 1
		await physics_frame
	await physics_frame
	if is_instance_valid(dummy) and (dummy as Node).call("is_alive"):
		failures.append("dummy survived 200 swings")
	if kills[0] != 1:
		failures.append("enemy_killed emitted %d times" % kills[0])
	if stats.level == 1 and stats.xp <= xp0:
		failures.append("no XP awarded (xp=%d lvl=%d)" % [stats.xp, stats.level])
	if (main.last_drops as Array).is_empty():
		failures.append("no drop recorded")
	_finish(main, failures)


func _finish(main: Node, failures: Array) -> void:
	main.queue_free()
	if failures.is_empty():
		print("COMBAT FLOW: PASS")
		quit(0)
	else:
		printerr("COMBAT FLOW: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
