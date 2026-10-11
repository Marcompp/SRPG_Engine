# Factions (design notes)

Design notes. Step 1 of the build order is built (`scripts/factions.gd`). Today a unit is on one of two teams, player (blue) or
enemy (red). This adds three AI factions, each with its own phase:

| Faction | Color | Default stance | Phase |
|---|---|---|---|
| Player | Blue | Hostile to red, purple | 1st |
| Ally | Green | Friendly to blue; hostile to red, purple | 2nd |
| Enemy | Red | Hostile to blue, green, purple, yellow | 3rd |
| Other | Purple | Hostile to everyone else | 4th |
| Neutral | Yellow | Hostile to no one, until provoked | 5th |

Phases with no units are skipped. Each has a banner ("Ally Phase"...).

## Relations

- **Hostility is one-way:** `hostile(a, b)` means faction a attacks b. Red is hostile
  to yellow, but yellow isn't hostile to anyone. Counterattacks don't check it:
  anyone attacked fights back.
- **Defaults** as in the table. A map can override them: `"relations":
  {"other": ["enemy"]}` (purple only fights red). Saved with the battle.
- **Events** change them mid-battle: `@hostile purple, player` / `@peace purple,
  player` (betrayals, truces), and `@side Unit, green` moves one unit to a faction
  (`@recruit` stays the shortcut for joining the player).
- **Passing through:** a unit can move through units of any faction that isn't
  hostile to it either way (blue and green pass through each other).
- **Your attacks** list every unit your side is hostile to. Your side starts hostile
  to yellow (you *can* attack neutrals), but see Neutrals.

## Green allies

- Fully AI-controlled, on their own phase, using the existing enemy AI (presets,
  healing, retreating) against whatever they're hostile to.
- Your units can support them: Heal, Restore, Dance, Rescue (and Drop), Talk. No
  Trade and no Shove. They can't be selected.
- They earn EXP and level up on their kills (a popup, no level-up window). They
  don't join the campaign army unless recruited.

## Yellow neutrals

- Don't attack anyone. Red (and purple) attack them by default: protect/escort
  missions.
- **Provoking:** when your side attacks a yellow unit, all of yellow becomes
  hostile to your side, and they fight you on their phase. (Only your side's
  attacks provoke; red attacking them doesn't change anything.)

## Map, danger zone and objectives

- Unit colors per faction (body, status screen portrait, info panel name).
- The danger zone shows every unit hostile to the player (red, purple, provoked
  yellow). Marking (Z) works on those; Z on a green or unprovoked yellow unit opens
  the map menu.
- **Rout** means defeating every unit hostile to the player. Green and unprovoked
  yellow don't count.
- New defeat condition `"protect": ["Name", ...]`: losing if one of these falls
  (green or yellow units to keep alive).
- Kills by a non-player faction give no player EXP; biography moments only for your
  units, as now.

## Level data

New roster lists beside `"players"` and `"enemies"`: `"allies"`, `"others"`,
`"neutrals"`. Turn events can name the phase: `== turn 3, ally ==`.

## Build order

1. **Core:** the factions and colors, a `hostile` / `friendly` check replacing the
   team comparisons, relations (defaults, per map, saved), the new roster lists,
   the phase loop with a phase per faction, AI targeting whatever its faction is
   hostile to, danger zone and rout.
2. **Interaction:** supporting green units, provoking yellow, green EXP, the
   `protect` defeat condition.
3. **Events and a test map:** `@hostile`, `@peace`, `@side`, per-faction turn
   triggers, and a "Three Armies" map with all of it.
