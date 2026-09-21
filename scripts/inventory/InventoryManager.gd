extends RefCounted
## InventoryManager: grid inventory DOMAIN model (fixme.md §32, no UI).
## Slots 0..capacity-1 hold item dicts (unique `unique_id`); stackables with
## equal base_id+rarity merge up to max_stack. All rules live here — UI
## (TASK 12) only calls these methods and refreshes. Emits no EventBus
## signals yet (event governance is a later stage); callers own side effects.
## State serializes via serialize()/deserialize() (save contract §30).

const RARITY_ORDER := ["normal", "uncommon", "rare", "epic", "legendary"]

var _data: Node
var _width := 10
var _height := 6
var _max_stack := 99
var _slots: Array = [] # index -> item dict or {}


func _init(data: Node, width: int = 0, height: int = 0) -> void:
	_data = data
	if width > 0 and height > 0:
		_width = width
		_height = height
	else:
		var table: Dictionary = _data.get_table("inventory_balance")
		var grid: Dictionary = table.get("grid", {})
		_width = int(grid.get("width", _width))
		_height = int(grid.get("height", _height))
		_max_stack = int((table.get("stacking", {}) as Dictionary).get("max_stack", _max_stack))
	_clear_slots()


func _clear_slots() -> void:
	_slots.clear()
	_slots.resize(_width * _height)
	for i in _slots.size():
		_slots[i] = {} # distinct dicts — shared refs would corrupt on mutate.


func capacity() -> int:
	return _width * _height


func count_free() -> int:
	var n := 0
	for slot in _slots:
		if (slot as Dictionary).is_empty():
			n += 1
	return n


func get_at(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	return (_slots[index] as Dictionary).duplicate(true)


func list() -> Array:
	var out: Array = []
	for i in _slots.size():
		if not (_slots[i] as Dictionary).is_empty():
			out.append({"slot": i, "item": (_slots[i] as Dictionary).duplicate(true)})
	return out


func contains(unique_id: String) -> bool:
	return find_slot(unique_id) >= 0


func find_slot(unique_id: String) -> int:
	for i in _slots.size():
		if str((_slots[i] as Dictionary).get("unique_id", "")) == unique_id:
			return i
	return -1


func find_by_base(base_id: String) -> Array:
	return _collect(func(item: Dictionary) -> bool: return str(item.get("base_id", "")) == base_id)


func find_by_rarity(rarity: String) -> Array:
	return _collect(func(item: Dictionary) -> bool: return str(item.get("rarity", "")) == rarity)


## Generic filter: criteria may hold rarity, slot(base slot name),
## min_level, base_id — all present keys must match.
func filter(criteria: Dictionary) -> Array:
	return _collect(func(item: Dictionary) -> bool:
		if criteria.has("rarity") and str(item.get("rarity", "")) != str(criteria["rarity"]):
			return false
		if criteria.has("slot") and str(item.get("slot", "")) != str(criteria["slot"]):
			return false
		if criteria.has("base_id") and str(item.get("base_id", "")) != str(criteria["base_id"]):
			return false
		if criteria.has("min_level") and int(item.get("item_level", 0)) < int(criteria["min_level"]):
			return false
		return true)


func _collect(pred: Callable) -> Array:
	var out: Array = []
	for i in _slots.size():
		var item := _slots[i] as Dictionary
		if not item.is_empty() and pred.call(item):
			out.append({"slot": i, "item": item.duplicate(true)})
	return out


## Add an item: merge into an open stack first, else first free slot.
## Returns {ok, slot (-1 if only merged/failed), reason}.
func add(item: Dictionary) -> Dictionary:
	if str(item.get("unique_id", "")) == "":
		return {"ok": false, "slot": -1, "reason": "Item has no unique_id."}
	if contains(str(item.get("unique_id", ""))):
		return {"ok": false, "slot": -1, "reason": "Duplicate unique_id."}
	var work := (item as Dictionary).duplicate(true)
	work["quantity"] = int(work.get("quantity", 1))
	if bool(work.get("stackable", false)):
		_merge(work)
		if int(work["quantity"]) <= 0:
			return {"ok": true, "slot": -1, "reason": ""}
	var slot := _first_free()
	if slot < 0:
		return {"ok": false, "slot": -1, "reason": "Inventory full."}
	_slots[slot] = work
	return {"ok": true, "slot": slot, "reason": ""}


func _merge(work: Dictionary) -> void:
	for i in _slots.size():
		if int(work.get("quantity", 0)) <= 0:
			return
		var cur := _slots[i] as Dictionary
		if cur.is_empty() or not bool(cur.get("stackable", false)):
			continue
		if str(cur.get("base_id", "")) != str(work.get("base_id", "")):
			continue
		if str(cur.get("rarity", "")) != str(work.get("rarity", "")):
			continue
		var room := _max_stack - int(cur.get("quantity", 1))
		if room <= 0:
			continue
		var take: int = mini(room, int(work["quantity"]))
		cur["quantity"] = int(cur.get("quantity", 1)) + take
		work["quantity"] = int(work["quantity"]) - take


func _first_free() -> int:
	for i in _slots.size():
		if (_slots[i] as Dictionary).is_empty():
			return i
	return -1


func remove(unique_id: String) -> Dictionary:
	var i := find_slot(unique_id)
	if i < 0:
		return {}
	var item := _slots[i] as Dictionary
	_slots[i] = {}
	return item


func remove_at(index: int) -> Dictionary:
	if index < 0 or index >= _slots.size():
		return {}
	var item := _slots[index] as Dictionary
	_slots[index] = {}
	return item


## Move/swap contents of two slots. Fails when `from` is empty/out of range.
func move(from_index: int, to_index: int) -> bool:
	if from_index < 0 or from_index >= _slots.size():
		return false
	if to_index < 0 or to_index >= _slots.size():
		return false
	if (_slots[from_index] as Dictionary).is_empty():
		return false
	var tmp: Dictionary = (_slots[from_index] as Dictionary).duplicate(true)
	_slots[from_index] = (_slots[to_index] as Dictionary).duplicate(true)
	_slots[to_index] = tmp
	return true


## Compact occupied slots toward 0, ordered by `by`: rarity > level > name.
func sort_inventory(by: String = "rarity") -> void:
	var items: Array = []
	for slot in _slots:
		if not (slot as Dictionary).is_empty():
			items.append(slot)
	items.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return _less(a, b, by))
	for i in _slots.size():
		_slots[i] = items[i] if i < items.size() else {}


func _less(a: Dictionary, b: Dictionary, by: String) -> bool:
	if by == "level":
		return int(a.get("item_level", 0)) > int(b.get("item_level", 0))
	if by == "name":
		return str(a.get("name", "")) < str(b.get("name", ""))
	var ra := RARITY_ORDER.find(str(a.get("rarity", "normal")))
	var rb := RARITY_ORDER.find(str(b.get("rarity", "normal")))
	if ra != rb:
		return ra > rb
	if int(a.get("item_level", 0)) != int(b.get("item_level", 0)):
		return int(a.get("item_level", 0)) > int(b.get("item_level", 0))
	return str(a.get("name", "")) < str(b.get("name", ""))


func serialize() -> Dictionary:
	var items: Array = []
	for slot in _slots:
		if not (slot as Dictionary).is_empty():
			items.append((slot as Dictionary).duplicate(true))
	return {"width": _width, "height": _height, "items": items}


func deserialize(data: Dictionary) -> bool:
	if not _is_int_like(data.get("width", 0)) or not _is_int_like(data.get("height", 0)):
		push_error("InventoryManager: save data missing grid size.")
		return false
	if typeof(data.get("items", null)) != TYPE_ARRAY:
		push_error("InventoryManager: save data missing items array.")
		return false
	var items := data["items"] as Array
	if items.size() > int(data["width"]) * int(data["height"]):
		push_error("InventoryManager: more items than grid holds.")
		return false
	var seen := {}
	for item in items:
		var id := str((item as Dictionary).get("unique_id", ""))
		if id == "" or seen.has(id):
			push_error("InventoryManager: item missing/duplicate unique_id.")
			return false
		seen[id] = true
	_width = int(data["width"])
	_height = int(data["height"])
	_clear_slots()
	for i in items.size():
		_slots[i] = (items[i] as Dictionary).duplicate(true)
	return true


func _is_int_like(v: Variant) -> bool:
	return v is int or (v is float and v == floor(v))
