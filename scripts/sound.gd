class_name Sound
extends Node
## Music and sound effects. Names come from data/sounds.cfg ([music] and [effects],
## each a file under res://audio/). A name whose file isn't there yet plays nothing,
## so the game can call every sound before it exists; a name missing from
## sounds.cfg is an error.
##
##   Sound.play("hit")             a sound effect
##   Sound.music("player_phase")   switch tracks (the old one fades out); asking for
##                                 the track already playing keeps it going
##   Sound.stop_music()
##
## One player node, made on first use under the tree's root, so music carries on
## across scenes. Volumes are options (Settings "music_volume", "effects_volume"),
## set on the Music and Effects buses; the Options screen calls apply_volumes().

const DIR := "res://audio/"
## Effects that can sound at once.
const VOICES := 8
## Seconds the old track takes to fade out.
const FADE := 0.4

static var MUSIC := GameData.section("sounds", "music")
static var EFFECTS := GameData.section("sounds", "effects")

## The current track's name ("" for none), even while its file is missing.
static var track := ""
## The effects asked for lately, newest last (for tests; at most 32).
static var played: Array[String] = []

static var _node: Sound

var _music: AudioStreamPlayer
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _fade: Tween
## Loaded streams by path and looping (null: the file isn't there). Kept on the node,
## not static, so they're freed with it when the game quits.
var _streams := {}
## The frame each effect last started, so a blast hitting five units sounds once.
var _started := {}


static func play(effect: String) -> void:
	if not EFFECTS.has(effect):
		push_error("Sound.play: no effect \"%s\" in data/sounds.cfg" % effect)
		return
	played.append(effect)
	if played.size() > 32:
		played.pop_front()
	var node := _player()
	if node and node.is_inside_tree():
		node._play_effect(effect)


static func music(track_name: String) -> void:
	if track_name == track:
		return
	if not MUSIC.has(track_name):
		push_error("Sound.music: no track \"%s\" in data/sounds.cfg" % track_name)
		return
	track = track_name
	var node := _player()
	if node:
		node._switch(node._stream(MUSIC[track_name], true), _volume(MUSIC[track_name]))


static func stop_music() -> void:
	track = ""
	var node := _player()
	if node:
		node._switch(null, 0.0)


## Stops the music and every effect at once (no fade), e.g. before quitting.
static func silence() -> void:
	track = ""
	if is_instance_valid(_node):
		_node._exit_tree()


## Sets the bus volumes from the options.
static func apply_volumes() -> void:
	for pair in [["Music", "music_volume"], ["Effects", "effects_volume"]]:
		var bus := AudioServer.get_bus_index(_bus(pair[0]))
		var level: float = Settings.value(pair[1])
		AudioServer.set_bus_mute(bus, level <= 0.0)
		AudioServer.set_bus_volume_db(bus, linear_to_db(maxf(level, 0.0001)))


## The player node, made the first time it's needed. It joins the tree at the end of
## the frame (the root may be busy adding a scene), and starts its track then.
static func _player() -> Sound:
	if is_instance_valid(_node):
		return _node
	var tree := Engine.get_main_loop() as SceneTree
	if tree == null:
		return null
	_node = Sound.new()
	_node.name = "Sound"
	tree.root.add_child.call_deferred(_node)
	return _node


func _init() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_music = AudioStreamPlayer.new()
	_music.bus = _bus("Music")
	add_child(_music)
	var effects_bus := _bus("Effects")
	for i in VOICES:
		var voice := AudioStreamPlayer.new()
		voice.bus = effects_bus
		add_child(voice)
		_voices.append(voice)
	apply_volumes()


func _ready() -> void:
	if _music.stream and not _music.playing:
		_music.play()


func _exit_tree() -> void:
	_music.stop()
	for voice in _voices:
		voice.stop()


func _play_effect(effect: String) -> void:
	var frame := Engine.get_process_frames()
	if _started.get(effect, -1) == frame:
		return
	var stream := _stream(EFFECTS[effect], false)
	if stream == null:
		return
	_started[effect] = frame
	var voice := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	voice.stream = stream
	voice.volume_db = _volume(EFFECTS[effect])
	voice.play()


## Fades out what's playing (game speed doesn't hurry it), then starts `stream`.
func _switch(stream: AudioStream, volume_db: float) -> void:
	if _fade:
		_fade.kill()
		_fade = null
	if not is_inside_tree() or not _music.playing:
		_start(stream, volume_db)
		return
	_fade = create_tween().set_ignore_time_scale()
	_fade.tween_property(_music, "volume_db", -40.0, FADE)
	_fade.tween_callback(_start.bind(stream, volume_db))


func _start(stream: AudioStream, volume_db: float) -> void:
	_music.stop()
	_music.stream = stream
	_music.volume_db = volume_db
	if stream and is_inside_tree():
		_music.play()


## The stream for a sounds.cfg entry (a path, or {"file", "volume", "loop"}), or
## null while its file isn't in the project.
func _stream(entry: Variant, is_music: bool) -> AudioStream:
	var path: String = DIR + (entry.file if entry is Dictionary else entry)
	var loop: bool = is_music and (entry.get("loop", true) if entry is Dictionary else true)
	var key := "%s|%s" % [path, loop]
	if not _streams.has(key):
		var stream: AudioStream = load(path) if ResourceLoader.exists(path) else null
		if stream:
			stream = stream.duplicate()  # looping is set per entry, not on the shared file
			if stream is AudioStreamWAV:
				stream.loop_mode = AudioStreamWAV.LOOP_FORWARD if loop else AudioStreamWAV.LOOP_DISABLED
				if loop and stream.loop_end <= 0:
					stream.loop_end = int(stream.get_length() * stream.mix_rate)
			elif "loop" in stream:
				stream.loop = loop
		_streams[key] = stream
	return _streams[key]


static func _volume(entry: Variant) -> float:
	return float(entry.get("volume", 0.0)) if entry is Dictionary else 0.0


## The bus named `bus_name`, made (feeding Master) if the project has none yet.
static func _bus(bus_name: String) -> StringName:
	if AudioServer.get_bus_index(bus_name) == -1:
		AudioServer.add_bus()
		AudioServer.set_bus_name(AudioServer.bus_count - 1, bus_name)
		AudioServer.set_bus_send(AudioServer.bus_count - 1, "Master")
	return bus_name
