class_name Settings
extends RefCounted
## Player options, saved to user://settings.cfg and loaded on first use.
## Read with Settings.value("key"); the Options screen changes them and saves.

## Tests point this elsewhere so they always run with the defaults.
static var path := "user://settings.cfg"

## Every option, in display order: key, label, and its choices as [value, text].
## The first choice is the default.
const OPTIONS := [
	{"key": "game_speed", "label": "Game speed",
		"choices": [[1.0, "Normal"], [1.5, "Fast"], [2.0, "Faster"]]},
	{"key": "fast_forward_speed", "label": "Fast-forward (hold X)",
		"choices": [[4.0, "x4"], [3.0, "x3"], [2.0, "x2"]]},
	{"key": "danger_zone_default", "label": "Danger zone at start",
		"choices": [[false, "Off"], [true, "On"]]},
	{"key": "auto_end_turn", "label": "Auto-end turn",
		"choices": [[true, "On"], [false, "Off"]]},
	{"key": "end_turn_warning", "label": "End turn warning",
		"choices": [[true, "On"], [false, "Off"]]},
	{"key": "level_up_wait", "label": "Level-up window",
		"choices": [[true, "Wait for Z"], [false, "Auto (2 s)"]]},
	{"key": "auto_save", "label": "Auto save",
		"choices": [[true, "Each turn"], [false, "Off"]]},
	{"key": "rewinds", "label": "Turn rewinds",
		"choices": [[3, "3 per map"], [5, "5 per map"], [1, "1 per map"], [-1, "Unlimited"], [0, "Off"]]},
]

static var _values := {}
static var _loaded := false


static func value(key: String) -> Variant:
	_ensure_loaded()
	return _values[key]


static func set_value(key: String, v: Variant) -> void:
	_ensure_loaded()
	_values[key] = v


## Index of the current value among an option's choices.
static func choice_index(option: Dictionary) -> int:
	var current: Variant = value(option.key)
	for i in option.choices.size():
		if option.choices[i][0] == current:
			return i
	return 0


static func save() -> void:
	_ensure_loaded()
	var cfg := ConfigFile.new()
	for key in _values:
		cfg.set_value("options", key, _values[key])
	cfg.save(path)


## Back to defaults and reread from `path` (used when tests switch the path).
static func reload() -> void:
	_loaded = false
	_ensure_loaded()


static func _ensure_loaded() -> void:
	if _loaded:
		return
	_loaded = true
	_values.clear()
	for option in OPTIONS:
		_values[option.key] = option.choices[0][0]
	var cfg := ConfigFile.new()
	if cfg.load(path) != OK:
		return
	for option in OPTIONS:
		var saved: Variant = cfg.get_value("options", option.key, _values[option.key])
		# Only accept values the option actually offers.
		if option.choices.any(func(c): return c[0] == saved):
			_values[option.key] = saved
