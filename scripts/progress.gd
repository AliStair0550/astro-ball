extends Node

## What survives the app closing: stars, records and the quiet count of
## how many times a field has beaten you.
##
## Registered as an autoload named GameProgress. Settings and progress
## are kept apart on purpose: RESET PROGRESS erases this file and leaves
## your sound and CRT choices alone.
##
## Section 15 gives three stars per level, and they are independent. You
## can earn the third without the second, so they are stored as bits and
## merged across attempts rather than replaced by the latest run.

signal changed()

const PATH := "user://progress.json"

## Star bits, section 15.
const STAR_CLEARED := 1
const STAR_UNDER_PAR := 2
const STAR_NO_LOSS := 4
const ALL_STARS := STAR_CLEARED | STAR_UNDER_PAR | STAR_NO_LOSS

## Section 15: three fails in a row on the same field quietly raise the
## share of good power-ups. The player is never told.
const HELPER_AFTER_FAILS := 3
const HELPER_POINTS := 15.0

var high_score := 0
## level id as a string -> {"stars": int, "fails": int, "best_time": float}
var levels: Dictionary = {}


func _ready() -> void:
	load_progress()


func load_progress() -> void:
	if not FileAccess.file_exists(PATH):
		return
	var text := FileAccess.get_file_as_string(PATH)
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_error("Progress file is not valid JSON, starting fresh")
		return
	var data: Dictionary = parsed
	high_score = int(data.get("high_score", 0))
	levels = {}
	var stored: Dictionary = data.get("levels", {})
	for key in stored:
		var entry: Dictionary = stored[key]
		levels[str(key)] = {
			"stars": int(entry.get("stars", 0)) & ALL_STARS,
			"fails": maxi(int(entry.get("fails", 0)), 0),
			"best_time": maxf(float(entry.get("best_time", 0.0)), 0.0),
		}


func save_progress() -> void:
	var data := {"high_score": high_score, "levels": levels}
	var file := FileAccess.open(PATH, FileAccess.WRITE)
	if file == null:
		push_error("Could not write %s" % PATH)
		return
	file.store_string(JSON.stringify(data, "\t"))
	file.close()


func _entry(level_id: int) -> Dictionary:
	var key := str(level_id)
	if not levels.has(key):
		levels[key] = {"stars": 0, "fails": 0, "best_time": 0.0}
	return levels[key]


func stars_for(level_id: int) -> int:
	return int(_entry(level_id)["stars"])


func star_count(level_id: int) -> int:
	var bits := stars_for(level_id)
	var n := 0
	for bit in [STAR_CLEARED, STAR_UNDER_PAR, STAR_NO_LOSS]:
		if bits & bit:
			n += 1
	return n


func best_time(level_id: int) -> float:
	return float(_entry(level_id)["best_time"])


## Which stars a run earned. Section 15: cleared, cleared under par,
## cleared without losing the ball. Independent of each other.
static func stars_earned(cleared: bool, seconds: float, par_time: float, lost_a_ball: bool) -> int:
	if not cleared:
		return 0
	var bits := STAR_CLEARED
	if par_time > 0.0 and seconds <= par_time:
		bits |= STAR_UNDER_PAR
	if not lost_a_ball:
		bits |= STAR_NO_LOSS
	return bits


## A cleared field merges its stars with what was already earned, so a
## later run can add the third star without giving up the second.
func record_clear(level_id: int, stars: int, seconds: float) -> void:
	var entry := _entry(level_id)
	entry["stars"] = int(entry["stars"]) | (stars & ALL_STARS)
	entry["fails"] = 0
	var previous := float(entry["best_time"])
	if previous <= 0.0 or seconds < previous:
		entry["best_time"] = seconds
	save_progress()
	changed.emit()


func record_fail(level_id: int) -> void:
	var entry := _entry(level_id)
	entry["fails"] = int(entry["fails"]) + 1
	save_progress()
	changed.emit()


func consecutive_fails(level_id: int) -> int:
	return int(_entry(level_id)["fails"])


## Section 15, the quiet helper. Nothing on screen, nothing in the sound.
func helper_points(level_id: int) -> float:
	return HELPER_POINTS if consecutive_fails(level_id) >= HELPER_AFTER_FAILS else 0.0


func helper_active(level_id: int) -> bool:
	return helper_points(level_id) > 0.0


## Returns true if the record was beaten.
func submit_score(value: int) -> bool:
	if value <= high_score:
		return false
	high_score = value
	save_progress()
	changed.emit()
	return true


## RESET PROGRESS, section 17. Stars, records and fail counts, all of it.
func reset() -> void:
	high_score = 0
	levels = {}
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	save_progress()
	changed.emit()
