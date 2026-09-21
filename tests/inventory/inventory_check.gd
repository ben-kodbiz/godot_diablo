extends SceneTree
## Headless inventory check (fixme.md TASK 10 acceptance).
## Usage: --script res://tests/inventory/inventory_check.gd
## Covers: grid capacity + overflow, add/remove/contains/find, move/swap,
## rarity sort, criteria filter, stack merging, serialize round-trip + corrupt.
## Prints INVENTORY CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const RNGScript = preload("res://scripts/core/RNGManager.gd")
const LootScript = preload("res://scripts/loot/LootGenerator.gd")
const InvScript = preload("res://scripts/inventory/InventoryManager.gd")


func _init() -> void:
	_run()


func _run() -> void:
	var failures: Array[String] = []
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
	rng.set_seed(7)
	var gen: RefCounted = LootScript.new(rng, data)
	var inv: RefCounted = InvScript.new(data)
	if inv.capacity() != 60:
		failures.append("capacity %d, want 60 (10x6)" % inv.capacity())

	# 1. Add + find + contains + remove.
	var sword: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	var r: Dictionary = inv.add(sword)
	if not bool(r["ok"]) or int(r["slot"]) != 0:
		failures.append("first add failed: %s" % r)
	if not inv.contains(str(sword["unique_id"])):
		failures.append("contains missed sword")
	if inv.find_by_base("iron_sword").size() != 1:
		failures.append("find_by_base wrong")
	if inv.find_by_rarity("epic").size() != 0:
		failures.append("find_by_rarity phantom hit")
	var gone: Dictionary = inv.remove(str(sword["unique_id"]))
	if str(gone.get("unique_id", "")) != str(sword["unique_id"]):
		failures.append("remove returned wrong item")
	if inv.contains(str(sword["unique_id"])):
		failures.append("removed item still contained")
	if not inv.remove("itm_missing").is_empty():
		failures.append("remove of missing not empty")
	r = inv.add(sword)
	r = inv.add(sword)
	if bool(r["ok"]):
		failures.append("duplicate unique_id accepted")

	# 2. Move / swap.
	var bow: Dictionary = gen.generate_item("iron_bow", 5, "normal")
	inv.add(bow) # slot 1 (sword re-added at 0 above)
	if not inv.move(1, 5):
		failures.append("move failed")
	if str(inv.get_at(5).get("unique_id", "")) != str(bow["unique_id"]):
		failures.append("move target wrong")
	if not inv.get_at(1).is_empty():
		failures.append("move source not cleared")
	if not inv.move(5, 0):
		failures.append("swap failed")
	if str(inv.get_at(0).get("unique_id", "")) != str(bow["unique_id"]):
		failures.append("swap result wrong")
	if inv.move(3, 4):
		failures.append("move from empty accepted")
	if inv.move(0, 6000):
		failures.append("move out of range accepted")

	# 3. Sort (rarity desc) + filter.
	var inv2: RefCounted = InvScript.new(data)
	var i_n: Dictionary = gen.generate_item("cloth_armor", 1, "normal")
	var i_r: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	var i_e: Dictionary = gen.generate_item("apprentice_staff", 10, "epic")
	inv2.add(i_n)
	inv2.add(i_r)
	inv2.add(i_e)
	inv2.sort_inventory()
	var order: Array = []
	for entry in inv2.list():
		order.append(str((entry["item"] as Dictionary)["rarity"]))
	if order != ["epic", "rare", "normal"]:
		failures.append("sort order %s" % str(order))
	var filt: Array = inv2.filter({"min_level": 5})
	if filt.size() != 2:
		failures.append("min_level filter %d, want 2" % filt.size())
	filt = inv2.filter({"rarity": "rare", "slot": "main_hand"})
	if filt.size() != 1 or str((filt[0]["item"] as Dictionary)["base_id"]) != "iron_sword":
		failures.append("combined filter wrong")

	# 4. Stacking (synthetic stackables).
	var inv3: RefCounted = InvScript.new(data, 2, 2)
	var coin := func(q: int, uid: String) -> Dictionary:
		return {"unique_id": uid, "base_id": "gold_coin", "name": "Gold",
			"rarity": "normal", "slot": "misc", "stackable": true, "quantity": q}
	r = inv3.add(coin.call(60, "c1"))
	r = inv3.add(coin.call(50, "c2")) # 39 merge into c1 (cap 99), 11 stay on c2.
	if not bool(r["ok"]):
		failures.append("stack add failed: %s" % r)
	var s0: Dictionary = inv3.get_at(0)
	var s1: Dictionary = inv3.get_at(1)
	if int(s0.get("quantity", 0)) != 99 or int(s1.get("quantity", 0)) != 11:
		failures.append("stack merge %s/%s" % [s0.get("quantity", "?"), s1.get("quantity", "?")])
	if inv3.list().size() != 2:
		failures.append("stack used wrong slot count")

	# 5. Overflow on a tiny grid (non-stackables cannot share a slot).
	var inv4: RefCounted = InvScript.new(data, 1, 1)
	inv4.add(gen.generate_item("cloth_armor", 1, "normal"))
	r = inv4.add(gen.generate_item("cloth_armor", 1, "normal"))
	if bool(r["ok"]):
		failures.append("overflow accepted")
	if inv4.count_free() != 0:
		failures.append("count_free wrong on full grid")

	# 6. Serialize round-trip + corrupt rejection.
	var snap: Dictionary = inv2.serialize()
	var inv5: RefCounted = InvScript.new(data)
	if not inv5.deserialize(snap):
		failures.append("round-trip failed")
	elif inv5.list().size() != 3:
		failures.append("round-trip lost items")
	if inv5.deserialize({"width": 1}):
		failures.append("gridless save accepted")
	if inv5.deserialize({"width": 1, "height": 1, "items": [{}, {}]}):
		failures.append("oversized save accepted")
	if inv5.deserialize({"width": 1, "height": 1, "items": [{"unique_id": "a"}, {"unique_id": "a"}]}):
		failures.append("duplicate-uid save accepted")

	rng.free()
	data.free()
	if failures.is_empty():
		print("INVENTORY CHECK: PASS")
		quit(0)
	else:
		printerr("INVENTORY CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
