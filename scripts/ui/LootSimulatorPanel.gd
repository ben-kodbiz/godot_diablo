extends PanelContainer
## Dev-only loot simulator (spec #58). Pick a base item + rarity + level,
## roll with the production LootGenerator, inspect the result.
## Instantiated by Main in debug builds only — never in release.

const LootGen = preload("res://scripts/loot/LootGenerator.gd")
const ItemInstance = preload("res://scripts/loot/ItemInstance.gd")

var _base_opt: OptionButton
var _rarity_opt: OptionButton
var _level_spin: SpinBox
var _results: RichTextLabel
var _gen: RefCounted


func _ready() -> void:
	_gen = LootGen.new(RNGManager, DataManager)
	anchor_left = 1.0
	anchor_right = 1.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = -416.0
	offset_right = -16.0
	offset_top = 16.0
	offset_bottom = -16.0

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Loot Simulator (dev)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	_base_opt = _labeled_option(box, "Base:")
	var equipment: Dictionary = DataManager.get_table("equipment")
	var base_ids: Array = equipment.keys()
	base_ids.sort()
	for i in base_ids.size():
		var def := equipment[base_ids[i]] as Dictionary
		_base_opt.add_item(str(def.get("name", base_ids[i])), i)
		_base_opt.set_item_metadata(i, str(base_ids[i]))

	_rarity_opt = _labeled_option(box, "Rarity:")
	_rarity_opt.add_item("Random (weighted)", 0)
	var order := ["normal", "uncommon", "rare", "epic", "legendary"]
	for i in order.size():
		_rarity_opt.add_item(ItemInstance.rarity_label(order[i]), i + 1)
		_rarity_opt.set_item_metadata(i + 1, order[i])

	var level_row := HBoxContainer.new()
	box.add_child(level_row)
	var level_label := Label.new()
	level_label.text = "Level:"
	level_label.custom_minimum_size = Vector2(64, 0)
	level_row.add_child(level_label)
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 100
	_level_spin.value = 10
	_level_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(_level_spin)

	var btn_row := HBoxContainer.new()
	box.add_child(btn_row)
	var roll := Button.new()
	roll.text = "Roll item"
	roll.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	roll.pressed.connect(_on_roll)
	btn_row.add_child(roll)
	var clear := Button.new()
	clear.text = "Clear"
	clear.pressed.connect(func() -> void: _results.clear())
	btn_row.add_child(clear)

	_results = RichTextLabel.new()
	_results.bbcode_enabled = true
	_results.scroll_following = true
	_results.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(_results)


func _labeled_option(parent: Control, text: String) -> OptionButton:
	var row := HBoxContainer.new()
	parent.add_child(row)
	var label := Label.new()
	label.text = text
	label.custom_minimum_size = Vector2(64, 0)
	row.add_child(label)
	var opt := OptionButton.new()
	opt.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(opt)
	return opt


func _on_roll() -> void:
	var base_id := str(_base_opt.get_item_metadata(_base_opt.selected))
	var rarity_id := ""
	if _rarity_opt.selected > 0:
		rarity_id = str(_rarity_opt.get_item_metadata(_rarity_opt.selected))
	var item: Dictionary = _gen.generate_item(base_id, int(_level_spin.value), rarity_id)
	if item.is_empty():
		return
	var hex: String = ItemInstance.rarity_color(str(item.get("rarity", ""))).to_html(false)
	_results.append_text("[color=#%s][b]%s[/b][/color]\n" % [hex, str(item.get("name", "?"))])
	for line in ItemInstance.tooltip(item).split("\n").slice(1):
		_results.append_text(line + "\n")
	_results.append_text("\n")
