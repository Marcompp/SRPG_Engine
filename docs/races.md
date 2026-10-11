# Races (design notes)

Reference for the race system (`scripts/races.gd`, data in `data/races.cfg`): the lore of each race and how it
plays. Races are about lore and worldbuilding first: a race being stronger than
another is fine. When a racial trait affects tactical play, it should be a skill.

## Status

**Built:** race data, tags, movement overrides, class bans, Rescue/Shove rules, the
three effectiveness levels, spell elements (Fire, Earth), racial skills (Adaptable,
Regeneration, Mana Flow, Poison Immunity, Fire Breath), the Amphibious terrain
skills. Poison is a status effect (`docs/status_effects.md`).

**Planned (decided):**
- Per-race stat cap changes (about -3 to +3), growth changes, and maybe base stats.
- Racial movement as skills, with a priority order between race, class and mount
  (see Movement).
- Fae MP regen renamed and made stronger (see Racial skills).
- Ents limited to plain foot and heavy armor classes, like Stoneborn.
- New race fields: gender ratio, generic name pools (the hook is in
  `data/names.cfg`), graphics.
- A hybrid table, for a future second generation.

**Not yet:** the mounted-class penalty, the other elements, counter-weapons for
Greenskin and Fae, per-race stats.

Defaults picked during implementation (change freely): Equine bonus is +1 MOV;
Troll regen is 10% max HP per turn; Fairy regen is +1 MP per turn; "foot and scout
classes" are the foot, rogue, climb, swim and swim_climb move types; Stoneborn can't
take scout classes; ship classes keep their movement whatever the race.

## The world

- **Three worlds:** the **Surface World**, where humans live; the **Otherworld**,
  home of the fae; and the **Underworld**. **Divinity** is a separate force that
  can touch beings in any of them (Harpies show it most clearly).
- **Humans dominate the Surface World.** Civilizations of other races are very,
  very rare outside truly remote places. Most other races are thought of as
  monsters or beasts that don't build civilizations, whether or not that's true.
  Meeting a "monster" who turns out to be a person is a theme the events can use.
- **Humans are metaphysical blank slates.** They can be molded and changed in ways
  other races can't. That is why humans are the most able to **change race**
  (becoming fae, vampires, werewolves, undead...) and the most likely to have
  **viable hybrid children** with other races.

## Model

### What a race can change

- **Stats:** small changes to caps (about -3 to +3) and growths; maybe base stats.
- **Classes:** a race can ban classes it can't take ("mounted", a move type), or
  allow only some ("only" foot and heavy).
- **Innate traits:** expressed as **skills** whenever they affect tactical play.
- **Tags:** for effectiveness (see below).
- **Flavor:** gender ratio, generic name pools, graphics.

A unit's race is a roster field (`race`, default `Human`), independent of class.
Class is training, not species: race bans come from the body (a tail can't ride,
wings can't wear plate), never from society.

### Subraces and layered races (open)

Many races have subraces (Elves, Trolls, Harpies, Dragons, Fae), and a unit might
need more than one race (an undead Naga). Options considered:

| Option | How | Pros | Cons |
|---|---|---|---|
| Flat entries | Each subrace is its own race, with a `family` field | Simplest | Duplication; no undead Naga |
| Inheritance | A subrace names a `parent` and lists only its differences | No duplication; families for free | Merge rules needed |
| Free layering | A unit has a list of races | Most flexible | Every pair can conflict; hybrids and names get ambiguous |
| Base + templates | One base race (with inheritance) plus templates for what *happens* to a unit (Ghost, Skeleton, Vampire, Werewolf) | Matches the lore (born as / became) | Two concepts |

Not decided: not needed yet.

### Tags and effectiveness

**Both classes and races carry tags.** Weapon/spell effectiveness, weaknesses and
resistances check the union of the two (a class's tags include its move type), plus
the mount's tags.

| Level | Multiplier | Used for |
|---|---|---|
| Effective | x3 | Specific counter-weapons (Pike vs horse, Hammer vs heavy...) and bows vs flying |
| Weak | x2 | Whole weapon types (spears vs aquatic, axes vs wooden) and elements |
| Resistant | x0.5 | Reduced damage (elements, spirits vs non-silver weapons) |

Multipliers don't stack: when several traits apply the same level to the same
source (Naga resists Fire as Aquatic and as Reptile), it counts once. When
different levels apply, the strongest one counts.

Example: a Ghost hit by a Silver Sword is Weak to it (Undead, x2) and the sword is
Effective against it (spirit, x3); only the x3 applies.

Greenskin and Fae are tags for future specific counter-weapons (Effective).

### Movement

**Today:** a race can **override** the class's movement (Naga, Centaur, Ghost...),
**add** to it (Lizal), or **ban** classes it can't take. Ship classes keep their
own movement. A movement override changes how the unit moves, not its tags: a
Centaur Guard moves as a horse but has both the horse and heavy tags, so both the
Pike and the Hammer are effective against it.

**Planned:** racial movement becomes skills (Winged, Aquatic, Equine, Spirit, Wooden
Body, Stone Body). The class, the race skills and the mount each propose a movement
type, and the highest one in this order wins:

> Spirit > Maritime (ship) > Horse / Drake > Flying > Heavy > Foot / Aquatic

Examples: a Winged Dragon on a horse moves as a horse (Horse beats Flying); a Ghost
always moves as a spirit; a Centaur Guard moves as a horse. This is a rule of thumb:
the exact order may need refining case by case.

- **Swimming, Climbing and Forester are modifiers**, not overrides: they change
  terrain costs on top of whatever movement type wins, so they don't follow the
  order. Their exact implementation may be rethought.
- **Winged units keep the flying tag** (and its weaknesses, like bows) even when
  they aren't moving as fliers.

### Carrying and shoving

Mounted units can Rescue but can't Shove; they can't be Shoved or Rescued.

| Who | Can carry | Can shove | Can be carried | Can be shoved |
|---|---|---|---|---|
| Mounted class | yes | no | no | no |
| Equine (Centaur) | yes, in any class | yes | no | no |
| Wooden Body / Stone Body | per class | per class | no | no |

### Gender and names

Generic units roll their hidden gender from the race's ratio. Default 50:50.

| Race | Ratio (female : male) |
|---|---|
| Harpy | 70 : 30 |
| Fae born from nature (Pixies, Sprites...) | Always female |
| Sidhe | 50 : 50 (Sidhe can have children of either gender) |
| Ent, Stoneborn | No gender |
| Skeleton, Ghost | Whatever they were in life |

Generic name pools are per race (`Names.BY_RACE`); every race uses the default
list for now.

## Racial skills

| Skill | Effect | Races | Status |
|---|---|---|---|
| Adaptable | 1.1x EXP | Human | Built |
| Regeneration | Recovers 10% max HP every turn | Troll | Built |
| Mana Flow | +1 MP every turn | Fairy | Built; becomes a weaker learnable skill |
| *(new name)* | Stronger MP regen drawn from nature (e.g. 15% max MP per turn) | Fae | Planned |
| Poison Immunity | Can't be poisoned | Orc, Troll, Lizal, Stoneborn, Skeleton, Ghost | Built |
| Fire Breath | Fire attack at range 1-2, STR-based, no MP | Dragon | Built |
| Swimming + Climbing (Amphibious) | In a foot class, also swims and climbs | Lizal | Built |
| Winged | Moves as flying (see Movement); counts as flying | Fairy, Harpy, Dragon | Planned as a skill (today a race property) |
| Aquatic | Moves as aquatic; counts as aquatic: weak to spears and Lightning, resists Fire and Water | Naga | Planned as a skill |
| Equine | Moves as horse, +1 MOV in foot classes; carries and shoves; can't be carried or shoved | Centaur | Planned as a skill |
| Spirit | Moves as spirit; counts as spirit | Ghost | Planned as a skill |
| Wooden Body | Moves as heavy; weak to axes, Fire and Ice; resists Water and Earth; can't be carried or shoved | Ent | Planned as a skill |
| Stone Body | Moves as heavy; counts as heavy; can't be carried or shoved | Stoneborn | Planned as a skill |

Tag-only traits (no skill): **Greenskin**, **Fae**, **Reptile** (weak to Ice,
resists Fire), **Undead** (weak to silver, Fire and Light; resists Dark),
**Half-Equine** (counts as horse for effectiveness, moves per class).

## Races

Summary of the rules. Each race's lore and details follow.

| Race | Traits | Can't take |
|---|---|---|
| Human | Adaptable | – |
| Orc | Greenskin, Poison Immunity | – |
| Troll | Regeneration, Poison Immunity | – |
| Elf | Fae | – |
| Fairy (Sidhe) | Winged, Fae, MP regen | – |
| Naga | Aquatic, Reptile | Mounted classes |
| Lizal | Amphibious, Reptile, Poison Immunity | – |
| Centaur | Equine | Flying classes, mounts |
| Minotaur | Half-Equine | Mounted classes |
| Harpy | Winged | Heavy classes |
| Dragon | Winged, Reptile, Fire Breath | – |
| Ent | Wooden Body | Mounted classes (planned: anything but plain foot or heavy) |
| Stoneborn | Stone Body, Poison Immunity | Anything but plain foot or heavy |
| Skeleton | Undead, Poison Immunity | – |
| Ghost | Undead, Spirit, Poison Immunity | – |

### Stat tendencies

Rough direction only, no numbers yet. `++` very high, `+` high, `-` low,
`--` very low / negligible, blank = average. These become cap and growth changes.

| Race | HP | MP | STR | INT | DEX | AGI | LCK | DEF | Notes |
|---|---|---|---|---|---|---|---|---|---|
| Human | | | | | | | | | Completely balanced |
| Orc | + | - | + | - | | | | | Physical powerhouse |
| Troll | + | - | + | - | | | | | Physical powerhouse |
| Elf | - | ++ | - | ++ | ++ | ++ | | - | Magic and explosive action, little resilience. STR - is a maybe |
| Fairy | | ++ | | ++ | | ++ | | - | |
| Naga | | | | | | | | | Not decided |
| Lizal | | - | | - | | + | | | Otherwise balanced |
| Centaur | | | | | | | | | Fairly balanced |
| Minotaur | + | | + | | | | | | |
| Harpy | | | | | | + | | - | |
| Dragon | | | | | | | | | Not decided |
| Ent | ++ | | | | | -- | | ++ | Can be magically powerful (MP not decided) |
| Stoneborn | ++ | | | | | -- | | ++ | |
| Skeleton | - | | | | - | | -- | | |
| Ghost | - | | - | | - | | -- | -- | No physical presence: low physical stats, but resists physical attacks |

### Human

Humans dominate most of the world. As individuals, their notable traits are
adaptability and the drive to grow: a human is said to eventually adapt to
anything that doesn't outright kill them. They have long-term stamina (thanks to
sweating) and resist an odd variety of poisons, which they call spices.
Metaphysically they are blank slates (see The world).

- **In game:** Adaptable (more EXP). Completely balanced stats.

### Greenskins: Orc (and Goblin, Ogre)

The greenskin races are Orcs and their cousins the Goblins and the Ogres. They are
hardier than humans, with thicker skin and stronger immune systems suited to rough
places like swamps, which makes them nearly immune to most poisons.

**Orcs** are more physically imposing than humans, though still within human scale
(about 1.9 to 2.2 m tall), stronger but somewhat less intelligent on average (also
within human scale). Where humans live, orcs rarely get to build civilizations of
their own, so they're seen as little more than beasts. They often join goblin
tribes, which are seen as pests.

- **In game:** Greenskin, Poison Immunity (simplified: the lore says *near*-immune).
  HP, STR +; MP, INT -.
- **Goblins** and **Ogres** aren't races in the game yet. Ogres may be too large
  for a one-tile unit.

### Troll

Trolls ruled the surface world before humans. Troll civilizations no longer exist:
most trolls live alone in the wild with no communication or education, so they're
seen as little more than beasts. That is circumstance, not capacity: a troll can
learn. About as tall as orcs and even broader, with large elephant-like tusks. Very
hardy, with absurdly good innate healing. Trolls adapt to where they live, with
slightly different (but compatible) biologies.

- **In game:** Regeneration, Poison Immunity. Not greenskins. Generic trolls are
  rarely in mage classes, but specific characters can be.
- **Subraces:** Swamp Trolls, Mountain Trolls, Frost Trolls.

### Elf

Sometimes called the race closest to the gods. Elves are thought mostly extinct
since the fall of the **Elven Empire**. Long-lived, svelte (usually a little
shorter than humans), built for explosive action rather than endurance. They have
an innate connection with nature and magic, very sharp senses, and are said to be
related to the fae.

Grown elves are very slow to change and adapt poorly, and have little drive to
reproduce. But in times of great upheaval elves reproduce much faster, and the
generation born or raised in the new circumstances becomes a **wholly new
subrace**, all sharing the same adaptations. Elven *populations* adapt even though
elven *individuals* don't.

- **In game:** Fae tag. Very high MP, INT, DEX, AGI; low HP and DEF (maybe STR).
- **Subraces:**

| Subrace | Where | Look | Traits |
|---|---|---|---|
| High Elves | The Elven Empire's upper class | About human height; fair/golden skin; golden or silver eyes and hair | Longest-lived, most magically potent; not very in tune with nature. Effectively extinct |
| Low Elves | The Elven Empire's lower class | Much shorter; dark blue/purple skin, dark hair | Hardier than High Elves; same preference of magic over nature. Effectively extinct |
| Wood Elves | Hidden communes deep in forests | Shorter and lither; tan/earthy skin, light hair, green eyes | Very reclusive, very in tune with nature, hardier |
| Sea Elves | The high sea, far from humans | Gills, webbed fingers; very pale bluish or greenish skin; dark green, ocean blue or teal hair; light, watery eyes | A bit hardier and stronger than most elves |
| Cave Elves | Underground | As short and slight as Wood Elves; earthy skin, brown and dark hair | |
| Festival Elves | Snowy regions of the Otherworld | Very short, pale; red and green furs; ginger, black, brown or green hair; green, blue or brown eyes | Friendly |
| Dark Elves | The Underworld | Ashen, grey or black skin, dark hair | Affinity for darker magic |

### Fae (Fairy race = Sidhe)

Fae are beings very in tune with nature, often born of the Otherworld. Childlike in
demeanor, with a logic of their own that is often alien. Insect-like glowing wings
and antennae. Almost all fae can interface directly with nature, drawing power from
it (the source of their MP regen) and sometimes guiding it.

Most fae are tiny (Pixies and Sprites fit in a hand). Those who gather enough power
can redefine themselves as person-sized fae: the **Sidhe**. Fairy Lords and Ladies
are Sidhe. Fae born directly from nature are always female; the Sidhe, unlike most
fae, can have children, male or female. A human can become a fae in some
circumstances (by default, a Sidhe).

- **In game:** the playable **Fairy** race is the Sidhe. Winged, Fae, MP regen
  (to be renamed and made stronger). Sidhe can ride, like dragons in human form.
- **Subraces (mostly too small to be units):** Pixies (born from nature), Sprites
  (born from magical elements), Redcaps (mushroom fae), Brownies (house fairies),
  and more.

### Naga

Sea-serpent people, the setting's mermaids. Amphibious: they survive both underwater
and on land. Below the waist, a sea-serpent tail instead of legs; fins, gills,
webbed fingers. Above the waist, Zora-like.

- **In game:** Aquatic, Reptile. Can't ride. Stats not decided.
- **Subraces:** **Abyssal Naga** have octopus-like tentacles instead of a tail.

### Lizal

The setting's lizardmen: scaly bodies, lizard heads, tails, claws and teeth. They
live in remote places humans don't: hard-to-cross mountains, swamps, caves.

- **In game:** Amphibious, Reptile, Poison Immunity. Agile; low MP and INT.

### Centaur

Humanoid from the waist up (with some exceptions, like horse ears); below the waist
a mostly horse-like body, with some goat-like traits that suit mountains (not
necessarily reflected in play). Their civilizations are usually nomadic and stay
away from humans.

- **In game:** Equine. Can't fly or take mounts (they reach mounted classes without
  one). Fairly balanced stats.

### Minotaur

Half bull/cow, half human. Bulkier and stronger than humans, furred, with mostly
bovine heads, large horns, cow tails and hooves. Thought less intelligent on
average. They like living underground. Mostly chill, but humans see them as
monsters.

- **In game:** Half-Equine (counts as horse: pikes work on hooves). Can't ride.
  HP, STR +.

### Harpy (the Winged)

Winged humanoids with feathered wings behind their arms and taloned hands and feet.
Tribes tend to be matriarchal; they scavenge and raid, hunting travelers from above.
Their feathers react to the environment, which defines their subraces. Harpies can
have children with several races (humans, orcs...); the child is almost always
indistinguishable from a full harpy.

- **In game:** Winged. Can't wear heavy armor. AGI +, DEF -. 70:30 female to male.
- **Subraces:**

| Subrace | Cause | Wings |
|---|---|---|
| Harpy | Surface World | Brown, green, moss or honey |
| Sylphid | Otherworld | Pastel |
| Fallen / Darkwing | Underworld | Dark grey or black |
| Angel | Contact with divinity | Pure white |
| Valkyrie | Divinity + Otherworld | Golden |
| Fury | Divinity + Underworld | Red / crimson |

### Dragon

Natural shapeshifters who change at will between humanoid and draconic form. In game
they're shown in a halfway state: human form with wings. Long-lived loners who
gather only in the **Dragon Valley** to nest and raise their young until adulthood
at 100. They breathe fire. Steel forged in a dragon's flame (**Dragon-forged
Steel**) is said to be unbreakable.

Dragons are born with more vital energy than their bodies can hold and expel it as
a **Dragonstone**. Tapping it gives a massive power boost that usually kills the
dragon. Young dragons traditionally forge a weapon and set their dragonstone in it,
and carry it all their lives.

- **In game:** Winged, Reptile, Fire Breath. Can ride in human form. Stats not
  decided.
- **Subraces (scale colors):** Red (stronger flames), Blue (more hydrodynamic,
  better swimmers), Green (thicker, more protective), Black (more cold-resistant),
  White (reflects light and some energy attacks), and more.

### Ent

Living wood, or walking trees. They have minds but act mostly on instinct, form no
civilizations, and can't speak. They can be magically powerful.

- **In game:** Wooden Body. Planned: plain foot and heavy classes only (like
  Stoneborn). Very high HP and DEF, very low AGI. No gender.

### Stoneborn

Statues that somehow came to life, bodies of solid stone. Very stubborn, with little
real knowledge of the world and none of the wisdom of growing up: usually set in
whatever role they were sculpted for. They can speak but don't grasp human
timescales and priorities, and barely count as living beings. Very, very rare,
though somewhere in the world is a terracotta-army-like civilization of them.

- **In game:** Stone Body, Poison Immunity. Plain foot and heavy classes only. Very
  high HP and DEF, very low AGI. No gender.

### Undead: Skeleton and Ghost

Other kinds of undead exist; these two are the ones in the game.

**Skeletons** are a kind of zombie: just bones, held together by the source of their
undeath (magic or another unnatural force). Depending on how they were raised, they
can be mindless or keep a soul and a consciousness.

**Ghosts** are undead without a body: souls that linger naturally after death, or
that are bound to the world by outside forces. The soul's power decides how much it
can affect the physical world, which in turn barely affects it. Without the
protective shell of a body, a ghost's soul is more open to corruption and meddling;
a ghost mage can use its own magic to reinforce itself. Magic affects ghosts
normally.

- **In game:** Undead (weak to silver, Fire and Light; resists Dark), Poison
  Immunity. Ghosts are also Spirit: they move as spirits and resist non-silver
  weapons, but have very low physical stats, DEF included. Healing works on them
  for now (may change for the undead).

## Hybrids

For a future second generation. The parents' order doesn't matter; a pair with no
entry can't have children. Races without gender never appear here.

| Parents | Child | Notes |
|---|---|---|
| Human + Orc | Half-Orc | |
| Orc + Goblin | Orcling | |
| Orc + Ogre | Ogrorc | |
| Human + Goblin | Hobgoblin | Smarter, human-sized goblins |
| Goblin + Ogre | Ogreling | Very similar to orcs |
| Human + Ogre | Half-Ogre | |
| Human + Elf | Half-Elf | |
| Human + Fae (Sidhe) | Changeling | At coming of age, chooses to become nigh-indistinguishable from a human or a Sidhe |
| Human + Naga | True Mermaid / Merman | Human above the waist; the tail can split in two to walk more easily |
| Human + Centaur | Horse Boy / Horse Girl | Human with horse ears and tail |
| Human + Minotaur | Cow Girl / Bull Man | Bigger than average human with cow horns, ears and tail |
| Minotaur + Centaur | Sagittaur | A minotaur with horse traits instead of bovine ones |
| Human + Harpy | Harpy | |
| Orc + Harpy | Harpy | Harpies breed with several races; the child is almost always a harpy |
| Human + Dragon | Dragonborn | A more powerful, long-lived human |

## Future (not designed yet)

- **Racial transformations:** necromancers raising units as undead; humans becoming
  vampires, werewolves, fae, demons...
- **Mid-map transformation:** a shapeshifter (dragon, werewolf) turns into a class
  with different, probably stronger stats and no weapons, attacking with claws and
  fangs. Something like a temporary reclass.
- **Dragon features:** the Dragonstone (personal weapon, the fatal power boost),
  full dragon form, Dragon-forged Steel.
- **Hybrid children** for a second generation.
- **Races not in the game yet:** Goblins, Ogres (size?), Hobgoblins, tiny fae,
  Abyssal Naga, other undead, the hybrids above.

## Open questions

- Subraces and layered races: which model (see Model).
- Movement priority puts Heavy above Aquatic, so a Naga in a heavy class would move
  as heavy armor. Today Naga always move as aquatic. Should Naga be banned from
  heavy classes, or is that the intended result?
- Half-Equine fits Minotaurs poorly as a name (they're bovine); the `horse` tag
  still works. Rename it (e.g. Hoofed), or keep it for the Sagittaur?
- Naga and Dragon stat tendencies.
- Name of the stronger Fae MP regen skill, and its exact amount.
