#!/usr/bin/env bash
# Runs the whole suite headless. Fails if a single check fails.
set -u
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
status=0

log="$(mktemp)"
for suite in mechanics brick_feel lifecycle play; do
  echo "=== $suite ==="
  "$GODOT" --headless --path "$ROOT" "res://tests/$suite.tscn" 2>&1 | grep -v "^Godot Engine" | tee "$log"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then status=1; fi
  # A run with no failed checks can still have shouted on the way.
  if grep -qE "SCRIPT ERROR|ObjectDB instances were leaked|resources still in use" "$log"; then
    echo "  --> $suite shouted in the console"
    status=1
  fi
done
rm -f "$log"

if [ "$status" -eq 0 ]; then echo "ALL SUITES PASSED"; else echo "AT LEAST ONE SUITE FAILED"; fi
exit "$status"
