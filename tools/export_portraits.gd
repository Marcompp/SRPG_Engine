extends SceneTree
## Exports the portrait parts (see tools/portrait_exporter.gd). Run from the project folder:
##   godot --headless --path . --script res://tools/export_portraits.gd
## The portrait editor (tools/portrait_editor.tscn) has a button for it too.


func _initialize() -> void:
	var errors := PortraitExporter.run()
	for e in errors:
		printerr(e)
	if errors.is_empty():
		var count := 0
		for slot in Portraits.PARTS:
			count += Portraits.PARTS[slot].size()
		print("Exported %d parts in %d slots (%dx%d)." % [count, Portraits.PARTS.size(), Portraits.SIZE.x, Portraits.SIZE.y])
	quit(0 if errors.is_empty() else 1)
