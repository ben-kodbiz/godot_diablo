# BALANCING

All numbers live in `data/` JSON — never in `.gd`. Retune by editing files,
then re-run the headless check (§Validation).

## Player (`data/balance/player.json`)

Base 10 STR/DEX/INT/VIT + 5 LUCK; per level +2/+2/+2/+3/+1. HP =
50 + VIT×5 + (level−1)×10 (L1 = 100). Mana = 20 + INT×3. Move 200 px/s
(×1 + move_speed% from pets/buffs). XP for level N→N+1 = 100 × 1.5^(N−1)
(L1→2 = 100, L2→3 = 150). Level-up refills HP and emits `player_level_up`.
Max player level 20 (in `xp_curve`).

## Skills (`data/skills/skills.json` + `data/balance/skills.json`)

One skill point every 3 player levels (L1, 4, 7, … 19 → 7 points at L20).
Unlock = 1 point (rank 1); each +1 rank = 1 point, max rank 5. Max 10 skills
per weapon family (5 authored per family today). Power at rank R:
flat = base_flat + per_flat×(R−1), pct likewise; cooldown/mana fixed.
Families unlock at 1/4/7/10/13 (starter → … → Meteor-tier). Skill execution
(cooldowns, targeting) is combat-stage work; numbers are final here.

## Rarity scheme (`data/rarities/rarities.json`)

| Rarity | Color | Weight | Affixes | Bonus buff |
| ------ | ----- | ------ | ------- | ---------- |
| normal | gray | 6000 (~60%) | 0–1 | 0 |
| uncommon (green) | green | 2500 (~25%) | 1 | 0 |
| rare (blue) | blue | 1000 (~10%) | 2 | 0 |
| epic (purple) | purple | 450 (~4.5%) | 3 | 1 |
| legendary | orange | 50 (~0.5%) | 4–5 | 1 (+ trigger effect) |

`bonus_buffs` draws from `data/effects/buffs.json` filtered by `min_rarity`
(rank ≤ item rarity) and `allowed_slots`. Legendary-only entries may carry a
`trigger` (modular combat effect, e.g. Moonpiercer Volley) and a `grants_name`
fixed item name.

## Affix values (`data/affixes/affixes.json`)

Each affix: `stat, min_value–max_value, is_percent, allowed_slots
(weapon/armor/accessory), prefix, suffix`. Final value formula
(`LootGenerator.scale_value`):

```text
value = roll(min–max) × (1 + (item_level − 1) × value_per_level) × rarity_multiplier
```

`value_per_level` (0.08) and `rarity_multipliers`
(1.0 / 1.1 / 1.25 / 1.5 / 2.0) live in `data/balance/loot.json`.

## Slot → pool mapping (`LootGenerator.SLOT_CATEGORIES`)

main_hand→weapon · off_hand→weapon+armor · armor/helmet→armor ·
accessory→accessory. If a pool is smaller than the rolled count (e.g. thin
pools), the generator caps at pool size instead of failing.

## Naming

Prefix from 1st affix + base name + suffix from 2nd affix
(`Swift Iron Bow of Precision`); legendary fixed name when the buff grants one.

## Pet roster (`data/pets/pets.json` — fixed signature pets)

| Pet | Rarity | Bonuses |
| --- | ------ | ------- |
| Green Slime | common | +3 VIT, +20 Health |
| Forest Wolf | common | +5 DEX, +2% Attack Speed |
| Stone Turtle | rare | +10 VIT, +5% Health |
| Mage Cat | rare | +8 INT, +10% Mana |
| Sky Unicorn | epic | +8% Move Speed, +10 LUCK, +2% Crit Chance |
| Ember Dragon | legendary | +15 STR, +12% Damage, +120 Health, +10% Crit Damage |

Fixed pets are hand-tuned and permanent — the bulk roster below never replaces them.

## Wild species (`data/pets/species.json` + `data/balance/pets.json`)

Species template × rarity scaling = combinatorial roster (6 species today,
100+ later with no code changes). Each species: `wild_pool` (bonus stat ranges)
+ `rarity_weights` (0 = excluded, e.g. bunnies never roll epic).

| Species | Rarities | Pool highlights |
| ------- | -------- | --------------- |
| Thorn Bunny | common | move speed, luck, health |
| Cave Bat | common | crit chance, attack speed, DEX |
| Ember Fox | rare/epic | damage, crit chance, move speed |
| Gloom Owl | rare | crit damage, INT, mana |
| Storm Eagle | epic | attack speed, move speed, DEX |
| Frost Lynx | epic | damage, crit damage, luck |

Scaling per rarity (`bonus_lines` × `value_mult`, clamped to pool size):

| Rarity | Lines | Mult |
| ------ | ----- | ---- |
| common | 1 | ×1.0 |
| rare | 2 | ×1.6 |
| epic | 3 | ×2.2 |
| legendary | 4 | ×3.2 |

Wild pet id/name derive deterministically (`ember_fox_epic` / "Epic Ember Fox")
so saves stay stable. To reach 100+: add species rows + egg `wild_rolls`
references — same validation, same `--check`.

## Eggs (`data/eggs/eggs.json`)

Each egg: `hatch_time_hours`, `min_map_level` (drop gate), weighted
`possible_pets` (fixed ids) and/or `wild_rolls` (species ids; rarity rolled
from species weights). Forest 2h (slime/wolf) · Burrow 4h (bunny/bat wild) ·
Mossy 8h (turtle/cat + fox/owl wild) · Sky 24h (unicorn-led) · Storm 30h
(eagle/lynx wild + unicorn) · Dragon 48h (80% dragon, 20% unicorn).
Hatching rolls are instant in the simulators; timestamp-based incubation
(survives browser close) is Stage 8.

Future egg categories for the battle-pet compendium (reference only, not in
game): `docs/BATTLE_PETS_EGG_TAXONOMY.md`.

## Egg drops (`data/drops/enemy_drops.json`)

Per killer tier, deliberately very rare:

| Killer | Egg chance | Pool |
| ------ | ---------- | ---- |
| normal mob | 0.5% | forest/burrow |
| elite | 5% | forest/mossy/burrow/sky/storm |
| boss | 25% | mossy/sky/storm/dragon (15% of pool) |

Pool entries below the egg's `min_map_level` are filtered out, so e.g. map
level 1 can only ever drop Forest Eggs and dragons need level 18+ content.

## Maps (`data/maps/maps.json`, `data/enemies/enemies.json`)

Forest Edge (1–10): slime/goblin + Goblin Brute elite · Forest Depths (8–18):
+ Dire Wolf + Troll Shaman elite · Heart of the Forest (15–25, boss level):
Troll Shaman elite + **Forest Guardian boss** (2-phase stub: normal/enraged).
Enemies carry `tier` (normal/elite/boss) + `loot_table`; maps list `enemies`,
`elites`, and one `boss` ("" = none).

## Validation

```sh
# roll N of a chosen rarity/base (defaults: random base, weighted rarity)
/tmp/opencode/godot472/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --script res://tests/loot/loot_simulator.gd -- \
  --rarity=epic --base=iron_sword --level=20 --count=5 --seed=3
# 10k-roll spec check: distribution, affix validity/bounds, buff rules, unique ids
/tmp/opencode/godot472/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --script res://tests/loot/loot_simulator.gd -- --check
# hatch eggs / simulate drops / validate pets+eggs+drops
/tmp/opencode/godot472/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --script res://tests/pets/pet_simulator.gd -- --egg=sky_egg --count=5 --seed=3
/tmp/opencode/godot472/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --script res://tests/pets/pet_simulator.gd -- --drops --tier=boss --map-level=20 --kills=1000
/tmp/opencode/godot472/Godot_v4.7.2-stable_linux.x86_64 --headless --path . \
  --script res://tests/pets/pet_simulator.gd -- --check
```

In-game: debug builds show a Loot Simulator panel (base + rarity + level → roll).
