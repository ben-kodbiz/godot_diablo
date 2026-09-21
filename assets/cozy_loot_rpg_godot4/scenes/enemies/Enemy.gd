extends CharacterBody2D

@export var hp := 20
@export var xp_reward := 10

signal died

func take_damage(amount:int):
    hp -= amount

    if hp <= 0:
        die()

func die():
    emit_signal("died")
    queue_free()
