extends Node2D
## Stage 0 entry point: bootstrap proof. Shows a placeholder world so the
## project (and later the browser export) visibly runs before any gameplay
## exists. Gameplay code must NOT live here — see stage managers.

const LootSimulatorPanel = preload("res://scripts/ui/LootSimulatorPanel.gd")
const PetSimulatorPanel = preload("res://scripts/ui/PetSimulatorPanel.gd")

var _info: Label


func _ready() -> void:
	var bg := ColorRect.new()
	bg.color = Color(0.07, 0.09, 0.13)
	bg.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(bg)

	var title := Label.new()
	title.text = "LootARPGPet — foundation boot"
	title.position = Vector2(440, 24)
	title.add_theme_font_size_override("font_size", 28)
	add_child(title)

	_info = Label.new()
	_info.position = Vector2(440, 72)
	_info.add_theme_font_size_override("font_size", 16)
	add_child(_info)

	var hint := Label.new()
	hint.text = "Move: WASD / arrows · Attack: mouse / space · I/C/T/P: panels (stages 4-8)"
	hint.position = Vector2(440, 700 - 40)
	hint.add_theme_font_size_override("font_size", 14)
	add_child(hint)

	if OS.is_debug_build():
		add_child(PetSimulatorPanel.new())
		add_child(LootSimulatorPanel.new())

	_refresh_status()


func _process(_delta: float) -> void:
	# Poll input through InputMap only (never hard-coded keys here either).
	var dir := Input.get_vector("move_left", "move_right", "move_up", "move_down")
	if dir != Vector2.ZERO:
		_refresh_status(dir)


func _refresh_status(dir: Vector2 = Vector2.ZERO) -> void:
	var weapons: Dictionary = DataManager.get_table("weapons")
	var names: Array = weapons.keys()
	names.sort()
	var player_text := "player: missing"
	if has_node("Player"):
		var p := get_node("Player")
		player_text = "player: lvl %d · hp %d/%d · pos %s" % [
			p.stats.level, p.stats.current_hp, p.stats.max_hp(), Vector2i(p.position)
		]
	_info.text = "DataManager errors: %d · weapons: %s\n%s\nInput vector: %s" % [
		DataManager.get_errors().size(), ", ".join(names), player_text, dir
	]
