extends SceneTree
## Headless equipment check (fixme.md TASK 11 acceptance).
## Usage: --script res://tests/equipment/equipment_check.gd
## Covers: slot mapping, level/stat requirements, two-handed displacement
## (both directions), accessory pairing, pet-slot guard, modifier output,
## serialize round-trip + corrupt-save rejection.
## Prints EQUIPMENT CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const RNGScript = preload("res://scripts/core/RNGManager.gd")
const LootScript = preload("res://scripts/loot/LootGenerator.gd")
const EquipScript = preload("res://scripts/equipment/EquipmentManager.gd")


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
	rng.set_seed(99)
	var gen: RefCounted = LootScript.new(rng, data)
	var StatsScript := load("res://scripts/character/CharacterStats.gd")
	var stats: Node = StatsScript.new()
	root.add_child(stats)
	for i in 4:
		stats.add_xp(stats.xp_next) # level 5: meets iron requirements.
	var mgr: RefCounted = EquipScript.new(data)

	# 1. Basic equip + slot mapping.
	var sword: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	var r: Dictionary = mgr.equip(sword, stats)
	if not bool(r["ok"]):
		failures.append("sword equip rejected: %s" % r["reason"])
	if str(mgr.get_equipped("main_hand").get("unique_id", "")) != str(sword["unique_id"]):
		failures.append("main_hand mismatch")
	var shield: Dictionary = gen.generate_item("wooden_shield", 5, "uncommon")
	r = mgr.equip(shield, stats)
	if not bool(r["ok"]):
		failures.append("shield equip rejected: %s" % r["reason"])

	# 2. Two-handed displacement, both directions (synthetic 2H footprint).
	var twohand := sword.duplicate(true)
	twohand["unique_id"] = "itm_test_twohand"
	twohand["occupies"] = ["main_hand", "off_hand"]
	r = mgr.equip(twohand, stats)
	if not bool(r["ok"]):
		failures.append("2H equip rejected: %s" % r["reason"])
	if (r["displaced"] as Array).size() != 2:
		failures.append("2H displaced %d, want 2" % (r["displaced"] as Array).size())
	if not mgr.get_equipped("off_hand").is_empty():
		failures.append("off_hand not cleared by 2H")
	r = mgr.equip(shield, stats)
	if not bool(r["ok"]):
		failures.append("shield-after-2H rejected: %s" % r["reason"])
	if (r["displaced"] as Array).size() != 1 or str((r["displaced"] as Array)[0].get("unique_id", "")) != "itm_test_twohand":
		failures.append("shield did not displace 2H")
	if not mgr.get_equipped("main_hand").is_empty():
		failures.append("main_hand not cleared by shield")

	# 3. Level requirement (fresh L1 character).
	var StatsScript2 := load("res://scripts/character/CharacterStats.gd")
	var baby: Node = StatsScript2.new()
	root.add_child(baby)
	var m2: RefCounted = EquipScript.new(data)
	r = m2.equip(sword, baby)
	if bool(r["ok"]):
		failures.append("L1 equipped level-5 sword")
	elif not ("level 5" in str(r["reason"]).to_lower() or "level" in str(r["reason"]).to_lower()):
		failures.append("bad requirement reason: %s" % r["reason"])
	# Stat/unit requirement checks directly.
	if m2._check_requirement({"type": "stat", "stat": "str", "value": 999.0}, baby) == "":
		failures.append("impossible stat req passed")
	if m2._check_requirement({"type": "level", "value": 99}, baby) == "":
		failures.append("impossible level req passed")
	if m2._check_requirement({"type": "fate"}, baby) == "":
		failures.append("unknown req type passed")
	baby.queue_free()

	# 4. Accessory pairing + pet-slot guard.
	var c1: Dictionary = gen.generate_item("lucky_charm", 1, "normal")
	var c2: Dictionary = gen.generate_item("lucky_charm", 1, "normal")
	var c3: Dictionary = gen.generate_item("lucky_charm", 1, "normal")
	mgr.equip(c1, stats)
	mgr.equip(c2, stats)
	if mgr.get_equipped("accessory_1").is_empty() or mgr.get_equipped("accessory_2").is_empty():
		failures.append("accessory pairing failed")
	r = mgr.equip(c3, stats)
	if bool(r["ok"]):
		failures.append("third accessory accepted")
	var fake_pet := {"unique_id": "x", "base_id": "x", "slot": "pet"}
	r = mgr.equip(fake_pet, stats)
	if bool(r["ok"]):
		failures.append("item entered pet slot")

	# 5. Modifiers feed stats (sword re-equipped on fresh manager).
	var m3: RefCounted = EquipScript.new(data)
	m3.equip(sword, stats)
	var mods: Array = m3.to_modifiers()
	var want_str := 8.0
	for a in (sword.get("affixes", []) as Array):
		if str((a as Dictionary).get("stat", "")) == "str" and not bool((a as Dictionary).get("is_percent", false)):
			want_str += float((a as Dictionary).get("value", 0))
	stats.set_contributors("equipment", mods)
	var bd: Dictionary = stats.get_breakdown()
	var got := float(((bd.get("str", {}) as Dictionary).get("flats", {}) as Dictionary).get("equipment", 0.0))
	if not is_equal_approx(got, want_str):
		failures.append("equipment str %.1f, want %.1f" % [got, want_str])

	# 6. Serialize round-trip + corrupt rejection.
	var snap: Dictionary = m3.serialize()
	var m4: RefCounted = EquipScript.new(data)
	if not m4.deserialize(snap):
		failures.append("round-trip deserialize failed")
	elif str(m4.get_equipped("main_hand").get("unique_id", "")) != str(sword["unique_id"]):
		failures.append("round-trip uid mismatch")
	if m4.deserialize({"slots": {"hat": {}}}):
		failures.append("unknown slot accepted")
	if m4.deserialize({"slots": {"main_hand": {"unique_id": "x"}}}):
		failures.append("non-item accepted")

	stats.queue_free()
	rng.free()
	data.free()
	if failures.is_empty():
		print("EQUIPMENT CHECK: PASS")
		quit(0)
	else:
		printerr("EQUIPMENT CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
