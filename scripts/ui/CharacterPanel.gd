extends PanelContainer
## Character UI: level/XP/HP readout plus the StatCalculator breakdown view
## (BASE/Lvl/Equip/Talent/Pet/Buff/Final). Read-only (§43). Toggled with the
## `toggle_character` action.

const StatCalculator = preload("res://scripts/character/StatCalculator.gd")

var _player: Node
var _summary: Label
var _breakdown: Label


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -560.0
	offset_right = -340.0
	offset_top = -250.0
	offset_bottom = 250.0
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Character  (C to close)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	_summary = Label.new()
	_summary.add_theme_font_size_override("font_size", 14)
	box.add_child(_summary)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_breakdown = Label.new()
	_breakdown.add_theme_font_size_override("font_size", 12)
	scroll.add_child(_breakdown)


func bind(player: Node, _game: Node) -> void:
	_player = player


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	if _player == null:
		return
	var stats = _player.stats
	_summary.text = "Level %d · XP %d/%d · HP %d/%d · Mana %d/%d" % [
		stats.level, stats.xp, stats.xp_next,
		stats.current_hp, stats.max_hp(), stats.current_mana, stats.max_mana()]
	var bd: Dictionary = stats.get_breakdown()
	var parts: Array[String] = []
	for stat in ["str", "dex", "int", "vit", "luck"]:
		parts.append(StatCalculator.format_breakdown(bd, stat))
	_breakdown.text = "\n\n".join(parts)
