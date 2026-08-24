extends Node

## Phase 5: the rest of section 7's power-ups, and The Drift's twelve
## fields. Everything here is either a capsule that was drawn but never
## reachable, or a field that did not exist yet.

var fails := 0
var checks := 0
var grid: BrickGrid


func _ready() -> void:
	seed(31337)
	grid = BrickGrid.new()
	add_child(grid)

	_test_catalog()
	_test_spawn_rules()
	_test_lottery()
	_test_magnet()
	_test_shield()
	_test_speed_ceiling()
	_test_splinter()
	_test_swap()
	_test_spark_table()
	_test_the_drift()
	_test_chains()

	print("--- PHASE 5: %d checks, %d failures ---" % [checks, fails])
	for child in get_children():
		child.free()
	await get_tree().create_timer(0.3).timeout
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


# --- The catalog --------------------------------------------------------

func _test_catalog() -> void:
	# Section 7 lists eighteen for version 1. Giant is section 20's, and
	# the nineteenth.
	var section_7 := [
		"wide", "multi", "fireball", "laser", "magnet", "slow", "shield",
		"life", "zap", "splinter",
		"narrow", "fast", "blind", "invert", "heavy", "death",
		"swap", "lottery",
	]
	for id in section_7:
		ok(Powerup.CATALOG.has(id), "section 7's '%s' exists" % id)
	eq(Powerup.CATALOG.size(), section_7.size() + 1, "eighteen, plus Giant")

	# The three kinds partition the catalog: exactly one is true of each.
	for id in Powerup.CATALOG:
		var name := str(id)
		var kinds := 0
		if Powerup.is_good(name):
			kinds += 1
		if Powerup.is_bad(name):
			kinds += 1
		if Powerup.is_neutral(name):
			kinds += 1
		eq(kinds, 1, "'%s' is exactly one kind of thing" % name)
		# Every capsule says its own name, from the strings file rather
		# than from the fallback that shouts the id back.
		ok(Strings.has("PU_%s" % name.to_upper()), "'%s' has a written name" % name)
		ok(not str(Powerup.info(name)["icon"]).is_empty(), "'%s' has an icon" % name)

	eq(Powerup.CATALOG["swap"]["kind"], Powerup.Kind.NEUTRAL, "Swap is a coin flip")
	eq(Powerup.CATALOG["lottery"]["kind"], Powerup.Kind.NEUTRAL, "so is Lottery")
	ok(Powerup.CATALOG["death"].has("edge"), "Death carries its own black edge")


# --- Spawn rules --------------------------------------------------------

func _test_spawn_rules() -> void:
	var pm := PowerupManager.new()
	add_child(pm)

	# A neutral is not a punishment: it may follow a bad one, which the
	# old rule forbade by treating everything not good as bad.
	pm.configure({"id": 9, "powerups": {"narrow": 50, "swap": 50}})
	var seen_neutral_after_bad := false
	for i in 200:
		pm.spawn(Vector2(100.0, 300.0))
		if pm._capsules.size() >= 2:
			var a: String = pm._capsules[0].id
			var b: String = pm._capsules[1].id
			if Powerup.is_bad(a) and Powerup.is_neutral(b):
				seen_neutral_after_bad = true
			for c in pm._capsules:
				c.queue_free()
			pm._capsules.clear()
	ok(seen_neutral_after_bad, "a coin flip may follow a punishment")

	# Two bad ones still never arrive back to back.
	pm.configure({"id": 9, "powerups": {"narrow": 50, "fast": 50}})
	var twice_bad := false
	var previous := ""
	for i in 300:
		pm._capsules.clear()
		pm.spawn(Vector2(100.0, 300.0))
		if pm._capsules.is_empty():
			continue
		var id: String = pm._capsules[0].id
		if Powerup.is_bad(id) and Powerup.is_bad(previous):
			twice_bad = true
		previous = id
	ok(not twice_bad, "and two punishments never arrive in a row")
	for c in pm._capsules:
		c.queue_free()
	pm._capsules.clear()

	# The quiet helper moves points from the punishments to the gifts and
	# leaves the coin flip exactly where it was.
	pm.configure({"id": 9, "powerups": {"multi": 50, "narrow": 40, "swap": 10}})
	pm.set_good_bonus(15.0)
	var table := pm.effective_table()
	eq(float(table["swap"]), 10.0, "the helper does not touch a neutral")
	ok(float(table["multi"]) > 50.0, "it makes the gifts more likely")
	ok(float(table["narrow"]) < 40.0, "and the punishments less")
	var sum := 0.0
	for id in table:
		sum += float(table[id])
	ok(absf(sum - 100.0) < 0.01, "and the table still sums to 100 (%.2f)" % sum)

	pm.queue_free()


func _test_lottery() -> void:
	var pm := PowerupManager.new()
	add_child(pm)

	# Lottery becomes one of the level's own drops, never another neutral
	# and never something the field does not otherwise contain.
	pm.configure({"id": 9, "powerups": {"multi": 40, "narrow": 40, "lottery": 20}})
	var picked := {}
	for i in 400:
		picked[pm.resolve_lottery()] = true
	ok(picked.has("multi") and picked.has("narrow"), "Lottery hands out both kinds")
	ok(not picked.has("lottery"), "and never itself")
	eq(picked.size(), 2, "and nothing the field does not contain")

	# It is not a back door into Death either.
	pm.configure({"id": 3, "powerups": {"death": 90, "multi": 10}})
	var death_early := false
	for i in 300:
		if pm.resolve_lottery() == "death":
			death_early = true
	ok(not death_early, "Lottery cannot smuggle Death into the first five fields")
	pm.configure({"id": 9, "powerups": {"death": 90, "multi": 10}})
	var death_late := false
	for i in 300:
		if pm.resolve_lottery() == "death":
			death_late = true
	ok(death_late, "but it can hand it over later, where the field says so")

	pm.queue_free()


# --- Magnet -------------------------------------------------------------

func _test_magnet() -> void:
	var arena := Arena.new()
	add_child(arena)
	var paddle := Paddle.new()
	add_child(paddle)
	paddle.position = Vector2(195.0, 735.0)
	paddle.set_bounds(6.0, 384.0)
	var ball := Ball.new()
	ball.arena = arena
	ball.paddle = paddle
	add_child(ball)
	ball.stuck = false

	# Without it the ball comes back.
	ball.global_position = Vector2(215.0, paddle.top_y() - 30.0)
	ball.velocity = Vector2(0.0, 320.0)
	ball._advance(0.2)
	ok(not ball.stuck, "an ordinary paddle returns the ball")
	ok(ball.velocity.y < 0.0, "upward")

	# With it, the ball is held where it landed, not in the middle.
	paddle.magnet = true
	var caught := {"count": 0}
	ball.caught.connect(func(_b: Ball) -> void: caught["count"] += 1)
	ball.stuck = false
	ball.global_position = Vector2(215.0, paddle.top_y() - 30.0)
	ball.velocity = Vector2(0.0, 320.0)
	ball._advance(0.2)
	ok(ball.stuck, "the Magnet holds it")
	eq(caught["count"], 1, "and says so once")
	ok(ball.velocity == Vector2.ZERO, "a held ball has no speed")
	ok(absf(ball.global_position.x - 215.0) < 6.0,
		"held where it landed, not recentred (x=%.1f)" % ball.global_position.x)
	ok(absf(ball.global_position.y - (paddle.top_y() - ball.radius - 1.0)) < 0.01,
		"and resting on the shield, not floating (y=%.1f against %.1f)"
		% [ball.global_position.y, paddle.top_y() - ball.radius - 1.0])

	# It follows the paddle while held, keeping its offset.
	paddle.position.x = 150.0
	ball._physics_process(1.0 / 60.0)
	ok(absf(ball.global_position.x - 170.0) < 6.0,
		"and rides along with the shield (x=%.1f)" % ball.global_position.x)

	# The offset can never put the ball off the end of the paddle.
	ball.stick_to_paddle(500.0)
	ok(absf(ball.global_position.x - paddle.global_position.x) <= paddle.half_width(),
		"a silly offset is clamped to the shield")

	# A tap lets go, and the ball leaves centred on its own launch angle.
	ball.launch()
	ok(not ball.stuck, "a tap releases it")
	ok(ball.velocity.y < 0.0, "upward")
	eq(ball.stick_offset, 0.0, "and the hold is forgotten")

	ball.queue_free()
	paddle.queue_free()
	arena.queue_free()


# --- Shield -------------------------------------------------------------

func _test_shield() -> void:
	var arena := Arena.new()
	add_child(arena)
	ok(not arena.shield_armed, "no shield to begin with")
	arena.shield_armed = true
	arena.spend_shield()
	ok(not arena.shield_armed, "and one save is all it is")

	var paddle := Paddle.new()
	add_child(paddle)
	paddle.position = Vector2(195.0, 735.0)
	var ball := Ball.new()
	ball.arena = arena
	ball.paddle = paddle
	add_child(ball)
	ball.stuck = false
	ball.global_position = Vector2(195.0, arena.death_y + 20.0)
	ball.velocity = Vector2(60.0, 300.0).normalized() * ball.current_speed()
	var before := ball.velocity.length()
	ball.save_at(arena.ember_line_y() - 2.0)
	ok(ball.global_position.y < arena.ember_line_y(), "a saved ball is back inside the field")
	ok(ball.velocity.y < 0.0, "and travelling up")
	ok(absf(ball.velocity.length() - before) < 1.0, "at the speed it was doing")
	ok(absf(rad_to_deg(ball.velocity.angle_to(Vector2.RIGHT))) >= 20.0,
		"never flatter than the minimum angle")

	ball.queue_free()
	paddle.queue_free()
	arena.queue_free()


# --- The ceiling --------------------------------------------------------

func _test_speed_ceiling() -> void:
	var ball := Ball.new()
	add_child(ball)
	ball.speed_base = Ball.MAX_SPEED
	ball.speed_scale = 1.0
	ok(absf(ball.current_speed() - Ball.MAX_SPEED) < 0.01, "the ramp tops out at its own cap")
	ball.speed_scale = 1.4
	ok(ball.current_speed() > Ball.MAX_SPEED, "Fast still bites at the top of the ramp")
	ok(ball.current_speed() <= Ball.ABSOLUTE_MAX_SPEED + 0.01,
		"but never past the ceiling (%.0f px/s)" % ball.current_speed())
	# Lower down the ramp it gets its full 140 per cent.
	ball.speed_base = 360.0
	ok(absf(ball.current_speed() - 504.0) < 0.01,
		"and lower down it is the whole punishment (%.0f px/s)" % ball.current_speed())
	ball.speed_scale = 0.7
	ok(absf(ball.current_speed() - 252.0) < 0.01, "Slow is untouched by the ceiling")
	ball.queue_free()


# --- Splinter and Swap --------------------------------------------------

func _test_splinter() -> void:
	grid.build([
		".............",
		".VVHHVVHHVVV.",
		".VVVVVVVVVVV.",
	], 0.0)
	var hardened := grid.brick_at(3, 1)
	eq(hardened.type, Brick.Type.HARDENED, "a Hardened brick to chip")
	var before := grid.remaining_breakable()
	var doomed := grid.splinter()
	eq(doomed, before - 4, "Splinter takes everything one hit from breaking, and only that")

	# Run the queue out and check the field agrees.
	for i in 200:
		grid._process(1.0 / 60.0)
	eq(grid.remaining_breakable(), 4, "the four Hardened are what is left")

	# Chipped twice, a Hardened brick is one hit from breaking, so the
	# next Splinter does take it.
	grid.hit(hardened, 2)
	eq(hardened.hits_left, 1, "chipped down to its last hit")
	eq(grid.splinter(), 1, "and now Splinter has it too")
	for i in 200:
		grid._process(1.0 / 60.0)
	eq(grid.remaining_breakable(), 3, "one of them was it")


func _test_swap() -> void:
	grid.build([
		".............",
		".VIPFHSEGX?..",
		".............",
	], 0.0)
	var before := grid.remaining_breakable()
	var specials := {}
	for col in [4, 5, 6, 7, 8, 9]:
		var brick := grid.brick_at(col, 1)
		if brick != null:
			specials[col] = brick.type
	var changed := grid.swap_types()
	eq(changed, 4, "Swap changes the four plain types and nothing else")
	eq(grid.remaining_breakable(), before, "the field is worth the same number of bricks")
	eq(grid.brick_at(1, 1).type, Brick.Type.ICE, "Volt becomes Ice")
	eq(grid.brick_at(2, 1).type, Brick.Type.PULSE, "Ice becomes Pulse")
	eq(grid.brick_at(3, 1).type, Brick.Type.FLARE, "Pulse becomes Flare")
	eq(grid.brick_at(4, 1).type, Brick.Type.VOLT, "and Flare comes back round to Volt")
	for col in specials:
		# Column 4 is Hardened in the row above and has already been
		# checked; the rest are the specials Swap must leave alone.
		if col == 4:
			continue
		eq(grid.brick_at(col, 1).type, specials[col],
			"the special brick in column %d is untouched" % col)

	# Four swaps and the field is itself again.
	for i in 3:
		grid.swap_types()
	eq(grid.brick_at(1, 1).type, Brick.Type.VOLT, "four Swaps is a full turn")


# --- The Spark's short list ---------------------------------------------

func _test_spark_table() -> void:
	var pm := PowerupManager.new()
	add_child(pm)
	var five: Dictionary = LevelLoader.load_level("res://levels/level_05.json")["data"]
	pm.configure(five)
	eq(pm.spark_table.size(), 2, "level 5 narrows what its Sparks give")
	var got := {}
	for i in 60:
		pm._capsules.clear()
		pm.spawn(Vector2(100.0, 300.0), true)
		if not pm._capsules.is_empty():
			got[pm._capsules[0].id] = true
	eq(got.size(), 2, "and hands out only those two")
	ok(got.has("magnet") and got.has("laser"), "Magnet and Laser, which is the lesson")

	# An ordinary drop still comes from the level's own table.
	pm.configure(LevelLoader.load_level("res://levels/level_01.json")["data"])
	eq(pm.spark_table.size(), 0, "a field without the key does not narrow anything")
	for c in pm._capsules:
		c.queue_free()
	pm._capsules.clear()
	pm.queue_free()


# --- The zone -----------------------------------------------------------

func _test_the_drift() -> void:
	var paths := LevelLoader.level_paths()
	eq(paths.size(), 12, "The Drift is twelve fields")

	var names := {}
	var types := {}
	var previous_id := 0
	for path in paths:
		var result := LevelLoader.load_level(path)
		ok(result["ok"], "%s validates: %s" % [path, ", ".join(result["errors"])])
		var d: Dictionary = result["data"]
		var name := str(d["name"])
		ok(not names.has(name), "'%s' is its own field" % name)
		names[name] = true
		eq(int(d["id"]), previous_id + 1, "%s is numbered in order" % name)
		previous_id = int(d["id"])
		ok(int(d.get("parTime", 0)) > 0, "%s has a par time" % name)
		for c in "".join(PackedStringArray(d["grid"])):
			if c != ".":
				types[c] = true

	# Section 3 lists ten kinds of brick for The Drift. By the end of the
	# zone the player has met all ten.
	for symbol in Brick.SYMBOLS:
		ok(types.has(symbol), "the zone uses the '%s' brick somewhere" % symbol)

	# The finale is where they all turn up at once.
	var twelve: Dictionary = LevelLoader.load_level(paths[11])["data"]
	var final_types := {}
	for c in "".join(PackedStringArray(twelve["grid"])):
		if c != ".":
			final_types[c] = true
	eq(final_types.size(), Brick.SYMBOLS.size(), "The Core holds every kind of brick")
	ok(LevelLoader.breakable_count(twelve["grid"]) > 120,
		"and enough of them to be a finale (%d)" % LevelLoader.breakable_count(twelve["grid"]))

	# Level 11 is blind from the first frame, and not because of a
	# capsule: nothing running out can give the field back.
	var eleven: Dictionary = LevelLoader.load_level(paths[10])["data"]
	ok(bool(eleven.get("blind", false)), "Blackout starts blind")
	ok(not eleven.get("powerups", {}).has("blind"),
		"and does not drop the capsule that would do nothing")


func _test_chains() -> void:
	# Section 10 promises that one hit clears 60 per cent of level 9. The
	# number is asserted because a redraw can quietly take it away.
	var nine: Dictionary = LevelLoader.load_level("res://levels/level_09.json")["data"]
	var share := _best_chain_share(nine["grid"])
	ok(share >= 0.55, "one hit takes most of The Fuse (%.0f %%)" % (share * 100.0))

	# Every level has a chain worth finding. Four of them once had no
	# blast brick at all, which meant no moment: just a wall coming down
	# one brick at a time. The floor is a fifth of the level in one hit.
	var paths := LevelLoader.level_paths()
	for i in paths.size():
		var d: Dictionary = LevelLoader.load_level(paths[i])["data"]
		var s := _best_chain_share(d["grid"])
		ok(s >= 0.20, "%s: one hit takes %.0f %% of it" % [str(d["name"]), s * 100.0])
	# And The Fuse is still the one the chain belongs to.
	for i in paths.size():
		if i == 8:
			continue
		var d: Dictionary = LevelLoader.load_level(paths[i])["data"]
		ok(_best_chain_share(d["grid"]) < share,
			"%s does not out-chain The Fuse" % str(d["name"]))


## The share of a field a single blast brick takes with it, measured the
## way the grid does it: a chain destroys outright, and a blast brick
## caught in one starts its own.
func _best_chain_share(rows: Array) -> float:
	var total := LevelLoader.breakable_count(rows)
	if total <= 0:
		return 0.0
	var best := 0
	for row in rows.size():
		var line: String = str(rows[row])
		for col in line.length():
			if line[col] == "E":
				best = maxi(best, _chain_from(rows, col, row))
	return float(best) / float(total)


func _chain_from(rows: Array, col: int, row: int) -> int:
	grid.build(rows, 0.0)
	var start := grid.brick_at(col, row)
	if start == null:
		return 0
	grid.hit(start, start.hits_left)
	for i in 600:
		grid._process(1.0 / 60.0)
	return LevelLoader.breakable_count(rows) - grid.remaining_breakable()
