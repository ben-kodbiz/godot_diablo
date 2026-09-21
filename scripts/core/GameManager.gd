extends Node
## Bootstrap / orchestration singleton. Owns nothing itself; verifies the
## foundation (features + data) at startup and reports a one-line status
## the headless check greps for. Gameplay state lives in stage systems,
## not here. See todoagent.md #2.

var _ready_ok := false


func _ready() -> void:
	var features: Dictionary = FeatureManager.all_flags()
	var data_ok := not DataManager.has_errors()
	_ready_ok = data_ok
	if data_ok:
		print("BOOT OK: features=%s weapons=%d equipment=%d rarities=%d affixes=%d effects=%d stats=%d pets=%d species=%d eggs=%d enemies=%d maps=%d" % [
			features,
			(DataManager.get_table("weapons") as Dictionary).size(),
			(DataManager.get_table("equipment") as Dictionary).size(),
			(DataManager.get_table("rarities") as Dictionary).size(),
			(DataManager.get_table("affixes") as Dictionary).size(),
			(DataManager.get_table("effects") as Dictionary).size(),
			(DataManager.get_table("stats") as Dictionary).size(),
			(DataManager.get_table("pets") as Dictionary).size(),
			(DataManager.get_table("species") as Dictionary).size(),
			(DataManager.get_table("eggs") as Dictionary).size(),
			(DataManager.get_table("enemies") as Dictionary).size(),
			(DataManager.get_table("maps") as Dictionary).size(),
		])
	else:
		push_error("BOOT FAILED: data errors:\n  " + "\n  ".join(DataManager.get_errors()))


func is_ready_ok() -> bool:
	return _ready_ok
