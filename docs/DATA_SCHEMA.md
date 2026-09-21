# DATA_SCHEMA

Every content file is a JSON object `{ "<id>": {…} }` (never arrays at root).
Validated structurally by `DataManager`, semantically by
`scripts/core/DataValidator.gd` (`tests/data/data_check.gd -- --check`).

## Schema versions (fixme.md §4–5)

- Each file carries `"_schema_version": 1` as its first key (dict-format
  option from the FIXME). Keys starting with `_` are metadata, never content:
  `DataManager`/`FeatureManager` skip them.
- Missing version → warning, assumed v1. Version ≠ 1 → hard `DATA ERROR`,
  tables stay empty so bad content can never silently load.
- This build reads **v1 only**. When a v2 format is needed: add a
  `DataMigration` module with `migrate_v1_to_v2()` per domain, bump
  `SUPPORTED_SCHEMA_VERSION`, and document the change here. Never edit v1
  semantics in place once saves reference it.

## Closed vocabularies (domain invariants, live in DataValidator)

- Weapon families: `ranged, magic, melee, defensive`
- Item slots: `main_hand, off_hand, armor, helmet, accessory`
- Affix/buff pools: `weapon, armor, accessory` (see `LootGenerator.SLOT_CATEGORIES`)
- Enemy tiers: `normal, elite, boss`
- Loot rarities: keys of `rarities.json`; pet rarities: `common, rare, epic, legendary`
- Stats: keys of `stats.json` + derived
  (`attack_speed, critical_chance, critical_damage, armor, health, mana,
  move_speed, damage, skill_power, block, physical_damage, ranged_damage, magic_damage`)
- Modifier sources: `base, level, equipment, talent, pet, buff, debuff, temporary, unknown`
- New vocabulary MUST be added to `DataValidator` — that is intentional
  centralization, not boilerplate.

## Domains

### stats.json — base attributes
`{id, name, effects[]}`. Key == id.

### weapons.json — weapon families
`{id, name, family(ranged|magic|melee|defensive), primary_stat, secondary_stats[],
talent_tree, slots[]}`. `primary_stat` should be a base stat.

### equipment.json — generatable base items
`{id, name, base_type, slot, required_level>=1, base_stats{stat: n>=0}}`.
`slot` ∈ item slots. Weapon slots (`main_hand/off_hand`) require
`base_type` ∈ `weapons.json` keys; other slots use a descriptive type.
Optional: `occupies[]` ⊆ item slots (two-handed footprint — the two-handed
rule lives HERE, never in code), `requirements[]` (`{type: level|stat,
value, stat?}`) gating equips beyond `required_level`.

### rarities.json — loot tiers
`{weight>=0, min_affixes/max_affixes (0<=min<=max<=10), bonus_buffs>=0}`.
No `id` field (the key IS the id).

### affixes.json — stat templates
`{id, stat ∈ vocab, min/max_value (0<=min<=max), is_percent?, allowed_slots[]
⊆ pools (non-empty), prefix?, suffix?}`.

### effects/buffs.json — buff + legendary-effect templates
`{id, name, description?, modifiers[{stat ∈ vocab, value numeric,
is_percent?}], min_rarity ∈ rarities, allowed_slots[]? ⊆ pools,
trigger{type,…}?, grants_name?}`. Empty `modifiers` allowed only with a
`trigger` (pure legendary effects).

### pets.json — fixed signature pets
`{id, name, rarity ∈ pet rarities, egg_type ∈ eggs, bonuses[non-empty]}`.

### pets/species.json — wild pet templates
`{id, name, egg_type ∈ eggs, rarity_weights{rarity: w} (≥1 weight > 0),
wild_pool[{stat ∈ vocab, min/max (0<=min<=max)}] (non-empty)}`.
Rarity weight 0 = excluded (e.g. bunnies never epic).

### skills.json — weapon abilities
`{id, name, family ∈ weapons keys, unlock_level 1..20, max_rank>=1,
base{damage_flat, damage_pct, cooldown_sec>=0, mana_cost>=0},
per_rank{damage_flat, damage_pct}}`. ≤10 skills per family (cap from
`skill_balance.caps`).

### eggs.json — hatchables
`{id, name, hatch_time_hours>0, min_map_level>=1,
possible_pets[{pet ∈ pets, weight>0}]?, wild_rolls[{species ∈ species,
weight>0}]?}`. At least one hatch option total.

### enemies.json — enemy definitions (not instances)
`{id, name, tier ∈ tiers, base_level>=1, health>0, damage>=0,
armor?/xp?, loot_table ∈ loot_tables, level_scaling?, phases[{health_threshold
0..100, behavior}]?, tint[r,g,b]?}`.

### maps.json — map definitions (not generated layouts)
`{id, name, biome, minimum_level>=1, maximum_level>=minimum,
room_count_min/max (1<=min<=max), enemies[non-empty, all tier normal],
elites[all tier elite], boss ("" or tier boss), scaling{…}}`.
Tier placement is enforced: elites lists with normal-tier ids fail.

### drops/enemy_drops.json — kill → egg chances
`{tiers{tier ∈ tiers: {egg_chance 0..100, egg_pool{egg ∈ eggs: weight>0} (non-empty)}}}`.

### drops/loot_tables.json — enemy loot_table registry
`{id, description?, enemy_tiers[]?}`. Exists so `enemies.loot_table` references
resolve; pool contents (equipment/egg/special) arrive with the loot-table
contract stage.

### balance/loot.json — loot numbers
`{scaling{value_per_level 0..1}, rarity_multipliers{rarity: m>0}}` — keys must
match `rarities.json` exactly both ways.

### balance/pets.json — wild scaling
`{rarity_scaling{pet rarity: {bonus_lines 1..10, value_mult>0}}}`.

### balance/player.json — player numbers
`{base_stats{stat ∈ stats}, per_level ⊆ base_stats, health/mana/move_speed
{numbers>=0}, xp_curve{base>0, growth>0, max_level 1..99}}`.

### balance/skills.json — skill economy
`{economy{unlock_every_levels>=1, points_per_unlock>=1},
caps{max_skills_per_weapon>=1, max_skill_rank>=1, max_player_level>=1}}`.
`max_player_level` MUST equal player `xp_curve.max_level`.

### config/features.json — feature flags
`{flag: bool}` (+ `_schema_version`, skipped). Unknown flags are accepted for
now (flag-dependency validation is a later stage).

### balance/inventory.json — inventory grid
`{grid{width>=1, height>=1}, stacking{max_stack>=1}}`. Slot count is content
config, not code.

### balance/combat.json — damage numbers
`{crit{base_mult>=1}, armor{constant>0}, variance{range 0..1},
limits{min_damage>=1}}`. Formula: `base×skill×weapon×buff`, crit
`×(base+crit_dmg%/100)`, variance `×(1−v+2·v·roll)`, armor `×K/(K+armor)`.
Plus `player_basic{base_damage/str_mult/range_px/cooldown_sec}`,
`enemy_scaling{hp/dmg/xp_per_level}` (all >= 0),
`enemy_ai{move_speed/aggro_range/hit_range/contact_cooldown}` (all >= 0).

## Modifier contract (fixme.md §9–11)

All stat contributors are `{stat, value, is_percent, source_type, source_id}`
(`scripts/core/StatModifier.gd`). Stamped at build: loot affixes
(`equipment:<base>`), buffs (`buff:<id>`), pet bonuses (`pet:<id>`).
Unstamped input normalizes to `unknown` with a warning — never a parallel format.
