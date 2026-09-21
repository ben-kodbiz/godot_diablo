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

## Built (equipment domain — fixme.md TASK 11)

- `scripts/equipment/EquipmentManager.gd` (`_init(data)`): 7 slots
  (accessory→first-free pairing, pet reserved), `equip()` returning
  `{ok, reason, displaced[]}` with symmetric footprint displacement,
  `requirement_error()` (level + generic `requirements[]`), `to_modifiers()`
  re-stamped `equipment:<uid>` (original stamp in `via`), `serialize()/
  deserialize()` save contract. Player integration is a separate later step.
- Items carry `base_stats` snapshot + `occupies` footprint from their base
  (`ItemInstance`); the two-handed rule lives in equipment JSON, never in code.
- Check: `tests/equipment/equipment_check.gd` (slots, requirements, 2H both
  directions, accessories, pet guard, modifier math, save round-trip + corrupt).

## Built (inventory domain — fixme.md TASK 10)

- `scripts/inventory/InventoryManager.gd` (`_init(data, w=0, h=0)`): grid slots
  (10×6 from `data/balance/inventory.json`), add (stack-merge then first-free,
  duplicate-uid rejection), remove/contains/find/filter, move/swap, rarity sort,
  `serialize()/deserialize()` with uid + capacity validation. Emits no EventBus
  signals yet (event governance is a later stage). No UI — TASK 12.
- Check: `tests/inventory/inventory_check.gd` (capacity, overflow, move/swap,
  sort/filter, stacking, save round-trip + corrupt).

## Built (equipment integration)

- `Player` owns `InventoryManager` + `EquipmentManager` (`_ready`) and mediates
  pickup → equip → stats: `pickup_item()`, `equip_item()` (capacity pre-check
  via `preview_displaced()`, displaced return to inventory, `refresh_stats()`,
  `item_equipped` emit), `unequip_slot()`. Rules stay in the managers, math in
  `StatCalculator` — `Player.gd` delegates.
- Check: `tests/integration/loadout_check.gd` (pickup→equip→stat gain→signal,
  unequip round-trip, under-level refusal, full-inventory swap refusal).

## Built (combat domain — fixme.md TASK 13)

- `scripts/combat/DamageCalculator.gd`: pure static `calculate(request,
  balance)` — multipliers → crit (caller-supplied rolls only, no RNG calls,
  no JSON access) → variance → armor `K/(K+armor)` → min-damage floor.
  Result carries `amount/raw/type/critical/blocked/absorbed/source/target`
  (§72) for UI to consume blind. Enemy entities + scene wiring are TASK 14.
- Check: `tests/combat/combat_check.gd` (chain math, crit on/off, armor curve,
  variance determinism, floor, result shape).

## Built (combat scene integration — fixme.md TASK 14)

- `scenes/enemies/Enemy.tscn` + `scripts/enemies/Enemy.gd`: definition-driven
  (setup loads JSON + level scaling, tier tint), `take_hit()` (own armor +
  DamageCalculator), `die()` (died + `enemy_killed`), chase/contact AI from
  balance. Instance state is runtime; definitions stay read-only.
- `Player.try_attack()`: facing melee query (enemies layer 2), cooldown,
  basic-attack damage (base + STR), crit/variance rolls via RNGManager.
  `Main.register_enemy()` wires death → XP + placeholder drops (loot-table
  contract stage replaces the random-base hookup); debug builds spawn one
  training goblin.
- Check: `tests/integration/combat_flow_check.gd` (swing → HP falls → death →
  signal + XP + recorded drop, through the real Main).

## Built (talent/skill integration — fixme.md TASK 15)

- `scripts/talents/TalentManager.gd` (`_init(data)`): points = level, active-tree
  gating, cost/rank guards, `to_modifiers()` stamped `talent`, `reset()`.
  20 talents (5 per bow/staff/sword/shield tree). SkillManager (executables,
  1pt/3lvls) and TalentManager (passives, 1pt/lvl) are deliberately parallel —
  same shape, separate economies, never mixed.
- `Player` owns both managers; `refresh_stats()` pushes equipment + talent
  modifiers and derives the active tree from the equipped main-hand.
- Check: `tests/talents/talent_check.gd` (trees, economy, gating, caps,
  modifier math, reset, equip→tree→stat through the player).

## Built (game UI — fixme.md TASK 12)

- `scripts/ui/`: `InventoryPanel` (60-slot grid, hover tooltips, select+Equip),
  `EquipmentPanel` (7 rows, Unequip), `TalentPanel` (4 trees, Unlock/+Rank,
  active-tree spend lock), `CharacterPanel` (read-only breakdown view).
  Pure views (§43): all rules in managers, refresh via `Main.refresh_ui()`,
  mutually exclusive, toggled by I/C/T. Mounted in all builds.
- Check: `tests/ui/ui_check.gd` (toggles, render, panel-driven equip/unequip/
  talent spend, breakdown text, through the real Main).

## Built (pet collection + egg timers — fixme.md §25-28)

- `scripts/core/ClockService.gd`: system/test clock abstraction — production
  code never calls Time directly.
- `scripts/pets/EggInstance.gd`: static state machine
  stored→incubating→ready→hatched from timestamps (browser-close safe).
- `scripts/pets/PetCollectionManager.gd`: owns pets, active pet, discovery,
  counts, `active_modifiers()`, save round-trip. `Player` owns one and feeds
  pet modifiers into stats — the full base+level+equip+talent+pet pipeline.
- Check: `tests/pets/collection_check.gd` (collection rules, save, full egg
  lifecycle on a test clock).

## Built (procedural maps — domain, no rendering yet)

- `scripts/procedural/MapGenerator.gd` (`_init(rng, data)`): seeded room
  placement (no overlaps), chained + loop L-corridors, spawn/exit/boss/elite
  assignment, enemy packs + loot spots, map-level bands. All randomness via
  RNGManager after `set_seed(hash(map:seed:attempt))` — same seed, same map.
- `validate_layout()` (counts, overlaps, distinct specials, BFS connectivity,
  in-room spawns, boss iff def has one); failures retry ≤10 then loud fail.
  `generation_version` recorded on every layout.
- Check: `tests/maps/map_check.gd` (determinism, 3 maps × 30 seeds valid,
  level bands, seed/version recording).

## Built (hardening — fixme.md P0)
- `scripts/core/DataValidator.gd`: semantic validation (types, enums, ranges,
  key/id consistency, cross-file refs incl. tier-correct map placement).
  Tool: `tests/data/data_check.gd -- --check` → `DATA CHECK: PASS`
  (production tables + 9 synthetic negative self-tests). Contract: `docs/DATA_SCHEMA.md`.
- Schema versions: every JSON carries `_schema_version: 1` (`_` keys are
  metadata, stripped before caching). Missing → warning; otherwise unsupported
  → hard error. v1 is the only contract; v2 needs a DataMigration module.
- `scripts/core/StatModifier.gd`: the one modifier contract
  `{stat, value, is_percent, source_type, source_id}`. Producers stamp at build
  (loot `equipment:<base>`, buffs `buff:<id>`, pets `pet:<id>`); unstamped input
  normalizes to `unknown` with a warning — no parallel formats, ever.
- `StatCalculator.calculate_breakdown()` + `format_breakdown()` (BASE/Lvl/source
  view; finals always equal `calculate()`), `CharacterStats.get_breakdown()`.
- `scripts/loot/LootContext.gd`: one-dict roll context (levels, tier, luck,
  seed…); `LootGenerator.generate_item_ctx()` wires luck + seed. Default context
  reproduces `generate_item()` exactly.

## Data contracts (fixme.md §6–7 — immutable)

- Definition (JSON, what things CAN be) vs instance (owned objects) stays
  absolute; runtime never mutates base definitions.
- Every `DataManager` getter returns a deep duplicate. Callers may mutate
  freely; bases stay clean. Keep this guarantee with a test, not just a comment.

## Dependency rules (enforced)

Systems → managers/services → data. UI never feeds generators
(`LootGenerator → ItemInstance → InventoryManager → InventoryUI`).
`Player.gd` (Stage 2) must talk through managers/services, never into
`LootGenerator/PetGenerator/MapGenerator/SaveManager` internals. Stats aggregate
in one place (`StatCalculator`, Stage 2); no ad-hoc patching.

## Next (Stage 3 equipment)

EquipmentManager, 7 slots, equip/unequip, two-handed rule, equipment stat
modifiers feeding `StatCalculator`. Then inventory/combat per `todoagent.md` §121.
