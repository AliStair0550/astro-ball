extends Node

## Spiller alle tre levels igennem med autopilot og holder øje med, at
## intet bryder sammen undervejs. Tiden køres 6 gange hurtigere ved at
## hæve både time_scale og fysikfrekvensen, så delta pr. tick stadig
## er 1/60 og kollisionen opfører sig som i rigtigt spil.

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
	var paddle := game.paddle
	var target: Ball = null
	var lowest := -INF
	for ball in game._balls:
		if ball.stuck:
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
		if p.x < Arena.WALL + Ball.RADIUS - 0.8 or p.x > Arena.SCREEN.x - Arena.WALL - Ball.RADIUS + 0.8:
			_err("bold uden for feltet i x: %.2f" % p.x)
		if p.y < Arena.HUD_HEIGHT + Arena.WALL + Ball.RADIUS - 0.8:
			_err("bold uden for feltet i y: %.2f" % p.y)
		if not ball.stuck and not ball.frozen:
			var speed := ball.velocity.length()
			max_speed = maxf(max_speed, speed)
			if absf(speed - ball.current_speed()) > 1.0:
				_err("fart afveg: %.1f mod %.1f" % [speed, ball.current_speed()])
			if speed > Ball.MAX_SPEED * 1.15:
				_err("farten brød loftet: %.1f" % speed)
			var ang := rad_to_deg(atan2(absf(ball.velocity.y), absf(ball.velocity.x)))
			min_angle = minf(min_angle, ang)
			if ang < 19.5:
				_err("vinkel under 20 grader: %.2f" % ang)

	max_balls_seen = maxi(max_balls_seen, game._balls.size())
	if game._balls.size() > Game.MAX_BALLS:
		_err("for mange bolde: %d" % game._balls.size())
	if game.score < last_score and game.state != Game.State.GAME_OVER:
		_err("scoren faldt: %d -> %d" % [last_score, game.score])
	last_score = game.score
	if game.lives < 0:
		_err("negativt antal liv")

	var r := game.paddle.world_rect()
	if r.position.x < Arena.WALL - 0.01 or r.end.x > Arena.SCREEN.x - Arena.WALL + 0.01:
		_err("paddlen stikker ud af feltet: %.1f til %.1f" % [r.position.x, r.end.x])

	# Klodserne må aldrig nå ned i paddlens bane.
	for brick in game.grid.live_bricks():
		if brick.rect.end.y > game.paddle.top_y() - 40.0:
			_err("klods for tæt på paddlen: y=%.0f" % brick.rect.end.y)
			break


func _err(msg: String) -> void:
	var line := "t=%.1fs: %s" % [elapsed, msg]
	if errors.size() < 14 and not errors.has(line):
		errors.append(line)


func _report() -> void:
	done = true
	print("--- SPIL: %.0f sekunder simuleret, %d frames ---" % [elapsed, frames])
	print("levels ryddet:     %d" % levels_cleared)
	for i in level_times.size():
		print("   level %d:        %.0f sekunder" % [i + 1, level_times[i]])
	print("klodser smadret:   %d (heraf %d af kæder)" % [bricks_destroyed, chains])
	print("power-ups samlet:  %d %s" % [powerups_collected, str(powerup_counts)])
	print("flest bolde:       %d" % max_balls_seen)
	print("hurtigste bold:    %.0f px/s (loft %.0f)" % [max_speed, Ball.MAX_SPEED])
	print("score:             %d" % game.score)
	print("mindste vinkel:    %.2f grader" % min_angle)
	print("fejl:              %d" % errors.size())
	for e in errors:
		print("   " + e)
	get_tree().quit(1 if errors.size() > 0 else 0)
