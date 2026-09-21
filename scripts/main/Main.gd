extends Node2D
## Stage 0 entry point: bootstrap proof. Shows a placeholder world so the
## project (and later the browser export) visibly runs before any gameplay
## exists. Gameplay code must NOT live here — see stage managers.

const LootSimulatorPanel = preload("res://scripts/ui/LootSimulatorPanel.gd")
const PetSimulatorPanel = preload("res://scripts/ui/PetSimulatorPanel.gd")
const InventoryPanel = preload("res://scripts/ui/InventoryPanel.gd")
const EquipmentPanel = preload("res://scripts/ui/EquipmentPanel.gd")
const TalentPanel = preload("res://scripts/ui/TalentPanel.gd")
const CharacterPanel = preload("res://scripts/ui/CharacterPanel.gd")
const EnemyScene = preload("res://scenes/enemies/Enemy.tscn")
const LootGen = preload("res://scripts/loot/LootGenerator.gd")
const PetGen = preload("res://scripts/pets/PetGenerator.gd")

var _info: Label
var last_drops: Array = [] # dev introspection: [{enemy, item, egg}].
var ui_panels := {} # name -> panel (real game UI, all builds).


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
		_spawn_training_dummy()

	_mount_ui()
	_refresh_status()


## Real game UI (all builds): panels bind to the player, only one visible.
func _mount_ui() -> void:
	var player := get_node_or_null("Player")
	var defs := {
		"inventory": InventoryPanel, "equipment": EquipmentPanel,
		"talents": TalentPanel, "character": CharacterPanel,
	}
	for key in defs.keys():
		var panel = (defs[key] as GDScript).new()
		add_child(panel)
		ui_panels[key] = panel
		if player != null:
			panel.bind(player, self)


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("toggle_inventory"):
		_show_only(["inventory", "equipment"])
	elif event.is_action_pressed("toggle_character"):
		_show_only(["character"])
	elif event.is_action_pressed("toggle_talents"):
		_show_only(["talents"])


## Show exactly these panels (toggle: all-visible → hide all). Others hide.
func _show_only(names: Array) -> void:
	var any_hidden := false
	for n in names:
		if not (ui_panels[n] as CanvasItem).visible:
			any_hidden = true
	for key in ui_panels.keys():
		var panel = ui_panels[key]
		panel.visible = (str(key) in names) and any_hidden
		if panel.visible and panel.has_method("refresh"):
			panel.refresh()


func refresh_ui() -> void:
	for key in ui_panels.keys():
		var panel = ui_panels[key]
		if panel.visible and panel.has_method("refresh"):
			panel.refresh()


## Debug-only target dummy: one goblin to swing at until maps spawn enemies.
func _spawn_training_dummy() -> void:
	var dummy = EnemyScene.instantiate()
	dummy.position = Vector2(760, 360)
	register_enemy(dummy, "forest_goblin", 1)


## World-owned enemy registration (MapManager takes this over later):
## definition setup, death → XP + placeholder drops.
func register_enemy(enemy: Node, def_id: String, level: int) -> bool:
	add_child(enemy) # in-tree before setup: setup() uses absolute lookups.
	if not enemy.call("setup", def_id, level):
		enemy.queue_free()
		return false
	enemy.connect("died", _on_enemy_died)
	return true


func _on_enemy_died(enemy: Node) -> void:
	var player := get_node_or_null("Player")
	if player != null:
		player.stats.add_xp(int(enemy.get("xp_reward")))
	# Placeholder drop hookup until the loot-table contract stage (TASK 17/18):
	# random base at enemy level + tier egg roll.
	var lootgen: RefCounted = LootGen.new(RNGManager, DataManager)
	var petgen: RefCounted = PetGen.new(RNGManager, DataManager)
	var bases: Array = (DataManager.get_table("equipment") as Dictionary).keys()
	bases.sort()
	var item: Dictionary = lootgen.generate_item(
		str(bases[RNGManager.random_int(0, bases.size() - 1)]), int(enemy.get("level")))
	var egg_id: String = petgen.roll_egg_drop(str(enemy.get("tier")), int(enemy.get("level")))
	last_drops.append({"enemy": enemy.get("enemy_id"), "item": item, "egg": egg_id})
	print("DROP: %s (lvl %d) → %s + egg '%s'" % [
		enemy.get("enemy_id"), enemy.get("level"),
		item.get("name", "?"), egg_id if egg_id != "" else "(none)"])


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
