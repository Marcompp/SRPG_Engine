# Status effects (design notes)

Design notes. Step 1 of the build order is built (`scripts/statuses.gd`): the core,
Poison, Antitoxin, Panacea, Restore and the `@status` / `@cure` event commands.
A **status** is a temporary condition on a unit
(Poison, Silence, Sleep...) that changes what it can do or how it fights, until it
runs out or is cured.

## How it works

- **A status is a temporary skill source.** `Skills.of(u)` already merges personal,
  class, race, learned, weapon and item skills; active statuses become one more
  source. So a status can use any skill key (`stats`, `battle`, `rules`, `map`...)
  and combat, the forecast and the AI see it with no extra code. Statuses are
  defined in `scripts/statuses.gd`, a table like the skills one.
- **On the unit:** `statuses: {name: turns_left}` (-1: until cured). Saved by
  SaveGame, so suspend, auto save and rewind keep them.
- **Several at once.** Different statuses coexist; the same one again refreshes its
  duration rather than stacking.
- **Ticks** at the start of the afflicted unit's side's phase: damage first, then
  turns left go down; at 0 the status ends (popup "Poison wore off").
- **Immunity:** the existing skill key `immune: [status]` (Poison Immunity on Orcs,
  Trolls, Lizals, Stoneborn, Skeletons, Ghosts) blocks it from being inflicted;
  the attempt pops up "Immune".
- **Between chapters** statuses are cleared, except ones marked `lingers` (Petrify),
  which carry into the next chapter until cured.

### Status-only keys

| Key | Meaning |
|---|---|
| `duration` | Default turns (-1: until cured) |
| `restrict` | Any of `move`, `act` (no commands, no counterattacks), `magic` (spells and racial attacks), `items` |
| `tick` | Start of phase effect, e.g. `{"damage": [4, 6]}` |
| `cure_on_hit` | Ends when the unit takes damage (Sleep) |
| `no_avoid` | Its Avoid is 0 |
| `control` | `"berserk"`: the AI moves it, attacking the nearest unit of any side |
| `lingers` | Survives the end of the chapter |

## The first set

| Status | Effect | Duration |
|---|---|---|
| Poison | Start of its phase: 4-6 damage. Never kills: a hit that would leaves it at 1 HP, but a unit already at 1 HP dies | 3 turns |
| Silence | Can't use spells or racial attacks | 3 turns |
| Sleep | Can't move, act or counter; ends when it takes damage | 2 turns |
| Paralyse | Can't move (can still act where it stands) | 1 turn |
| Berserk | The AI controls it at the start of its side's phase: attacks the nearest unit of any side | 3 turns |
| Petrify | Can't move, act or counter; +10 DEF (magic defense unchanged), Avoid 0. Lingers | Until cured |

Carried units (rescued, aboard a ship) don't tick: they're off the map.

A unit killed by Poison has "Succumbed to poison" added to its biography; nobody gets
EXP for it, and it counts as a death for defeat conditions and events.

## Sources and cures

- **Inflicting:** weapons, spells and racial attacks get
  `"inflict": {"status", "chance"}` (rolled on each hit that lands; the forecast
  notes it). A new `after_combat` skill effect, `inflict`. An event command,
  `status <unit> <status> [turns]`. Later: terrain (a poison swamp).
- **Status spells** (Silence, Sleep, Berserk, Petrify) are enemy-target spells with
  no damage that use the normal spell hit chance and inflict on a hit.
- **Cures:** the turn count running out; a Restore spell (ally target, cures every
  status, heals nothing; the enemy AI doesn't cast it yet); items: Antitoxin
  (Poison), Panacea (everything).

## UI

- Popup when inflicted, cured or worn off.
- A small marker on the unit's map tile (a letter per status until there's art).
- Info panel: the status names with turns left.
- Status screen, Stats page: one square per status (its color and initial, placeholders
  for icons); highlighting one shows its description and turns left. Statuses work
  like skills internally but are never listed on the Skills page.
- Forecast: "Poison 30%" style note when the attack can inflict.

## AI

- First version: restricted units skip what they can't do; a Silenced caster
  fights with weapons; Berserk reuses the normal targeting with every unit as a foe.
- Later: valuing statuses (silence the healer, finish off a sleeping unit).

## Build order

1. **Core:** `statuses.gd`, the unit field, the skill source, ticking and expiry,
   save/restore, the chapter clear with `lingers`, immunity, the event command, the
   basic UI. Content: Poison, Antitoxin, Restore.
2. **Restrictions:** Silence, Sleep, Paralyse and Petrify (`restrict`,
   `cure_on_hit`, `no_avoid`, no counters), AI skipping restricted actions.
3. **Sources:** `inflict` on weapons, spells and abilities, the forecast note, the
   `inflict` after_combat effect; content: a venom weapon, the status spells.
4. **Berserk:** the AI taking over a player unit, and any-side targeting.
