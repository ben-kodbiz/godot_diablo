extends Node
## Central deterministic RNG. All loot/map/pet rolls must go through here
## so generation is reproducible and the Loot/Pet simulators reuse
## production code. See todoagent.md #56-59.

var _rng: RandomNumberGenerator = RandomNumberGenerator.new()


func _ready() -> void:
	_rng.randomize()


func set_seed(value: int) -> void:
	_rng.seed = value


func get_seed() -> int:
	return _rng.seed


func random_int(min_value: int, max_value: int) -> int:
	return _rng.randi_range(min_value, max_value)


func random_float(min_value: float, max_value: float) -> float:
	return _rng.randf_range(min_value, max_value)


## Returns an index into `weights` proportional to weight. Returns -1 if
## total weight is <= 0.
func weighted_choice(weights: PackedFloat32Array) -> int:
	var total := 0.0
	for w in weights:
		total += w
	if total <= 0.0:
		return -1
	var roll := _rng.randf() * total
	var acc := 0.0
	for i in weights.size():
		acc += weights[i]
		if roll < acc:
			return i
	return weights.size() - 1


## Deterministic 0.0-1.0 float derived from a seed + salt string, without
## disturbing the main stream. Used for map gen and tests.
func seeded_random(seed_value: int, salt: String = "") -> float:
	var digest := str(seed_value, ":", salt).hash()
	var local := RandomNumberGenerator.new()
	local.seed = digest
	return local.randf()
