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


## gridAnchor read safely. float(null) throws, and a throw inside
## validate() hands the caller an empty error list, so a broken level
## comes back clean. An explicit null is this project's own idiom for an
## absent optional field, so it has to be survivable.
static func anchor_of(data: Dictionary) -> float:
	var raw: Variant = data.get("gridAnchor", 0)
	if raw == null:
		return 0.0
	if typeof(raw) != TYPE_INT and typeof(raw) != TYPE_FLOAT:
		return 0.0
	return float(raw)


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
		# The row closest to the paddle, which is not the last array row
		# when a level pads itself with blank rows. Placement already
		# uses last_brick_row; the rule has to look at the same row.
		var last: String = str(grid[BrickGrid.last_brick_row(grid)])
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

	# Section 20: gridAnchor is a px offset from the default wall line.
	# A negative one lifts the wall, and lifting it too far eats the sky
	# the ball needs to get up behind the wall.
	var raw_anchor: Variant = data.get("gridAnchor", 0)
	if raw_anchor != null and typeof(raw_anchor) != TYPE_INT and typeof(raw_anchor) != TYPE_FLOAT:
		errors.append("gridAnchor must be a number, not %s" % type_string(typeof(raw_anchor)))
	var anchor := anchor_of(data)
	var sky := BrickGrid.sky_for(grid, anchor)
	if sky < BrickGrid.MIN_SKY:
		errors.append("gridAnchor %.0f leaves %.0f px of sky, the minimum is %.0f"
			% [anchor, sky, BrickGrid.MIN_SKY])
	# The 57 per cent line is the guard: no wall's underside may cross it,
	# whatever the anchor asks for. That is what keeps the fall zone long
	# enough to react in, on every level.
	var bottom := BrickGrid.origin_for(grid, anchor) + BrickGrid.wall_height(grid)
	if bottom > BrickGrid.wall_line_y() + 0.01:
		errors.append("gridAnchor %.0f puts the lowest row at y %.0f, past the wall line at %.0f"
			% [anchor, bottom, BrickGrid.wall_line_y()])

	errors.append_array(mosaic_errors(grid))

	var forced: Variant = data.get("forcedFirstPowerup", null)
	if forced != null and not Powerup.CATALOG.has(str(forced)):
		errors.append("forcedFirstPowerup '%s' does not exist" % str(forced))

	return errors


## Section 20's mosaic rule. A wall has to be read at a glance, and a
## field of one colour is a field with nothing to read.
##
##   At least three of the four one-hit colours.
##   No more than two rows in a row made of a single colour.
##
## Pulse's placement is a design rule rather than a validation one: it is
## worth double, so it belongs in from the edge, and that is checked in
## the tests where the intent can be written down.
const MOSAIC_COLOURS := ["V", "I", "P", "F"]
const MOSAIC_MIN_COLOURS := 3
const MOSAIC_MAX_SAME_ROWS := 2


static func mosaic_errors(grid: Array) -> PackedStringArray:
	var errors := PackedStringArray()
	var seen := {}
	var run := 0
	var last := ""
	for i in grid.size():
		var row: String = str(grid[i])
		var colours := {}
		for c in row:
			if c in MOSAIC_COLOURS:
				colours[c] = true
				seen[c] = true
		if colours.size() == 1:
			var only: String = colours.keys()[0]
			run = run + 1 if only == last else 1
			last = only
			if run > MOSAIC_MAX_SAME_ROWS:
				errors.append("rows %d to %d are all '%s': at most %d in a row"
					% [i + 2 - run, i + 1, only, MOSAIC_MAX_SAME_ROWS])
		else:
			run = 0
			last = ""
	if not grid.is_empty() and seen.size() < MOSAIC_MIN_COLOURS:
		errors.append("the wall uses %d of the one-hit colours, the minimum is %d"
			% [seen.size(), MOSAIC_MIN_COLOURS])
	return errors


## Number of bricks that count toward clearing the field.
static func breakable_count(grid: Array) -> int:
	var n := 0
	for row in grid:
		for c in str(row):
			if c != "." and Brick.SYMBOLS.has(c) and Brick.DATA[Brick.SYMBOLS[c]]["hits"] > 0:
				n += 1
	return n
