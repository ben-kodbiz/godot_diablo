# AGENTODO.md

# Modular Pixel ARPG + Loot + Pet Collection Game

> Master implementation specification for an AI coding/game-development agent.
>
> Engine: Godot 4.x
> Language: GDScript
> Initial platform: Web Browser
> Future platform: Windows / Linux / Steam
> Art direction: 2D pixel art
> Data architecture: JSON-driven
> Primary design philosophy: Modular, replaceable, extensible, deterministic where required, content separated from code.

---

# 0. PROJECT VISION

Build a browser-based 2D pixel-art action RPG inspired by the **loot-driven progression loop** of classic ARPGs.

Core gameplay loop:

```text
Enter Map
    ↓
Fight Mobs
    ↓
Gain XP
    ↓
Level Up
    ↓
Find Loot
    ↓
Evaluate Equipment
    ↓
Equip / Salvage / Sell
    ↓
Improve Character
    ↓
Find Better Loot
    ↓
Find Eggs
    ↓
Hatch / Collect Pets
    ↓
Build Character + Pet Synergy
    ↓
Fight Elite / Boss
    ↓
Unlock Higher-Level Content
    ↓
Repeat
```

The game should prioritize:

1. Simple controls.
2. Satisfying combat.
3. Interesting loot.
4. Weapon-specific progression.
5. Pet collection.
6. Procedurally generated maps.
7. Highly modular systems.
8. JSON-driven balancing.
9. Pixel-art presentation.
10. Browser compatibility.
11. Low resource requirements.
12. Future portability to Steam.

---

# 1. CORE DESIGN PRINCIPLE

## EVERYTHING SHOULD BE A MODULE

A developer should be able to remove or add:

* weapon classes
* weapon types
* talents
* stats
* loot rarities
* affixes
* enemies
* bosses
* maps
* map themes
* procedural-generation rules
* pets
* pet rarities
* pet abilities
* equipment slots
* quests
* NPCs
* crafting
* salvage
* vendors
* events
* skills
* status effects

without rewriting the entire game.

Avoid large monolithic scripts.

Bad:

```text
Player.gd
    ├── combat
    ├── loot
    ├── pets
    ├── inventory
    ├── maps
    ├── enemies
    ├── quests
    └── save system
```

Preferred:

```text
Player
 ├── CharacterStats
 ├── EquipmentManager
 ├── InventoryManager
 ├── CombatController
 ├── TalentManager
 ├── PetManager
 └── ProgressionManager
```

Global systems:

```text
GameManager
DataManager
LootManager
MapManager
EnemyManager
SaveManager
AudioManager
UIManager
EventBus
```

---

# 2. TARGET ARCHITECTURE

Use a layered architecture.

```text
                    ┌─────────────────────┐
                    │       UI Layer      │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │    Game Systems     │
                    │                     │
                    │ Combat              │
                    │ Loot                │
                    │ Inventory           │
                    │ Pets                │
                    │ Talents             │
                    │ Maps                │
                    │ Enemies             │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │    Data Layer       │
                    │                     │
                    │ JSON definitions    │
                    │ Balance values      │
                    │ Tables              │
                    │ Content definitions  │
                    └──────────┬──────────┘
                               │
                    ┌──────────▼──────────┐
                    │    Save Layer       │
                    │                     │
                    │ Player save         │
                    │ Inventory           │
                    │ Pets                │
                    │ Progression         │
                    └─────────────────────┘
```

Code should not contain large amounts of balancing data.

---

# 3. ENGINE

Use:

```text
Godot 4.x
GDScript
2D renderer
Web export
```

Do NOT use C# for the initial version because Web deployment should remain straightforward.

Use native Godot scenes and GDScript.

Recommended rendering target:

```text
Compatibility renderer
```

This keeps the project appropriate for browser deployment.

---

# 4. PROJECT STRUCTURE

Create:

```text
project/
│
├── project.godot
│
├── scenes/
│   ├── main/
│   │   ├── Main.tscn
│   │   └── Main.gd
│   │
│   ├── player/
│   │   ├── Player.tscn
│   │   └── Player.gd
│   │
│   ├── enemies/
│   │   ├── Enemy.tscn
│   │   ├── EliteEnemy.tscn
│   │   └── Boss.tscn
│   │
│   ├── loot/
│   │   ├── LootDrop.tscn
│   │   └── LootPickup.tscn
│   │
│   ├── pets/
│   │   ├── Pet.tscn
│   │   └── Egg.tscn
│   │
│   ├── maps/
│   │   ├── Map.tscn
│   │   ├── MapRoom.tscn
│   │   └── MapPortal.tscn
│   │
│   └── ui/
│       ├── HUD.tscn
│       ├── Inventory.tscn
│       ├── CharacterPanel.tscn
│       ├── TalentPanel.tscn
│       ├── PetPanel.tscn
│       ├── LootTooltip.tscn
│       └── Settings.tscn
│
├── scripts/
│   ├── core/
│   ├── combat/
│   ├── character/
│   ├── equipment/
│   ├── inventory/
│   ├── loot/
│   ├── talents/
│   ├── pets/
│   ├── enemies/
│   ├── maps/
│   ├── procedural/
│   ├── save/
│   ├── ui/
│   └── utilities/
│
├── data/
│   ├── stats/
│   ├── weapons/
│   ├── equipment/
│   ├── loot/
│   ├── rarities/
│   ├── affixes/
│   ├── talents/
│   ├── pets/
│   ├── eggs/
│   ├── enemies/
│   ├── bosses/
│   ├── maps/
│   ├── biomes/
│   ├── drops/
│   ├── balance/
│   └── localization/
│
├── assets/
│   ├── characters/
│   ├── enemies/
│   ├── weapons/
│   ├── pets/
│   ├── tilesets/
│   ├── environment/
│   ├── UI/
│   ├── VFX/
│   ├── SFX/
│   ├── music/
│   └── fonts/
│
├── tests/
│   ├── loot/
│   ├── stats/
│   ├── pets/
│   ├── maps/
│   ├── combat/
│   └── save/
│
├── docs/
│   ├── GAME_DESIGN.md
│   ├── ARCHITECTURE.md
│   ├── LOOT_DESIGN.md
│   ├── PET_DESIGN.md
│   ├── MAP_GENERATION.md
│   ├── ASSET_LICENSES.md
│   └── BALANCING.md
│
└── README.md
```

---

# 5. DATA-DRIVEN DESIGN

JSON is the source of truth for game content.

Example:

```text
data/weapons/weapons.json
data/talents/talents.json
data/pets/pets.json
data/enemies/enemies.json
data/maps/maps.json
data/loot/loot_tables.json
```

Do not scatter balance numbers throughout GDScript.

---

# 6. GLOBAL STATS

Initial stats:

```text
STR
DEX
INT
VIT
LUCK
```

Definitions:

### STR

Physical power.

Potential effects:

```text
physical_damage
maximum_health
melee_damage
```

### DEX

Agility.

Potential effects:

```text
ranged_damage
attack_speed
critical_chance
evasion
```

### INT

Magical power.

Potential effects:

```text
magic_damage
mana
skill_power
```

### VIT

Survivability.

Potential effects:

```text
maximum_health
armor
health_regeneration
```

### LUCK

Loot-related stat.

Potential effects:

```text
loot_quantity
rare_drop_chance
pet_drop_chance
```

Do NOT overcomplicate these during MVP.

---

# 7. WEAPON SYSTEM

Initial weapon categories:

```text
bow
crossbow
staff
sword
two_handed_sword
shield
```

Internally, use a weapon family system.

Example:

```json
{
  "id": "bow",
  "family": "ranged",
  "primary_stat": "dex",
  "secondary_stats": ["attack_speed", "critical_chance"],
  "talent_tree": "bow"
}
```

Staff:

```json
{
  "id": "staff",
  "family": "magic",
  "primary_stat": "int",
  "secondary_stats": ["mana", "skill_power"],
  "talent_tree": "staff"
}
```

Sword:

```json
{
  "id": "sword",
  "family": "melee",
  "primary_stat": "str",
  "secondary_stats": ["attack_speed", "physical_damage"],
  "talent_tree": "sword"
}
```

Shield:

```json
{
  "id": "shield",
  "family": "defensive",
  "primary_stat": "vit",
  "secondary_stats": ["armor", "block"],
  "talent_tree": "shield"
}
```

---

# 8. EQUIPMENT SLOT MODEL

Initial slots:

```text
Main Hand
Off Hand
Armor
Helmet
Accessory 1
Accessory 2
Pet
```

Rules:

```text
Sword
    Main Hand

Bow
    Main Hand

Crossbow
    Main Hand

Staff
    Main Hand

Shield
    Off Hand

Two-Handed Sword
    Main Hand
    Occupies Off Hand
```

Keep these rules in equipment data.

Do not hard-code them into Player.gd.

---

# 9. WEAPON ATTRIBUTE BONUS

Equipping equipment automatically modifies character stats.

Example:

```text
Bow
+DEX

Staff
+INT

Sword
+STR

Shield
+VIT
```

The exact values should be generated from loot generation.

Example:

```json
{
  "id": "iron_bow",
  "base_type": "bow",
  "required_level": 5,
  "base_stats": {
    "dex": 8
  }
}
```

---

# 10. TALENT SYSTEM

Each weapon family has a dedicated talent tree.

Example:

```text
Bow
├── Rapid Shot
├── Precision
├── Multi Shot
├── Piercing Arrow
└── Critical Focus
```

Staff:

```text
Staff
├── Arcane Power
├── Mana Flow
├── Spell Echo
├── Elemental Focus
└── Arcane Burst
```

Sword:

```text
Sword
├── Cleave
├── Heavy Strike
├── Sword Mastery
├── Critical Slash
└── Bloodless Fury
```

Shield:

```text
Shield
├── Block Mastery
├── Shield Wall
├── Guard
├── Counter
└── Fortification
```

---

# 11. TALENT DESIGN

Talents should NOT be permanently tied to Player.gd.

Talent definition:

```json
{
  "id": "bow_precision",
  "weapon_family": "bow",
  "max_rank": 5,
  "cost_per_rank": 1,
  "effects": [
    {
      "type": "critical_chance",
      "value_per_rank": 2
    }
  ]
}
```

Talent manager responsibilities:

```text
unlock talent
upgrade talent
validate requirements
calculate talent modifiers
reset talents
save talents
```

---

# 12. WEAPON-SPECIFIC PROGRESSION

When player levels:

```text
Character Level increases
        +
Talent Point awarded
```

Talent points can be spent in the currently supported weapon trees.

Recommended system:

```text
Universal Talent Points
```

rather than separate points per weapon.

This makes experimenting with different equipment easier.

Later, a specialization system can be added.

---

# 13. LOOT SYSTEM

Loot must be procedural.

Every drop should be generated from:

```text
Base Item
+
Item Level
+
Rarity
+
Affixes
+
Random Rolls
+
Optional Special Effect
```

Example:

```text
Iron Bow
Level 14
Rare

+19 DEX
+5% Attack Speed
+3% Critical Chance
```

---

# 14. RARITY SYSTEM

Initial rarity categories:

```text
Normal
Green
Blue
Purple
Legendary
```

Suggested internal IDs:

```text
normal
uncommon
rare
epic
legendary
```

Suggested meaning:

### Normal

Base item.

```text
0-1 affixes
```

### Green / Uncommon

```text
1-2 affixes
```

### Blue / Rare

```text
2-3 affixes
```

### Purple / Epic

```text
3-4 affixes
```

### Legendary

```text
4+ affixes
+
unique legendary effect
```

Exact values must be JSON-configurable.

---

# 15. RARITY JSON

Example:

```json
{
  "normal": {
    "weight": 6000,
    "min_affixes": 0,
    "max_affixes": 1
  },
  "uncommon": {
    "weight": 2500,
    "min_affixes": 1,
    "max_affixes": 2
  },
  "rare": {
    "weight": 1000,
    "min_affixes": 2,
    "max_affixes": 3
  },
  "epic": {
    "weight": 450,
    "min_affixes": 3,
    "max_affixes": 4
  },
  "legendary": {
    "weight": 50,
    "min_affixes": 4,
    "max_affixes": 5
  }
}
```

Weights should be balance data.

---

# 16. AFFIX SYSTEM

Affixes are modular.

Examples:

```text
+STR
+DEX
+INT
+VIT
+LUCK

+Attack Speed
+Critical Chance
+Critical Damage
+Armor
+Health
+Mana
+Move Speed
+Damage
+Skill Power
```

Example:

```json
{
  "id": "dex",
  "stat": "dex",
  "min_value": 1,
  "max_value": 20,
  "allowed_slots": [
    "weapon",
    "armor"
  ]
}
```

Affix eligibility must be data-driven.

---

# 17. LOOT GENERATION PIPELINE

Implement:

```text
LootGenerator.generate_item(
    base_item,
    item_level,
    drop_context
)
```

Pipeline:

```text
1. Select base item
2. Determine item level
3. Roll rarity
4. Determine affix count
5. Build valid affix pool
6. Roll affixes
7. Roll values
8. Apply item-level scaling
9. Apply rarity multiplier
10. Apply legendary effect if required
11. Generate display name
12. Generate item ID
13. Return ItemData
```

---

# 18. ITEM INSTANCE VS ITEM DEFINITION

Important architecture.

Definition:

```text
Iron Bow
```

Instance:

```text
Iron Bow
Level 18
Rare
+22 DEX
+4% Critical Chance
+7% Attack Speed
Unique Instance ID
```

Never modify the base item definition when generating loot.

---

# 19. ITEM ID

Every generated item receives a unique ID.

Example:

```text
itm_8f91a23c
```

The ID is required for save/load.

---

# 20. LOOT DROP TABLES

Loot should be determined by:

```text
Enemy
+
Map
+
Enemy Level
+
Difficulty
+
Boss/Elite status
```

Example:

```json
{
  "goblin": {
    "equipment": 40,
    "gold": 50,
    "egg": 2
  }
}
```

Boss:

```json
{
  "ancient_guardian": {
    "equipment": 100,
    "epic_bonus": 20,
    "legendary_bonus": 10,
    "egg": 10
  }
}
```

Numbers are examples only.

---

# 21. PET SYSTEM

Pets are a major progression and collection system.

Initial function:

```text
Passive stat bonuses
```

Pets do NOT need active combat behavior for MVP.

Example:

```text
Wolf

+5 DEX
+2% Attack Speed
```

Mage Cat:

```text
+7 INT
+3% Mana
```

Turtle:

```text
+10 VIT
+5% Health
```

---

# 22. PET RARITIES

Initial:

```text
Common
Rare
Epic
```

Future:

```text
Legendary
Mythic
Ancient
```

Do not implement future tiers until the core system works.

---

# 23. PET DATA

Example:

```json
{
  "id": "wolf",
  "name": "Forest Wolf",
  "rarity": "common",
  "egg_type": "forest_egg",
  "bonuses": [
    {
      "stat": "dex",
      "value": 5
    }
  ]
}
```

---

# 24. PET COLLECTION

Player should maintain:

```text
Owned Pets
Active Pet
Pet Collection
Pet Discovery
Pet Level
```

Initial MVP:

```text
1 active pet
```

Future:

```text
multiple pet slots
pet teams
pet synergy
pet evolution
pet fusion
pet traits
```

Do not implement these until the basic pet system is stable.

---

# 25. EGG SYSTEM

Eggs drop from:

```text
Normal enemies
Elite enemies
Bosses
Special events
```

Eggs have:

```text
egg type
rarity
hatch duration
possible pets
```

Example:

```json
{
  "id": "forest_egg",
  "hatch_time_hours": 24,
  "possible_pets": [
    "wolf",
    "forest_fairy",
    "green_slime"
  ]
}
```

---

# 26. REAL-TIME HATCHING

Egg hatching should use a timestamp.

Save:

```text
egg_id
start_timestamp
hatch_duration
```

On loading:

```text
current_time - start_timestamp
```

If duration is complete:

```text
egg becomes hatchable
```

Do NOT rely on a running timer alone.

This allows the browser to close while the egg is incubating.

---

# 27. IMPORTANT WEB-SAFETY DESIGN

The browser is not authoritative.

Never trust:

```text
client-side timer
client-side currency
client-side loot probability
client-side level
```

For the initial offline game, this is acceptable because it is a single-player experience.

If online accounts/trading/PvP are introduced later:

```text
server-authoritative backend
```

must be introduced.

---

# 28. PET PASSIVE SYSTEM

Pets should use generic modifiers.

Example:

```json
{
  "type": "stat_modifier",
  "stat": "dex",
  "value": 5
}
```

Another:

```json
{
  "type": "percentage_modifier",
  "stat": "attack_speed",
  "value": 3
}
```

PetManager should simply aggregate modifiers.

---

# 29. CHARACTER STAT CALCULATION

Never manually modify stats in multiple places.

Use:

```text
Base Stats
+
Level Stats
+
Equipment Stats
+
Talent Stats
+
Pet Stats
+
Temporary Buffs
=
Final Stats
```

Example:

```text
STR:
base STR
+ equipment STR
+ pet STR
+ talent STR
+ temporary STR
```

Create:

```text
StatCalculator
```

as a central system.

---

# 30. MODIFIER SYSTEM

Every system should produce modifiers.

Example:

```text
EquipmentModifier
TalentModifier
PetModifier
BuffModifier
DebuffModifier
```

All feed:

```text
StatCalculator
```

This prevents spaghetti code.

---

# 31. ENEMY SYSTEM

Enemy definitions must be JSON-driven.

Example:

```json
{
  "id": "forest_goblin",
  "base_level": 1,
  "health": 50,
  "damage": 8,
  "armor": 2,
  "xp": 10,
  "loot_table": "forest_common"
}
```

Enemy scene should be generic.

```text
Enemy.tscn
```

loads its definition and behaves accordingly.

---

# 32. ENEMY TYPES

Initial:

```text
Normal
Elite
Boss
```

Future:

```text
Rare
Champion
Event
MiniBoss
```

---

# 33. ENEMY AI

Initial AI:

```text
Idle
Patrol
Detect Player
Chase
Attack
Take Damage
Die
```

Do not build complicated AI initially.

Create:

```text
EnemyAI.gd
```

with replaceable behavior modules.

---

# 34. BOSS SYSTEM

Bosses should be data-driven.

Boss JSON:

```json
{
  "id": "forest_guardian",
  "level_scaling": true,
  "phases": [
    {
      "health_threshold": 100,
      "behavior": "normal"
    },
    {
      "health_threshold": 50,
      "behavior": "enraged"
    }
  ],
  "loot_table": "forest_boss"
}
```

Boss phases should eventually support:

```text
phase change
new attack
summon enemies
movement changes
arena hazards
loot changes
```

---

# 35. MAP SYSTEM

Maps are procedural.

Each map is defined by JSON.

Example:

```json
{
  "id": "forest_01",
  "biome": "forest",
  "minimum_level": 1,
  "maximum_level": 20,
  "room_count_min": 8,
  "room_count_max": 15,
  "enemy_table": "forest_enemies",
  "boss": "forest_guardian"
}
```

---

# 36. MAP LEVEL SCALING

Map level should scale around player level.

Example:

```text
Player Level = 20

Map base level = 15
Map scaling = enabled

Final map level = 18-22
```

Use configurable rules.

Example:

```json
{
  "scaling": {
    "enabled": true,
    "player_level_offset_min": -2,
    "player_level_offset_max": 2
  }
}
```

---

# 37. PROCEDURAL MAP GENERATOR

Use deterministic procedural generation.

Input:

```text
map_id
seed
player_level
difficulty
```

Output:

```text
rooms
corridors
spawn points
enemy groups
loot locations
elite locations
boss arena
exit
```

---

# 38. SEED SYSTEM

Every generated map should have a seed.

Example:

```text
FOREST-20260921-839201
```

This allows:

```text
reproduce map
debug map
share map seed
test generation
```

---

# 39. MAP GENERATION PIPELINE

```text
Load Map Definition
        ↓
Generate Seed
        ↓
Generate Room Layout
        ↓
Connect Rooms
        ↓
Place Spawn
        ↓
Place Enemies
        ↓
Place Elite
        ↓
Place Loot
        ↓
Generate Boss Arena
        ↓
Place Boss
        ↓
Place Exit
        ↓
Validate Map
        ↓
Start Game
```

Map validation is mandatory.

Check:

```text
Player can reach exit
Player can reach boss
No room overlaps
No impossible corridors
No spawn inside wall
No unreachable loot
```

---

# 40. BIOME SYSTEM

Create biome definitions.

Initial:

```text
Forest
Cave
Ruins
```

Future:

```text
Desert
Swamp
Snow
Volcanic
Underground
Castle
```

Biome controls:

```text
tileset
music
ambient effects
enemy tables
boss pool
loot table
room decorations
color palette
```

---

# 41. PROCEDURAL GENERATION MUST BE DATA-DRIVEN

Bad:

```gdscript
if biome == "forest":
    spawn_tree()
```

Better:

```text
BiomeDefinition
    decorations
    room_rules
    tileset
    enemy_table
```

Then generator consumes the definition.

---

# 42. COMBAT SYSTEM

Keep combat modular.

Components:

```text
CombatController
DamageCalculator
HitDetector
AttackController
SkillController
StatusEffectManager
```

Damage formula should live in one place.

Example:

```text
Base Damage
× Skill Multiplier
× Weapon Modifier
× Critical Modifier
× Buff Modifier
× Enemy Resistance
```

Do not duplicate damage calculations.

---

# 43. DAMAGE TYPES

Initial:

```text
Physical
Magic
```

Future:

```text
Fire
Ice
Lightning
Poison
Holy
Shadow
```

Do not implement all damage types in MVP.

Build the architecture so they can be added later.

---

# 44. INVENTORY

Initial inventory:

```text
Grid inventory
```

Each item:

```text
Item Instance
```

Actions:

```text
Equip
Unequip
Drop
Sell
Salvage
Compare
Sort
Filter
```

---

# 45. INVENTORY FILTERS

Allow:

```text
All
Weapons
Armor
Accessories
Eggs
Pets
Materials
```

Rarity filter:

```text
Normal
Green
Blue
Purple
Legendary
```

---

# 46. LOOT FILTER

Eventually implement an automatic loot filter.

Example:

```text
Hide Normal equipment
Show Green+
Show all Eggs
Show Legendary
```

This is highly useful for an ARPG.

Make it JSON-configurable.

---

# 47. ITEM COMPARISON

When hovering an item:

```text
Current Item
vs
New Item
```

Show:

```text
DEX +8
Damage +12
Crit -1%
Attack Speed +3%
```

Use clear UI indicators.

---

# 48. SALVAGE SYSTEM

Optional MVP+ feature.

Destroy equipment:

```text
Equipment
↓
Salvage
↓
Materials
```

Materials can later be used for:

```text
crafting
upgrading
rerolling
```

Keep the system modular even if disabled initially.

---

# 49. CRAFTING

Do NOT implement full crafting during the first MVP.

Prepare interface:

```text
CraftingManager
RecipeManager
MaterialManager
```

Feature flag:

```json
{
  "crafting_enabled": false
}
```

Later:

```text
upgrade
reroll
combine
craft
```

---

# 50. SAVE SYSTEM

Initial browser save:

```text
user://save.json
```

Save:

```text
player level
XP
stats
talents
inventory
equipment
pets
eggs
gold
settings
map progression
achievements
```

Use a save schema version.

Example:

```json
{
  "save_version": 1,
  "player": {},
  "inventory": {},
  "pets": {},
  "settings": {}
}
```

---

# 51. SAVE MIGRATION

Future save format changes must not destroy old saves.

Implement:

```text
SaveMigrationManager
```

Example:

```text
save_version 1
        ↓
Migration 1 → 2
        ↓
Migration 2 → 3
```

---

# 52. EVENT BUS

Create a global event bus.

Events:

```text
player_level_up
item_dropped
item_equipped
item_salvaged
enemy_killed
boss_killed
pet_obtained
egg_hatched
talent_upgraded
map_completed
```

Systems communicate through events instead of direct dependencies wherever practical.

---

# 53. FEATURE FLAGS

Create:

```text
FeatureManager
```

Example:

```json
{
  "pets": true,
  "crafting": false,
  "quests": false,
  "bosses": true,
  "legendary_items": true,
  "procedural_maps": true
}
```

This allows unfinished systems to remain disabled.

---

# 54. CONTENT REGISTRY

Create a central DataManager.

Responsibilities:

```text
load JSON
validate JSON
cache definitions
provide definitions to systems
report invalid definitions
```

API example:

```gdscript
DataManager.get_weapon("bow")
DataManager.get_pet("wolf")
DataManager.get_enemy("forest_goblin")
DataManager.get_map("forest_01")
```

---

# 55. JSON VALIDATION

Every JSON file must be validated at startup.

Example:

```text
Weapon:
    id required
    primary_stat required
    family required

Pet:
    id required
    rarity required
    bonuses required

Enemy:
    id required
    health required
    damage required
```

Invalid content should generate a clear error:

```text
DATA ERROR:
pets.json
pet: wolf
missing field: rarity
```

Do not silently continue with broken data.

---

# 56. RANDOM NUMBER SYSTEM

Centralize random generation.

Create:

```text
RNGManager
```

Support:

```text
random_int
random_float
weighted_choice
seeded_random
```

Loot and map generation should be able to use deterministic RNG.

---

# 57. TESTABILITY

Loot generation must be testable without launching the entire game.

Example:

```text
LootGeneratorTest
```

Generate:

```text
10,000 items
```

Then verify:

```text
rarity distribution
affix validity
item level
stat ranges
legendary rate
```

---

# 58. LOOT SIMULATION TOOL

Create developer-only UI:

```text
Loot Simulator
```

Inputs:

```text
Player Level
Enemy Level
Enemy Type
Map
Luck
```

Output:

```text
10,000 simulated drops
```

Display:

```text
Normal %
Green %
Blue %
Purple %
Legendary %
```

This will make balancing dramatically easier.

---

# 59. PET SIMULATION

Create:

```text
Pet Egg Simulator
```

Input:

```text
Egg
```

Output:

```text
Common %
Rare %
Epic %
```

This must use the same production RNG code.

---

# 60. DEBUG MODE

Create:

```text
DebugManager
```

Developer shortcuts:

```text
give_gold
give_item
give_pet
give_egg
level_up
teleport
spawn_enemy
spawn_boss
regenerate_map
show_seed
show_hitboxes
show_fps
show_stat_breakdown
```

Debug mode must be disabled in release builds.

---

# 61. STAT DEBUG PANEL

Developer UI should display:

```text
BASE
LEVEL
EQUIPMENT
TALENTS
PETS
BUFFS
FINAL
```

Example:

```text
DEX

Base             10
Level            15
Equipment        38
Talent            8
Pet               5
Buff              0
--------------------
Final             76
```

This is extremely important for debugging.

---

# 62. USER INTERFACE

Primary HUD:

```text
┌─────────────────────────────────────────┐
│ HP              XP             Level 12 │
│ ████████        ███████                   │
│                                         │
│                                         │
│              GAME WORLD                 │
│                                         │
│                                         │
│                                         │
│ Inventory   Character   Talents   Pets  │
└─────────────────────────────────────────┘
```

---

# 63. PIXEL ART STYLE

Recommended:

```text
16x16
24x24
32x32
48x48
```

Choose ONE primary scale.

Recommended MVP:

```text
32x32 logical sprite size
```

Use nearest-neighbor filtering.

Avoid mixing wildly different pixel densities.

---

# 64. CAMERA

Use:

```text
2D Camera
```

Features:

```text
follow player
screen shake
zoom
map boundaries
```

Keep camera effects subtle.

---

# 65. INPUT

Support:

```text
Keyboard
Mouse
```

Potential future:

```text
Controller
Touch
```

Use Godot InputMap.

Never hard-code keyboard keys directly into gameplay code.

---

# 66. BROWSER-FIRST UX

The game must work when launched directly from a browser.

Avoid unnecessary:

```text
huge assets
large audio files
massive textures
long loading times
```

Create:

```text
Loading Screen
Asset Loading
Progress Indicator
```

---

# 67. WEB SAVE

Use Godot's user storage for the initial offline game.

Important:

```text
Save
Load
Export
Import
```

Add a manual save backup feature eventually:

```text
Export Save
Import Save
```

This protects players from browser data loss.

---

# 68. FUTURE STEAM ARCHITECTURE

Do not build the game specifically around browser APIs.

Avoid:

```text
JavaScript-only gameplay
browser-specific game logic
localStorage-only architecture
```

Keep gameplay inside Godot.

The web layer should only be the deployment target.

This allows later:

```text
Godot Web
        ↓
Windows
Linux
Steam
```

without rewriting the game.

---

# 69. ASSET POLICY

Use only:

```text
CC0
CC-BY
CC-BY-SA
MIT
Apache
other explicitly compatible licenses
```

For every external asset create:

```text
docs/ASSET_LICENSES.md
```

Track:

```text
asset
creator
source
license
attribution requirement
modification
```

Never assume that "free download" means commercially reusable.

Godot's own license permits commercial use, but third-party assets have their own licensing requirements.

---

# 70. ASSET DIRECTORY RULE

Every asset must have provenance.

Example:

```text
assets/enemies/goblin/
    goblin_idle.png
    goblin_attack.png
    SOURCE.md
```

SOURCE.md:

```text
Creator:
Source:
License:
URL:
Attribution:
Modification:
```

---

# 71. AUDIO

Initial audio:

```text
attack
hit
enemy death
loot drop
level up
item equip
egg hatch
boss spawn
button click
```

Music:

```text
town
forest
cave
boss
```

Use compressed formats appropriate for Web.

---

# 72. GAME WORLD STRUCTURE

Initial progression:

```text
Town / Hub
   ↓
Forest
   ↓
Forest Depths
   ↓
Forest Boss
```

Then:

```text
Cave
Ruins
```

Do not create 20 maps initially.

Build 3 good environments first.

---

# 73. MVP CONTENT

MVP should contain:

## Player

```text
1 character
movement
basic attack
HP
XP
level
stats
```

## Weapons

```text
Bow
Staff
Sword
Shield
```

Add crossbow and two-handed sword after core architecture is proven.

## Loot

```text
Normal
Green
Blue
Purple
Legendary
```

## Pets

```text
3-6 pets
Common
Rare
Epic
```

## Maps

```text
1 biome
3 procedural maps
1 boss
```

## Enemies

```text
3 normal enemies
1 elite
1 boss
```

---

# 74. STAGE 0 — PROJECT BOOTSTRAP

Tasks:

* [ ] Create Godot project.
* [ ] Configure Web export.
* [ ] Configure Compatibility renderer.
* [ ] Configure pixel-art texture filtering.
* [ ] Configure InputMap.
* [ ] Create folder architecture.
* [ ] Create Git repository.
* [ ] Create README.
* [ ] Create LICENSE/asset-license documentation.
* [ ] Create basic Main scene.
* [ ] Confirm game launches in browser.

Acceptance:

```text
Godot project launches.
Browser build launches.
No errors.
```

---

# 75. STAGE 1 — DATA ENGINE

Implement:

* [ ] DataManager.
* [ ] JSON loader.
* [ ] JSON validator.
* [ ] Data cache.
* [ ] Error reporting.
* [ ] FeatureManager.
* [ ] RNGManager.
* [ ] EventBus.

Create initial JSON:

```text
stats.json
weapons.json
rarities.json
affixes.json
```

Acceptance:

```text
Game can load all JSON definitions.
Invalid JSON produces useful error messages.
```

---

# 76. STAGE 2 — PLAYER

Implement:

* [ ] Player scene.
* [ ] movement.
* [ ] camera.
* [ ] HP.
* [ ] XP.
* [ ] levels.
* [ ] base stats.
* [ ] StatCalculator.
* [ ] input system.

Acceptance:

```text
Player can move.
Player can level.
Stats update correctly.
```

---

# 77. STAGE 3 — EQUIPMENT

Implement:

* [ ] ItemDefinition.
* [ ] ItemInstance.
* [ ] EquipmentManager.
* [ ] Equipment slots.
* [ ] equip.
* [ ] unequip.
* [ ] two-handed slot logic.
* [ ] equipment stat modifiers.

Acceptance:

```text
Bow → DEX
Staff → INT
Sword → STR
Shield → VIT
```

All relationships come from JSON.

---

# 78. STAGE 4 — INVENTORY

Implement:

* [ ] inventory grid.
* [ ] item stack handling where applicable.
* [ ] item selection.
* [ ] equip.
* [ ] drop.
* [ ] item comparison.
* [ ] sorting.
* [ ] rarity filtering.

Acceptance:

```text
Loot can enter inventory.
Player can equip it.
Stats change correctly.
```

---

# 79. STAGE 5 — LOOT GENERATOR

Implement:

* [ ] rarity system.
* [ ] weighted rarity.
* [ ] affix system.
* [ ] item-level scaling.
* [ ] stat rolls.
* [ ] legendary effects.
* [ ] generated item names.
* [ ] loot tables.

Acceptance:

Generate thousands of items without invalid combinations.

---

# 80. STAGE 6 — COMBAT

Implement:

* [ ] attack.
* [ ] hit detection.
* [ ] damage calculation.
* [ ] enemy health.
* [ ] enemy death.
* [ ] XP.
* [ ] loot drop.
* [ ] basic enemy AI.

Acceptance:

```text
Player
→ attack enemy
→ enemy dies
→ XP awarded
→ loot appears
```

---

# 81. STAGE 7 — TALENTS

Implement:

* [ ] talent definitions.
* [ ] talent trees.
* [ ] talent points.
* [ ] talent unlock.
* [ ] talent rank.
* [ ] weapon-specific trees.
* [ ] talent UI.
* [ ] stat modifiers.

Acceptance:

```text
Bow equipped
→ Bow talents available.

Staff equipped
→ Staff talents available.
```

Do not destroy talent progress when changing weapon.

---

# 82. STAGE 8 — PET SYSTEM

Implement:

* [ ] pet definitions.
* [ ] pet collection.
* [ ] pet UI.
* [ ] active pet.
* [ ] passive modifiers.
* [ ] egg drops.
* [ ] egg inventory.
* [ ] hatch timer.
* [ ] hatch result.
* [ ] pet rarity.

Acceptance:

```text
Enemy
→ egg drop
→ player starts hatch
→ browser closes
→ player returns later
→ egg becomes ready
→ pet obtained
→ pet stats applied
```

---

# 83. STAGE 9 — PROCEDURAL MAPS

Implement:

* [ ] room generator.
* [ ] corridor generator.
* [ ] spawn system.
* [ ] loot placement.
* [ ] elite placement.
* [ ] boss room.
* [ ] exit.
* [ ] map validation.
* [ ] seed system.

Acceptance:

```text
Same seed
→ same map.

Different seed
→ different map.
```

---

# 84. STAGE 10 — MAP LEVEL SCALING

Implement:

```text
Player Level
+
Map Base Level
+
Scaling Rules
=
Map Level
```

Ensure:

```text
Enemy level
Loot level
XP
Boss level
```

all use the resulting map level.

Acceptance:

```text
Player Level 5
→ low-level enemies.

Player Level 30
→ same map remains relevant.
```

---

# 85. STAGE 11 — BOSS

Implement:

* [ ] boss definition.
* [ ] boss AI.
* [ ] health phases.
* [ ] special attacks.
* [ ] boss arena.
* [ ] boss loot.
* [ ] boss UI.

Acceptance:

```text
Boss is meaningfully different from normal enemies.
```

---

# 86. STAGE 12 — UI POLISH

Implement:

* [ ] HUD.
* [ ] inventory.
* [ ] character panel.
* [ ] talents.
* [ ] pets.
* [ ] item tooltip.
* [ ] item comparison.
* [ ] map UI.
* [ ] settings.
* [ ] loading screen.
* [ ] death screen.
* [ ] victory screen.

---

# 87. STAGE 13 — SAVE SYSTEM

Implement:

* [ ] SaveManager.
* [ ] save schema.
* [ ] save version.
* [ ] migration system.
* [ ] autosave.
* [ ] manual save.
* [ ] export save.
* [ ] import save.

Test:

```text
Play
→ save
→ reload browser
→ progress retained.
```

---

# 88. STAGE 14 — BALANCING TOOLS

Implement developer tools:

```text
Loot Simulator
Pet Simulator
Enemy DPS Simulator
XP Simulator
Map Generator Preview
Stat Debugger
```

This stage is critical.

Do not balance everything manually by playing repeatedly.

---

# 89. STAGE 15 — CONTENT PASS

Add:

```text
Forest biome
Cave biome
Ruins biome
```

Add:

```text
10+ enemies
3+ elites
3 bosses
20+ weapon/item bases
20+ affixes
10+ pets
3 egg types
```

Only after systems are stable.

---

# 90. STAGE 16 — ART PASS

Replace placeholder art with coherent pixel-art assets.

Priorities:

1. Player.
2. Main enemies.
3. Main weapons.
4. Environment.
5. UI.
6. Pets.
7. Bosses.
8. VFX.

Do not spend weeks creating beautiful art before gameplay exists.

---

# 91. STAGE 17 — AUDIO PASS

Add:

```text
combat SFX
loot SFX
level-up SFX
pet SFX
boss SFX
UI SFX
music
ambient
```

---

# 92. STAGE 18 — WEB OPTIMIZATION

Measure:

```text
initial load time
memory usage
FPS
asset size
JavaScript/WASM size
PCK size
```

Optimize:

```text
texture sizes
audio
unused assets
enemy counts
particle counts
map size
```

Godot's Web export has browser-specific constraints, so browser testing should happen throughout development rather than being left until the final stage.

---

# 93. STAGE 19 — RELEASE CANDIDATE

Test:

```text
Chrome
Firefox
Edge
```

Test:

```text
desktop
small window
large window
different resolutions
```

Test:

```text
new player
returning player
save/load
browser refresh
browser close
long play session
```

---

# 94. STAGE 20 — FUTURE STEAM PORT

Only after browser version is stable.

Do NOT rewrite gameplay.

Add:

```text
Steam integration
achievements
cloud saves
controller support
native window settings
```

Keep Steam-specific functionality behind adapters.

Example:

```text
PlatformService
    ├── WebPlatform
    └── SteamPlatform
```

---

# 95. IMPORTANT MODULAR INTERFACES

Prefer interfaces/base classes such as:

```text
IStatModifier
IEquipmentEffect
ILootSource
ILootGenerator
IMapGenerator
IEnemyBehavior
IPetModifier
ITalentEffect
ISaveable
```

Example:

```text
Pet
    ↓
IPetModifier

Equipment
    ↓
IStatModifier

Talent
    ↓
IStatModifier
```

---

# 96. DEPENDENCY RULE

Low-level systems must not depend on UI.

Bad:

```text
LootGenerator → InventoryUI
```

Good:

```text
LootGenerator
    ↓
ItemInstance
    ↓
InventoryManager
    ↓
InventoryUI
```

---

# 97. ANOTHER DEPENDENCY RULE

Do not let:

```text
Player.gd
```

know detailed implementation of:

```text
LootGenerator
PetGenerator
MapGenerator
SaveManager
```

Player should communicate through managers/services.

---

# 98. CONTENT PIPELINE

Content creator workflow:

```text
Create JSON
     ↓
Run validator
     ↓
Launch game
     ↓
Content appears
```

Ideally adding:

```text
new_pet.json
```

should be enough to make a new pet available.

Adding a new enemy should require:

```text
enemy JSON
sprite
optional animation
```

not modification of multiple core scripts.

---

# 99. ADDING A NEW WEAPON

The architecture should make this possible:

```text
1. Add weapon JSON
2. Add weapon sprite
3. Add attack animation/effect
4. Add talent tree JSON
5. Add relevant affixes
```

Example future weapon:

```text
Dagger
```

Then:

```json
{
  "id": "dagger",
  "family": "melee",
  "primary_stat": "dex",
  "talent_tree": "dagger"
}
```

No rewrite of:

```text
Player
LootGenerator
Inventory
StatCalculator
SaveManager
```

---

# 100. ADDING A NEW PET

Should require:

```text
pet JSON
sprite
optional VFX
```

Example:

```json
{
  "id": "crystal_fox",
  "rarity": "epic",
  "bonuses": [
    {
      "stat": "int",
      "value": 12
    }
  ]
}
```

---

# 101. ADDING A NEW BIOME

Should require:

```text
biome JSON
tileset
environment assets
enemy table
loot table
music
optional boss
```

No changes to procedural generator.

---

# 102. ADDING A NEW RARITY

Should require:

```text
rarity JSON
```

and possibly:

```text
UI presentation
```

No rewrite of LootGenerator.

---

# 103. ADDING A NEW STAT

Example:

```text
Armor Penetration
```

Should involve:

```text
stats definition
stat calculation rule
UI display
```

rather than modifying every equipment system.

---

# 104. GAME ECONOMY

Initial currency:

```text
Gold
```

Sources:

```text
enemy drops
selling items
bosses
```

Sinks:

```text
vendor
salvage
future crafting
```

Avoid complex economy during MVP.

---

# 105. ITEM NAMING

Generated names should combine:

```text
Prefix
+
Base Item
+
Suffix
```

Example:

```text
Swift Iron Bow
Iron Bow of Precision
Ancient Arcane Staff
```

Legendary items can have fixed names.

Example:

```text
Moonpiercer
```

---

# 106. LEGENDARY SYSTEM

Legendary items should feel different from ordinary random loot.

Example:

```text
Moonpiercer

+DEX
+Critical Chance

Legendary Effect:
Every fifth ranged attack fires a second projectile.
```

Store legendary effects as modular effect definitions.

---

# 107. FUTURE SET SYSTEM

Prepare architecture for:

```text
2-piece
3-piece
4-piece
```

but DO NOT implement in MVP.

---

# 108. FUTURE SKILL SYSTEM

Prepare:

```text
SkillManager
SkillDefinition
SkillEffect
CooldownManager
```

Skills can later connect to weapon talent trees.

---

# 109. FUTURE QUEST SYSTEM

Prepare:

```text
QuestManager
QuestDefinition
QuestObjective
QuestReward
```

but keep disabled initially.

---

# 110. FUTURE ACHIEVEMENT SYSTEM

Prepare:

```text
AchievementManager
```

Potential:

```text
Kill 100 enemies
Find first legendary
Collect 10 pets
Defeat boss
Reach level 50
```

---

# 111. PERFORMANCE RULES

Do not instantiate thousands of nodes unnecessarily.

Use:

```text
object pooling
```

for:

```text
projectiles
damage numbers
particles
temporary effects
```

where profiling demonstrates the need.

Do not optimize prematurely.

Profile first.

---

# 112. BROWSER PERFORMANCE TARGET

Initial target:

```text
60 FPS desktop browser
```

Secondary:

```text
30 FPS acceptable on lower-end systems
```

Avoid designing maps that require hundreds of active enemies simultaneously.

---

# 113. DEVELOPMENT MILESTONES

## Milestone A

```text
Player moves
```

## Milestone B

```text
Player kills enemy
```

## Milestone C

```text
Enemy drops loot
```

## Milestone D

```text
Player equips loot
```

## Milestone E

```text
Stats change
```

## Milestone F

```text
Talent changes build
```

## Milestone G

```text
Pet changes build
```

## Milestone H

```text
Procedural map works
```

## Milestone I

```text
Boss works
```

## Milestone J

```text
Save/load works
```

## Milestone K

```text
Browser release works
```

---

# 114. DEFINITION OF MVP

MVP is NOT:

```text
20 biomes
100 pets
500 weapons
100 bosses
crafting
PvP
multiplayer
quests
guilds
```

MVP IS:

```text
1 polished gameplay loop
+
1 good biome
+
procedural maps
+
4-6 weapon families
+
5 rarity levels
+
interesting random loot
+
weapon talents
+
pet collection
+
egg hatching
+
boss
+
save/load
+
browser deployment
```

---

# 115. CRITICAL DESIGN GOAL

The game should be fun even without hundreds of content items.

The core loop must work:

```text
Fight
↓
Loot
↓
Compare
↓
Equip
↓
Grow
↓
Fight Stronger Enemy
↓
Find Better Loot
```

Pets add:

```text
Collection
+
Long-term progression
+
Build customization
```

Talents add:

```text
Weapon identity
+
Build decisions
```

Procedural maps add:

```text
Replayability
```

---

# 116. AGENT CODING RULES

When an AI coding agent works on this repository:

1. Read `AGENTODO.md`.
2. Read `ARCHITECTURE.md`.
3. Inspect existing implementation before changing it.
4. Never duplicate an existing manager/system.
5. Search before creating a new utility.
6. Keep data separate from code.
7. Never hard-code balance values if they belong in JSON.
8. Do not modify unrelated systems.
9. Add tests for core logic.
10. Test browser export after major platform changes.
11. Keep commits small.
12. Document architectural changes.
13. Never delete working functionality without explicit reason.
14. Never introduce a dependency without documenting it.
15. Preserve save compatibility.
16. Validate JSON after changing content.
17. Prefer composition over giant inheritance trees.

---

# 117. TODO FORMAT FOR FUTURE AGENTS

Every task should contain:

```text
## Task

## Why

## Files to inspect

## Implementation

## Acceptance criteria

## Tests

## Browser test

## Notes
```

Example:

```text
## Task

Implement procedural forest map generation.

## Why

Maps must be replayable.

## Files to inspect

scripts/procedural/
data/maps/
scenes/maps/

## Implementation

Create MapGenerator.gd.

## Acceptance criteria

Same seed produces same layout.

## Tests

Generate 100 maps.

## Browser test

Run Web export.

## Notes

Do not modify combat.
```

---

# 118. TEST MATRIX

Every release candidate:

```text
Player movement       PASS
Combat                PASS
XP                    PASS
Leveling              PASS
Equipment             PASS
Loot                  PASS
Rarity                PASS
Affixes               PASS
Talents               PASS
Pets                  PASS
Eggs                  PASS
Save                   PASS
Load                   PASS
Map generation         PASS
Map scaling            PASS
Boss                   PASS
Browser export         PASS
Browser save           PASS
```

---

# 119. FINAL ARCHITECTURE

Target architecture:

```text
                       GAME
                        │
             ┌──────────┴──────────┐
             │                     │
          PLAYER                 WORLD
             │                     │
       ┌─────┼─────┐        ┌──────┼──────┐
       │     │     │        │      │      │
    Stats Equip Talents   Maps   Enemies Boss
       │     │     │        │      │      │
       └─────┼─────┘        └──────┼──────┘
             │                     │
             └──────────┬──────────┘
                        │
                    GAME SYSTEMS
                        │
        ┌───────────────┼────────────────┐
        │               │                │
       LOOT            PETS             SAVE
        │               │                │
   LootGenerator   PetManager      SaveManager
        │               │                │
        └───────────────┼────────────────┘
                        │
                    DATA MANAGER
                        │
             ┌──────────┼──────────┐
             │          │          │
            JSON       JSON       JSON
          Weapons     Enemies      Pets
```

---

# 120. END STATE

The final system should allow the developer to add:

```text
New Weapon
New Talent
New Enemy
New Boss
New Pet
New Egg
New Biome
New Map
New Loot Table
New Affix
New Rarity
New Stat
```

without redesigning the core game.

The game should therefore behave more like a **small RPG engine with content packs** than a collection of hard-coded gameplay scripts.

---

# 121. FIRST IMPLEMENTATION ORDER

DO NOT attempt the entire game at once.

The agent should execute in this order:

```text
PHASE 1
Project + architecture
        ↓
PHASE 2
JSON/DataManager
        ↓
PHASE 3
Player + stats
        ↓
PHASE 4
Equipment
        ↓
PHASE 5
Inventory
        ↓
PHASE 6
Loot generator
        ↓
PHASE 7
Combat
        ↓
PHASE 8
Talents
        ↓
PHASE 9
Pets + eggs
        ↓
PHASE 10
Procedural maps
        ↓
PHASE 11
Bosses
        ↓
PHASE 12
Save system
        ↓
PHASE 13
UI polish
        ↓
PHASE 14
Balancing
        ↓
PHASE 15
Pixel art/audio
        ↓
PHASE 16
Web optimization
        ↓
PHASE 17
Browser release
        ↓
PHASE 18
Steam preparation
```

---

# 122. GOLDEN RULE

Do not build a giant game.

Build a **small, complete, modular game engine first**.

The first playable loop should be:

```text
Spawn
  ↓
Move
  ↓
Fight
  ↓
Kill
  ↓
Loot
  ↓
Equip
  ↓
Gain XP
  ↓
Level
  ↓
Talent
  ↓
Find Egg
  ↓
Hatch Pet
  ↓
Become Stronger
  ↓
Enter Procedural Map
  ↓
Kill Boss
  ↓
Get Better Loot
```

Once this loop is fun and technically stable, content can be expanded almost indefinitely through JSON and assets.

**Do not proceed to large-scale content production until this loop works end-to-end.**
