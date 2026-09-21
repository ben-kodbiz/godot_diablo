extends SceneTree
## Headless loadout check: loot → inventory → equipment → stats + signals.
## Usage: --script res://tests/integration/loadout_check.gd
## Prints LOADOUT CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const RNGScript = preload("res://scripts/core/RNGManager.gd")
const LootScript = preload("res://scripts/loot/LootGenerator.gd")


func _init() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []
	await physics_frame
	await physics_frame
	await physics_frame
	var data: Node = DataScript.new()
	data.load_all()
	if data.has_errors():
		for e in data.get_errors():
			printerr(e)
		data.free()
		quit(2)
		return
	var rng: Node = RNGScript.new()
	rng.set_seed(21)
	var gen: RefCounted = LootScript.new(rng, data)
	var scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	root.add_child(player)
	await physics_frame
	var stats = player.get_node("CharacterStats")
	for i in 4:
		stats.add_xp(stats.xp_next) # level 5.
	var equipped_signals := [0]
	root.get_node("EventBus").item_equipped.connect(func(_id: String, _slot: String) -> void: equipped_signals[0] += 1)

	# 1. Pickup → equip → stats rise → signal fires.
	var sword: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	var str0: float = stats.get_stat("str")
	if not bool(player.pickup_item(sword)["ok"]):
		failures.append("pickup failed")
	var er: Dictionary = player.equip_item(str(sword["unique_id"]))
	if not bool(er["ok"]):
		failures.append("equip failed: %s" % er.get("reason", "?"))
	if equipped_signals[0] != 1:
		failures.append("item_equipped emitted %d times" % equipped_signals[0])
	var want := 8.0
	for a in (sword.get("affixes", []) as Array):
		if str((a as Dictionary).get("stat", "")) == "str":
			want += float((a as Dictionary).get("value", 0))
	# L5 str base 10 + 2*4 = 18; equipment adds base 8 + str affixes.
	if not is_equal_approx(stats.get_stat("str"), 18.0 + want):
		failures.append("equipped str %.1f, want %.1f" % [stats.get_stat("str"), 18.0 + want])

	# 2. Shield alongside, then unequip returns it to inventory.
	var shield: Dictionary = gen.generate_item("wooden_shield", 5, "uncommon")
	player.pickup_item(shield)
	player.equip_item(str(shield["unique_id"]))
	var ur: Dictionary = player.unequip_slot("off_hand")
	if not bool(ur["ok"]):
		failures.append("unequip failed: %s" % ur.get("reason", "?"))
	if not player.inventory.contains(str(shield["unique_id"])):
		failures.append("unequipped shield not in inventory")
	if not player.equipment.get_equipped("off_hand").is_empty():
		failures.append("off_hand not cleared")

	# 3. Under-leveled player is refused, item stays in inventory.
	var baby = scene.instantiate()
	root.add_child(baby)
	await physics_frame
	var bstats = baby.get_node("CharacterStats")
	var bsword: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	baby.pickup_item(bsword)
	var br: Dictionary = baby.equip_item(str(bsword["unique_id"]))
	if bool(br["ok"]):
		failures.append("L1 equipped level-5 sword")
	if not baby.inventory.contains(str(bsword["unique_id"])):
		failures.append("refused item left inventory")
	if not is_equal_approx(bstats.get_stat("str"), 10.0):
		failures.append("baby str changed without equip")

	# 4. Full inventory refuses a displacing swap (everything stays put).
	# Setup: sword + shield equipped; inventory holds 58 junk + twohand + 1 junk
	# = 60/60. Removing twohand frees 1 slot, but 2 occupants clash → refuse.
	player.equip_item(str(shield["unique_id"]))
	for i in 58:
		var junk: Dictionary = gen.generate_item("cloth_armor", 1, "normal")
		player.pickup_item(junk)
	var twohand: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	twohand["unique_id"] = "itm_test_flow_2h"
	twohand["occupies"] = ["main_hand", "off_hand"]
	player.pickup_item(twohand)
	player.pickup_item(gen.generate_item("cloth_armor", 1, "normal"))
	var tr: Dictionary = player.equip_item("itm_test_flow_2h")
	if bool(tr["ok"]):
		failures.append("displacing swap accepted with no room")
	if player.equipment.get_equipped("main_hand").is_empty():
		failures.append("sword lost on refused swap")
	if not player.inventory.contains("itm_test_flow_2h"):
		failures.append("2H left inventory on refused swap")

	player.queue_free()
	baby.queue_free()
	rng.free()
	data.free()
	if failures.is_empty():
		print("LOADOUT CHECK: PASS")
		quit(0)
	else:
		printerr("LOADOUT CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
