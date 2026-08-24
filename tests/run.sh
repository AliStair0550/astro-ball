#!/usr/bin/env bash
# Kører hele testsuiten headless. Fejler, hvis bare ét tjek fejler.
set -u
GODOT="${GODOT:-/Applications/Godot.app/Contents/MacOS/Godot}"
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
status=0

log="$(mktemp)"
for suite in mechanics lifecycle play; do
  echo "=== $suite ==="
  "$GODOT" --headless --path "$ROOT" "res://tests/$suite.tscn" 2>&1 | grep -v "^Godot Engine" | tee "$log"
  if [ "${PIPESTATUS[0]}" -ne 0 ]; then status=1; fi
  # En koersel uden fejlede tjek kan stadig have raabt op undervejs.
  if grep -qE "SCRIPT ERROR|ObjectDB instances were leaked|resources still in use" "$log"; then
    echo "  --> $suite raabte op i konsollen"
    status=1
  fi
done
rm -f "$log"

if [ "$status" -eq 0 ]; then echo "ALLE SUITER BESTOD"; else echo "MINDST ÉN SUITE FEJLEDE"; fi
exit "$status"
