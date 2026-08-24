class_name FeelTest
extends Node

## The feel lab. Not a test suite, not part of the game.
##
## Section 13, point 2: smash one brick two hundred times until it feels
## right. This scene exists so that can be done without playing a level
## first. It borrows the whole game and only replaces the field.
##
##   1  one Volt brick, respawns 500 ms after it breaks
##   2  a wall, 11 wide and 6 rows, for mass destruction and combo pitch
##   3  the same wall with the ball pinned at 520 px/s
##
## F1 shows combo, live shard count and hits landed.
## R resets the counter.

enum Mode { SINGLE, WALL, MAX_SPEED }

const RESPAWN_DELAY := 0.5
const MAX_SPEED := 520.0
## Row 11 puts the single brick low enough that the trip back is short.
const SINGLE_ROW := 11
const WALL_ROWS := 6

var game: Game
var mode := Mode.SINGLE
var hits := 0
var respawn_timer := 0.0
var _label: Label


func _ready() -> void:
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game

	# The lab never ends. No level clear, no game over, no menus.
	game.grid.cleared.disconnect(game._on_level_cleared)
	game.grid.cleared.connect(_on_field_cleared)
	game.grid.brick_destroyed.connect(func(_b, _chain): hits += 1)
	game.lives = 9999

	_label = Label.new()
	_label.position = Vector2(12.0, 150.0)
	_label.add_theme_font_size_override("font_size", 12)
	_label.add_theme_color_override("font_color", Color("D6FF3D"))
	_label.add_theme_color_override("font_outline_color", Color("07070C"))
	_label.add_theme_constant_override("outline_size", 4)
	game.get_node("HUDLayer").add_child(_label)

	set_mode(Mode.SINGLE)


func set_mode(new_mode: Mode) -> void:
	mode = new_mode
	hits = 0
	respawn_timer = 0.0
	game.hud.visible = false
	game.screens.show_screen(Screens.Screen.NONE)
	game.state = Game.State.PLAYING
	game.paddle.input_enabled = true
	game.combo = 0
	game.score = 0
	game.run.start_level()
	# The lab holds one speed so the hand can learn it.
	game.level_data["ballSpeed"] = MAX_SPEED if mode == Mode.MAX_SPEED else Ball.BASE_SPEED

	_build_field()
	game._clear_balls()
	var ball := game._spawn_ball(true)
	ball.input_enabled = true
	ball.frozen = false
	game.audio.start_drone()


func _build_field() -> void:
	var rows: Array[String] = []
	match mode:
		Mode.SINGLE:
			for i in SINGLE_ROW:
				rows.append(".............")
			rows.append("......V......")
		_:
			for i in WALL_ROWS:
				rows.append(".VVVVVVVVVVV.")
	game.grid.build(rows)


func _on_field_cleared() -> void:
	respawn_timer = RESPAWN_DELAY


func _process(delta: float) -> void:
	if respawn_timer > 0.0:
		respawn_timer -= delta
		if respawn_timer <= 0.0:
			_build_field()

	# A lost ball costs nothing here. It comes straight back.
	# Zeroing the timer is not enough: the game only advances state while
	# the timer is above zero, so setting it to exactly zero strands the
	# lab in BALL_LOST with no ball and no way out.
	if game.state == Game.State.BALL_LOST:
		game._state_timer = 0.0
		game._advance_state()

	_label.text = "\n".join([
		"FEEL TEST   1 single   2 wall   3 max speed   R reset",
		"MODE        %s" % Mode.keys()[mode],
		"HITS        %d" % hits,
		"COMBO       %d" % game.combo,
		"SHARDS      %d" % game.effects.shard_count(),
		"SPEED       %.0f px/s" % (game._balls[0].current_speed() if not game._balls.is_empty() else 0.0),
		"BRICKS      %d left" % game.grid.remaining_breakable(),
	])


func _input(event: InputEvent) -> void:
	if not (event is InputEventKey and event.pressed and not event.echo):
		return
	match event.keycode:
		KEY_1:
			set_mode(Mode.SINGLE)
		KEY_2:
			set_mode(Mode.WALL)
		KEY_3:
			set_mode(Mode.MAX_SPEED)
		KEY_R:
			hits = 0
