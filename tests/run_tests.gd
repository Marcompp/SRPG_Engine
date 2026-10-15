extends SceneTree
## Headless test runner. Run from the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## (or tests/run_tests.sh, which also fails on runtime script errors).
## Exits with code 0 if every test passes, 1 otherwise.
##
## Tests live in the suites below (tests/test_*.gd, helpers in tests/test_base.gd).
## Every method named test_* runs, in order, each on a fresh battle scene. Pass
## suite names as extra arguments to run only those (e.g. "-- skills events").

const SUITES: Array[String] = ["core", "ai", "units", "ui", "campaign", "maps", "skills", "events", "mounts", "statuses", "factions",
	"text", "economy", "weapons", "data", "sound", "portraits"]

## How much faster than normal the battle runs in tests (see Battle.speed_boost).
const SPEED_BOOST := 60.0

var b: Node
var failures: Array[String] = []
var current_test := ""


func _initialize() -> void:
	# Never touch a real suspend file.
	SaveGame.path = "user://test_suspend.save"
	SaveGame.delete_suspend()
	# ...or real settings: tests run with the defaults.
	Settings.path = "user://test_settings.cfg"
	DirAccess.remove_absolute(Settings.path)
	Settings.reload()
	# ...or a real campaign.
	Campaign.save_prefix = "user://test_campaign_"
	Campaign.old_path = "user://test_campaign.save"
	_delete_campaign_saves()
	_run_all()

func _run_all() -> void:
	var wanted := OS.get_cmdline_user_args()
	var count := 0
	for suite_name in SUITES:
		if not wanted.is_empty() and not wanted.has(suite_name):
			continue
		# A suite that doesn't parse is a failure, not a hang.
		var script: GDScript = load("res://tests/test_%s.gd" % suite_name)
		if script == null or not script.can_instantiate():
			failures.append("%s: the suite doesn't load (see the errors above)" % suite_name)
			continue
		var suite = script.new()
		suite.setup(self)
		for method in suite.get_script().get_script_method_list():
			var t: String = method.name
			if not t.begins_with("test_"):
				continue
			current_test = t
			# Every test starts on the default test map, outside the campaign.
			Levels.selected = "river_crossing"
			# Animations and pauses run sped up (tests about game speed set it back to 1).
			Battle.speed_boost = SPEED_BOOST
			Campaign.active = false
			Campaign.clear_deployment()
			Campaign.select(Chapters.CAMPAIGNS.keys()[0])  # the test campaign, whatever a test chose
			await suite._fresh_battle()
			var before := failures.size()
			await suite.call(t)
			print(("PASS  " if failures.size() == before else "FAIL  ") + t)
			count += 1
			b.queue_free()
			await process_frame
	SaveGame.delete_suspend()
	DirAccess.remove_absolute(Settings.path)
	_delete_campaign_saves()
	# Sounds still playing at exit would be reported as leaks.
	Sound.silence()
	await create_timer(0.1, true, false, true).timeout  # real time: the audio thread lets go
	print("")
	if failures.is_empty():
		print("All %d tests passed." % count)
		quit(0)
	else:
		print("%d failure(s):" % failures.size())
		for f in failures:
			print("  " + f)
		quit(1)


## Every campaign's test save (tests may play any campaign).
func _delete_campaign_saves() -> void:
	for id: String in Chapters.CAMPAIGNS:
		Campaign.select(id)
		Campaign.delete_save()
	Campaign.select(Chapters.CAMPAIGNS.keys()[0])
