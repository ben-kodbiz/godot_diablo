extends PanelContainer
## Equipment UI: pure view over the player's EquipmentManager (§43).
## Rows per slot, Unequip returns the item to inventory. Main toggles it
## together with Inventory on the `toggle_inventory` action.

const EquipmentManager = preload("res://scripts/equipment/EquipmentManager.gd")

var _player: Node
var _game: Node
var _rows: VBoxContainer
var _unequip_btn: Button
var _selected := ""


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
	box.add_theme_constant_override("separation", 4)
	add_child(box)
	var title := Label.new()
	title.text = "Equipment"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	_rows = VBoxContainer.new()
	box.add_child(_rows)
	_unequip_btn = Button.new()
	_unequip_btn.text = "Unequip"
	_unequip_btn.pressed.connect(_on_unequip)
	box.add_child(_unequip_btn)


func bind(player: Node, game: Node) -> void:
	_player = player
	_game = game


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	if _player == null:
		return
	for c in _rows.get_children():
		c.queue_free()
	_selected = ""
	_unequip_btn.disabled = true
	for slot in EquipmentManager.SLOTS:
		var item: Dictionary = _player.equipment.get_equipped(slot)
		var row := HBoxContainer.new()
		_rows.add_child(row)
		var label := Label.new()
		label.text = str(slot).capitalize()
		label.custom_minimum_size = Vector2(110, 0)
		label.add_theme_font_size_override("font_size", 12)
		row.add_child(label)
		var btn := Button.new()
		btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		btn.add_theme_font_size_override("font_size", 12)
		if item.is_empty():
			btn.text = "— empty —"
			btn.disabled = true
		else:
			btn.text = str(item.get("name", "?"))
			btn.tooltip_text = "Level %d %s" % [int(item.get("item_level", 1)), item.get("rarity", "")]
			var s: String = slot
			btn.pressed.connect(func() -> void: _select(s))
		row.add_child(btn)


func _select(slot: String) -> void:
	_selected = slot
	_unequip_btn.disabled = false
	_unequip_btn.text = "Unequip (%s)" % str(slot).capitalize()


func _on_unequip() -> void:
	if _selected == "":
		return
	var res: Dictionary = _player.unequip_slot(_selected)
	if not bool(res.get("ok", false)):
		_unequip_btn.text = "Full!"
	_game.refresh_ui()
