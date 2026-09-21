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

## Dependency rules (enforced)

Systems → managers/services → data. UI never feeds generators
(`LootGenerator → ItemInstance → InventoryManager → InventoryUI`).
`Player.gd` (Stage 2) must talk through managers/services, never into
`LootGenerator/PetGenerator/MapGenerator/SaveManager` internals. Stats aggregate
in one place (`StatCalculator`, Stage 2); no ad-hoc patching.

## Next (Stage 2)

Player scene + movement + camera + HP/XP/levels + base stats + `StatCalculator`
+ input-driven controls. Then equipment/inventory/loot per `todoagent.md` §121.
