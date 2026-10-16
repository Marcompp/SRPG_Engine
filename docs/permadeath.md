# Permadeath (design notes)

Design notes. Nothing here is built yet beyond the basics under "What exists".
The goal: a death should **change the story** instead of just shrinking the
army. Losing a unit should leave traces the player keeps running into: an empty
seat, a grudge, a familiar face in an enemy necromancer's ranks. That makes
playing on after a loss feel like a choice, not a reason to reset. FE4/5 are the
model.

## What exists

- A player unit that falls in a campaign chapter leaves the army for good
  (`Campaign.finish_chapter`). `Battle.campaign_deaths` records
  `{"name", "turn", "how"}` during the map; on victory the unit's full record
  (`SaveGame.unit_to_dict`: stats, class, race, items, mount, biography) moves to
  `Campaign.fallen` as `{"unit", "chapter", "turn"}`.
- The biography gets a last line from `Campaign.DEATH_TEXTS` ("Fell in {map},
  turn {turn}." / "Succumbed to poison...").
- The `death` event trigger runs death quotes (`docs/events.md`).
- Losing a chapter retries it from the save made before it, so only deaths in a
  won chapter are permanent.
- Skeletons and Ghosts exist as races (`docs/races.md`, Undead), with lore that
  fits raising the dead: skeletons may or may not keep a soul, and ghosts are
  souls that linger or are bound.

## Pieces

From cheapest to most involved. Each one stands alone.

### 1. A richer fallen record

Store more about each death so later pieces (and events) have something to use:

| Field | Meaning |
|---|---|
| `how` | Already recorded in battle; copy it into the fallen entry too |
| `killer` | `{"name", "class", "team"}` of the unit that struck the blow, or empty (poison, terrain) |
| `cell` | Where the unit fell (for a grave or a ghost that lingers on the map) |
| `raised` | Set once a necromancer has used the body (see 3), so it can't be raised twice |

Enemy deaths stay unrecorded except for named units, which only events need.

### 2. Memorial

A **Fallen** page in the prep screen: each fallen unit's portrait (or class icon),
class and level, where it fell and who killed it, plus its biography. It's read
only. It costs little and keeps the dead in view between chapters.

Biography moments that come with it:
- Killing the unit that killed an ally: "Avenged {ally} at {map}." on the
  avenger, and "Was slain by {avenger}, avenging {ally}." if the killer is
  named and its death is recorded.
- A unit that survives a map where an ally fell next to it (adjacent at the
  moment of death): "Saw {ally} fall at {map}." This seeds the biography-effects
  idea in `features_to_add.txt`.

### 3. Necromancy

The main mechanic. **Raising** turns a dead unit into an Undead (Skeleton, or
Ghost for a soul that lingers) on the raiser's side.

- **During a map:** a unit that dies leaves a **grave** marker on its cell (a map
  object like a door or a breakable wall, not a unit). A necromancer uses
  **Raise** on a grave in range. The raised unit appears there with the dead
  unit's class, level, items and weapon ranks, its race swapped to Skeleton, at
  half HP. It belongs to the raiser's faction for the rest of the map. Raising
  your own fallen means the dead fight on until the map ends. Raising theirs
  means fighting your friend with their own face and weapons.
- **Between chapters (events):** a new event command `@raise <name> [race]
  [team]` spawns a unit from `Campaign.fallen` with its saved record. That lets a
  later chapter bring back a unit that fell three maps earlier as an enemy boss's
  Skeleton. Writers don't have to predict who died: the command can pick from
  the fallen ("the highest level", "the most recent", "anyone from chapter 3").
- **Keeping a raised ally:** a raised player unit that survives the map can stay
  in the army as an Undead version of itself. It keeps its name and biography and
  gets the line "Raised by {necromancer} at {map}.". The default is that it stays,
  because the lore supports it (a skeleton that keeps its soul). A campaign can
  turn this off.
- **Who can raise:** a `raise` skill key (`{"race": "Skeleton"}`) on a class,
  race or item. That way a Necromancer class, a cursed staff and a lich boss all
  use the same rule. This adds the first dark-magic user. Which class gets it, and
  where it sits in the class tree, is decided in `docs/classes.md`, not here.
- **Cost:** Raise is a command that ends the necromancer's action and uses up the
  grave. There is no per-map cap: raising takes an action, a body has to be in
  range, and the raised unit is weaker than it was. That's balance enough.

### 4. Lingering ghosts

The lore says some souls linger without help. A unit with strong ties to a place
(an event flag, or a biography moment like "Defended {map}") can come back as a
Ghost on a later visit to that map, or in an epilogue. It's event-driven only,
never random, so the writer decides when it fits.

### 5. Campaign rules

Permadeath stays the default. Other rules are per campaign, waiting on
"Selectively enable features for campaign":

| Rule | A fallen unit... |
|---|---|
| Permadeath | Leaves the army (now) |
| Wounded | Survives but sits out the next chapter, with "Badly wounded at {map}." |
| Retreat | Leaves the map and comes back next chapter (casual) |

Lords dying is still a defeat in every mode.

## Open questions

- **Race templates.** Raising a Naga as a Skeleton is the "undead Naga" case from
  `docs/races.md` (Subraces and layered races). Swapping the race loses what it
  was in life (tail, wings, size). Necromancy is the feature that forces the
  decision; "Base + templates" fits best, since Undead is something that
  *happens to* a unit. Until it's decided, raising swaps the race outright.
- **Class limits after raising.** A raised unit's class may be banned for its
  new race (a mounted Skeleton without its horse, an Ent's class). Options:
  dismount and keep the foot class (like a lost mount), or allow the class
  anyway because it was the unit's class in life.
- **Healing the undead.** `docs/races.md` says healing works on Undead "for now".
  If raised allies become common, Light healing hurting them (or not working)
  matters more.
- **Grief and bonds.** There's no support or relationship system yet, so
  reactions to a specific ally dying (a stat boost for the avenger, a unit
  leaving the army in grief) only work through events and flags for now. A bond
  system would be its own feature.
- **Grave markers vs. carried bodies.** Should a rescued or carried unit that
  dies leave its grave where it was set down (current passenger logic) or where
  its carrier stood?

## Build order

1. Richer fallen record (`killer`, `cell`, `how`) and the Avenged / Saw fall
   biography moments.
2. Memorial page in the prep screen.
3. `@raise` event command (between chapters), from `Campaign.fallen`.
4. Graves, the `raise` skill key and the Raise command (during a map). AI support
   for enemy necromancers.
5. Raised allies staying in the army.
6. Campaign rules (Wounded, Retreat), once per-campaign toggles exist.
