class_name Game
extends Node2D

## Spillets dirigent.
##
## Ingen af de andre scripts kender hinanden. Bolden ved ikke, hvad en
## score er, gridet ved ikke, at der findes power-ups, skærmene ved ikke,
## hvad et level er, og baggrunden ved kun, at noget skete et bestemt
## sted. Alt mødes her.

enum State { TITLE, SETTINGS, LEVEL_INTRO, PLAYING, BALL_LOST, LEVEL_CLEAR, GAME_OVER }

const START_LIVES := 3
const MAX_BALLS := 6
const BALL_LOST_PAUSE := 0.5
const LEVEL_INTRO_PAUSE := 2.2
const LEVEL_CLEAR_PAUSE := 2.4

## Hitstop. Fase 1 havde den sat til 0. Nu er det den, der giver
## sprængklodsen sin vægt.
const HITSTOP_BRICK := 0.018
const HITSTOP_HARDENED := 0.012
const HITSTOP_BLAST := 0.06

const SHAKE_WALL := Vector2(2.0, 0.06)
const SHAKE_BLAST := Vector2(6.0, 0.12)

@onready var game_feel: GameFeel = $GameFeel
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
@onready var crt: CRT = $CRTLayer/CRT
@onready var _debug_label: Label = $HUDLayer/Debug

var state := State.TITLE
var score := 0
var lives := START_LIVES
var combo := 0
var best_combo := 0

var level_index := 0
var level_data: Dictionary = {}
var level_paths: PackedStringArray

var _balls: Array[Ball] = []
## Klodser smadret i dette level. Farten stiger med dem.
var _bricks_this_level := 0
var _state_timer := 0.0
var _debug := false


func _ready() -> void:
	background.screen_size = Arena.SCREEN
	effects.screen_size = Arena.SCREEN
	hud.screen_size = Arena.SCREEN
	screens.screen_size = Arena.SCREEN
	crt.screen_size = Arena.SCREEN

	paddle.set_bounds(arena.inner_rect().position.x, arena.inner_rect().end.x)
	paddle.position = Vector2(Arena.SCREEN.x * 0.5, Arena.SCREEN.y - 64.0)

	powerups.paddle = paddle
	powerups.kill_y = arena.death_y
	powerups.collected.connect(_on_powerup_collected)
	powerups.expired.connect(_on_powerup_expired)

	grid.brick_damaged.connect(_on_brick_damaged)
	grid.brick_destroyed.connect(_on_brick_destroyed)
	grid.brick_revealed.connect(_on_brick_revealed)
	grid.stone_popped.connect(_on_stone_popped)
	grid.cleared.connect(_on_level_cleared)

	paddle.laser_fired.connect(_on_laser_fired)
	screens.action.connect(_on_screen_action)

	level_paths = LevelLoader.level_paths()
	if level_paths.is_empty():
		push_error("No levels in res://levels")
		return

	_load_level(0)
	_set_state(State.TITLE)
	_debug_label.visible = false


# --- Tilstande ---------------------------------------------------------

func _set_state(new_state: State) -> void:
	state = new_state
	_state_timer = 0.0

	var overlay := Screens.Screen.NONE
	match state:
		State.TITLE:
			overlay = Screens.Screen.TITLE
		State.SETTINGS:
			overlay = Screens.Screen.SETTINGS
		State.LEVEL_INTRO:
			overlay = Screens.Screen.LEVEL_INTRO
			_state_timer = LEVEL_INTRO_PAUSE
		State.LEVEL_CLEAR:
			overlay = Screens.Screen.LEVEL_CLEAR
			_state_timer = LEVEL_CLEAR_PAUSE
		State.GAME_OVER:
			overlay = Screens.Screen.GAME_OVER
		State.BALL_LOST:
			_state_timer = BALL_LOST_PAUSE

	screens.level_number = int(level_data.get("id", 1))
	screens.level_title = str(level_data.get("name", ""))
	screens.final_score = score
	screens.show_screen(overlay)

	# Titel og indstillinger vises over det bare stjernefelt. Klodser og
	# skjold bag et logo er støj, ikke stemning.
	var field_visible := state != State.TITLE and state != State.SETTINGS
	arena.visible = field_visible
	grid.visible = field_visible
	paddle.visible = field_visible
	balls_root.visible = field_visible
	powerups.visible = field_visible
	effects.visible = field_visible

	var interactive := state == State.PLAYING
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
		"play", "restart":
			audio.play("ui_select")
			_start_new_game()
		"settings":
			audio.play("ui_select")
			_set_state(State.SETTINGS)
		"menu":
			audio.play("ui_back")
			_set_state(State.TITLE)
		"back":
			audio.play("ui_back")
			_set_state(State.TITLE)
		"skip":
			if state == State.LEVEL_INTRO:
				_begin_level()
			elif state == State.LEVEL_CLEAR:
				_next_level()
		"toggle_sound":
			GameSettings.sound_on = not GameSettings.sound_on
			GameSettings.apply()
			audio.play("ui_select")
		"toggle_crt":
			GameSettings.crt = not GameSettings.crt
			GameSettings.apply()
			audio.play("ui_select")
		"toggle_shake":
			GameSettings.screen_shake = not GameSettings.screen_shake
			GameSettings.apply()
			audio.play("ui_select")
		"volume_up":
			GameSettings.volume = clampf(GameSettings.volume + 0.1, 0.0, 1.0)
			GameSettings.apply()
			audio.play("ui_move")
		"volume_down":
			GameSettings.volume = clampf(GameSettings.volume - 0.1, 0.0, 1.0)
			GameSettings.apply()
			audio.play("ui_move")


func _start_new_game() -> void:
	score = 0
	lives = START_LIVES
	best_combo = 0
	_load_level(0)
	_set_state(State.LEVEL_INTRO)


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
	grid.build(level_data.get("grid", []))
	grid.blind = false
	arena.reset()
	effects.clear_all()
	powerups.reset_level()
	powerups.configure(level_data)
	background.set_level_mood(int(level_data.get("id", 1)))

	paddle.set_width(Paddle.WIDTH_NORMAL)
	paddle.laser = false
	paddle.follow_speed = 1.0
	paddle.clear_bolts()

	_clear_balls()
	_spawn_ball(true)

	combo = 0
	_bricks_this_level = 0
	_refresh_hud()


func _next_level() -> void:
	_load_level(level_index + 1)
	_set_state(State.LEVEL_INTRO)


# --- Bolde -------------------------------------------------------------

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


# --- Signaler ----------------------------------------------------------

func _shake(amount: Vector2) -> void:
	if GameSettings.screen_shake:
		game_feel.shake(amount.x, amount.y)


func _on_ball_launched() -> void:
	audio.play("launch", randf_range(0.96, 1.04), -3.0)


func _on_wall_hit(pos: Vector2, _normal: Vector2) -> void:
	arena.register_hit(pos)
	_shake(SHAKE_WALL)
	background.flash_near(pos, 5, Arena.VOLT)
	audio.play("wall", randf_range(0.94, 1.08), -5.0)


func _on_paddle_hit(pos: Vector2, _angle: float, sweet: bool) -> void:
	# Komboen nulstilles ved paddle-ramt. Det er den, der gør en lang
	# tur oppe bag muren værd at jagte.
	combo = 0
	audio.set_drone_intensity(0)
	effects.sparks(pos, Vector2.UP, 2, Paddle.VOLT if sweet else Paddle.BONE)
	audio.play("paddle", 1.12 if sweet else randf_range(0.97, 1.03), -2.0)
	_refresh_hud()


func _on_brick_hit(brick: Brick, damage: int, pos: Vector2, _passed: bool, ball: Ball) -> void:
	if brick == null or not brick.alive:
		return
	if ball.zap and brick.is_breakable():
		grid.zap_neighbours(brick)
	grid.hit(brick, damage)


func _on_brick_damaged(brick: Brick) -> void:
	# Hærdet tager skade: 3 gnister, ingen splinter, klodsen ryster.
	effects.brick_damaged(brick.rect.get_center(), brick.color())
	game_feel.hitstop(HITSTOP_HARDENED)
	audio.play("brick_hard", randf_range(0.95, 1.06), -3.0)


func _on_brick_destroyed(brick: Brick, by_chain: bool) -> void:
	combo += 1
	best_combo = maxi(best_combo, combo)
	_bricks_this_level += 1
	_apply_ball_speed()

	var points := brick.score_value() * _combo_multiplier()
	score += points

	effects.brick_smashed(brick.rect, brick.color(), brick.shard_count(), brick.type == Brick.Type.GLASS)
	effects.score_popup(brick.rect.get_center(), points)
	background.flash_near(brick.rect.get_center(), randi_range(5, 8), brick.color())

	match brick.type:
		Brick.Type.BLAST:
			var area := Rect2(brick.rect.position - BrickGrid.PITCH, brick.rect.size + BrickGrid.PITCH * 2.0)
			effects.blast(brick.rect, area)
			_shake(SHAKE_BLAST)
			game_feel.hitstop(HITSTOP_BLAST)
			audio.play("blast", randf_range(0.94, 1.06))
		Brick.Type.GLASS:
			audio.play("glass", randf_range(0.94, 1.08), -2.0)
			if not by_chain:
				game_feel.hitstop(HITSTOP_BRICK)
		Brick.Type.PULSE:
			# Pulse-kernen sender en større lysbølge end normalt.
			effects.shockwave(brick.rect.get_center(), 54.0, brick.color())
			background.field_glint()
			audio.play_brick(combo, "brick", 1.0)
			if not by_chain:
				game_feel.hitstop(HITSTOP_BRICK)
		_:
			audio.play_brick(combo)
			if not by_chain:
				game_feel.hitstop(HITSTOP_BRICK)

	if combo == 5 or combo == 10 or combo == 20:
		effects.combo(combo)
		audio.play("combo", 1.0 + float(combo) * 0.01, -4.0)
	background.set_intensity(combo)
	audio.set_drone_intensity(combo)

	powerups.roll_for(brick.rect.get_center(), brick.powerup_chance())
	_refresh_hud()


func _on_brick_revealed(brick: Brick) -> void:
	effects.sparks(brick.rect.get_center(), Vector2.UP, 2, brick.color())


func _on_stone_popped(brick: Brick) -> void:
	effects.brick_smashed(brick.rect, brick.color(), 8)
	effects.shockwave(brick.rect.get_center(), 40.0, Arena.VOLT)
	audio.play("brick", randf_range(0.7, 0.85), -4.0)


func _on_level_cleared() -> void:
	if state != State.PLAYING:
		return
	arena.celebrate()
	background.blitz()
	audio.play("level_clear")
	_set_state(State.LEVEL_CLEAR)


func _on_ball_lost(ball: Ball) -> void:
	_remove_ball(ball)
	if not _balls.is_empty():
		return
	if state != State.PLAYING:
		return

	lives -= 1
	combo = 0
	effects.ball_lost(Vector2(ball.global_position.x, arena.death_y - 6.0))
	arena.set_danger(1.0)
	background.dim()
	audio.play("life_lost")
	audio.set_drone_intensity(0)
	powerups.reset_level()
	paddle.set_width(Paddle.WIDTH_NORMAL)
	paddle.laser = false
	powerups.guarantee_good()

	if lives <= 0:
		screens.high_score = GameSettings.high_score
		screens.new_record = GameSettings.submit_score(score)
		screens.final_score = score
		audio.play("game_over")
		_set_state(State.GAME_OVER)
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
	effects.powerup_icon(paddle.global_position - Vector2(0.0, 22.0), str(info["name"]), info["color"])
	audio.play("powerup_good" if Powerup.is_good(id) else "powerup_bad", 1.0, -2.0)

	match id:
		"multi":
			_split_balls()
		"life":
			lives += 1
	_sync_powerup_state()
	_refresh_hud()


func _on_powerup_expired(_id: String) -> void:
	_sync_powerup_state()


## Alt, der har en varighed, udledes af listen over aktive power-ups.
## Så kan to modsatrettede aldrig efterlade paddlen i en umulig tilstand.
func _sync_powerup_state() -> void:
	var active := powerups.active_effects()

	var width := Paddle.WIDTH_NORMAL
	if active.has("wide"):
		width = Paddle.WIDTH_WIDE
	elif active.has("narrow"):
		width = Paddle.WIDTH_NARROW
	paddle.set_width(width)
	paddle.laser = active.has("laser")

	var scale := 1.0
	if active.has("slow"):
		scale = 0.7
	elif active.has("fast"):
		scale = 1.4
	for ball in _balls:
		ball.speed_scale = scale
		ball.fireball = active.has("fireball")
		ball.zap = active.has("zap")


## Multi: bolden deler sig i 3.
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
	if combo >= 20:
		return 4
	if combo >= 10:
		return 3
	if combo >= 5:
		return 2
	return 1


## Hastigheden starter på levelets egen og stiger 4 procent per 10
## klodser, med loft ved 520 px/s. Det er den, der gør, at et level
## slutter hurtigere end det begynder.
func level_ball_speed() -> float:
	var base := float(level_data.get("ballSpeed", Ball.BASE_SPEED))
	var steps := _bricks_this_level / Ball.SPEED_STEP_BRICKS
	return minf(base * pow(Ball.SPEED_STEP, float(steps)), Ball.MAX_SPEED)


func _apply_ball_speed() -> void:
	var speed := level_ball_speed()
	for ball in _balls:
		ball.speed_base = speed


# --- Løkke -------------------------------------------------------------

func _process(delta: float) -> void:
	background.set_focus_x(paddle.position.x)
	_update_danger()
	_update_lasers()

	var positions: Array[Vector2] = []
	for ball in _balls:
		positions.append(ball.global_position)
	grid.update_proximity(positions)

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
	hud.lives = maxi(lives, 0)
	hud.max_lives = maxi(START_LIVES, lives)
	hud.combo = combo
	hud.active = powerups.active_effects()
	hud.visible = state != State.TITLE and state != State.SETTINGS


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo:
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
			KEY_ESCAPE:
				if state == State.PLAYING or state == State.LEVEL_INTRO:
					_set_state(State.TITLE)


func _update_debug() -> void:
	hud.active = powerups.active_effects()
	var ball: Ball = _balls[0] if not _balls.is_empty() else null
	var lines := [
		"FPS        %d" % Engine.get_frames_per_second(),
		"STATE      %s" % State.keys()[state],
		"LEVEL      %d %s" % [int(level_data.get("id", 0)), str(level_data.get("name", ""))],
		"BRICKS     %d left" % grid.remaining_breakable(),
		"BALLS      %d" % _balls.size(),
		"COMBO      %d (best %d, x%d)" % [combo, best_combo, _combo_multiplier()],
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
