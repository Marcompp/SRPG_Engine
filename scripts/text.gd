class_name Text
extends RefCounted
## Player-facing text, ready for translation. Rules: docs/translation.md.
##
## The English text is its own translation key (gettext style). Code shows text
## through tr() (TranslationServer.translate() in static functions), so with no
## translation loaded everything reads as written. tools/extract_strings.gd collects
## every key into locale/messages.pot.
##
## Text that is kept, like biography entries, is stored untranslated as an entry,
## and translated when shown: a save made in one language reads in another.


## A kept text: `text` is the English template, with {placeholders} filled from
## `args`. Args can be numbers, strings (translated when shown: map and class
## names...) or entries themselves.
static func entry(text: String, args := {}) -> Dictionary:
	return {"text": text, "args": args}


## The translated text of an entry, or of a plain string (older saves, roster "bio").
static func render(e: Variant) -> String:
	if e is Dictionary:
		var args := {}
		for k in e.get("args", {}):
			args[k] = render(e.args[k])
		return TranslationServer.translate(e.text).format(args)
	if e is String or e is StringName:
		return TranslationServer.translate(e)
	return str(e)


## Turns automatic translation of Label text off under `node`: the code translates
## what it shows, and a translated text must not be looked up a second time.
static func manual(node: Node) -> void:
	node.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
