extends Node

## Game Center, and the seam it sits behind.
##
## Registered as an autoload named GameCenterLink. Godot 4 has no Game
## Center of its own — the 3.x module did not come across — so the real
## thing is an iOS plugin that has to be built against the export
## templates and cannot exist until the app has a record in App Store
## Connect with its leaderboards and achievements defined.
##
## What is here is the whole surface the game calls, with the platform
## behind it optional. With no plugin present every call is a no-op that
## returns false: on a Mac, in a test, in a headless run, and on a phone
## with Game Center switched off or no network. Nothing here ever blocks
## play, ever shows a dialogue, and ever fails loudly. A player who has
## never heard of Game Center must not be able to tell it is here.
##
## The ids below are the contract with App Store Connect. They are listed
## in docs/gamecenter.md, and they are what has to be typed in there.

signal authenticated(ok: bool)

const SINGLETON := "GameCenter"

## Leaderboards.
const BOARD_TOTAL_STARS := "astroball.stars.total"
const BOARD_LEVEL_PREFIX := "astroball.level."

## Achievements, and what earns them. The names are what a player sees.
const ACHIEVEMENTS := {
	"first_breach": "FIRST BREACH",
	"chain_of_five": "CHAIN OF FIVE",
	"clean_sweep": "CLEAN SWEEP",
	"ahead_of_schedule": "AHEAD OF SCHEDULE",
	"three_of_three": "THREE OF THREE",
	"patience": "PATIENCE",
	"one_hit": "ONE HIT",
	"the_drift_cleared": "THE DRIFT CLEARED",
	"constellation_charted": "CONSTELLATION CHARTED",
	"full_chart": "FULL CHART",
}

var _platform: Object = null
var _signed_in := false
## Reported achievements, so the same one is not sent every level.
var _sent: Dictionary = {}


func _ready() -> void:
	if Engine.has_singleton(SINGLETON):
		_platform = Engine.get_singleton(SINGLETON)
	authenticate()


## Quietly. There is no waiting on this and no screen behind it: the
## player is in a level before the answer arrives, either way.
func authenticate() -> bool:
	if _platform == null:
		authenticated.emit(false)
		return false
	if not _platform.has_method("authenticate"):
		authenticated.emit(false)
		return false
	_platform.call("authenticate")
	_signed_in = true
	authenticated.emit(true)
	return true


func is_available() -> bool:
	return _platform != null


func is_signed_in() -> bool:
	return _signed_in


## A score for one board. Returns whether it actually went anywhere.
func submit_score(board: String, value: int) -> bool:
	if value <= 0 or not _signed_in or _platform == null:
		return false
	if not _platform.has_method("post_score"):
		return false
	_platform.call("post_score", {"score": value, "category": board})
	return true


func submit_level_score(level_id: int, value: int) -> bool:
	return submit_score("%s%02d" % [BOARD_LEVEL_PREFIX, level_id], value)


func submit_total_stars(stars: int) -> bool:
	return submit_score(BOARD_TOTAL_STARS, stars)


## An achievement, once. Sending the same one on every level clear is
## harmless on Apple's side and noise on ours.
func report(id: String, percent := 100.0) -> bool:
	if not ACHIEVEMENTS.has(id):
		push_error("GameCenterLink: no achievement '%s'" % id)
		return false
	if _sent.get(id, 0.0) >= percent:
		return false
	_sent[id] = percent
	if not _signed_in or _platform == null:
		return false
	if not _platform.has_method("award_achievement"):
		return false
	_platform.call("award_achievement",
		{"name": id, "progress": clampf(percent, 0.0, 100.0)})
	return true


## Test-only: forgets what has been sent, so a suite can check the rules
## rather than the order it happened to run in.
func forget() -> void:
	_sent.clear()
