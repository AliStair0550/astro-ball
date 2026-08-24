extends Node

## Settings that survive a restart.
##
## Registered as an autoload named GameSettings, because audio, CRT and
## the screens all need to read them without knowing about each other.
##
## The list is section 17 of the design document, whole and closed.
## Nothing is added to it without a decision.

signal changed()

const PATH := "user://settings.cfg"

var sound := true
var music := true
## Stored now, used when touch control lands in phase 4.
var haptics := true
## Section 12: nostalgia is opt-in, modern is the default.
var crt := false
## Mirrors buttons on the screens. Never gameplay.
var left_handed := false

var high_score := 0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sound = bool(cfg.get_value("audio", "sound", sound))
	music = bool(cfg.get_value("audio", "music", music))
	haptics = bool(cfg.get_value("input", "haptics", haptics))
	crt = bool(cfg.get_value("video", "crt", crt))
	left_handed = bool(cfg.get_value("video", "left_handed", left_handed))
	high_score = int(cfg.get_value("progress", "high_score", high_score))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound", sound)
	cfg.set_value("audio", "music", music)
	cfg.set_value("input", "haptics", haptics)
	cfg.set_value("video", "crt", crt)
	cfg.set_value("video", "left_handed", left_handed)
	cfg.set_value("progress", "high_score", high_score)
	cfg.save(PATH)


func apply() -> void:
	save_settings()
	changed.emit()


## Returns true if the record was beaten.
func submit_score(value: int) -> bool:
	if value <= high_score:
		return false
	high_score = value
	save_settings()
	return true


## Reset Progress. Stars and zone progression join this once they exist.
func reset_progress() -> void:
	high_score = 0
	save_settings()
	changed.emit()
