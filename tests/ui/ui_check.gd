extends SceneTree
## Headless UI check: real panels against a live player (fixme.md TASK 12).
## Usage: --script res://tests/ui/ui_check.gd
## Covers: panel mount + toggle actions, inventory grid render, select +
## equip through the panel, equipment unequip, talent spend through the
## panel + stat gain, character breakdown text. Prints UI CHECK: PASS.

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
	rng.set_seed(53)
	var gen: RefCounted = LootScript.new(rng, data)
	var main = load("res://scenes/main/Main.tscn").instantiate()
	root.add_child(main)
	await physics_frame
	await physics_frame
	var player = main.get_node("Player")
	var stats = player.get_node("CharacterStats")
	for i in 4:
		stats.add_xp(stats.xp_next) # level 5.
	if (main.ui_panels as Dictionary).size() != 4:
		failures.append("mounted %d panels, want 4" % (main.ui_panels as Dictionary).size())

	# 1. Toggle actions show/hide panels.
	_press(main, "toggle_inventory")
	if not _vis(main, "inventory") or not _vis(main, "equipment"):
		failures.append("I did not open inventory+equipment")
	_press(main, "toggle_character")
	if not _vis(main, "character") or _vis(main, "inventory"):
		failures.append("C did not swap to character")
	_press(main, "toggle_talents")
	if not _vis(main, "talents") or _vis(main, "character"):
		failures.append("T did not swap to talents")

	# 2. Inventory panel: give item, render, select, equip through UI.
	var sword: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	player.pickup_item(sword)
	_press(main, "toggle_inventory")
	var inv = main.ui_panels["inventory"]
	var filled := 0
	for b in inv._grid.get_children():
		if b is Button and not (b as Button).disabled:
			filled += 1
	if filled != 1:
		failures.append("grid shows %d items, want 1" % filled)
	inv._select(0)
	if inv._equip_btn.disabled:
		failures.append("equip button disabled for sword")
	inv._on_equip()
	if player.equipment.get_equipped("main_hand").is_empty():
		failures.append("panel equip failed")

	# 3. Equipment panel: unequip through UI.
	var eq = main.ui_panels["equipment"]
	eq.refresh()
	eq._select("main_hand")
	eq._on_unequip()
	if not player.equipment.get_equipped("main_hand").is_empty():
		failures.append("panel unequip failed")
	if not player.inventory.contains(str(sword["unique_id"])):
		failures.append("unequipped sword not in inventory")

	# 4. Talent panel: spend through UI, stat rises.
	player.equip_item(str(sword["unique_id"])) # sword tree active.
	var tp = main.ui_panels["talents"]
	_press(main, "toggle_talents")
	tp._family_opt.selected = 2 # sword.
	tp.refresh()
	var str0: float = stats.get_stat("str")
	tp._on_spend("sword_mastery")
	if player.talents.get_rank("sword_mastery") != 1:
		failures.append("panel talent spend failed")
	if stats.get_stat("str") <= str0:
		failures.append("talent did not raise str through UI")

	# 5. Character panel: breakdown text present.
	var cp = main.ui_panels["character"]
	_press(main, "toggle_character")
	if not ("STR" in cp._breakdown.text and "Final" in cp._breakdown.text):
		failures.append("breakdown text missing")

	main.queue_free()
	rng.free()
	data.free()
	if failures.is_empty():
		print("UI CHECK: PASS")
		quit(0)
	else:
		printerr("UI CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)


func _press(main: Node, action: String) -> void:
	var ev := InputEventAction.new()
	ev.action = action
	ev.pressed = true
	main._unhandled_input(ev)
	ev.pressed = false
	main._unhandled_input(ev)


func _vis(main: Node, panel: String) -> bool:
	return ((main.ui_panels as Dictionary)[panel] as CanvasItem).visible
