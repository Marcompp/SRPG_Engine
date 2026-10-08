# Races (design notes)

Reference for the race system (`scripts/races.gd`). Races are about lore and
worldbuilding first: a race being stronger than another is fine.

Implemented: race data, tags, movement overrides, class bans, Rescue/Shove rules,
the three effectiveness levels, spell elements (Fire, Earth), Troll HP regen, Fairy
MP regen, Human EXP. Not yet: poison, the mounted-class penalty, the other elements,
counter-weapons for Greenskin and Fae, per-race stats.

Defaults picked during implementation (change freely): Equine bonus is +1 MOV;
Troll regen is 10% max HP per turn; Fairy regen is +1 MP per turn; "foot and scout
classes" are the foot, rogue, climb, swim and swim_climb move types; Stoneborn can't
take scout classes; ship classes keep their movement whatever the race.

## Model

- A unit's race is a roster field (`race`, default `Human`), independent of class.
- Both **classes and races carry tags**. Weapon/spell effectiveness, weaknesses and
  resistances check the union of the two (a class's tags include its move type).
- A race can **override** the class's movement (Naga, Centaur, Ghost...), **add** to
  it (Lizal), or **ban** classes it can't take.
- A movement override changes how the unit moves, not its tags: the class's tags
  stay. A Centaur Guard moves as a horse but has both the horse and heavy tags, so
  both the Pike and the Hammer are effective against it.
- A race can also change carrying and shoving rules (Rescue / Shove), see below.

## Effectiveness levels

| Level | Multiplier | Used for |
|---|---|---|
| Effective | x3 | Specific counter-weapons (Pike vs horse, Hammer vs heavy...) and bows vs flying |
| Weak | x2 | Whole weapon types (spears vs aquatic, axes vs wooden) and elements |
| Resistant | x0.5 | Reduced damage (elements, spirits vs non-silver weapons) |

Multipliers don't stack: when several traits apply the same level to the same
source (Naga resists Fire as Aquatic and as Reptile), it counts once. When
different levels apply, the strongest one counts.

Greenskin and Fae are tags for future specific counter-weapons (Effective).

Example: a Ghost hit by a Silver Sword is Weak to it (Undead, x2) and the sword is
Effective against it (spirit, x3); only the x3 applies.

## Carrying and shoving

Today: mounted units can Rescue but can't Shove; they can't be Shoved or Rescued.

| Who | Can carry | Can shove | Can be carried | Can be shoved |
|---|---|---|---|---|
| Mounted class | yes | no | no | no |
| Equine (Centaur) | yes, in any class | yes | no | no |
| Wooden Body / Stone Body | per class | per class | no | no |

## Traits

| Trait | Effect |
|---|---|
| Greenskin | Tag only (for effectiveness). |
| Fae | Tag only (for effectiveness). |
| Aquatic | Always moves as aquatic (mermaid) and counts as aquatic, whatever the class. Weak to spears and Lightning; resists Fire and Water. |
| Reptile | Tag. Weak to Ice; resists Fire. |
| Equine | Always moves as horse and counts as horse. Ignores the mounted-class penalty (not implemented yet). Bonus MOV in foot and scout classes. Can carry and shove other units; can't be carried or shoved. |
| Half-Equine | Counts as horse for effectiveness only (moves per class). |
| Wooden Body | Always moves as heavy. Weak to axes, Fire and Ice; resists Water and Earth. Can't be shoved or carried. |
| Stone Body | Always moves as heavy and counts as heavy. Can't be shoved or carried. |
| Amphibious | In a foot class, gains swim + climb movement (on top of scout movement if the class has it). |
| Winged | Always moves as flying (unless in a mounted class) and counts as flying. |
| Undead | Weak to silver weapons (x2), Fire and Light; resists Dark. |
| Spiritual | Always moves as spirit and counts as spirit. |
| Regen HP | Recovers a little HP every turn. |
| Regen MP | Recovers extra MP every turn. |
| Poison immune | Immune to poison (poison not implemented yet). |
| Fast learner | 1.1x EXP. |

## Races

| Race | Traits | Can't take |
|---|---|---|
| Human | Fast learner | – |
| Orc | Greenskin, Poison immune | – |
| Troll | Regen HP, Poison immune | – |
| Elf | Fae | – |
| Fairy | Winged, Fae, Regen MP | – |
| Naga | Aquatic, Reptile | Mounted classes |
| Lizal | Amphibious, Reptile, Poison immune | – |
| Centaur | Equine | Flying classes |
| Minotaur | Half-Equine | Mounted classes |
| Harpy | Winged | Heavy classes |
| Ent | Wooden Body | Mounted classes |
| Stoneborn | Stone Body, Poison immune | Anything but foot or heavy classes |
| Skeleton | Undead, Poison immune | – |
| Ghost | Undead, Spiritual, Poison immune | – |

## Stat tendencies

Rough direction only, no numbers yet. `++` very high, `+` high, `-` low,
`--` very low / negligible, blank = average.

| Race | HP | MP | STR | INT | DEX | AGI | LCK | DEF | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Human | | | | | | | | | Completely balanced |
| Orc | + | - | + | - | | | | | Lopsided, physical powerhouse |
| Troll | + | - | + | - | | | | | Lopsided, physical powerhouse |
| Elf | | ++ | | ++ | ++ | ++ | | | |
| Fairy | | ++ | | ++ | | ++ | | - | |
| Naga | | | | | | | | | Not decided |
| Lizal | | - | | - | | + | | | Otherwise balanced |
| Centaur | | | | | | | | | Fairly balanced |
| Minotaur | + | | + | | | | | | |
| Harpy | | | | | | + | | - | |
| Ent | ++ | | | | | -- | | ++ | |
| Stoneborn | ++ | | | | | -- | | ++ | |
| Skeleton | - | | | | - | | -- | | |
| Ghost | - | | | | - | | -- | -- | |

## Class cleanup

The `Naga`, `Naga Elite`, `Harpy` and `Harpy Elite` classes are gone: levels use a
Naga Footman and a Harpy Archer instead.

## Still to build

- Needs new systems: elements on spells (Fire, Ice, Water, Earth, Lightning, Light,
  Dark), poison, HP regen, the mounted-class penalty, composable hybrid movement.
