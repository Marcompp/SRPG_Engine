# Translation (design notes)

Groundwork only: there are no translations and no language option yet. Player-facing
text is written so that adding a language later means writing a translation file,
not changing code.

## How it works

- **The English text is the key** (gettext style): `tr("Seize!")`. With no translation
  loaded, every text reads as written. There is no list of ids to keep in sync, and
  editing an English line only means its translations need a look.
- **Static functions** use `TranslationServer.translate()` (and
  `TranslationServer.translate_plural()`), since `tr()` needs an object.
- **Scene roots turn off Godot's automatic Label translation** (`Text.manual`): the
  code translates what it shows, so a text is never looked up twice.
- **Kept text** (biography entries, stored in saves) is stored untranslated, as a Text
  entry `{"text": "Seized {map}.", "args": {"map": "Hill Fort"}}`, and translated when
  shown (`Text.render`). A save made in one language reads in another. String args are
  translated too, and an arg can be an entry itself ("{name} the {class}"). Plain
  strings still work (older saves, roster `"bio"`).
- **Events:** dialogue, `@narrate` and `@banner` text are translated when shown. A
  speaker with no unit ("Messenger") is translated; unit names aren't.

## Writing text

- **Placeholders:** a sentence with values in it uses named placeholders, so a
  translation can reorder them: `tr("{unit} now rides {mount}.").format({...})`. Short
  labels and number layouts can use `%`: `tr("HP %d/%d") % [hp, max_hp]`.
- **No sentences glued from pieces:** `"Struck down " + how + " at %s."` can't be
  translated. Write each whole sentence, even if that means two similar ones.
- **Plurals:** `tr_n("End turn? %d unit hasn't acted", "End turn? %d units haven't acted", n) % n`.
- **Menu entries are English ids:** the code matches on them ("Wait", "Attack"), and
  the menu translates each one when it draws it. Entries built from a template are
  translated where they're built ("Turn %d").
- **Text kept in constants** (faction names, options, glossary) is translated where
  it's shown. Mark the constant with an `# i18n` comment so the extractor finds it:

  ```gdscript
  const NAMES := {PLAYER: "Player", ALLY: "Ally"}  # i18n
  options.append("Seize")  # i18n
  ```

  The marker covers the whole statement (open brackets and `\` continue it). The
  extractor skips dictionary keys and lowercase ids (`"game_speed"`, `"x4"`), so a
  marked display text must not be one lowercase word.

## Extracting

```
godot --headless --path . --script res://tools/extract_strings.gd
```

This writes `locale/messages.pot`, the gettext template that `.po` translation files
are made from (with Poedit or similar). It's generated, so it isn't kept in git. A
language is added by putting its `.po` in `locale/` and listing it under Project
Settings > Localization > Translations.

It collects:
- the first argument of `tr()`, `TranslationServer.translate()` and `Text.entry()`,
  and both arguments of `tr_n()` and `TranslationServer.translate_plural()`,
  in `scripts/*.gd`;
- every string on a statement marked `# i18n`;
- dialogue, speakers, `@narrate` and `@banner` text in `events/*.txt`.

## Not done yet

- **Game data:** class, race, skill, item, weapon, spell, status, mount, terrain and
  map names and descriptions, roster bios, and event scripts written as data lists in
  `scripts/levels.gd`. They're shown as written. Some screens already pass them through
  `tr()`, but nothing extracts them yet. This belongs with moving the data out of
  `.gd` constants, which will pick the key scheme.
- **English grammar in code:** a few texts build English forms, like `"{race}s can't
  ride."`, `.to_lower()` on a status name, `.capitalize()` on move types and weapon
  types, and the hidden gender words (`male`, `female`). These go with the data.
- **Unit names** aren't translated (on purpose for now).
- **A language option**, and a font with the glyphs other languages need.
- **Changing the language mid-scene:** labels built once (forecast rows, tabs) keep
  their language until the scene reloads.
