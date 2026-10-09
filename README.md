# SRPG_Engine

A tactical RPG prototype in the style of the GBA Fire Emblem games, built with Godot 4.4 (GDScript).

## Running

Open the folder in Godot 4.4 and press F5. The game starts on a level select screen (for testing), which also has **Options** and, after a suspend, **Resume**. In a battle, Z on an empty tile opens the map menu:

| Entry | What it does |
|---|---|
| Units | Sortable table of every unit (Left/Right: sort column, Z: go to unit, D: status) |
| Objective | Victory/defeat conditions, turn, units left |
| Options | Game speed, fast-forward speed, danger zone at start, auto-end turn, end turn warning, level-up window (saved to `user://settings.cfg`) |
| Suspend | Saves the battle to `user://suspend.save` and returns to the level select (deleted when the map ends) |
| Restart | Restarts the map (asks first) |
| Level Select | Back to the level select (on the Victory/Defeat screen, X also goes there) |
| End Turn | Ends the player phase. Always last, so Up from the top of the menu reaches it. Asks first if units haven't acted, unless the "End turn warning" option is off |

| Level | Shows off |
|---|---|
| River Crossing | Mixed army, magic, forts, Inspire, every enemy behavior preset |
| Coastal Raid | Movement types and ships: horse, flier, rogue, naga, a Corsair and a Galley to ferry troops, vs. climbing Brigands, a Harpy and galleys; the Swashbuckler boss holds an island fort |
| Desert Outpost | Sand, dunes, paths, houses, an oasis; horses vs. scouts in the desert |
| Frozen Pass | Snow, ice, hills, mountains, thickets, a waterfall; climbers, a swimmer and armor on ice |
| Castle Keep | Indoors: floor, carpet, walls, pillars, pits and fences; slow mounted units and a wall-walking Wraith |
| Ruined Fort | Breakable terrain: a cracked wall and fence, a locked door (the Scout opens it) and trunks to fell across the river. Skills: the Lord has Sol, the Warden boss Pavise and Vantage; a Power Ring and a Celerity Scroll |
| Great Valley | A 30x20 map: the camera scrolls with the cursor (and follows moving units), stopping at the map edges |

## Campaign

**New Campaign** on the level select starts five chapters played by one army (`scripts/chapters.gd`, state in `scripts/campaign.gd`, saved to `user://campaign.save`):

| Chapter | Objective | Also introduces | Recruits |
|---|---|---|---|
| 1. Border Village | Rout | Villages to Visit; a Thief that burns them | Lord, Rider, Fighter, Archer, Cleric |
| 2. Hill Fort | Seize the throne | Chests (Lockpick opens them freely, others need a Chest Key) | Scout |
| 3. The Bandit King | Defeat the boss | Boss on a hilltop fort | Pegasus |
| 4. The Siege | Defend the town hall 7 turns | Reinforcement waves; losing if an enemy reaches the tile | Guard, Mage |
| 5. Flight from the Keep | Escape (Lord through the gate) | Escape command; other units can leave early | Dancer |

- **Carried over:** levels, EXP, items and promotions. Survivors are healed between chapters.
- **Permadeath:** fallen units leave the army for good. They're kept in `Campaign.fallen` (with chapter and turn) for future mechanics, and "Fell in …" is added to their biography.
- **Defeat** retries the chapter with the army as it was before it.
- **Prep screen** before each chapter: Pick Units (the Lord always deploys), Items (unit ↔ convoy), Promote (Lv 15+, class-dependent stat bonus, level kept), Status, Fight!
- **Biography** logs joining, promotion, seizing and falling.
- **Objectives** (`scripts/objectives.gd`) work on any level: `"objective": {"type": "rout" | "boss" | "seize" | "survive" | "defend" | "escape", ...}`, plus `"objects"` (villages, chests) and `"reinforcements"` (enemies arriving on a given turn).

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
- Maps of any size: a camera (`scripts/battle_camera.gd`) shows a 15x10 window and scrolls, GBA-style, to keep the cursor (or a moving unit) 2 tiles from the screen edge; panels go on the side of the screen away from the cursor. Maps that fit on one screen don't scroll
- Map readability: enemy danger zone, per-enemy range view, a movement arrow that follows the cursor's trail, full unit stats screen
- Configurable enemy behaviors (see below) and Fort tiles (DEF +2, AVO +20, heal 20% max HP at the start of the occupant's phase)
- Movement types (see below), shown as a small colored badge on each unit
- Skills (design: [docs/skills.md](docs/skills.md)), defined in `scripts/skills.gd`. A unit has the skills of every source: personal (roster `"skills"`), class, race, learned, its equipped weapon and the non-weapon items it holds (rings). Learned skills come from level-up tables (class or roster `"learn": {level: skill}`) and scrolls, capped at 5: learning a sixth asks which to forget (or not to learn it; an unread scroll isn't used up). Skills can give stat bonuses, unit menu commands (Dance, Inspire), turn-start healing/MP, an EXP multiplier and immunities; racial traits (Human EXP bonus, Troll regeneration, Fairy MP, poison immunity) are race skills. The status screen's Skills page lists them with their source (skills marked hidden never show), and skill-boosted stats show in gold. Combat skills: battle modifiers with conditions (Wrath, Death Blow, Darting Blow, Steady Stance, the Breakers), strike-order rules (Vantage, Desperation, Quick Riposte, Wary Fighter, Dazzle, Close Counter) and procs that roll each strike and pop up their name (Luna, Sol, Lethality, Pavise, Aegis, Miracle). The forecast and the enemy AI include modifiers and rules but not procs. Also: after-combat effects (Lifetaker, Galeforce, Poison Strike, Savage Blow), turn-start healing (Renewal), movement (Pass, Pathfinder, Canto: move again with the MOV left after acting, not after Wait), auras (Charisma, Anathema, Fortify), adjacency conditions (Solo Fighter) and growth/EXP skills (Aptitude, Paragon). Class skills (see Classes): terrain movement (Forester, Climbing, Swimming), Steal (take a non-weapon item from an adjacent foe with lower AGI), Lockpick (chests and doors without a key), Canto on mounted classes, range bonuses (Bow Range +1, Spell Range +1), terrain Hit bonuses (Sea Legs, Ambush, Highlander), Prayer (adjacent allies heal 10% each turn), Footwork (Canto after Dancing), Warding (+5 magic defense)
- Hidden gender (`Unit.gender`, "male" or "female"): never shown, but rules can check it (e.g. mounts that only take some riders). Set with `"gender"` in a roster entry; units without one get a random gender. Saved with the unit
- Breakable tiles: **Break** picks a weapon that reaches a breakable tile, then the tile. It always hits for the unit's Attack (STR + Mt), with no counter, crit or EXP, and uses weapon durability. Works at range. Cracked Wall (20 HP) becomes floor, Cracked Fence (10 HP) becomes plain, and a Trunk (15 HP) becomes plain and falls into adjacent river/lake water as a Bridge of up to 3 tiles (away from the attacker if there's water that way, otherwise toward the first side with water). Hovering a breakable tile shows its remaining HP. Tile HP is kept when suspending
- Doors (20 HP): **Open Door** for an adjacent unit that could open a chest (Lockpick: freely, anyone else uses up a Chest Key); otherwise they must be broken

## Classes

Set with `"class"` in a unit's roster entry (required); defined in `scripts/classes.gd`. Stats stay per unit. Promotion is data only for now (it will happen in a battle prep screen and keep the unit's level).

Innate skills come with the class (a promoted class lists its own full set); Lv 10 skills are learned for good on reaching level 10 in the class (see Skills). Scouts, climbers and swimmers move as foot units with a terrain skill.

| Group | Class | Weapons | Move | Innate skills | Lv 10 | Promotes to (innate skills) |
|---|---|---|---|---|---|---|
| Foot | Swordsman | Sword | foot | | Speed +2 | Swordsmaster (Sword; Crit +20) |
| | Footman | Spear | foot | | Open Ground | Hoplite (Spear; Impale) |
| | Axeman | Axe | foot | | Strength +2 | Berserker (Axe; Swimming, Climbing, Wrath) |
| | Archer | Bow | foot | | Skill +4 | Marksman (Bow; Bow Range +1) |
| Rogue | Rogue | Sword | foot | Forester, Steal, Lockpick | Evasion | Assassin (Sword, Bow; Forester, Steal, Lockpick, Lethality) |
| | Corsair | Sword | foot | Swimming | Sea Legs | Swashbuckler (Sword, Axe; Swimming, Pass) |
| | Brigand | Axe | foot | Climbing | Highlander | Berserker |
| | Poacher | Bow | foot | Forester | Ambush | Reaver (Bow, Axe; Forester, Brawn) |
| Armor | Guard | Spear | heavy | | Defense +2 | Juggernaut (Spear, Axe, Bow; Warding) |
| | Turret | Bow | heavy | | Max HP +5 | Juggernaut |
| Mage | Mage | Staff | foot | | Magic +2 | Sorcerer (Staff, Sword; Spell Range +1) |
| | Cleric | Staff | foot | | Max MP +5 | Bishop (Staff, Spear; Prayer) |
| Horse | Equestrian | Sword | horse | Canto | | Gendarme (Sword, Spear; Canto) |
| | Cavalry | Spear | horse | Canto | | Gendarme |
| | Nomad | Bow | horse | Canto | | Hussar (Bow, Spear; Canto) |
| Flying | Flier | Spear | flying | Canto | | Whitewing (Spear, Sword; Canto) |
| Ship | Galley | Bow | ship | (Board/Unload, holds 2) | | |
| Special | Performer | Sword | foot | Dance | Footwork | |
| | Bannerman | Spear | foot | Inspire | | |

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
| Lizal | reptile | foot classes (scouts too) also get Swimming and Climbing | Poison immune* | |
| Centaur | horse | horse; +1 MOV in foot classes | Can Rescue and Shove; can't be Rescued or Shoved | Flying classes |
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

Movement types: **foot** (most units), **heavy** (armor), **horse**, **mermaid** (aquatic), **ship** (seafaring), **flying**, **spirit**. Terrain specialties are skills that make their own terrain cheaper and nothing else: **Forester** (forest 1.5, thicket 6: scouts), **Climbing** (hill 2, mountain 4: Brigands), **Swimming** (river/lake/sea 2, waterfall 6: Corsairs); Berserkers and amphibious races in foot classes have both Swimming and Climbing. **Pathfinder** makes every enterable tile cost 1. Fliers and spirits get no terrain DEF/AVO. Fliers pay 1 MOV anywhere a tile doesn't list them, and spirits always pay 1 MOV, even through walls, abysses and fences.

| Terrain | DEF | AVO | foot | heavy | horse | mermaid | ship | flying |
|---|---|---|---|---|---|---|---|---|
| Plain `.` | | | 1 | 1 | 1 | 3 | 6 | 1 |
| Path `=` | | -20 | 0.7 | 0.7 | 0.7 | 1.5 | 5 | 1 |
| House `H` | | +15 | 1 | 1 | 1.2 | 1 | 10 | 1 |
| Fort `T` (heals 20%) | +3 | +25 | 1.5 | 1.5 | 1.5 | 1.5 | 1.5 | 1 |
| Sand `S` | | +5 | 1 | 1 | 1.5 | 2 | 5 | 1 |
| Dune `D` | | +15 | 1.5 | 1.5 | 3 | 2 | 4 | 1 |
| Forest `F` | +1 | +20 | 2 | 2 | 4 | 3 | 10 | 1 |
| Thicket `#` | +2 | +30 | 10 | 10 | 20 | 10 | 20 | 1 |
| Hill `h` | +2 | +20 | 4 | 10 | 10 | 10 | 20 | 1 |
| Mountain `M` | +3 | +30 | 7 | 15 | 15 | 15 | 20 | 1 |
| River `~` / Lake `L` / Sea `W` | | +10 | 6 | 8 | 8 | 1 | 1 | 1 |
| Waterfall `v` | | +30 | 20 | 20 | 20 | 6 | 8 | 1 |
| Snow `*` | | +5 | 1 | 1 | 1.5 | 2 | 5 | 1 |
| Ice `i` | | -20 | 1.5 | 1 | 2 | 1 | 4 | 1 |
| Floor `_` / Carpet `c` | | | 1 | 1 | 1.5 | 3 | 10 | 1.5 |
| Wall `X` | | | – | – | – | – | – | – |
| Pillar `I` | | +20 | 2 | 2 | 2 | 2 | 20 | 1 |
| Abyss `O` / Fence `\|` | | | – | – | – | – | – | 1 |
| Cracked Fence `/` (10 HP) / Trunk `Y` (15 HP) | | | – | – | – | – | – | 1 |
| Cracked Wall `x` / Door `+` (20 HP) | | | – | – | – | – | – | – |
| Bridge `B` (water units pass under) | | | 1 | 1 | 1 | 1 | 1 | 1 |

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
| `breaks` | Default `true`: when moving, opens doors (if it could open a chest) and breaks breakable tiles that block a shorter way to its goal |

Presets: `charger` (default), `ambusher`, `boss`, `turret`, `sentry`, `sleeper`, `reinforcement`, `coward`, `thief`.

## Layout

- `scenes/level_select.tscn`, `scripts/level_select.gd`: the start screen
- `scenes/main.tscn`: the battle scene
- `scripts/levels.gd`: levels (terrain layout + both rosters)
- `scripts/battle.gd`: the battle scene root: shared state (`state`, `turn`, ...), unit queries and enemy threat. Its parts are child nodes reached as `battle.input`, `battle.actions` and `battle.phases`:
  - `battle_input.gd`: player input, menus, targeting and forecasts, the trade and info screens
  - `battle_actions.gd`: what units can do and doing it (shove, rescue, ships, break, combat, EXP...), shared by the player and the enemy AI
  - `battle_phases.gd`: player/enemy phases, reinforcements, game over, campaign and suspend flow
- `scripts/combat.gd`, `experience.gd`: formulas
- `scripts/classes.gd`, `races.gd`, `weapons.gd`, `items.gd`, `spells.gd`: data
- `scripts/enemy_ai.gd`, `ai_profiles.gd`: enemy behavior and its settings/presets
- `scripts/battle_map.gd`, `unit.gd`, `cursor.gd`, `ui.gd`: map, units and HUD
- `scripts/status_screen.gd`, `glossary.gd`: the GBA-style status screen and its detail-mode help text
- `scripts/unit_list.gd`, `options_screen.gd`: the Units and Options screens
- `scripts/save_game.gd`, `settings.gd`: suspend data (units saved generically; see `Unit.SAVE_SKIP`) and options
- `scripts/campaign.gd`, `chapters.gd`, `objectives.gd`, `prep_screen.gd` (+ `scenes/prep.tscn`): the campaign, its chapters, map objectives and the prep screen
