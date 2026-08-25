extends Node

## What survives the app being closed in the middle of a level.
##
## Registered as an autoload named GameSession. Progress (stars, records)
## is GameProgress and is a different thing: this is one level in flight,
## and it is thrown away the moment that level ends, however it ends.
##
## Section 7 of phase 9: backgrounding pauses and persists the exact
## state, and coming back puts the ball on the paddle with the wall as it
## was. Across an app kill it keeps the level, the wall, the score and
## the lives.
##
## What it deliberately does not keep:
##
##   Capsules in flight. They are thrown away, because a capsule frozen
##   mid-air for two days and then dropped on a player who has forgotten
##   the level is not a kindness. Anything already caught and running is
##   dropped with them, for the same reason a lost ball clears them.
##
##   The ball's position and velocity. It comes back on the paddle,
##   waiting to be fired, which is the one state a player can always
##   read at a glance.

const PATH := "user://session.json"
## Bumped when the shape below changes, so an old file is ignored rather
## than half-read.
const FORMAT := 1

var _data: Dictionary = {}


func _ready() -> void:
	load_session()


func has_session() -> bool:
	return not _data.is_empty()


func data() -> Dictionary:
	return _data


## Everything needed to put one level back as it was.
func store(level_index: int, level_id: int, score: int, lives: int,
		bricks: Array, run_time: float, run_bricks: int, best_combo: int) -> void:
	_data = {
		"format": FORMAT,
		"level_index": level_index,
		"level_id": level_id,
		"score": maxi(score, 0),
		"lives": clampi(lives, 0, 9),
		"bricks": bricks,
		"run_time": maxf(run_time, 0.0),
		"run_bricks": maxi(run_bricks, 0),
		"best_combo": maxi(best_combo, 0),
	}
	save_session()


func clear() -> void:
	_data = {}
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))


func save_session() -> void:
	if _data.is_empty():
		clear()
		return
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % PATH)
		return
	file.store_string(JSON.stringify(_data))
	file.close()


func load_session() -> void:
	_data = {}
	if not FileAccess.file_exists(PATH):
		return
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(PATH))
	if typeof(parsed) != TYPE_DICTIONARY:
		# A half-written file is no session at all. Not an error worth
		# shouting about: the player loses one level, not their progress.
		clear()
		return
	var raw: Dictionary = parsed
	if int(raw.get("format", 0)) != FORMAT:
		clear()
		return
	if not raw.has("bricks") or typeof(raw["bricks"]) != TYPE_ARRAY:
		clear()
		return
	_data = raw
