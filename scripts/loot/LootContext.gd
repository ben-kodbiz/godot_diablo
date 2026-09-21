extends RefCounted
## LootContext: everything a loot roll depends on, in one dict (fixme.md §16).
##   player_level, map_level, enemy_level, enemy_tier, map_id, biome,
##   luck, difficulty, source_id, seed
## Generators take a context instead of a dozen loose arguments. luck flows
## into rarity rolls; a nonzero seed reproduces the exact roll via RNGManager.

static func make(params: Dictionary = {}) -> Dictionary:
	return {
		"player_level": int(params.get("player_level", 1)),
		"map_level": int(params.get("map_level", 1)),
		"enemy_level": int(params.get("enemy_level", 0)),
		"enemy_tier": str(params.get("enemy_tier", "normal")),
		"map_id": str(params.get("map_id", "")),
		"biome": str(params.get("biome", "")),
		"luck": float(params.get("luck", 0.0)),
		"difficulty": str(params.get("difficulty", "normal")),
		"source_id": str(params.get("source_id", "")),
		"seed": int(params.get("seed", 0)),
	}


static func item_level(ctx: Dictionary) -> int:
	if int(ctx.get("enemy_level", 0)) > 0:
		return int(ctx["enemy_level"])
	return maxi(int(ctx.get("map_level", 1)), 1)


static func describe(ctx: Dictionary) -> String:
	return "lvl=%d map=%s(%d) %s:%s luck=%.1f seed=%d" % [
		ctx["player_level"], ctx["map_id"], ctx["map_level"],
		ctx["enemy_tier"], ctx["source_id"], float(ctx["luck"]), ctx["seed"],
	]
