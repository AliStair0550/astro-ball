extends Node

## Mechanics without waiting: the grid, the bricks, level validation,
## the power-up rules and the ball sweep. Time is driven by hand.

var fails := 0
var checks := 0


func _ready() -> void:
	seed(4242)
	_test_level_validation()
	_test_broken_levels()
	_test_geometry()
	_test_grid_counts()
	_test_hardened()
	_test_blast_chain()
	_test_hidden_reveal()
	_test_glass_and_stone()
	_test_zap()
	_test_clear_pops_stones()
	_test_sweep_vs_brick()
	_test_powerup_rules()
	_test_paddle_states()
	for child in get_children():
		child.free()
	print("--- MECHANICS: %d checks, %d failures ---" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("  FAIL: %s" % label)


func eq(got: Variant, want: Variant, label: String) -> void:
	checks += 1
	if got != want:
		fails += 1
		print("  FAIL: %s (got %s, wanted %s)" % [label, str(got), str(want)])


func _test_level_validation() -> void:
	var paths := LevelLoader.level_paths()
	eq(paths.size(), 3, "three level files exist")
	for path in paths:
		var result := LevelLoader.load_level(path)
		ok(result["ok"], "%s validates: %s" % [path, ", ".join(result["errors"])])
	var one: Dictionary = LevelLoader.load_level("res://levels/level_01.json")["data"]
	eq(LevelLoader.breakable_count(one["grid"]), 47, "level 1 has 47 bricks")
	eq(str(one["forcedFirstPowerup"]), "wide", "level 1 forces Wide first")
	# Slow belongs where it gets hard, not in the opening fields.
	for path in paths:
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		ok(not data.get("powerups", {}).has("slow"), "%s has no Slow" % path)


func _test_broken_levels() -> void:
	var base := {
		"grid": [".VVVVVVVVVVV.", ".VVVVVVVVVVV."],
		"powerups": {"wide": 100},
	}
	ok(LevelLoader.validate(base).is_empty(), "a valid test level produces no errors")

	var short_row := base.duplicate(true)
	short_row["grid"][0] = ".VVVVVVVVVV."
	ok(not LevelLoader.validate(short_row).is_empty(), "a 12 character row is rejected")

	var too_tall := base.duplicate(true)
	too_tall["grid"] = []
	for i in 13:
		too_tall["grid"].append(".VVVVVVVVVVV.")
	ok(not LevelLoader.validate(too_tall).is_empty(), "13 rows are rejected")

	var stone_bottom := base.duplicate(true)
	stone_bottom["grid"][1] = ".VVVVVSVVVVV."
	ok(not LevelLoader.validate(stone_bottom).is_empty(), "Stone in the bottom row is rejected")

	var too_few := base.duplicate(true)
	too_few["grid"] = [".VVVVV.......", "............."]
	ok(not LevelLoader.validate(too_few).is_empty(), "fewer than 20 bricks is rejected")

	var bad_sum := base.duplicate(true)
	bad_sum["powerups"] = {"wide": 40, "multi": 40}
	ok(not LevelLoader.validate(bad_sum).is_empty(), "a power-up sum below 100 is rejected")

	var bad_symbol := base.duplicate(true)
	bad_symbol["grid"][0] = ".VVVVZVVVVVV."
	ok(not LevelLoader.validate(bad_symbol).is_empty(), "an unknown symbol is rejected")

	var bad_powerup := base.duplicate(true)
	bad_powerup["powerups"] = {"tidsmaskine": 100}
	ok(not LevelLoader.validate(bad_powerup).is_empty(), "an unknown power-up is rejected")


func _test_geometry() -> void:
	var left := BrickGrid.ORIGIN_X
	var right := BrickGrid.ORIGIN_X + 12.0 * BrickGrid.PITCH.x + Brick.SIZE.x
	var inner := Rect2(Arena.WALL, Arena.HUD_HEIGHT + Arena.WALL,
		Arena.SCREEN.x - Arena.WALL * 2.0, Arena.SCREEN.y - Arena.HUD_HEIGHT - Arena.WALL)
	ok(left > inner.position.x, "the grid starts inside the field (%.1f > %.1f)" % [left, inner.position.x])
	ok(right < inner.end.x, "the grid ends inside the field (%.1f < %.1f)" % [right, inner.end.x])
	eq(Brick.SIZE, Vector2(24.0, 16.0), "the brick is 24x16")
	eq(BrickGrid.SPACING, 2.0, "2 px between bricks")
	ok(Arena.HUD_HEIGHT >= 120.0, "the HUD fills the top (%.0f px)" % Arena.HUD_HEIGHT)

	# The wall hangs from a short, fixed sky, and the 57 per cent line is
	# the guard that stops a deep wall from reaching the paddle. Section
	# 20 anchored from the bottom alone, which left a shallow level with
	# more dead sky above it than fall zone below.
	var field_top := BrickGrid.field_top()
	var expected_line := field_top + 0.57 * (Arena.SCREEN.y - field_top)
	ok(absf(BrickGrid.wall_line_y() - expected_line) < 0.01,
		"the wall line guard is at %.2f" % BrickGrid.wall_line_y())
	ok(Arena.HUD_HEIGHT >= 180.0,
		"the HUD carries the space the sky gave up (%.0f px)" % Arena.HUD_HEIGHT)

	var paddle_top := Arena.SCREEN.y - 64.0 - Paddle.HEIGHT * 0.5
	for row_count in range(1, 13):
		var grid: Array = []
		for i in row_count:
			grid.append(".VVVVVVVVVVV.")
		var top := BrickGrid.origin_for(grid)
		var bottom := top + BrickGrid.wall_height(grid)
		var sky := BrickGrid.sky_for(grid)
		ok(absf(sky - BrickGrid.SKY) < 0.01,
			"%d rows leave exactly the sky we asked for (%.1f)" % [row_count, sky])
		ok(sky >= BrickGrid.MIN_SKY,
			"%d rows clear the minimum sky" % row_count)
		ok(bottom <= BrickGrid.wall_line_y() + 0.01,
			"%d rows stay above the wall line guard (%.1f)" % [row_count, bottom])
		ok(paddle_top - bottom > 200.0,
			"%d rows leave the ball room to fall (%.1f px)" % [row_count, paddle_top - bottom])
		var fall := Arena.SCREEN.y - bottom
		ok(fall / Ball.BASE_SPEED > 0.8,
			"%d rows leave at least eight tenths of a second (%.2f s)"
				% [row_count, fall / Ball.BASE_SPEED])

	# The sky never collapses even for a wall deep enough that the guard
	# would bind, which is the case section 20 was actually protecting.
	var deep: Array = []
	for i in 12:
		deep.append(".VVVVVVVVVVV.")
	ok(BrickGrid.origin_for(deep) + BrickGrid.wall_height(deep) <= BrickGrid.wall_line_y() + 0.01,
		"the deepest legal wall still clears the guard")

	# An empty trailing row must not lift the wall off its sky.
	var padded: Array = [".VVVVVVVVVVV.", ".VVVVVVVVVVV.", "............."]
	eq(BrickGrid.last_brick_row(padded), 1, "the lowest brick row ignores empty rows below it")
	ok(absf(BrickGrid.sky_for(padded) - BrickGrid.SKY) < 0.01,
		"a trailing empty row still leaves the same sky")

	# gridAnchor moves the wall down.
	ok(absf(BrickGrid.origin_for(padded, 40.0) - BrickGrid.origin_for(padded) - 40.0) < 0.01,
		"a positive gridAnchor pushes the wall down")

	# bottom_y() is the underside of the lowest row, not one spacing below.
	var g := _make_grid([".VVVVVVVVVVV.", ".VVVVVVVVVVV."])
	ok(absf(g.bottom_y() - (BrickGrid.origin_for([".VVVVVVVVVVV.", ".VVVVVVVVVVV."])
		+ BrickGrid.PITCH.y + Brick.SIZE.y)) < 0.01,
		"bottom_y is the underside of the lowest row (%.2f)" % g.bottom_y())
	g.queue_free()

	# And the shipped levels must land where the rule says.
	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		var rows_data: Array = data["grid"]
		var anchor := LevelLoader.anchor_of(data)
		var low := BrickGrid.origin_for(rows_data, anchor) + BrickGrid.wall_height(rows_data)
		ok(low <= BrickGrid.wall_line_y() + 0.01, "%s stays above the guard" % path)
		ok(BrickGrid.sky_for(rows_data, anchor) >= BrickGrid.MIN_SKY,
			"%s keeps its sky" % path)


func _make_grid(rows: Array) -> BrickGrid:
	var g := BrickGrid.new()
	add_child(g)
	g.build(rows)
	return g


func _pump(g: BrickGrid, seconds: float) -> void:
	var step := 1.0 / 60.0
	var t := 0.0
	while t < seconds:
		g._process(step)
		t += step


func _test_grid_counts() -> void:
	var data: Dictionary = LevelLoader.load_level("res://levels/level_02.json")["data"]
	var g := _make_grid(data["grid"])
	eq(g.rows, 10, "level 2 has 10 rows")
	eq(g.remaining_breakable(), 68, "level 2 has 68 breakable bricks")
	ok(g.brick_at(1, 0) != null and g.brick_at(1, 0).type == Brick.Type.STONE, "Stone in the corner")
	ok(not g.brick_at(1, 0).counts_toward_clear(), "Stone does not count toward clearing")
	g.queue_free()


func _test_hardened() -> void:
	var g := _make_grid([".HHHHHHHHHHH.", ".VVVVVVVVVVV."])
	var h := g.brick_at(1, 0)
	eq(h.hits_left, 3, "Hardened takes 3 hits")
	eq(h.damage_stage(), 0, "undamaged Hardened is stage 0")
	ok(not g.hit(h), "the first hit does not break it")
	eq(h.damage_stage(), 1, "after one hit it is stage 1")
	ok(not g.hit(h), "the second hit does not break it")
	eq(h.damage_stage(), 2, "after two hits it is stage 2")
	ok(g.hit(h), "the third hit breaks it")
	ok(not h.alive, "Hardened is gone")
	eq(h.score_value(), 300, "Hardened scores triple")
	g.queue_free()


func _test_blast_chain() -> void:
	var g := _make_grid([".VVV.........", ".VEV.........", ".VVV........."])
	eq(g.remaining_breakable(), 9, "nine bricks before")
	var blast := g.brick_at(2, 1)
	eq(blast.type, Brick.Type.BLAST, "the middle brick is a blast brick")
	ok(g.hit(blast), "the blast brick breaks")
	_pump(g, 0.05)
	ok(g.remaining_breakable() > 0, "the chain is not finished after 50 ms")
	_pump(g, 0.5)
	eq(g.remaining_breakable(), 0, "all 8 neighbours were taken by the chain")
	g.queue_free()

	# A blast brick two cells away is not a neighbour and must NOT fire.
	var g_far := _make_grid([".VVVVV.......", ".VEVEV.......", ".VVVVV......."])
	ok(g_far.hit(g_far.brick_at(2, 1)), "the blast brick breaks")
	_pump(g_far, 1.0)
	ok(g_far.brick_at(4, 1).alive, "a blast brick two cells away does not go off")
	eq(g_far.remaining_breakable(), 6, "only the 8 neighbours went")
	g_far.queue_free()

	# Chain reaction: a neighbouring blast fires its own ring.
	var g2 := _make_grid([".VVVV........", ".VEEV........", ".VVVV........"])
	eq(g2.remaining_breakable(), 12, "twelve bricks before the chain")
	ok(g2.hit(g2.brick_at(2, 1)), "the first blast brick breaks")
	_pump(g2, 1.5)
	eq(g2.remaining_breakable(), 0, "the chain continued through the neighbouring blast")
	g2.queue_free()


func _test_hidden_reveal() -> void:
	var g := _make_grid([".V?..........", ".VV.........."])
	var hidden := g.brick_at(2, 0)
	eq(hidden.type, Brick.Type.HIDDEN, "the hidden brick loaded")
	ok(not hidden.revealed, "the hidden brick starts hidden")
	ok(not g.bricks_in(hidden.rect.grow(2.0)).has(hidden), "the hidden brick cannot be hit")
	g.hit(g.brick_at(1, 0))
	ok(hidden.revealed, "the hidden brick shows when its neighbour breaks")
	ok(g.bricks_in(hidden.rect.grow(2.0)).has(hidden), "a revealed brick can now be hit")
	g.queue_free()


func _test_glass_and_stone() -> void:
	var g := _make_grid([".GS..........", ".VV.........."])
	var glass := g.brick_at(1, 0)
	var stone := g.brick_at(2, 0)
	ok(glass.lets_ball_pass(), "Glass lets the ball through")
	eq(glass.shard_count(), 12, "Glass shatters into 12 shards")
	ok(g.hit(glass), "Glass breaks all the same")
	ok(not stone.is_breakable(), "Stone cannot be broken")
	ok(not g.hit(stone), "a hit on Stone does nothing")
	ok(stone.alive, "Stone is still standing")
	g.queue_free()


func _test_zap() -> void:
	var g := _make_grid([".VVVVV.......", ".VVVVV......."])
	g.zap_neighbours(g.brick_at(3, 0))
	_pump(g, 0.2)
	ok(not g.brick_at(2, 0).alive, "Zap took the neighbour to the left")
	ok(not g.brick_at(4, 0).alive, "Zap took the neighbour to the right")
	ok(g.brick_at(3, 1).alive, "Zap did not take the brick below")
	g.queue_free()


func _test_clear_pops_stones() -> void:
	var g := _make_grid([".S.V.......S.", "............."])
	var cleared := [false]
	g.cleared.connect(func(): cleared[0] = true)
	var popped := [0]
	g.stone_popped.connect(func(_b): popped[0] += 1)
	g.hit(g.brick_at(3, 0))
	ok(cleared[0], "clearing fires when the breakables are gone")
	_pump(g, 1.0)
	eq(popped[0], 2, "both Stone cores go off in sequence")
	g.queue_free()


func _test_sweep_vs_brick() -> void:
	var rect := Rect2(100.0, 100.0, 24.0, 16.0)
	var from_below := Ball._sweep_circle_rect(Vector2(112.0, 130.0), Vector2(0.0, -20.0), 4.0, rect)
	ok(from_below["hit"], "the sweep hits the underside")
	ok(from_below["normal"].is_equal_approx(Vector2(0.0, 1.0)), "the normal points down")
	ok(absf(float(from_below["t"]) - 0.5) < 0.01, "contact halfway (t=%.3f)" % from_below["t"])
	var from_side := Ball._sweep_circle_rect(Vector2(80.0, 108.0), Vector2(30.0, 0.0), 4.0, rect)
	ok(from_side["hit"], "the sweep hits the left side")
	ok(from_side["normal"].is_equal_approx(Vector2(-1.0, 0.0)), "the normal points left")
	var miss := Ball._sweep_circle_rect(Vector2(200.0, 108.0), Vector2(0.0, 30.0), 4.0, rect)
	ok(not miss["hit"], "a sweep past the brick does not hit")


func _test_powerup_rules() -> void:
	var pm := PowerupManager.new()
	add_child(pm)
	var paddle := Paddle.new()
	paddle.position = Vector2(195.0, 780.0)
	add_child(paddle)
	pm.paddle = paddle
	pm.configure(LevelLoader.load_level("res://levels/level_01.json")["data"])

	eq(pm._pick_id(), "wide", "level 1 forces Wide as the first power-up")
	pm.spawn(Vector2(195.0, 300.0))
	pm.spawn(Vector2(180.0, 300.0))
	pm.spawn(Vector2(160.0, 300.0))
	eq(pm._capsules.size(), 2, "at most 2 capsules on screen")

	pm.configure(LevelLoader.load_level("res://levels/level_03.json")["data"])
	var bad_in_a_row := 0
	var worst := 0
	for i in 400:
		pm.reset_level()
		pm._last_was_bad = true
		if not Powerup.is_good(pm._pick_id()):
			bad_in_a_row += 1
	eq(bad_in_a_row, 0, "a bad one is never followed by a bad one")

	for i in 200:
		pm.reset_level()
		pm.guarantee_good()
		if not Powerup.is_good(pm._pick_id()):
			worst += 1
	eq(worst, 0, "after a lost ball the next power-up is good")

	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		for id in data.get("powerups", {}):
			ok(Powerup.CATALOG.has(str(id)), "%s knows power-up '%s'" % [path, str(id)])

	eq(Brick.DATA[Brick.Type.SPARK]["powerup"], 1.0, "Spark guarantees a power-up")

	# The distribution must follow the table, or a power-up is dead in
	pm.configure(LevelLoader.load_level("res://levels/level_01.json")["data"])
	var counts := {}
	for i in 4000:
		pm.reset_level()
		pm._first_spawned = true
		var id := pm._pick_id()
		counts[id] = int(counts.get(id, 0)) + 1
	for id in ["multi", "fireball", "laser", "wide"]:
		var share := 100.0 * float(counts.get(id, 0)) / 4000.0
		var want := float(pm.table[id])
		ok(absf(share - want) < 3.0,
			"level 1 draws %s %.1f %% against the table %.0f %%" % [id, share, want])
	pm.queue_free()
	paddle.queue_free()


func _test_paddle_states() -> void:
	var p := Paddle.new()
	add_child(p)
	p.position = Vector2(195.0, 780.0)
	p.set_bounds(6.0, 384.0)

	p.set_width(Paddle.WIDTH_NORMAL)
	eq(p.segment_count(), 3, "the normal paddle has three segments")
	eq(p.sweet_offsets().size(), 1, "the normal paddle has one sweet spot")
	ok(p.is_sweet(0.0) and p.is_sweet(3.9) and not p.is_sweet(5.0), "the sweet spot is 8 px wide")

	p.set_width(Paddle.WIDTH_WIDE)
	eq(p.segment_count(), 5, "the wide paddle has five segments")
	eq(p.sweet_offsets().size(), 2, "the wide paddle has two sweet spots")
	eq(p.width, 132.0, "the wide paddle is 132 px")
	eq(p._seam_positions().size(), 4, "five segments give four seams")

	p.set_width(Paddle.WIDTH_NARROW)
	eq(p.segment_count(), 1, "the narrow paddle has one segment")
	ok(not p.has_sweet_spot(), "the narrow paddle has no sweet spot")
	ok(not p.is_sweet(0.0), "the narrow paddle never gives a sweet spot")
	eq(p._seam_positions().size(), 0, "one segment has no seams")

	p.set_width(Paddle.WIDTH_WIDE)
	ok(p.min_x >= 6.0 + 66.0 - 0.01 and p.max_x <= 384.0 - 66.0 + 0.01, "the wide paddle stays inside the field")
	p.queue_free()
