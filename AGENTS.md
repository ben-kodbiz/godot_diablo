# AGENTS.md — lootarpgpet

Greenfield Godot 4 ARPG (loot + pets). No `project.godot`, code, or scenes exist yet.
Source of truth: `todoagent.md` (~3900-line master spec). Read the relevant section before
implementing any system; do not invent architecture that contradicts it.

## Toolchain

- Engine: Godot **4.7.2** (mono binary vendored at
  `Godot_v4.7.2-stable_mono_linux_x86_64/Godot_v4.7.2-stable_mono_linux.x86_64`).
- Language: **GDScript only. Do NOT use C#** — web export must stay straightforward.
- Renderer: **Compatibility** (browser target). 2D, pixel art: one sprite scale
  (spec recommends 32x32), nearest-neighbor filtering, no mixed pixel densities.
- Run headless: `./Godot_v4.7.2-stable_mono_linux_x86_64/Godot_v4.7.2-stable_mono_linux.x86_64 --headless --path <project-dir> …`
  (mono build needs .NET `hostfxr`; if it crashes on missing dotnet, use a standard
  Godot 4.7.2 linux binary for headless GDScript checks — project is GDScript-only).
- No test framework, CI, lint, or export presets configured yet. When adding tests,
  prefer headless-runnable scripts (e.g. `SceneTree` scripts generating 10k loot rolls)
  over full-game launches.
- Loot check: `<godot> --headless --path . --script res://tests/loot/loot_simulator.gd -- --check`
  (rolls: `--rarity=epic --base=iron_sword --level=20 --count=5 --seed=3`).
  Pet check: `<godot> --headless --path . --script res://tests/pets/pet_simulator.gd -- --check`
  (hatch: `--egg=sky_egg --count=5`; drops: `--drops --tier=elite --map-level=15 --kills=1000`).
  Player check: `<godot> --headless --path . --script res://tests/player/player_check.gd`
  (movement, XP/level + signal, HP, StatCalculator math).
  Skill check: `<godot> --headless --path . --script res://tests/skills/skill_check.gd -- --check`
  (tree: `--weapon=staff --level=10`; economy, upgrade math, level-20 cap).
  Balance scheme lives in `docs/BALANCING.md`, not in code.

## Build order (do not skip ahead)

Follow `todoagent.md` §121 phases in order: project bootstrap → DataManager/JSON →
player+stats → equipment → inventory → loot → combat → talents → pets+eggs →
procedural maps → bosses → save → UI polish → balancing → art/audio → web opt →
browser release. MVP = 1 biome, 3 maps, 1 boss, bow/staff/sword/shield,
normal→legendary rarities, 3–6 pets (common/rare/epic), save/load, browser deploy.
No crafting/quests/multiplayer/sets in MVP (stub behind `FeatureManager` flags only).

## Target layout (create as built)

`project.godot` at repo root (once created) · `scenes/` · `scripts/core|combat|character|
equipment|inventory|loot|talents|pets|enemies|maps|procedural|save|ui|utilities/` ·
`data/` (JSON per system) · `assets/` · `tests/loot|stats|pets|maps|combat|save/` ·
`docs/` (`ARCHITECTURE.md`, `BALANCING.md`, `ASSET_LICENSES.md`, …).

## Architecture — hard rules

- Small composable managers, never a god `Player.gd`. Canonical globals:
  `GameManager, DataManager, LootManager, MapManager, EnemyManager, SaveManager,
  AudioManager, UIManager, EventBus, RNGManager, StatCalculator, FeatureManager,
  DebugManager`.
- Dependency direction: systems → managers/services → data. Low-level systems must
  NOT depend on UI (`LootGenerator → ItemInstance → InventoryManager → InventoryUI`).
  `Player.gd` must not reach into `LootGenerator`/`PetGenerator`/`MapGenerator`/`SaveManager`
  internals. Cross-system chatter goes through `EventBus`
  (`player_level_up, item_dropped/equipped/salvaged, enemy/boss_killed,
  pet_obtained, egg_hatched, talent_upgraded, map_completed`).
- Single aggregator: `StatCalculator` = base + level + equipment + talents + pets +
  buffs. Every contributor emits a generic modifier (`IStatModifier`-style); never
  patch stats ad hoc. Keep a stat-breakdown debug view (BASE/Lvl/Equip/Talent/Pet/Buff/Final).
- `DataManager.get_weapon/get_pet/get_enemy/get_map(id)` is the only content access.
  Validate every JSON at startup with file+id+missing-field errors; never silently
  continue on broken data. Keep it headless-testable (`LootGeneratorTest`: 10k rolls →
  rarity/affix/level/stat checks).
- Deterministic RNG via `RNGManager` (`random_int/float, weighted_choice, seeded_random`).
  Map gen input = `(map_id, seed, player_level, difficulty)`; same seed → same map.
  Always run map validation (exit/boss reachable, no overlaps, no wall spawns).
- Balance lives in `data/` JSON (ids: weapons `bow/crossbow/staff/sword/
  two_handed_sword/shield`; rarities `normal/uncommon/rare/epic/legendary`; pets
  `common/rare/epic`); never scatter numbers in `.gd`. Adding content = JSON (+ sprite),
  no core-script edits: weapon = weapon JSON + sprite + talent-tree JSON + affixes;
  pet = pet JSON + sprite; biome = biome JSON + tileset + enemy/loot tables.

## Gotchas agents actually hit

- **Input:** use `InputMap` actions; never hard-code keys in gameplay code.
- **Slots:** 7 slots (Main/Off Hand, Armor, Helmet, Accessory×2, Pet). Two-handed sword
  occupies Main + Off Hand — keep this rule in equipment JSON, not code.
- **Items:** clone definition → `ItemInstance` with unique `itm_*` id; never mutate base
  definitions. Legendary = 4+ affixes + modular effect definition, can have fixed name.
- **Eggs:** timestamp-based hatching (`egg_id + start_timestamp + duration`, compare on
  load) — never a live timer, must survive browser close.
- **Saves:** `user://save.json` with `save_version`; add `SaveMigrationManager`
  (1→2→3…) and never break old saves. Ship Export/Import save (browser data loss).
  Talents persist across weapon swaps; use universal talent points.
- **Web-first, Steam-later:** keep gameplay inside Godot, no browser-only logic
  (`localStorage`-only, JS gameplay). Platform specifics go behind adapters
  (`PlatformService → WebPlatform/SteamPlatform`). Test web export + save/load +
  refresh/close after every platform-level change; keep PCK/assets small, compressed
  audio, loading screen.
- **Perf:** object-pool projectiles/damage-numbers/particles (profile first, no
  premature optimization); target 60 FPS desktop / 30 low-end; no hundred-enemy scenes.
- **Audio/assets:** web-safe compressed formats; only CC0/CC-BY/CC-BY-SA/MIT/Apache
  assets, each directory with `SOURCE.md` (creator/source/license/URL/attribution/
  modification) + entry in `docs/ASSET_LICENSES.md`.
- **Debug:** `DebugManager` cheats (`give_gold/item/pet/egg, level_up, teleport,
  spawn_enemy/boss, regenerate_map, show_seed/hitboxes/fps/stat_breakdown`) plus
  dev-only Loot/Pet simulators reusing production RNG — all disabled in release.

## Agent workflow (from spec §116–117)

Search before creating (never duplicate a manager/util); keep data separate from code;
scope edits to the task system; small commits; document arch changes; preserve working
features and save compat; validate JSON after content edits; prefer composition over
inheritance. Frame tasks as Task/Why/Files-to-inspect/Implementation/Acceptance/
Tests/Browser-test/Notes. Verify with the §118 test matrix
(movement, combat, XP/level, equipment, loot/rarity/affixes, talents, pets/eggs,
save/load, map gen+scaling, boss, browser export+save).
