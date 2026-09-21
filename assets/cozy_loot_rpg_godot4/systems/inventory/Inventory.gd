extends Node

var items := []
const MAX_SLOTS := 20

func add_item(item):
    if items.size() >= MAX_SLOTS:
        return false

    items.append(item)
    return true

func remove_item(index:int):
    if index >= 0 and index < items.size():
        items.remove_at(index)
