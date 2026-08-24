extends Node

## Plays all three levels through on autopilot and watches that nothing
## breaks on the way. Time runs 6 times faster by raising both
## time_scale and the physics rate, so delta per tick is still 1/60 and
## collision behaves exactly as it does in a real game.

const SPEEDUP := 6.0
const MAX_SECONDS := 900.0

var game: Game
var frames := 0
var errors: Array[String] = []
var levels_cleared := 0
var bricks_destroyed := 0
var powerups_collected := 0
var chains := 0
var last_score := 0
var min_angle := 999.0
var max_speed := 0.0
var max_balls_seen := 0
var offset_bias := 0.0
var elapsed := 0.0
var level_started := 0.0
var level_times: Array[float] = []
var powerup_counts: Dictionary = {}
var done := false


func _ready() -> void:
	seed(99)
	Engine.time_scale = SPEEDUP
	Engine.physics_ticks_per_second = int(60.0 * SPEEDUP)
	Engine.max_physics_steps_per_frame = 16

	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game
	game.paddle.set_physics_process(false)
	# Spring titel og intro over, saa autopiloten kan gaa i gang.
	game.call_deferred("_on_screen_action", "play")
	game.grid.brick_destroyed.connect(func(_b, by_chain):
		bricks_destroyed += 1
		if by_chain:
			chains += 1
	)
	game.grid.cleared.connect(func():
		levels_cleared += 1
		level_times.append(elapsed - level_started)
		level_started = elapsed
	)
	game.powerups.collected.connect(func(id):
		powerups_collected += 1
		powerup_counts[id] = int(powerup_counts.get(id, 0)) + 1
	)


func _physics_process(delta: float) -> void:
	if done:
		return
	frames += 1
	elapsed += delta

	_autopilot()
	_check_invariants()

	if levels_cleared >= 3 or elapsed > MAX_SECONDS:
		_report()


func _autopilot() -> void:
	# The intro screens get clicked away.
	if game.state == Game.State.LEVEL_INTRO or game.state == Game.State.LEVEL_CLEAR:
		game._on_screen_action("skip")
		return
	if game.state != Game.State.PLAYING and game.state != Game.State.BALL_LOST:
		return
	var paddle := game.paddle
	var target: Ball = null
	var lowest := -INF
	for ball in game._balls:
		if ball.stuck and game.state == Game.State.PLAYING:
			ball.launch()
		if ball.global_position.y > lowest:
			lowest = ball.global_position.y
			target = ball

	var capsule_x := INF
	for capsule in game.powerups._capsules:
		if is_instance_valid(capsule) and capsule.position.y > 560.0:
			capsule_x = capsule.position.x

	if frames % 90 == 0:
		offset_bias = randf_range(-1.0, 1.0) * (paddle.half_width() - 4.0)

	var want := paddle.position.x
	if target:
		want = target.global_position.x - offset_bias
		if capsule_x != INF and lowest < 640.0:
			want = capsule_x
	paddle.position.x = clampf(want, paddle.min_x, paddle.max_x)
	if paddle.laser and frames % 12 == 0:
		paddle.fire_laser()


func _check_invariants() -> void:
	for ball in game._balls:
		var p := ball.global_position
		if not is_finite(p.x) or not is_finite(p.y):
			_err("boldposition er ikke et tal")
			continue
		if p.x < Arena.WALL + ball.radius - 0.8 or p.x > Arena.SCREEN.x - Arena.WALL - ball.radius + 0.8:
			_err("ball outside the field in x: %.2f" % p.x)
		if p.y < Arena.HUD_HEIGHT + Arena.WALL + ball.radius - 0.8:
			_err("ball outside the field in y: %.2f" % p.y)
		if not ball.stuck and not ball.frozen:
			var speed := ball.velocity.length()
			max_speed = maxf(max_speed, speed)
			if absf(speed - ball.current_speed()) > 1.0:
				_err("speed drifted: %.1f against %.1f" % [speed, ball.current_speed()])
			if speed > Ball.MAX_SPEED * 1.15:
				_err("speed broke the cap: %.1f" % speed)
			var ang := rad_to_deg(atan2(absf(ball.velocity.y), absf(ball.velocity.x)))
			min_angle = minf(min_angle, ang)
			if ang < 19.5:
				_err("angle below 20 degrees: %.2f" % ang)

	max_balls_seen = maxi(max_balls_seen, game._balls.size())
	if game._balls.size() > Game.MAX_BALLS:
		_err("too many balls: %d" % game._balls.size())
	if game.score < last_score and game.state != Game.State.SIGNAL_LOST:
		_err("the score fell: %d -> %d" % [last_score, game.score])
	last_score = game.score
	if game.lives < 0:
		_err("negative life count")

	var r := game.paddle.world_rect()
	if r.position.x < Arena.WALL - 0.01 or r.end.x > Arena.SCREEN.x - Arena.WALL + 0.01:
		_err("the paddle sticks out of the field: %.1f to %.1f" % [r.position.x, r.end.x])

	# The bricks must never reach the paddle's lane.
	for brick in game.grid.live_bricks():
		if brick.rect.end.y > game.paddle.top_y() - 40.0:
			_err("brick too close to the paddle: y=%.0f" % brick.rect.end.y)
			break


func _err(msg: String) -> void:
	var line := "t=%.1fs: %s" % [elapsed, msg]
	if errors.size() < 14 and not errors.has(line):
		errors.append(line)


func _report() -> void:
	done = true
	print("--- PLAY: %.0f seconds simulated, %d frames ---" % [elapsed, frames])
	print("fields cleared:    %d" % levels_cleared)
	for i in level_times.size():
		print("   level %d:        %.0f seconds" % [i + 1, level_times[i]])
	print("bricks broken:     %d (%d by chains)" % [bricks_destroyed, chains])
	print("power-ups caught:  %d %s" % [powerups_collected, str(powerup_counts)])
	print("most balls:        %d" % max_balls_seen)
	print("fastest ball:      %.0f px/s (cap %.0f)" % [max_speed, Ball.MAX_SPEED])
	print("score:             %d" % game.score)
	print("smallest angle:    %.2f degrees" % min_angle)
	print("failures:          %d" % errors.size())
	for e in errors:
		print("   " + e)
	await _teardown()
	get_tree().quit(1 if errors.size() > 0 else 0)


## Rydder scenen af inden exit, saa motoren ikke rapporterer objekter,
## der bare stod i traeet, da vi lukkede midt i en frame.
func _teardown() -> void:
	# Time runs 6 times faster. Without resetting it the timer below
	# waits a sixth of what it appears to.
	Engine.time_scale = 1.0
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
	# noder, der bare stod i traeet, som laekager.
	await get_tree().process_frame
	await get_tree().process_frame
