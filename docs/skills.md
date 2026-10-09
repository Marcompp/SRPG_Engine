# Skills (design notes)

Design for the skill system. Nothing here is implemented yet. Modeled on the FE8 Skill
System hack: skills come from many sources, are data, and plug into a fixed set of
moments in the game (before combat, each strike, after combat, turn start, the unit
menu...).

## Goals

- One system for everything a unit "has": class abilities (Dance, Inspire), racial
  traits (Troll regeneration, Human EXP bonus), personal skills, weapon and item
  skills, and skills learned from levels or scrolls.
- Most skills are **pure data** in `scripts/skills.gd`, built from a small set of
  effect types. Skills that don't fit get a named handler in code (an escape hatch,
  not the default).
- Every number the player sees (forecast, stats screen) already includes skill
  effects, so the AI and the forecast agree with what happens.

## Where skills come from

A unit's skills are the union of these sources, recomputed when any of them changes:

| Source | Data | Notes |
|---|---|---|
| Personal | roster `"skills": [...]` | Character-specific (FE's personal skills) |
| Class | `Classes.DATA[c].skills` | Lost on reclass/promotion unless learned |
| Class, by level | `Classes.DATA[c].learn: {5: "Canto", 15: "Luna"}` | Learned for good when reaching the level in that class |
| Personal, by level | roster `"learn": {10: "Miracle"}` | Same, per character |
| Race | `Races.DATA[r].skills` | Racial traits become skills (see Migration) |
| Equipped weapon | `Weapons.DATA[w].skills` | Only while equipped (e.g. a Wo Dao-like crit sword) |
| Held item | `Items.DATA[i].skills` | Only while in the inventory (rings, charms) |
| Scroll | item kind `"scroll"`, `"skill": "Vantage"` | Using it teaches the skill for good; the scroll is used up |

"Learned" skills (from levels and scrolls) are stored on the unit (`Unit.learned`, at
most 5) and saved; the others are derived from class, race, roster and inventory
every time.

## What a skill can do

A skill is a dictionary with a name, a description, and one or more effects. Each
effect has a **kind**, saying when it applies, and optional **conditions**.

### Effect kinds

| Kind | When | Examples |
|---|---|---|
| `stats` | Always: flat changes to stats, MOV, max HP/MP | Celerity (+1 MOV), Strength +2 |
| `battle` | When combat numbers are computed (forecast, AI, the real fight): changes to Atk, Def, Hit, Avo, Crit, Crit avoid, AS | Wrath, Darting Blow, Fortress, Charm-like auras |
| `rules` | Combat structure: strike order and counters | Vantage, Desperation, Quick Riposte, Wary Fighter, Close/Distant Counter, Dazzle (no counter) |
| `proc` | Each strike, with an activation rate | Luna, Sol, Pavise, Aegis, Lethality, Miracle, Astra |
| `after_combat` | Once the fight is over | Lifetaker (heal on kill), Galeforce (act again after a kill), Poison Strike, Savage Blow |
| `turn_start` | Start of the unit's phase | Renewal (heal %), MP regen, Imbue |
| `command` | Adds an entry to the unit menu | Dance, Inspire, Steal, Rally |
| `map` | Movement and positioning | Pass (move through enemies), Pathfinder (all terrain costs 1), Canto (move again after acting) |
| `exp` | EXP and growth | Paragon (EXP x2), the Human EXP bonus, growth boosts |
| `aura` | Wraps a `battle` effect for units within a radius | Charisma (+10 Hit/Avo to allies within 3), Anathema |

### Conditions

Shared by every kind, so new skills rarely need code. All listed conditions must hold:

- `initiating` / `defending`: who started the fight
- `phase`: "player" / "enemy"
- `hp_below` / `hp_above`: fraction of max HP
- `range`: e.g. [1, 1] for melee only
- `weapon_type`: "sword", "bow"... (own equipped weapon)
- `foe_tag`: the opponent has a tag ("flying", "horse", "spirit"...)
- `adjacent_ally` / `no_adjacent_ally`
- `terrain`: standing on certain terrain keys

### Activation rates (procs)

`"rate"` is either a number (fixed %) or a stat expression evaluated on the skill's
owner: `"dex"`, `"lck"`, `"dex/2"`, `"lv"`. FE uses SKL for most procs; DEX is the
closest stat here. Procs show the skill name as a popup when they fire. They are not
in the forecast (as in FE), and the AI ignores them when choosing targets.

### Proc effects

A small fixed set covers most of FE: `pierce` (ignore a fraction of DEF: Luna),
`drain` (heal a fraction of damage dealt: Sol), `reduce` (cut damage taken by a
fraction: Pavise/Aegis), `extra_strikes` (Astra), `lethal` (instant kill), `survive`
(survive a lethal hit at 1 HP: Miracle), `damage_bonus` (+X damage).

### Escape hatch

`"handler": "galeforce"` names a function in `scripts/skill_handlers.gd`, called at the
skill's kind's moment with the unit and context. Only for skills the data can't
express.

## Example data

```gdscript
"Wrath":        {"desc": "+20 Crit at or below half HP.",
                 "battle": {"crit": 20}, "if": {"hp_below": 0.5}},
"Darting Blow": {"desc": "+5 AS when initiating combat.",
                 "battle": {"as": 5}, "if": {"initiating": true}},
"Vantage":      {"desc": "Strikes first when attacked at or below half HP.",
                 "rules": ["vantage"], "if": {"defending": true, "hp_below": 0.5}},
"Luna":         {"desc": "DEX% chance to ignore half the foe's DEF.",
                 "proc": {"on": "attack", "rate": "dex", "effect": "pierce", "value": 0.5}},
"Pavise":       {"desc": "DEX% chance to halve melee damage taken.",
                 "proc": {"on": "defend", "rate": "dex", "effect": "reduce", "value": 0.5},
                 "if": {"range": [1, 1]}},
"Celerity":     {"desc": "+1 MOV.", "stats": {"mov": 1}},
"Renewal":      {"desc": "Recovers 10% HP at the start of each turn.", "turn_start": {"heal": 0.1}},
"Dance":        {"desc": "Refresh an adjacent ally that has acted.", "command": "dance"},
"Galeforce":    {"desc": "Can act again after defeating a foe on its own phase (once per turn).",
                 "handler": "galeforce"},
```

## Where it plugs into the code

- **`scripts/skills.gd`** (`Skills`): the data, plus `Skills.of(u)` (every source,
  deduplicated, in a stable order) and helpers to sum `stats`/`battle` effects whose
  conditions hold.
- **Unit**: `learned` (saved), `skills()` (cached, invalidated when the class, level,
  items or equipped weapon change). `combat_str()` and friends add `stats` effects.
- **Combat**: the formulas get a single per-matchup entry point (attacker, defender,
  map, who initiated) that applies `battle` effects and auras, so the forecast, the
  AI and the real strikes share the numbers. `strike_order` reads `rules`. Each
  strike rolls the striker's and the target's procs.
- **BattleActions**: `after_combat` effects after `_finish_exchange`; commands
  replace `has_ability("dance")`-style checks.
- **BattlePhases**: `turn_start` effects at the start of each side's phase (next to
  healing tiles).
- **BattleInput**: the unit menu lists command skills.
- **UI**: the status screen's Skills page lists skills with their source; detail
  mode shows the description. Proc popups in battle. The info panel's "Skill:" line
  lists command skills.
- **Level-ups**: reaching a level in a class's or roster's `learn` table teaches the
  skill, with a popup after the level-up window.

## Migration

Existing special cases become skills, so there's one system instead of three:

- Class abilities "dance" and "inspire" → command skills Dance and Inspire on the
  Performer and Bannerman classes. "ship" stays a class property (it's about what
  the class is, not something it does).
- Race traits → race skills: Human EXP bonus (Adaptable), Troll HP regen
  (Regeneration), Fairy MP regen, poison immunity. Race "move", "tags", "banned",
  "carrier" etc. stay race properties.

## Build order

Steps 1-3 are done. Step 4 (content) is in progress: the class skills agreed so far
are in the README's Classes table. Rules for class skills: base classes get few,
low-impact skills that reinforce the class identity (learned at Lv 10 as small
rewards for sticking with the class); innate skills are the class's identity and a
promoted class lists its own full set; class skills end up on enemies, so they must
not change damage or attack speed depending on who attacks, nor add damage procs
(Lethality on Assassin is the accepted exception). Still open: the cavalry line's Lv 10 and promoted skills, personal skills and
loot. Limits for now: procs only on weapon strikes; Canto only for
player units (the AI doesn't plan around it); auras only carry `battle` modifiers.
Auras and adjacency conditions see the map's units through `Skills.field`, set by
the battle scene.

1. Core: `Skills` data and sources (personal, class, race, weapon, item, learned),
   `stats` effects, scrolls, level-learned skills, status screen page, save/load.
   Migrate Dance/Inspire and the racial traits.
2. Combat: `battle` effects with conditions, `rules` (strike order), `proc` effects
   with popups.
3. Around combat: `after_combat`, `turn_start`, `map` (Pass, Pathfinder, Canto),
   `aura`, `exp`.
4. Content: a starter set of FE skills across classes, races, a few skill weapons,
   rings and scrolls, used on the test maps and in the campaign.

## Decided

- **Learned skills are capped at 5** (`Skills.LEARNED_CAP`). Learning a sixth (level-up
  or scroll) asks which to forget, or not to learn the new one; a scroll that isn't
  learned isn't used up. Enemies that are full just don't learn.
- **Promotion drops the old class's skills** (they come from the class). Skills the
  unit *learned* from its old class's level table are learned skills, so they stay.
- **Skills are visible on both sides' status screens**, except skills marked
  `"hidden": true`, which never show anywhere (player or enemy), proc popups included.
- Units that start above level 1 already know what their learn tables teach up to
  that level (keeping the last 5).
