extends Node

## The visual revision: the v2 brick, the mosaic rule, and the pressure
## wave a chain leaves behind it.

var fails := 0
var checks := 0
var grid: BrickGrid
var canvas: BrickCanvas


func _ready() -> void:
	seed(1212)
	grid = BrickGrid.new()
	add_child(grid)
	canvas = BrickCanvas.new()
	add_child(canvas)
	call_deferred("_run")


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


func _run() -> void:
	await _test_every_type_and_stage()
	_test_mitred_corners()
	_test_chain_shards()
	_test_mosaic_validator()
	_test_balance_snapshot()

	print("--- VISUAL: %d checks, %d failures ---" % [checks, fails])
	for child in get_children():
		child.free()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(1 if fails > 0 else 0)


# --- 1. The v2 brick ----------------------------------------------------

## Every type at every damage stage, through the real draw path. Drawing
## cannot be called from a test directly — Godot refuses draw commands
## outside a draw pass — so it goes through a canvas that draws them all
## in its own _draw, and the suite fails on any error the console sees.
func _test_every_type_and_stage() -> void:
	canvas.queue_redraw()
	await get_tree().process_frame
	await get_tree().process_frame
	eq(canvas.drawn, canvas.expected(), "every type is drawn at every stage it has")
	ok(canvas.drawn > 20, "which is %d bricks" % canvas.drawn)

	# The base sits back from the colour so the bevel has room to go both
	# ways, and the light edges are lighter than it while the dark ones
	# are darker.
	var brick := Brick.new(Brick.Type.VOLT, 0, 0, Rect2(0.0, 0.0, Brick.SIZE.x, Brick.SIZE.y))
	var base: Color = brick.color()
	ok(Brick.BASE_LUM < 1.0, "the base is set back from the colour")
	ok(float(Brick.NORMAL_BEVEL[0]) > 1.0 and float(Brick.NORMAL_BEVEL[1]) > 1.0,
		"the top and left edges are lit")
	ok(float(Brick.NORMAL_BEVEL[2]) < 1.0 and float(Brick.NORMAL_BEVEL[3]) < 1.0,
		"the right and bottom edges are in shadow")
	ok(float(Brick.NORMAL_BEVEL[0]) > float(Brick.NORMAL_BEVEL[1]),
		"and the light comes from above and to the left")
	# Stone keeps far less of the lift than the drop, which is what dead
	# looks like next to eleven bricks that are lit.
	var lift := float(Brick.NORMAL_BEVEL[0]) - 1.0
	var stone_lift := float(Brick.STONE_BEVEL[0]) - 1.0
	ok(stone_lift < lift * 0.5, "Stone keeps less than half the lift")
	ok(float(Brick.STONE_BEVEL[3]) > float(Brick.NORMAL_BEVEL[3]),
		"and a shallower shadow with it")
	ok(base.r > 0.0, "and a Volt brick is still Volt")


# --- 2. The mitre -------------------------------------------------------

## The four edges are trapezoids that meet on the diagonal. Stacked
## rectangles would cross at the corners and read as a picture frame
## rather than as a tile.
func _test_mitred_corners() -> void:
	var r := Rect2(0.0, 0.0, Brick.SIZE.x, Brick.SIZE.y)
	var b := Brick.BEVEL
	var top := Brick.bevel_polygon(r, 0)
	var left := Brick.bevel_polygon(r, 1)
	var right := Brick.bevel_polygon(r, 2)
	var bottom := Brick.bevel_polygon(r, 3)
	for poly in [top, left, right, bottom]:
		eq(poly.size(), 4, "an edge is a trapezoid")

	# The top and the left share the inner corner, and both touch the
	# outer one: that is the mitre.
	ok(top[3].is_equal_approx(Vector2(b, b)), "the top's inner left corner is the mitre point")
	ok(left[1].is_equal_approx(Vector2(b, b)), "and so is the left's")
	ok(top[0].is_equal_approx(Vector2.ZERO) and left[0].is_equal_approx(Vector2.ZERO),
		"and they meet at the outer corner too")
	ok(right[3].is_equal_approx(Vector2(r.size.x - b, b)), "the right mitres at the top")
	ok(bottom[2].is_equal_approx(Vector2(r.size.x - b, r.size.y - b)),
		"and the bottom meets it at the other end")

	# At grid spacing the bevels of two neighbours never touch: the gap
	# between bricks stays a gap.
	var gap := BrickGrid.PITCH.x - Brick.SIZE.x
	ok(gap > 0.0, "there is a gap between bricks (%.0f px)" % gap)
	var mine := Brick.bevel_polygon(r, 2)
	var theirs := Brick.bevel_polygon(Rect2(BrickGrid.PITCH.x, 0.0, Brick.SIZE.x, Brick.SIZE.y), 1)
	var my_right := -INF
	for p in mine:
		my_right = maxf(my_right, p.x)
	var their_left := INF
	for p in theirs:
		their_left = minf(their_left, p.x)
	ok(their_left - my_right >= gap - 0.01,
		"and the bevels of two neighbours keep it (%.1f px apart)" % (their_left - my_right))

	# Stage two takes the corners off, so the mitre stops short.
	var chipped := Brick.bevel_polygon(r, 0, 3.0)
	ok(chipped[0].x > top[0].x, "a chipped brick loses its corner")


# --- 3. The pressure wave -----------------------------------------------

func _test_chain_shards() -> void:
	var effects := Effects.new()
	add_child(effects)
	var rect := Rect2(200.0, 300.0, Brick.SIZE.x, Brick.SIZE.y)
	var origin := rect.get_center() - Vector2(60.0, 0.0)
	var away := (rect.get_center() - origin).normalized()

	# A chain throws its shards away from the blast, and faster.
	effects.clear_all()
	effects.brick_smashed(rect, Color("D6FF3D"), 8, false, origin, Game.CHAIN_SHARD_SPEED)
	var with_push := _shard_stats(effects, away)
	ok(float(with_push["forward"]) >= 7.0,
		"the chain throws its shards away from the blast (%d of 8)" % int(with_push["forward"]))

	# The same brick taken by a ball scatters them from the contact.
	effects.clear_all()
	effects.brick_smashed(rect, Color("D6FF3D"), 8, false, origin, 1.0)
	var plain := _shard_stats(effects, away)
	ok(float(with_push["speed"]) > float(plain["speed"]) * 1.3,
		"and half again as fast (%.0f against %.0f px/s)" % [with_push["speed"], plain["speed"]])
	ok(float(with_push["forward"]) >= float(plain["forward"]),
		"and more of them go the way the wave was going")

	# Without an origin there is nothing to fly away from, and the spray
	# is even: a brick nobody pushed.
	effects.clear_all()
	effects.brick_smashed(rect, Color("D6FF3D"), 12)
	var even := _shard_stats(effects, away)
	ok(float(even["forward"]) < 11.0, "an unpushed brick scatters both ways")
	effects.queue_free()

	# The wave itself: a brick queued into a chain washes before it goes.
	grid.build([".............", ".VEVVVVVVVVV.", "............."], 0.0)
	var blast := grid.brick_at(2, 1)
	var neighbour := grid.brick_at(3, 1)
	eq(neighbour.wash, 0.0, "a brick nobody is coming for is not washed")
	grid.hit(blast, blast.hits_left)
	ok(neighbour.chain_from != Vector2.INF, "a queued brick remembers where the blast was")
	# The wash arrives inside the last sixty milliseconds before it goes.
	var washed := false
	for i in 20:
		grid._process(1.0 / 120.0)
		if neighbour.alive and neighbour.wash > 0.0:
			washed = true
	ok(washed, "and it washes orange before it shatters")


func _shard_stats(effects: Effects, away: Vector2) -> Dictionary:
	var forward := 0
	var speed := 0.0
	var count := 0
	for bit in effects._bits:
		if str(bit["kind"]) != "splinter":
			continue
		var v: Vector2 = bit["vel"]
		count += 1
		speed += v.length()
		if v.normalized().dot(away) > 0.0:
			forward += 1
	return {"forward": float(forward), "speed": speed / maxf(float(count), 1.0)}


# --- 4. The mosaic rule -------------------------------------------------

func _test_mosaic_validator() -> void:
	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		var errors := LevelLoader.mosaic_errors(data["grid"])
		ok(errors.is_empty(), "%s reads as a mosaic: %s" % [path, ", ".join(errors)])

	# A wall of one colour is not a mosaic.
	var flat := [".VVVVVVVVVVV.", ".VVVVVVVVVVV.", ".VVVVVVVVVVV."]
	ok(not LevelLoader.mosaic_errors(flat).is_empty(), "a single colour wall is refused")
	# Three rows of the same colour is one too many, even with others
	# elsewhere on the wall.
	var three := [".VVVVVVVVVVV.", ".VVVVVVVVVVV.", ".VVVVVVVVVVV.", ".IIIIIIIIIII.", ".PPPPPPPPPPP."]
	ok(not LevelLoader.mosaic_errors(three).is_empty(), "three rows of one colour is refused")
	var two := [".VVVVVVVVVVV.", ".VVVVVVVVVVV.", ".IIIIIIIIIII.", ".PPPPPPPPPPP."]
	ok(LevelLoader.mosaic_errors(two).is_empty(), "two is allowed")
	# And the rule counts colours, not bricks: a wall of one colour plus
	# specials is still one colour.
	var specials := [".VVVEEEVVVVV.", ".VVVHHHVVVVV."]
	ok(not LevelLoader.mosaic_errors(specials).is_empty(),
		"specials do not stand in for a second colour")

	# Pulse is worth double, so it never sits on the edge of a row where
	# it is the easiest brick on the wall to reach.
	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		for row in data["grid"]:
			var line := str(row)
			var first := -1
			var last := -1
			for i in line.length():
				if line[i] != ".":
					if first < 0:
						first = i
					last = i
			if first < 0:
				continue
			ok(line[first] != "P" and line[last] != "P",
				"%s keeps Pulse in from the edge" % path)


# --- 5. Balance ---------------------------------------------------------

## The recolour moved colours and nothing else. Every count that decides
## how a level plays is compared against what it was before the pass.
func _test_balance_snapshot() -> void:
	var text := FileAccess.get_file_as_string("res://tests/fixtures/level_balance.json")
	var parsed: Variant = JSON.parse_string(text)
	ok(typeof(parsed) == TYPE_DICTIONARY, "the balance snapshot loads")
	if typeof(parsed) != TYPE_DICTIONARY:
		return
	var snapshot: Dictionary = parsed
	eq(snapshot.size(), 12, "one entry per level")

	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		# JSON numbers come back as floats, so "6" arrives as "6.0" and
		# matches nothing in the snapshot.
		var id := str(int(data["id"]))
		ok(snapshot.has(id), "level %s is in the snapshot" % id)
		if not snapshot.has(id):
			continue
		var want: Dictionary = snapshot[id]
		var joined := "".join(PackedStringArray(data["grid"]))
		for symbol in ["E", "H", "G", "S", "X", "?"]:
			eq(joined.count(symbol), int(want[symbol]),
				"level %s still has %d '%s'" % [id, int(want[symbol]), symbol])
		eq(LevelLoader.breakable_count(data["grid"]), int(want["breakable"]),
			"level %s still has the same number of bricks" % id)
		var plain := 0
		for c in joined:
			if c in ["V", "I", "P", "F"]:
				plain += 1
		eq(plain, int(want["plain"]), "level %s still has the same one-hit bricks" % id)


## Draws every brick type at every damage stage it has, so the whole v2
## path is exercised by something that can actually draw.
class BrickCanvas:
	extends Node2D

	var drawn := 0

	func expected() -> int:
		var n := 0
		for type in Brick.Type.values():
			n += Brick.DATA[type]["hits"] if int(Brick.DATA[type]["hits"]) > 0 else 1
		# Every type once more, drawn flat for the feel lab's comparison.
		return n + Brick.Type.values().size()

	func _draw() -> void:
		drawn = 0
		var x := 0.0
		for type in Brick.Type.values():
			var stages: int = maxi(int(Brick.DATA[type]["hits"]), 1)
			for stage in stages:
				var brick := Brick.new(type, int(x), 0, Rect2(x, 0.0, Brick.SIZE.x, Brick.SIZE.y))
				brick.hits_left = maxi(stages - stage, 1)
				brick.revealed = true
				brick.proximity = 0.6
				brick.wash = 0.4
				brick.draw_into(self, 1.0)
				drawn += 1
				x += BrickGrid.PITCH.x
			var flat := Brick.new(type, int(x), 1, Rect2(x, 0.0, Brick.SIZE.x, Brick.SIZE.y))
			flat.revealed = true
			flat.draw_into(self, 1.0, false, true)
			drawn += 1
			x += BrickGrid.PITCH.x
