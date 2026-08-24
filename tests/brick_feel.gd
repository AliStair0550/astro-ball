extends Node

## Phase 2 gate: the brick must reflect correctly on every face and
## corner, at every speed, and never be passed through. The shards must
## always be the right number and always clean up after themselves.

const BRICK := Rect2(100.0, 100.0, 24.0, 16.0)
const SPEEDS := [320.0, 520.0]
## Section 20: Giant doubles the ball, so every sweep guarantee has to
## hold at both sizes. A bigger circle overlaps more rects per step.
const RADII := [4.0, 8.0]
const SWEEP_TRIALS := 10000

var fails := 0
var checks := 0
var grid: BrickGrid
var effects: Effects


func _ready() -> void:
	seed(31337)
	grid = BrickGrid.new()
	add_child(grid)
	effects = Effects.new()
	add_child(effects)

	_test_faces()
	_test_corners()
	_test_no_tunneling()
	_test_shard_count()
	_test_shard_cleanup()
	_test_combo_pitch()

	print("--- BRICK FEEL: %d checks, %d failures ---" % [checks, fails])
	for child in get_children():
		child.free()
	get_tree().quit(1 if fails > 0 else 0)


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("  FAIL: %s" % label)


## One Volt brick, placed so its rect is exactly BRICK.
func _single_brick_grid() -> Brick:
	var col := 4
	var row := 2
	var rows: Array[String] = []
	for r in row + 1:
		rows.append("............." if r < row else "....V........")
	grid.build(rows)
	return grid.brick_at(col, row)


func _make_ball(radius := 4.0) -> Ball:
	var ball := Ball.new()
	ball.grid = grid
	add_child(ball)
	ball.stuck = false
	ball.radius = radius
	return ball


## Fires a ball at the brick from `from` in direction `dir` and returns
## the recorded hit, if any.
func _fire(ball: Ball, brick: Brick, from: Vector2, dir: Vector2, speed: float) -> Dictionary:
	var record := {"hit": false, "normal": Vector2.ZERO, "velocity": Vector2.ZERO}
	var handler := func(b: Brick, _d: int, _p: Vector2, _passed: bool):
		if b == brick:
			record["hit"] = true
	ball.brick_hit.connect(handler)

	ball.global_position = from
	ball.velocity = dir.normalized() * speed
	# Long enough that the sweep certainly reaches the brick.
	var distance := from.distance_to(brick.rect.get_center()) + 60.0
	ball._advance(distance / speed)

	record["velocity"] = ball.velocity
	ball.brick_hit.disconnect(handler)
	return record


func _test_faces() -> void:
	for radius: float in RADII:
		_faces_at(radius)


func _faces_at(radius: float) -> void:
	for speed: float in SPEEDS:
		var brick := _single_brick_grid()
		var center := brick.rect.get_center()
		var cases := {
			"lower": [center + Vector2(0.0, 40.0), Vector2(0.0, -1.0), Vector2(0.0, 1.0)],
			"upper": [center + Vector2(0.0, -40.0), Vector2(0.0, 1.0), Vector2(0.0, -1.0)],
			"left": [center + Vector2(-50.0, 0.0), Vector2(1.0, 0.0), Vector2(-1.0, 0.0)],
			"right": [center + Vector2(50.0, 0.0), Vector2(-1.0, 0.0), Vector2(1.0, 0.0)],
		}
		for name in cases:
			var brick_now := _single_brick_grid()
			var case: Array = cases[name]
			var ball := _make_ball(radius)
			var result := _fire(ball, brick_now, case[0], case[1], speed)
			ok(result["hit"], "r%.0f %.0f px/s: the %s face is hit" % [radius, speed, name])
			var out: Vector2 = result["velocity"]
			var want: Vector2 = case[2]
			ok(out.normalized().dot(want) > 0.9,
				"%.0f px/s: the %s face throws the ball back (got %s)" % [speed, name, str(out.normalized())])
			ok(absf(out.length() - speed) < 1.0,
				"%.0f px/s: speed is unchanged after the %s face" % [speed, name])
			ok(not brick_now.rect.grow(ball.radius - 0.5).has_point(ball.global_position),
				"%.0f px/s: the ball ends outside the brick at %s" % [speed, name])
			ball.free()


func _test_corners() -> void:
	for radius: float in RADII:
		_corners_at(radius)


func _corners_at(radius: float) -> void:
	for speed: float in SPEEDS:
		var offsets := {
			"top left": Vector2(-1.0, -1.0),
			"top right": Vector2(1.0, -1.0),
			"bottom left": Vector2(-1.0, 1.0),
			"bottom right": Vector2(1.0, 1.0),
		}
		for name in offsets:
			var brick := _single_brick_grid()
			var center := brick.rect.get_center()
			var away: Vector2 = offsets[name]
			var corner := center + Vector2(away.x * brick.rect.size.x * 0.5, away.y * brick.rect.size.y * 0.5)
			var from := corner + away.normalized() * 45.0
			var ball := _make_ball(radius)
			var result := _fire(ball, brick, from, -away.normalized(), speed)
			ok(result["hit"], "r%.0f %.0f px/s: the %s corner is hit" % [radius, speed, name])
			var out: Vector2 = result["velocity"]
			# Whatever face or corner it caught, it must leave the brick.
			ok(out.dot(center - ball.global_position) < 0.0,
				"%.0f px/s: the %s corner sends the ball away from the brick" % [speed, name])
			ok(not brick.rect.grow(ball.radius - 0.5).has_point(ball.global_position),
				"%.0f px/s: the ball ends outside the brick at the %s corner" % [speed, name])
			ball.free()


## Ten thousand runs straight at the brick from every angle, every one
## of them a single step long enough to carry the ball clean past it.
## That is what tunnelling is: not a fast ball, but a step longer than
## the thing it should have hit. Not one of them may pass through.
func _test_no_tunneling() -> void:
	for radius: float in RADII:
		_tunneling_at(radius)


func _tunneling_at(radius: float) -> void:
	var brick := _single_brick_grid()
	var center := brick.rect.get_center()
	var ball := _make_ball(radius)
	var missed := 0
	var worst_step := 0.0
	var worst_frames := 0.0

	for i in SWEEP_TRIALS:
		var angle := randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		# Aim through the brick, not only at its centre.
		var target := center + Vector2(randf_range(-11.0, 11.0), randf_range(-7.0, 7.0))
		# Start well clear of the brick, so the ball is never inside it
		# at t=0. A ball that starts inside is a different problem.
		# Far enough out that the ball is never inside the brick at t=0,
		# at either radius: half the brick diagonal is 14.4 px.
		var start_distance := randf_range(30.0 + radius, 160.0)
		var from := target - dir * start_distance
		var speed: float = SPEEDS[i % SPEEDS.size()]
		# One step that reaches past the far side in a single sweep.
		var step := (start_distance + 40.0) / speed
		worst_step = maxf(worst_step, speed * step)
		worst_frames = maxf(worst_frames, step * 60.0)

		# A Dictionary, not a bool: GDScript lambdas capture locals by
		# value, so writing to a captured bool writes to a copy.
		var record := {"hit": false}
		var handler := func(b: Brick, _d: int, _p: Vector2, _passed: bool):
			if b == brick:
				record["hit"] = true
		ball.brick_hit.connect(handler)
		ball.global_position = from
		ball.velocity = dir * speed
		ball._advance(step)
		ball.brick_hit.disconnect(handler)

		if not record["hit"]:
			missed += 1
			if missed <= 3:
				print("    missed: from %s dir %s speed %.0f step %.1f px"
					% [str(from.round()), str(dir.snapped(Vector2(0.01, 0.01))), speed, speed * step])

	ok(missed == 0, "r%.0f: %d of %d runs tunnelled through the brick" % [radius, missed, SWEEP_TRIALS])
	ok(worst_step > 150.0,
		"the test reached steps of %.0f px (%.1f frames), far past the brick 16 px"
			% [worst_step, worst_frames])
	ball.free()


func _test_shard_count() -> void:
	# Section 6: 5 to 8 shards. Glass is the stated exception with 12.
	for type in Brick.DATA:
		var data: Dictionary = Brick.DATA[type]
		if int(data["hits"]) <= 0:
			continue
		var shards := int(data["shards"])
		if type == Brick.Type.GLASS:
			ok(shards == 12, "Glass shatters into 12 shards")
		else:
			ok(shards >= 5 and shards <= 8,
				"%s shatters into 5 to 8 pieces (got %d)" % [str(data["name"]), shards])

	# And the effect actually produces the number it is asked for.
	for count in [5, 6, 7, 8]:
		effects.clear_all()
		effects.brick_smashed(BRICK, Color("D6FF3D"), count, false, BRICK.get_center() + Vector2(0.0, 10.0))
		ok(effects.shard_count() == count, "brick_smashed(%d) produced %d shards" % [count, effects.shard_count()])


func _test_shard_cleanup() -> void:
	effects.clear_all()
	effects.brick_smashed(BRICK, Color("D6FF3D"), 8, false)
	ok(effects.shard_count() == 8, "eight shards in the air")
	var t := 0.0
	var step := 1.0 / 60.0
	while t < 0.4:
		effects._process(step)
		t += step
	ok(effects.shard_count() == 0, "every shard is gone within 400 ms (%d left)" % effects.shard_count())


func _test_combo_pitch() -> void:
	ok(absf(Audio.combo_pitch(0) - 1.0) < 0.0001, "combo 0 gives the base tone")
	ok(absf(Audio.combo_pitch(1) - 1.0) < 0.0001, "the first brick gives the base tone")
	ok(absf(Audio.combo_pitch(2) - pow(2.0, 1.0 / 12.0)) < 0.0001, "the second brick rises a semitone")
	ok(absf(Audio.combo_pitch(13) - 2.0) < 0.0001, "twelve steps is a whole octave")
	for combo in [13, 20, 50, 500]:
		ok(absf(Audio.combo_pitch(combo) - 2.0) < 0.0001,
			"the pitch cap holds at combo %d" % combo)
