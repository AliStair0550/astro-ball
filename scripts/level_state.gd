class_name LevelState
extends RefCounted

## The numbers a run is made of: lives, score, combo, and the two clocks
## that decide the stars.
##
## Kept out of the conductor on purpose. The state has no opinion about
## screens, bricks or sound, which means it can be tested on its own and
## the conductor stays a wiring diagram.

const START_LIVES := 3

var lives := START_LIVES
var score := 0
var combo := 0
var best_combo := 0

## Whole run, across levels. What SIGNAL LOST reports.
var run_bricks := 0
var run_time := 0.0

## This level only. What the stars are judged on.
var level_bricks := 0
var level_time := 0.0
var level_start_score := 0
var lost_a_ball := false
var re_entry_used := false


func start_run() -> void:
	lives = START_LIVES
	score = 0
	combo = 0
	best_combo = 0
	run_bricks = 0
	run_time = 0.0
	re_entry_used = false
	start_level()


func start_level() -> void:
	combo = 0
	level_bricks = 0
	level_time = 0.0
	level_start_score = score
	lost_a_ball = false


## Section 16: RESTART FIELD rolls the level score back and hands out
## three fresh lives. The run clock keeps running, because it did.
func restart_level() -> void:
	score = level_start_score
	lives = START_LIVES
	re_entry_used = false
	start_level()


func tick(delta: float) -> void:
	run_time += delta
	level_time += delta


## Combo multiplies the brick's own value. The design document sets no
## numbers here, so these are ours: see README.
func combo_multiplier() -> int:
	if combo >= 20:
		return 4
	if combo >= 10:
		return 3
	if combo >= 5:
		return 2
	return 1


## Returns the points scored.
func on_brick_destroyed(base_points: int) -> int:
	combo += 1
	best_combo = maxi(best_combo, combo)
	run_bricks += 1
	level_bricks += 1
	var points := base_points * combo_multiplier()
	score += points
	return points


## The combo resets on paddle contact. That is what makes a long run up
## behind the wall worth chasing.
func on_paddle_hit() -> void:
	combo = 0


## Returns true when that was the last life.
func on_ball_lost() -> bool:
	lives -= 1
	combo = 0
	lost_a_ball = true
	return lives <= 0


func on_re_entry() -> void:
	re_entry_used = true
	lives = 1


func add_life() -> void:
	lives += 1


func stars(par_time: float) -> int:
	return GameProgressStars.stars_earned(true, level_time, par_time, lost_a_ball)


## Indirection so the state does not need the autoload at parse time.
class GameProgressStars:
	const STAR_CLEARED := 1
	const STAR_UNDER_PAR := 2
	const STAR_NO_LOSS := 4

	static func stars_earned(cleared: bool, seconds: float, par_time: float, lost_ball: bool) -> int:
		if not cleared:
			return 0
		var bits := STAR_CLEARED
		if par_time > 0.0 and seconds <= par_time:
			bits |= STAR_UNDER_PAR
		if not lost_ball:
			bits |= STAR_NO_LOSS
		return bits
