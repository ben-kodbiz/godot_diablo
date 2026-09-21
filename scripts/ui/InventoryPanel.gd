extends PanelContainer
## Inventory UI (fixme.md TASK 12): pure view over the player's
## InventoryManager + EquipmentManager. Owns NO state (§43): every button
## calls player methods, then asks Main to refresh all panels.
## Mounted always (not debug-only); toggled with the `toggle_inventory` action.

const ItemInstance = preload("res://scripts/loot/ItemInstance.gd")

const EQUIPPABLE_SLOTS := ["main_hand", "off_hand", "armor", "helmet", "accessory"]

var _player: Node
var _game: Node
var _grid: GridContainer
var _detail: Label
var _equip_btn: Button
var _selected := -1


func _ready() -> void:
	anchor_left = 0.5
	anchor_right = 0.5
	anchor_top = 0.5
	anchor_bottom = 0.5
	offset_left = -330.0
	offset_right = 330.0
	offset_top = -250.0
	offset_bottom = 250.0
	visible = false
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	add_child(box)
	var title := Label.new()
	title.text = "Inventory  (I to close)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)
	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(scroll)
	_grid = GridContainer.new()
	_grid.columns = 10
	_grid.add_theme_constant_override("h_separation", 2)
	_grid.add_theme_constant_override("v_separation", 2)
	scroll.add_child(_grid)
	_detail = Label.new()
	_detail.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_detail.custom_minimum_size = Vector2(0, 110)
	box.add_child(_detail)
	var row := HBoxContainer.new()
	box.add_child(row)
	_equip_btn = Button.new()
	_equip_btn.text = "Equip"
	_equip_btn.pressed.connect(_on_equip)
	row.add_child(_equip_btn)
	var close_btn := Button.new()
	close_btn.text = "Close"
	close_btn.pressed.connect(func() -> void: visible = false)
	row.add_child(close_btn)


func bind(player: Node, game: Node) -> void:
	_player = player
	_game = game


func open() -> void:
	visible = true
	refresh()


func refresh() -> void:
	if _player == null:
		return
	for c in _grid.get_children():
		c.queue_free()
	_selected = -1
	_detail.text = "Select an item."
	_equip_btn.disabled = true
	var inv = _player.inventory
	for i in inv.capacity():
		var item: Dictionary = inv.get_at(i)
		var btn := Button.new()
		btn.custom_minimum_size = Vector2(58, 30)
		btn.add_theme_font_size_override("font_size", 11)
		if item.is_empty():
			btn.text = "·"
			btn.disabled = true
		else:
			btn.text = str(item.get("name", "?")).left(9)
			btn.tooltip_text = ItemInstance.tooltip(item)
			btn.add_theme_color_override("font_color",
				ItemInstance.rarity_color(str(item.get("rarity", "normal"))))
			var slot: int = i
			btn.pressed.connect(func() -> void: _select(slot))
		_grid.add_child(btn)


func _select(slot: int) -> void:
	_selected = slot
	var item: Dictionary = _player.inventory.get_at(slot)
	_detail.text = ItemInstance.tooltip(item)
	_equip_btn.disabled = str(item.get("slot", "")) not in EQUIPPABLE_SLOTS


func _on_equip() -> void:
	if _selected < 0:
		return
	var item: Dictionary = _player.inventory.get_at(_selected)
	var res: Dictionary = _player.equip_item(str(item.get("unique_id", "")))
	if not bool(res.get("ok", false)):
		_detail.text = "Cannot equip: %s" % res.get("reason", "?")
	_game.refresh_ui()
