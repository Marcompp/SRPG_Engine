# Game data (format notes)

The game's database lives in `data/`: classes, races, weapons, items, spells, skills,
statuses, mounts, terrain, AI presets, prices and the maps. The scripts hold the
rules and read the data; editing a stat, adding a weapon or drawing a map shouldn't
mean touching code. This is the groundwork for a database editor, several campaigns
and per-campaign feature toggles.

## Files

| File | Read into | What |
|---|---|---|
| `weapons.cfg` | `Weapons.DATA` | weapons |
| `items.cfg` | `Items.CONSUMABLES` | consumables and held items (rings) |
| `economy.cfg` | `Items.PRICES`, `Shop.DEFAULT_STOCK` | `[prices]`, `[shop]` default stock |
| `classes.cfg` | `Classes.DATA` | classes |
| `icons.cfg` | `ClassIcon.ICONS` | placeholder class icons (7x7 pixel rows) |
| `class_stats.cfg` | `Classes.DEFAULT_CAPS`, `DEFAULT_PROMOTION_BONUS` | `[default_caps]`, `[default_promotion_bonus]` |
| `promotion_bonuses.cfg` | `Classes.PROMOTION_BONUS` | per promoted class |
| `races.cfg` | `Races.DATA` | races |
| `spells.cfg` | `Spells.DATA` | spells and racial attacks |
| `skills.cfg` | `Skills.DATA` | skills |
| `statuses.cfg` | `Statuses.DATA` | status effects |
| `mount_species.cfg` | `Mounts.SPECIES` | mount species |
| `mounts.cfg` | `Mounts.MOUNTED_CLASS`, `DISPLAY`, `NAMES` | `[mounted_class]`, `[display]`, `[names]` |
| `names.cfg` | `Names.BY_RACE`, `Names.DEFAULT` | generic unit names: `[default]`, plus a section per race with its own |
| `ai_presets.cfg` | `AIProfiles.PRESETS` | enemy behavior presets |
| `weapon_traits.cfg` | `WeaponTraits.LEANINGS`, `GENERIC` | `[leanings]`, `[generic]` |
| `terrain.cfg` | `BattleMap.TERRAIN` | terrain, by layout key |
| `sounds.cfg` | `Sound.MUSIC`, `Sound.EFFECTS` | `[music]` tracks and `[effects]`: names to files under `audio/` |
| `combat.cfg` | `Combat.TRIANGLE`, `TAG_TRAITS` | `[triangle]`, `[tag_traits]` |
| `levels/` | `Levels.DATA`, `Levels.ORDER` | test maps: one file each, `index.cfg` lists them in order |
| `campaigns/` | `Chapters.CAMPAIGNS`, `Chapters.DATA`, `Chapters.ORDER` | campaigns: `index.cfg` lists them; each `<id>/` has a `campaign.cfg` (name, description, `chapters` in play order, optional `start_gold`) and a `chapters/` folder, one file per chapter. Chapter ids are unique across campaigns and test maps |

What each field means is documented where the code uses it, at the top of the
script that reads the file (`scripts/weapons.gd` for weapons, and so on). Engine
rules stay in code: faction sides, UI layouts, the lists of valid keys, the
glossary, and single numbers like `Classes.PROMOTION_LEVEL`.

## Format

Godot's `ConfigFile` format: `[sections]` of `key=value` lines, where a value is
written as in GDScript. It was picked over JSON because it keeps what the data
needs: ints and floats stay apart (`mt=5`, `cost={"*": 0.7}`), dictionaries can have
int keys (`learn={10: "Speed +2"}`), cells are `Vector2i(1, 4)`, and lines can have
comments.

```ini
; Effective weapons
[Pike]
type="spear"
mt=7
effective=["horse"]
```

- **An entry is a section**, named by its id (`[Iron Sword]`, `[Swordsman]`,
  `[.]` for the plain terrain). The order of sections is the order in game.
- **Keys** that aren't plain lowercase names need quotes: `"Iron Sword"=460`.
  Unquoted, ConfigFile drops their spaces.
- **Map files** (`levels/`, a campaign's `chapters/`) are one entry each, with their keys at the
  top and no section header.
- **Comments** start with `;`. A `#` is not a comment.
- **Colors** are hex strings (`color="b050e0"`): any key named `color` is read as a
  Color.
- **A section with no keys disappears** on loading. Give it at least one (the
  `charger` preset spells out the default `move="charge"`).
- Values can span lines while brackets are open.

## How it's loaded

`GameData` (`scripts/game_data.gd`) reads the files. Each data module loads its
tables once, as static vars with the names the constants had, so the rest of the
code didn't change. The tables are read-only, down to nested values, like the
constants were. Copy what you need to change (`Weapons.make()` already does).

A new table: write the file, load it from its module with `GameData.entries()`
(sections as entries), `GameData.section()` (one section as a dictionary),
`GameData.strings()` (a typed list of names) or `GameData.folder()` (one file per
entry), and add a row above.

## Checks

The `data` test suite (`tests/test_data.gd`) checks that the files load as the
constants did (types, read-only, order) and that every name one file uses for
another's entries exists: class, race and item skills, statuses named by weapons,
items and spells, prices, mount tables, terrain, AI presets, and every map's rosters
and objects. The older suites check the rest (`Skills.validate()`,
`Statuses.validate()`, level layouts, class promotions).

## Translation

`tools/extract_strings.gd` also collects text from the data files (see
`docs/translation.md`): entry names in the files whose entries are shown by name
(weapons, items, classes, races, spells, skills, statuses, mount species), the
`name`, `description` and `cured_text` keys of an entry (so terrain and map names
too, but not a roster unit's name), and the mounted class names in `mounts.cfg`.
The English text is the key, as everywhere else.

## Exporting

`.cfg` files aren't Godot resources, so an export must include them: add `data/*`
to the export preset's "Filters to export non-resource files".

## Later

- **Per-campaign data:** campaigns have their own folders now (chapters, settings); a
  campaign folder could also override or add to the shared tables (classes, items...).
  `GameData` is the one place that would need to know.
- **Database editor:** it can read and write these files with `ConfigFile`. Saving
  through `ConfigFile` drops comments and reflows values, so the editor should keep
  them some other way, or this format's comments become the editor's notes field.
