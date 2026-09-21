# FIXME.md

# LootARPGPet — Architecture Hardening & Enhancement Plan

> Repository reviewed:
> `ben-kodbiz/godot_diablo`
>
> Target:
> Godot 4.x / GDScript / Web-first / JSON-driven / modular ARPG + pet collection
>
> Purpose:
> This document is a corrective implementation plan for the current repository.
>
> DO NOT rewrite the project from scratch.
>
> Preserve working systems and progressively harden the architecture before adding large amounts of gameplay content.

---

# 0. REVIEW SUMMARY

Current repository already contains:

* Project bootstrap
* Godot Web export configuration
* Compatibility renderer configuration
* EventBus
* RNGManager
* FeatureManager
* DataManager
* GameManager
* Player/stat foundation
* Skill foundation
* Loot generation
* Item instance generation
* Pet generation
* Egg/drop generation
* JSON validation
* Headless simulation tools
* Loot simulator
* Pet simulator
* Player checks
* Architecture documentation
* Balancing documentation

The repository README currently describes the project as a Godot 4.7 browser-first modular pixel ARPG and identifies the foundation, loot core, pet core and player/stat systems as implemented. Combat, inventory UI and real egg timers are still later stages.

DO NOT destroy this foundation.

The goal of this FIXME is:

```text
Current Foundation
       ↓
Architecture Hardening
       ↓
Stable Contracts
       ↓
Gameplay Systems
       ↓
Integration Tests
       ↓
Content Expansion
```

---

# 1. PRIORITY CLASSIFICATION

Use:

```text
P0 = architecture/data integrity blocker
P1 = important before next major gameplay system
P2 = important improvement
P3 = future enhancement
```

Never work on P3 items while P0 items remain unresolved.

---

# 2. P0 — CREATE A REAL DATA CONTRACT SYSTEM

## Problem

The project is JSON-driven, but JSON is currently validated mostly by expected fields.

As the project grows this will become dangerous.

Example:

```json
{
    "id": "something",
    "stat": "dexterity"
}
```

may technically parse while the rest of the game expects:

```text
dex
```

The project needs semantic validation, not only structural validation.

## Fix

Create:

```text
scripts/core/DataValidator.gd
```

with validators:

```text
validate_weapon()
validate_equipment()
validate_rarity()
validate_affix()
validate_effect()
validate_pet()
validate_species()
validate_egg()
validate_enemy()
validate_map()
validate_skill()
validate_balance()
```

Each validator must verify:

```text
required fields
field types
allowed enum values
referenced IDs
numeric ranges
duplicate IDs
cross-file references
```

---

# 3. P0 — CROSS-REFERENCE VALIDATION

Data files reference other data files.

Examples:

```text
equipment
    ↓
weapon family

egg
    ↓
pet

map
    ↓
enemy

map
    ↓
boss

rarity
    ↓
buff

skill
    ↓
weapon family
```

Create validation for:

```text
unknown reference
missing reference
duplicate reference
circular reference
invalid reference type
```

Example error:

```text
DATA ERROR

File:
data/eggs/eggs.json

Entry:
forest_egg

Field:
possible_pets[3]

Unknown pet:
forest_dragon

Referenced object does not exist.
```

Never silently ignore missing references.

---

# 4. P0 — DATA SCHEMA VERSION

Every major JSON schema should have a version.

Example:

```json
{
    "schema_version": 1,
    "entries": []
}
```

OR, if keeping the existing dictionary-oriented format:

```json
{
    "_schema_version": 1,
    "forest_egg": {}
}
```

The chosen format must be consistent.

Document the decision in:

```text
docs/DATA_SCHEMA.md
```

---

# 5. P0 — DATA MIGRATION

Create:

```text
scripts/core/DataMigration.gd
```

Purpose:

```text
schema v1
    ↓
migration
    ↓
schema v2
```

Do not allow data format changes to silently break old content.

---

# 6. P0 — SEPARATE DEFINITION FROM INSTANCE

This distinction must remain absolute.

Definition:

```text
what an object CAN be
```

Instance:

```text
what the player ACTUALLY owns
```

Example:

```text
EquipmentDefinition
        ↓
ItemInstance
```

and:

```text
PetDefinition
        ↓
PetInstance
```

Never modify JSON definitions at runtime.

---

# 7. P0 — IMMUTABLE DATA CONTRACT

`DataManager` currently returns duplicated data, which is good.

Keep this guarantee.

Every API such as:

```text
get_weapon()
get_pet()
get_enemy()
get_map()
get_affix()
```

must return a safe copy.

Document this explicitly in:

```text
docs/ARCHITECTURE.md
```

---

# 8. P0 — CENTRALIZE STAT MODIFIERS

The existing `StatCalculator` is one of the strongest parts of the current foundation.

Keep it pure.

Current conceptual pipeline:

```text
Base
+
Level
+
Contributors
=
Final
```

Expand this carefully into:

```text
Base Stats
+
Level Growth
+
Equipment
+
Talents
+
Pets
+
Permanent Progression
+
Temporary Buffs
+
Temporary Debuffs
=
Final Stats
```

Do NOT put this logic into:

```text
Player.gd
Pet.gd
Equipment.gd
UI
```

---

# 9. P0 — ADD STAT SOURCE IDENTIFIERS

Every modifier should eventually identify its source.

Instead of:

```json
{
    "stat": "dex",
    "value": 5
}
```

prefer:

```json
{
    "source_type": "pet",
    "source_id": "forest_wolf",
    "stat": "dex",
    "value": 5,
    "is_percent": false
}
```

Possible source types:

```text
base
level
equipment
talent
pet
buff
debuff
temporary
```

This enables a future stat-debug UI.

---

# 10. P0 — STAT BREAKDOWN API

Create:

```text
StatCalculator.calculate_breakdown()
```

Return:

```text
base
level
flat
percent
final
contributors
```

Example:

```text
DEX

Base:          10
Level:         18
Equipment:     32
Pet:            5
Talent:         8
Buff:           0
------------------
Final:         73
```

This should be available to the UI and developer tools.

---

# 11. P0 — MODIFIER PIPELINE CONTRACT

Define one standard modifier format.

Example:

```json
{
    "stat": "attack_speed",
    "value": 5,
    "is_percent": true,
    "source_type": "pet",
    "source_id": "forest_wolf"
}
```

Every system producing stat modifiers must use the same contract.

Do NOT create:

```text
pet_bonus
equipment_bonus
talent_bonus
buff_bonus
```

as unrelated formats.

---

# 12. P0 — RNG CONTRACT

The current project already has a dedicated RNGManager.

Keep it.

All gameplay randomness must flow through:

```text
RNGManager
```

Do not use random functions directly in gameplay systems.

Exception:

```text
non-gameplay visual ordering
```

may use ordinary shuffle if the result does not affect game state.

---

# 13. P0 — RNG STREAMS

Enhance RNGManager with optional named streams:

```text
loot
pets
maps
enemies
events
visual
```

Example:

```text
RNGManager.stream("loot")
RNGManager.stream("maps")
```

Purpose:

A change in map generation should not unexpectedly change loot results.

---

# 14. P0 — DETERMINISTIC TEST MODE

Support:

```text
--seed=12345
```

for every simulation tool.

Also support:

```text
--seed=12345
--count=10000
```

All results must be reproducible.

---

# 15. P1 — BREAK LOOT GENERATION INTO PIPELINE MODULES

Current `LootGenerator.gd` is doing many responsibilities.

It currently handles concepts including:

```text
base selection
item level
rarity
affixes
scaling
buffs
names
IDs
```

This is acceptable for the prototype but will become a maintenance problem as the game grows.

Split conceptually into:

```text
LootGenerator
    ↓
LootContext
    ↓
BaseItemSelector
    ↓
RarityRoller
    ↓
AffixRoller
    ↓
EffectRoller
    ↓
StatScaler
    ↓
ItemNameGenerator
    ↓
ItemInstance
```

Do not necessarily create eight scripts immediately.

Refactor incrementally.

---

# 16. P1 — INTRODUCE LOOT CONTEXT

Create:

```text
LootContext
```

Containing:

```text
player_level
map_level
enemy_level
enemy_tier
map_id
biome
luck
difficulty
source_id
seed
```

Then:

```text
LootGenerator.generate(context)
```

instead of passing many independent arguments.

---

# 17. P1 — LOOT SOURCE SEPARATION

Separate:

```text
WHAT CAN DROP
```

from:

```text
HOW AN ITEM IS GENERATED
```

Loot table:

```text
enemy → possible item pools
```

Generator:

```text
item pool → actual randomized item
```

This distinction is critical.

---

# 18. P1 — LOOT TABLE CONTRACT

Create a standard:

```text
LootTableDefinition
```

with:

```text
equipment pools
currency
egg pools
special drops
rarity modifiers
level restrictions
```

Example concept:

```json
{
    "id": "forest_elite",
    "equipment_pool": "forest_equipment",
    "egg_pool": "forest_eggs",
    "rarity_modifier": 1.2
}
```

---

# 19. P1 — PREVENT INVALID AFFIX COMBINATIONS

Current affix generation uses slot eligibility and randomized pool selection.

Add:

```text
exclusive_with
requires
group
```

Example:

```json
{
    "id": "example_affix",
    "group": "movement",
    "exclusive_with": [
        "another_affix"
    ]
}
```

This prevents nonsensical combinations later.

---

# 20. P1 — AFFIX GROUPS

Introduce:

```text
affix_group
```

Examples:

```text
primary_attribute
offensive
defensive
utility
resource
special
```

This allows future loot rules such as:

```text
maximum 2 primary attributes
maximum 1 special affix
```

without changing generator code.

---

# 21. P1 — RARITY SHOULD BE DATA ONLY

Keep rarity configuration in:

```text
data/rarities/
```

Generator code must not contain assumptions like:

```text
legendary = 5 affixes
```

unless that information is loaded from JSON.

The current project already follows this direction; preserve it.

---

# 22. P1 — LOOT ROLL RECORD

For debugging, allow a generated item to optionally retain:

```text
generation_seed
loot_table
source_id
item_level
rarity_roll
affix_rolls
effect_rolls
```

Do NOT necessarily save all of this in production.

Debug builds may retain it.

---

# 23. P1 — PET GENERATOR RESPONSIBILITY REDUCTION

The current pet generator handles:

```text
fixed pets
wild pets
rarity rolls
bonus generation
egg drops
```

Separate conceptually:

```text
PetGenerator
EggGenerator
PetDropGenerator
PetModifierProvider
```

The exact refactor can happen gradually.

---

# 24. P1 — PET INSTANCE IDENTITY

A generated pet needs:

```text
instance_id
species_id
rarity
egg_source
bonuses
creation_timestamp
```

Do not identify a pet only by:

```text
species + rarity
```

because two copies should be distinct instances if collection depth is expanded later.

---

# 25. P1 — PET COLLECTION MANAGER

Create:

```text
PetCollectionManager
```

Responsibilities:

```text
add pet
remove pet
own pet
count species
count rarity
active pet
collection discovery
```

PetGenerator should generate.

CollectionManager should own.

---

# 26. P1 — EGG INSTANCE

Separate:

```text
EggDefinition
```

from:

```text
EggInstance
```

EggInstance:

```text
instance_id
egg_type
started_at
duration_seconds
state
```

States:

```text
stored
incubating
ready
hatched
```

---

# 27. P1 — REAL EGG TIMER

Do NOT rely on:

```text
Timer node
```

as the authoritative hatch state.

Store timestamp data.

On load:

```text
now - started_at >= duration
```

Then:

```text
READY
```

The browser can close and reopen safely.

---

# 28. P1 — CLOCK ABSTRACTION

Create:

```text
ClockService
```

Instead of directly calling system time everywhere.

Why:

```text
production clock
test clock
simulated clock
```

can then be swapped.

Tests can instantly simulate:

```text
+1 hour
+24 hours
+7 days
```

without waiting.

---

# 29. P1 — SAVE SYSTEM BEFORE DEEP CONTENT

Do not wait until the end to implement save/load.

Create the save contract before inventory/pet systems become large.

```text
SaveData
    version
    player
    equipment
    inventory
    talents
    pets
    eggs
    progression
    settings
```

---

# 30. P1 — SAVE SERIALIZATION CONTRACT

Every persistent system should implement:

```text
serialize()
deserialize()
```

or an equivalent central adapter.

Do not make SaveManager know every private field of every system.

---

# 31. P1 — SAVE MIGRATION TESTS

For every save schema version:

```text
old save
    ↓
load
    ↓
migrate
    ↓
new save
    ↓
validate
```

Create fixtures:

```text
tests/save/fixtures/
    save_v1.json
    save_v2.json
```

---

# 32. P1 — INVENTORY DOMAIN MODEL

Before building inventory UI, implement the domain layer:

```text
Inventory
    add
    remove
    contains
    find
    move
    sort
    filter
```

UI should not contain inventory rules.

---

# 33. P1 — EQUIPMENT MANAGER

Create:

```text
EquipmentManager
```

It owns:

```text
equipped instances
slot validation
equip
unequip
stat contributors
```

The Player node should not directly manipulate equipment internals.

---

# 34. P1 — EQUIPMENT RULES AS DATA

Equipment compatibility should be data-driven.

Represent:

```text
allowed_slots
occupies_slots
required_tags
blocked_tags
```

This makes future content extensible.

---

# 35. P1 — ITEM REQUIREMENTS

Add a generic requirement system:

```text
requirements[]
```

Possible future requirements:

```text
minimum level
stat requirement
talent requirement
quest requirement
achievement requirement
```

Do not hard-code each requirement into equipment code.

---

# 36. P1 — SKILL/TALENT TERMINOLOGY

The repository currently uses `skills`, while the original game specification uses `talents`.

Choose one conceptual model.

Recommended:

```text
Talent = progression node
Skill = executable player ability
```

Therefore:

```text
TalentManager
SkillManager
```

should be separate.

Example:

```text
Talent:
+5% ability power

Skill:
Cast Arcane Burst
```

Do not mix these responsibilities.

---

# 37. P1 — WEAPON/FAMILY DATA MODEL

Keep equipment identity separate from progression identity.

Concept:

```text
Item:
Iron Example

Equipment Type:
example_family

Family:
ranged / magic / melee / defensive

Progression Tree:
example_tree
```

The talent/skill system should depend on the family/tree ID rather than a specific item name.

This is what makes future content scalable.

---

# 38. P1 — BUILD PROFILE

Create:

```text
BuildProfile
```

containing:

```text
equipped equipment
active pet
talent allocation
active skills
stat summary
```

This will eventually allow:

```text
save build
load build
compare build
```

---

# 39. P1 — EVENTBUS GOVERNANCE

The EventBus is useful, but unrestricted global events can become spaghetti.

Document:

```text
event naming convention
payload schema
publisher
subscribers
```

Example:

```text
player_level_up
{
    "old_level": 4,
    "new_level": 5
}
```

Avoid events containing entire mutable objects unless necessary.

---

# 40. P1 — EVENT TYPES

Separate:

```text
domain events
UI events
debug events
```

Do not let UI-only events become game-system dependencies.

---

# 41. P1 — GAME MANAGER SHOULD STAY SMALL

Do not turn:

```text
GameManager.gd
```

into a god object.

It should coordinate lifecycle.

It should NOT become:

```text
PlayerManager
LootManager
SaveManager
MapManager
PetManager
CombatManager
```

all inside one script.

---

# 42. P1 — MAIN SCENE MUST REMAIN THIN

`Main.gd` should only:

```text
bootstrap
create world
start game
```

It should not contain:

```text
loot logic
pet logic
stat calculations
inventory rules
map generation
```

---

# 43. P1 — UI MUST NOT OWN GAME STATE

Bad:

```text
InventoryPanel
    modifies player inventory directly
```

Good:

```text
InventoryPanel
    ↓
InventoryManager
    ↓
state changed
    ↓
EventBus
    ↓
InventoryPanel refresh
```

---

# 44. P1 — HEADLESS TEST SUITE

Current simulation tools are a strong foundation.

Expand to:

```text
tests/data/
tests/player/
tests/loot/
tests/pets/
tests/inventory/
tests/equipment/
tests/progression/
tests/save/
tests/maps/
tests/combat/
```

Every new subsystem needs at least:

```text
happy path
invalid data
edge case
deterministic test
```

---

# 45. P1 — TEST DATA FIXTURES

Do not rely only on production JSON for unit tests.

Create:

```text
tests/fixtures/
```

with minimal datasets.

Example:

```text
minimal_player.json
minimal_pet.json
minimal_egg.json
minimal_item.json
minimal_map.json
```

This makes tests faster and more deterministic.

---

# 46. P1 — JSON DATA LINTER

Create:

```text
tests/data/data_check.gd
```

Command:

```text
--check
```

It must validate ALL data.

Expected:

```text
DATA CHECK: PASS
```

No warnings should be hidden.

---

# 47. P1 — MASTER CI CHECK

Create a single command:

```text
./tools/check.sh
```

or equivalent Godot-only launcher.

It should run:

```text
data validation
loot check
pet check
player check
skill check
save check
headless boot
```

Expected final output:

```text
================================
PROJECT CHECK: PASS
================================
```

---

# 48. P1 — WEB SMOKE TEST

The project is browser-first.

Every major milestone should verify:

```text
Godot editor run
headless run
Web export
Web launch
```

Do not leave Web validation until release.

---

# 49. P1 — EXPORT ARTIFACT CHECK

After Web export verify:

```text
index.html exists
PCK exists
WASM exists
assets load
game boots
no missing resources
```

---

# 50. P1 — ERROR POLICY

No silent failure for:

```text
missing JSON
missing item
missing pet
missing map
missing enemy
missing skill
invalid rarity
invalid stat
```

Use:

```text
push_error()
```

for fatal data errors.

Use:

```text
push_warning()
```

for recoverable conditions.

Do not use:

```text
print()
```

as the only error mechanism.

---

# 51. P2 — REPLACE MAGIC STRINGS

Centralize IDs/enums where appropriate.

Avoid repeated literals:

```text
"normal"
"legendary"
"weapon"
"pet"
"common"
```

However:

DO NOT replace every JSON identifier with a giant GDScript enum.

JSON IDs should remain data-driven.

Use constants only for engine/domain invariants.

---

# 52. P2 — TYPE SAFETY

The README already identifies dynamic-return typing as a common Godot/GDScript issue.

Continue using explicit types for dynamic API calls.

Prefer:

```gdscript
var definition: Dictionary = DataManager.get_pet(id)
```

over:

```gdscript
var definition := DataManager.get_pet(id)
```

where the return type is Variant.

---

# 53. P2 — REDUCE DICTIONARY SPRAWL

The project currently relies heavily on:

```text
Dictionary
Array
```

This is useful for JSON.

But runtime systems should gradually introduce typed domain objects where complexity warrants it.

Recommended:

```text
ItemInstance
PetInstance
EggInstance
LootContext
StatModifier
SaveData
```

Do not convert every JSON object into a Resource.

Use typed runtime objects selectively.

---

# 54. P2 — RUNTIME OBJECT CONTRACTS

Every important runtime object should expose a small API.

Example:

```text
ItemInstance
    get_id()
    get_display_name()
    get_rarity()
    get_stat_modifiers()
    serialize()
```

Avoid external code reaching into:

```text
item["some_internal_field"]
```

everywhere.

---

# 55. P2 — ITEM DISPLAY SEPARATION

`ItemInstance` should eventually stop owning too much presentation logic.

Separate:

```text
ItemInstance
```

from:

```text
ItemFormatter
```

ItemFormatter:

```text
name
tooltip
rarity presentation
stat display
comparison
```

This keeps domain objects independent of UI.

---

# 56. P2 — PET DISPLAY SEPARATION

Likewise:

```text
PetInstance
```

should represent data.

A separate formatter/view-model should handle:

```text
pet name
rarity label
bonus text
collection display
```

---

# 57. P2 — LOCALIZATION PREPARATION

Do not embed all user-facing text deeply in JSON logic.

Use:

```text
localization keys
```

Example:

```text
item.iron_bow.name
pet.forest_wolf.name
rarity.legendary.name
```

This makes future multilingual support easier.

---

# 58. P2 — CONTENT IDs MUST NEVER CHANGE CASUALLY

Once released, IDs become persistent identifiers.

Do not casually rename:

```text
pet ID
item ID
egg ID
map ID
skill ID
```

because save files may depend on them.

If an ID must change:

```text
migration alias
```

must be provided.

---

# 59. P2 — ADD ID ALIAS SYSTEM

Future save compatibility:

```json
{
    "old_id": "forest_wolf_old",
    "new_id": "forest_wolf"
}
```

Save migration can resolve old IDs.

---

# 60. P2 — CONTENT PACK MODEL

Long-term architecture should support:

```text
base content
+
content pack
+
seasonal content
```

Example:

```text
data/content/base/
data/content/forest/
data/content/events/
```

Do not implement a complicated plugin loader yet.

Just keep the data architecture compatible with this future.

---

# 61. P2 — FEATURE FLAGS NEED VALIDATION

Feature flags should be validated.

If code checks:

```text
FeatureManager.is_enabled("pets")
```

and JSON accidentally contains:

```text
petz
```

the system should report:

```text
UNKNOWN FEATURE FLAG
```

---

# 62. P2 — FEATURE DEPENDENCIES

Some features depend on others.

Example:

```text
pet_collection
    requires pets

pet_hatching
    requires pets + eggs

pet_synergy
    requires pets + stat modifiers
```

Represent dependencies.

If a feature is disabled:

```text
dependent feature automatically disabled
```

or produce a clear startup error.

---

# 63. P2 — MAP SYSTEM CONTRACT

Before procedural maps are implemented, define:

```text
MapDefinition
MapContext
GeneratedMap
RoomDefinition
SpawnDefinition
MapSeed
```

Keep these separate.

---

# 64. P2 — PROCEDURAL GENERATOR CONTRACT

Create:

```text
IMapGenerator
```

Concept:

```text
generate(context) -> GeneratedMap
```

Then future algorithms can be swapped:

```text
RoomGraphGenerator
DungeonGenerator
BranchingGenerator
ArenaGenerator
```

without changing MapManager.

---

# 65. P2 — MAP VALIDATION

Every generated map must validate:

```text
player spawn exists
exit exists
boss reachable
all mandatory rooms reachable
no overlapping rooms
no invalid spawn positions
```

If invalid:

```text
discard seed
generate another
```

with a maximum retry count.

---

# 66. P2 — MAP SEED RECORDING

Generated map should retain:

```text
map_id
seed
player_level
map_level
generation_version
```

The generation version is important.

If the generator changes:

```text
generation_version 1
generation_version 2
```

old seeds remain understandable.

---

# 67. P2 — MAP GENERATION VERSION

Save:

```text
generation_version
```

with the generated map context.

Never assume a seed alone permanently identifies a layout after the algorithm changes.

---

# 68. P2 — ENEMY DEFINITION VS ENEMY INSTANCE

Separate:

```text
EnemyDefinition
```

from:

```text
EnemyInstance
```

Definition:

```text
base health
base stats
behavior ID
loot table
```

Instance:

```text
level
current health
spawn position
runtime state
```

---

# 69. P2 — ENEMY BEHAVIOR STRATEGY

Do not make one giant:

```text
Enemy.gd
```

Eventually use:

```text
BehaviorController
```

with strategies:

```text
Idle
Patrol
Chase
Attack
Retreat
BossPhase
```

Data chooses the behavior.

---

# 70. P2 — STATUS EFFECT SYSTEM

Prepare a generic system:

```text
StatusEffect
StatusEffectManager
```

with data definitions.

Possible future types:

```text
slow
stun
burn
poison
silence
shield
```

Do not implement a large list before combat exists.

---

# 71. P2 — DAMAGE SYSTEM SEPARATION

Keep damage calculation independent from:

```text
Player scene
Enemy scene
UI
animations
```

Concept:

```text
DamageRequest
    ↓
DamageCalculator
    ↓
DamageResult
```

This makes combat testable headlessly.

---

# 72. P2 — DAMAGE RESULT

A damage result should eventually contain:

```text
amount
damage_type
critical
blocked
absorbed
source
target
```

UI can consume the result without knowing calculation internals.

---

# 73. P2 — COMBAT EVENT MODEL

Prefer:

```text
attack_started
hit_confirmed
damage_applied
entity_defeated
```

instead of UI-specific events.

This makes combat replay/debugging easier.

---

# 74. P2 — REPLAYABLE DEBUG EVENTS

Eventually support recording:

```text
seed
input
events
```

for debugging.

Not required for MVP.

---

# 75. P2 — PERFORMANCE

Do not prematurely optimize.

First profile.

Potential future optimizations:

```text
object pooling
enemy activation radius
effect pooling
projectile pooling
UI redraw reduction
map chunk loading
```

Only implement after measurements demonstrate need.

---

# 76. P2 — NODE LIFETIME OWNERSHIP

Every dynamically created Node must have a clear owner.

Document:

```text
who creates it
who removes it
when it is freed
```

This becomes important once enemies, loot, projectiles and map rooms are dynamic.

---

# 77. P2 — RESOURCE CLEANUP

When changing maps:

```text
old enemies freed
old loot freed
old effects freed
old map nodes freed
```

No references should keep previous maps alive.

---

# 78. P2 — UI SIGNAL CLEANUP

When UI panels connect to EventBus:

```text
connect
disconnect
```

appropriately.

Avoid duplicate subscriptions after opening/closing panels repeatedly.

---

# 79. P2 — DEBUG UI SEPARATION

Current developer simulator panels are useful.

Keep them behind:

```text
OS.is_debug_build()
```

and/or:

```text
FeatureManager
```

Never ship developer controls accidentally.

---

# 80. P2 — DEBUG COMMAND SERVICE

Instead of adding debug code throughout the game, create:

```text
DebugService
```

Commands:

```text
spawn
give
level
teleport
regenerate
simulate
dump_stats
dump_save
```

Only debug builds expose it.

---

# 81. P2 — BALANCE SIMULATION

Current loot/pet simulators are excellent.

Expand to:

```text
10
100
1,000
10,000
100,000
```

where practical.

Generate CSV/JSON reports:

```text
rarity_distribution
average_item_power
average_stat_value
pet_distribution
egg_distribution
XP_per_hour
```

---

# 82. P2 — BALANCE REGRESSION

Store expected ranges.

Example:

```text
legendary_rate:
0.3% - 0.8%
```

A balance check fails if:

```text
actual < minimum
actual > maximum
```

This prevents accidental economy changes.

---

# 83. P2 — POWER SCORE

Eventually create a generic:

```text
ItemPowerEvaluator
```

for developer tooling.

It should NOT dictate what players must equip.

Use it to:

```text
compare generated items
detect extreme rolls
identify broken affixes
```

---

# 84. P2 — CONTENT QUALITY CHECK

Create automated checks for:

```text
unused item IDs
unused pet IDs
unused enemy IDs
unused map IDs
unused affixes
unused skills
```

Report:

```text
ORPHAN CONTENT
```

---

# 85. P2 — DUPLICATE NAME CHECK

Warn when:

```text
two items share identical display names
two pets share identical names
two maps share identical names
```

IDs can remain unique.

---

# 86. P2 — DUPLICATE EFFECT CHECK

Warn when two effects have identical IDs.

Never silently overwrite dictionary entries.

---

# 87. P2 — JSON FILE SIZE

If individual JSON files become very large:

```text
split by domain
```

For example:

```text
pets/common.json
pets/rare.json
pets/boss.json
```

Do not prematurely split tiny files.

---

# 88. P2 — DOCUMENTATION SPLIT

`todoagent.md` is currently the master implementation document and is very large.

Keep it as the master roadmap, but move detailed implementation contracts into:

```text
docs/ARCHITECTURE.md
docs/DATA_SCHEMA.md
docs/LOOT_DESIGN.md
docs/PET_DESIGN.md
docs/COMBAT_DESIGN.md
docs/MAP_GENERATION.md
docs/SAVE_FORMAT.md
docs/UI_ARCHITECTURE.md
docs/TESTING.md
```

The agent should read:

```text
AGENTS.md
FIXME.md
relevant docs
```

rather than loading the entire 3,900-line roadmap for every task.

---

# 89. P1 — AGENT TASK BOUNDARIES

AI agents must NOT implement multiple major systems in one task.

Bad:

```text
Implement combat + inventory + maps + pets.
```

Good:

```text
Implement Inventory domain model.
```

Then:

```text
Implement EquipmentManager.
```

Then:

```text
Implement inventory UI.
```

---

# 90. P1 — AGENT MUST INSPECT BEFORE EDIT

Before modifying a system:

```text
read existing implementation
read architecture contract
read relevant JSON
read relevant tests
```

Then make the smallest change that satisfies the task.

---

# 91. P1 — AGENT MUST NOT REWRITE WORKING SYSTEMS

If an existing system passes:

```text
LOOT CHECK
PET CHECK
PLAYER CHECK
```

do not rewrite it simply because another architecture looks cleaner.

Refactor only when:

```text
measurable problem
clear architectural conflict
new requirement
testability problem
```

exists.

---

# 92. P1 — ACCEPTANCE CRITERIA REQUIRED

Every TODO item must contain:

```text
Implementation
Tests
Acceptance Criteria
Files Changed
Regression Checks
```

No vague tasks such as:

```text
"Improve loot"
```

---

# 93. P1 — CHANGE IMPACT REPORT

After every significant task the agent must report:

```text
Files changed:
Systems affected:
JSON changed:
Tests added:
Tests executed:
Known limitations:
```

---

# 94. P1 — REGRESSION GATE

Before marking any task complete:

```text
DATA CHECK
LOOT CHECK
PET CHECK
PLAYER CHECK
HEADLESS BOOT
```

must pass.

Once new systems exist, add:

```text
INVENTORY CHECK
EQUIPMENT CHECK
SAVE CHECK
MAP CHECK
COMBAT CHECK
```

---

# 95. P1 — NO FEATURE WITHOUT TEST

New core system:

```text
code
+
test
+
documentation
```

all required.

---

# 96. P1 — NO BALANCE WITHOUT SIMULATION

If changing:

```text
loot probability
XP
pet rarity
egg timing
stat growth
item scaling
```

the agent must run the corresponding simulator.

---

# 97. P1 — NO CONTENT WITHOUT VALIDATION

Every new:

```text
item
pet
egg
enemy
map
skill
affix
effect
```

must pass the data validator.

---

# 98. P1 — VERSION CONTROL

Keep commits small.

Recommended:

```text
feat(data):
feat(loot):
feat(pets):
feat(player):
feat(inventory):
feat(save):
refactor(core):
test(loot):
test(pets):
docs:
fix:
```

---

# 99. P1 — ONE SYSTEM PER COMMIT

Prefer:

```text
feat: add inventory domain model
```

instead of:

```text
feat: implement entire game
```

---

# 100. P2 — GIT TAGS

Create milestones:

```text
v0.1-foundation
v0.2-loot
v0.3-player
v0.4-inventory
v0.5-combat
v0.6-pets
v0.7-maps
v0.8-save
v0.9-alpha
v1.0-browser
```

Exact numbering can change.

---

# 101. P2 — CURRENT IMPLEMENTATION ORDER

Based on the current repository state, DO NOT restart at Stage 0.

Use:

```text
CURRENT
Foundation
Loot
Pet
Player
    ↓
FIXME P0
    ↓
Equipment domain
    ↓
Inventory domain
    ↓
Equipment integration
    ↓
Combat
    ↓
Talent/Skill integration
    ↓
Pet collection + timers
    ↓
Procedural maps
    ↓
Bosses
    ↓
Save/load
    ↓
UI
    ↓
Balance
    ↓
Art/audio
    ↓
Web release
```

---

# 102. NEXT IMPLEMENTATION TASKS

## TASK 01 — Data Validator

Priority:

```text
P0
```

Acceptance:

```text
all JSON files validate
unknown references detected
duplicate IDs detected
invalid enums detected
invalid numeric ranges detected
```

---

## TASK 02 — Data Schema Documentation

Priority:

```text
P0
```

Create:

```text
docs/DATA_SCHEMA.md
```

Document every JSON domain.

---

## TASK 03 — Stat Modifier Contract

Priority:

```text
P0
```

Create:

```text
StatModifier
```

and update:

```text
equipment
pets
skills/talents
buffs
```

to use it.

---

## TASK 04 — Stat Breakdown

Priority:

```text
P0
```

Add:

```text
calculate_breakdown()
```

and developer display.

---

## TASK 05 — LootContext

Priority:

```text
P1
```

Create:

```text
scripts/loot/LootContext.gd
```

---

## TASK 06 — Loot Pipeline Refactor

Priority:

```text
P1
```

Refactor without changing existing generated results unnecessarily.

Existing:

```text
Loot CHECK
```

must remain passing.

---

## TASK 07 — Pet/Egg Separation

Priority:

```text
P1
```

Separate generation from persistence and timer state.

---

## TASK 08 — ClockService

Priority:

```text
P1
```

Add testable time abstraction.

---

## TASK 09 — Save Contract

Priority:

```text
P1
```

Define versioned save format.

---

## TASK 10 — Inventory Domain

Priority:

```text
P1
```

No UI initially.

---

## TASK 11 — Equipment Manager

Priority:

```text
P1
```

Integrate with stat contributors.

---

## TASK 12 — Inventory UI

Priority:

```text
P1
```

Only after the domain model passes tests.

---

## TASK 13 — Combat Domain

Priority:

```text
P1
```

Keep calculations independent of UI.

---

## TASK 14 — Combat Scene Integration

Priority:

```text
P1
```

Connect the already-tested domain logic to scenes.

---

## TASK 15 — Talent/Skill Integration

Priority:

```text
P1
```

Separate:

```text
progression
```

from:

```text
execution
```

---

# 103. DEFINITION OF DONE

A task is NOT complete because:

```text
Godot opens
```

It is complete only when:

```text
Implementation works
AND
Data validates
AND
Unit/simulation tests pass
AND
Existing regression tests pass
AND
Headless boot passes
AND
Web build still works
AND
Documentation is updated
```

---

# 104. ARCHITECTURAL RED FLAGS

Agents MUST stop and report instead of proceeding if they encounter:

```text
Player.gd > 500 lines
GameManager becoming a god object
LootGenerator containing UI code
PetGenerator storing persistent player state
UI directly modifying game internals
balance numbers hard-coded in GDScript
duplicate RNG systems
multiple incompatible stat modifier formats
JSON definitions being mutated
save code scattered across gameplay scripts
system time accessed everywhere
map generation dependent on UI
```

---

# 105. RED FLAG: JSON LOGIC LEAK

If GDScript contains:

```gdscript
if rarity == "legendary":
    ...
```

ask:

```text
Does this belong in JSON?
```

If yes, move it to data.

Code should implement rules.

JSON should configure content and balance.

---

# 106. RED FLAG: GOD OBJECT

If a new feature requires:

```text
GameManager.gd
Player.gd
Main.gd
```

all to change, stop and evaluate whether the feature needs its own manager/service.

---

# 107. RED FLAG: UI DEPENDENCY

Never introduce:

```text
core → UI
```

dependency.

Allowed:

```text
UI → domain/system
```

Not:

```text
domain → UI
```

---

# 108. RED FLAG: DUPLICATED CALCULATION

If the same calculation appears in:

```text
Player
UI
Simulator
Enemy
Pet
```

move it into a domain calculator.

---

# 109. RED FLAG: RANDOMNESS OUTSIDE RNG

If production gameplay introduces:

```text
randf()
randi()
randomize()
```

outside RNGManager:

```text
STOP
```

and review it.

---

# 110. RED FLAG: DIRECT JSON ACCESS EVERYWHERE

Avoid:

```gdscript
data["pets"]["wolf"]["bonuses"]
```

throughout the project.

Prefer:

```text
DataManager
```

and typed domain APIs.

---

# 111. RED FLAG: SAVE FORMAT COUPLING

Do not serialize entire runtime Nodes directly.

Save:

```text
data
```

not:

```text
scene tree
```

---

# 112. RED FLAG: SCENE AS DATABASE

Do not store persistent game state primarily in `.tscn`.

Scenes define presentation/runtime structure.

JSON/save data define persistent game state.

---

# 113. RED FLAG: CONTENT CODE COUPLING

Adding a new content object should NOT require editing:

```text
Player.gd
GameManager.gd
Main.gd
```

unless the new feature genuinely introduces a new system.

---

# 114. FINAL TARGET ARCHITECTURE

```text
                    ┌───────────────────┐
                    │        UI         │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Application Layer │
                    │                   │
                    │ MapManager        │
                    │ InventoryManager  │
                    │ EquipmentManager  │
                    │ PetManager        │
                    │ TalentManager     │
                    │ SaveManager       │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │   Domain Layer    │
                    │                   │
                    │ LootGenerator     │
                    │ StatCalculator    │
                    │ DamageCalculator  │
                    │ MapGenerator      │
                    │ PetGenerator      │
                    │ XP Calculator     │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │    Data Layer     │
                    │                   │
                    │ JSON definitions  │
                    │ Balance tables    │
                    │ Content registry  │
                    └─────────┬─────────┘
                              │
                    ┌─────────▼─────────┐
                    │ Infrastructure    │
                    │                   │
                    │ RNG               │
                    │ Clock             │
                    │ Save IO           │
                    │ EventBus          │
                    └───────────────────┘
```

---

# 115. FINAL PRINCIPLE

The project should become:

```text
DATA
    ↓
DOMAIN RULES
    ↓
GAME SYSTEMS
    ↓
PRESENTATION
```

Never:

```text
UI
    ↓
random JSON access
    ↓
Player.gd
    ↓
GameManager
    ↓
another UI
```

The first is an engine.

The second becomes spaghetti.

---

# 116. IMMEDIATE AGENT INSTRUCTION

The next agent MUST NOT start implementing new maps, large enemy rosters, large pet rosters, or visual polish.

First execute:

```text
FIXME-01 Data Validator
FIXME-02 Data Schema
FIXME-03 Stat Modifier Contract
FIXME-04 Stat Breakdown
FIXME-05 LootContext
```

Then run:

```text
DATA CHECK
LOOT CHECK
PET CHECK
PLAYER CHECK
HEADLESS BOOT
WEB EXPORT
```

Only when all pass should the agent proceed to:

```text
Equipment
Inventory
Combat
Talent/Skill integration
Pet collection/timers
Procedural maps
```

---

# 117. SUCCESS CONDITION

The architecture hardening phase is complete when:

```text
[PASS] JSON validation
[PASS] Cross-reference validation
[PASS] Stat modifier contract
[PASS] Stat breakdown
[PASS] Deterministic RNG
[PASS] Loot simulation
[PASS] Pet simulation
[PASS] Player simulation
[PASS] Headless boot
[PASS] Web export
```

and the following statement is true:

> A developer can add a new content definition without modifying unrelated gameplay systems.

That is the primary architectural quality gate for this project.
