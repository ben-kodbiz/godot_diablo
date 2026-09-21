# Battle-Pets Egg Taxonomy (reference only)

Source: "Dark Legacy Compendium" Google Sheet (battle-pet stats for a different
game — **NOT used in our game**). Parsed 99 rows from a truncated dump (the
sheet claims 107/111, so ~8 entries were not visible). Columns seen: Pets,
Health, Mana, Attack, Defense, Size, Tactics, Unique Traits/Skills, Cosmetics.

Purpose: when battle pets (or their families) come into our game later, egg
categories already exist. To promote any category into the game: add
`species.json` rows → add an egg entry with `wild_rolls` → add it to a tier
pool in `enemy_drops.json` → run pet `--check`. Game data-see `docs/BALANCING.md`.

## Egg categories

3 map to eggs we already have; 10 are reserved for later. Counts sum to 99
(Spirit Kitten is listed under Seasonal but would hatch from Forest).

| Egg | Status | Families → members |
| --- | ------ | ------------------ |
| Forest Egg | **in game** | Woodland felines (Spirit Kitten, Rich Brown Cat), canines (Faded Black Dog, Dingo, Wolf, Fox), rodents (Orange Fuzzy Hamster, Lemming, Orange Moss Chipmunk, Raccoon), lagomorphs (Vorpal Bunny, Soft Fuzzy Bunny), mustelids (Weasel, Ferret), Grizzly Bear — 15 |
| Sky Egg | **in game** | Birds: Death Crow, Spotted White Mockingbird, Pigeon, Raven, Eagle, Hawk, Owl, Chicken, Turkey, Duck — 10 |
| Burrow Egg | **in game** | Diggers/cave-dwellers: Mole, Rat, Wombat, Badger, Bat, Fossilized Gravel Worm — 6 |
| Marsh Egg | reserved | Amphibians (Zombie Toad, Slimy Green Toad, Frog, Tadpole, Newt, Chameleon, Salamander), pond reptiles (Scaled Green Lizard, Gecko, Snake, Crocodile, Komodo Dragon), Beaver — 13 |
| Hive Egg | reserved | Colony/crawling insects: Foggy Grey Huge Spider, Giant Ant, Giant Bee, Stink Bug, Praying Mantis, Fluffy, Clay Grub — 7 |
| Ember Egg | reserved | Fire-aligned: Fire Lizard, Dragonette, Drake, Dragon, Imp, Balrog — 6 |
| Tide Egg | reserved | Aquatic: Vibrating Funky Dolphin, Platypus, Octopus, Sea Monkey, Hippocampus, Turtle, Giant Turtle — 7 |
| Fey Egg | reserved | Spirits/magical smallfolk: Glowing Navy Fey, Will O Wisp, Sprite, Mini Doll, Earth Sprite — 5 |
| Stone Egg | reserved | Constructs/earth: Golem, Rock Troll, Gargoyle — 3 |
| Pasture Egg | reserved | Hoofed/farm: Red Speckled Horse, Cow, Sheep, Donkey, Bison**, Camel, Maned Brown Pony, Warhorse — 8 |
| Canopy Egg | reserved | Primates (Splotched Yellow Ape, Baboon, Monkey, Orangutan, Chimpanzee, Gorilla) + big cats (Leopard, Tiger, Lion, Cheetah) — 10 |
| Frost Egg | reserved | Northern: Polar Wolf, Wolverine, Lynx, Granite Penguin — 4 |
| Celestial Egg | reserved | Mythic winged: Unicorn, Pegasus, Gryphon, Hippogryph, Roc — 5 |
| Seasonal Egg | reserved (event) | Spirit Kitten is the sheet's only `Seasonal`-marked row — pattern for event-only eggs |

## Tier guidance (for later pool placement)

Rough power signal from the sheet's Size/Attack columns — use when assigning
categories to normal/elite/boss drop pools:

- **Normal pools:** Forest, Burrow, Pasture, Marsh (Midget–Fair Sized, Docile/Mixed tactics).
- **Elite pools:** + Sky, Hive, Canopy, Frost, Tide (Sky/Fast tactics, higher Attack).
- **Boss pools only:** Ember, Celestial, Stone (Mighty/Behemoth size: Dragon, Roc;
  Tank/Cast tactics, top Attack/Defense). Dragon stays the jackpot — same rule as
  our `dragon_egg` today (≤15–20% of the boss pool).
- **Event pool:** Seasonal Egg, never in standard pools.

## Data-quality flags (in the source, not ours)

`B aboon` (= Baboon), `Dohphin` (= Dolphin) typos; `Bison**` has an unexplained
`**` marker; Giant Turtle / Sea Monkey have blank Tactics; 8 of 111 rows missing
from the dump. Verify against the live sheet before importing anything.
