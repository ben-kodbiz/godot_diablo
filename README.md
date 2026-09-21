# LootARPGPet — README

Modular 2D pixel-art ARPG (Godot 4.7, GDScript): loot-driven progression + pet
collection. Browser-first, JSON-driven, deterministic where required.

- Master spec: `todoagent.md` (everything the game will become — read the
  section for any system before you touch it).
- Agent rules: `AGENTS.md` (short, mandatory).
- Live architecture notes: `docs/ARCHITECTURE.md` · numbers: `docs/BALANCING.md`.

## 1. Current state (what exists today)

Foundation + loot core + pet core. There is **no combat, player movement,
inventory UI, or real egg timers yet** — those are later stages (§121 order in
`todoagent.md`). What works:

| System | Files | Try it |
| ------ | ----- | ------ |
| Project bootstrap | `project.godot`, `scenes/main/Main.tscn` | Run → placeholder world + 2 dev panels |
| Data engine | `scripts/core/` (EventBus, RNG, Features, Data, Game) | `BOOT OK …` in output, `DATA ERROR` on bad JSON |
| Player | `scenes/player/`, `scripts/character/` (Player, CharacterStats, StatCalculator) | Run → move with WASD, status shows lvl/HP; `tests/player/player_check.gd` |
| Skills | `scripts/skills/` (SkillManager) + `data/skills/`, `data/balance/skills.json` | `tests/skills/skill_check.gd -- --weapon=staff --level=10`, `--check` |
| Equipment | `scripts/equipment/` (EquipmentManager, domain only — no player wiring yet) | `tests/equipment/equipment_check.gd` |
| Inventory | `scripts/inventory/` (InventoryManager, domain only — no UI yet) | `tests/inventory/inventory_check.gd` |
| Loadout | `Player` pickup/equip/unequip + stat refresh (integration) | `tests/integration/loadout_check.gd` |
| Combat | `scripts/combat/` (DamageCalculator) + `scenes/enemies/`, player basic attack, Main drop wiring | `tests/combat/combat_check.gd`, `tests/integration/combat_flow_check.gd` |
| Loot generator | `scripts/loot/`, `data/equipment|affixes|rarities|effects|balance/loot.json` | Loot panel / loot simulator |
| Pets + eggs + drops | `scripts/pets/`, `data/pets|eggs|drops|enemies|maps`, `data/balance/pets.json` | Pet panel / pet simulator |

## 2. Prerequisites (first-time Godot setup)

1. **Install Godot 4.7.2 (standard, NOT mono).** Download
   `Godot_v4.7.2-stable_linux.x86_64` from godotengine.org releases. This project
   is GDScript-only, so you do not need C# or .NET.
   > The repo vendors a *mono* Godot binary that crashes without .NET
   > (`hostfxr`) installed — ignore it and use the standard binary. It is
   > git-ignored (`.gitignore`) so it never gets committed.
2. **(Only for browser builds)** Install the Godot **4.7 Web export templates**:
   Editor → Settings → Export → Install templates (or copy the `.tpz` into
   `~/.local/share/godot/export_templates/4.7.2.stable/`). Without these, the
   `Web` preset cannot export — everything else works fine.
3. No other dependencies. No Node, no Python, no build step: Godot runs the
   source directly.

In the commands below, `GODOT` means your binary, e.g.:

```sh
GODOT=/tmp/opencode/godot472/Godot_v4.7.2-stable_linux.x86_64
```

## 3. Opening the project (Godot editor, 60-second tour)

1. Open Godot → **Import** → select this folder (`project.godot`) → **Open**.
2. You land in the editor. The five panels that matter:
   - **FileSystem** (bottom-left): the repo files. Double-click a `.tscn` to open
     a scene, a `.gd` to edit code, a `.json` to edit data.
   - **Scene** (top-left): node tree of the open scene (`Main.tscn` = one
     `Main` node; everything else spawns at runtime for now).
   - **Inspector** (right): properties of the selected node.
   - **Output** (bottom): `print()` text and red `SCRIPT ERROR`s — always watch
     this while working.
   - **Play buttons** (top-right): ▶ runs the game, ⏸ pauses, ⏹ stops.
3. Press ▶: the game window opens showing the placeholder world, a status line,
   and (debug builds) the **Loot Simulator** (right) and **Pet Simulator**
   (left) panels. Close it with ⏹.
4. `project.godot` is a text file — InputMap actions, autoloads, and renderer
   settings live there. Prefer the editor UI
   (Project → Project Settings / Input Map) over hand-editing it.

Key project settings already configured: **Compatibility** renderer (web-safe),
nearest-neighbor texture filtering (crisp pixels), 1280×720 `canvas_items`
stretch, and InputMap actions (`move_up/down/left/right`, `attack`, `interact`,
`toggle_inventory/character/talents/pets`).

## 4. Running and verifying

```sh
# Normal run (opens a window; use the editor ▶ instead if you have a display)
$GODOT --path .

# Headless smoke check — expect: BOOT OK … and no SCRIPT ERROR
$GODOT --headless --path . --quit-after 60

# First-time import (creates .godot/ cache; re-run if scripts act stale)
$GODOT --headless --path . --import
```

**Reading the output:** `BOOT OK: … weapons=4 equipment=7 … pets=6 species=6 …`
means every JSON loaded and validated. If you see
`DATA ERROR: res://data/weapons/weapons.json entry: foo missing field: family`,
the game still boots but `GameManager` reports `BOOT FAILED` — fix the JSON,
don't silence the error.

## 5. Repository tour

```text
project.godot            engine config: main scene, autoloads, input, renderer
export_presets.cfg       Web export preset → build/web/index.html
scenes/main/Main.tscn    entry scene (bootstrap proof only — no gameplay code)
scripts/core/            autoloads, loaded in order:
                         EventBus → RNGManager → FeatureManager → DataManager → GameManager
scripts/loot/            LootGenerator.gd (roller) + ItemInstance.gd (assembly/tooltip)
scripts/pets/            PetGenerator.gd (hatch + egg drops) + PetInstance.gd
scripts/ui/              dev-only simulator panels (debug builds only)
scripts/main/Main.gd     placeholder world + mounts dev panels
data/                    ALL content and numbers (JSON = source of truth)
  stats/ weapons/ equipment/ rarities/ affixes/ effects/ balance/
  pets/ species.json eggs/ drops/ enemies/ maps/ config/features.json
tests/loot|pets/         headless simulator + validation scripts (run with --script)
docs/                    ARCHITECTURE.md, BALANCING.md, ASSET_LICENSES.md
assets/                  empty placeholders (art lands at the art stage)
```

**Golden rules:** balance numbers live in `data/`, never in `.gd`. Systems talk
through `EventBus` and managers, never by reaching into each other's internals.
Low-level code (generators) must not depend on UI. Getters like
`DataManager.get_weapon("bow")` return *copies* — mutate freely, bases stay clean.

## 6. Tools guide

All generator tools reuse the **production** code (same RNG, same data), so a
roll in the tool is identical to a roll in-game. Two frontends each:

### Loot tools

```sh
# Roll N items of YOUR chosen rarity/base/level (the "user picks blue" tool)
$GODOT --headless --path . --script res://tests/loot/loot_simulator.gd -- \
  --rarity=rare --base=iron_bow --level=14 --count=5 --seed=7
# --rarity: normal|uncommon|rare|epic|legendary (omit = weighted random)
# --base: any id from data/equipment/equipment.json (omit = all, cycled)
# --seed: omit = true random; set it to reproduce an exact roll

# Full validation: 10,000 rolls — distribution, affix counts/bounds,
# buff rules, unique itm_* ids (spec §57). Must print LOOT CHECK: PASS.
$GODOT --headless --path . --script res://tests/loot/loot_simulator.gd -- --check
```

### Player check

```sh
# StatCalculator math + live movement + XP/level/signal + HP rules.
# Must print PLAYER CHECK: PASS.
$GODOT --headless --path . --script res://tests/player/player_check.gd
```

### Skill tool
```sh
# Show a weapon's tree at a level (demo-spends points in unlock order)
/godot-binary --headless --path . --script res://tests/skills/skill_check.gd -- \
  --weapon=bow --level=13
# Validate: data rules, point economy, upgrade guards, power math, level-20 cap
/godot-binary --headless --path . --script res://tests/skills/skill_check.gd -- --check
```

**Scheme:** 1 skill point per 3 player levels (7 by L20) · unlock = 1pt ·
+1 rank = 1pt up to rank 5 · max 10 skills per weapon · player cap L20.
Details in `docs/BALANCING.md`.

### Data check (run FIRST after any content edit)

```sh
# Semantic + cross-reference validation of ALL JSON + negative self-tests.
/godot-binary --headless --path . --script res://tests/data/data_check.gd -- --check
```

Catches what structure checks miss: unknown references (egg→ghost pet,
map→wrong-tier boss), bad enums, inverted ranges, key/id mismatches.
Contract: `docs/DATA_SCHEMA.md`. Full gate order: data → loot/pet/player/skill → boot.

### Equipment check

```sh
# Slots, level/stat requirements, two-handed displacement both ways,
# accessory pairing, pet-slot guard, modifier math, save round-trip.
/godot-binary --headless --path . --script res://tests/equipment/equipment_check.gd
```

7 slots (accessory auto-pairs, pet reserved); `occupies` footprint + generic
`requirements[]` live in equipment JSON. Domain only — player/UI wiring later.

### Inventory check

```sh
# Capacity, add/remove/find, move/swap, rarity sort, filters, stack merging,
# save round-trip. Prints INVENTORY CHECK: PASS.
/godot-binary --headless --path . --script res://tests/inventory/inventory_check.gd
```

10×6 grid from `data/balance/inventory.json` (stack cap 99). Domain only, no UI.

### Loadout check (integration)

```sh
# Loot → inventory → equipment → stats → item_equipped signal, plus refusal
# paths (under-level, full inventory). Prints LOADOUT CHECK: PASS.
/godot-binary --headless --path . --script res://tests/integration/loadout_check.gd
```

### Combat check

```sh
# Damage formula: multiplier chain, crit on/off, armor curve, variance
# determinism, min-damage floor, result shape. Prints COMBAT CHECK: PASS.
/godot-binary --headless --path . --script res://tests/combat/combat_check.gd
```

Pure math (rolls in, result out — no RNG calls, no scenes). Numbers in
`data/balance/combat.json`.

### Combat flow check (integration)

```sh
# Real Main scene: training dummy → attacks → death → enemy_killed + XP +
# recorded drop. Debug builds spawn one forest goblin to swing at; attack with
# mouse/space, move with WASD. Prints COMBAT FLOW: PASS.
/godot-binary --headless --path . --script res://tests/integration/combat_flow_check.gd
```

In-game: the **Loot Simulator** panel → pick Base + Rarity + Level → **Roll item**.
Rarity-colored names, full tooltip, same generator.

**Scheme:** green 1 affix · blue 2 · epic 3 + 1 buff · legendary 4–5 + buff/effect.
Weights/values in `docs/BALANCING.md`.

### Pet tools

```sh
# Hatch N eggs of your choice (shows odds incl. wild scaled variants)
$GODOT --headless --path . --script res://tests/pets/pet_simulator.gd -- \
  --egg=storm_egg --count=5 --seed=3

# Simulate K kills: how often do eggs actually drop?
$GODOT --headless --path . --script res://tests/pets/pet_simulator.gd -- \
  --drops --tier=elite --map-level=15 --kills=1000
# --tier: normal|elite|boss. Expect ~0.5% / ~5% / ~25%.

# Full validation: hatch odds (fixed + wild), scaled-bonus bounds, drop rates,
# map-level gating, dragon jackpot share. Must print PET CHECK: PASS.
$GODOT --headless --path . --script res://tests/pets/pet_simulator.gd -- --check
```

In-game: the **Pet Simulator** panel → pick Egg → **Hatch egg**, or pick Killer
tier + Map lvl → **Test drops (100 kills)**.

**Scheme:** 6 fixed signature pets + 6 wild species (rarity-scaled bonuses);
eggs 2–48h; drops only from kills, gated by map level. Details + roster table in
`docs/BALANCING.md`.

### How to read a failure

- `LOOT/ PET CHECK: FAIL` + indented lines → each line is one broken rule with
  the offending id (e.g. `itm_… affix count 2 out of range`). Fix data or
  generator, re-run `--check`.
- `SCRIPT ERROR: Parse Error: Cannot infer the type of "x" …` → you used `:=`
  on a call to another script/autoload (its return type is unknown). Write
  `var x: Dictionary = …` (or `int`, `String`, …) instead. This is the #1
  newcomer gotcha in this codebase — dynamic calls need explicit types.

## 7. Cookbook (common tasks — all JSON, no code)

> After any data edit: run data `--check` FIRST, then the matching system
> check (loot/pet/player/skill) plus one headless boot. `DATA ERROR` names the
> exact file, entry, and field. New files need `"_schema_version": 1` as their
> first key (see `docs/DATA_SCHEMA.md`).

| Task | Steps |
| ---- | ----- |
| **Add a weapon base** (e.g. dagger) | 1. Append to `data/equipment/equipment.json`: `id, name, base_type, slot (main_hand/off_hand/armor/helmet/accessory), required_level, base_stats`. 2. Ensure `base_type` exists in `data/weapons/weapons.json` (family/primary_stat/talent tree) — add it there too if new. 3. Roll it: `--base=iron_dagger --rarity=rare --count=3`. |
| **Add an affix** (e.g. lifesteal) | Append to `data/affixes/affixes.json`: `id, stat, min/max_value, is_percent, allowed_slots (weapon/armor/accessory), prefix, suffix`. Slot pools pick it up automatically; thin pools (accessory!) need ≥3–4 entries for legendary rolls. |
| **Add a buff** (e.g. +10% move speed) | Append to `data/effects/buffs.json`: `id, name, description, modifiers[], min_rarity (epic/legendary), allowed_slots`. Legendary-only entries may add `trigger{}` + `grants_name` for a fixed item name. |
| **Retune loot** | `data/rarities/rarities.json` (weights, affix ranges, `bonus_buffs`) and `data/balance/loot.json` (level scaling, rarity multipliers). Never touch the generator. |
| **Add a pet species** (wild) | Append to `data/pets/species.json`: `id, name, egg_type, rarity_weights (0 = excluded), wild_pool[{stat,min,max,is_percent}]`. Reference it from an egg's `wild_rolls`. Bonuses scale automatically per `data/balance/pets.json`. 20 species × rarities ≈ 100+ pets with no code changes. |
| **Add a fixed signature pet** | Append to `data/pets/pets.json` (`id, name, rarity, egg_type, bonuses[]`) and reference it from an egg's `possible_pets`. Reserve this for special pets (dragons!) — bulk roster should be wild. |
| **Add an egg** | Append to `data/eggs/eggs.json`: `id, name, hatch_time_hours, min_map_level, possible_pets[] and/or wild_rolls[]`. Add it to a tier pool in `data/drops/enemy_drops.json`. |
| **Retune drops/pets** | `data/drops/enemy_drops.json` (tier chances + pools), `data/balance/pets.json` (lines + multipliers per rarity). Re-run pet `--check`: gating, rates, dragon share. |
| **Add a skill** | Append to `data/skills/skills.json`: `id, name, family, unlock_level (1–20), max_rank, base{damage_flat/damage_pct/cooldown_sec/mana_cost}, per_rank{…}`. Keep ≤10 per family, unlocks ascending. Re-run skill `--check`. |
| **Tune player** | `data/balance/player.json` (base/growth stats, HP/mana rules, move speed, XP curve). Re-run player check. |
| **Add an enemy / map** | `data/enemies/enemies.json` needs `id, tier (normal/elite/boss), health, damage` (+ flavor: name, level, armor, xp, loot_table). `data/maps/maps.json` needs `id, biome` + `enemies[]`, `elites[]`, `boss` ("" = none). Enemy/map *behavior* (AI, generation) arrives in later stages — data first. |
| **Disable an unfinished system** | `data/config/features.json` (`crafting/quests: false`). Code gates on `FeatureManager.is_enabled(…)`. |

## 8. GDScript survival notes (Godot newcomers)

- **Scripts run directly** — no compile step. Errors appear at load in Output.
- **Autoloads are global singletons** (`EventBus`, `RNGManager`,
  `FeatureManager`, `DataManager`, `GameManager`). In any script just write
  `DataManager.get_weapon("bow")`. (In headless `--script` tools autoloads
  don't exist, so those scripts instantiate the modules manually — that's why
  they look different. Game code: use autoloads.)
- **`:=` needs a known type.** Calls into other scripts return `Variant`, so
  `var x := DataManager.get_pet(id)` fails to parse — always annotate:
  `var x: Dictionary = …`. Same for `rng.weighted_choice(…)` → `var i: int`.
- **JSON numbers arrive as `float`.** `8` in JSON is `8.0` in code — display
  helpers already normalize whole floats; use `int(…)` when you need ints.
- **`preload()` > `class_name` here.** Modules reference each other with
  `preload("res://…")` constants — deterministic, no global-class cache issues.
- **`pool.shuffle()` uses the global RNG**, not `RNGManager` — fine for
  *ordering* a fairly-rolled pool, never for the rolls themselves.
- **`.godot/` is cache.** If new scripts behave oddly, run `--import` once.

## 9. Troubleshooting

| Symptom | Cause → fix |
| ------- | ----------- |
| `dotnet: not found` + crash (signal 11) | You ran the vendored **mono** binary → use the standard 4.7.2 binary (§2). |
| `BOOT FAILED` + `DATA ERROR`s | Broken JSON — the message names file/entry/field → fix data, re-run. |
| `Cannot infer the type` parse error | `:=` on a dynamic call → add explicit type (§6). |
| `Invalid call … 'new'` in simulator | A preloaded script failed to compile — scroll up for its real error. |
| Panel/commands fine headless but blank in editor | Check Output for red errors; ensure you pressed ▶ with `Main.tscn` as main scene. |
| Web export fails | Missing export templates (§2) or wrong Godot version — preset targets 4.7. |

## 10. What's next (don't skip ahead)

`todoagent.md` §121 order: player ✅ → equipment → inventory → loot polish →
combat → talents → pets/eggs timers → procedural maps → bosses → save → UI →
balancing → art/audio → web optimization → browser release → Steam prep.
MVP = 1 biome, 3 maps, 1 boss, bow/staff/sword/shield, 5 loot rarities, pet
collection + hatching, save/load, browser deploy. No crafting/quests/multiplayer
in MVP — they sit behind `FeatureManager` flags.
