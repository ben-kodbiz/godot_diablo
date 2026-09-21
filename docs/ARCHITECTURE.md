# ARCHITECTURE

Source of truth: `todoagent.md` (§2 layered architecture, §95–99 modularity rules).
This file tracks what is actually built; update it whenever structure changes.

## Built (Stage 0 + 1)

- Autoloads (in order): `EventBus → RNGManager → FeatureManager → DataManager → GameManager`
  (`scripts/core/`, wired in `project.godot`).
- `EventBus`: signals only (`player_level_up, item_dropped/equipped/salvaged,
  enemy/boss_killed, pet_obtained, egg_hatched, talent_upgraded, map_completed`).
- `RNGManager`: `random_int/float, weighted_choice, seeded_random`, `set_seed`.
- `FeatureManager`: `data/config/features.json` (`pets/bosses/legendary_items/
  procedural_maps` on; `crafting/quests` off).
- `DataManager`: loads + validates `stats/weapons/rarities/affixes` (required) and
  `pets/enemies/maps` (stubbed); getters return deep duplicates.
- Entry: `scenes/main/Main.tscn` → `scripts/main/Main.gd` (bootstrap proof only).

## Built (Stage 5 loot core)

- `scripts/loot/LootGenerator.gd` (RefCounted, `_init(rng, data)`): roll pipeline
  base → level → rarity (weighted) → affix count → pool (`allowed_slots`) →
  values → level scaling → rarity multiplier → buffs (`min_rarity` + slots) →
  name → `itm_*` id. No balance numbers in code.
- `scripts/loot/ItemInstance.gd`: assembles item dicts (never mutates bases),
  rarity labels/colors, `+19 DEX` / `+5% Attack Speed` formatting, tooltip text.
- Content: `data/equipment/equipment.json` (7 bases), `data/effects/buffs.json`
  (7 buffs + Moonpiercer legendary trigger), `data/balance/loot.json` (scaling +
  rarity multipliers), rarities carry `bonus_buffs` (epic/legendary: 1).
- Tools: headless `tests/loot/loot_simulator.gd` (`--rarity/--base/--level/
  --count/--seed`, plus `--check` 10k validation) and in-game dev-only
  `scripts/ui/LootSimulatorPanel.gd` (debug builds only). Scheme: `docs/BALANCING.md`.

## Built (pets + eggs + drops + maps)

- `scripts/pets/PetGenerator.gd` (`_init(rng, data)`): `hatch(egg_id)` (weighted
  fixed `possible_pets` + wild `wild_rolls`), `hatch_wild`/`roll_wild`
  (species × rarity scaling → `species_rarity` ids, clamped to pool),
  `roll_wild_rarity`, `roll_egg_drop(tier, map_level)`, `hatch_odds`.
- `scripts/pets/PetInstance.gd`: `pet_*` ids, rarity labels/colors, bonus text.
- Content: 6 fixed pets + 6 wild species (common→epic; dragon stays the lone
  legendary), 6 eggs (2h–48h, mixed fixed/wild), 6 tiered enemies, 3 forest
  maps (Edge/Depths/boss level), tier drop table
  (normal 0.5% / elite 5% / boss 25% egg chance).
- Tools: headless `tests/pets/pet_simulator.gd` (`--egg/--count`, `--drops
  --tier/--map-level/--kills`, `--check`) + dev-only
  `scripts/ui/PetSimulatorPanel.gd` (hatch + 100-kill drop test).

## Built (Stage 2 player)

- `scenes/player/Player.tscn` (CharacterBody2D + placeholder sprite, collision,
  smoothing Camera2D, `CharacterStats` node) driven by `scripts/character/Player.gd`
  — movement only, via `Input.get_vector(...)`. Instanced in Main.
- `scripts/character/CharacterStats.gd`: level/XP (curve from
  `data/balance/player.json`), HP/mana, `set_contributors(source, mods)` hook
  for equipment/talents/pets/buffs, emits `player_level_up` through EventBus.
- `scripts/character/StatCalculator.gd`: pure static
  `(base + growth + flats) × (1 + percents)` + `xp_for_level`.
- Check: `tests/player/player_check.gd` (calculator math, live movement,
  level-up/signal, HP rules, contributor hook).

## Built (skills)

- `scripts/skills/SkillManager.gd` (`_init(data)`): point economy
  (1 per 3 levels, L1 starts with 1), unlock/upgrade with point + level +
  family + max-rank guards, `skill_power(id)` combat numbers, `family_view`
  for UI, `reset()` for respec. `_ranks` is plain save data.
- Content: 20 skills (5 per bow/staff/sword/shield family, unlocks 1/4/7/10/13),
  `data/balance/skills.json` (cadence, 10-per-weapon / rank-5 / level-20 caps).
- Tool: `tests/skills/skill_check.gd` (`--weapon/--level` tree view, `--check`
  data + economy + math + cap validation). No in-game panel yet — skill UI
  lands with the talent/UI stage.

## Dependency rules (enforced)

Systems → managers/services → data. UI never feeds generators
(`LootGenerator → ItemInstance → InventoryManager → InventoryUI`).
`Player.gd` (Stage 2) must talk through managers/services, never into
`LootGenerator/PetGenerator/MapGenerator/SaveManager` internals. Stats aggregate
in one place (`StatCalculator`, Stage 2); no ad-hoc patching.

## Next (Stage 3 equipment)

EquipmentManager, 7 slots, equip/unequip, two-handed rule, equipment stat
modifiers feeding `StatCalculator`. Then inventory/combat per `todoagent.md` §121.
