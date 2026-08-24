class_name LevelLoader
extends RefCounted

## Leveldata fra JSON, med validering efter reglerne i afsnit 11.
##
## Valideringsreglerne er ikke pynt. Et level med 12 tegn i en række
## eller power-up-procenter, der ikke summerer til 100, er en fejl, der
## først viser sig som mærkelig opførsel midt i et spil. Bedre at fange
## den ved indlæsning.

const GRID_COLUMNS := 13
const MAX_ROWS := 12
const MIN_BREAKABLE := 20
const LEVEL_DIR := "res://levels"


## Alle levelfiler i levels/, sorteret efter filnavn.
static func level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var names := DirAccess.get_files_at(LEVEL_DIR)
	names.sort()
	for name in names:
		# Godot omdøber til .json.remap i eksporterede spil.
		var clean := name.trim_suffix(".remap")
		if clean.ends_with(".json"):
			paths.append("%s/%s" % [LEVEL_DIR, clean])
	return paths


## Returnerer {"ok": bool, "data": Dictionary, "errors": PackedStringArray}.
static func load_level(path: String) -> Dictionary:
	var errors := PackedStringArray()
	if not FileAccess.file_exists(path):
		errors.append("filen findes ikke: %s" % path)
		return {"ok": false, "data": {}, "errors": errors}

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s er ikke gyldig JSON" % path)
		return {"ok": false, "data": {}, "errors": errors}

	var data: Dictionary = parsed
	data["path"] = path
	errors = validate(data)
	return {"ok": errors.is_empty(), "data": data, "errors": errors}


static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()

	if not data.has("grid") or typeof(data["grid"]) != TYPE_ARRAY:
		errors.append("mangler grid")
		return errors

	var grid: Array = data["grid"]
	if grid.size() > MAX_ROWS:
		errors.append("%d rækker, maks er %d" % [grid.size(), MAX_ROWS])
	if grid.is_empty():
		errors.append("gridet er tomt")

	var breakable := 0
	for i in grid.size():
		var row: String = str(grid[i])
		if row.length() != GRID_COLUMNS:
			errors.append("række %d har %d tegn, skal have %d" % [i + 1, row.length(), GRID_COLUMNS])
		for c in row:
			if c == ".":
				continue
			if not Brick.SYMBOLS.has(c):
				errors.append("ukendt tegn '%s' i række %d" % [c, i + 1])
				continue
			var type: int = Brick.SYMBOLS[c]
			if Brick.DATA[type]["hits"] > 0:
				breakable += 1

	if not grid.is_empty():
		var last: String = str(grid[grid.size() - 1])
		if last.contains("S"):
			errors.append("Sten i nederste række")

	if breakable < MIN_BREAKABLE:
		errors.append("kun %d smadrelige klodser, mindst %d kræves" % [breakable, MIN_BREAKABLE])

	var powerups: Dictionary = data.get("powerups", {})
	var sum := 0.0
	for key in powerups:
		if not Powerup.CATALOG.has(key):
			errors.append("ukendt power-up '%s'" % key)
		sum += float(powerups[key])
	if not powerups.is_empty() and absf(sum - 100.0) > 0.001:
		errors.append("power-up-procenter summerer til %.1f, ikke 100" % sum)

	var forced: Variant = data.get("forcedFirstPowerup", null)
	if forced != null and not Powerup.CATALOG.has(str(forced)):
		errors.append("forcedFirstPowerup '%s' findes ikke" % str(forced))

	return errors


## Antal klodser, der tæller mod level clear.
static func breakable_count(grid: Array) -> int:
	var n := 0
	for row in grid:
		for c in str(row):
			if c != "." and Brick.SYMBOLS.has(c) and Brick.DATA[Brick.SYMBOLS[c]]["hits"] > 0:
				n += 1
	return n
