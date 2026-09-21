extends SceneTree
## Headless pet collection + egg timer check (fixme.md §25-28).
## Usage: --script res://tests/pets/collection_check.gd
## Covers: collection add/duplicate/active/counts/discovery, modifiers,
## serialize round-trip + corrupt, egg lifecycle on a test clock
## (stored → incubating → ready → hatched), premature hatch refusal.
## Prints COLLECTION CHECK: PASS on success.

const DataScript = preload("res://scripts/core/DataManager.gd")
const RNGScript = preload("res://scripts/core/RNGManager.gd")
const PetGenScript = preload("res://scripts/pets/PetGenerator.gd")
const CollectionScript = preload("res://scripts/pets/PetCollectionManager.gd")
const EggScript = preload("res://scripts/pets/EggInstance.gd")
const ClockScript = preload("res://scripts/core/ClockService.gd")


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
	rng.set_seed(41)
	var petgen: RefCounted = PetGenScript.new(rng, data)
	var col: RefCounted = CollectionScript.new()

	# 1. Collection basics.
	var wolf: Dictionary = petgen.hatch("forest_egg")
	if not col.add_pet(wolf):
		failures.append("add failed")
	if col.add_pet(wolf):
		failures.append("duplicate add accepted")
	if not col.owns(str(wolf["unique_id"])):
		failures.append("owns() missed")
	if col.count_total() != 1 or col.count_species() != 1:
		failures.append("counts wrong")
	if not col.set_active(str(wolf["unique_id"])):
		failures.append("set_active failed")
	if col.set_active("pet_missing"):
		failures.append("set_active unknown accepted")
	var mods: Array = col.active_modifiers()
	if mods.is_empty():
		failures.append("no active modifiers")
	col.clear_active()
	if not col.active_modifiers().is_empty():
		failures.append("modifiers after clear")
	col.set_active(str(wolf["unique_id"]))
	var owl: Dictionary = petgen.roll_wild("gloom_owl", "rare", "mossy_egg")
	col.add_pet(owl)
	if col.count_rarity("rare") < 1:
		failures.append("rarity count wrong")
	if col.discovered().size() < 2:
		failures.append("discovery wrong: %s" % col.discovered())
	var gone: Dictionary = col.remove_pet(str(wolf["unique_id"]))
	if gone.is_empty() or col.owns(str(wolf["unique_id"])):
		failures.append("remove failed")
	if not col.get_active().is_empty():
		failures.append("active not cleared on remove")

	# 2. Save round-trip + corrupt rejection.
	var snap: Dictionary = col.serialize()
	var col2: RefCounted = CollectionScript.new()
	if not col2.deserialize(snap):
		failures.append("round-trip failed")
	elif col2.count_total() != 1 or not col2.owns(str(owl["unique_id"])):
		failures.append("round-trip lost pets")
	if col2.deserialize({"pets": [{"unique_id": "a"}, {"unique_id": "a"}]}):
		failures.append("duplicate-uid save accepted")
	if col2.deserialize({"pets": [], "active_uid": "pet_ghost"}):
		failures.append("ghost-active save accepted")

	# 3. Egg lifecycle on a test clock (forest_egg = 2h = 7200s).
	var clock: RefCounted = ClockScript.new()
	clock.use_test_clock(1_000_000)
	var eggdef: Dictionary = data.get_egg("forest_egg")
	var egg := EggScript.from_def(eggdef, EggScript.make_id())
	if str(egg["state"]) != EggScript.STORED:
		failures.append("egg not stored initially")
	if not EggScript.hatch(egg, clock, petgen).is_empty():
		failures.append("hatch from stored accepted")
	if not EggScript.start_incubating(egg, clock):
		failures.append("start rejected")
	if EggScript.start_incubating(egg, clock):
		failures.append("double start accepted")
	clock.advance(7199)
	if EggScript.is_ready(egg, clock):
		failures.append("ready 1s early")
	if EggScript.seconds_left(egg, clock) != 1:
		failures.append("seconds_left wrong")
	clock.advance(1)
	if not EggScript.is_ready(egg, clock):
		failures.append("not ready at duration")
	var pet: Dictionary = EggScript.hatch(egg, clock, petgen)
	if pet.is_empty() or str(pet.get("egg_source", "")) != "forest_egg":
		failures.append("hatch failed: %s" % pet)
	if str(egg["state"]) != EggScript.HATCHED:
		failures.append("egg not marked hatched")
	if not EggScript.hatch(egg, clock, petgen).is_empty():
		failures.append("double hatch accepted")

	rng.free()
	data.free()
	if failures.is_empty():
		print("COLLECTION CHECK: PASS")
		quit(0)
	else:
		printerr("COLLECTION CHECK: FAIL")
		for f in failures.slice(0, 20):
			printerr("  " + f)
		quit(1)
