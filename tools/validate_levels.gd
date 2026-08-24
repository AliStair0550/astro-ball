extends SceneTree

## Validates every level in levels/ and exits non-zero if any of them
## fails. Meant for the test run and for CI, where nothing is watching
## the console.
##
##     godot --headless --path . --script tools/validate_levels.gd
##
## The rules live in scripts/level_loader.gd, section 11 of the design
## document, plus the sky and paddle-lane checks from section 20. This
## is only the runner.

func _initialize() -> void:
	var paths := LevelLoader.level_paths()
	var failures := 0

	if paths.is_empty():
		printerr("validate_levels: no level files found in %s" % LevelLoader.LEVEL_DIR)
		quit(1)
		return

	for path in paths:
		var result := LevelLoader.load_level(path)
		var data: Dictionary = result["data"]
		var id := int(data.get("id", 0))
		var name := str(data.get("name", "?"))
		if result["ok"]:
			var grid: Array = data.get("grid", [])
			var anchor := LevelLoader.anchor_of(data)
			print("  ok   level %d %-14s %2d rows, %3d bricks, sky %3.0f px, wall line %.0f"
				% [id, name, grid.size(), LevelLoader.breakable_count(grid),
					BrickGrid.sky_for(grid, anchor),
					BrickGrid.origin_for(grid, anchor)
						+ float(BrickGrid.last_brick_row(grid)) * BrickGrid.PITCH.y + Brick.SIZE.y])
		else:
			failures += 1
			for error in result["errors"]:
				printerr("  FAIL level %d (%s): %s" % [id, path, error])

	if failures > 0:
		printerr("validate_levels: %d of %d levels failed" % [failures, paths.size()])
		quit(1)
		return
	print("validate_levels: %d levels, all valid" % paths.size())
	quit(0)
