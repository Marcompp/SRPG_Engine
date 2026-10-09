# Events: dialogue and cutscenes (design notes)

Design notes. The first version is built: see Decided, the format reference in
`scripts/event_script.gd` and the sample `events/great_valley.txt`. Event files are
plain text, so an exported game needs `*.txt` in the export filter.

A map's **events** are scripts that run when something happens: the map starts, a
turn begins, two units talk, a boss is attacked, a unit dies, a unit reaches a
place, the map is won. A script is a list of lines of dialogue plus a few
commands (move a unit, spawn one, recruit one...). The battle waits while a
script runs.

## Triggers

Each event has a trigger, optional conditions, and runs once unless it says
otherwise.

| Trigger | When | Typical use |
|---|---|---|
| `start` | Before the first player phase | Opening scene |
| `turn` (N, phase) | Start of turn N's player or enemy phase | Reinforcement taunts, story beats |
| `talk` (A, B) | A has a **Talk** command next to B | Conversations, recruiting an enemy |
| `battle` (unit, optionally with whom) | Before a fight involving the unit | Boss quotes, special matchups |
| `death` (unit) | The unit falls | Death quotes |
| `area` (cells, optionally who) | A unit ends its move there | Ambush triggers, "the gate is open" |
| `visit` (cell) | A village is visited | Village text (the item reward is separate) |
| `victory` | The map is won, before the end screen | Closing scene |

Conditions: a flag is set or not set (`if: {"flag": "spared_thief"}`), a unit
is alive, a minimum turn.

## Commands

| Command | Does |
|---|---|
| say | A line of dialogue with the speaker's portrait and name |
| narrate | Text with no speaker |
| move | Walks a unit along a path to a cell (the camera follows) |
| spawn / remove | A unit appears (roster entry) or leaves |
| recruit | A unit switches to the player's side (and joins the campaign army) |
| give | Puts an item in a unit's inventory |
| camera | Pans to a cell |
| wait | Pause |
| flag | Sets a flag (kept for the map; campaign flags later) |
| banner | Shows a banner like "Reinforcements!" |

## Presentation

GBA style: a dialogue box at the bottom of the screen, two portrait slots
(speakers alternate sides, a speaker who already has a slot keeps it), the name
on a plate, and text typed out letter by letter.
- **Z:** finishes the line, then advances.
- **Hold X:** fast-forwards.
- **A skip key:** skips the whole scene; commands still run, so the map ends up
  the same.

There's no portrait art yet, so a placeholder is drawn the way the stats screen
does it (team color and the unit's initial). Units will be able to name a
portrait image later, like maps will name a tileset.

## Writing scripts

Two options; see the open questions.

**A. A small text format** (one line per beat, commands start with `@`):

```
Lord: The bridge is ours if we hold it till dusk.
Rider: Riders, my lord. East bank, a dozen at least.
@move Bandit 10,4
Bandit: Hand over the village, and nobody drowns.
@narrate The river runs high this time of year.
```

**B. Data lists**, like the rest of the level data:

```gdscript
[["say", "Lord", "The bridge is ours if we hold it till dusk."],
 ["move", "Bandit", Vector2i(10, 4)],
 ["say", "Bandit", "Hand over the village, and nobody drowns."]]
```

The text format reads like a screenplay and is much faster to write in bulk; the
data lists need no parser. Option A can live inline in the level data (a
multi-line string per event) or in one text file per chapter.

## Decided

- **Format:** the text format, one file per map: `events/<map id>.txt` (e.g.
  `events/ch1.txt`). Data lists are the fallback for anything the text can't
  express: a level's `"events"` entry can hold scripts as lists of commands.
- **First version:** `start`, `turn`, `talk` (with recruiting), `battle` and `death`.
  `area`, `visit` and `victory` come next.
- **Speakers:** a unit's name when one matches, otherwise a free label ("Messenger")
  with a generic portrait.
