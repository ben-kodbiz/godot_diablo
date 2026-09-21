extends Node

const RARITIES = ["Common", "Rare", "Epic", "Legendary"]

func generate_loot():
    var rarity = RARITIES[randi() % RARITIES.size()]

    var item = {
        "name": "Sword",
        "rarity": rarity,
        "damage": randi_range(2, 10)
    }

    return item

func roll_egg_drop():
    var chance = randi_range(1, 100)

    if chance <= 10:
        return {
            "type": "egg",
            "pet": "Slime"
        }

    return null
