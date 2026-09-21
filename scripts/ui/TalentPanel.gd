extends PanelContainer
## Talent UI: pure view over the player's TalentManager (§43). View any of
## the 4 trees; spending is allowed only in the ACTIVE tree (equipped weapon).
## Toggled with the `toggle_talents` action.

const FAMILIES := ["bow", "staff", "sword", "shield"]

var _player: Node
var _game: Node
var _family_opt: OptionButton
var _points: Label
var _list: VBoxContainer


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -280.0
	offset_right = 280.0
	offset_top = -250.0
	offset_bottom = 250.0
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Talents  (T to close)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var top := HBoxContainer.new()
	box.add_child(top)
	_family_opt = OptionButton.new()
	_family_opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	for f in FAMILIES:
		_family_opt.add_item(f.capitalize())
	_family_opt.item_selected.connect(func(_i: int) -> void: refresh())
	top.add_child(_family_opt)
	_points = Label.new()
	_points.add_theme_font_size_override("font_size", 14)
	top.add_child(_points)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_list = VBoxContainer.new()
	_list.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	scroll.add_child(_list)


func bind(player: Node, game: Node) -> void:
	_player = player
	_game = game


func open() -> void:
	visible = true
	refresh()


func current_family() -> String:
	return FAMILIES[_family_opt.selected]


func refresh() -> void:
	if _player == null:
		return
	for c in _list.get_children():
		c.queue_free()
	var level: int = _player.stats.level
	var active := str(_player.talents.get_active_family())
	_points.text = "%d points (active: %s)" % [_player.talents.spendable_points(level), active if active != "" else "none"]
	for v in _player.talents.family_view(current_family(), level):
		var vd := v as Dictionary
		var row := HBoxContainer.new()
		_list.add_child(row)
		var label := Label.new()
		label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		label.add_theme_font_size_override("font_size", 13)
		label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		label.text = "%s  %d/%d\n%s" % [vd["name"], vd["rank"], vd["max_rank"], _effects_text(str(vd["id"]))]
		row.add_child(label)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(96, 0)
		if int(vd["rank"]) == 0:
			btn.text = "Unlock"
			btn.disabled = not bool(vd["can_unlock"])
		elif int(vd["rank"]) < int(vd["max_rank"]):
			btn.text = "+ Rank"
			btn.disabled = not bool(vd["can_upgrade"])
		else:
			btn.text = "MAX"
			btn.disabled = true
		if not bool(vd.get("active", true)) and current_family() != active:
			btn.disabled = true
		var tid := str(vd["id"])
		btn.pressed.connect(func() -> void: _on_spend(tid))
		row.add_child(btn)


func _effects_text(talent_id: String) -> String:
	var def: Dictionary = _player.talents.get_def(talent_id)
	var parts: Array[String] = []
	for fx in (def.get("effects", []) as Array):
		var fd := fx as Dictionary
		var v := "+%s%s %s/rank" % [fd.get("value_per_rank", 0),
			"%" if bool(fd.get("is_percent", false)) else "",
			str(fd.get("stat", "?")).capitalize()]
		parts.append(v)
	return ", ".join(parts)


func _on_spend(talent_id: String) -> void:
	var level: int = _player.stats.level
	if _player.talents.get_rank(talent_id) == 0:
		_player.talents.unlock(talent_id, level)
	else:
		_player.talents.upgrade(talent_id, level)
	_player.refresh_stats()
	_game.refresh_ui()
