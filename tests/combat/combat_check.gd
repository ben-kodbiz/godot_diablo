extends SceneTree
## Headless combat check (fixme.md TASK 13 acceptance).
## Usage: --script res://tests/combat/combat_check.gd
## Covers the damage formula end to end: multipliers, crit math, armor
## mitigation curve, variance determinism, min-damage floor, result shape.
## Prints COMBAT CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const CalcScript = preload("res://scripts/combat/DamageCalculator.gd")


func _init() -> void:
	var failures: Array[String] = []
	var data: Node = DataScript.new()
	data.load_all()
	if data.has_errors():
		for e in data.get_errors():
			printerr(e)
		data.free()
		quit(2)
		return
	var bal: Dictionary = data.get_table("combat_balance")
	var base := {
		"base_damage": 100.0, "skill_mult": 1.0, "weapon_mult": 1.0,
		"buff_mult": 1.0, "crit_chance_pct": 0.0, "crit_damage_pct": 0.0,
		"crit_roll": 1.0, "variance_roll": 0.5, "armor": 0.0,
		"damage_type": "physical", "source": "player", "target": "goblin",
	}

	# 1. Naked hit: 100 base, no armor, neutral variance → 100.
	var r: Dictionary = CalcScript.calculate(base, bal)
	if int(r["amount"]) != 100 or bool(r["critical"]):
		failures.append("naked hit %s" % r)

	# 2. Multiplier chain: 100 × 1.5 skill × 1.2 weapon × 2 buff = 360.
	var chained := base.duplicate()
	chained["skill_mult"] = 1.5
	chained["weapon_mult"] = 1.2
	chained["buff_mult"] = 2.0
	r = CalcScript.calculate(chained, bal)
	if int(r["amount"]) != 360:
		failures.append("multiplier chain %d, want 360" % r["amount"])

	# 3. Crit: 5% roll vs 50% chance, +50% crit damage → 100 × 2.5 = 250.
	var crit := base.duplicate()
	crit["crit_chance_pct"] = 50.0
	crit["crit_roll"] = 0.05
	crit["crit_damage_pct"] = 50.0
	r = CalcScript.calculate(crit, bal)
	if not bool(r["critical"]) or int(r["amount"]) != 250:
		failures.append("crit %s" % r)
	crit["crit_roll"] = 0.75
	r = CalcScript.calculate(crit, bal)
	if bool(r["critical"]) or int(r["amount"]) != 100:
		failures.append("non-crit %s" % r)

	# 4. Armor curve K=100: 100 armor halves, 300 quarters (of 100 base).
	var armored := base.duplicate()
	armored["armor"] = 100.0
	r = CalcScript.calculate(armored, bal)
	if int(r["amount"]) != 50:
		failures.append("armor100 %d, want 50" % r["amount"])
	armored["armor"] = 300.0
	r = CalcScript.calculate(armored, bal)
	if int(r["amount"]) != 25:
		failures.append("armor300 %d, want 25" % r["amount"])

	# 5. Variance determinism: rolls 0.0/1.0 with range 0.1 → 90/110.
	var low := base.duplicate()
	low["variance_roll"] = 0.0
	var high := base.duplicate()
	high["variance_roll"] = 1.0
	var rl: Dictionary = CalcScript.calculate(low, bal)
	var rh: Dictionary = CalcScript.calculate(high, bal)
	if int(rl["amount"]) != 90 or int(rh["amount"]) != 110:
		failures.append("variance %d/%d, want 90/110" % [rl["amount"], rh["amount"]])
	if int(CalcScript.calculate(base, bal)["amount"]) != int(CalcScript.calculate(base, bal)["amount"]):
		failures.append("same input diverged")

	# 6. Min-damage floor: 1 base vs 10000 armor still deals ≥ 1.
	var chip := base.duplicate()
	chip["base_damage"] = 1.0
	chip["armor"] = 10000.0
	r = CalcScript.calculate(chip, bal)
	if int(r["amount"]) < 1:
		failures.append("damage floor broken: %d" % r["amount"])

	# 7. Result shape (§72): all consumer fields present.
	for field in ["amount", "raw", "damage_type", "critical", "blocked", "absorbed", "source", "target"]:
		if not r.has(field):
			failures.append("result missing '%s'" % field)

	data.free()
	if failures.is_empty():
		print("COMBAT CHECK: PASS")
		quit(0)
	else:
		printerr("COMBAT CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
