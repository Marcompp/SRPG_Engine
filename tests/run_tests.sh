#!/usr/bin/env bash
# Runs the headless test suite. Also fails if Godot printed any runtime script
# error: Godot logs those and keeps going, so the GDScript runner can't see them.
#
# Usage: GODOT=/path/to/godot tests/run_tests.sh   (GODOT defaults to "godot")

GODOT="${GODOT:-godot}"
cd "$(dirname "$0")/.." || exit 1

output=$("$GODOT" --headless --path . --script res://tests/run_tests.gd 2>&1)
code=$?
echo "$output"

if echo "$output" | grep -q "SCRIPT ERROR"; then
	echo ""
	echo "FAILED: runtime script errors were printed above."
	exit 1
fi
exit $code
