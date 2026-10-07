# SRPG_Engine

A tactical RPG prototype in the style of the GBA Fire Emblem games, built with Godot 4.4 (GDScript).

## Running

Open the folder in Godot 4.4 and press F5.

## Tests

Headless test suite (combat math, ranges, inventory, EXP, spells, Dance, enemy AI, full enemy phases):

```
godot --headless --path . --script res://tests/run_tests.gd
```

Exits with code 0 when every test passes, 1 otherwise.

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

## Layout

- `scenes/main.tscn`: the battle scene
- `scripts/battle.gd`: turn flow, input, unit rosters
- `scripts/combat.gd`, `experience.gd`: formulas
- `scripts/weapons.gd`, `items.gd`, `spells.gd`: data
- `scripts/enemy_ai.gd`: enemy behavior
- `scripts/battle_map.gd`, `unit.gd`, `cursor.gd`, `ui.gd`: map, units and HUD
