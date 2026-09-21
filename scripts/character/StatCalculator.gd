extends RefCounted
## StatCalculator: the SINGLE place final stats are computed (spec #29-30).
##   final = (base + per_level*(level-1) + flat contributors)
##           × (1 + percent contributors / 100)      [per stat]
## Pure static math — no autoloads, no tree — so it unit-tests headless.
## Contributors are StatModifier dicts (source_type/source_id stamped);
## equipment, talents, pets, and buffs all feed the same pipe
## (set via CharacterStats). calculate_breakdown() exposes the same math
## per-source for the stat-breakdown debug view — its finals ALWAYS equal
## calculate() finals.

const StatModifier = preload("res://scripts/core/StatModifier.gd")

static func calculate(
	base: Dictionary, level: int, per_level: Dictionary, contributors: Array
) -> Dictionary:
	var flat := {}
	for stat in base.keys():
		flat[stat] = float(base.get(stat, 0)) + float(per_level.get(stat, 0)) * float(maxi(level - 1, 0))
	var pct := {}
	for mod in contributors:
		var md := mod as Dictionary
		var stat := str(md.get("stat", "?"))
		var value := float(md.get("value", 0))
		if bool(md.get("is_percent", false)):
			pct[stat] = float(pct.get(stat, 0)) + value
		else:
			flat[stat] = float(flat.get(stat, 0)) + value
	var final := {}
	for stat in flat.keys():
		final[stat] = float(flat[stat]) * (1.0 + float(pct.get(stat, 0)) / 100.0)
	for stat in pct.keys():
		if not final.has(stat):
			final[stat] = 0.0 * (1.0 + float(pct[stat]) / 100.0)
	return final


## XP needed to go FROM `level` TO `level+1`.
static func xp_for_level(level: int, curve_base: float, curve_growth: float) -> int:
	return int(round(curve_base * pow(curve_growth, float(maxi(level - 1, 0)))))


## Same math as calculate(), attributed per stat:
## {stat: {base, level, flats: {source_type: x}, pct: {source_type: y},
##          flat_total, pct_total, final}}
static func calculate_breakdown(
	base: Dictionary, level: int, per_level: Dictionary, contributors: Array
) -> Dictionary:
	var out := {}
	for stat in base.keys():
		out[stat] = {
			"base": float(base.get(stat, 0)),
			"level": float(per_level.get(stat, 0)) * float(maxi(level - 1, 0)),
			"flats": {}, "pct": {},
			"flat_total": 0.0, "pct_total": 0.0, "final": 0.0,
		}
	for mod in contributors:
		var md := mod as Dictionary
		var stat := str(md.get("stat", "?"))
		if not out.has(stat):
			out[stat] = {
				"base": 0.0, "level": 0.0,
				"flats": {}, "pct": {},
				"flat_total": 0.0, "pct_total": 0.0, "final": 0.0,
			}
		var row := out[stat] as Dictionary
		var source := StatModifier.source_of(md)
		var bucket := "pct" if bool(md.get("is_percent", false)) else "flats"
		var group := row[bucket] as Dictionary
		group[source] = float(group.get(source, 0.0)) + float(md.get("value", 0))
	for stat in out.keys():
		var row := out[stat] as Dictionary
		var flat_total := float(row["base"]) + float(row["level"])
		for source in (row["flats"] as Dictionary).keys():
			flat_total += float((row["flats"] as Dictionary)[source])
		var pct_total := 0.0
		for source in (row["pct"] as Dictionary).keys():
			pct_total += float((row["pct"] as Dictionary)[source])
		row["flat_total"] = flat_total
		row["pct_total"] = pct_total
		row["final"] = flat_total * (1.0 + pct_total / 100.0)
	return out


## Dev-display text for one stat (the BASE/Lvl/Equip/… debug view).
static func format_breakdown(breakdown: Dictionary, stat: String) -> String:
	if not breakdown.has(stat):
		return "%s: no data" % stat
	var row := breakdown[stat] as Dictionary
	var lines: Array[String] = [stat.to_upper()]
	lines.append("Base             %s" % _num(row["base"]))
	lines.append("Level            %s" % _num(row["level"]))
	var order := ["equipment", "talent", "pet", "buff", "debuff", "temporary", "unknown"]
	var extra_sources: Array = []
	for other in (row["flats"] as Dictionary).keys():
		if str(other) not in order:
			extra_sources.append(str(other))
	for other in (row["pct"] as Dictionary).keys():
		if str(other) not in order and str(other) not in extra_sources:
			extra_sources.append(str(other))
	for source in order + extra_sources:
		var f := float((row["flats"] as Dictionary).get(source, 0.0))
		var p := float((row["pct"] as Dictionary).get(source, 0.0))
		if f == 0.0 and p == 0.0:
			continue
		lines.append(str(source).capitalize().rpad(16) + _num(f))
		if p != 0.0:
			lines.append((str(source).capitalize() + " %").rpad(16) + _num(p) + "%")
	lines.append("--------------------")
	lines.append("Final            %s" % _num(row["final"]))
	return "\n".join(lines)


static func _num(v: Variant) -> String:
	var f := float(v)
	if f == floor(f):
		return str(int(f))
	return str(snappedf(f, 0.01))
