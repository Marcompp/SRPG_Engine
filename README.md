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

## Features

- Grid movement with terrain costs, player and enemy phases, Victory (rout) and Defeat (lord dies)
- FE-style combat: hit/crit with "two RN" true hit, weapon triangle, doubling, weapon weight and durability
- Ranged weapons (bows, javelins, hatchets, knives); bows win the triangle at range
- 5-slot inventories with equip, weapon choice on attack
- EXP and level-ups with growth rates
- MP-based magic: Heal, Fire, Firestorm (area), Earth Spike (raises a mountain)
- Dancer, Cleric and Mage units; enemy AI that heals, picks weapons and casts spells

## Layout

- `scenes/main.tscn`: the battle scene
- `scripts/battle.gd`: turn flow, input, unit rosters
- `scripts/combat.gd`, `experience.gd`: formulas
- `scripts/weapons.gd`, `spells.gd`: data
- `scripts/enemy_ai.gd`: enemy behavior
- `scripts/battle_map.gd`, `unit.gd`, `cursor.gd`, `ui.gd`: map, units and HUD
