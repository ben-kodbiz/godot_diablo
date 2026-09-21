extends RefCounted
## EggInstance: timestamp-based egg state (fixme.md §26-27, spec §26).
## Definition (eggs.json: WHAT can hatch) vs instance (THIS egg's journey).
## States: stored → incubating → ready → hatched. Readiness derives from
## started_at + duration vs clock — NEVER a live Timer — so the browser can
## close and reopen safely. Time comes from ClockService (testable).

const STORED := "stored"
const INCUBATING := "incubating"
const READY := "ready"
const HATCHED := "hatched"

static var _counter := 0


static func make_id() -> String:
	_counter += 1
	return "egg_%d_%d" % [Time.get_ticks_msec(), _counter]


static func build(egg_type: String, duration_seconds: int, unique_id: String) -> Dictionary:
	return {
		"instance_id": unique_id,
		"egg_type": egg_type,
		"started_at": 0,
		"duration_seconds": maxi(duration_seconds, 1),
		"state": STORED,
	}


## Build from an egg definition (hatch_time_hours → seconds).
static func from_def(egg_def: Dictionary, unique_id: String) -> Dictionary:
	var hours := float(egg_def.get("hatch_time_hours", 1))
	return build(str(egg_def.get("id", "?")), int(hours * 3600.0), unique_id)


static func start_incubating(egg: Dictionary, clock: RefCounted) -> bool:
	if str(egg.get("state", "")) != STORED:
		return false
	egg["started_at"] = clock.now()
	egg["state"] = INCUBATING
	return true


static func refresh(egg: Dictionary, clock: RefCounted) -> String:
	if str(egg.get("state", "")) == INCUBATING:
		if clock.now() - int(egg.get("started_at", 0)) >= int(egg.get("duration_seconds", 0)):
			egg["state"] = READY
	return str(egg.get("state", STORED))


static func is_ready(egg: Dictionary, clock: RefCounted) -> bool:
	return refresh(egg, clock) == READY


static func seconds_left(egg: Dictionary, clock: RefCounted) -> int:
	if str(egg.get("state", "")) != INCUBATING:
		return 0
	return maxi(int(egg.get("duration_seconds", 0)) - (clock.now() - int(egg.get("started_at", 0))), 0)


## Hatch into a pet via PetGenerator. Only from READY; marks HATCHED.
static func hatch(egg: Dictionary, clock: RefCounted, petgen: RefCounted) -> Dictionary:
	if not is_ready(egg, clock):
		return {}
	var pet: Dictionary = petgen.hatch(str(egg.get("egg_type", "")))
	if pet.is_empty():
		return {}
	egg["state"] = HATCHED
	return pet
