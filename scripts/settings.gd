extends Node

## Indstillinger, der overlever et genstart.
##
## Registreret som autoload under navnet GameSettings, fordi lyd, CRT og
## skærmene alle skal kunne læse dem uden at kende hinanden.

signal changed()

const PATH := "user://settings.cfg"

var sound_on := true
var volume := 0.8
## Afsnit 12: nostalgi som tilvalg, moderne som standard.
var crt := false
var screen_shake := true
var high_score := 0


func _ready() -> void:
	load_settings()


func load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(PATH) != OK:
		return
	sound_on = bool(cfg.get_value("audio", "sound_on", sound_on))
	volume = clampf(float(cfg.get_value("audio", "volume", volume)), 0.0, 1.0)
	crt = bool(cfg.get_value("video", "crt", crt))
	screen_shake = bool(cfg.get_value("video", "screen_shake", screen_shake))
	high_score = int(cfg.get_value("play", "high_score", high_score))


func save_settings() -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("audio", "sound_on", sound_on)
	cfg.set_value("audio", "volume", volume)
	cfg.set_value("video", "crt", crt)
	cfg.set_value("video", "screen_shake", screen_shake)
	cfg.set_value("play", "high_score", high_score)
	cfg.save(PATH)


func apply() -> void:
	save_settings()
	changed.emit()


## Returnerer true, hvis rekorden blev slået.
func submit_score(value: int) -> bool:
	if value <= high_score:
		return false
	high_score = value
	save_settings()
	return true
