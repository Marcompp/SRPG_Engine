# Mounts (design notes)

Design for the mount system. The first version is built (see "Decided later" and
`scripts/mounts.gd`); capture, raising and breeding are still open.

Mounts are creatures a unit rides into battle. Equipping one in battle prep reclasses
the unit into a mounted class. Mounts have their own stats, levels and skills, and
they are captured and raised over a campaign. The goal: a mounted unit is about as
strong as an unmounted one, never really stronger. A high-level mount can carry a
low-level rider, and a weak mount holds a strong rider back.

## Decided

### Equipping

- Mounts are not items. They live in their own **stable** screen, where they can be
  renamed, assigned to riders and managed.
- Mounts are equipped and unequipped in battle prep only. A mounted unit keeps its
  mount for the whole battle (the Loyal skill is the exception, see Death).
- Equipping a mount reclasses the unit into the mounted equivalent of its class.
  Every class needs a mounted equivalent or a "can't mount" rule (to decide per
  class).
- Races banned from mounted classes (Naga, Minotaur, Ent, Stoneborn...) can't equip
  mounts. **Centaurs can't equip mounts**: they already reach mounted classes
  without the mount stat rules.
- Each mount species can restrict its riders. **Pegasi only accept female riders.**
  This is a per-species data field, not hardcoded, so another game made with the
  engine can change it. It needs the hidden unit gender from the feature list. Since
  unit gender is hidden, prep must say why a unit can't take a pegasus.

### Stats

Effective stat while mounted = rider's stat / 2 + mount's stat.

| | Cap | Mounted contribution |
|---|---|---|
| Rider | 20 (global cap) | 10 at most |
| Horse | 10 | 10 at most |
| Total | | 20, same as an unmounted unit at cap |

- The halved value is always computed from the rider's real stat, never stored
  rounded, so every 2 rider points are exactly 1 mounted point and nothing is lost
  over time.
- **MOV comes entirely from the mount**, it isn't halved.
- Each species can have its own caps in each stat, which gives each one its own
  power curve.

### Showing it to the player

- The rider's level-up screen shows the rider's own gains at full value (+1 STR):
  those are the unit's real stats.
- The mount gets its own level-up popup. Mount gains count in full, so this is
  where a mounted unit's growth shows.
- The status screen shows rider, mount and effective stats.

### Experience

- Rider and mount both gain EXP from battle, at different rates. Each species can
  have its own rate (a rare drake can level slower than a common horse).
- Mounts have a low level cap.
- Battle is the main way to level a mount. Items can level mounts on the bench, as
  a catch-up for newly captured ones.

### Death

- By default, rider and mount die together.
- **Loyal** (mount skill): the mount takes a fatal blow once. The mount dies and the
  rider stays on the map dismounted, at 1 HP. Enemy mounts can have it too, so
  players sometimes meet a dismounted enemy who survived.

### Enemies

- Enemy mounted units get a generated mount. Its level scales with the chapter, so
  late-game enemies ride better mounts, and those are the ones worth capturing.

### Species

| Species | Class set | Move | Tags | Notes |
|---|---|---|---|---|
| Horse | Ground | horse | Horse | Baseline. |
| Pegasus | Air (?) | flying | Flying | Female riders only. |
| Drake | Ground (?) | new `drake` type | Reptile | Flightless. Less MOV than a horse, better through mountains. Reptile: weak to Ice, resists Fire. No Horse tag, so pikes aren't effective; Ice is its counter. |
| Kelpie, Unicorn... | Ground | horse variants | Horse | Possible later variants, without new classes. |

Tags from the mount join the rider's class and race tags like any other tags.
Multipliers still don't stack: a Lizal on a drake is Reptile once.

### Mount gender

Mounts have a visible gender, for flavor only (unlike the hidden unit gender).

### Mount record

Name, species, gender, level, EXP, stats, growths, skills, current rider.

### Decided later (2026-10-09)

- **Shared mounted classes** (model 2 below): one mounted class per role, shared by
  every species; the species supplies move type and tags, plus a display name per
  (class, species) pair.
- **Who mounts:** every foot class, including casters, rogues and the specials; heavy
  armor (Guard, Turret, Juggernaut) can't. Race bans and species rules still apply.
- **Stats:** STR, INT, DEX, AGI, LCK and DEF use rider / 2 + mount. **HP and MP stay
  the rider's own** (no HP/MP on mounts), which also settles dismounting (Loyal):
  the rider keeps its own HP pool. MOV comes from the mount.
- **First version:** species (Horse, Pegasus, Drake with a new `drake` move type),
  mount records (name, species, gender, level, EXP, growths, stats, skills), the
  stable in prep (assign, unassign, rename), the stat formula, mount EXP and
  level-ups, dying together and Loyal, generated enemy mounts, the status screen.
  Capture (Unhorse, fleeing mounts), raising items and breeding come later.

### Proposal: mounted classes (to approve)

A mounted unit remembers its foot class; unmounting returns it there. Rules:

- **Innate skills:** the mounted class's own (Canto) plus its foot class's innate
  skills, except terrain movement (Forester, Swimming, Climbing), since the mount
  moves for it. A mounted Rogue keeps Steal and Lockpick; a mounted Performer
  keeps Dance.
- **Learned (Lv 10) skills** are learned skills, so they stay either way.
- **Promotion:** a mounted unit promotes through its foot class (Rogue to Assassin),
  and the result is mounted again (Assassin to its mounted class). So promoting then
  mounting and mounting then promoting always give the same class.

| Foot class | Mounted class | Weapons | Promoted foot | Promoted mounted | Weapons |
|---|---|---|---|---|---|
| Swordsman | Equestrian | Sword | Swordsmaster | Gendarme | Sword, Spear |
| Rogue | Equestrian | Sword | Assassin | Gendarme | Sword, Spear |
| Corsair | Equestrian | Sword | Swashbuckler | Gendarme | Sword, Spear |
| Performer | Equestrian | Sword | – | – | |
| Footman | Cavalry | Spear | Hoplite | Gendarme | Sword, Spear |
| Bannerman | Cavalry | Spear | – | – | |
| Axeman | Raider *(new)* | Axe | Berserker | Warlord *(new)* | Axe, Spear |
| Brigand | Raider | Axe | Berserker | Warlord | Axe, Spear |
| Archer | Nomad | Bow | Marksman | Hussar | Bow, Spear |
| Poacher | Nomad | Bow | Reaver | Hussar | Bow, Spear |
| Mage | Battlemage *(new)* | Staff | Sorcerer | Spellknight *(new)* | Staff, Sword |
| Cleric | Battlemage | Staff | Bishop | Spellknight | Staff, Sword |

Notes:
- The mounted class's weapons replace the foot class's (a mounted Assassin uses
  sword and spear, not bow). The alternative is to keep the foot class's weapons,
  which makes mounted classes thinner (closer to the overlay model).
- Display names per species, for flavor:

| Mounted class | Horse | Pegasus | Drake |
|---|---|---|---|
| Equestrian | Equestrian | Sky Knight | Drake Knight |
| Cavalry | Cavalry | Flier | Drake Lancer |
| Raider | Raider | Sky Raider | Drake Raider |
| Nomad | Nomad | Sky Archer | Drake Archer |
| Battlemage | Battlemage | Sky Mage | Drake Mage |
| Gendarme | Gendarme | Whitewing | Drake Lord |
| Warlord | Warlord | Storm Rider | Wyrm Warlord |
| Hussar | Hussar | Sky Hussar | Drake Hussar |
| Spellknight | Spellknight | Sky Sage | Drake Sage |

- Today's Flier and Whitewing classes become Cavalry and Gendarme on a pegasus;
  existing roster units that use them get a "mount" in their roster entry instead.

## Open questions

### Mounted classes

Two models:

1. **A class family per mount type.** Horses unlock the horse classes, pegasi the
   flying classes, drakes a new set. This needs many classes, and each new species
   adds more.
2. **Shared mounted classes.** The mount supplies the move type and tags, as races
   already do with movement overrides. A display name per class and mount type pair
   keeps the flavor (Gendarme on a pegasus shows as "Whitewing"). This adds variants
   like kelpies and unicorns without class bloat.

Leaning: shared classes, maybe split into a **ground set** (horse, drake, variants)
and an **air set** (pegasus, later griffon or wyvern). Flying changes play much more
than a horse variant does (terrain stops mattering, bows deal x3), so pegasi may need
their own classes. Not settled.

Also to decide:
- The mounted equivalent of every foot class (Mage, Cleric, Rogue, Corsair,
  Brigand, Guard, Turret...), or which ones can't mount.
- Promotion must give the same result in either order: promote then mount, or mount
  then promote. Classes that share a promotion (Axeman and Brigand → Berserker)
  need care.
- Whether some class and mount pairs are banned (a Guard on a pegasus).

### Stats

- Whether INT and MP are halved. If they are, mounted mages are weak until their
  mount levels up, unless some species (a unicorn?) carries magic stats.
- How HP works if a rider is dismounted mid-battle (Loyal): the rider's own HP pool,
  or a conversion from the mounted HP.

### Mount survives the rider (capture)

Needs more work. Options so far:

- **Unhorse**: a command or skill. If its hit would kill the rider, the rider dies
  and the mount stays riderless on that tile, ready to capture. Predictable, and the
  player controls it.
- **Fleeing mount**: a riderless mount moves toward the map edge each enemy phase
  and is caught by ending a turn next to it. Can be combined with Unhorse.
- Other rider-dies-without-mount cases (and the reverse) beyond Loyal.

### Other

- **Boats as mounts**: leaning no. Ship classes already keep their movement whatever
  the race, and boats don't fit raising, renaming, gender or mount EXP. Could come
  back later as a separate "vehicle" idea tied to Rescue.
- **Raising** between chapters (training in the stable, feed items).
- **Breeding** (possible later): two mounts produce a foal that inherits growths or
  skills. Mount gender would then matter.
- **Mount skills** depend on the skill system from the feature list.

## Dependencies

- Hidden unit gender (pegasus rule).
- Skill system (Loyal, other mount skills).
- The new `drake` move type.
- The "mounted-class penalty" in [races.md](races.md), which Equine ignores, still
  needs a definition. It may or may not be the mount stat rules above.
