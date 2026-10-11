# Classes (design notes)

Reference for the class system (`scripts/classes.gd`): what each class is for and
the rules that shape them. Races are in `docs/races.md`, mounts in
`docs/mounts.md`, skills in `docs/skills.md`.

## Principles

- **A class is readable from its map sprite.** Seeing one should tell the player a
  decent bit about the unit: which weapons it might wield, roughly what its stats
  look like, what threat or utility it brings, and how to counter it.
- **A class is a unit's gameplay identity**: what it can and can't do. That's why
  free reclassing doesn't exist.
- **Classes are gameplay abstractions**, not in-world institutions or professions.
- **Foot vs mounted:** keeping a unit on foot gives better stats and skills;
  mounting gives mobility, and with it utility.

## Reclassing

The only reclassing available by default:

- **Promotion** (in prep, from Lv 15, keeps the level).
- **Mounting** (in prep): every unit has a foot and a mounted configuration. The
  player weighs not only the unit's usefulness in each, but also the skills it
  will learn by being raised in that class.

Planned: a costly, out-of-the-way reclass for players who really want it, like
FE Fates' seals.

### Foot and mounted classes (proposed)

- **Base tier:** each base foot class names its mounted counterpart (several can
  share one: Swordsman, Rogue and Corsair all ride as Equestrian). A roster entry may
  override the pairing for a special character.
- **Promotion picks only the current configuration's branch.** A unit on foot picks
  among its foot class's promotions; a mounted unit picks among its mounted class's.
  One decision at a time.
- **The other branch is picked the first time the unit switches** (mounts or
  dismounts in prep): prep asks for its promoted class then. The choice is
  permanent, like a promotion. A unit that never switches never has to choose.
- So foot and mounted classes each have their own `promotes_to`, and the mounted
  tree is independent of the foot tree (Cavalry can promote into Paladin directly).
- The unit keeps both classes (foot and mounted, the second possibly not chosen yet);
  both are saved.

Open:
- **Promotion bonus:** stats are the rider's own, so the bonus is applied once, by
  the class picked at promotion. The branch picked later gives no second bonus.
  Fine if promotion bonuses stay similar across classes.
- **Losing the mount mid-battle (Loyal)** when the foot branch isn't chosen yet:
  ask right there, or use a default for the rest of the battle and ask in prep?
- Is the later pick free (any promotion of the other base class), or limited by the
  first pick?

### Split promotions (under consideration)

A base class may promote into one of two classes. Only where a second identity
exists, not for symmetry. Ideas so far are in the promotion tree below.

## Skills

- **Innate skills are the class's identity.** Base classes get few, low-impact ones;
  strong skills belong to promoted classes (or personal skills and scrolls).
- **Learned skills (Lv 10) are small rewards** for sticking with a class. A promoted
  class's innate skills are never upgrades of a base class's learned skill.
- **Enemy consistency:** class skills end up on enemies, so they must not change
  damage or attack speed depending on who initiates, and no damage procs. Numbers a
  player checks on their turn must still hold on the enemy phase. (Lethality on the
  Assassin is an accepted exception.)
- Terrain movement (Forester, Swimming, Climbing) is innate, and promoted classes
  keep it.
- Skill names are placeholders.

Proposed:
- **Mastery skill:** promoted classes teach a skill at Lv 20. Since promotion keeps
  the level, promoting late delays it. (Learned skills cap at 5,
  `Skills.LEARNED_CAP`.)
- **Which class teaches:** the one the unit is in when it reaches the level, mounted
  or not. So mounted classes need their own Lv 10 skills (they have none yet).

## Stats

- Every class uses the default caps for now, but a class can set its own (`caps`,
  partial). Promoted classes may get different caps later.
- Promotion bonuses are per class (`PROMOTION_BONUS`).
- Class growths: not decided.

## Foot classes

Your run-of-the-mill, reliable units: mostly good combat stats.

### Swordsman → Swordsmaster

- **Swordsman:** the fast duelist. Hits often, dodges, low power. Lv 10 Speed +2.
- **Swordsmaster:** high risk, high reward. Very high crit and AGI, weak defenses
  (it survives by dodging) and unremarkable attack (it kills with crits and personal
  procs), but very good at both. The hype-moment, aura class. Innate Crit +20.
- Open: a slower, sturdier sword class (FE's Mercenary to the Swordsman's
  Myrmidon). **Fencer** is one idea; the name fits best if its sturdiness comes from
  parrying and countering.

### Footman → Hoplite

- **Footman:** FE's Soldier. The all-rounder, and the most common enemy. Lv 10 Open
  Ground (+Avo on open terrain).
- **Hoplite:** almost a reward for sticking with the most boring class. Good,
  balanced stats, especially DEF and DEX. Impale punishes mounted units.

### Axeman → Berserker

- **Axeman:** raw power, less accuracy. Closer to FE5's Axe Fighters than to GBA FE's
  Fighters. Lv 10 Strength +2.
- **Berserker** (shared with Brigand): see Brigand.

### Archer → Marksman

- **Archer:** ranged chip damage and anti-air. Among the strongest player-phase units,
  to make up for rarely countering on the enemy phase: good stats all round,
  especially DEX, decent AGI and STR. Lv 10 Skill +4. Planned: Forester, and **Keen
  Eye** (more sight in fog of war, once fog exists).
- **Marksman:** the best player-phase unit. Bow Range +1 lets it avoid almost all
  counterattacks while supporting defensive formations and terrain. Very good stats.

## Scouts

Alternatives to the plain foot units, with different stat focuses and a terrain
they cross well. They open up map design, and appear more on the enemy side.

### Corsair → Swashbuckler

- **Corsair:** FE's Pirate, with swords so it doesn't overlap the Brigand. Swimming;
  Lv 10 Sea Legs (+Hit on water).
- **Swashbuckler:** a movement specialist among foot units. Adds axes; Swimming,
  Pass. Could also be a Fencer promotion if Fencer exists.

### Brigand → Berserker

- **Brigand:** FE's Brigand. Low hit but high HP: good early-game enemies. Climbing;
  Lv 10 Highlander (+Hit on hills and mountains).
- **Berserker:** high risk, high reward. As a player unit, ideally like FE6's
  Berserkers: either they miss, or they one-shot. Swimming, Climbing, Wrath.

### Poacher → Reaver

- **Poacher:** a woodland bow user (originally imagined as a bow-using rogue).
  Forester; Lv 10 Ambush (+Hit in forests). Overlaps the Archer; kept separate for
  now, to revisit.
- **Reaver:** imagined as FE's Warrior: a big class with heavy base damage, hence
  bows and axes. Forester, Brawn. Might fit better as an Axeman promotion.

## Rogues

Not scouts so much as specialized utility units: a specific role rather than
combat.

### Rogue → Assassin

- **Rogue:** Steal and Lockpick are unique utility and should feel very impactful.
  In level design, enemy thieves are anti-turtling incentives: they grab treasure and
  flee, so the player has to pick up the pace. Forester; Lv 10 Evasion.
- **Assassin:** makes Rogues more combat-viable, though far from reliable. Their main
  value is still the Rogue skills; Lethality is something of a gimmick. Adds bows.
  Idea: **Killing Machine** (doubles crit) for a low-damage, high-crit identity
  (keep it distinct from the Swordsmaster's crit-and-dodge).

## Armor

The clearest roles of all: very tanky enemies with clear weaknesses, and reliable
tanks that can take a hit on the player side.

- **Guard:** enemy-phase focused, placed in the path of melee units. Lv 10
  Defense +2.
- **Turret:** player-phase focused, very safe chip damage, with built-in counterplay:
  it can be surrounded when alone. Lv 10 Max HP +5.
- **Juggernaut** (shared): more of the same, able to fill both roles. Spears, axes,
  bows; Warding (+magic defense).

## Casters

Staves are some of the worst weapons, leaving casters fairly helpless on the enemy
phase, but they bring a ton of utility from spells. **Spells belong to the unit,
not the class.** Mage and Cleric differ in flavor, skills and maybe stat
distribution, not in what they can cast.

- **Mage:** the aggressive one, INT-focused. Lv 10 Magic +2.
- **Cleric:** the defensive, utility one, max-MP-focused. Lv 10 Max MP +5.
- **Sorcerer** (adds swords; Spell Range +1) and **Bishop** (adds spears; Prayer):
  more of the same.

## Special classes

They don't promote (for now) and are defined by one special function; their
learned skills enhance it.

- **Performer:** Dance refreshes an ally so it can move again. Lv 10 Footwork.
  - **Duet:** Dancing an ally that can also Dance (and has acted) doesn't refresh
    it. Instead, every ally next to either dancer is refreshed. Dancers caught in
    that area join the troupe and extend it, so the effect chains. The troupe
    itself is never refreshed. That is the one rule that stops two dancers from
    refreshing each other forever: each Duet costs one dancer's action and gives
    no dancer an action back. There is no other limit. Setting up a Duet takes
    careful positioning and at least two deployment slots, and that is the cost.
- **Bannerman:** Inspire buffs adjacent allies.

Open: whether they can mount.

## Mounted classes

Mounted utility by default, but not the stats or utility of foot units. Shared by
every species: the species sets movement, tags and the displayed name ("Cavalry"
on a pegasus is a "Flier"). All get Canto for now.

| Base | Weapons | Rides for |
|---|---|---|
| Equestrian | Sword | Swordsman, Rogue, Corsair |
| Cavalry | Spear | Footman |
| Outrider *(renamed from Raider)* | Axe | Axeman, Brigand |
| Nomad | Bow | Archer, Poacher |
| Pilgrim or Wayfarer *(renamed from Battlemage)* | Staff | Mage, Cleric |

| Promoted | Weapons | Notes |
|---|---|---|
| Gendarme | Sword, Spear | The plain, quintessential mounted class |
| Hussar | Bow, Spear | |
| Cataphract *(replaces Warlord)* | Axe, Spear? | Heavy and mounted: a niche apart from the Gendarme. Moves as a horse but counts as heavy too (Pike and Hammer both effective) |
| Raider *(idea)* | Bow, Axe | Mounted equivalent of Berserkers and Reavers |
| Paladin *(idea)* | Spear, Staff | Promotes from Cavalry and Pilgrim |
| Spellknight | Staff, Sword | Mounted Sorcerer |

Pegasus and Drake share these classes under their own names, but should eventually
get different learned skills. Open: per-species Lv 10 skills on the class (on the
rider), or species skills learned by the mount itself.

## Promotion tree (draft)

Status: **current** = in the game; **idea** = proposed, not decided.

| Base | Promotes to | Status |
|---|---|---|
| Swordsman | Swordsmaster | current |
| | Swashbuckler (Sword, Axe), shared with Corsair | idea |
| Footman | Hoplite | current |
| | Gladiator (Axe, Spear), shared with Brigand | idea |
| Axeman | Berserker | current |
| | Reaver | idea (instead of Poacher's) |
| Archer | Marksman | current |
| | shared promotion with Turret | idea |
| Corsair | Swashbuckler | current |
| Brigand | Berserker | current |
| | Gladiator | idea |
| Poacher | Reaver | current |
| | Assassin | idea |
| Rogue | Assassin | current |
| | Trickster: all-in utility, bows, mastery skill removing most terrain costs | idea |
| Guard | Juggernaut | current |
| Turret | Juggernaut | current |
| | shared promotion with Archer | idea |
| Mage | Sorcerer | current |
| | Wizard, shared with Cleric | idea |
| Cleric | Bishop | current |
| | Wizard | idea |
| Performer, Bannerman | – | no promotion |


This is the foot tree. The mounted base classes get their own promotion lists (see
Foot and mounted classes); still to draft.

| Base | Promotes to | Status |
|---|---|---|
| Equestrian | Gendarme | current |
| | Spellknight, shared with pilgrim | idea |
| | Sagittari, swords and bows, shared with Nomad | idea |
| Cavalry | Gendarme | current |
| | Paladin, shared with Pilgrim | idea |
| | Hussar, shared with Nomad | idea |
| Outrider | Cataphract | current |
| | Raider, shared with nomad | idea |
| | Warlord; shared with Pilgrim | idea |
| Nomad | Hussar | current
| | Raider, shared with outrider | idea
| | Sagittari, swords and bows, shared with Equestrian | idea |
| Pilgrim | Spellknight | current |
| | Paladin | idea |
| | Warlord; armored, axes and staves | idea |

## Planned and missing

- **Beast:** a class with no weapons, using racial attacks and spells only, for
  monster units. Also a base for mid-map transformations (see races.md). Open: races
  without a racial attack (Troll, Minotaur) need a natural attack (claws, gore) to
  fight in it.
- **A mounted armored class:** Cataphract. Open: can Guard and Turret mount (today
  armor can't)?
- **Trainee (tier 0) classes:** maybe.
- **The full promotion tree**, if split promotions happen.

## Retired

- **Wraith:** spirit movement now comes from the Ghost race. Still used 5 times in
  `scripts/levels.gd`; those become Ghost units in a regular class.

## Open questions

- Split promotions: yes or no, and which.
- Fencer: whether it exists, and its role.
- Poacher vs Archer overlap (revisit later).
- Can special classes mount? Can armor mount?
- Class growths, and per-class caps for promoted classes.
- The Lv 20 mastery skill and the "class you're in teaches" rule (proposed).
- Pegasus and Drake learned skills: on the class or on the mount.
- Names: Pilgrim or Wayfarer; the Archer/Turret and Mage/Cleric shared promotions.
