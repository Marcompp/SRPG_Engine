extends SceneTree
## Makes the placeholder sound effects (audio/effects/*.wav, the names in
## data/sounds.cfg [effects]) with a small retro synth. Run from the project folder:
##   godot --headless --path . --script res://tools/generate_sounds.gd
## then let the editor import them (or add --import to a headless run). Pass effect
## names after "--" to remake only those. Made from scratch, so free to use.
## Effects with no recipe are recorded sounds (see audio/CREDITS.md) and left alone.
##
## Each effect (RECIPES) is a list of voices, mixed together. A voice:
##   wave:  "square", "triangle", "sine", "saw" or "noise" (noise's pitch is how often
##          it picks a new random level: low is a rumble, high a hiss)
##   f0/f1: pitch in Hz at the start and end (a sweep; f1 defaults to f0)
##   at, dur: start and length in seconds
##   vol:   loudness (0..1); attack: fade-in seconds; curve: how fast it dies away
##          (1: straight line, higher: a sharper pluck)
##   duty:  square pulse width (0.5 hollow, 0.125 thin); vib/vib_rate: vibrato
##          depth (fraction of the pitch) and speed (Hz); lp: low-pass (0..1, lower
##          is duller; 1 is off)

const OUT_DIR := "res://audio/effects/"
const RATE := 22050

## A note's pitch, by name: "C5", "F#4", "Bb6".
static func n(note: String) -> float:
	var names := {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}
	var semis: int = names[note[0]]
	var rest := note.substr(1)
	if rest.begins_with("#"):
		semis += 1
		rest = rest.substr(1)
	elif rest.begins_with("b"):
		semis -= 1
		rest = rest.substr(1)
	var midi := (rest.to_int() + 1) * 12 + semis
	return 440.0 * pow(2.0, (midi - 69) / 12.0)


## Quick notes one after another, all with the same settings.
static func arp(notes: Array, step: float, base: Dictionary, last_dur := 0.0) -> Array:
	var voices := []
	for i in notes.size():
		var v := base.duplicate()
		v.f0 = n(notes[i])
		v.at = base.get("at", 0.0) + i * step
		v.dur = last_dur if i == notes.size() - 1 and last_dur > 0.0 else base.get("dur", step)
		voices.append(v)
	return voices


static func recipes() -> Dictionary:
	return {
		# Menus: short and quiet, heard hundreds of times.
		"cancel": arp(["E5", "A4"], 0.045, {"wave": "square", "vol": 0.22, "duty": 0.25, "curve": 1.5, "dur": 0.05},
			0.08),
		"text": [{"wave": "square", "f0": 880.0, "dur": 0.018, "vol": 0.08, "duty": 0.5, "curve": 1.0}],
		# Combat
		"hit": [
			{"wave": "noise", "f0": 6000.0, "f1": 800.0, "dur": 0.12, "vol": 0.55, "curve": 3.0, "lp": 0.6},
			{"wave": "square", "f0": 320.0, "f1": 60.0, "dur": 0.1, "vol": 0.45, "duty": 0.5, "curve": 2.0},
		],
		"spell": arp(["C5", "G5", "D6", "A6", "E7"], 0.035, {"wave": "triangle", "vol": 0.3, "curve": 1.2,
			"dur": 0.12, "vib": 0.02, "vib_rate": 30.0}, 0.3)
			+ [{"wave": "noise", "f0": 12000.0, "dur": 0.35, "vol": 0.08, "attack": 0.1, "curve": 1.0, "lp": 0.5}],
		"break": [
			{"wave": "noise", "f0": 2500.0, "f1": 300.0, "dur": 0.4, "vol": 0.45, "curve": 1.8, "lp": 0.5},
			{"wave": "square", "f0": 150.0, "f1": 35.0, "dur": 0.25, "vol": 0.4, "duty": 0.5, "curve": 1.5},
			{"wave": "noise", "f0": 700.0, "at": 0.12, "dur": 0.2, "vol": 0.3, "curve": 2.0, "lp": 0.3},
		],
	}


func _init() -> void:
	var wanted := OS.get_cmdline_user_args()
	var all := recipes()
	DirAccess.make_dir_recursive_absolute(OUT_DIR)
	var count := 0
	for effect: String in GameData.section("sounds", "effects"):
		if not wanted.is_empty() and not wanted.has(effect):
			continue
		if not all.has(effect):
			# A recorded sound, not a placeholder.
			if wanted.has(effect):
				push_warning("no recipe for \"%s\"" % effect)
			continue
		var entry: Variant = GameData.section("sounds", "effects")[effect]
		var path: String = "res://audio/" + (entry.file if entry is Dictionary else entry)
		write_wav(path, render(all[effect]))
		count += 1
	print("Wrote %d effects to %s" % [count, OUT_DIR])
	quit()


## Mixes the voices into samples (-1..1).
static func render(voices: Array) -> PackedFloat32Array:
	var length := 0.0
	for v in voices:
		length = maxf(length, v.get("at", 0.0) + v.dur)
	var out := PackedFloat32Array()
	out.resize(int(length * RATE) + 1)
	var rng := RandomNumberGenerator.new()
	rng.seed = 7  # the same file every run
	for v in voices:
		var start := int(v.get("at", 0.0) * RATE)
		var count := int(v.dur * RATE)
		var f0: float = v.f0
		var f1: float = v.get("f1", f0)
		var phase := 0.0
		var level := 0.0
		var smooth := 0.0
		var lp: float = v.get("lp", 1.0)
		for i in count:
			var t := float(i) / count
			var freq: float = lerpf(f0, f1, t) * (1.0 + v.get("vib", 0.0) * sin(TAU * v.get("vib_rate", 0.0) * i / RATE))
			var last := phase
			phase = fmod(phase + freq / RATE, 1.0)
			var s := 0.0
			match v.wave:
				"square":
					# Balanced around 0 at any width, so thin pulses don't push the speaker off center.
					var duty: float = v.get("duty", 0.5)
					s = 2.0 * ((1.0 - duty) if phase < duty else -duty)
				"triangle":
					s = 4.0 * absf(phase - 0.5) - 1.0
				"sine":
					s = sin(TAU * phase)
				"saw":
					s = 2.0 * phase - 1.0
				"noise":
					if phase < last or i == 0:
						level = rng.randf_range(-1.0, 1.0)
					s = level
			smooth += (s - smooth) * lp
			var secs := float(i) / RATE
			var attack: float = v.get("attack", 0.002)
			var env := minf(1.0, secs / attack) if attack > 0.0 else 1.0
			env *= pow(1.0 - t, v.get("curve", 1.0))
			out[start + i] += smooth * env * v.vol
	# A soft limit instead of clipping: loud layers round off rather than crackle.
	for i in out.size():
		var x := out[i]
		out[i] = x if absf(x) < 0.7 else signf(x) * (0.7 + 0.3 * tanh((absf(x) - 0.7) / 0.3))
	return out


## 16-bit mono PCM.
static func write_wav(path: String, samples: PackedFloat32Array) -> void:
	var data := PackedByteArray()
	data.resize(samples.size() * 2)
	for i in samples.size():
		data.encode_s16(i * 2, int(samples[i] * 32767.0))
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_buffer("RIFF".to_ascii_buffer())
	file.store_32(36 + data.size())
	file.store_buffer("WAVEfmt ".to_ascii_buffer())
	file.store_32(16)
	file.store_16(1)  # PCM
	file.store_16(1)  # mono
	file.store_32(RATE)
	file.store_32(RATE * 2)
	file.store_16(2)
	file.store_16(16)
	file.store_buffer("data".to_ascii_buffer())
	file.store_32(data.size())
	file.store_buffer(data)
