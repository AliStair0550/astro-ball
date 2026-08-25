extends Node

## Phase 9: the juice pass, the session, and the Game Center seam.

const SaveGuard := preload("res://tests/save_guard.gd")

var game: Game
var fails := 0
var checks := 0


func _ready() -> void:
	seed(9090)
	SaveGuard.stash()
	GameSession.clear()
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game
	game.paddle.set_physics_process(false)
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
	_test_last_brick()
	_test_the_save()
	_test_combo_milestones()
	_test_capsule_snap()
	_test_drone_config()
	_test_session()
	_test_game_center()

	print("--- PHASE 9: %d checks, %d failures ---" % [checks, fails])
	GameSession.clear()
	SaveGuard.restore()
	game.audio.stop_all()
	await get_tree().create_timer(0.4).timeout
	game.free()
	await get_tree().process_frame
	get_tree().quit(1 if fails > 0 else 0)


# --- 1. The last brick --------------------------------------------------

## Exactly once per level, whether a ball took the last brick or a chain
## did. It hangs off the grid's cleared signal, which is emitted once.
func _test_last_brick() -> void:
	game.game_feel.end_slow_motion()
	game._start_new_game()
	game._begin_level()
	ok(not game.game_feel.is_slow(), "a running level is not in slow motion")

	# A chain that takes the whole field: the signal still fires once, on
	# the last brick of the cascade rather than on the one that was hit.
	game.grid.build([".............", ".VEV.........", "............."], 0.0)
	var blast := game.grid.brick_at(2, 1)
	eq(blast.type, Brick.Type.BLAST, "a blast brick to set off")
	var cleared := {"count": 0}
	game.grid.cleared.connect(func() -> void: cleared["count"] += 1)
	game.grid.hit(blast, blast.hits_left)
	for i in 120:
		game.grid._process(1.0 / 60.0)
	eq(cleared["count"], 1, "the field is cleared once, at the end of the chain")
	eq(game.grid.remaining_breakable(), 0, "and the chain took all of it")
	ok(game.game_feel.is_slow(), "which puts the last brick in slow motion")

	# Once. A second clear on the same level cannot start it again.
	game.game_feel.end_slow_motion()
	game._on_level_cleared()
	ok(not game.game_feel.is_slow(), "and it does not fire twice for one level")
	game._process(0.016)
	game.game_feel.end_slow_motion()
	game._set_state(Game.State.TITLE)


# --- 2. The save --------------------------------------------------------

func _test_the_save() -> void:
	game._start_new_game()
	game._begin_level()
	game.game_feel.end_slow_motion()
	game._last_save_ms = -10000.0

	var high := Vector2(195.0, game.arena.ember_line_y() - 200.0)
	ok(not game._try_the_save(high), "a catch in the middle of the field is just a catch")

	var low := Vector2(195.0, game.arena.ember_line_y() - 10.0)
	ok(game._try_the_save(low), "a catch on the line is a save")
	ok(game.game_feel.is_slow(), "and the world stretches for it")

	# Once every three seconds, whatever the ball does down there.
	ok(not game._try_the_save(low), "a second save inside the cooldown does not fire")
	ok(not game._try_the_save(low), "nor a third")
	game._last_save_ms -= Game.SAVE_COOLDOWN_MS + 1.0
	ok(game._try_the_save(low), "and it comes back once the cooldown is up")

	game.game_feel.end_slow_motion()
	game._set_state(Game.State.TITLE)


# --- 3. Combo milestones ------------------------------------------------

## Everything a milestone adds, it takes away again. Asymmetry here is
## how a game ends up with a permanently long tail after one good run.
func _test_combo_milestones() -> void:
	game._start_new_game()
	game._begin_level()
	var ball: Ball = game._balls[0]

	game.combo = 0
	game._apply_combo_milestones()
	ok(not ball.long_trail, "no combo, no tail")
	ok(not game.arena.combo_pulse, "and no field pulse")
	eq(ball.trail_length(), Ball.TRAIL_LENGTH, "the tail is its ordinary length")

	game.combo = 9
	game._apply_combo_milestones()
	ok(not ball.long_trail, "nine is not ten")

	game.combo = 10
	game._apply_combo_milestones()
	ok(ball.long_trail, "ten lengthens the tail")
	eq(ball.trail_length(), Ball.TRAIL_LENGTH + Ball.TRAIL_BONUS, "by four segments")
	ok(not game.arena.combo_pulse, "and ten does not touch the field")

	game.combo = 20
	game._apply_combo_milestones()
	ok(ball.long_trail, "twenty keeps the tail")
	ok(game.arena.combo_pulse, "and sets the field breathing")

	# And back, in one step, the way a paddle hit does it.
	game.combo = 0
	game._apply_combo_milestones()
	ok(not ball.long_trail, "the tail goes back when the combo breaks")
	ok(not game.arena.combo_pulse, "and so does the field")
	eq(ball.trail_length(), Ball.TRAIL_LENGTH, "with nothing left over")
	game._set_state(Game.State.TITLE)


# --- 4. The capsule snap ------------------------------------------------

func _test_capsule_snap() -> void:
	var capsule := Powerup.new()
	add_child(capsule)
	capsule.setup("wide", Vector2(100.0, 100.0), 800.0)
	ok(not capsule.is_snapping(), "a falling capsule is not being caught")
	ok(capsule.snap_to(Vector2(120.0, 140.0)), "and it can be caught")
	ok(capsule.is_snapping(), "then it is being caught")
	ok(not capsule.snap_to(Vector2(0.0, 0.0)), "and it cannot be caught twice")
	ok(not capsule.snap_done(), "the pull takes a moment")
	for i in 4:
		capsule._process(Powerup.SNAP_TIME * 0.5)
	ok(capsule.snap_done(), "and then it has arrived")
	ok(capsule.position.distance_to(Vector2(120.0, 140.0)) < 0.5, "where it was pulled to")
	capsule.queue_free()

	# Through the manager: one capsule, one effect, however many frames
	# the pull takes.
	game._start_new_game()
	game._begin_level()
	var caught: Array[String] = []
	var handler := func(id: String) -> void: caught.append(id)
	game.powerups.collected.connect(handler)
	game.powerups.spawn(Vector2(game.paddle.position.x, game.paddle.top_y() - 40.0))
	ok(not game.powerups._capsules.is_empty(), "a capsule to catch")
	# The capsules are children with their own _process, and a test loop
	# runs inside one engine frame: both have to be driven by hand.
	for i in 60:
		for falling in game.powerups._capsules.duplicate():
			if is_instance_valid(falling):
				falling._process(1.0 / 60.0)
		game.powerups._process(1.0 / 60.0)
	eq(caught.size(), 1, "the catch fires exactly once")
	eq(game.powerups._capsules.size(), 0, "and the capsule is gone")
	game.powerups.collected.disconnect(handler)
	game._set_state(Game.State.TITLE)


# --- 5. The drone -------------------------------------------------------

func _test_drone_config() -> void:
	eq(Audio.DRONE_TUNING.size(), 5, "one drone block per universe")
	for slug in ["baeltet", "isringen", "solvinden", "taagen", "hullet"]:
		ok(Audio.DRONE_TUNING.has(slug), "universe '%s' is tuned" % slug)
		var block: Dictionary = Audio.DRONE_TUNING[slug]
		for key in ["pitch", "cutoff", "layer_pitch", "layer_gain"]:
			ok(block.has(key), "'%s' has %s" % [slug, key])
		var band: Array = block["cutoff"]
		ok(float(band[0]) < float(band[1]), "'%s' opens up with the combo" % slug)
	# The Drift sits high and thin, which is what cold and metallic means
	# on a filter.
	var drift: Dictionary = Audio.DRONE_TUNING["baeltet"]
	var core: Dictionary = Audio.DRONE_TUNING["hullet"]
	ok(float(drift["pitch"]) > float(core["pitch"]), "The Drift is the colder of the two")
	ok(float(drift["cutoff"][0]) > float(core["cutoff"][0]), "and the thinner")
	game.audio.set_universe("baeltet")
	game.audio.set_drone_layer(true)
	game.audio.set_drone_layer(false)
	ok(true, "and the layer can be switched both ways without complaint")


# --- 7. The session -----------------------------------------------------

func _test_session() -> void:
	GameSession.clear()
	game._start_new_game()
	game._begin_level()
	# Play a bit of it: some bricks down, some score, a life gone.
	var live := game.grid.live_bricks()
	for i in mini(6, live.size()):
		game.grid.hit(live[i], live[i].hits_left)
	game.score = 4200
	game.run.lives = 2
	var bricks_left := game.grid.remaining_breakable()
	var level_id := int(game.level_data["id"])

	# Something in flight, which is not kept.
	game.powerups.spawn(Vector2(120.0, 300.0))
	ok(not game.powerups._capsules.is_empty(), "a capsule in flight")

	game._store_session()
	ok(GameSession.has_session(), "backgrounding writes the level down")

	# The app dies here. Everything in memory goes with it.
	game._set_state(Game.State.TITLE)
	game._load_level(0)
	game.score = 0
	game.run.lives = 3

	ok(game._restore_session(), "and it comes back")
	eq(int(game.level_data["id"]), level_id, "the same level")
	eq(game.grid.remaining_breakable(), bricks_left, "the wall as it was")
	eq(game.score, 4200, "the score as it was")
	eq(game.lives, 2, "the lives as it was")
	eq(game._balls.size(), 1, "one ball")
	ok(game._balls[0].stuck, "glued to the paddle, waiting to be fired")
	eq(game.powerups._capsules.size(), 0, "and the capsules are gone, as documented")

	# A cleared level takes its session with it.
	game._set_state(Game.State.PLAYING)
	game._begin_clear_ceremony()
	ok(not GameSession.has_session(), "a cleared level leaves no session behind")

	# So does walking out of one on purpose.
	game._start_new_game()
	game._begin_level()
	game._store_session()
	ok(GameSession.has_session(), "a level in flight is written down")
	game._on_screen_action("menu")
	ok(not GameSession.has_session(), "and leaving for the menu gives it up")

	# A session that does not fit the level it claims is refused rather
	# than half-applied.
	GameSession.store(0, 999, 100, 3, [1, 2, 3], 0.0, 0, 0)
	ok(not game._restore_session(), "a session from another level is refused")
	ok(not GameSession.has_session(), "and thrown away")
	game._set_state(Game.State.TITLE)


# --- 6. Game Center -----------------------------------------------------

## Offline, on a Mac, in a test: every call is a no-op that says so.
func _test_game_center() -> void:
	GameCenterLink.forget()
	ok(not GameCenterLink.is_available(), "no plugin here, so no Game Center")
	ok(not GameCenterLink.is_signed_in(), "and nobody is signed in")
	ok(not GameCenterLink.authenticate(), "authenticating says no rather than waiting")
	ok(not GameCenterLink.submit_total_stars(12), "a score goes nowhere")
	ok(not GameCenterLink.submit_level_score(1, 4200), "and so does a level score")
	ok(not GameCenterLink.report("first_breach"), "and an achievement goes nowhere")

	# The ids are a contract with App Store Connect, and the game only
	# ever reports ones that exist.
	eq(GameCenterLink.ACHIEVEMENTS.size(), 10, "ten achievements")
	for id in ["first_breach", "chain_of_five", "clean_sweep", "the_drift_cleared"]:
		ok(GameCenterLink.ACHIEVEMENTS.has(id), "'%s' is one of them" % id)
	for id in GameCenterLink.ACHIEVEMENTS:
		var name := str(GameCenterLink.ACHIEVEMENTS[id])
		ok(name == name.to_upper(), "'%s' is in the game's voice" % name)
		ok(not name.contains("!"), "and carries no exclamation mark")
	eq(GameCenterLink.BOARD_TOTAL_STARS, "astroball.stars.total", "the stars board id")

	# Reporting one twice is refused whether or not there is a platform,
	# so the rule is testable from here.
	GameCenterLink.forget()
	GameCenterLink.report("clean_sweep")
	ok(not GameCenterLink.report("clean_sweep"), "an achievement is reported once")
	GameCenterLink.forget()

	# And a level cleared with no platform under it does not fall over.
	game._start_new_game()
	game._begin_level()
	game._report_clear(1, GameProgress.ALL_STARS)
	ok(true, "a cleared level reports into nothing without complaint")
	game._set_state(Game.State.TITLE)
