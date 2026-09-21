extends SceneTree
## Headless loot tool. Reuses production RNGManager/DataManager/LootGenerator.
## Usage (run from repo root with a Godot binary):
##   Roll items:
##     --script res://tests/loot/loot_simulator.gd -- --rarity=rare --base=iron_bow --level=14 --count=5 --seed=7
##   Validate generator (10k rolls, spec #57):
##     --script res://tests/loot/loot_simulator.gd -- --check
## Args: --base (default: cycle all), --rarity (default: weighted roll),
##       --level (default 10), --count (default 5), --seed (default 0=random).

const RNGScript = preload("res://scripts/core/RNGManager.gd")
const DataScript = preload("res://scripts/core/DataManager.gd")
const LootGen = preload("res://scripts/loot/LootGenerator.gd")
const ItemInstance = preload("res://scripts/loot/ItemInstance.gd")

const RANKS := ["normal", "uncommon", "rare", "epic", "legendary"]


func _init() -> void:
	var args := _parse_args(OS.get_cmdline_user_args())
	var rng: Node = RNGScript.new()
	var data: Node = DataScript.new()
	var seed_value := int(args.get("seed", 0))
	if seed_value == 0 and bool(args.get("check", false)):
		seed_value = 12345 # deterministic gate (fixme.md §14); override with --seed=N.
	if seed_value == 0:
		rng._rng.randomize()
	else:
		rng.set_seed(seed_value)
	data.load_all()
	if data.has_errors():
		for e in data.get_errors():
			printerr(e)
		quit(2)
		return
	var gen: RefCounted = LootGen.new(rng, data)
	var exit_code := 0
	if bool(args.get("check", false)):
		exit_code = 0 if _run_check(gen, data) else 1
	else:
		_run_rolls(gen, data, args)
	rng.free()
	data.free()
	quit(exit_code)


func _parse_args(raw: PackedStringArray) -> Dictionary:
	var out := {"level": 10, "count": 5, "seed": 0, "base": "", "rarity": "", "check": false}
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
	out["count"] = int(out.get("count", 5))
	out["seed"] = int(out.get("seed", 0))
	return out


func _run_rolls(gen: RefCounted, data: Node, args: Dictionary) -> void:
	var bases: Array = []
	if str(args.get("base", "")) != "":
		bases = [str(args["base"])]
	else:
		var table: Dictionary = data.get_table("equipment")
		bases = table.keys()
		bases.sort()
	var rarity := str(args.get("rarity", ""))
	var count: int = maxi(int(args.get("count", 5)), 1)
	for i in count:
		var item: Dictionary = gen.generate_item(
			str(bases[i % bases.size()]), int(args.get("level", 10)), rarity)
		if item.is_empty():
			printerr("FAILED to generate item.")
			continue
		print(ItemInstance.tooltip(item))
		print("")


func _run_check(gen: RefCounted, data: Node) -> bool:
	var failures: Array[String] = []
	var rarities: Dictionary = data.get_table("rarities")
	var affix_defs: Dictionary = data.get_table("affixes")
	var effect_defs: Dictionary = data.get_table("effects")
	var balance: Dictionary = data.get_table("balance")
	var per_level := float((balance.get("scaling", {}) as Dictionary).get("value_per_level", 0.08))
	var mults: Dictionary = balance.get("rarity_multipliers", {})
	var bases: Array = (data.get_table("equipment") as Dictionary).keys()
	bases.sort()
	var counts := {"normal": 0, "uncommon": 0, "rare": 0, "epic": 0, "legendary": 0}
	var seen_ids := {}
	var total := 10000
	for i in total:
		var level := 1 + i % 50
		var item: Dictionary = gen.generate_item(str(bases[i % bases.size()]), level)
		if item.is_empty():
			failures.append("empty item at roll %d" % i)
			continue
		var rarity_id := str(item.get("rarity", "?"))
		if not counts.has(rarity_id):
			failures.append("unknown rarity '%s'" % rarity_id)
			continue
		counts[rarity_id] += 1
		var uid := str(item.get("unique_id", ""))
		if not uid.begins_with("itm_") or seen_ids.has(uid):
			failures.append("bad/duplicate id '%s'" % uid)
		seen_ids[uid] = true
		var rdef: Dictionary = rarities.get(rarity_id, {})
		var affixes: Array = item.get("affixes", [])
		var pool_size: int = gen.affix_pool(str(item.get("slot", "main_hand"))).size()
		var count_ok: bool = affixes.size() <= int(rdef.get("max_affixes", 99)) and (
			affixes.size() >= int(rdef.get("min_affixes", 0)) or pool_size <= affixes.size())
		if not count_ok:
			failures.append("%s affix count %d out of range" % [uid, affixes.size()])
		for a in affixes:
			var ad := a as Dictionary
			var def: Dictionary = affix_defs.get(str(ad.get("id", "")), {})
			if def.is_empty():
				failures.append("%s unknown affix '%s'" % [uid, ad.get("id", "")])
				continue
			var raw_est := float(ad.get("value", 0)) / ((1.0 + float(level - 1) * per_level) * float(mults.get(rarity_id, 1.0)))
			if raw_est < float(def.get("min_value", 0)) - 1.0 or raw_est > float(def.get("max_value", 0)) + 1.0:
				failures.append("%s affix %s value %s out of scaled bounds" % [uid, ad.get("id", ""), str(ad.get("value", ""))])
		var buffs: Array = item.get("buffs", [])
		if buffs.size() > int(rdef.get("bonus_buffs", 0)):
			failures.append("%s too many buffs (%d)" % [uid, buffs.size()])
		for b in buffs:
			var bd := b as Dictionary
			var def: Dictionary = effect_defs.get(str(bd.get("id", "")), {})
			if def.is_empty():
				failures.append("%s unknown buff '%s'" % [uid, bd.get("id", "")])
			elif RANKS.find(str(def.get("min_rarity", "normal"))) > RANKS.find(rarity_id):
				failures.append("%s buff %s above rarity" % [uid, bd.get("id", "")])
		if failures.size() > 20:
			break
	print("rolls=%d normal=%.1f%% uncommon=%.1f%% rare=%.1f%% epic=%.1f%% legendary=%.1f%%" % [
		total,
		100.0 * counts["normal"] / total, 100.0 * counts["uncommon"] / total,
		100.0 * counts["rare"] / total, 100.0 * counts["epic"] / total,
		100.0 * counts["legendary"] / total,
	])
	var expected := {"normal": 60.0, "uncommon": 25.0, "rare": 10.0, "epic": 4.5, "legendary": 0.5}
	for r in RANKS:
		var got := 100.0 * float(counts[r]) / float(total)
		var want: float = expected[r]
		if absf(got - want) > maxf(want * 0.35, 0.25):
			failures.append("rarity %s off: got %.2f%% want %.2f%%" % [r, got, want])
	if failures.is_empty():
		print("LOOT CHECK: PASS (%d rolls)" % total)
		return true
	printerr("LOOT CHECK: FAIL")
	for f in failures.slice(0, 20):
		printerr("  " + f)
	return false
