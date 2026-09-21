extends RefCounted
## StatCalculator: the SINGLE place final stats are computed (spec #29-30).
##   final = (base + per_level*(level-1) + flat contributors)
##           × (1 + percent contributors / 100)      [per stat]
## Pure static math — no autoloads, no tree — so it unit-tests headless.
## Contributors are generic {stat, value, is_percent} dicts; equipment,
## talents, pets, and buffs all feed the same pipe (set via CharacterStats).

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
