extends Node
## Global event bus. Cross-system chatter goes through here so low-level
## systems never depend on UI and Player.gd never reaches into generators.
## See todoagent.md #52.

signal player_level_up(new_level: int)
signal item_dropped(item_id: String)
signal item_equipped(item_id: String, slot: String)
signal item_salvaged(item_id: String)
signal enemy_killed(enemy_id: String, level: int)
signal boss_killed(boss_id: String)
signal pet_obtained(pet_id: String)
signal egg_hatched(egg_id: String, pet_id: String)
signal talent_upgraded(talent_id: String, rank: int)
signal map_completed(map_id: String, seed: String)
