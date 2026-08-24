class_name LevelLoader
extends RefCounted

## Level data from JSON, validated against the rules in section 11.
##
## The validation is not decoration. A level with 12 characters in a row,
## or power-up percentages that do not sum to 100, is a fault that only
## shows up as strange behaviour in the middle of a game. Better to catch
## it at load time.

const GRID_COLUMNS := 13
const MAX_ROWS := 12
const MIN_BREAKABLE := 20
const LEVEL_DIR := "res://levels"


## Every level file in levels/, sorted by filename.
static func level_paths() -> PackedStringArray:
	var paths := PackedStringArray()
	var names := DirAccess.get_files_at(LEVEL_DIR)
	names.sort()
	for name in names:
		# Godot renames to .json.remap in exported builds.
		var clean := name.trim_suffix(".remap")
		if clean.ends_with(".json"):
			paths.append("%s/%s" % [LEVEL_DIR, clean])
	return paths


## Returns {"ok": bool, "data": Dictionary, "errors": PackedStringArray}.
static func load_level(path: String) -> Dictionary:
	var errors := PackedStringArray()
	if not FileAccess.file_exists(path):
		errors.append("file not found: %s" % path)
		return {"ok": false, "data": {}, "errors": errors}

	var text := FileAccess.get_file_as_string(path)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		errors.append("%s is not valid JSON" % path)
		return {"ok": false, "data": {}, "errors": errors}

	var data: Dictionary = parsed
	data["path"] = path
	errors = validate(data)
	return {"ok": errors.is_empty(), "data": data, "errors": errors}


static func validate(data: Dictionary) -> PackedStringArray:
	var errors := PackedStringArray()

	if not data.has("grid") or typeof(data["grid"]) != TYPE_ARRAY:
		errors.append("grid is missing")
		return errors

	var grid: Array = data["grid"]
	if grid.size() > MAX_ROWS:
		errors.append("%d rows, the maximum is %d" % [grid.size(), MAX_ROWS])
	if grid.is_empty():
		errors.append("the grid is empty")

	var breakable := 0
	for i in grid.size():
		var row: String = str(grid[i])
		if row.length() != GRID_COLUMNS:
			errors.append("row %d has %d characters, it needs %d" % [i + 1, row.length(), GRID_COLUMNS])
		for c in row:
			if c == ".":
				continue
			if not Brick.SYMBOLS.has(c):
				errors.append("unknown symbol '%s' in row %d" % [c, i + 1])
				continue
			var type: int = Brick.SYMBOLS[c]
			if Brick.DATA[type]["hits"] > 0:
				breakable += 1

	if not grid.is_empty():
		var last: String = str(grid[grid.size() - 1])
		if last.contains("S"):
			errors.append("Stone in the bottom row")

	if breakable < MIN_BREAKABLE:
		errors.append("only %d breakable bricks, at least %d are required" % [breakable, MIN_BREAKABLE])

	var powerups: Dictionary = data.get("powerups", {})
	var sum := 0.0
	for key in powerups:
		if not Powerup.CATALOG.has(key):
			errors.append("unknown power-up '%s'" % key)
		sum += float(powerups[key])
	if not powerups.is_empty() and absf(sum - 100.0) > 0.001:
		errors.append("power-up percentages sum to %.1f, not 100" % sum)

	var forced: Variant = data.get("forcedFirstPowerup", null)
	if forced != null and not Powerup.CATALOG.has(str(forced)):
		errors.append("forcedFirstPowerup '%s' does not exist" % str(forced))

	return errors


## Number of bricks that count toward clearing the field.
static func breakable_count(grid: Array) -> int:
	var n := 0
	for row in grid:
		for c in str(row):
			if c != "." and Brick.SYMBOLS.has(c) and Brick.DATA[Brick.SYMBOLS[c]]["hits"] > 0:
				n += 1
	return n
