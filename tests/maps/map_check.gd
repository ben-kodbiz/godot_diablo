extends SceneTree
## Headless map check (procedural generation acceptance, spec §39).
## Usage: --script res://tests/maps/map_check.gd
## Covers: same seed → same map, different seed → different map, 30 seeds ×
## 3 maps all valid (counts, specials, connectivity, in-room spawns),
## enemy/boss level bands, seed + version recording.
## Prints MAP CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const RNGScript = preload("res://scripts/core/RNGManager.gd")
const MapGenScript = preload("res://scripts/procedural/MapGenerator.gd")


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
	var rng: Node = RNGScript.new()
	var gen: RefCounted = MapGenScript.new(rng, data)
	var maps: Array = ["forest_01", "forest_02", "forest_03"]

	# 1. Determinism: same context twice → identical layout.
	var a: Dictionary = gen.generate("forest_01", "test-seed", 5)
	var b: Dictionary = gen.generate("forest_01", "test-seed", 5)
	if not bool(a.get("valid", false)) or not bool(b.get("valid", false)):
		failures.append("seeded map invalid")
	elif JSON.stringify(a["rooms"]) != JSON.stringify(b["rooms"]) \
			or JSON.stringify(a["corridors"]) != JSON.stringify(b["corridors"]) \
			or JSON.stringify(a["enemy_groups"]) != JSON.stringify(b["enemy_groups"]):
		failures.append("same seed gave different maps")
	var c: Dictionary = gen.generate("forest_01", "other-seed", 5)
	if JSON.stringify(a["rooms"]) == JSON.stringify(c["rooms"]):
		failures.append("different seeds gave identical maps")
	if str(a.get("seed", "")) != "test-seed":
		failures.append("seed not recorded")
	if int(a.get("generation_version", 0)) != 1:
		failures.append("generation version not recorded")

	# 2. Sweep: 30 seeds × 3 maps, all valid with sane bands.
	for map_id in maps:
		var def: Dictionary = data.get_map(str(map_id))
		for i in 30:
			var gm: Dictionary = gen.generate(str(map_id), "sweep-%d" % i, 3 + i % 20)
			if not bool(gm.get("valid", false)):
				failures.append("%s seed %d invalid" % [map_id, i])
				continue
			var ml: int = gm["map_level"]
			if ml < int(def["minimum_level"]) or ml > int(def["maximum_level"]):
				failures.append("%s map_level %d outside def range" % [map_id, ml])
			for g in (gm["enemy_groups"] as Array):
				for m in ((g as Dictionary)["members"] as Array):
					var lvl := int((m as Dictionary)["level"])
					if lvl < maxi(ml - 1, 1) or lvl > ml + 1:
						failures.append("%s mob lvl %d outside band (map %d)" % [map_id, lvl, ml])
			for s in (gm["elite_spots"] as Array):
				var sd := s as Dictionary
				var want_boss := str(def.get("boss", "")) != "" and str(sd["enemy_id"]) == str(def["boss"])
				var want := ml + (3 if want_boss else 2)
				if int(sd["level"]) != want:
					failures.append("%s %s lvl %d, want %d" % [map_id, sd["enemy_id"], sd["level"], want])
			if (str(def.get("boss", "")) != "") != (not (gm["boss_room"] as Dictionary).is_empty()):
				failures.append("%s boss room mismatch" % map_id)

	rng.free()
	data.free()
	if failures.is_empty():
		print("MAP CHECK: PASS (3 maps x 30 seeds)")
		quit(0)
	else:
		printerr("MAP CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
