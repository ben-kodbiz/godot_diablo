extends SceneTree
## Headless pet tool. Reuses production RNGManager/DataManager/PetGenerator.
## Usage (run from repo root with a Godot binary):
##   Hatch N eggs:
##     --script res://tests/pets/pet_simulator.gd -- --egg=sky_egg --count=5 --seed=3
##   Simulate egg drops (1000 kills of a tier at a map level):
##     --script res://tests/pets/pet_simulator.gd -- --drops --tier=elite --map-level=15 --kills=1000 --seed=3
##   Validate (hatch odds, drop rates, gating, unique ids):
##     --script res://tests/pets/pet_simulator.gd -- --check

const RNGScript = preload("res://scripts/core/RNGManager.gd")
const DataScript = preload("res://scripts/core/DataManager.gd")
const PetGen = preload("res://scripts/pets/PetGenerator.gd")
const PetInstance = preload("res://scripts/pets/PetInstance.gd")


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var rng: Node = RNGScript.new()
	var data: Node = DataScript.new()
	var seed_value := int(args.get("seed", 0))
	if seed_value == 0:
		rng._rng.randomize()
	else:
		rng.set_seed(seed_value)
	data.load_all()
	if data.has_errors():
		for e in data.get_errors():
			printerr(e)
		rng.free()
		data.free()
		quit(2)
		return
	var gen: RefCounted = PetGen.new(rng, data)
	var exit_code := 0
	if bool(args.get("check", false)):
		exit_code = 0 if _run_check(gen, data) else 1
	elif bool(args.get("drops", false)):
		_run_drops(gen, args)
	else:
		_run_hatch(gen, data, args)
	rng.free()
	data.free()
	quit(exit_code)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {"egg": "forest_egg", "count": 5, "seed": 0, "tier": "elite",
		"map-level": 15, "kills": 1000, "check": false, "drops": false}
	for a in raw:
		var s := a.trim_prefix("--")
		if s == "check":
			out["check"] = true
		elif s == "drops":
			out["drops"] = true
		elif "=" in s:
			var parts := s.split("=", true, 1)
			out[parts[0]] = parts[1] if parts.size() > 1 else ""
		else:
			out[s] = true
	out["count"] = int(out.get("count", 5))
	out["seed"] = int(out.get("seed", 0))
	out["map-level"] = int(out.get("map-level", 15))
	out["kills"] = int(out.get("kills", 1000))
	return out


func _run_hatch(gen: RefCounted, data: Node, args: Dictionary) -> void:
	var egg_id := str(args.get("egg", "forest_egg"))
	var egg: Dictionary = data.get_egg(egg_id)
	print("%s — hatch %dh, odds:" % [str(egg.get("name", egg_id)), int(egg.get("hatch_time_hours", 0))])
	for o in gen.hatch_odds(egg_id):
		var od := o as Dictionary
		var tag := "wild" if bool(od.get("wild", false)) else "fixed"
		print("  %s (%s): %.1f%% [%s]" % [od["label"], od["rarity"], float(od["chance_pct"]), tag])
	print("")
	var count: int = maxi(int(args.get("count", 5)), 1)
	for i in count:
		var pet: Dictionary = gen.hatch(egg_id)
		if pet.is_empty():
			continue
		print(PetInstance.tooltip(pet))
		print("")


func _run_drops(gen: RefCounted, args: Dictionary) -> void:
	var tier := str(args.get("tier", "elite"))
	var map_level: int = int(args.get("map-level", 15))
	var kills: int = maxi(int(args.get("kills", 1000)), 1)
	var drops := {}
	for i in kills:
		var egg_id: String = gen.roll_egg_drop(tier, map_level)
		if egg_id != "":
			drops[egg_id] = int(drops.get(egg_id, 0)) + 1
	var total := 0
	for key in drops.keys():
		total += int(drops[key])
	print("%d %s kills at map level %d → %d eggs (%.2f%%)" % [kills, tier, map_level, total, 100.0 * total / kills])
	var keys: Array = drops.keys()
	keys.sort()
	for key in keys:
		print("  %s: %d (%.2f%% of kills)" % [key, drops[key], 100.0 * drops[key] / kills])


## Returns "" if the wild pet is valid, else a failure description.
func _check_wild(pet: Dictionary, species: Dictionary, scaling: Dictionary) -> String:
	var sid := str(pet.get("species", "?"))
	var rarity_id := str(pet.get("rarity", "?"))
	if not species.has(sid):
		return "unknown species '%s'" % sid
	if str(pet.get("pet_id", "")) != "%s_%s" % [sid, rarity_id]:
		return "bad wild pet_id '%s'" % pet.get("pet_id", "")
	var spec := species[sid] as Dictionary
	var rule: Dictionary = scaling.get(rarity_id, {})
	var pool: Array = spec.get("wild_pool", [])
	var want_lines: int = mini(int(rule.get("bonus_lines", 1)), pool.size())
	var mult := float(rule.get("value_mult", 1.0))
	var bonuses: Array = pet.get("bonuses", [])
	if bonuses.size() != want_lines:
		return "%s got %d bonus lines, want %d" % [sid, bonuses.size(), want_lines]
	var pool_stats := {}
	for e in pool:
		var ed := e as Dictionary
		pool_stats[str(ed.get("stat", ""))] = ed
	var seen_stats := {}
	for b in bonuses:
		var bd := b as Dictionary
		var stat := str(bd.get("stat", "?"))
		if not pool_stats.has(stat):
			return "%s bonus stat '%s' not in species pool" % [sid, stat]
		if seen_stats.has(stat):
			return "%s duplicate bonus stat '%s'" % [sid, stat]
		seen_stats[stat] = true
		var entry := pool_stats[stat] as Dictionary
		var raw_est := float(bd.get("value", 0)) / mult
		if raw_est < float(entry.get("min", 0)) - 1.0 or raw_est > float(entry.get("max", 0)) + 1.0:
			return "%s %s value %s out of scaled bounds" % [sid, stat, str(bd.get("value", ""))]
	return ""


func _run_check(gen: RefCounted, data: Node) -> bool:
	var failures: Array[String] = []
	var eggs: Dictionary = data.get_table("eggs")
	var pets: Dictionary = data.get_table("pets")
	var species: Dictionary = data.get_table("species")
	var scaling: Dictionary = (data.get_table("pet_balance") as Dictionary).get("rarity_scaling", {})
	# 1. Every egg hatches valid fixed + wild pets at roughly the defined odds.
	for egg_id in eggs.keys():
		var seen := {}
		var total := 2000
		for i in total:
			var pet: Dictionary = gen.hatch(str(egg_id))
			if pet.is_empty():
				failures.append("%s: empty hatch" % egg_id)
				break
			var uid := str(pet.get("unique_id", ""))
			if not uid.begins_with("pet_"):
				failures.append("%s: bad pet id '%s'" % [egg_id, uid])
			if str(pet.get("egg_source", "")) != str(egg_id):
				failures.append("%s: wrong egg_source" % egg_id)
			if bool(pet.get("wild", false)):
				var key := "W:%s/%s" % [pet.get("species", "?"), pet.get("rarity", "?")]
				seen[key] = int(seen.get(key, 0)) + 1
				var wfail: String = _check_wild(pet, species, scaling)
				if wfail != "":
					failures.append("%s: %s" % [egg_id, wfail])
			else:
				var pid := str(pet.get("pet_id", "?"))
				seen["F:" + pid] = int(seen.get("F:" + pid, 0)) + 1
				if not pets.has(pid):
					failures.append("%s: unknown pet '%s'" % [egg_id, pid])
		for o in gen.hatch_odds(str(egg_id)):
			var od := o as Dictionary
			var key := ("W:" if bool(od.get("wild", false)) else "F:") + str(od["ref"])
			if bool(od.get("wild", false)):
				key += "/" + str(od["rarity"])
			var got := 100.0 * float(seen.get(key, 0)) / float(total)
			var want := float(od["chance_pct"])
			if absf(got - want) > maxf(want * 0.3, 1.0):
				failures.append("%s %s rate %.1f%% want %.1f%%" % [egg_id, key, got, want])
	# 2. Drop rates per tier (seeded): normal ~0.5%, elite ~5%, boss ~25%.
	var expected := {"normal": 0.5, "elite": 5.0, "boss": 25.0}
	for tier in expected.keys():
		var hits := 0
		var kills := 20000
		for i in kills:
			if str(gen.roll_egg_drop(str(tier), 25)) != "":
				hits += 1
		var got := 100.0 * float(hits) / float(kills)
		var want := float(expected[tier])
		if absf(got - want) > maxf(want * 0.3, 0.3):
			failures.append("tier %s drop rate %.2f%% want %.2f%%" % [tier, got, want])
		else:
			print("tier %s: %.2f%% over %d kills" % [tier, got, kills])
	# 3. Map-level gating: level 1 can only ever drop forest_egg.
	for i in 5000:
		var egg_id: String = gen.roll_egg_drop("elite", 1)
		if egg_id != "" and egg_id != "forest_egg":
			failures.append("gating broken: '%s' dropped at map level 1" % egg_id)
			break
	# 4. Dragon stays jackpot-rare: boss pool caps it at 15% of boss eggs.
	var dragon := 0
	var boss_eggs := 0
	for i in 20000:
		var egg_id: String = gen.roll_egg_drop("boss", 25)
		if egg_id != "":
			boss_eggs += 1
			if egg_id == "dragon_egg":
				dragon += 1
	var dragon_share := 100.0 * float(dragon) / float(maxi(boss_eggs, 1))
	print("dragon share of boss eggs: %.1f%% (%d/%d)" % [dragon_share, dragon, boss_eggs])
	if dragon_share > 20.0:
		failures.append("dragon too common: %.1f%% of boss eggs" % dragon_share)
	if failures.is_empty():
		print("PET CHECK: PASS")
		return true
	printerr("PET CHECK: FAIL")
	for f in failures.slice(0, 20):
		printerr("  " + f)
	return false
