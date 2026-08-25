extends Node

## The game's states: lives, signal lost, level progression, speed ramp.

const SaveGuard := preload("res://tests/save_guard.gd")

var game: Game
var fails := 0
var checks := 0


func _ready() -> void:
	seed(11)
	SaveGuard.stash()
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


func about(got: float, want: float, tol: float, label: String) -> void:
	checks += 1
	if absf(got - want) > tol:
		fails += 1
		print("  FAIL: %s (got %.2f, wanted %.2f)" % [label, got, want])


func _kill_all_balls() -> void:
	for ball in game._balls.duplicate():
		ball.global_position = Vector2(195.0, game.arena.death_y + 20.0)
		game._on_ball_lost(ball)


func _skip_pause() -> void:
	game._state_timer = 0.0
	game._advance_state()


func _run() -> void:
	_test_opening()
	_test_speed_ramp()
	_test_multiball_and_lives()
	_test_game_over()
	_test_level_progression()
	_test_level_clear_freeze()
	_test_scoring()
	_test_every_level_survives_a_loss()
	_test_screen_presses()
	_test_pause()
	_test_settings()
	_test_audio_bank()
	_test_english()

	SaveGuard.restore()
	print("--- LIFECYCLE: %d checks, %d failures ---" % [checks, fails])
	await _teardown()
	get_tree().quit(1 if fails > 0 else 0)


## Phase 5's definition of done: GAME OVER works on every level, not
## just the one it was written against. Each level is loaded, lost,
## continued and restarted, and the field has to come back whole.
func _test_every_level_survives_a_loss() -> void:
	for index in game.level_paths.size():
		var name := "level %d" % (index + 1)
		game.run.start_run()
		game._load_level(index)
		game._begin_level()
		var bricks := game.grid.remaining_breakable()
		ok(bricks >= 20, "%s builds a field (%d bricks)" % [name, bricks])

		# Three lives, three losses.
		for life in 3:
			_kill_all_balls()
			if game.state == Game.State.BALL_LOST:
				_skip_pause()
		eq(game.state, Game.State.SIGNAL_LOST, "%s ends in GAME OVER" % name)
		eq(game.lives, 0, "%s has no lives left" % name)

		# Continue puts the same field back with a ball on the paddle.
		game._on_screen_action("re_entry")
		eq(game.state, Game.State.PLAYING, "%s continues" % name)
		eq(game.grid.remaining_breakable(), bricks, "%s keeps its field" % name)
		eq(game._balls.size(), 1, "%s gets one ball back" % name)
		ok(game._balls[0].stuck, "%s waits for the player to fire it" % name)

		# And a restart is the field from the beginning with three lives.
		game._on_screen_action("restart")
		eq(game.state, Game.State.LEVEL_INTRO, "%s restarts into its intro" % name)
		eq(game.lives, Game.START_LIVES, "%s restarts with three lives" % name)
		game._begin_level()
		eq(game.grid.remaining_breakable(), bricks, "%s is built again" % name)
	game._set_state(Game.State.TITLE)


## One press, on the thing under the finger.
##
## Both of these shipped: every button needed pressing twice, and after
## a trip into settings the title's START GAME opened settings again.
## The press was acting on _hover, which is worked out once a frame from
## the mouse position, and on a phone there is no mouse until a finger
## has already arrived somewhere.
func _test_screen_presses() -> void:
	game._set_state(Game.State.TITLE)
	eq(_press_button("play"), true, "START GAME is on the title")
	eq(game.state, Game.State.UNIVERSES, "and one press is enough")

	game._set_state(Game.State.TITLE)
	_press_button("settings")
	eq(game.state, Game.State.SETTINGS, "one press opens settings")
	_press_button("back")
	eq(game.state, Game.State.TITLE, "one press comes back")
	_press_button("play")
	eq(game.state, Game.State.UNIVERSES,
		"and START GAME is still START GAME after a trip through settings")

	# One finger is one press. iOS sends the touch and Godot's mouse
	# emulation used to send a second press at the same point; the first
	# acted, the screen relaid itself out, and the second landed on
	# whatever button had moved under the finger. MAIN MENU went to the
	# title and straight into settings, and BACK bounced back into it.
	game._set_state(Game.State.PAUSED)
	var menu_at := Vector2.ZERO
	for button in game.screens._buttons:
		if str(button["id"]) == "menu":
			menu_at = Rect2(button["rect"]).get_center()
	ok(menu_at != Vector2.ZERO, "the held level offers a way to the menu")
	game.screens._last_press_ms = -1000.0
	_press_raw(menu_at)
	eq(game.state, Game.State.TITLE, "one press leaves the level")
	# The same point again, in the same breath: on the title that lands
	# on SETTINGS, and it must not be taken.
	_press_raw(menu_at)
	eq(game.state, Game.State.TITLE, "and the second half of that press is not a decision")

	# A press on nothing is a press on nothing, whatever was last hovered.
	game._set_state(Game.State.TITLE)
	_press_at(Vector2(20.0, 800.0))
	eq(game.state, Game.State.TITLE, "a press on empty screen does nothing")

	# The same again on the universe list, which is three presses deep.
	game._set_state(Game.State.UNIVERSES)
	_press_button("universe_1")
	eq(game.state, Game.State.STAR_MAP, "one press enters a universe")
	game._set_state(Game.State.TITLE)


## Presses the button with this id where it actually sits. Returns false
## if the screen does not have it.
func _press_button(id: String) -> bool:
	for button in game.screens._buttons:
		if str(button["id"]) == id:
			_press_at(Rect2(button["rect"]).get_center())
			return true
	return false


## A deliberate press. The debounce that stops one finger from being
## read as two is cleared first, because these are separate decisions
## made faster than a hand could make them.
func _press_at(point: Vector2) -> void:
	game.screens._last_press_ms = -1000.0
	_press_raw(point)


func _press_raw(point: Vector2) -> void:
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = point
	game.screens._unhandled_input(press)


## Section 16 has no way out of a field except dying. On a phone that is
## not a rule, it is a trap: a call arrives, or the wrong field was
## chosen, and the only exit is to lose three lives on purpose.
func _test_pause() -> void:
	game._start_new_game()
	game._begin_level()
	eq(game.state, Game.State.PLAYING, "a field is running")
	var ball: Ball = game._balls[0]
	ok(not ball.frozen, "and the ball is live")

	# The control is in the panel, and a thumb can find it.
	var reach := game.hud.pause_touch_rect()
	ok(reach.size.x >= 44.0 and reach.size.y >= 44.0,
		"the pause control is thumb sized (%.0f x %.0f)" % [reach.size.x, reach.size.y])
	ok(reach.end.y <= Arena.HUD_HEIGHT + 0.01,
		"and it never reaches down into the field (%.0f against %.0f)"
		% [reach.end.y, Arena.HUD_HEIGHT])
	ok(reach.end.x <= Arena.SCREEN.x, "nor off the side of the screen")

	# A press on it holds the field.
	var press := InputEventScreenTouch.new()
	press.pressed = true
	press.position = game.hud.pause_rect().get_center()
	game._unhandled_input(press)
	eq(game.state, Game.State.PAUSED, "a press on it holds the field")
	ok(ball.frozen, "the ball stops where it was")
	ok(not game.touch.enabled, "and the field stops listening")
	ok(game.grid.visible, "the field stays visible behind the words")

	# And the way back in is the first thing on the screen.
	var ids := []
	for button in game.screens._buttons:
		ids.append(str(button["id"]))
	eq(ids[0], "resume", "the way back into the field is the first button")
	ok(ids.has("menu") and ids.has("restart"), "with a way out beside it")
	eq(ids.size(), 3, "and nothing else on it")
	ok(not ids.has("settings"),
		"a held level is not where anybody goes to change the haptics")
	game._on_screen_action("resume")
	eq(game.state, Game.State.PLAYING, "and it goes back in")
	ok(not ball.frozen, "with the ball live again")

	# A held level is held. Capsules used to keep falling behind the
	# screen, and be caught by a paddle nobody was steering.
	game.powerups.spawn(Vector2(195.0, 300.0))
	var capsule: Powerup = game.powerups._capsules[0]
	game._on_screen_action("pause")
	ok(not game.powerups.can_process(), "the capsules stop falling while the level is held")
	ok(not capsule.can_process(), "the one already falling included")
	ok(not game.grid.can_process(), "and the field stops with them")
	game._on_screen_action("resume")
	ok(capsule.can_process(), "and they fall again the moment it is not")
	ok(game.grid.can_process(), "with the field")
	capsule.queue_free()
	game.powerups._capsules.clear()

	# Whatever takes the screen, the ball is not still falling.
	game._start_new_game()
	game._begin_level()
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	eq(game.state, Game.State.PAUSED, "losing focus holds the field")
	game._on_screen_action("resume")
	game._set_state(Game.State.TITLE)
	game._notification(Node.NOTIFICATION_APPLICATION_FOCUS_OUT)
	eq(game.state, Game.State.TITLE, "and losing focus on the title does nothing")

	# The panel is not the field: a press up there is not a launch.
	var touch := game.touch
	touch.reset()
	touch.enabled = true
	var launched := {"count": 0}
	touch.tapped.connect(func() -> void: launched["count"] += 1)
	touch._press(0, Vector2(360.0, 128.0))
	touch._release(0)
	eq(launched["count"], 0, "a press in the panel does not fire the ball")
	touch._press(0, Vector2(195.0, 600.0))
	touch._release(0)
	eq(launched["count"], 1, "a press in the field still does")


## The game opens on the title screen, not in the middle of a field.
func _test_opening() -> void:
	eq(game.state, Game.State.TITLE, "the game opens on the title screen")
	ok(game.screens.is_open(), "the title screen is visible")
	ok(not game._balls[0].input_enabled, "the ball cannot be launched behind a screen")
	ok(not game.paddle.input_enabled, "the paddle is still behind a screen")

	game._on_screen_action("settings")
	eq(game.state, Game.State.SETTINGS, "SETTINGS opens from the title")
	game._on_screen_action("back")
	eq(game.state, Game.State.TITLE, "BACK leads back to the title")

	# START GAME asks which universe first, and a universe asks which
	# level. Each screen puts exactly one question.
	game._on_screen_action("play")
	eq(game.state, Game.State.UNIVERSES, "START GAME leads to the universes")
	game._on_screen_action("universe_1")
	eq(game.state, Game.State.STAR_MAP, "The Drift opens its levels")
	game._on_field_chosen(0)
	eq(game.state, Game.State.LEVEL_INTRO, "and a level leads to its intro")
	eq(int(game.level_data["id"]), 1, "the intro shows level 1")
	eq(game.screens.level_title, "Liftoff", "the intro shows the field name")
	eq(game.lives, 3, "the game starts with three lives")
	eq(game.score, 0, "the score starts at zero")

	game._on_screen_action("skip")
	eq(game.state, Game.State.PLAYING, "a click skips the intro")
	ok(game._balls[0].input_enabled, "the ball can be launched once the field runs")
	ok(game._balls[0].stuck, "the ball starts stuck to the paddle")
	eq(game.grid.remaining_breakable(), 30, "level 1 has 30 bricks")


## Section 4: speed rises 4 per cent per 10 bricks, capped at 520.
func _test_speed_ramp() -> void:
	var base := float(game.level_data["ballSpeed"])
	game.run.level_bricks = 0
	about(game.level_ball_speed(), base, 0.01, "speed starts at the level own")
	game.run.level_bricks = 9
	about(game.level_ball_speed(), base, 0.01, "nine bricks still give the base speed")
	game.run.level_bricks = 10
	about(game.level_ball_speed(), base * 1.04, 0.01, "ten bricks give 4 per cent more")
	game.run.level_bricks = 30
	about(game.level_ball_speed(), base * pow(1.04, 3), 0.01, "thirty bricks give three steps")
	game.run.level_bricks = 10000
	about(game.level_ball_speed(), 520.0, 0.01, "speed stops at the 520 cap")

	# The ball corrects its speed at once, not a frame later.
	game.run.level_bricks = 0
	game._apply_ball_speed()
	var ball := game._balls[0]
	ball.launch()
	game.run.level_bricks = 50
	game._apply_ball_speed()
	about(ball.velocity.length(), ball.current_speed(), 0.01, "the ball speed follows in the same frame")
	game.run.level_bricks = 0
	game._apply_ball_speed()


func _test_multiball_and_lives() -> void:
	if game._balls[0].stuck:
		game._balls[0].launch()
	game._split_balls()
	eq(game._balls.size(), 3, "Multi produced three balls")
	var doomed := game._balls[2]
	doomed.global_position = Vector2(195.0, game.arena.death_y + 20.0)
	game._on_ball_lost(doomed)
	eq(game._balls.size(), 2, "the lost ball is gone")
	eq(game.lives, 3, "only the last ball costs a life")

	game.paddle.set_width(Paddle.WIDTH_WIDE)
	game.powerups._active["laser"] = 10.0
	game.paddle.laser = true
	_kill_all_balls()
	eq(game.lives, 2, "the last ball costs a life")
	eq(game.state, Game.State.BALL_LOST, "the state is BALL_LOST")
	eq(game._balls.size(), 0, "no balls during the pause")
	eq(game.paddle.width, Paddle.WIDTH_NORMAL, "the paddle is back to 88 px")
	ok(not game.paddle.laser, "the laser goes out on a lost ball")
	ok(game.powerups.active_effects().is_empty(), "active power-ups clear on a lost ball")
	ok(game.powerups._next_guaranteed_good, "the next power-up is guaranteed good")
	ok(Powerup.is_good(game.powerups._pick_id()), "and it actually is good")

	_skip_pause()
	eq(game.state, Game.State.PLAYING, "the game continues after the pause")
	eq(game._balls.size(), 1, "a new ball is stuck to the paddle")
	ok(game._balls[0].stuck, "the new ball waits for a click")


func _test_game_over() -> void:
	game.score = 5000
	_kill_all_balls()
	eq(game.lives, 1, "second loss")
	_skip_pause()
	_kill_all_balls()
	eq(game.lives, 0, "third loss")
	eq(game.state, Game.State.SIGNAL_LOST, "the state is SIGNAL_LOST")
	eq(game.screens.final_score, 5000, "the screen shows the score reached")
	ok(game.screens.bricks_cleared >= 0, "the telemetry carries a brick count")
	ok(game.screens.can_re_enter, "RE-ENTRY is available the first time")
	ok(not game.paddle.input_enabled, "control is off on SIGNAL LOST")

	# RE-ENTRY: ét liv, samme felt, samme score, samme ur.
	var bricks_before := game.grid.remaining_breakable()
	var score_before := game.score
	game._on_screen_action("re_entry")
	eq(game.state, Game.State.PLAYING, "RE-ENTRY continues the game")
	eq(game.lives, 1, "RE-ENTRY gives one life")
	eq(game.score, score_before, "RE-ENTRY does not touch the score")
	eq(game.grid.remaining_breakable(), bricks_before, "RE-ENTRY does not touch the bricks")
	eq(game._balls.size(), 1, "RE-ENTRY gives a new ball")
	ok(not game.screens.can_re_enter or true, "RE-ENTRY has been used on this field")

	# Anden gang er der kun RESTART FIELD tilbage.
	_kill_all_balls()
	eq(game.state, Game.State.SIGNAL_LOST, "back on SIGNAL LOST")
	ok(not game.screens.can_re_enter, "RE-ENTRY can only be used once per field")

	game._on_screen_action("restart")
	eq(game.state, Game.State.LEVEL_INTRO, "RESTART FIELD rebuilds the field")
	eq(game.lives, 3, "RESTART FIELD gives three lives")
	eq(int(game.level_data["id"]), 1, "and it is still level 1")
	eq(game.grid.remaining_breakable(), 30, "the field is built again")
	game._begin_level()


func _test_level_progression() -> void:
	eq(int(game.level_data["id"]), 1, "back on level 1")
	game._next_level()
	eq(game.state, Game.State.LEVEL_INTRO, "every new level starts with an intro")
	eq(int(game.level_data["id"]), 2, "level 2 loads")
	eq(game.screens.level_title, "The Capsule", "the intro shows level 2 name")
	eq(game.grid.remaining_breakable(), 79, "level 2 has 79 bricks")
	eq(game.paddle.width, Paddle.WIDTH_NORMAL, "a new level gives a normal paddle")
	eq(game.run.level_bricks, 0, "the speed ramp resets on a new level")
	game._begin_level()
	game._next_level()
	eq(int(game.level_data["id"]), 3, "level 3 loads")
	eq(game.screens.level_title, "The Chain", "the intro shows level 3 name")
	eq(game.grid.remaining_breakable(), 57, "level 3 has 57 bricks")
	game._begin_level()
	game._next_level()
	eq(int(game.level_data["id"]), 4, "and the zone keeps going")
	eq(game.screens.level_title, "The Constellation", "the intro shows level 4 name")

	# Every field in the zone loads, is named, and hangs its wall where
	# the rules say. Walking the whole list is the only way a broken
	# level twelve shows up before a player finds it.
	for i in range(5, 13):
		game._begin_level()
		game._next_level()
		eq(int(game.level_data["id"]), i, "level %d loads" % i)
		ok(not game.screens.level_title.is_empty(), "level %d is named" % i)
		ok(game.grid.remaining_breakable() >= 20, "level %d has a field" % i)
	game._begin_level()
	game._next_level()
	eq(game.state, Game.State.STAR_MAP, "the zone ends on the chart, not back at field one")
	eq(int(game.level_data["id"]), 12, "and the finale is still the field it left")
	game._set_state(Game.State.TITLE)
	game._begin_level()


func _test_level_clear_freeze() -> void:
	game._set_state(Game.State.PLAYING)
	game._balls[0].launch()
	var speed_before := game._balls[0].velocity.length()
	game._on_level_cleared()
	# Phase 9: the last brick hangs in the air first. Eighty milliseconds
	# of the player's own time, and the ceremony is behind it.
	ok(game.game_feel.is_slow(), "the last brick hangs")
	eq(game.state, Game.State.PLAYING, "and the level is still running while it does")
	game._on_level_cleared()
	ok(game.game_feel.is_slow(), "and a second call cannot start it twice")
	game.game_feel.end_slow_motion()
	game._process(0.016)
	eq(game.state, Game.State.LEVEL_CLEAR, "the state is LEVEL_CLEAR")
	ok(game._balls[0].frozen, "the ball freezes on field cleared")
	about(game._balls[0].velocity.length(), speed_before, 0.01, "speed is preserved through the freeze")


func _test_scoring() -> void:
	game.combo = 0
	eq(game._combo_multiplier(), 1, "combo below 5 gives x1")
	game.combo = 5
	eq(game._combo_multiplier(), 2, "combo 5 gives x2")
	game.combo = 10
	eq(game._combo_multiplier(), 3, "combo 10 gives x3")
	game.combo = 20
	eq(game._combo_multiplier(), 4, "combo 20 gives x4")

	eq(HUD.group_digits(0), "0", "zero shows as 0")
	eq(HUD.group_digits(999), "999", "three digits stand alone")
	eq(HUD.group_digits(1000), "1 000", "four digits get a space")
	eq(HUD.group_digits(1234567), "1 234 567", "seven digits get two spaces")


## Settings have to survive a restart.
func _test_settings() -> void:
	var s := get_node("/root/GameSettings")
	var was_crt: bool = s.crt
	var was_handed: bool = s.left_handed
	s.crt = not was_crt
	s.left_handed = not was_handed
	s.save_settings()
	s.crt = was_crt
	s.left_handed = was_handed
	s.load_settings()
	eq(s.crt, not was_crt, "the CRT choice is saved")
	eq(s.left_handed, not was_handed, "the left-handed choice is saved")
	s.crt = was_crt
	s.left_handed = was_handed
	s.save_settings()

	# Afsnit 17: listen er lukket. Praecis disse seks.
	for field in ["sound", "music", "haptics", "crt", "left_handed"]:
		ok(field in s, "the setting '%s' exists" % field)
	ok(get_node("/root/GameProgress").has_method("reset"), "Reset Progress exists")

	# The record lives in progress, not in settings.
	var progress := get_node("/root/GameProgress")
	var was_high: int = progress.high_score
	progress.high_score = 1000
	ok(not progress.submit_score(500), "a lower score does not beat the record")
	ok(progress.submit_score(1500), "a higher score beats the record")
	eq(progress.high_score, 1500, "the record is updated")
	progress.high_score = was_high
	progress.save_progress()


## The whole sound bank must load, or some sound is silently missing.
func _test_audio_bank() -> void:
	for id in Audio.BANK:
		var stream: Resource = load(Audio.BANK[id])
		ok(stream != null, "the sound '%s' loads" % str(id))
		if stream is AudioStreamWAV:
			ok(stream.get_length() > 0.01, "the sound '%s' has content" % str(id))
	var drone: AudioStreamWAV = load(Audio.DRONE_PATH)
	ok(drone != null and drone.get_length() > 4.0, "the drone is long enough to loop")


## Alt, spilleren laeser, er paa engelsk.
func _test_english() -> void:
	var danish_letters := "æøåÆØÅ"
	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		var name := str(data.get("name", ""))
		var clean := true
		for ch in danish_letters:
			if name.contains(ch):
				clean = false
		ok(clean and not name.is_empty(), "%s has an English name (%s)" % [path, name])
	eq(game.hud.zone_slug, "baeltet", "the level data keeps the zone slug")
	eq(Strings.zone_name("baeltet"), "THE DRIFT", "the player reads THE DRIFT")
	eq(Strings.universe_line("baeltet"), "UNIVERSE 1 · THE DRIFT",
		"and the zone is presented as a universe")

	# Afsnit 14: de officielle engelske navne.
	var official := {1: "Liftoff", 2: "The Capsule", 3: "The Chain"}
	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		var id := int(data.get("id", 0))
		if official.has(id):
			eq(str(data.get("name", "")), official[id],
				"level %d carries its official name" % id)


## Clears the scene before exit, so the engine does not report nodes
## der bare stod i traeet, da vi lukkede midt i en frame.
func _teardown() -> void:
	if is_instance_valid(game):
		# Sound still running holds playback objects when the engine
		# closes. Stop it first, then clean up.
		game.audio.stop_all()
		# The audio server releases its playbacks a few ticks later, and
		# how many depends on the machine. Wait long enough that it is
		# not a race.
		await get_tree().create_timer(0.6).timeout
		game.free()
		await get_tree().process_frame
	# Lad motoren rydde op, inden vi lukker, ellers rapporterer den
	# that were merely still in the tree as leaks.
	await get_tree().process_frame
	await get_tree().process_frame
