extends RefCounted
## ClockService: time abstraction (fixme.md §28). Production code NEVER calls
## Time directly — it asks the clock. Production clock reads system time;
## test clock is manual, so tests simulate +1h/+24h instantly.
## Egg hatching, daily resets, and buff durations all share this.

var _test_now := -1


func now() -> int:
	if _test_now >= 0:
		return _test_now
	return int(Time.get_unix_time_from_system())


func is_test_clock() -> bool:
	return _test_now >= 0


func use_test_clock(start: int) -> void:
	_test_now = maxi(start, 0)


func use_system_clock() -> void:
	_test_now = -1


func advance(seconds: int) -> void:
	if _test_now >= 0:
		_test_now = maxi(_test_now + seconds, 0)
