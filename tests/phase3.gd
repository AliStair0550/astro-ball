extends Node

## Phase 3: the level system, the power-up rules, stars and progress,
## the quiet helper, Giant, and the strings file.

var fails := 0
var checks := 0
var grid: BrickGrid
var progress: Node


func _ready() -> void:
	seed(90210)
	progress = get_node("/root/GameProgress")
	grid = BrickGrid.new()
	add_child(grid)

	_test_strings()
	_test_loader_fixtures()
	_test_grid_anchor()
	_test_level_state()
	_test_stars()
	_test_progress_roundtrip()
	_test_silent_helper()
	_test_powerup_timers()
	_test_giant()

	print("--- PHASE 3: %d checks, %d failures ---" % [checks, fails])
	for child in get_children():
		child.free()
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


func about(got: float, want: float, tol: float, label: String) -> void:
	checks += 1
	if absf(got - want) > tol:
		fails += 1
		print("  FAIL: %s (got %.3f, wanted %.3f)" % [label, got, want])


# --- Section 14, strings ------------------------------------------------

func _test_strings() -> void:
	for key in Strings.keys():
		var value := Strings.text(str(key))
		ok(not value.is_empty(), "the string '%s' is not empty" % str(key))
		ok(not value.contains(Strings.MISSING), "the string '%s' resolves" % str(key))

	# Section 14: the official names.
	eq(Strings.zone_name("baeltet"), "THE DRIFT", "the zone is called The Drift")
	eq(Strings.universe_index("baeltet"), 1, "The Drift is universe 1")
	eq(Strings.universe_line("baeltet"), "UNIVERSE 1 · THE DRIFT",
		"and it is presented as a universe")
	eq(Strings.universe_short("baeltet"), "UNIVERSE 1", "the short form for the HUD")
	eq(Strings.fmt("LEVEL_NUMBER", [1]), "LEVEL 1", "the level intro line")
	eq(Strings.text("SIGNAL_LOST"), "SIGNAL LOST", "section 16 names the death screen")
	eq(Strings.text("FIELD_CLEARED"), "FIELD CLEARED", "section 14 tone, no exclamation")

	# Tone, section 14: telemetry, never an exclamation mark.
	for key in Strings.keys():
		ok(not Strings.text(str(key)).contains("!"), "'%s' carries no exclamation mark" % str(key))

	# Every power-up in the catalog can be named to the player.
	for id in Powerup.CATALOG:
		var name := Strings.powerup_name(str(id))
		ok(not name.is_empty() and not name.contains(Strings.MISSING),
			"power-up '%s' has a player-facing name" % str(id))

	# An unknown key is loud on screen, not silently blank. Asserted
	# through has() so the test does not print the error it is checking.
	ok(not Strings.has("NO_SUCH_KEY"), "an unknown key is reported as missing")
	ok(Strings.has("SIGNAL_LOST"), "and a real one is not")


# --- Section 11, the loader ---------------------------------------------

func _base_level() -> Dictionary:
	var grid_rows: Array = []
	for i in 3:
		grid_rows.append(".VVVVVVVVVVV.")
	return {"id": 99, "name": "Fixture", "zone": "baeltet", "grid": grid_rows,
		"powerups": {"wide": 100}, "parTime": 60}


func _test_loader_fixtures() -> void:
	ok(LevelLoader.validate(_base_level()).is_empty(), "the fixture is valid to begin with")

	var narrow := _base_level()
	narrow["grid"][0] = ".VVVVVVVVVV."
	ok(not LevelLoader.validate(narrow).is_empty(), "a 12 character row is rejected")

	var stone := _base_level()
	stone["grid"][2] = ".VVVVVSVVVVV."
	ok(not LevelLoader.validate(stone).is_empty(), "Stone in the bottom row is rejected")

	var ninetynine := _base_level()
	ninetynine["powerups"] = {"wide": 60, "multi": 39}
	var errors := LevelLoader.validate(ninetynine)
	ok(not errors.is_empty(), "percentages summing to 99 are rejected")
	var mentions_sum := false
	for e in errors:
		if str(e).contains("99"):
			mentions_sum = true
	ok(mentions_sum, "and the error names the sum it found")

	var too_tall := _base_level()
	too_tall["grid"] = []
	for i in 13:
		too_tall["grid"].append(".VVVVVVVVVVV.")
	ok(not LevelLoader.validate(too_tall).is_empty(), "13 rows are rejected")

	var thin := _base_level()
	thin["grid"] = [".VVVVV.......", "............."]
	ok(not LevelLoader.validate(thin).is_empty(), "fewer than 20 bricks is rejected")

	# Every shipped level still passes, and level 1 is the section 9 grid.
	for path in LevelLoader.level_paths():
		var result := LevelLoader.load_level(path)
		ok(result["ok"], "%s validates: %s" % [path, ", ".join(result["errors"])])
	var one: Dictionary = LevelLoader.load_level("res://levels/level_01.json")["data"]
	eq(str(one["name"]), "Liftoff", "level 1 is Liftoff")
	eq(str(one["zone"]), "baeltet", "the zone slug in the data stays baeltet")
	eq(str(one["forcedFirstPowerup"]), "wide", "level 1 forces Wide first")
	eq(int(one["parTime"]), 60, "level 1 par time is 60")
	eq(LevelLoader.breakable_count(one["grid"]), 47, "level 1 has 47 bricks")
	# The first fields teach the chain before they teach patience:
	# blast bricks early, and no Hardened at all.
	for path in LevelLoader.level_paths():
		var d: Dictionary = LevelLoader.load_level(path)["data"]
		var joined := "".join(PackedStringArray(d["grid"]))
		ok(joined.contains("E"), "%s has blast bricks" % path)
		ok(not joined.contains("H"), "%s has no Hardened yet" % path)

	# Section 9: no bad drops in level 1.
	for id in one["powerups"]:
		ok(Powerup.is_good(str(id)), "level 1 drop '%s' is a good one" % str(id))
	ok(one["powerups"].has("giant"), "level 1 can drop Giant")


# --- Section 20, the bottom anchor --------------------------------------

func _test_grid_anchor() -> void:
	var rows: Array = [".VVVVVVVVVVV.", ".VVVVVVVVVVV."]
	var base := BrickGrid.origin_for(rows, 0.0)
	about(BrickGrid.origin_for(rows, 30.0) - base, 30.0, 0.01,
		"a positive gridAnchor pushes the wall down")
	about(BrickGrid.origin_for(rows, -30.0) - base, -30.0, 0.01,
		"a negative gridAnchor lifts it")

	# An anchor that eats the sky is refused by the loader.
	var lifted := _base_level()
	lifted["gridAnchor"] = -400
	ok(not LevelLoader.validate(lifted).is_empty(), "an anchor that eats the sky is rejected")

	# And so is one that reaches the paddle lane.
	var dropped := _base_level()
	dropped["gridAnchor"] = 300
	ok(not LevelLoader.validate(dropped).is_empty(), "an anchor that reaches the paddle is rejected")

	# A modest anchor is fine.
	var nudged := _base_level()
	nudged["gridAnchor"] = 20
	ok(LevelLoader.validate(nudged).is_empty(), "a modest anchor is accepted")

	# The grid actually builds where the rule says.
	grid.build(rows, 0.0)
	about(grid.bottom_y(), BrickGrid.origin_for(rows) + BrickGrid.wall_height(rows), 0.01,
		"the built grid sits where the rule puts it")
	about(BrickGrid.sky_for(rows), BrickGrid.SKY, 0.01, "with the sky the rule asks for")
	grid.build(rows, 25.0)
	about(grid.bottom_y(), BrickGrid.origin_for(rows) + BrickGrid.wall_height(rows) + 25.0, 0.01,
		"and follows the anchor")
	# Collision must follow the grid, not a stale constant.
	var brick := grid.brick_at(1, 1)
	ok(brick != null and grid.bricks_in(brick.rect).has(brick),
		"the broad phase finds a brick at the anchored position")


# --- Level state ---------------------------------------------------------

func _test_level_state() -> void:
	var s := LevelState.new()
	s.start_run()
	eq(s.lives, 3, "a run starts with three lives")
	eq(s.score, 0, "and no score")

	eq(s.combo_multiplier(), 1, "combo below 5 is x1")
	for i in 5:
		s.on_brick_destroyed(100)
	eq(s.combo, 5, "five bricks make a combo of five")
	eq(s.combo_multiplier(), 2, "combo 5 is x2")
	eq(s.run_bricks, 5, "the run counts them")
	eq(s.level_bricks, 5, "so does the level")

	s.on_paddle_hit()
	eq(s.combo, 0, "the combo resets on paddle contact")
	eq(s.best_combo, 5, "but the best is remembered")

	var before := s.score
	var points := s.on_brick_destroyed(200)
	eq(points, 200, "a Pulse brick at combo 1 scores double the base")
	eq(s.score, before + 200, "and the score follows")

	# RESTART FIELD rolls the level back but not the run.
	s.level_start_score = 1000
	s.score = 4000
	s.lives = 0
	s.restart_level()
	eq(s.score, 1000, "RESTART FIELD rolls the level score back")
	eq(s.lives, 3, "and hands out three lives")
	eq(s.level_bricks, 0, "the level counters reset")
	ok(s.run_bricks > 0, "the run counters do not")

	# A lost ball is only final when it is the last.
	s.lives = 2
	ok(not s.on_ball_lost(), "losing a ball with lives left is not final")
	ok(s.lost_a_ball, "but it is remembered for the stars")
	eq(s.lives, 1, "and it costs a life")
	ok(s.on_ball_lost(), "losing the last one is final")


# --- Section 15, stars ---------------------------------------------------

func _test_stars() -> void:
	var all_three: int = progress.stars_earned(true, 40.0, 60.0, false)
	eq(all_three, progress.ALL_STARS, "cleared, under par, no loss earns all three")

	var slow_clean: int = progress.stars_earned(true, 90.0, 60.0, false)
	ok(slow_clean & progress.STAR_CLEARED, "a slow clean run is cleared")
	ok(not (slow_clean & progress.STAR_UNDER_PAR), "but not under par")
	ok(slow_clean & progress.STAR_NO_LOSS, "and it kept the ball")

	# Section 15: the stars are independent, the third can come without
	# the second.
	var fast_messy: int = progress.stars_earned(true, 40.0, 60.0, true)
	ok(fast_messy & progress.STAR_UNDER_PAR, "a fast messy run is under par")
	ok(not (fast_messy & progress.STAR_NO_LOSS), "but it lost a ball")
	ok(slow_clean != fast_messy, "the two runs earn different stars")

	eq(progress.stars_earned(false, 10.0, 60.0, false), 0, "a field that was not cleared earns none")

	# A level with no par time cannot award the par star.
	var no_par: int = progress.stars_earned(true, 5.0, 0.0, false)
	ok(not (no_par & progress.STAR_UNDER_PAR), "no par time means no par star")

	# LevelState computes the same thing from its own clock.
	var s := LevelState.new()
	s.start_run()
	s.level_time = 40.0
	eq(s.stars(60.0), progress.ALL_STARS, "a clean fast level earns all three")
	s.lost_a_ball = true
	ok(not (s.stars(60.0) & progress.STAR_NO_LOSS), "losing a ball drops the third")


func _test_progress_roundtrip() -> void:
	var keep_levels: Dictionary = progress.levels.duplicate(true)
	var keep_high: int = progress.high_score
	progress.levels = {}
	progress.high_score = 0

	# Merging: a later run adds a star without giving up an earlier one.
	progress.record_clear(1, progress.STAR_CLEARED | progress.STAR_UNDER_PAR, 45.0)
	eq(progress.star_count(1), 2, "a fast run earns two stars")
	progress.record_clear(1, progress.STAR_CLEARED | progress.STAR_NO_LOSS, 80.0)
	eq(progress.star_count(1), 3, "a clean run adds the third without losing the second")
	about(progress.best_time(1), 45.0, 0.01, "and the best time is the faster of the two")

	progress.submit_score(1234)
	progress.save_progress()
	progress.levels = {}
	progress.high_score = 0
	progress.load_progress()
	eq(progress.star_count(1), 3, "stars survive a round trip through the file")
	about(progress.best_time(1), 45.0, 0.01, "so does the best time")
	eq(progress.high_score, 1234, "and the record")

	progress.reset()
	eq(progress.star_count(1), 0, "RESET PROGRESS erases the stars")
	eq(progress.high_score, 0, "and the record")

	progress.levels = keep_levels
	progress.high_score = keep_high
	progress.save_progress()


# --- Section 15, the quiet helper ---------------------------------------

func _test_silent_helper() -> void:
	var keep: Dictionary = progress.levels.duplicate(true)
	progress.levels = {}

	ok(not progress.helper_active(1), "no helper on a fresh field")
	progress.record_fail(1)
	progress.record_fail(1)
	ok(not progress.helper_active(1), "two fails are not enough")
	progress.record_fail(1)
	ok(progress.helper_active(1), "the third fail turns it on")
	about(progress.helper_points(1), 15.0, 0.01, "worth 15 percentage points")

	progress.record_clear(1, progress.STAR_CLEARED, 50.0)
	ok(not progress.helper_active(1), "clearing the field turns it off again")
	eq(progress.consecutive_fails(1), 0, "and resets the count")

	# The table it produces still sums to 100 and moves the promised
	# points from the bad drops to the good ones.
	var pm := PowerupManager.new()
	add_child(pm)
	pm.configure({"powerups": {"wide": 40, "multi": 20, "narrow": 25, "fast": 15}, "id": 1})
	var plain := pm.effective_table()
	var plain_good := 0.0
	for id in plain:
		if Powerup.is_good(str(id)):
			plain_good += float(plain[id])
	about(plain_good, 60.0, 0.01, "the untouched table is 60 per cent good")

	pm.set_good_bonus(15.0)
	var helped := pm.effective_table()
	var good := 0.0
	var total := 0.0
	for id in helped:
		total += float(helped[id])
		if Powerup.is_good(str(id)):
			good += float(helped[id])
	about(total, 100.0, 0.01, "the helped table still sums to 100")
	about(good, 75.0, 0.01, "and the good share is 15 points higher")
	ok(helped.size() == plain.size(), "no drop disappears from the table")

	# A table with nothing bad in it has nothing to take from.
	pm.configure({"powerups": {"wide": 50, "multi": 50}, "id": 1})
	pm.set_good_bonus(15.0)
	var all_good := pm.effective_table()
	about(float(all_good["wide"]), 50.0, 0.01, "an all-good table is left alone")

	pm.queue_free()
	progress.levels = keep
	progress.save_progress()


# --- Section 7, timers and Multi -----------------------------------------

func _test_powerup_timers() -> void:
	var pm := PowerupManager.new()
	add_child(pm)
	var paddle := Paddle.new()
	paddle.position = Vector2(195.0, 780.0)
	add_child(paddle)
	pm.paddle = paddle
	pm.configure(LevelLoader.load_level("res://levels/level_01.json")["data"])

	# Catching Wide again refreshes its clock instead of stacking.
	pm._apply("wide")
	about(float(pm.active_effects()["wide"]), 20.0, 0.01, "Wide runs for 20 seconds")
	pm._process(8.0)
	about(float(pm.active_effects()["wide"]), 12.0, 0.01, "and counts down")
	pm._apply("wide")
	about(float(pm.active_effects()["wide"]), 20.0, 0.01, "catching it again refreshes the clock")

	# Multi is permanent, so it never enters the timer ledger.
	pm._apply("multi")
	ok(not pm.active_effects().has("multi"), "Multi has no timer, it is permanent")

	# Section 20: Giant and Fireball cannot both be active.
	pm._apply("fireball")
	ok(pm.active_effects().has("fireball"), "Fireball is active")
	pm._apply("giant")
	ok(pm.active_effects().has("giant"), "Giant is active")
	ok(not pm.active_effects().has("fireball"), "and it turned Fireball off")
	pm._apply("fireball")
	ok(not pm.active_effects().has("giant"), "the last one caught always wins")

	pm.queue_free()
	paddle.queue_free()


# --- Section 20, Giant ---------------------------------------------------

func _make_ball(arena: Arena, paddle: Paddle) -> Ball:
	var ball := Ball.new()
	ball.arena = arena
	ball.paddle = paddle
	ball.grid = grid
	add_child(ball)
	ball.stuck = false
	return ball


func _test_giant() -> void:
	var arena := Arena.new()
	add_child(arena)
	var paddle := Paddle.new()
	paddle.position = Vector2(195.0, 780.0)
	add_child(paddle)
	paddle.set_bounds(6.0, 384.0)

	grid.build([".............", "....HH.......", "............."], 0.0)
	var ball := _make_ball(arena, paddle)

	about(ball.radius, Ball.BASE_RADIUS, 0.01, "the ball rests at 4 px")
	ball.global_position = Vector2(195.0, 700.0)
	ball.giant = true
	about(ball.radius, Ball.BASE_RADIUS * 2.0, 0.01, "Giant doubles the radius")
	about(ball._scale(), 2.0, 0.01, "and the tail scales with it")
	eq(ball.look(), Ball.Look.GIANT, "and it looks like Giant")
	ball.giant = false
	about(ball.radius, Ball.BASE_RADIUS, 0.01, "and it goes back when it expires")

	# Section 20: Giant breaks Hardened in one hit, but does not pass through.
	var hardened := grid.brick_at(4, 1)
	eq(hardened.hits_left, 3, "Hardened normally takes three hits")
	var record := {"damage": 0, "passed": true}
	var handler := func(_b: Brick, damage: int, _p: Vector2, passed: bool):
		record["damage"] = damage
		record["passed"] = passed
	ball.brick_hit.connect(handler)
	ball.giant = true
	ball.global_position = hardened.rect.get_center() + Vector2(0.0, 60.0)
	ball.velocity = Vector2(0.0, -320.0)
	ball._advance(0.3)
	ball.brick_hit.disconnect(handler)
	eq(record["damage"], 3, "Giant does three damage in one hit")
	ok(not record["passed"], "and it bounces off, it is heavy, not a ghost")
	ok(ball.velocity.y < 0.0 or ball.velocity.y > 0.0, "the ball still has a direction")

	# Growth must never leave the ball inside anything.
	for offset in [Vector2(0.0, -6.0), Vector2(5.0, 0.0), Vector2(-5.0, 3.0)]:
		ball.giant = false
		ball.global_position = hardened.rect.get_center() + Vector2(0.0, hardened.rect.size.y) + offset
		ball.giant = true
		ok(not ball._is_overlapping() or ball.radius == Ball.BASE_RADIUS,
			"growth beside a brick either frees the ball or waits (offset %s)" % str(offset))

	# Against the frame: a giant ball must be pushed back into the field.
	ball.giant = false
	ball.global_position = Vector2(Arena.WALL + 5.0, 700.0)
	ball.giant = true
	ok(ball.global_position.x >= Arena.WALL + ball.radius - 0.6,
		"growth beside the wall pushes the ball back into the field (x=%.2f, r=%.1f)"
			% [ball.global_position.x, ball.radius])

	# And a sweep that starts wedged must not burn its substeps and come
	# out with a garbage velocity.
	ball.giant = false
	ball.global_position = hardened.rect.get_center()
	ball.velocity = Vector2(200.0, 200.0)
	var speed_before := ball.velocity.length()
	ball._advance(1.0 / 60.0)
	about(ball.velocity.length(), speed_before, 1.0, "a wedged sweep keeps its speed")
	ok(is_finite(ball.global_position.x) and is_finite(ball.global_position.y),
		"and leaves the ball somewhere real")

	ball.queue_free()
	paddle.queue_free()
	arena.queue_free()
