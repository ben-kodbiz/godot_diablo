extends CharacterBody2D

@export var follow_speed := 80
var player = null

func _physics_process(delta):
    if player == null:
        return

    var dir = (player.global_position - global_position).normalized()

    velocity = dir * follow_speed
    move_and_slide()
