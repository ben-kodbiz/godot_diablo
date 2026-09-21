extends RefCounted
## DamageCalculator: the SINGLE place damage is computed (fixme.md §71).
## Pure static math — no scenes, no UI, no RNG calls, no JSON access — so
## combat tests run headless. Balance arrives as a parameter (callers pass
## DataManager's combat_balance table); randomness enters only through
## caller-supplied rolls (crit_roll, variance_roll ∈ 0..1, drawn from
## RNGManager by the caller), keeping every result exactly reproducible.
##
## Formula (spec §42, constants in data/balance/combat.json):
##   raw = base × skill × weapon × buff
##   crit? raw ×= (crit_base + crit_damage_pct / 100)
##   raw ×= (1 − variance + 2 × variance × variance_roll)
##   amount = max(min_damage, round(raw × K / (K + armor)))


static func calculate(request: Dictionary, balance: Dictionary) -> Dictionary:
	var bal := balance
	var raw := float(request.get("base_damage", 0))
	raw *= float(request.get("skill_mult", 1.0))
	raw *= float(request.get("weapon_mult", 1.0))
	raw *= float(request.get("buff_mult", 1.0))
	var critical := float(request.get("crit_roll", 1.0)) * 100.0 < float(request.get("crit_chance_pct", 0.0))
	if critical:
		var crit_base := float((bal.get("crit", {}) as Dictionary).get("base_mult", 2.0))
		raw *= crit_base + float(request.get("crit_damage_pct", 0.0)) / 100.0
	var variance := float((bal.get("variance", {}) as Dictionary).get("range", 0.1))
	raw *= 1.0 - variance + 2.0 * variance * clampf(float(request.get("variance_roll", 0.5)), 0.0, 1.0)
	var armor := maxf(float(request.get("armor", 0.0)), 0.0)
	var constant := float((bal.get("armor", {}) as Dictionary).get("constant", 100.0))
	var mitigated := raw * constant / (constant + armor)
	var amount: int = maxi(int(round(mitigated)), int((bal.get("limits", {}) as Dictionary).get("min_damage", 1)))
	return {
		"amount": amount,
		"raw": snappedf(raw, 0.01),
		"damage_type": str(request.get("damage_type", "physical")),
		"critical": critical,
		"blocked": false,
		"absorbed": false,
		"source": str(request.get("source", "")),
		"target": str(request.get("target", "")),
	}
