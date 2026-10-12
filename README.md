# SRPG_Engine

A tactical RPG prototype in the style of the GBA Fire Emblem games, built with Godot 4.4 (GDScript).

## Running

Open the folder in Godot 4.4 and press F5. The game starts on a level select screen (for testing), which also has **Options** and, after a suspend, **Resume**. In a battle, Z on an empty tile (or a unit that already acted) opens the map menu:

| Entry | What it does |
|---|---|
| Units | Sortable table of every unit (Left/Right: sort column, Z: go to unit, D: status) |
| Objective | Victory/defeat conditions, turn, units left |
| Options | Game speed, fast-forward speed, danger zone at start, auto-end turn, end turn warning, level-up window, auto save, turn rewinds (saved to `user://settings.cfg`) |
| Rewind | Back to the start of any earlier player phase on this map (this turn's included), newest first. Uses per map come from Options (3 by default; 1, 5, unlimited or off); history and uses are kept in suspends |
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
| Loyal Steeds | Mounts: a Loyal horse and pegasus on your side (the mount takes a fatal blow once), a Loyal enemy Lancer, and a level 20 rider whose level 1 horse still levels up |
| Status Trials | Status effects: the Knight starts petrified (Restore or a Panacea), the Lord poisons with a Venom Edge and Envenom (not the Orc), the Witch casts Sleep, Silence, Bind and Berserk (try it on the packed Brigands, or Silence the Mender), and an enemy Venom Edge poisons you back (Antitoxin) |
| Royal Pursuit | The Royal Guard (demo campaign mechanic): escape east across the river while bandits hold the bridges. On turn 3 the Guard (yellow) arrives behind you and follows Rosalind without attacking; if one gets next to her she's caught and the map is lost, and none of them may fall. Block the bridges to hold them back. The danger zone shows where they could catch her |
| Three Armies | Factions: green militia guarding a village, purple mercenaries hunting the raiders (until Gorr buys them on turn 3; the Lord can talk Varga's band over to your side), and villagers to keep alive: defeat Gorr, and the Elder must not fall |

## Campaign

**New Campaign** on the level select starts five chapters played by one army (`data/chapters/`, format in `scripts/chapters.gd`, state in `scripts/campaign.gd`, saved to `user://campaign.save`):

| Chapter | Objective | Also introduces | Recruits |
|---|---|---|---|
| 1. Border Village | Rout | Villages to Visit; a Thief that burns them | Lord, Rider, Fighter, Archer, Cleric |
| 2. Hill Fort | Seize the throne | Chests (Lockpick opens them freely, others need a Chest Key) | Scout |
| 3. The Bandit King | Defeat the boss | Boss on a hilltop fort | Pegasus |
| 4. The Siege | Defend the town hall 7 turns | Reinforcement waves; losing if an enemy reaches the tile | Guard, Mage |
| 5. Flight from the Keep | Escape (Lord through the gate) | Escape command; other units can leave early | Dancer |

- **Carried over:** levels, EXP, items, promotions and the army's gold. Survivors are healed between chapters.
- **Gold:** each chapter pays a reward when won (1000 for chapter 1, up to 3000); thieves and bosses carry gold (defeat them or Steal it), some villages and chests hold gold, and chapter 3 has a shop on the map. The prep screen's Shop stocks more from chapter 3 on.
- **Permadeath:** fallen units leave the army for good. They're kept in `Campaign.fallen` (with chapter and turn) for future mechanics, and "Fell in …" is added to their biography.
- **Defeat** retries the chapter with the army as it was before it.
- **Prep screen** before each chapter: Pick Units (the Lord always deploys), Items (unit ↔ convoy), Shop (buy into the convoy, sell from it), Repair (any worn or broken weapon in the army or convoy, for the price of the uses it restores), Stable (assign, unassign and rename mounts; riders a mount refuses say why), Promote (Lv 15+, class-dependent stat bonus, level kept), Status, Check Map, Fight!
- **Check Map** opens the chapter's map before it starts, with the deploy cells outlined: look around as in battle (ranges, danger zone, marks, status, unit list, objective), and Z on a unit then Z on a deploy cell to move it there (swapping with whoever is on it). The layout is kept for the battle, for restarts and for retries after a defeat. Z on an empty tile: Fight! (start from the map), Units, Objective, Options, Back to Prep; X also goes back to prep
- **Biography** logs joining, promotion, seizing and falling, plus moments from play: a unit's first kill, defeating a boss (noting a critical finishing blow), barely surviving a hit (10% HP or less, once per battle) and being saved by Miracle.
- **Generic enemies** (roster `"generic": true`, all non-boss campaign enemies) get a random name by race and gender (`data/names.cfg`; races without their own lists use the default ones).
- **Objectives** (`scripts/objectives.gd`) work on any level: `"objective": {"type": "rout" | "boss" | "seize" | "survive" | "defend" | "escape", ...}` (any type can add `"protect": [names]`, losing if one of them falls, and `"caught_by": side`, losing if a unit of that side is ever next to the Lord; the danger zone shows where they could catch it), plus `"objects"` (villages, chests) and `"reinforcements"` (enemies arriving on a given turn).

## Tests

Headless test suite, split by topic in `tests/test_*.gd` (shared helpers in `tests/test_base.gd`): `core` (combat, magic, items, trade), `ai`, `units` (movement, classes, races), `ui` (screens, suspend, options, rewind), `campaign` (including the prep screen and Check Map), `maps` (breakable terrain, the camera), `skills`, `events`, `mounts`, `statuses`, `factions`, `text` (translation groundwork), `economy`, `weapons` and `data` (the data files and the names they use for each other). Every method named `test_*` in a suite runs on a fresh battle; there's no list to update. Battles run 60x faster than normal in tests (`SPEED_BOOST` in `tests/run_tests.gd`, via `Battle.speed_boost`); tests that check the game speed itself set it back to 1. The whole suite takes about a minute.

```
GODOT=/path/to/godot tests/run_tests.sh            # everything
GODOT=/path/to/godot tests/run_tests.sh skills ui  # just these suites
```

Exits with code 0 when every test passes, 1 otherwise. The wrapper also fails if Godot printed any runtime script error, because Godot logs those and keeps running, so the GDScript runner can't see them. To run the suite directly: `godot --headless --path . --script res://tests/run_tests.gd [-- suite...]`.

## Translation

Not translated yet, but ready for it: player-facing text goes through `tr()` with the English text as its key, and `tools/extract_strings.gd` collects every key into a gettext template (`godot --headless --path . --script res://tools/extract_strings.gd` writes `locale/messages.pot`). Rules for writing text: `docs/translation.md`.

## Controls

| Key | Action |
|---|---|
| Arrow keys | Move cursor / menu selection |
| Z, Enter, Space | Confirm |
| X, Esc, Backspace | Cancel / go back |
| C | Toggle enemy danger zone |
| D | Status screen. Left/Right: page (Stats, Items, Skills, Bio), Up/Down: unit, D: detail mode (highlight anything to see its description), X: back/close (the cursor stays on the unit flipped to) |
| A | Jump the cursor to the next unit that hasn't acted; on an enemy, to the next enemy |
| Hold X (enemy phase) | Fast-forward at 4× speed |
| Z (level-up window) | Continue |
| Hover a unit | Show its move and attack range (either side) |
| Z on an enemy | Mark it: red overlay of its threat (Z again to unmark) |
| Z on an enemy or a hurt ally while moving a unit | Move to a cell it can attack/heal from (the last cell hovered if possible, else the nearest to it), then pick the weapon or spell with that unit targeted |

## Features

- Grid movement with terrain costs, player and enemy phases, Victory (rout) and Defeat (lord dies)
- Classes (see below): each decides a unit's weapon types, movement type and abilities
- Races (see below): per-unit, independent of class; can change movement, add effectiveness tags, weaknesses and resistances, and give regen or EXP perks
- FE-style combat: hit/crit with "two RN" true hit, weapon triangle (sword > axe > spear > sword), doubling, weapon weight and durability. A weapon that runs out of uses breaks but stays (as in Three Houses): still usable at half Mt, -30 Hit and no Crit until repaired, and labeled "broken" in menus
- Ranged weapons (bows, javelins, hatchets, knives); bows win the triangle at range. Staves are melee weapons outside the triangle
- Effectiveness levels, checked against a unit's tags (its class's move type plus its race's tags). **Effective** (×3 might, tagged "x3" in the forecast): bows vs fliers, Pike vs horses, Hammer vs heavy armor, Woodcutter vs ships, silver weapons vs spirits. **Weak** (×2 might or spell power, "x2"): whole weapon types and spell elements vs some races (see Races). **Resistant** (half damage, "1/2"): spirits vs non-silver weapons, and some races vs elements. Levels don't stack: the strongest one counts
- 5-slot inventories with equip, weapon choice on attack, and consumables (Potion: 3 uses, heals 15; Ether: 3 uses, restores 15 MP; Antitoxin: 3 uses, cures Poison; Panacea: 1 use, cures every status; Repair Kit: 2 uses, restores a chosen weapon to full uses). Units can carry weapons their class can't wield (marked `(x)`), but not equip them
- Trade with adjacent allies any number of times before acting (trading commits the move)
- Shove (FE9-style): any unit that isn't mounted or a ship can push an adjacent ally (also not mounted or a ship) one tile away, onto walkable empty ground; ends the shover's turn. Centaurs can shove; Centaurs, Ents and Stoneborn can't be shoved
- Weapon traits (`scripts/weapon_traits.gd`): every weapon keeps a kill history (who it killed: foe tags and weapon types; how: crits, counters or its own attacks, at range, bosses; and its wielder's state: low HP, no ally adjacent, under a status). On its 50th kill it earns one trait, a skill granted while it's equipped, rolled with weights from that history (an armor-killer leans to Armorbane, a weapon of desperate last stands to Wrath or Vantage). New trait skills: the -bane family (+5 Atk against a kind of foe) and Far Shot. The trait stays with the weapon; the description shows kills toward it, and the wielder's biography notes it
- Mounts (design: [docs/mounts.md](docs/mounts.md), data: `data/mount_species.cfg`, `data/mounts.cfg`): Horse, Pegasus (flying, female riders only) and Drake (new `drake` move type: foot costs, but hills and mountains like a climber; reptile). Riding reclasses a unit into its foot class's mounted class (Swordsman/Rogue/Corsair/Performer: Equestrian; Footman/Bannerman: Cavalry; Axeman/Brigand: Raider; Archer/Poacher: Nomad; Mage/Cleric: Battlemage; promotions likewise), keeping the foot class's innate skills except terrain movement. Heavy armor can't ride. While mounted, STR/INT/DEX/AGI/LCK/DEF are the rider's / 2 + the mount's, HP and MP stay the rider's, and MOV is the species'. Mounts have levels (cap 10), growths, EXP worked out on their own (the combat formula with the mount's level, counted double, against the foe's, times a species rate; non-combat EXP is the fixed amount times the rate), so a young mount under a veteran levels fast, with their own level-up popup; a level 20 rider's mount keeps earning EXP, a visible gender and skills; **Loyal** lets the mount take a fatal blow once (the rider survives on foot at 1 HP). Rosters give units a `"mount": {"species": ...}` (level defaults to half the rider's); promotion goes through the foot class and stays mounted. In the campaign, mounts ride with their unit or wait in the stable
- Rescue/Drop (Thracia 776-style): mounted units and Centaurs can carry an adjacent ally off the map (not a mounted unit, ship, Centaur, Ent or Stoneborn) (carrier's DEX/AGI halved) and set it down on an adjacent tile later. Each action ends the carrier's turn, but a dropped ally that hasn't acted can still move, so mounted units can ferry others. A fallen carrier's passenger is set down where it fell.
- EXP and level-ups with growth rates
- MP-based magic: Heal, Restore (cures statuses), Fire, Firestorm (area), Earth Spike (raises a mountain). Damage spells have an element (Fire, Earth...)
- Board/Unload: a unit next to an allied ship with room can Board it (ends the boarder's turn; a Galley holds 2). The ship can Unload passengers onto adjacent cells they can stand on without ending its own turn, and passengers that haven't acted can then move. A sunk ship's passengers are set down on the nearest free cell they can stand on
- Dance (Performer) refreshes an adjacent ally (Dancing another dancer is a Duet: every ally next to either one is refreshed, chaining through other adjacent dancers, but the dancers aren't); Inspire (Bannerman) gives every adjacent ally +STR/DEF until the next player phase: +1, plus 1 more every 5 levels (+5 at Lv 20)
- Enemy AI that heals, picks weapons and casts spells
- Kill counts per unit and per weapon (shown in the weapon's description); spell kills count for the unit only
- Auto save (Options, on by default): the start of every player phase is saved, so the level select can resume from there
- Map events: dialogue and cutscenes (design: [docs/events.md](docs/events.md)). Each map can have an `events/<map id>.txt` file written like a screenplay (`Lord: line`, `@move Bandit (10, 4)`, `@recruit Thief`...; full format in `scripts/event_script.gd`). Triggers: map start, the start of a turn's player or enemy phase, Talk (a unit menu command next to the named unit; can recruit), before a fight involving a unit (boss quotes), a unit's death, a unit ending its move in an area (cells or rectangles, optionally one unit or side; a scene commits the move), a village visit (before its reward), and victory/defeat (before the end screen). Events run once (or `| repeat`), can depend on flags they set (`| if flag`), and are saved with suspends and rewinds. GBA-style dialogue box with two portrait slots (placeholders until there's art): Z advances, hold X to type faster, S skips the scene. Great Valley has sample events for every trigger (opening, enemy-phase message, recruiting the Wyrm by talking to it with Ember, boss quotes, a death quote, village text, an area near the General's fort, victory and defeat)
- Maps of any size: a camera (`scripts/battle_camera.gd`) shows a 15x10 window and scrolls, GBA-style, to keep the cursor (or a moving unit) 2 tiles from the screen edge; panels go on the side of the screen away from the cursor. Maps that fit on one screen don't scroll
- Map readability: placeholder class icons on unit tokens and status screen portraits until there are sprites (a 7x7 pixel icon per role in `data/icons.cfg`, picked by each class's `icon`; dialogue portraits keep the initial), enemy danger zone (it updates once a unit has moved, while it still picks its action, so you can see how the move changes what enemies reach), per-enemy range view, unit ranges on hover (move blue, attack red, status spells yellow, healing green), a movement arrow that follows the cursor's trail, full unit stats screen
- Status effects (design: [docs/status_effects.md](docs/status_effects.md)), defined in `data/statuses.cfg`: an active status works like a skill internally (its effects use skill keys) but isn't listed with them: it shows as a colored dot on the unit, a "Status:" line in the info panel and a square on the status screen's Stats page (highlight it for what it does and the turns left), ticks at the start of its side's phase and counts down at the end of it (a duration is how many of the unit's own phases it lasts). Poison: 4-6 damage each phase start for 3 turns, never below 1 HP unless already at 1 (then it kills, no EXP); Poison Immunity blocks it. Silence (3): no spells or racial attacks. Sleep (2): can't move, act or counter; damage wakes it. Paralyse (1): can't move. Berserk (3): the AI plays its turn at the start of its phase, attacking the nearest unit it can reach on any side (no EXP for hitting its own side). Petrify (until cured, lingers between chapters): can't move, act or counter, DEF +10, Avoid 0. Asleep or petrified enemies drop out of the danger zone. Weapons and spells with `"inflict"` give a status on a hit (the forecast shows a Status row): Venom Edge (poisons), and the no-damage, no-counter status spells Silence, Sleep, Bind (Paralyse), Berserk and Stone (Petrify), which the enemy AI doesn't cast yet. Envenom skill: poisons the foe it attacked after combat. Cleared between chapters unless the status lingers. Events: `@status` / `@cure`
- Factions (design: [docs/factions.md](docs/factions.md)), in `scripts/factions.gd`: besides the player (blue) and enemy (red), levels can field allies (green, roster `"allies"`), a third army (purple, `"others"`) and neutrals (yellow, `"neutrals"`). Each AI side gets its own phase after yours (Ally, Enemy, Other, Neutral; sides with no units are skipped) and attacks whatever its side is hostile to: green fights red and purple, purple fights everyone, neutrals fight no one. A level's `"relations"` can override who's hostile to whom. You can move through green units; a rout means defeating every unit hostile to you. Turn events can name any phase (`== turn 2, ally ==`, or by color: `green`). Your units can Heal, Restore and Rescue green allies, who earn EXP and level up; attacking a neutral turns all neutrals hostile to you. Objectives can add `"protect": [names]`. Events: `@hostile`, `@peace` (two sides start or stop fighting) and `@side` (a unit changes sides)
- Gold (design: [docs/economy.md](docs/economy.md)): one purse for the army (`Campaign.gold`, starting at 1000; a battle works on its own copy, kept if the chapter is won). Income: a chapter's `"reward"`, villages and chests with `"gold"`, enemies carrying roster `"gold"` (defeat them, or Steal it), and selling at shops (half the value). Shops: the prep screen's Shop (buy into the convoy, sell from it; the chapter's `"shop"` stock, or a default one) and shop objects on maps (`{"type": "shop", "cell", "stock": [...]}`: a unit on one gets a Shop command to buy into or sell from its inventory; buying or selling ends its turn). Every item has a price (`data/economy.cfg`); a worn one is worth its uses left. The prep screen's Repair costs the price of the uses it restores. Funds show on the prep and Objective screens
- Configurable enemy behaviors (see below) and Fort tiles (DEF +2, AVO +20, heal 20% max HP at the start of the occupant's phase)
- Movement types (see below), shown as a small colored badge on each unit
- Skills (design: [docs/skills.md](docs/skills.md)), defined in `data/skills.cfg`. A unit has the skills of every source: personal (roster `"skills"`), class, race, learned, its equipped weapon and the non-weapon items it holds (rings). Learned skills come from level-up tables (class or roster `"learn": {level: skill}`) and scrolls, capped at 5: learning a sixth asks which to forget (or not to learn it; an unread scroll isn't used up). Skills can give stat bonuses, unit menu commands (Dance, Inspire), turn-start healing/MP, an EXP multiplier and immunities; racial traits (Human EXP bonus, Troll regeneration, Fairy MP, poison immunity) are race skills. The status screen's Skills page lists them with their source (skills marked hidden never show), and skill-boosted stats show in gold. Combat skills: battle modifiers with conditions (Wrath, Death Blow, Darting Blow, Steady Stance, the Breakers), strike-order rules (Vantage, Desperation, Quick Riposte, Wary Fighter, Dazzle, Close Counter) and procs that roll each strike and pop up their name (Luna, Sol, Lethality, Pavise, Aegis, Miracle). The forecast and the enemy AI include modifiers and rules but not procs. Also: after-combat effects (Lifetaker, Galeforce, Poison Strike, Savage Blow), turn-start healing (Renewal), movement (Pass, Pathfinder, Canto: move again with the MOV left after acting, not after Wait; then Wait, and X takes the Canto move back), auras (Charisma, Anathema, Fortify), adjacency conditions (Solo Fighter) and growth/EXP skills (Aptitude, Paragon). Class skills (see Classes): terrain movement (Forester, Climbing, Swimming), Steal (take a non-weapon item from an adjacent foe with lower AGI), Lockpick (chests and doors without a key), Canto on mounted classes, range bonuses (Bow Range +1, Spell Range +1), terrain Hit bonuses (Sea Legs, Ambush, Highlander), Prayer (adjacent allies heal 10% each turn), Footwork (Canto after Dancing), Warding (+5 magic defense)
- Hidden gender (`Unit.gender`, "male" or "female"): never shown, but rules can check it (e.g. mounts that only take some riders). Set with `"gender"` in a roster entry; units without one get a random gender. Saved with the unit
- Breakable tiles: **Break** picks a weapon that reaches a breakable tile, then the tile. It always hits for the unit's Attack (STR + Mt), with no counter, crit or EXP, and uses weapon durability. Works at range. Cracked Wall (20 HP) becomes floor, Cracked Fence (10 HP) becomes plain, and a Trunk (15 HP) becomes plain and falls into adjacent river/lake water as a Bridge of up to 3 tiles (away from the attacker if there's water that way, otherwise toward the first side with water). Hovering a breakable tile shows its remaining HP. Tile HP is kept when suspending
- Doors (20 HP): **Open Door** for an adjacent unit that could open a chest (Lockpick: freely, anyone else uses up a Chest Key); otherwise they must be broken

## Classes

Set with `"class"` in a unit's roster entry (required); defined in `data/classes.cfg`. Stats stay per unit. Promotion is data only for now (it will happen in a battle prep screen and keep the unit's level).

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
| Mounted | Equestrian | Sword | mount's | Canto | | Gendarme (Sword, Spear; Canto) |
| | Cavalry | Spear | mount's | Canto | | Gendarme |
| | Raider | Axe | mount's | Canto | | Warlord (Axe, Spear; Canto) |
| | Nomad | Bow | mount's | Canto | | Hussar (Bow, Spear; Canto) |
| | Battlemage | Staff | mount's | Canto | | Spellknight (Staff, Sword; Canto) |
| Ship | Galley | Bow | ship | (Board/Unload, holds 2) | | |
| Special | Performer | Sword | foot | Dance | Footwork | |
| | Bannerman | Spear | foot | Inspire | | |

Mounted classes are what a unit becomes on a mount (see Mounts); they're shared by every species, which sets their movement, tags and name ("Cavalry" on a pegasus is a "Flier", "Gendarme" a "Whitewing").

Spells are separate from classes: any unit with `"spells"` in its roster entry can cast them.

## Races

Set with `"race"` in a unit's roster entry (default Human); defined in `data/races.cfg`. Design and lore notes are in [docs/races.md](docs/races.md). Racial movement comes from body skills (Winged, Aquatic, Equine, Spirit, Wooden Body, Stone Body): the class (or the mount, when riding) and the unit's own skills each propose a movement type, and the highest wins: spirit > ship > horse/drake > flying > heavy > foot/aquatic, a skill winning ties with its class (`Races.MOVE_PRIORITY`). The class's tag stays either way (a Centaur Guard moves as a horse and is a target for both the Pike and the Hammer). Races also change stat caps and growth rates (following the stat tendencies in docs/races.md), and roll a unit's hidden gender from their ratio when the roster doesn't set it (Harpies 70% female; Ents and the Stoneborn have none).

| Race | Tags | Movement | Other | Can't take |
|---|---|---|---|---|
| Human | | | 1.1x EXP | |
| Orc | greenskin | | Poison immune | |
| Troll | | | Regenerates 10% HP per turn; poison immune | |
| Elf | fae | | | |
| Fairy | flying, fae | Winged: flying | Wellspring: recovers 15% of max MP per turn | |
| Naga | aquatic, reptile | Aquatic: mermaid | | Mounted classes |
| Lizal | reptile | foot classes (scouts too) also get Swimming and Climbing | Poison immune | |
| Centaur | horse | Equine: horse; +1 MOV in foot classes | Can Rescue and Shove; can't be Rescued or Shoved | Flying classes |
| Minotaur | horse | | | Mounted classes |
| Harpy | flying | Winged: flying | | Heavy classes |
| Dragon | flying, reptile | Winged: flying | Fire Breath (racial attack: fire, range 1-2, STR + 6 vs DEF, no MP; its own unit menu entry) | |
| Ent | wooden | Wooden Body: heavy | Can't be Rescued or Shoved | All but foot and heavy classes |
| Stoneborn | heavy | Stone Body: heavy | Can't be Rescued or Shoved; poison immune | All but foot and heavy classes |
| Skeleton | undead | | Poison immune | |
| Ghost | undead, spirit | Spirit: spirit | Poison immune | |

| Tag | Weak to (x2) | Resists (1/2) |
|---|---|---|
| aquatic | spears, Lightning | Fire, Water |
| reptile | Ice | Fire |
| wooden | axes, Fire, Ice | Water, Earth |
| undead | silver weapons, Fire, Light | Dark |
| spirit | | weapons that aren't silver |

Only Fire and Earth spells exist so far.

## Terrain and movement types

A unit's class sets its movement type. Costs live in `data/terrain.cfg` (– = impassable). Costs can be fractional, and a unit can be placed by Shove, Drop or Unload only on a tile it could enter in one move (cost ≤ MOV).

A unit's body skills can propose another one, and the highest in the movement priority wins (see Races).

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

Each enemy roster entry in a map (`data/levels/`, `data/chapters/`) can have an `"ai"` dictionary: a preset, a preset plus overrides, or raw settings (all documented in `scripts/ai_profiles.gd`).

```gdscript
"ai": {"preset": "boss"}
"ai": {"preset": "coward", "targeting": "weakest"}
"ai": {"move": "hold", "wake": {"in_threat": true, "attacked": true, "group": "south"}}
```

| Setting | Options |
|---|---|
| `move` | `charge`, `in_range` (only moves to attack), `hold` (never moves), `guard` (stays within `guard_radius`), `goto` (heads for `destination`), `follow` (heads for the unit named `target`, default the player's Lord; moves even on a side with no foes) |
| `attack` | `false` = never starts fights |
| `wake` | `radius`, `in_threat`, `turn`, `attacked`, `group`: switches to `awake_move` for good once any is met |
| `targeting` / `priority` | `damage`, `kill`, `weakest`; plus a list of unit names to prefer |
| `caution` | Weight on expected counter damage (0 = reckless) |
| `retreat_below` / `retreat_until` / `retreat_to` / `retreat_attacks` | Retreat at low HP to a healer, a healing tile, or away from players |
| `breaks` | Default `true`: when moving, opens doors (if it could open a chest) and breaks breakable tiles that block a shorter way to its goal |

Presets: `charger` (default), `ambusher`, `boss`, `turret`, `sentry`, `sleeper`, `reinforcement`, `coward`, `thief`, `pursuer` (follows the Lord, never attacks, breaks nothing: the Royal Guard).

## Layout

- `scenes/level_select.tscn`, `scripts/level_select.gd`: the start screen
- `scenes/main.tscn`: the battle scene
- `data/`: the game's database: classes, races, weapons, items, spells, skills, statuses, mounts, terrain, AI presets, prices and the maps (format: [docs/data.md](docs/data.md)), read by `scripts/game_data.gd`
- `scripts/levels.gd`: levels (terrain layout + both rosters; the maps are in `data/levels/`)
- `events/`, `scripts/event_script.gd`, `battle_events.gd`, `dialogue_box.gd`: map event scripts, their parser, the battle part that runs them, and the dialogue box
- `scripts/battle.gd`: the battle scene root: shared state (`state`, `turn`, ...), unit queries and enemy threat. Its parts are child nodes reached as `battle.input`, `battle.actions`, `battle.phases` and `battle.events` (map events, see below):
  - `battle_input.gd`: player input, menus, targeting and forecasts, the info screens; it owns `battle_trade.gd` (the trade screen) and `battle_formation.gd` (Check Map)
  - `battle_actions.gd`: what units can do and doing it (shove, rescue, ships, break, combat, EXP...), shared by the player and the enemy AI
  - `battle_phases.gd`: player/enemy phases, reinforcements, game over, campaign and suspend flow
- `scripts/combat.gd`, `experience.gd`: formulas
- `scripts/classes.gd`, `races.gd`, `weapons.gd`, `items.gd`, `spells.gd`: data rules (their tables are in `data/`)
- `scripts/enemy_ai.gd`, `ai_profiles.gd`: enemy behavior and its settings/presets
- `scripts/battle_map.gd`, `unit.gd`, `cursor.gd`, `ui.gd`: map, units and HUD
- `scripts/status_screen.gd`, `glossary.gd`: the GBA-style status screen and its detail-mode help text
- `scripts/unit_list.gd`, `options_screen.gd`: the Units and Options screens
- `scripts/save_game.gd`, `settings.gd`: suspend data (units saved generically; see `Unit.SAVE_SKIP`) and options
- `scripts/campaign.gd`, `chapters.gd`, `objectives.gd`, `prep_screen.gd` (+ `scenes/prep.tscn`): the campaign, its chapters, map objectives and the prep screen
