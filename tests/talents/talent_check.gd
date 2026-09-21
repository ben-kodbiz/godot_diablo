extends SceneTree
## Headless talent check (fixme.md TASK 15 acceptance).
## Usage: --script res://tests/talents/talent_check.gd
## Covers: data rules, point economy, active-family gating, upgrade caps,
## modifier math, reset, and player integration (equip → tree → stat gain).
## Prints TALENT CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const RNGScript = preload("res://scripts/core/RNGManager.gd")
const LootScript = preload("res://scripts/loot/LootGenerator.gd")
const TalentScript = preload("res://scripts/talents/TalentManager.gd")


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
	var mgr: RefCounted = TalentScript.new(data)

	# 1. Data rules: 4 trees × 5 talents, known families.
	for family in ["bow", "staff", "sword", "shield"]:
		if mgr.family_talents(family).size() != 5:
			failures.append("%s tree size %d, want 5" % [family, mgr.family_talents(family).size()])

	# 2. Economy: points == level (L1 → 1, L20 → 20).
	if mgr.lifetime_points(1) != 1:
		failures.append("L1 points %d, want 1" % mgr.lifetime_points(1))
	if mgr.lifetime_points(20) != 20:
		failures.append("L20 points %d, want 20" % mgr.lifetime_points(20))

	# 3. Family gating: nothing spendable with no active family.
	mgr.set_active_family("")
	if mgr.unlock("sword_mastery", 5):
		failures.append("unlock with no active family allowed")
	mgr.set_active_family("sword")
	if not mgr.unlock("sword_mastery", 5):
		failures.append("sword unlock rejected")
	if mgr.unlock("bow_precision", 5):
		failures.append("cross-tree unlock allowed")
	if mgr.unlock("sword_mastery", 5):
		failures.append("double unlock allowed")

	# 4. Upgrades to max rank, then refusal; spend accounting.
	for i in 4:
		if not mgr.upgrade("sword_mastery", 5):
			failures.append("upgrade %d rejected" % i)
	if mgr.upgrade("sword_mastery", 5):
		failures.append("over-max-rank upgrade allowed")
	if mgr.spent_points() != 5 or mgr.spendable_points(5) != 0:
		failures.append("spend accounting %d/%d" % [mgr.spent_points(), mgr.spendable_points(5)])
	if mgr.upgrade("sword_cleave", 5):
		failures.append("upgrade of locked talent allowed")

	# 5. Modifier math: mastery rank 5 = +10 STR, stamped talent.
	var mods: Array = mgr.to_modifiers()
	if mods.size() != 1:
		failures.append("modifier count %d, want 1" % mods.size())
	else:
		var m := mods[0] as Dictionary
		if str(m.get("stat", "")) != "str" or not is_equal_approx(float(m.get("value", 0)), 10.0):
			failures.append("modifier wrong: %s" % m)
		if str(m.get("source_type", "")) != "talent":
			failures.append("modifier not stamped talent")
	mgr.reset()
	if mgr.spent_points() != 0 or not mgr.to_modifiers().is_empty():
		failures.append("reset failed")

	# 6. Player integration: equip sword → sword tree live → STR rises.
	var rng: Node = RNGScript.new()
	rng.set_seed(31)
	var gen: RefCounted = LootScript.new(rng, data)
	var scene: PackedScene = load("res://scenes/player/Player.tscn")
	var player = scene.instantiate()
	root.add_child(player)
	await physics_frame
	var stats = player.get_node("CharacterStats")
	for i in 4:
		stats.add_xp(stats.xp_next) # level 5.
	var sword: Dictionary = gen.generate_item("iron_sword", 5, "rare")
	player.pickup_item(sword)
	player.equip_item(str(sword["unique_id"]))
	if str(player.talents.get_active_family()) != "sword":
		failures.append("active family '%s', want sword" % player.talents.get_active_family())
	var str_before: float = stats.get_stat("str")
	if not player.talents.unlock("sword_mastery", stats.level):
		failures.append("player talent unlock rejected")
	player.refresh_stats()
	# L5 str base 10 + 2*4 = 18, + sword 8, + mastery 2 = 28 (+ any str affix).
	var want := 28.0
	for a in (sword.get("affixes", []) as Array):
		if str((a as Dictionary).get("stat", "")) == "str":
			want += float((a as Dictionary).get("value", 0))
	if not is_equal_approx(stats.get_stat("str"), want):
		failures.append("talented str %.1f, want %.1f" % [stats.get_stat("str"), want])
	if str_before >= stats.get_stat("str"):
		failures.append("talent did not raise str")
	var bd: Dictionary = stats.get_breakdown()
	if not ((bd.get("str", {}) as Dictionary).get("flats", {}) as Dictionary).has("talent"):
		failures.append("breakdown missing talent source")

	player.queue_free()
	rng.free()
	data.free()
	if failures.is_empty():
		print("TALENT CHECK: PASS")
		quit(0)
	else:
		printerr("TALENT CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
