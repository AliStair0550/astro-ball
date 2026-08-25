extends Node

## Phase 3: the level system, the power-up rules, stars and progress,
## the quiet helper, Giant, and the strings file.

const SaveGuard := preload("res://tests/save_guard.gd")

var fails := 0
var checks := 0
var grid: BrickGrid
var progress: Node


func _ready() -> void:
	seed(90210)
	SaveGuard.stash()
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
	await _test_feel_lab()
	_test_review_regressions()
	_test_continue_gate()

	SaveGuard.restore()
	print("--- PHASE 3: %d checks, %d failures ---" % [checks, fails])
	for child in get_children():
		child.free()
	# The audio server releases its playbacks a few ticks later. Quitting
	# on top of a running sound is what reports as a leak.
	await get_tree().create_timer(0.4).timeout
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
	# The HUD says the place, not its number: a player knows where they
	# are by the name of it.
	eq(Strings.universe_short("baeltet"), "THE DRIFT", "the short form for the HUD")
	eq(Strings.fmt("LEVEL_NUMBER", [1]), "LEVEL 1", "the level intro line")
	# One word per thing. A level is a level everywhere, and the screen
	# that says you are finished says so in the words everyone has.
	eq(Strings.text("SIGNAL_LOST"), "GAME OVER", "the death screen says what happened")
	eq(Strings.text("FIELD_CLEARED"), "LEVEL CLEARED", "and the win screen too")
	eq(Strings.text("BTN_RE_ENTRY"), "CONTINUE", "no coined words on the buttons")
	eq(Strings.text("BTN_RESTART_FIELD"), "RESTART LEVEL", "and a level is called a level")
	for key in Strings.keys():
		var value := Strings.text(str(key))
		ok(not value.contains("FIELD"), "'%s' does not call a level a field" % str(key))
		ok(not value.contains("RE-ENTRY"), "'%s' has no coined word in it" % str(key))

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
	# Three colours in a mirror, so the fixture passes the mosaic rule
	# it is not here to test.
	var grid_rows: Array = []
	for i in 3:
		grid_rows.append(".FFIIVPVIIFF." if i % 2 == 0 else ".IIFFVPVFFII.")
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
	eq(LevelLoader.breakable_count(one["grid"]), 30, "level 1 has 30 bricks")
	# The first fields teach the chain before they teach patience: blast
	# bricks in all three, and no Hardened until level 6, which is the
	# one built out of it.
	var paths := LevelLoader.level_paths()
	for i in 3:
		var d: Dictionary = LevelLoader.load_level(paths[i])["data"]
		var joined := "".join(PackedStringArray(d["grid"]))
		ok(joined.contains("E"), "%s has blast bricks" % paths[i])
		ok(not joined.contains("H"), "%s has no Hardened yet" % paths[i])
	for i in 5:
		var d: Dictionary = LevelLoader.load_level(paths[i])["data"]
		ok(not "".join(PackedStringArray(d["grid"])).contains("H"),
			"%s is still before the Hardened fields" % paths[i])
	var six: Dictionary = LevelLoader.load_level(paths[5])["data"]
	ok("".join(PackedStringArray(six["grid"])).contains("H"),
		"level 6 is where Hardened arrives")

	# Section 9 gave level 1 no bad drops at all. It has one now, at a
	# weight low enough to teach the dark edge and the zigzag without
	# punishing anyone for learning: you have to meet the category before
	# level 2 uses it against you.
	var bad_share := 0.0
	for id in one["powerups"]:
		if not Powerup.is_good(str(id)):
			bad_share += float(one["powerups"][id])
	ok(bad_share > 0.0, "level 1 teaches that a drop can be bad")
	ok(bad_share <= 10.0, "but only just: %.0f %% of drops" % bad_share)
	ok(one["powerups"].has("giant"), "level 1 can drop Giant")

	# And the punishments spread out rather than arriving all at once.
	# The share climbs the length of the zone: no field is ever kinder
	# than the one before it, which is the only difficulty curve this
	# game has that the player cannot see.
	var previous := 0.0
	var shares: Array[float] = []
	for path in LevelLoader.level_paths():
		var d: Dictionary = LevelLoader.load_level(path)["data"]
		var share := 0.0
		for id in d.get("powerups", {}):
			if Powerup.is_bad(str(id)):
				share += float(d["powerups"][id])
		ok(share >= previous - 0.01, "%s is no gentler than the level before it" % path)
		previous = share
		shares.append(share)
	ok(shares[2] >= 25.0, "by level 3 a quarter of the drops can hurt (%.0f %%)" % shares[2])
	ok(shares[shares.size() - 1] >= 35.0,
		"and by the zone finale better than a third (%.0f %%)" % shares[shares.size() - 1])
	# A neutral is neither, and must not be counted as a punishment.
	var neutral_seen := false
	for path in LevelLoader.level_paths():
		var d: Dictionary = LevelLoader.load_level(path)["data"]
		for id in d.get("powerups", {}):
			if Powerup.is_neutral(str(id)):
				neutral_seen = true
	ok(neutral_seen, "the zone offers a coin flip somewhere")

	# Every punishment in section 7 except Death is reachable somewhere.
	var seen := {}
	for path in LevelLoader.level_paths():
		var d: Dictionary = LevelLoader.load_level(path)["data"]
		for id in d.get("powerups", {}):
			seen[str(id)] = true
	for id in ["narrow", "fast", "heavy", "blind", "invert", "death",
			"shrink", "wobble"]:
		ok(seen.has(id), "the punishment '%s' is reachable" % id)
	for id in ["bomb", "bonus"]:
		ok(seen.has(id), "and the gift '%s' is too" % id)
	# Death is reachable, but not before it is allowed to be.
	for i in PowerupManager.HARSH_SAFE_LEVELS:
		var d: Dictionary = LevelLoader.load_level(LevelLoader.level_paths()[i])["data"]
		ok(not d.get("powerups", {}).has("death"),
			"level %d cannot drop Death" % [i + 1])


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


## The feel lab is a tool, not a test, which is exactly why nothing was
## watching when a field it reads moved into LevelState and killed it.
## This is the tripwire: build it, and check it actually built a field.
func _test_feel_lab() -> void:
	var lab: Node = load("res://scenes/feel_test.tscn").instantiate()
	add_child(lab)
	ok(lab.game != null, "the feel lab builds the game")
	ok(lab.game.grid.remaining_breakable() > 0, "and a field to hit")
	eq(lab.game._balls.size(), 1, "and a ball to hit it with")
	ok(lab.game.state == Game.State.PLAYING, "and it is playing, not behind a screen")

	lab.set_mode(lab.Mode.WALL)
	eq(lab.game.grid.remaining_breakable(), 11 * 6, "the wall mode is 11 wide and 6 rows")
	lab.set_mode(lab.Mode.MAX_SPEED)
	about(lab.game._balls[0].current_speed(), Ball.MAX_SPEED, 0.5,
		"max speed mode pins the ball at the cap")
	lab.set_mode(lab.Mode.SINGLE)
	eq(lab.game.grid.remaining_breakable(), 1, "single mode is one brick")

	# 6. The lab froze forever on the first lost ball: it zeroed the state
	#    timer, but the game only advances state while the timer is above
	#    zero. Drop a ball and check it comes back.
	var doomed: Ball = lab.game._balls[0]
	doomed.global_position = Vector2(195.0, lab.game.arena.death_y + 20.0)
	lab.game._on_ball_lost(doomed)
	eq(lab.game.state, Game.State.BALL_LOST, "the lab notices a lost ball")
	lab._process(1.0 / 60.0)
	eq(lab.game.state, Game.State.PLAYING, "and the ball comes straight back")
	eq(lab.game._balls.size(), 1, "with a ball to hit")
	ok(lab.game.paddle.input_enabled, "and the paddle answering again")

	lab.game.audio.stop_all()
	lab.free()
	await get_tree().process_frame


## One test per defect the adversarial review confirmed. Each of these
## was green before the fix, which is the whole point of writing them.
func _test_review_regressions() -> void:
	# 1. float(null) threw inside validate(), and a throw hands the caller
	#    an empty error list, so a broken level came back clean.
	var poisoned := {
		"grid": [".VVVZVVV", ".VVVVVVVVVVV."],
		"gridAnchor": null,
		"powerups": {"wide": 40, "narrow": 40},
		"forcedFirstPowerup": "teleport",
	}
	var errors := LevelLoader.validate(poisoned)
	ok(errors.size() >= 4, "a null gridAnchor no longer swallows the other errors (%d found)" % errors.size())
	about(LevelLoader.anchor_of(poisoned), 0.0, 0.01, "a null anchor reads as zero")
	about(LevelLoader.anchor_of({"gridAnchor": 25}), 25.0, 0.01, "a real anchor still reads")
	about(LevelLoader.anchor_of({}), 0.0, 0.01, "a missing anchor reads as zero")
	ok(not LevelLoader.validate({"grid": [".VVVVVVVVVVV.", ".VVVVVVVVVVV.",
		".VVVVVVVVVVV.", ".VVVVVVVVVVV."], "gridAnchor": "down",
		"powerups": {"wide": 100}}).is_empty(), "a non-numeric anchor is reported")

	# 2. The Stone rule read the last array row, so one trailing blank row
	#    turned it off for the row actually closest to the paddle.
	var padded := {
		"grid": [".VVVVVVVVVVV.", ".VVVVVVVVVVV.", ".SSSSSSSSSSS.", "............."],
		"powerups": {"wide": 100},
	}
	var padded_errors := LevelLoader.validate(padded)
	var caught := false
	for e in padded_errors:
		if str(e).contains("Stone"):
			caught = true
	ok(caught, "Stone in the lowest brick row is caught behind a trailing blank row")

	# 3. Every paddle overlap was resolved upward, so a ball passing
	#    beside the paddle was lifted onto it and bounced: a miss turned
	#    into a save.
	var arena := Arena.new()
	add_child(arena)
	var paddle := Paddle.new()
	add_child(paddle)
	paddle.position = Vector2(195.0, 780.0)
	paddle.set_bounds(6.0, 384.0)
	var ball := Ball.new()
	ball.arena = arena
	ball.paddle = paddle
	ball.grid = grid
	add_child(ball)
	ball.stuck = false
	ball.giant = true
	var rect := paddle.world_rect()
	ball.global_position = Vector2(rect.position.x - 7.0, 778.0)
	ball.velocity = Vector2(-40.0, 300.0)
	ball._resolve_paddle_overlap()
	ok(ball.global_position.y > paddle.top_y() - ball.radius,
		"a ball beside the paddle is not lifted onto it (y=%.1f)" % ball.global_position.y)
	ok(ball.velocity.y > 0.0, "and it keeps falling, the miss stays a miss")

	# A real hit from above still saves.
	ball.global_position = Vector2(195.0, paddle.top_y() - 1.0)
	ball.velocity = Vector2(0.0, 300.0)
	ball._resolve_paddle_overlap()
	ok(ball.velocity.y < 0.0, "a hit from above is still a save")

	# 4. Giant claimed the branch before Glass could, so a giant ball
	#    bounced off glass instead of going through it.
	grid.build([".............", ".G...........", "............."], 0.0)
	var glass := grid.brick_at(1, 1)
	eq(glass.type, Brick.Type.GLASS, "a glass brick to aim at")
	var seen := {"passed": false, "damage": 0}
	var handler := func(_b: Brick, damage: int, _p: Vector2, passed: bool):
		seen["passed"] = passed
		seen["damage"] = damage
	ball.brick_hit.connect(handler)
	ball.giant = true
	ball.global_position = glass.rect.get_center() + Vector2(0.0, 50.0)
	ball.velocity = Vector2(0.0, -320.0)
	ball._advance(0.3)
	ball.brick_hit.disconnect(handler)
	ok(seen["passed"], "a giant ball still passes through glass")
	ok(ball.velocity.y < 0.0, "and keeps going the way it was going")

	# 5. A growth with no room was held, and switching Giant off left the
	#    request armed, so the ball grew after the power-up was gone.
	ball.giant = false
	ball.global_position = Vector2(195.0, 700.0)
	ball._pending_radius = Ball.BASE_RADIUS * 2.0
	ball.giant = false
	ball._physics_process(1.0 / 60.0)
	about(ball.radius, Ball.BASE_RADIUS, 0.01,
		"a pending growth does not outlive the power-up that asked for it")

	ball.queue_free()
	paddle.queue_free()
	arena.queue_free()


## Section 16 and 19: the price of a re-entry. No ad network and no store
## in this build, so the gate answers FREE. The branches have to be there
## and have to work, because that is the whole reason the seam exists.
func _test_continue_gate() -> void:
	var gate := ContinueGate.new()

	eq(gate.cost_for(0), ContinueGate.Cost.FREE, "with no store and no ads, a re-entry is free")
	ok(gate.available(0), "and it is offered")
	eq(gate.cost_for(1), ContinueGate.Cost.UNAVAILABLE, "but only once per field")
	ok(not gate.available(1), "the second time it is not offered")

	# The paid unlock, section 19.
	gate.entitled = true
	eq(gate.cost_for(0), ContinueGate.Cost.FREE, "the paid version keeps it free")
	gate.entitled = false

	# The free version once an ad layer exists.
	gate.rewarded_ready = true
	eq(gate.cost_for(0), ContinueGate.Cost.WATCH_AD, "with an ad ready, it costs an ad")
	eq(gate.cost_for(1), ContinueGate.Cost.UNAVAILABLE, "still only once per field")

	# Asking for it waits for the ad rather than granting at once.
	var log := {"granted": 0, "denied": 0, "asked": 0}
	gate.granted.connect(func(): log["granted"] += 1)
	gate.denied.connect(func(): log["denied"] += 1)
	gate.ad_requested.connect(func(): log["asked"] += 1)

	gate.request(0)
	eq(log["asked"], 1, "the gate asks the ad layer")
	eq(log["granted"], 0, "and grants nothing yet")
	ok(gate.is_pending(), "it is waiting")
	gate.resolve(true)
	eq(log["granted"], 1, "a watched ad grants the re-entry")
	ok(not gate.is_pending(), "and the wait is over")

	gate.resolve(true)
	eq(log["granted"], 1, "a stray resolve does nothing")

	gate.request(0)
	gate.resolve(false)
	eq(log["denied"], 1, "an abandoned ad denies it")

	# And with no ad ready it grants straight away, which is today.
	gate.rewarded_ready = false
	gate.request(0)
	eq(log["granted"], 2, "with no ad layer it grants at once")

	gate.request(1)
	eq(log["denied"], 2, "and a used-up field is denied")
