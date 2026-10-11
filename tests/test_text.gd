extends "res://tests/test_base.gd"
## Translation groundwork (docs/translation.md): text goes through tr() with the
## English as its key, kept text is stored as Text entries, and the extractor finds
## every key.


## A pretend translation for these tests, removed again by _end().
func _pretend(messages: Dictionary) -> Translation:
	var t := Translation.new()
	t.locale = "xx"
	for key in messages:
		t.add_message(key, messages[key])
	TranslationServer.add_translation(t)
	TranslationServer.set_locale("xx")
	return t


func _end(t: Translation) -> void:
	TranslationServer.remove_translation(t)
	TranslationServer.set_locale("en")


func test_entries_render_translated() -> void:
	var entry := Text.entry("Defeated {foe} at {map}.", {"map": "Hill Fort",
		"foe": Text.entry("{name} the {class}", {"name": "Garret", "class": "Brigand"})})
	check_eq(Text.render(entry), "Defeated Garret the Brigand at Hill Fort.", "English with no translation")
	check_eq(Text.render("Raised in the river villages."), "Raised in the river villages.", "plain strings too")
	check_eq(Text.render(Text.entry("Barely survived {foe} at {map}, with {hp} HP left.",
		{"foe": "Gorr", "map": "Ford", "hp": 2})), "Barely survived Gorr at Ford, with 2 HP left.", "numbers")
	var t := _pretend({"Defeated {foe} at {map}.": "{map}: vencio a {foe}.", "{name} the {class}": "{name}, {class}",
		"Brigand": "Bandido"})
	check_eq(Text.render(entry), "Hill Fort: vencio a Garret, Bandido.", "translated when shown, args too")
	_end(t)


func test_biography_is_kept_untranslated() -> void:
	var lord := unit_named("Lord")
	await b.actions.do_seize(lord)
	var entry: Variant = lord.biography[-1]
	check(entry is Dictionary and entry.text == "Seized {map}.", "stored as an entry: %s" % [entry])
	var data := SaveGame.unit_to_dict(lord)
	var copy := SaveGame.unit_from_dict(data)
	check_eq(Text.render(copy.biography[-1]), Text.render(entry), "survives a save")
	copy.free()
	var t := _pretend({"Seized {map}.": "Tomo {map}."})
	b.ui.show_status(lord)
	b.ui.status_screen.page = StatusScreen.PAGES.find("Bio")
	b.ui.status_screen.change_page(0)
	check(_texts(b.ui.status_screen).any(func(s): return s.begins_with("- Tomo ")), "shown translated")
	b.ui.hide_status()
	_end(t)


func test_menus_draw_translated_entries() -> void:
	var lord := unit_named("Lord")
	var t := _pretend({"Wait": "Esperar", "Items": "Objetos"})
	await open_menu_in_place(lord)
	check(b.ui.menu_options.has("Wait"), "entries stay English ids")
	check(b.ui._menu_label.text.contains("Esperar"), "and are drawn translated")
	await pick("Wait")
	check(lord.has_acted, "picking still works")
	_end(t)


func test_event_text_is_translated() -> void:
	var errors: Array = b.events.load_text("""
== turn 2 ==
Messenger: The bridge is out!
@banner Reinforcements!
""")
	check_eq(errors, [], "parses")
	var t := _pretend({"The bridge is out!": "El puente cayo!", "Messenger": "Mensajero"})
	await b.events.on_turn(2, "player")
	check_eq(b.ui.dialogue._text.text, "El puente cayo!", "dialogue translated")
	check_eq(b.ui.dialogue._name_label.text, "Mensajero", "a speaker with no unit too")
	_end(t)


func test_scene_roots_translate_by_hand() -> void:
	# Labels don't translate their text again: the code already did.
	check_eq(b.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_DISABLED, "battle")
	check_eq(b.ui.status_screen.auto_translate_mode, Node.AUTO_TRANSLATE_MODE_INHERIT, "its UI inherits it")


func test_extractor_finds_every_kind_of_key() -> void:
	var extractor = load("res://tools/extract_strings.gd")
	var found := {}
	for m in extractor.scan_script("""
const NAMES := {A: "Alpha", B: "Beta"}  # i18n
const OPTIONS := [  # i18n
	{"key": "game_speed", "label": "Game speed",
		"choices": [[1.0, "Normal"], [2.0, "x2"]]},
]
func f(n):
	popup(tr("Got {item}").format({"item": "Iron Sword"}))
	var s := tr_n("%d unit left", "%d units left", n) % n
	bio.append(Text.entry("Seized {map}.", {"map": title}))
	var x := "Struck down {foe}." if a \\
		else "Defeated {foe}."  # i18n
	var y := TranslationServer.translate('It\\'s "fine"')
	var no := str("Not this") + label("Nor this")
"""):
		found[m.text] = m
	for key in ["Alpha", "Beta", "Game speed", "Normal", "Got {item}", "%d unit left", "Seized {map}.",
			"Struck down {foe}.", "Defeated {foe}.", "It's \"fine\""]:
		check(found.has(key), "finds %s" % key)
	for key in ["game_speed", "key", "label", "x2", "Iron Sword", "map", "Not this", "Nor this"]:
		check(not found.has(key), "skips %s" % key)
	check_eq(found.get("%d unit left", {}).get("plural", ""), "%d units left", "plurals")
	check_eq(found.get("Defeated {foe}.", {}).get("line", 0), 12, "line numbers")
	var events: Array = extractor.scan_events("== start ==\nLord: Hold the bridge.\n@narrate Dawn.\n@move Lord (1, 2)\n")
	check_eq(events.map(func(m): return m.text), ["Lord", "Hold the bridge.", "Dawn."], "event text")
	# The whole project: menu ids, marked constants, event lines.
	var all: Dictionary = extractor.collect()
	for key in ["Wait", "Player Phase", "Seized {map}.", "Fell in {map}, turn {turn}.", "Game speed",
			"Raiders from the east! Keep them off the Elder!"]:
		check(all.has(key), "project has %s" % key)
	var pot: String = extractor.to_pot(all)
	check(pot.contains("msgid \"Wait\"\nmsgstr \"\""), "writes a gettext template")
	check(pot.contains("msgid_plural"), "with plurals")
