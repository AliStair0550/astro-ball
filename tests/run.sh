#!/usr/bin/env bash
# Kører hele testsuiten headless. Fejler, hvis bare ét tjek fejler.
set -u
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
status=0

for suite in mechanics lifecycle play; do
  echo "=== $suite ==="
  "$GODOT" --headless --path "$ROOT" "res://tests/$suite.tscn" 2>&1 | grep -v "^Godot Engine"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then status=1; fi
done

if [ "$status" -eq 0 ]; then echo "ALLE SUITER BESTOD"; else echo "MINDST ÉN SUITE FEJLEDE"; fi
exit "$status"
