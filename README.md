# SRPG_Engine

A tactical RPG prototype in the style of the GBA Fire Emblem games, built with Godot 4.4 (GDScript).

## Running

Open the folder in Godot 4.4 and press F5. The game starts on a level select screen (for testing). In a battle, Z on an empty tile opens a menu with **Level Select**; on the Victory/Defeat screen, X returns there.

| Level | Shows off |
|---|---|
| River Crossing | Mixed army, magic, forts, every enemy behavior preset |
| Coastal Raid | Movement types: cavalry, a pegasus, an outlaw and a siren vs. galleys, a naga and a wyvern; the boss holds an island fort |

## Tests

Headless test suite (combat math, ranges, inventory, EXP, spells, Dance, enemy AI, levels, movement types, full enemy phases):

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
| R | Unit stats screen (Up/Down: next unit) |
| Hover a unit | Show its move and attack range (either side) |
| Z on an enemy | Mark it: red overlay of its threat (Z again to unmark) |

## Features

- Grid movement with terrain costs, player and enemy phases, Victory (rout) and Defeat (lord dies)
- FE-style combat: hit/crit with "two RN" true hit, weapon triangle, doubling, weapon weight and durability
- Ranged weapons (bows, javelins, hatchets, knives); bows win the triangle at range
- 5-slot inventories with equip, weapon choice on attack, and consumables (Potion: 3 uses, heals 15)
- Trade with adjacent allies any number of times before acting (trading commits the move)
- Shove (FE9-style): any unit can push an adjacent ally one tile away, onto walkable empty ground; ends the shover's turn
- EXP and level-ups with growth rates
- MP-based magic: Heal, Fire, Firestorm (area), Earth Spike (raises a mountain)
- Dancer, Cleric and Mage units; enemy AI that heals, picks weapons and casts spells
- Map readability: enemy danger zone, per-enemy range view, a movement arrow that follows the cursor's trail, full unit stats screen
- Configurable enemy behaviors (see below) and Fort tiles (DEF +2, AVO +20, heal 20% max HP at the start of the occupant's phase)
- Movement types (see below), shown as a small colored badge on each unit

## Movement types

Set with `"move"` in a unit's roster entry (default `foot`). Costs per terrain, from `BattleMap.MOVE_COSTS` (– = impassable):

| Type | Plain | Forest | Mountain | River | Sea | Sand | Fort | Notes |
|---|---|---|---|---|---|---|---|---|
| foot | 1 | 2 | – | – | – | 1 | 2 | |
| horse | 1 | 3 | – | – | – | 2 | 2 | |
| rogue | 1 | 1 | – | – | – | 1 | 2 | |
| flying | 1 | 1 | 1 | 1 | 1 | 1 | 1 | Gets no terrain DEF/AVO |
| ship | – | – | – | 1 | 1 | – | – | Water only |
| mermaid | 2 | 3 | – | 1 | 1 | 2 | 2 | |

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
- `scripts/weapons.gd`, `items.gd`, `spells.gd`: data
- `scripts/enemy_ai.gd`, `ai_profiles.gd`: enemy behavior and its settings/presets
- `scripts/battle_map.gd`, `unit.gd`, `cursor.gd`, `ui.gd`: map, units and HUD
