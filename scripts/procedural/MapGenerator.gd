extends RefCounted
## MapGenerator: deterministic procedural layouts (spec §37-39, fixme.md §63-67).
## Input (map_id, seed, player_level, difficulty) → GeneratedMap:
## rooms, L-corridors, spawn/exit/boss rooms, enemy groups, elite spots,
## loot spots. Same seed → same map (all randomness via the injected
## RNGManager after set_seed — never Array.shuffle/global RNG).
## Every layout runs validate_layout(); failures retry with a derived seed
## up to max_retries, then fail loud. generation_version records the
## algorithm — old seeds stay interpretable after generator changes.
## Rendering/spawning (MapManager) is a later stage; this outputs data.

const GENERATION_VERSION := 1


var _rng: Node
var _data: Node


func _init(rng: Node, data: Node) -> void:
	_rng = rng
	_data = data


func generate(map_id: String, seed: String, player_level: int, difficulty: String = "normal") -> Dictionary:
	var def: Dictionary = _data.get_map(map_id)
	if def.is_empty():
		push_error("MapGenerator: unknown map '%s'." % map_id)
		return {"valid": false, "reason": "unknown map"}
	var gen: Dictionary = def.get("gen", {})
	var max_retries := int(gen.get("max_retries", 10))
	var attempt := 0
	while attempt <= max_retries:
		_rng.set_seed(abs((str(map_id, ":", seed, ":", attempt)).hash()))
		var gm := _build(def, player_level, difficulty)
		var issues := validate_layout(gm, def)
		if issues.is_empty():
			gm["valid"] = true
			gm["attempt"] = attempt
			gm["seed"] = seed
			return gm
		attempt += 1
	push_error("MapGenerator: no valid layout for '%s' after %d retries." % [map_id, max_retries])
	return {"valid": false, "reason": "validation failed"}


func map_level_for(def: Dictionary, player_level: int) -> int:
	var scaling: Dictionary = def.get("scaling", {})
	var lo := int(scaling.get("player_level_offset_min", -2))
	var hi := int(scaling.get("player_level_offset_max", 2))
	var lvl: int = player_level + _rng.random_int(mini(lo, hi), maxi(lo, hi))
	return clampi(lvl, int(def.get("minimum_level", 1)), int(def.get("maximum_level", 99)))


func _build(def: Dictionary, player_level: int, difficulty: String) -> Dictionary:
	var gen: Dictionary = def.get("gen", {})
	var gw := int(gen.get("grid_width", 60))
	var gh := int(gen.get("grid_height", 60))
	var map_level := map_level_for(def, player_level)
	var want: int = _rng.random_int(int(def.get("room_count_min", 8)), int(def.get("room_count_max", 12)))
	var rooms := _place_rooms(gw, gh, want, int(gen.get("room_min_size", 5)),
		int(gen.get("room_max_size", 12)), int(gen.get("max_place_tries", 200)))
	var corridors := _connect(rooms)
	var specials := _assign_specials(rooms, def)
	var groups := _enemy_groups(rooms, specials, def, map_level, gen)
	return {
		"map_id": str(def.get("id", "?")),
		"seed": "", "player_level": player_level, "map_level": map_level,
		"difficulty": difficulty, "generation_version": GENERATION_VERSION,
		"grid": [gw, gh], "rooms": rooms, "corridors": corridors,
		"spawn": specials.get("spawn", {}), "exit": specials.get("exit", {}),
		"boss_room": specials.get("boss_room", {}),
		"enemy_groups": groups["normal"], "elite_spots": groups["elite"],
		"loot_spots": groups["loot"],
	}


func _place_rooms(gw: int, gh: int, want: int, min_size: int, max_size: int, tries: int) -> Array:
	var rooms: Array = []
	var id := 0
	for t in tries:
		if rooms.size() >= want:
			break
		var w: int = _rng.random_int(min_size, max_size)
		var h: int = _rng.random_int(min_size, max_size)
		var x: int = _rng.random_int(1, maxi(gw - w - 1, 2))
		var y: int = _rng.random_int(1, maxi(gh - h - 1, 2))
		var rect := [x - 1, y - 1, w + 2, h + 2]
		var clash := false
		for r in rooms:
			var o := r as Dictionary
			if _rects_overlap(rect, [o["x"] - 1, o["y"] - 1, o["w"] + 2, o["h"] + 2]):
				clash = true
				break
		if clash:
			continue
		rooms.append({"id": id, "x": x, "y": y, "w": w, "h": h,
			"cx": x + w / 2, "cy": y + h / 2, "kind": "normal"})
		id += 1
	return rooms


func _rects_overlap(a: Array, b: Array) -> bool:
	return int(a[0]) < int(b[0]) + int(b[2]) and int(b[0]) < int(a[0]) + int(a[2]) \
		and int(a[1]) < int(b[1]) + int(b[3]) and int(b[1]) < int(a[1]) + int(a[3])


func _connect(rooms: Array) -> Array:
	var order: Array = rooms.duplicate()
	order.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return int(a["cx"]) < int(b["cx"]))
	var corridors: Array = []
	for i in range(1, order.size()):
		corridors.append(_corridor(order[i - 1], order[i]))
	# A few extra loops so maps aren't pure chains.
	var extra: int = maxi(order.size() / 4, 0)
	for i in extra:
		var a: Dictionary = order[_rng.random_int(0, order.size() - 1)] as Dictionary
		var b: Dictionary = order[_rng.random_int(0, order.size() - 1)] as Dictionary
		if int(a["id"]) != int(b["id"]):
			corridors.append(_corridor(a, b))
	return corridors


func _corridor(a: Dictionary, b: Dictionary) -> Dictionary:
	var cells: Array = []
	var x := int(a["cx"])
	var y := int(a["cy"])
	var tx := int(b["cx"])
	var ty := int(b["cy"])
	while x != tx:
		x += 1 if tx > x else -1
		cells.append([x, y])
	while y != ty:
		y += 1 if ty > y else -1
		cells.append([x, y])
	return {"a": int(a["id"]), "b": int(b["id"]), "cells": cells}


func _assign_specials(rooms: Array, def: Dictionary) -> Dictionary:
	var out := {}
	if rooms.is_empty():
		return out
	var spawn := rooms[0] as Dictionary
	spawn["kind"] = "spawn"
	out["spawn"] = spawn
	var by_dist: Array = rooms.duplicate()
	by_dist.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _dist(a, spawn) > _dist(b, spawn))
	var has_boss := str(def.get("boss", "")) != ""
	if has_boss:
		var boss_room := by_dist[0] as Dictionary
		boss_room["kind"] = "boss"
		out["boss_room"] = boss_room
		for r in by_dist:
			var rd := r as Dictionary
			if int(rd["id"]) != int(spawn["id"]) and int(rd["id"]) != int(boss_room["id"]):
				rd["kind"] = "exit"
				out["exit"] = rd
				break
	else:
		var exit_room := by_dist[0] as Dictionary
		exit_room["kind"] = "exit"
		out["exit"] = exit_room
	var elite_ids: Array = def.get("elites", [])
	var normals: Array = []
	for r in rooms:
		if str((r as Dictionary).get("kind", "")) == "normal":
			normals.append(r)
	normals.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _dist(a, spawn) < _dist(b, spawn))
	out["elite_rooms"] = []
	for i in mini(elite_ids.size(), normals.size()):
		var room := normals[int(i * normals.size() / maxi(mini(elite_ids.size(), normals.size()), 1))] as Dictionary
		room["kind"] = "elite"
		(out["elite_rooms"] as Array).append({"room": room, "enemy_id": str(elite_ids[i])})
	return out


func _dist(a: Dictionary, b: Dictionary) -> float:
	return Vector2(float(a["cx"]) - float(b["cx"]), float(a["cy"]) - float(b["cy"])).length()


func _enemy_groups(rooms: Array, specials: Dictionary, def: Dictionary, map_level: int, gen: Dictionary) -> Dictionary:
	var normal: Array = []
	var loot: Array = []
	var variance := int(gen.get("level_variance", 1))
	var pack_min := int(gen.get("pack_min", 2))
	var pack_max := int(gen.get("pack_max", 4))
	var pool: Array = def.get("enemies", [])
	for r in rooms:
		var room := r as Dictionary
		if str(room.get("kind", "")) != "normal":
			continue
		var count: int = _rng.random_int(mini(pack_min, pack_max), maxi(pack_min, pack_max))
		var members: Array = []
		for i in count:
			members.append({
				"enemy_id": str(pool[_rng.random_int(0, pool.size() - 1)]),
				"level": maxi(map_level + _rng.random_int(-variance, variance), 1),
				"pos": _room_cell(room),
			})
		normal.append({"room": int(room["id"]), "members": members})
		loot.append({"room": int(room["id"]), "pos": [int(room["cx"]), int(room["cy"])]})
	var elite: Array = []
	for entry in (specials.get("elite_rooms", []) as Array):
		var ed := entry as Dictionary
		var room := ed["room"] as Dictionary
		elite.append({
			"room": int(room["id"]),
			"enemy_id": str(ed["enemy_id"]),
			"level": map_level + int(gen.get("elite_level_bonus", 2)),
			"pos": [int(room["cx"]), int(room["cy"])],
		})
	if specials.has("boss_room"):
		var broom := specials["boss_room"] as Dictionary
		elite.append({
			"room": int(broom["id"]),
			"enemy_id": str(def.get("boss", "")),
			"level": map_level + int(gen.get("boss_level_bonus", 3)),
			"pos": [int(broom["cx"]), int(broom["cy"])],
		})
	return {"normal": normal, "elite": elite, "loot": loot}


func _room_cell(room: Dictionary) -> Array:
	var x: int = _rng.random_int(int(room["x"]), int(room["x"]) + int(room["w"]) - 1)
	var y: int = _rng.random_int(int(room["y"]), int(room["y"]) + int(room["h"]) - 1)
	return [x, y]


## Mandatory map validation (spec §39). Returns issue strings (empty = valid):
## room-count range, no overlaps, specials present + distinct, full
## connectivity, spawns inside their rooms, boss iff the def has one.
func validate_layout(gm: Dictionary, def: Dictionary) -> Array:
	var issues: Array[String] = []
	var rooms: Array = gm.get("rooms", [])
	if rooms.size() < 3:
		issues.append("only %d rooms (need 3+)." % rooms.size())
	if rooms.size() < int(def.get("room_count_min", 0)) or rooms.size() > int(def.get("room_count_max", 999)):
		issues.append("room count %d outside def range." % rooms.size())
	for i in rooms.size():
		for j in range(i + 1, rooms.size()):
			var a := rooms[i] as Dictionary
			var b := rooms[j] as Dictionary
			if _rects_overlap([a["x"], a["y"], a["w"], a["h"]], [b["x"], b["y"], b["w"], b["h"]]):
				issues.append("rooms %d and %d overlap." % [a["id"], b["id"]])
	var spawn := gm.get("spawn", {}) as Dictionary
	var exit := gm.get("exit", {}) as Dictionary
	if spawn.is_empty() or exit.is_empty():
		issues.append("spawn/exit missing.")
	elif int(spawn.get("id", -1)) == int(exit.get("id", -2)):
		issues.append("spawn and exit share a room.")
	var want_boss := str(def.get("boss", "")) != ""
	var has_boss := not (gm.get("boss_room", {}) as Dictionary).is_empty()
	if want_boss != has_boss:
		issues.append("boss room mismatch (def '%s')." % def.get("boss", ""))
	if not _connected(rooms, gm.get("corridors", [])):
		issues.append("rooms not fully connected.")
	var by_id := {}
	for r in rooms:
		by_id[int((r as Dictionary)["id"])] = r
	for g in (gm.get("enemy_groups", []) as Array):
		for m in ((g as Dictionary).get("members", []) as Array):
			var md := m as Dictionary
			if not _cell_in_room((md.get("pos", []) as Array), by_id.get(int((g as Dictionary).get("room", -1)), {}) as Dictionary):
				issues.append("enemy spawn outside its room.")
	for s in (gm.get("elite_spots", []) as Array):
		var sd := s as Dictionary
		if not _cell_in_room((sd.get("pos", []) as Array), by_id.get(int(sd.get("room", -1)), {}) as Dictionary):
			issues.append("elite spawn outside its room.")
	return issues


func _connected(rooms: Array, corridors: Array) -> bool:
	if rooms.is_empty():
		return false
	var adj := {}
	for r in rooms:
		adj[int((r as Dictionary)["id"])] = []
	for c in corridors:
		var cd := c as Dictionary
		(adj.get(int(cd["a"]), []) as Array).append(int(cd["b"]))
		(adj.get(int(cd["b"]), []) as Array).append(int(cd["a"]))
	var seen := {}
	var stack: Array = [int((rooms[0] as Dictionary)["id"])]
	while not stack.is_empty():
		var id: int = stack.pop_back()
		if seen.has(id):
			continue
		seen[id] = true
		for n in (adj.get(id, []) as Array):
			stack.append(n)
	return seen.size() == rooms.size()


func _cell_in_room(cell: Array, room: Dictionary) -> bool:
	if room.is_empty() or cell.size() < 2:
		return false
	return int(cell[0]) >= int(room["x"]) and int(cell[0]) < int(room["x"]) + int(room["w"]) \
		and int(cell[1]) >= int(room["y"]) and int(cell[1]) < int(room["y"]) + int(room["h"])
