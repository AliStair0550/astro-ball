class_name Game
extends Node2D

## The conductor.
##
## None of the other scripts know each other. The ball does not know
## what a score is, the grid does not know power-ups exist, the screens
## do not know what a level is, and the background only knows that
## something happened somewhere. It all meets here.

enum State { TITLE, UNIVERSES, SETTINGS, STAR_MAP, PAUSED, LEVEL_INTRO, PLAYING, BALL_LOST, LEVEL_CLEAR, FINALE, SIGNAL_LOST }

const START_LIVES := LevelState.START_LIVES
const MAX_BALLS := 6
const BALL_LOST_PAUSE := 0.5
const LEVEL_INTRO_PAUSE := 1.6
const LEVEL_CLEAR_PAUSE := 3.0

## Hitstop. 16 ms on a brick, 60 on a blast. It is what gives the blast
## brick its weight.
const HITSTOP_BRICK := 0.016
const HITSTOP_HARDENED := 0.012
const HITSTOP_BLAST := 0.06

## The last brick of a level, in slow motion. Eighty milliseconds of the
## player's own time, not of the clock's, and exactly once per level: it
## hangs off the grid's cleared signal, which fires on the last brick to
## die whether a ball hit it or a chain took it.
const LAST_BRICK_SCALE := 0.25
const LAST_BRICK_TIME := 0.08

## The save: a catch inside thirty pixels of the line.
const SAVE_REACH := 30.0
const SAVE_SCALE := 0.6
const SAVE_TIME := 0.12
const SAVE_COOLDOWN_MS := 3000.0

## What a combo is worth beyond points.
const COMBO_TRAIL_AT := 10
const COMBO_FIELD_AT := 20

## A chain throws its shards half again as fast as a ball does.
const CHAIN_SHARD_SPEED := 1.6

const SHAKE_WALL := Vector2(2.0, 0.06)
const SHAKE_BLAST := Vector2(6.0, 0.12)

@onready var game_feel: GameFeel = $GameFeel
@onready var touch: TouchInput = $TouchInput
@onready var background: Background = $Background
@onready var arena: Arena = $Arena
@onready var grid: BrickGrid = $BrickGrid
@onready var paddle: Paddle = $Paddle
@onready var balls_root: Node2D = $Balls
@onready var powerups: PowerupManager = $Powerups
@onready var effects: Effects = $Effects
@onready var audio: Audio = $Audio
@onready var hud: HUD = $HUDLayer/HUD
@onready var screens: Screens = $ScreenLayer/Screens
@onready var star_map: StarMap = $ScreenLayer/StarMap
@onready var crt: CRT = $CRTLayer/CRT
@onready var _debug_label: Label = $HUDLayer/Debug

var state := State.TITLE

## The numbers live in LevelState. These stay as the conductor's public
## surface so nothing else has to know where they moved to.
var run := LevelState.new()

var score: int:
	get:
		return run.score
	set(value):
		run.score = value
var lives: int:
	get:
		return run.lives
	set(value):
		run.lives = value
var combo: int:
	get:
		return run.combo
	set(value):
		run.combo = value
var best_combo: int:
	get:
		return run.best_combo
	set(value):
		run.best_combo = value

var level_index := 0
var level_data: Dictionary = {}
var level_paths: PackedStringArray
## Section 10, level 11. Set per level, and not cleared by a power-up
## running out: the field is blind because it is that field.
var _level_blind := false
## Whether SETTINGS was opened from a paused field or from the title.
var _settings_from_pause := false
var _meta_cache: Array[Dictionary] = []
## Section 18. Debug builds only, and off unless somebody asks for it.
var recording := false
## How much of the finale has already been heard, so the notes are not
## played twice when it is run to the end by a press.
var _last_save_ms := -10000.0
## The ceremony waits for the slow motion to finish.
var _clear_pending := false
## How many bricks the chain running right now has taken.
var _chain_run := 0
var _finale_stars := 0
var _finale_lines := 0

var _balls: Array[Ball] = []
## Section 16 and 19: a re-entry is free in the paid version and costs a
## rewarded ad in the free one. Neither a store nor an ad network is in
## this build, so the gate answers FREE. What matters is that the branch
## and the wiring exist, so the ad layer plugs in without touching this
## file. See scripts/continue_gate.gd.
var continue_gate := ContinueGate.new()
## Where the ball last touched a brick. The shards fly away from it.
var _last_impact := Vector2.INF
var _state_timer := 0.0
var _debug := false
## Stars still waiting to be heard landing on the clear screen.
var _star_sounds := 0
var _star_sound_timer := 0.0


func _ready() -> void:
	# Before anything measures the field: the panel grows to clear the
	# notch, and every derived position follows from that.
	Arena.apply_safe_area()

	background.screen_size = Arena.SCREEN
	effects.screen_size = Arena.SCREEN
	hud.screen_size = Arena.SCREEN
	screens.screen_size = Arena.SCREEN
	crt.screen_size = Arena.SCREEN

	paddle.set_bounds(arena.inner_rect().position.x, arena.inner_rect().end.x)
	paddle.position = Vector2(Arena.SCREEN.x * 0.5, Arena.FIELD_BOTTOM - 65.0)

	powerups.paddle = paddle
	powerups.kill_y = arena.death_y
	powerups.collected.connect(_on_powerup_collected)
	powerups.rolling.connect(_on_lottery_rolling)
	powerups.expired.connect(_on_powerup_expired)

	grid.brick_damaged.connect(_on_brick_damaged)
	grid.brick_destroyed.connect(_on_brick_destroyed)
	grid.brick_revealed.connect(_on_brick_revealed)
	grid.stone_popped.connect(_on_stone_popped)
	grid.cleared.connect(_on_level_cleared)

	paddle.laser_fired.connect(_on_laser_fired)
	screens.action.connect(_on_screen_action)
	star_map.screen_size = Arena.SCREEN
	star_map.chosen.connect(_on_field_chosen)
	star_map.action.connect(_on_map_action)
	touch.steered.connect(_on_steered)
	touch.tapped.connect(_on_tapped)
	continue_gate.granted.connect(_on_continue_granted)
	continue_gate.denied.connect(_on_continue_denied)

	level_paths = LevelLoader.level_paths()
	if level_paths.is_empty():
		push_error("No levels in res://levels")
		return

	# A level left in flight comes back held rather than running: the
	# player decides when it starts again, which is the whole point of
	# it having been interrupted.
	# A test build says so once, and then never again.
	if OS.is_debug_build() and not GameSettings.seen_test_notice:
		screens.show_test_notice = true
		GameSettings.seen_test_notice = true
		GameSettings.save_settings()

	if _restore_session():
		_set_state(State.PAUSED)
	else:
		_load_level(0)
		_set_state(State.TITLE)
	_debug_label.visible = false


# --- States ------------------------------------------------------------

func _set_state(new_state: State) -> void:
	state = new_state
	_state_timer = 0.0
	# No screen is ever entered in slow motion.
	if new_state != State.PLAYING:
		game_feel.end_slow_motion()

	var overlay := Screens.Screen.NONE
	match state:
		State.TITLE:
			overlay = Screens.Screen.TITLE
		State.UNIVERSES:
			overlay = Screens.Screen.UNIVERSES
			screens.universes = _universe_rows()
		State.SETTINGS:
			overlay = Screens.Screen.SETTINGS
		State.PAUSED:
			overlay = Screens.Screen.PAUSED
		State.LEVEL_INTRO:
			overlay = Screens.Screen.LEVEL_INTRO
			_state_timer = LEVEL_INTRO_PAUSE
		State.LEVEL_CLEAR:
			overlay = Screens.Screen.LEVEL_CLEAR
			_state_timer = LEVEL_CLEAR_PAUSE
			_star_sound_timer = 0.0
		State.FINALE:
			overlay = Screens.Screen.FINALE
			_finale_stars = 0
			_finale_lines = 0
		State.SIGNAL_LOST:
			overlay = Screens.Screen.SIGNAL_LOST
		State.BALL_LOST:
			_state_timer = BALL_LOST_PAUSE

	screens.level_number = int(level_data.get("id", 1))
	screens.level_title = str(level_data.get("name", ""))
	screens.zone_slug = str(level_data.get("zone", "baeltet"))
	screens.final_score = score
	screens.bricks_cleared = run.run_bricks
	screens.best_combo = run.best_combo
	screens.run_time = run.run_time
	screens.can_re_enter = continue_gate.available(_re_entries_used())
	screens.re_entry_costs_ad = continue_gate.cost_for(_re_entries_used()) == ContinueGate.Cost.WATCH_AD
	screens.show_screen(overlay)
	if state != State.STAR_MAP:
		star_map.close()

	# Section 16: SIGNAL LOST is a black screen with the star field at
	# 20 per cent. Title and settings sit over the bare stars too. Bricks
	# and shield behind a readout are noise, not atmosphere.
	var field_visible := state != State.TITLE and state != State.SETTINGS \
		and state != State.SIGNAL_LOST and state != State.STAR_MAP \
		and state != State.UNIVERSES
	arena.visible = field_visible
	grid.visible = field_visible
	paddle.visible = field_visible
	balls_root.visible = field_visible
	powerups.visible = field_visible
	effects.visible = field_visible

	var interactive := state == State.PLAYING
	touch.enabled = interactive
	touch.dead_zone_top = Arena.HUD_HEIGHT
	# Capsules fall in the field's own time. Behind a full screen they
	# used to keep falling, keep being caught by a paddle nobody was
	# steering, and run the clock down on everything already active.
	# A lost ball and a cleared level are not that: their effects have to
	# play out, so only the states that put a screen over everything stop
	# the field.
	var suspended := state == State.TITLE or state == State.UNIVERSES \
		or state == State.SETTINGS or state == State.STAR_MAP \
		or state == State.PAUSED or state == State.SIGNAL_LOST \
		or state == State.FINALE
	# process_mode, not set_process: the capsules are children of the
	# manager and have their own _process. Switching off the parent's
	# left them falling exactly as before, which is the bug this is here
	# to fix. A disabled mode is inherited; a disabled process is not.
	var mode := Node.PROCESS_MODE_DISABLED if suspended else Node.PROCESS_MODE_INHERIT
	powerups.process_mode = mode
	effects.process_mode = mode
	grid.process_mode = mode
	if not interactive:
		# A finger that dismissed a screen must not also steer or launch.
		touch.reset()
	paddle.input_enabled = interactive
	for ball in _balls:
		ball.input_enabled = interactive
		ball.frozen = not interactive

	if state == State.PLAYING:
		audio.start_drone()
	else:
		audio.stop_drone()

	_refresh_hud()


func _on_screen_action(name: String) -> void:
	match name:
		"hover":
			audio.play("ui_move", 1.0, -6.0)
		"play":
			audio.play("ui_select")
			_set_state(State.UNIVERSES)
		"chart":
			audio.play("ui_select")
			_open_chart(false)
		"universe_1":
			audio.play("ui_select")
			_open_chart(false)
		"universe_2", "universe_3", "universe_4", "universe_5":
			# Nothing to enter yet. The tile says so; the sound agrees.
			audio.play("ui_back", 0.8, -6.0)
		"pause":
			audio.play("ui_move", 0.8, -4.0)
			_set_state(State.PAUSED)
		"re_entry":
			audio.play("ui_select")
			continue_gate.request(_re_entries_used())
		"restart":
			# The field from the start, three lives, level score cleared.
			audio.play("ui_select")
			GameSession.clear()
			run.restart_level()
			_load_level(level_index)
			_set_state(State.LEVEL_INTRO)
		"arm_reset":
			audio.play("ui_move")
		"reset_progress":
			audio.play("ui_back")
			GameProgress.reset()
		"settings":
			audio.play("ui_select")
			# Settings from a paused field must come back to the field,
			# not to the title, or the pause has eaten the run.
			_settings_from_pause = state == State.PAUSED
			_set_state(State.SETTINGS)
		"resume":
			audio.play("ui_select")
			_set_state(State.PLAYING)
		"menu":
			# Leaving on purpose gives the level up. Coming back to the
			# title with a level still saved would mean two truths about
			# where the player is.
			audio.play("ui_back")
			GameSession.clear()
			_set_state(State.TITLE)
		"back":
			audio.play("ui_back")
			if _settings_from_pause:
				_settings_from_pause = false
				_set_state(State.PAUSED)
			else:
				_set_state(State.TITLE)
		"skip":
			if state == State.FINALE:
				if screens.finale_done():
					_open_chart(false)
				else:
					screens.finish_finale()
			elif state == State.LEVEL_INTRO:
				_begin_level()
			elif state == State.LEVEL_CLEAR:
				# One press runs the ceremony out, the next goes on. A
				# fast finger cannot land between the two.
				if screens.ceremony_done():
					_next_level()
				else:
					_finish_ceremony()
		"toggle_sound":
			GameSettings.sound = not GameSettings.sound
			GameSettings.apply()
			audio.play("ui_select")
		"toggle_music":
			GameSettings.music = not GameSettings.music
			GameSettings.apply()
			audio.play("ui_select")
		"toggle_haptics":
			GameSettings.haptics = not GameSettings.haptics
			GameSettings.apply()
			audio.play("ui_select")
		"toggle_crt":
			GameSettings.crt = not GameSettings.crt
			GameSettings.apply()
			audio.play("ui_select")
		"toggle_handed":
			GameSettings.left_handed = not GameSettings.left_handed
			GameSettings.apply()
			audio.play("ui_select")


func _re_entries_used() -> int:
	return 1 if run.re_entry_used else 0


## Section 16: one extra life, continue exactly where it stood. The
## bricks, the score and the clock are all untouched.
func _on_continue_granted() -> void:
	run.on_re_entry()
	_spawn_ball(true)
	_set_state(State.PLAYING)


func _on_continue_denied() -> void:
	_set_state(State.SIGNAL_LOST)


## PLAY on a fresh save is level 1. On a save with progress it is the
## first field still standing, because that is what the player means.
func _start_new_game() -> void:
	GameSession.clear()
	run.start_run()
	_load_level(_first_unfinished())
	_set_state(State.LEVEL_INTRO)


func _first_unfinished() -> int:
	var meta := _level_meta()
	for i in meta.size():
		if GameProgress.stars_for(int(meta[i]["id"])) & GameProgress.STAR_CLEARED:
			continue
		return i
	return 0


## True when every level in the universe has been cleared at least once.
func _universe_complete() -> bool:
	for entry in _level_meta():
		if not (GameProgress.stars_for(int(entry["id"])) & GameProgress.STAR_CLEARED):
			return false
	return true


## The five universes, as the select screen needs them. Only The Drift
## has levels; the rest are named so the player can see where the game
## goes, and marked so nobody presses them twice.
func _universe_rows() -> Array[Dictionary]:
	var rows: Array[Dictionary] = []
	for number in range(1, 6):
		var slug := Strings.slug_of_universe(number)
		var built := number == 1
		var note := Strings.text("UNIVERSE_SOON")
		if built:
			var cleared := 0
			for entry in _level_meta():
				if GameProgress.stars_for(int(entry["id"])) & GameProgress.STAR_CLEARED:
					cleared += 1
			note = Strings.fmt("UNIVERSE_CLEARED", [cleared, _level_meta().size()])
		rows.append({
			"name": Strings.zone_name(slug),
			"note": note,
			"open": built,
			"slug": slug,
		})
	return rows


## The level list, read once. Twelve JSON files parsed every time a menu
## opened was a menu that felt slow for no reason anyone could see.
func _level_meta() -> Array[Dictionary]:
	if not _meta_cache.is_empty():
		return _meta_cache
	for i in level_paths.size():
		var data: Dictionary = LevelLoader.load_level(level_paths[i])["data"]
		_meta_cache.append({
			"id": int(data.get("id", i + 1)),
			"name": str(data.get("name", "")),
		})
	return _meta_cache


## Section 15. Everything the chart needs to draw itself, read once when
## it opens rather than reached for while it draws.
func _open_chart(celebrate: bool) -> void:
	var entries: Array[Dictionary] = []
	for entry in _level_meta():
		var id := int(entry["id"])
		var bits := GameProgress.stars_for(id)
		entries.append({
			"name": str(entry["name"]),
			"bits": bits,
			"stars": GameProgress.star_count(id),
			"cleared": (bits & GameProgress.STAR_CLEARED) != 0,
			"best_time": GameProgress.best_time(id),
		})
	_set_state(State.STAR_MAP)
	star_map.open(entries, _first_unfinished(), celebrate)


func _on_field_chosen(index: int) -> void:
	audio.play("ui_select")
	GameSession.clear()
	run.start_run()
	_load_level(index)
	_set_state(State.LEVEL_INTRO)


func _on_map_action(name: String) -> void:
	match name:
		"hover":
			audio.play("ui_move", 1.0, -8.0)
		"locked":
			audio.play("ui_back", 0.8, -4.0)
		"line_drawn":
			# One note per line, climbing as the figure closes.
			audio.play("combo", 0.9 + 0.03 * float(star_map._lines_drawn), -6.0)
		"back":
			# Out of a universe's levels is back to the universes, which
			# is the screen the player came through.
			audio.play("ui_back")
			_set_state(State.UNIVERSES)


func _begin_level() -> void:
	_set_state(State.PLAYING)


# --- Levels ------------------------------------------------------------

func _load_level(index: int) -> void:
	level_index = posmod(index, level_paths.size())
	var result := LevelLoader.load_level(level_paths[level_index])
	for error in result["errors"]:
		push_error("%s: %s" % [level_paths[level_index], error])
	if not result["ok"]:
		return

	level_data = result["data"]
	grid.build(level_data.get("grid", []), LevelLoader.anchor_of(level_data))
	# Section 10, level 11: a field can start blind. The Blind capsule
	# then has nothing left to take, which is the joke.
	_level_blind = bool(level_data.get("blind", false))
	grid.blind = _level_blind
	arena.reset()
	effects.clear_all()
	powerups.reset_level()
	powerups.configure(level_data)
	# Section 15, the quiet helper. Three fails on this field and the
	# good drops get more generous. Nothing says so on screen.
	powerups.set_good_bonus(GameProgress.helper_points(int(level_data.get("id", 1))))
	background.set_level_mood(int(level_data.get("id", 1)))
	audio.set_universe(str(level_data.get("zone", "baeltet")))

	paddle.set_width(Paddle.WIDTH_NORMAL)
	paddle.laser = false
	paddle.follow_speed = 1.0
	paddle.clear_bolts()

	_clear_balls()
	_spawn_ball(true)

	run.start_level()
	_refresh_hud()


## Everything the ceremony still had to say, said at once. The stars that
## had not landed still land, still make their noise, and still count.
func _finish_ceremony() -> void:
	screens.finish_ceremony()
	for bit in [1, 2, 4]:
		if _star_sounds & bit:
			_star_sounds &= ~bit
			audio.play("star_%d" % ([1, 2, 4].find(bit) + 1), 1.0, -6.0)
	game_feel.pulse(GameFeel.HAPTIC_STAR)
	_state_timer = 0.4


func _next_level() -> void:
	run.re_entry_used = false
	if level_index + 1 >= level_paths.size():
		# The end of a universe. If every level in it has fallen, the
		# constellation is drawn where it was played, before the chart
		# opens underneath it. If some are still standing, there is no
		# figure to draw and the chart is the right place to go.
		if _universe_complete():
			_set_state(State.FINALE)
		else:
			_open_chart(true)
		return
	_load_level(level_index + 1)
	_set_state(State.LEVEL_INTRO)


# --- Balls -------------------------------------------------------------

func _spawn_ball(stuck: bool, at := Vector2.ZERO, angle_deg := 0.0) -> Ball:
	if _balls.size() >= MAX_BALLS:
		return null
	var ball := Ball.new()
	ball.arena = arena
	ball.paddle = paddle
	ball.grid = grid
	ball.game_feel = game_feel
	ball.effects = effects
	ball.speed_base = level_ball_speed()
	ball.input_enabled = state == State.PLAYING
	ball.frozen = state != State.PLAYING
	balls_root.add_child(ball)
	_balls.append(ball)

	ball.wall_hit.connect(_on_wall_hit)
	ball.paddle_hit.connect(_on_paddle_hit)
	ball.brick_hit.connect(_on_brick_hit.bind(ball))
	ball.launched.connect(_on_ball_launched)
	ball.caught.connect(_on_ball_caught)
	ball.lost.connect(_on_ball_lost)

	if stuck:
		ball.stick_to_paddle()
	else:
		ball.global_position = at
		ball.launch_at(angle_deg)
	_sync_powerup_state()
	return ball


func _clear_balls() -> void:
	for ball in _balls:
		if is_instance_valid(ball):
			ball.queue_free()
	_balls.clear()


func _remove_ball(ball: Ball) -> void:
	_balls.erase(ball)
	if is_instance_valid(ball):
		ball.queue_free()


# --- Signals -----------------------------------------------------------

func _shake(amount: Vector2) -> void:
	game_feel.shake(amount.x, amount.y)


## Relative steering, section: the paddle moves BY the finger's delta.
func _on_steered(delta_x: float) -> void:
	if state == State.PLAYING:
		paddle.nudge(delta_x)


## A tap does whatever the moment calls for: launch a waiting ball, or
## fire the laser. A drag does neither.
func _on_tapped() -> void:
	if state != State.PLAYING:
		return
	var launched := false
	for ball in _balls:
		if ball.stuck:
			ball.launch()
			launched = true
			break
	if not launched and paddle.laser:
		paddle.fire_laser()


func _on_ball_launched() -> void:
	audio.play("launch", randf_range(0.96, 1.04), -3.0)


func _on_wall_hit(pos: Vector2, _normal: Vector2) -> void:
	arena.register_hit(pos)
	_shake(SHAKE_WALL)
	background.flash_near(pos, 5, Arena.VOLT)
	audio.play("wall", randf_range(0.94, 1.08), -5.0)


func _on_paddle_hit(pos: Vector2, _angle: float, sweet: bool) -> void:
	# The combo resets on paddle contact. That is what makes a long run
	# up behind the wall worth chasing.
	run.on_paddle_hit()
	audio.set_drone_intensity(0)
	_apply_combo_milestones()
	effects.sparks(pos, Vector2.UP, 2, Paddle.VOLT if sweet else Paddle.BONE)
	audio.play("paddle", 1.12 if sweet else randf_range(0.97, 1.03), -2.0)
	game_feel.pulse(GameFeel.HAPTIC_PADDLE)
	_try_the_save(pos)
	_refresh_hud()


## The save. A catch made in the last thirty pixels before the line is
## the best thing that happens in a run of this game, and it used to
## sound and look exactly like every other catch.
##
## Rate limited to once every three seconds of real time: a ball rattling
## along the bottom would otherwise put the whole game in slow motion.
func _try_the_save(pos: Vector2) -> bool:
	if arena.ember_line_y() - pos.y > SAVE_REACH:
		return false
	var now := float(Time.get_ticks_msec())
	if now - _last_save_ms < SAVE_COOLDOWN_MS:
		return false
	_last_save_ms = now
	game_feel.slow_motion(SAVE_SCALE, SAVE_TIME)
	effects.sparks(Vector2(pos.x, paddle.top_y()), Vector2.UP, 10, Powerup.VOLT)
	effects.shockwave(Vector2(pos.x, paddle.top_y()), 46.0, Powerup.VOLT)
	audio.play("save", 1.0, -1.0)
	game_feel.pulse(GameFeel.HAPTIC_POWERUP)
	return true


## Section: what a combo is worth beyond points. Ten lengthens the tail
## and brings a second voice in under the drone; twenty sets the
## containment field breathing in time with it. Both revert together,
## and neither shakes the screen.
func _apply_combo_milestones() -> void:
	var long_tail := combo >= COMBO_TRAIL_AT
	for ball in _balls:
		ball.long_trail = long_tail
	audio.set_drone_layer(long_tail)
	arena.combo_pulse = combo >= COMBO_FIELD_AT


func _on_brick_hit(brick: Brick, damage: int, pos: Vector2, _passed: bool, ball: Ball) -> void:
	if brick == null or not brick.alive:
		return
	_last_impact = pos
	if ball.zap and brick.is_breakable():
		# Section 5: a small bolt to each brick it takes with it.
		for neighbour in grid.zap_neighbours(brick):
			effects.lightning(brick.rect.get_center(), neighbour.rect.get_center(), Powerup.VOLT)
	grid.hit(brick, damage)


func _on_brick_damaged(brick: Brick) -> void:
	# Hardened takes damage: 3 sparks, no shards, the brick shakes.
	effects.brick_damaged(brick.rect.get_center(), brick.color())
	game_feel.hitstop(HITSTOP_HARDENED)
	audio.play("brick_hard", randf_range(0.95, 1.06), -3.0)
	game_feel.pulse(GameFeel.HAPTIC_HARDENED)


func _on_brick_destroyed(brick: Brick, by_chain: bool) -> void:
	# A chain is a run of bricks taken without the ball touching one. Two
	# achievements hang off how long it gets.
	if by_chain:
		_chain_run += 1
		if _chain_run >= 5:
			GameCenterLink.report("chain_of_five")
		if _chain_run >= 30:
			GameCenterLink.report("one_hit")
	else:
		_chain_run = 0
	var points := run.on_brick_destroyed(brick.score_value())
	_apply_ball_speed()

	# A brick the chain took throws its pieces away from the blast at
	# half again the speed. One the ball took scatters them from the
	# point of contact.
	var push := _last_impact
	var throw := 1.0
	if by_chain and brick.chain_from != Vector2.INF:
		push = brick.chain_from
		throw = CHAIN_SHARD_SPEED
	effects.brick_smashed(brick.rect, brick.color(), brick.shard_count(),
		brick.type == Brick.Type.GLASS, push, throw)
	effects.score_popup(brick.rect.get_center(), points)
	# Section 2 had the nearest stars answer every brick. On a phone,
	# with a chain running, that is a field of lamps blinking behind the
	# thing the player is trying to watch. The sky answers the frame
	# instead, where it is one event at a time.

	match brick.type:
		Brick.Type.BLAST:
			var area := Rect2(brick.rect.position - BrickGrid.PITCH, brick.rect.size + BrickGrid.PITCH * 2.0)
			effects.blast(brick.rect, area)
			_shake(SHAKE_BLAST)
			game_feel.hitstop(HITSTOP_BLAST)
			audio.play("blast", randf_range(0.94, 1.06))
			game_feel.pulse(GameFeel.HAPTIC_BLAST)
		Brick.Type.GLASS:
			audio.play("glass", randf_range(0.94, 1.08), -2.0)
			if not by_chain:
				game_feel.hitstop(HITSTOP_BRICK)
		Brick.Type.PULSE:
			# The Pulse core sends a wider wave of light than usual.
			effects.shockwave(brick.rect.get_center(), 54.0, brick.color())
			background.field_glint()
			audio.play_brick(combo, "brick", 1.0)
			if not by_chain:
				game_feel.hitstop(HITSTOP_BRICK)
		_:
			audio.play_brick(combo)
			if not by_chain:
				game_feel.hitstop(HITSTOP_BRICK)

	_apply_combo_milestones()
	if combo == 5 or combo == 10 or combo == 20:
		effects.combo(combo)
		audio.play("combo", 1.0 + float(combo) * 0.01, -4.0)
	background.set_intensity(combo)
	audio.set_drone_intensity(combo)

	if brick.type != Brick.Type.BLAST:
		game_feel.pulse(GameFeel.HAPTIC_BRICK)
	powerups.roll_for(brick.rect.get_center(), brick.powerup_chance(),
		brick.type == Brick.Type.SPARK)
	_refresh_hud()


func _on_brick_revealed(brick: Brick) -> void:
	effects.sparks(brick.rect.get_center(), Vector2.UP, 2, brick.color())


func _on_stone_popped(brick: Brick) -> void:
	effects.brick_smashed(brick.rect, brick.color(), 8)
	effects.shockwave(brick.rect.get_center(), 40.0, Arena.VOLT)
	audio.play("brick", randf_range(0.7, 0.85), -4.0)


## The grid says the field is empty. That signal fires once, on whatever
## brick happened to be last — a ball's hit or the tail of a chain — so
## the slow motion lands on the right frame either way.
func _on_level_cleared() -> void:
	if state != State.PLAYING or _clear_pending:
		return
	_clear_pending = true
	game_feel.slow_motion(LAST_BRICK_SCALE, LAST_BRICK_TIME)


## The ceremony, once the last brick has finished hanging in the air.
func _begin_clear_ceremony() -> void:
	_clear_pending = false
	if state != State.PLAYING:
		return
	GameSession.clear()
	# Section 15: cleared, cleared under par, cleared without losing the
	# ball. Independent, and merged with what earlier attempts earned.
	var level_id := int(level_data.get("id", 1))
	var par := float(level_data.get("parTime", 0))
	var earned := run.stars(par)
	var had := GameProgress.stars_for(level_id)
	GameProgress.record_clear(level_id, earned, run.level_time)
	GameProgress.submit_score(run.score)
	# Only what this run actually added is celebrated. A star you already
	# had does not land twice.
	screens.stars_earned = earned & ~had
	screens.stars_total = GameProgress.stars_for(level_id)
	screens.level_time = run.level_time
	screens.par_time = par
	_star_sounds = screens.stars_earned
	_report_clear(level_id, earned)
	arena.celebrate()
	background.blitz()
	audio.play("level_clear")
	# Two knocks: the level is down, and there is another one.
	game_feel.pulse_pattern([[GameFeel.HAPTIC_LEVEL_CLEAR, 110.0],
		[GameFeel.HAPTIC_LEVEL_CLEAR, 0.0]])
	_set_state(State.LEVEL_CLEAR)


## What a cleared level is worth outside the game. Every one of these is
## a no-op unless a plugin and a signed-in player are both there.
func _report_clear(level_id: int, earned: int) -> void:
	GameCenterLink.submit_level_score(level_id, score)
	var stars := 0
	for entry in _level_meta():
		stars += GameProgress.star_count(int(entry["id"]))
	GameCenterLink.submit_total_stars(stars)

	if level_id == 1:
		GameCenterLink.report("first_breach")
	if level_id == 6:
		GameCenterLink.report("patience")
	if level_id == level_paths.size():
		GameCenterLink.report("the_drift_cleared")
	if earned & GameProgress.STAR_NO_LOSS:
		GameCenterLink.report("clean_sweep")
	if earned & GameProgress.STAR_UNDER_PAR:
		GameCenterLink.report("ahead_of_schedule")
	if GameProgress.stars_for(level_id) == GameProgress.ALL_STARS:
		GameCenterLink.report("three_of_three")
	if _universe_complete():
		GameCenterLink.report("constellation_charted")
	if stars >= _level_meta().size() * 3:
		GameCenterLink.report("full_chart")


## The Magnet held it. Same note as a paddle hit, a fifth lower, so the
## hand knows the ball is waiting without the eye having to check.
func _on_ball_caught(_ball: Ball) -> void:
	audio.play("paddle", 0.72, -4.0)
	game_feel.pulse(GameFeel.HAPTIC_PADDLE)


## One free save, spent only on the last ball on the field. It never goes
## on a spare, and it does catch Death, which is the moment worth having.
func _shield_save(ball: Ball) -> bool:
	if not arena.shield_armed:
		return false
	arena.spend_shield()
	ball.save_at(arena.ember_line_y() - 2.0)
	effects.sparks(Vector2(ball.global_position.x, arena.ember_line_y()), Vector2.UP, 8, Powerup.VOLT)
	effects.shockwave(Vector2(ball.global_position.x, arena.ember_line_y()), 60.0, Powerup.VOLT)
	game_feel.shake(0.0, 4.0)
	audio.play("powerup_good", 0.8, 0.0)
	game_feel.pulse(GameFeel.HAPTIC_POWERUP)
	arena.set_danger(0.0)
	return true


func _on_ball_lost(ball: Ball) -> void:
	if state == State.PLAYING and _balls.size() <= 1 and _shield_save(ball):
		return
	_remove_ball(ball)
	if not _balls.is_empty():
		return
	if state != State.PLAYING:
		return

	var final := run.on_ball_lost()
	# Death takes the ball in mid-air, so the comet has to come apart
	# where it actually was, not always at the bottom of the field.
	effects.ball_lost(Vector2(
		ball.global_position.x,
		minf(ball.global_position.y, arena.death_y - 6.0)))
	arena.set_danger(1.0)
	background.dim()
	audio.play("life_lost")
	game_feel.pulse(GameFeel.HAPTIC_BALL_LOST)
	audio.set_drone_intensity(0)
	audio.drone_dip()
	powerups.reset_level()
	paddle.set_width(Paddle.WIDTH_NORMAL)
	paddle.laser = false
	paddle.magnet = false
	powerups.guarantee_good()

	if final:
		GameSession.clear()
		GameProgress.record_fail(int(level_data.get("id", 1)))
		screens.high_score = GameProgress.high_score
		screens.new_record = GameProgress.submit_score(run.score)
		audio.play("game_over")
		game_feel.pulse(GameFeel.HAPTIC_SIGNAL_LOST)
		_set_state(State.SIGNAL_LOST)
	else:
		_set_state(State.BALL_LOST)
	_refresh_hud()


func _on_laser_fired(from: Vector2) -> void:
	effects.sparks(from, Vector2.UP, 2, Powerup.EMBER)
	audio.play("laser", randf_range(0.95, 1.08), -5.0)


# --- Power-ups ---------------------------------------------------------

func _on_powerup_collected(id: String) -> void:
	var info := Powerup.info(id)
	paddle.on_powerup_caught(info["color"])
	effects.powerup_icon(paddle.global_position - Vector2(0.0, 22.0), Strings.powerup_name(id), info["color"])
	# Three kinds of capsule, three sounds. A coin flip must not arrive
	# sounding like a gift or like a punishment.
	var note := "powerup_good"
	if Powerup.is_bad(id):
		note = "powerup_bad"
	elif Powerup.is_neutral(id):
		note = "powerup_neutral"
	audio.play(note, 1.0, -2.0)
	game_feel.pulse(GameFeel.HAPTIC_POWERUP)

	match id:
		"multi":
			_split_balls()
		"life":
			run.add_life()
		"shield":
			arena.shield_armed = true
		"splinter":
			_splinter()
		"swap":
			_swap_bricks()
		"death":
			_death()
	_sync_powerup_state()
	_refresh_hud()


func _on_powerup_expired(_id: String) -> void:
	_sync_powerup_state()


## Everything with a duration is derived from the list of active
## power-ups, so two opposing ones can never leave the paddle stuck.
func _sync_powerup_state() -> void:
	var active := powerups.active_effects()

	var width := Paddle.WIDTH_NORMAL
	if active.has("wide"):
		width = Paddle.WIDTH_WIDE
	elif active.has("narrow"):
		width = Paddle.WIDTH_NARROW
	paddle.set_width(width)
	paddle.laser = active.has("laser")
	paddle.magnet = active.has("magnet")
	# Section 7's three remaining punishments. Each takes away something
	# different: what you can see, which way you mean, and how fast the
	# shield answers.
	grid.blind = _level_blind or active.has("blind")
	paddle.inverted = active.has("invert")
	paddle.follow_speed = 0.6 if active.has("heavy") else 1.0

	var scale := 1.0
	if active.has("slow"):
		scale = 0.7
	elif active.has("fast"):
		scale = 1.4
	for ball in _balls:
		ball.speed_scale = scale
		ball.fireball = active.has("fireball")
		ball.giant = active.has("giant")
		ball.zap = active.has("zap")


## A Lottery has been caught and is being drawn. The paddle keeps its
## flash and the question mark does the waiting.
func _on_lottery_rolling(seconds: float) -> void:
	paddle.on_powerup_caught(Powerup.FLARE)
	effects.suspense(paddle.global_position - Vector2(0.0, 34.0), seconds, Powerup.FLARE)
	audio.play("powerup_neutral", 1.2, -6.0)
	game_feel.pulse(GameFeel.HAPTIC_STAR)


## Splinter: everything one hit from breaking goes at once.
func _splinter() -> void:
	var count := grid.splinter()
	if count <= 0:
		return
	audio.play("powerup_good", 1.15, 0.0)
	game_feel.shake(0.0, 3.0)


## Swap: the whole field changes what it is worth.
func _swap_bricks() -> void:
	if grid.swap_types() <= 0:
		return
	audio.play("glass", 0.85, -4.0)
	background.field_glint()


## Death: it takes one ball, not the field. With three in play you lose
## a third of your luck; with one in play the Shield still gets its say.
func _death() -> void:
	if _balls.is_empty():
		return
	audio.play("life_lost", 1.25, -6.0)
	_balls[0].kill()


## Multi: the ball splits into 3.
func _split_balls() -> void:
	var source: Ball = null
	for ball in _balls:
		if not ball.stuck:
			source = ball
			break
	if source == null and not _balls.is_empty():
		source = _balls[0]
		source.launch()
	if source == null:
		return
	var base_angle := rad_to_deg(atan2(-source.velocity.y, source.velocity.x))
	for offset in [-32.0, 32.0]:
		_spawn_ball(false, source.global_position, base_angle + offset)


func _combo_multiplier() -> int:
	return run.combo_multiplier()


## Speed starts at the level's own and rises 4 per cent per 10 bricks,
## capped at 520 px/s. It is what makes a field end faster than it
## begins.
func level_ball_speed() -> float:
	var base := float(level_data.get("ballSpeed", Ball.BASE_SPEED))
	var steps := run.level_bricks / Ball.SPEED_STEP_BRICKS
	return minf(base * pow(Ball.SPEED_STEP, float(steps)), Ball.MAX_SPEED)


func _apply_ball_speed() -> void:
	var speed := level_ball_speed()
	for ball in _balls:
		ball.speed_base = speed


# --- Loop --------------------------------------------------------------

func _process(delta: float) -> void:
	if state == State.PLAYING:
		run.tick(delta)
	# Once the device has produced a real touch, the mouse stops driving.
	paddle.follow_mouse = not touch.seen_touch
	background.set_focus_x(paddle.position.x)
	_update_danger()
	_update_lasers()

	var positions: Array[Vector2] = []
	for ball in _balls:
		positions.append(ball.global_position)
	grid.update_proximity(positions)

	# The hang on the last brick is over: the ceremony can start.
	if _clear_pending and not game_feel.is_slow():
		_begin_clear_ceremony()

	if state == State.FINALE:
		_run_finale()

	if state == State.LEVEL_CLEAR and _star_sounds != 0:
		_star_sound_timer += delta
		var due: float = float(Screens.CEREMONY["first_star"])
		for bit in [1, 2, 4]:
			if _star_sounds & bit and _star_sound_timer > due:
				_star_sounds &= ~bit
				audio.play("star_%d" % ([1, 2, 4].find(bit) + 1), 1.0, -2.0)
				game_feel.pulse(GameFeel.HAPTIC_STAR)
				break
			due += float(Screens.CEREMONY["star_gap"])

	if _state_timer > 0.0:
		_state_timer = maxf(0.0, _state_timer - delta)
		if _state_timer <= 0.0:
			_advance_state()

	if _debug:
		_update_debug()


func _advance_state() -> void:
	match state:
		State.BALL_LOST:
			_spawn_ball(true)
			_set_state(State.PLAYING)
		State.LEVEL_INTRO:
			_begin_level()
		State.LEVEL_CLEAR:
			_next_level()


## The finale's sound and its ending. Twelve stars, each a note higher
## than the last, then the lines, then the chart.
func _run_finale() -> void:
	var t := screens.time_on_screen()
	while _finale_stars < StarMap.NODES.size() and t >= Screens.finale_star_at(_finale_stars):
		_finale_stars += 1
		audio.play("star_%d" % (1 + _finale_stars % 3), 0.82 + 0.03 * float(_finale_stars), -4.0)
		game_feel.pulse(GameFeel.HAPTIC_STAR)
	while _finale_lines < StarMap.EDGES.size() and t >= Screens.finale_line_at(_finale_lines):
		_finale_lines += 1
		audio.play("combo", 0.9 + 0.02 * float(_finale_lines), -8.0)
	if _finale_lines == StarMap.EDGES.size():
		_finale_lines += 1
		audio.play("level_clear", 0.9, -2.0)
		game_feel.pulse_pattern([[GameFeel.HAPTIC_LEVEL_CLEAR, 120.0],
			[GameFeel.HAPTIC_LEVEL_CLEAR, 120.0], [GameFeel.HAPTIC_LEVEL_CLEAR, 0.0]])
	# It ends on its own if nobody presses anything.
	if t >= Screens.finale_length() + 2.0:
		_open_chart(false)


func _update_danger() -> void:
	if _balls.is_empty() or state != State.PLAYING:
		arena.set_danger(0.0)
		return
	var nearest := INF
	for ball in _balls:
		if not ball.stuck:
			nearest = minf(nearest, arena.death_y - ball.global_position.y)
	if nearest == INF:
		arena.set_danger(0.0)
		return
	arena.set_danger(1.0 - clampf(nearest / Arena.EMBER_WARN_DISTANCE, 0.0, 1.0))


func _update_lasers() -> void:
	for bolt in paddle.laser_bolts():
		if not bolt["alive"]:
			continue
		var pos: Vector2 = bolt["pos"]
		var area := Rect2(pos - Vector2(2.0, 6.0), Vector2(4.0, 10.0))
		for brick in grid.bricks_in(area):
			if brick.rect.intersects(area):
				bolt["alive"] = false
				grid.hit(brick)
				break


func _refresh_hud() -> void:
	hud.score = score
	hud.level_number = int(level_data.get("id", level_index + 1))
	hud.level_name = str(level_data.get("name", ""))
	hud.zone_slug = str(level_data.get("zone", "baeltet"))
	hud.lives = maxi(lives, 0)
	hud.max_lives = maxi(START_LIVES, lives)
	hud.combo = combo
	hud.active = powerups.active_effects()
	hud.stars = GameProgress.stars_for(int(level_data.get("id", 1)))
	hud.best_score = GameProgress.high_score
	hud.visible = state != State.TITLE and state != State.SETTINGS \
		and state != State.SIGNAL_LOST and state != State.STAR_MAP \
		and state != State.UNIVERSES and state != State.FINALE and not recording


## The pause control sits in the panel, above the field. TouchInput
## ignores presses that start there, so this is the only thing listening.
func _unhandled_input(event: InputEvent) -> void:
	if state != State.PLAYING:
		return
	var point := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
	if point == Vector2.INF or not hud.pause_touch_rect().has_point(point):
		return
	get_viewport().set_input_as_handled()
	_on_screen_action("pause")


## A phone call, a swipe up, a notification. Whatever took the screen,
## the ball must not still be falling when it comes back.
func _notification(what: int) -> void:
	match what:
		NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_WM_WINDOW_FOCUS_OUT, \
		NOTIFICATION_APPLICATION_PAUSED:
			if state == State.PLAYING:
				_set_state(State.PAUSED)
			_store_session()
		NOTIFICATION_WM_CLOSE_REQUEST:
			_store_session()


## The level in flight, written down. Phase 9, section 7: the app can be
## closed in the middle of a level and the level comes back.
func _store_session() -> void:
	var playable := state == State.PLAYING or state == State.PAUSED \
		or state == State.BALL_LOST
	if not playable or level_data.is_empty():
		return
	GameSession.store(level_index, int(level_data.get("id", 1)), score, lives,
		grid.snapshot(), run.run_time, run.run_bricks, run.best_combo)


## Puts a stored level back. Returns false if there was nothing to put
## back, or the wall did not fit the level it claims to belong to.
func _restore_session() -> bool:
	if not GameSession.has_session():
		return false
	var saved := GameSession.data()
	var index := int(saved.get("level_index", 0))
	if index < 0 or index >= level_paths.size():
		GameSession.clear()
		return false
	run.start_run()
	_load_level(index)
	if int(level_data.get("id", -1)) != int(saved.get("level_id", -2)):
		GameSession.clear()
		return false
	if not grid.restore(saved.get("bricks", [])):
		GameSession.clear()
		return false
	# Every brick still standing counts, and a field with none left is
	# not a session worth restoring.
	if grid.remaining_breakable() <= 0:
		GameSession.clear()
		return false
	score = int(saved.get("score", 0))
	run.lives = int(saved.get("lives", START_LIVES))
	run.run_time = float(saved.get("run_time", 0.0))
	run.run_bricks = int(saved.get("run_bricks", 0))
	run.best_combo = int(saved.get("best_combo", 0))
	combo = 0
	_clear_balls()
	_spawn_ball(true)
	_refresh_hud()
	return true


## Section 18: the recording mode. Never visible to a player, and never
## present in a release build: OS.is_debug_build() is false there, and
## the whole block below is behind it. It exists to make clips of the
## game without having to play for the right moment.
##
##   F1  overlay      F5  recording mode on/off (hides the panel)
##   F2  next level   1   the wall, whole again
##   F3  restart      2   a chain, from the best blast brick on the field
##                    3   three balls
##                    4   the level falls
func _input(event: InputEvent) -> void:
	if not OS.is_debug_build():
		return
	if event is InputEventKey and event.pressed and not event.echo:
		if recording and _recording_key(event.keycode):
			return
		match event.keycode:
			KEY_F1:
				_debug = not _debug
				_debug_label.visible = _debug
			KEY_F2:
				if state == State.PLAYING:
					_next_level()
			KEY_F3:
				if state == State.PLAYING:
					_load_level(level_index)
					_set_state(State.PLAYING)
			KEY_F5:
				recording = not recording
				_refresh_hud()
			KEY_ESCAPE:
				if state == State.PLAYING or state == State.LEVEL_INTRO:
					_set_state(State.TITLE)


## The scenarios, on any level. Returns whether the key was one of them.
func _recording_key(key: int) -> bool:
	match key:
		KEY_1:
			_load_level(level_index)
			_set_state(State.PLAYING)
		KEY_2:
			_record_chain()
		KEY_3:
			_split_balls()
		KEY_4:
			_record_clear()
		_:
			return false
	return true


## The biggest chain on the field, set off. Picks the blast brick that
## takes the most with it, so a clip never catches a dud.
func _record_chain() -> void:
	var best: Brick = null
	var best_count := -1
	for brick in grid.live_bricks():
		if brick.type != Brick.Type.BLAST:
			continue
		var count := 0
		for offset in BrickGrid.NEIGHBOUR_SPIRAL:
			var n := grid.brick_at(brick.col + offset.x, brick.row + offset.y)
			if n != null and n.alive and n.is_breakable():
				count += 1
		if count > best_count:
			best_count = count
			best = brick
	if best != null:
		# Through the grid, not through the ball's own hit path: that one
		# reads the ball that struck, and in a recording there is not
		# necessarily one. The destroyed signal carries the rest.
		grid.hit(best, best.hits_left)


## The level falls, all of it, so the ceremony can be filmed on demand.
func _record_clear() -> void:
	for brick in grid.live_bricks():
		if brick.counts_toward_clear():
			grid.hit(brick, brick.hits_left)


func _update_debug() -> void:
	hud.active = powerups.active_effects()
	var ball: Ball = _balls[0] if not _balls.is_empty() else null
	var lines := [
		"FPS        %d (%.2f ms)" % [Engine.get_frames_per_second(),
			1000.0 / maxf(float(Engine.get_frames_per_second()), 1.0)],
		"PHYSICS    %d Hz, interpolated" % Engine.physics_ticks_per_second,
		"STATE      %s" % State.keys()[state],
		"LEVEL      %d %s" % [int(level_data.get("id", 0)), str(level_data.get("name", ""))],
		"BRICKS     %d left" % grid.remaining_breakable(),
		"BALLS      %d" % _balls.size(),
		"COMBO      %d (best %d, x%d)" % [combo, best_combo, _combo_multiplier()],
		"SHARDS     %d live, %d pooled" % [effects.shard_count(), effects.pool_size()],
		"TOUCH      %s" % ("yes" if touch.seen_touch else "mouse"),
		"LIVES      %d" % lives,
	]
	if ball:
		lines.append("SPEED      %.0f px/s (base %.0f, cap %.0f)" % [ball.current_speed(), level_ball_speed(), Ball.MAX_SPEED])
		lines.append("EXIT       %.1f deg" % ball.last_exit_angle)
		lines.append("ANGLE      %.1f deg" % _angle_of(ball))
	var names := PackedStringArray()
	for id in powerups.active_effects():
		names.append("%s %.1fs" % [str(Powerup.info(str(id))["name"]), float(powerups.active_effects()[id])])
	lines.append("ACTIVE     %s" % ("none" if names.is_empty() else ", ".join(names)))
	lines.append("F1 hide · F2 next level · F3 restart · ESC menu")
	_debug_label.text = "\n".join(lines)


static func _angle_of(ball: Ball) -> float:
	if ball.velocity.length() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(absf(ball.velocity.y), absf(ball.velocity.x)))
