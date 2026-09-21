extends Node

var player_level := 1
var player_xp := 0
var xp_to_next := 100

signal player_leveled(level)

func add_xp(amount:int):
    player_xp += amount

    if player_xp >= xp_to_next:
        player_xp -= xp_to_next
        player_level += 1
        xp_to_next += 50
        emit_signal("player_leveled", player_level)
