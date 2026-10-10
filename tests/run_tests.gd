extends SceneTree
## Headless test runner. Run from the project folder:
##   godot --headless --path . --script res://tests/run_tests.gd
## (or tests/run_tests.sh, which also fails on runtime script errors).
## Exits with code 0 if every test passes, 1 otherwise.
##
## Tests live in the suites below (tests/test_*.gd, helpers in tests/test_base.gd).
## Every method named test_* runs, in order, each on a fresh battle scene. Pass
## suite names as extra arguments to run only those (e.g. "-- skills events").

const SUITES: Array[String] = ["core", "ai", "units", "ui", "campaign", "maps", "skills", "events", "mounts"]

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
	Campaign.path = "user://test_campaign.save"
	Campaign.delete_save()
	_run_all()

func _run_all() -> void:
	var wanted := OS.get_cmdline_user_args()
	var count := 0
	for suite_name in SUITES:
		if not wanted.is_empty() and not wanted.has(suite_name):
			continue
		var suite = load("res://tests/test_%s.gd" % suite_name).new()
		suite.setup(self)
		for method in suite.get_script().get_script_method_list():
			var t: String = method.name
			if not t.begins_with("test_"):
				continue
			current_test = t
			# Every test starts on the default test map, outside the campaign.
			Levels.selected = "river_crossing"
			Campaign.active = false
			Campaign.clear_deployment()
			await suite._fresh_battle()
			var before := failures.size()
			await suite.call(t)
			print(("PASS  " if failures.size() == before else "FAIL  ") + t)
			count += 1
			b.queue_free()
			await process_frame
	SaveGame.delete_suspend()
	DirAccess.remove_absolute(Settings.path)
	Campaign.delete_save()
	print("")
	if failures.is_empty():
		print("All %d tests passed." % count)
		quit(0)
	else:
		print("%d failure(s):" % failures.size())
		for f in failures:
			print("  " + f)
		quit(1)
