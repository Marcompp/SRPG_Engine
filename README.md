# SRPG_Engine

A tactical RPG prototype in the style of the GBA Fire Emblem games, built with Godot 4.4 (GDScript).

## Running

Open the folder in Godot 4.4 and press F5. The game starts on a level select screen (for testing). In a battle, Z on an empty tile opens a menu with **Level Select**; on the Victory/Defeat screen, X returns there.

| Level | Shows off |
|---|---|
| River Crossing | Mixed army, magic, forts, Inspire, every enemy behavior preset |
| Coastal Raid | Movement types and ships: horse, flier, rogue, naga, a Corsair and a Galley to ferry troops, vs. climbing Brigands, a Harpy and galleys; the Swashbuckler boss holds an island fort |
| Desert Outpost | Sand, dunes, paths, houses, an oasis; horses vs. scouts in the desert |
| Frozen Pass | Snow, ice, hills, mountains, thickets, a waterfall; climbers, a swimmer and armor on ice |
| Castle Keep | Indoors: floor, carpet, walls, pillars, pits and fences; slow mounted units and a wall-walking Wraith |

## Tests

Headless test suite (combat math, ranges, inventory, EXP, spells, Dance, Inspire, classes, ships, enemy AI, levels, movement types, full enemy phases):

```
GODOT=/path/to/godot tests/run_tests.sh
```

Exits with code 0 when every test passes, 1 otherwise. The wrapper also fails if Godot printed any runtime script error, because Godot logs those and keeps running, so the GDScript runner can't see them. To run the suite directly: `godot --headless --path . --script res://tests/run_tests.gd`.

## Controls

| Key | Action |
|---|---|
| Arrow keys | Move cursor / menu selection |
| Z, Enter, Space | Confirm |
| X, Esc, Backspace | Cancel / go back |
| C | Toggle enemy danger zone |
| D | Status screen. Left/Right: page (Stats, Items, Skills, Bio), Up/Down: unit, D: detail mode (highlight anything to see its description), X: back/close |
| A | Jump the cursor to the next unit that hasn't acted |
| Hold X (enemy phase) | Fast-forward at 4× speed |
| Z (level-up window) | Continue |
| Hover a unit | Show its move and attack range (either side) |
| Z on an enemy | Mark it: red overlay of its threat (Z again to unmark) |

## Features

- Grid movement with terrain costs, player and enemy phases, Victory (rout) and Defeat (lord dies)
- Classes (see below): each decides a unit's weapon types, movement type and abilities
- Races (see below): per-unit, independent of class; can change movement, add effectiveness tags, weaknesses and resistances, and give regen or EXP perks
- FE-style combat: hit/crit with "two RN" true hit, weapon triangle (sword > axe > spear > sword), doubling, weapon weight and durability
- Ranged weapons (bows, javelins, hatchets, knives); bows win the triangle at range. Staves are melee weapons outside the triangle
- Effectiveness levels, checked against a unit's tags (its class's move type plus its race's tags). **Effective** (×3 might, tagged "x3" in the forecast): bows vs fliers, Pike vs horses, Hammer vs heavy armor, Woodcutter vs ships, silver weapons vs spirits. **Weak** (×2 might or spell power, "x2"): whole weapon types and spell elements vs some races (see Races). **Resistant** (half damage, "1/2"): spirits vs non-silver weapons, and some races vs elements. Levels don't stack: the strongest one counts
- 5-slot inventories with equip, weapon choice on attack, and consumables (Potion: 3 uses, heals 15; Ether: 3 uses, restores 15 MP). Units can carry weapons their class can't wield (marked `(x)`), but not equip them
- Trade with adjacent allies any number of times before acting (trading commits the move)
- Shove (FE9-style): any unit that isn't mounted or a ship can push an adjacent ally (also not mounted or a ship) one tile away, onto walkable empty ground; ends the shover's turn. Centaurs can shove; Centaurs, Ents and Stoneborn can't be shoved
- Rescue/Drop (Thracia 776-style): mounted classes (horse units, Flier, Whitewing) and Centaurs can carry an adjacent ally off the map (not a mounted unit, ship, Centaur, Ent or Stoneborn) (carrier's DEX/AGI halved) and set it down on an adjacent tile later. Each action ends the carrier's turn, but a dropped ally that hasn't acted can still move, so mounted units can ferry others. A fallen carrier's passenger is set down where it fell.
- EXP and level-ups with growth rates
- MP-based magic: Heal, Fire, Firestorm (area), Earth Spike (raises a mountain). Damage spells have an element (Fire, Earth...)
- Board/Unload: a unit next to an allied ship with room can Board it (ends the boarder's turn; a Galley holds 2). The ship can Unload passengers onto adjacent cells they can stand on without ending its own turn, and passengers that haven't acted can then move. A sunk ship's passengers are set down on the nearest free cell they can stand on
- Dance (Performer) refreshes an adjacent ally; Inspire (Bannerman) gives every adjacent ally +STR/DEF until the next player phase: +1, plus 1 more every 5 levels (+5 at Lv 20)
- Enemy AI that heals, picks weapons and casts spells
- Map readability: enemy danger zone, per-enemy range view, a movement arrow that follows the cursor's trail, full unit stats screen
- Configurable enemy behaviors (see below) and Fort tiles (DEF +2, AVO +20, heal 20% max HP at the start of the occupant's phase)
- Movement types (see below), shown as a small colored badge on each unit

## Classes

Set with `"class"` in a unit's roster entry (required); defined in `scripts/classes.gd`. Stats stay per unit. Promotion is data only for now (it will happen in a battle prep screen and keep the unit's level).

| Group | Class | Weapons | Move | Notes | Promotes to |
|---|---|---|---|---|---|
| Foot | Swordsman | Sword | foot | | Swordsmaster (Sword) |
| | Footman | Spear | foot | | Hoplite (Spear) |
| | Axeman | Axe | foot | | Berserker (Axe; swim_climb) |
| | Archer | Bow | foot | | Marksman (Bow) |
| Rogue | Rogue | Sword | rogue | | Assassin (Sword, Bow) |
| | Corsair | Sword | swim | | Swashbuckler (Sword, Axe; swim) |
| | Brigand | Axe | climb | | Berserker (Axe; swim_climb) |
| | Poacher | Bow | rogue | | Reaver (Bow, Axe) |
| Armor | Guard | Spear | foot | | Juggernaut (Spear, Axe, Bow) |
| | Turret | Bow | foot | | Juggernaut |
| Mage | Mage | Staff | foot | | Sorcerer (Staff, Sword) |
| | Cleric | Staff | foot | | Bishop (Staff, Spear) |
| Horse | Equestrian | Sword | horse | Mounted | Gendarme (Sword, Spear) |
| | Cavalry | Spear | horse | Mounted | Gendarme |
| | Nomad | Bow | horse | Mounted | Hussar (Bow, Spear) |
| Flying | Flier | Spear | flying | Mounted | Whitewing (Spear, Sword) |
| Ship | Galley | Bow | ship | Board/Unload, holds 2 | |
| Special | Performer | Sword | foot | Dance | |
| | Bannerman | Spear | foot | Inspire | |

Spells are separate from classes: any unit with `"spells"` in its roster entry can cast them.

## Races

Set with `"race"` in a unit's roster entry (default Human); defined in `scripts/races.gd`. Design and lore notes, including planned stat tendencies, are in [docs/races.md](docs/races.md). A race's movement replaces its class's, but the class's tag stays (a Centaur Guard moves as a horse and is a target for both the Pike and the Hammer). Ship classes keep sailing whatever the race.

| Race | Tags | Movement | Other | Can't take |
|---|---|---|---|---|
| Human | | | 1.1x EXP | |
| Orc | greenskin | | Poison immune* | |
| Troll | | | Regenerates 10% HP per turn; poison immune* | |
| Elf | fae | | | |
| Fairy | flying, fae | flying unless mounted | +1 MP regen | |
| Naga | aquatic, reptile | mermaid | | Mounted classes |
| Lizal | reptile | foot/scout classes also swim and climb | Poison immune* | |
| Centaur | horse | horse; +1 MOV in foot/scout classes | Can Rescue and Shove; can't be Rescued or Shoved | Flying classes |
| Minotaur | horse | | | Mounted classes |
| Harpy | flying | flying unless mounted | | Heavy classes |
| Ent | wooden | heavy | Can't be Rescued or Shoved | Mounted classes |
| Stoneborn | heavy | heavy | Can't be Rescued or Shoved; poison immune* | All but foot and heavy classes |
| Skeleton | undead | | Poison immune* | |
| Ghost | undead, spirit | spirit | Poison immune* | |

\* Poison isn't implemented yet.

| Tag | Weak to (x2) | Resists (1/2) |
|---|---|---|
| aquatic | spears, Lightning | Fire, Water |
| reptile | Ice | Fire |
| wooden | axes, Fire, Ice | Water, Earth |
| undead | silver weapons, Fire, Light | Dark |
| spirit | | weapons that aren't silver |

Only Fire and Earth spells exist so far.

## Terrain and movement types

A unit's class sets its movement type. Costs live in `BattleMap.TERRAIN` (– = impassable). Costs can be fractional, and a unit can be placed by Shove, Drop or Unload only on a tile it could enter in one move (cost ≤ MOV).

A unit's race can override it (see Races).

Movement types: **foot** (most units), **heavy** (armor), **horse**, **rogue** (scouts), **climb**, **swim**, **mermaid** (aquatic), **ship** (seafaring), **flying**, **spirit**, and the hybrids **swim_climb** (Berserker, amphibious races) and **rogue_swim_climb** (amphibious scouts), which pay the cheapest of their parts' costs on every tile. Fliers and spirits get no terrain DEF/AVO. Fliers pay 1 MOV anywhere a tile doesn't list them, and spirits always pay 1 MOV, even through walls, abysses and fences.

| Terrain | DEF | AVO | foot | heavy | horse | rogue | climb | swim | mermaid | ship | flying |
|---|---|---|---|---|---|---|---|---|---|---|---|
| Plain `.` | | | 1 | 1 | 1 | 1 | 1 | 1 | 3 | 6 | 1 |
| Path `=` | | -20 | 0.7 | 0.7 | 0.7 | 0.7 | 0.7 | 0.7 | 1.5 | 5 | 1 |
| House `H` | | +15 | 1 | 1 | 1.2 | 1 | 1 | 1 | 1 | 10 | 1 |
| Fort `T` (heals 20%) | +3 | +25 | 1.5 | 1.5 | 1.5 | 1.5 | 1.5 | 1.5 | 1.5 | 1.5 | 1 |
| Sand `S` | | +5 | 1 | 1 | 1.5 | 1 | 1 | 1 | 2 | 5 | 1 |
| Dune `D` | | +15 | 1.5 | 1.5 | 3 | 1.5 | 1.5 | 1.5 | 2 | 4 | 1 |
| Forest `F` | +1 | +20 | 2 | 2 | 4 | 1.5 | 2 | 2 | 3 | 10 | 1 |
| Thicket `#` | +2 | +30 | 10 | 10 | 20 | 6 | 10 | 10 | 10 | 20 | 1 |
| Hill `h` | +2 | +20 | 4 | 10 | 10 | 4 | 2 | 4 | 10 | 20 | 1 |
| Mountain `M` | +3 | +30 | 7 | 15 | 15 | 7 | 4 | 7 | 15 | 20 | 1 |
| River `~` / Lake `L` / Sea `W` | | +10 | 6 | 8 | 8 | 6 | 6 | 2 | 1 | 1 | 1 |
| Waterfall `v` | | +30 | 20 | 20 | 20 | 20 | 20 | 6 | 6 | 8 | 1 |
| Snow `*` | | +5 | 1 | 1 | 1.5 | 1 | 1 | 1 | 2 | 5 | 1 |
| Ice `i` | | -20 | 1.5 | 1 | 2 | 1.5 | 1.5 | 1.5 | 1 | 4 | 1 |
| Floor `_` / Carpet `c` | | | 1 | 1 | 1.5 | 1 | 1 | 1 | 3 | 10 | 1.5 |
| Wall `X` | | | – | – | – | – | – | – | – | – | – |
| Pillar `I` | | +20 | 2 | 2 | 2 | 2 | 2 | 2 | 2 | 20 | 1 |
| Abyss `O` / Fence `\|` | | | – | – | – | – | – | – | – | – | 1 |

## Enemy behaviors

Each enemy roster entry in `scripts/levels.gd` can have an `"ai"` dictionary: a preset, a preset plus overrides, or raw settings (all documented in `scripts/ai_profiles.gd`).

```gdscript
"ai": {"preset": "boss"}
"ai": {"preset": "coward", "targeting": "weakest"}
"ai": {"move": "hold", "wake": {"in_threat": true, "attacked": true, "group": "south"}}
```

| Setting | Options |
|---|---|
| `move` | `charge`, `in_range` (only moves to attack), `hold` (never moves), `guard` (stays within `guard_radius`), `goto` (heads for `destination`) |
| `attack` | `false` = never starts fights |
| `wake` | `radius`, `in_threat`, `turn`, `attacked`, `group`: switches to `awake_move` for good once any is met |
| `targeting` / `priority` | `damage`, `kill`, `weakest`; plus a list of unit names to prefer |
| `caution` | Weight on expected counter damage (0 = reckless) |
| `retreat_below` / `retreat_until` / `retreat_to` / `retreat_attacks` | Retreat at low HP to a healer, a healing tile, or away from players |

Presets: `charger` (default), `ambusher`, `boss`, `turret`, `sentry`, `sleeper`, `reinforcement`, `coward`, `thief`.

## Layout

- `scenes/level_select.tscn`, `scripts/level_select.gd`: the start screen
- `scenes/main.tscn`: the battle scene
- `scripts/levels.gd`: levels (terrain layout + both rosters)
- `scripts/battle.gd`: turn flow and input
- `scripts/combat.gd`, `experience.gd`: formulas
- `scripts/classes.gd`, `races.gd`, `weapons.gd`, `items.gd`, `spells.gd`: data
- `scripts/enemy_ai.gd`, `ai_profiles.gd`: enemy behavior and its settings/presets
- `scripts/battle_map.gd`, `unit.gd`, `cursor.gd`, `ui.gd`: map, units and HUD
- `scripts/status_screen.gd`, `glossary.gd`: the GBA-style status screen and its detail-mode help text
