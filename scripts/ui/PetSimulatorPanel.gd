extends PanelContainer
## Dev-only pet simulator (spec #59). Pick an egg, hatch with the production
## PetGenerator, and test egg-drop rates per killer tier / map level.
## Instantiated by Main in debug builds only — never in release.

const PetGen = preload("res://scripts/pets/PetGenerator.gd")
const PetInstance = preload("res://scripts/pets/PetInstance.gd")

var _egg_opt: OptionButton
var _tier_opt: OptionButton
var _level_spin: SpinBox
var _results: RichTextLabel
var _gen: RefCounted


func _ready() -> void:
	_gen = PetGen.new(RNGManager, DataManager)
	anchor_left = 0.0
	anchor_right = 0.0
	anchor_top = 0.0
	anchor_bottom = 1.0
	offset_left = 16.0
	offset_right = 416.0
	offset_top = 16.0
	offset_bottom = -16.0

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	add_child(box)

	var title := Label.new()
	title.text = "Pet Simulator (dev)"
	title.add_theme_font_size_override("font_size", 18)
	box.add_child(title)

	_egg_opt = _labeled_option(box, "Egg:")
	var eggs: Dictionary = DataManager.get_table("eggs")
	var egg_ids: Array = eggs.keys()
	egg_ids.sort()
	for i in egg_ids.size():
		var def := eggs[egg_ids[i]] as Dictionary
		_egg_opt.add_item("%s (%dh)" % [str(def.get("name", egg_ids[i])), int(def.get("hatch_time_hours", 0))], i)
		_egg_opt.set_item_metadata(i, str(egg_ids[i]))

	_tier_opt = _labeled_option(box, "Killer:")
	var tiers := ["normal", "elite", "boss"]
	for i in tiers.size():
		_tier_opt.add_item(tiers[i], i)
		_tier_opt.set_item_metadata(i, tiers[i])
	_tier_opt.selected = 1

	var level_row := HBoxContainer.new()
	box.add_child(level_row)
	var level_label := Label.new()
	level_label.text = "Map lvl:"
	level_label.custom_minimum_size = Vector2(64, 0)
	level_row.add_child(level_label)
	_level_spin = SpinBox.new()
	_level_spin.min_value = 1
	_level_spin.max_value = 100
	_level_spin.value = 15
	_level_spin.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	level_row.add_child(_level_spin)

	var hatch_btn := Button.new()
	hatch_btn.text = "Hatch egg"
	hatch_btn.pressed.connect(_on_hatch)
	box.add_child(hatch_btn)
	var drops_btn := Button.new()
	drops_btn.text = "Test drops (100 kills)"
	drops_btn.pressed.connect(_on_test_drops)
	box.add_child(drops_btn)

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


func _on_hatch() -> void:
	var egg_id := str(_egg_opt.get_item_metadata(_egg_opt.selected))
	var pet: Dictionary = _gen.hatch(egg_id)
	if pet.is_empty():
		return
	var hex: String = PetInstance.rarity_color(str(pet.get("rarity", ""))).to_html(false)
	_results.append_text("[color=#%s][b]%s[/b][/color]\n" % [hex, str(pet.get("name", "?"))])
	for line in PetInstance.tooltip(pet).split("\n").slice(1):
		_results.append_text(line + "\n")
	_results.append_text("\n")


func _on_test_drops() -> void:
	var tier := str(_tier_opt.get_item_metadata(_tier_opt.selected))
	var map_level := int(_level_spin.value)
	var kills := 100
	var drops := {}
	for i in kills:
		var egg_id: String = _gen.roll_egg_drop(tier, map_level)
		if egg_id != "":
			drops[egg_id] = int(drops.get(egg_id, 0)) + 1
	var total := 0
	for key in drops.keys():
		total += int(drops[key])
	_results.append_text("[b]%d %s kills @ lvl %d → %d eggs[/b]\n" % [kills, tier, map_level, total])
	if drops.is_empty():
		_results.append_text("(no eggs — expected for normal mobs)\n\n")
		return
	var keys: Array = drops.keys()
	keys.sort()
	for key in keys:
		_results.append_text("  %s: %d\n" % [key, drops[key]])
	_results.append_text("\n")
