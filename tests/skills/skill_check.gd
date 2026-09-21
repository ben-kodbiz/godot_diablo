extends SceneTree
## Headless skill tool. Reuses production DataManager/SkillManager.
## Usage (run from repo root with a Godot binary):
##   Show a weapon's skill tree at a level (with 7 demo points spent in order):
##     --script res://tests/skills/skill_check.gd -- --weapon=staff --level=10
##   Validate (data rules, economy, upgrade math, level-20 cap):
##     --script res://tests/skills/skill_check.gd -- --check

const DataScript = preload("res://scripts/core/DataManager.gd")
const SkillScript = preload("res://scripts/skills/SkillManager.gd")

const FAMILIES := ["bow", "staff", "sword", "shield"]


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var data: Node = DataScript.new()
	data.load_all()
	if data.has_errors():
		for e in data.get_errors():
			printerr(e)
		data.free()
		quit(2)
		return
	var exit_code := 0
	if bool(args.get("check", false)):
		exit_code = 0 if _run_check(data) else 1
	else:
		_run_show(data, str(args.get("weapon", "staff")), int(args.get("level", 10)))
	data.free()
	quit(exit_code)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {"weapon": "staff", "level": 10, "check": false}
	for a in raw:
		var s := a.trim_prefix("--")
		if s == "check":
			out["check"] = true
		elif "=" in s:
			var parts := s.split("=", true, 1)
			out[parts[0]] = parts[1] if parts.size() > 1 else ""
		else:
			out[s] = true
	out["level"] = int(out.get("level", 10))
	return out


func _run_show(data: Node, family: String, level: int) -> void:
	var mgr: RefCounted = SkillScript.new(data)
	# Demo spend: unlock in order, then pour remaining points into skill 1.
	for def in mgr.unlocked_skills(family, level):
		mgr.unlock(str((def as Dictionary).get("id", "")), family, level)
	var first: Array = mgr.unlocked_skills(family, level)
	while not first.is_empty() and mgr.upgrade(str((first[0] as Dictionary).get("id", "")), level):
		pass
	print("%s skills at player level %d (points %d/%d spent):" % [
		family, level, mgr.spent_points(), mgr.lifetime_points(level)])
	for v in mgr.family_view(family, level):
		var vd := v as Dictionary
		var state := "rank %d/%d" % [vd["rank"], vd["max_rank"]] if int(vd["rank"]) > 0 else ("locked" if not bool(vd["unlocked"]) else "available")
		print("  L" + str(vd["unlock_level"]) + " " + str(vd["name"]).rpad(18)
			+ " " + state.rpad(10)
			+ " flat=" + str(vd["damage_flat"]) + " pct=" + str(vd["damage_pct"])
			+ " cd=" + str(vd["cooldown_sec"]) + "s mana=" + str(vd["mana_cost"]))
	print("")


func _run_check(data: Node) -> bool:
	var failures: Array[String] = []
	var table: Dictionary = data.get_table("skills")
	var mgr: RefCounted = SkillScript.new(data)
	# 1. Data rules: ≤10 per family, unlock levels in 1..20, ranks sane.
	for family in FAMILIES:
		var fam: Array = mgr.family_skills(family)
		if fam.size() > 10:
			failures.append("%s has %d skills (max 10)" % [family, fam.size()])
		var prev := 0
		for def in fam:
			var dd := def as Dictionary
			var ul := int(dd.get("unlock_level", 0))
			if ul < 1 or ul > 20:
				failures.append("%s unlock_level %d out of 1..20" % [dd["id"], ul])
			if ul < prev:
				failures.append("%s not in unlock order" % family)
			prev = ul
			if int(dd.get("max_rank", 0)) < 1:
				failures.append("%s bad max_rank" % dd["id"])
			for section in ["base", "per_rank"]:
				var sd: Dictionary = dd.get(section, {})
				for field in ["damage_flat", "damage_pct"]:
					if not sd.has(field):
						failures.append("%s %s missing %s" % [dd["id"], section, field])
	# 2. Economy: 1 point at L1, 2 at L4, 7 at L20.
	for pair in [[1, 1], [3, 1], [4, 2], [19, 7], [20, 7]]:
		var got: int = mgr.lifetime_points(int(pair[0]))
		if got != int(pair[1]):
			failures.append("points at L%d = %d, want %d" % [pair[0], got, pair[1]])
	# 3. Spend flow on a fresh manager at L20 (7 points).
	var m2: RefCounted = SkillScript.new(data)
	if not m2.unlock("staff_magic_bolt", "staff", 20):
		failures.append("could not unlock first skill")
	if m2.unlock("staff_magic_bolt", "staff", 20):
		failures.append("double unlock allowed")
	if m2.unlock("staff_meteor", "staff", 10):
		failures.append("above-level unlock allowed")
	if m2.upgrade("staff_arcane_blast", 20):
		failures.append("upgrade of locked skill allowed")
	for i in 4:
		if not m2.upgrade("staff_magic_bolt", 20):
			failures.append("upgrade %d rejected" % i)
	if m2.upgrade("staff_magic_bolt", 20):
		failures.append("over-max-rank upgrade allowed")
	if m2.spendable_points(20) != 2:
		failures.append("spendable %d, want 2" % m2.spendable_points(20))
	if m2.unlock("bow_quick_shot", "staff", 20):
		failures.append("cross-family unlock allowed")
	# 4. Power math: bolt rank 5 = (12 + 6*4) flat, (0 + 5*4) pct.
	var power: Dictionary = m2.skill_power("staff_magic_bolt")
	if not is_equal_approx(float(power["damage_flat"]), 36.0):
		failures.append("bolt flat %s, want 36" % power["damage_flat"])
	if not is_equal_approx(float(power["damage_pct"]), 20.0):
		failures.append("bolt pct %s, want 20" % power["damage_pct"])
	# 5. Player level cap 20 (CharacterStats, in-tree so balance loads).
	var StatsScript := load("res://scripts/character/CharacterStats.gd")
	var stats: Node = StatsScript.new()
	root.add_child(stats)
	stats.add_xp(10_000_000)
	if stats.level != 20:
		failures.append("level cap broken: lvl %d" % stats.level)
	stats.add_xp(10_000_000)
	if stats.level != 20:
		failures.append("XP past cap changed level")
	stats.free()
	if failures.is_empty():
		print("SKILL CHECK: PASS (families=%d)" % FAMILIES.size())
		return true
	printerr("SKILL CHECK: FAIL")
	for f in failures.slice(0, 20):
		printerr("  " + f)
	return false
