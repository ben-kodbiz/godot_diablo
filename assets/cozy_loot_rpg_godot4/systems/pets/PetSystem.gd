extends Node

var active_pet = null

func hatch_egg(egg_data):
    active_pet = {
        "name": egg_data.pet,
        "level": 1,
        "xp": 0
    }

func add_pet_xp(amount:int):
    if active_pet == null:
        return

    active_pet.xp += amount

    if active_pet.xp >= 100:
        active_pet.level += 1
        active_pet.xp = 0
