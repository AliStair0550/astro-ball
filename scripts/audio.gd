class_name Audio
extends Node

## Lyden.
##
## Afsnit 12: alle lyde har en kort, mørk rumklang, som om feltet er et
## stort kammer. Selve samplerne er tørre. Klangen lægges på i en bus, så
## alt sidder i det samme rum i stedet for at have hver sin bagte klang.
## Det er den billigste vej til at føle sig inde i rummet i stedet for
## foran en skærm.
##
## Under spil er der ingen musik, kun en dyb, næsten uhørlig drone, der
## stiger en anelse i intensitet med komboen.

const BANK := {
	"brick": "res://assets/audio/brick.wav",
	"brick_hard": "res://assets/audio/brick_hard.wav",
	"blast": "res://assets/audio/blast.wav",
	"glass": "res://assets/audio/glass.wav",
	"paddle": "res://assets/audio/paddle.wav",
	"wall": "res://assets/audio/wall.wav",
	"powerup_good": "res://assets/audio/powerup_good.wav",
	"powerup_bad": "res://assets/audio/powerup_bad.wav",
	"laser": "res://assets/audio/laser.wav",
	"life_lost": "res://assets/audio/life_lost.wav",
	"level_clear": "res://assets/audio/level_clear.wav",
	"game_over": "res://assets/audio/game_over.wav",
	"combo": "res://assets/audio/combo.wav",
	"launch": "res://assets/audio/launch.wav",
	"ui_move": "res://assets/audio/ui_move.wav",
	"ui_select": "res://assets/audio/ui_select.wav",
	"ui_back": "res://assets/audio/ui_back.wav",
}

const DRONE_PATH := "res://assets/audio/drone.wav"
const VOICES := 14
## Klods-klik stiger i tonehøjde med komboen, maks en oktav.
const MAX_COMBO_SEMITONES := 12.0

var _streams: Dictionary = {}
var _voices: Array[AudioStreamPlayer] = []
var _next_voice := 0
var _drone: AudioStreamPlayer
var _drone_target := 0.0
var _drone_level := 0.0
var _sfx_bus := 1
var _drone_bus := 2
var _drone_filter: AudioEffectLowPassFilter


func _ready() -> void:
	_build_buses()
	for id in BANK:
		_streams[id] = load(BANK[id])

	for i in VOICES:
		var player := AudioStreamPlayer.new()
		player.bus = "SFX"
		add_child(player)
		_voices.append(player)

	_drone = AudioStreamPlayer.new()
	_drone.bus = "Drone"
	var drone_stream: AudioStreamWAV = load(DRONE_PATH)
	drone_stream.loop_mode = AudioStreamWAV.LOOP_FORWARD
	drone_stream.loop_begin = 0
	drone_stream.loop_end = drone_stream.data.size() / 2
	_drone.stream = drone_stream
	add_child(_drone)

	if has_node("/root/GameSettings"):
		get_node("/root/GameSettings").changed.connect(_apply_settings)
	_apply_settings()


func _build_buses() -> void:
	# SFX: kammeret. Stort rum, kraftig dæmpning, så klangen er mørk.
	_sfx_bus = AudioServer.bus_count
	AudioServer.add_bus(_sfx_bus)
	AudioServer.set_bus_name(_sfx_bus, "SFX")
	AudioServer.set_bus_send(_sfx_bus, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.72
	reverb.damping = 0.68
	reverb.spread = 0.85
	reverb.predelay_msec = 14.0
	reverb.predelay_feedback = 0.25
	reverb.wet = 0.30
	reverb.dry = 0.92
	AudioServer.add_bus_effect(_sfx_bus, reverb)

	# Dronen: samme rum, men bag et filter, så den ligger under alt andet.
	_drone_bus = AudioServer.bus_count
	AudioServer.add_bus(_drone_bus)
	AudioServer.set_bus_name(_drone_bus, "Drone")
	AudioServer.set_bus_send(_drone_bus, "Master")
	_drone_filter = AudioEffectLowPassFilter.new()
	_drone_filter.cutoff_hz = 320.0
	_drone_filter.resonance = 0.2
	AudioServer.add_bus_effect(_drone_bus, _drone_filter)
	var drone_reverb := AudioEffectReverb.new()
	drone_reverb.room_size = 0.9
	drone_reverb.damping = 0.8
	drone_reverb.wet = 0.4
	drone_reverb.dry = 0.8
	AudioServer.add_bus_effect(_drone_bus, drone_reverb)


func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


func _apply_settings() -> void:
	var s := _settings()
	var on := true
	var vol := 0.8
	if s:
		on = s.sound_on
		vol = s.volume
	var db := linear_to_db(clampf(vol, 0.0001, 1.0))
	AudioServer.set_bus_mute(_sfx_bus, not on)
	AudioServer.set_bus_mute(_drone_bus, not on)
	AudioServer.set_bus_volume_db(_sfx_bus, db)
	AudioServer.set_bus_volume_db(_drone_bus, db - 4.0)


## Spiller en lyd. pitch er en faktor, ikke halvtoner.
func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(id):
		return
	var player := _pick_voice()
	player.stream = _streams[id]
	player.pitch_scale = clampf(pitch, 0.2, 4.0)
	player.volume_db = volume_db
	player.play()


## Klodsens klik stiger i tonehøjde med komboen og nulstilles ved
## paddle-ramt. Det er den enkleste måde at gøre en lang tur oppe bag
## muren til noget, man kan høre.
func play_brick(combo: int, id := "brick", volume_db := 0.0) -> void:
	var semitones := minf(float(maxi(combo - 1, 0)), MAX_COMBO_SEMITONES)
	play(id, pow(2.0, semitones / 12.0), volume_db)


func _pick_voice() -> AudioStreamPlayer:
	for i in VOICES:
		var index := (_next_voice + i) % VOICES
		if not _voices[index].playing:
			_next_voice = (index + 1) % VOICES
			return _voices[index]
	var fallback := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	return fallback


## Stopper alt med det samme. Bruges ved nedlukning og af testene, så
## motoren ikke lukker ned oven i en lyd, der stadig kører.
func stop_all() -> void:
	for voice in _voices:
		voice.stop()
	if _drone:
		_drone.stop()
	_drone_level = 0.0
	_drone_target = 0.0


func start_drone() -> void:
	if not _drone.playing:
		_drone.play()
	_drone_target = 1.0


func stop_drone() -> void:
	_drone_target = 0.0


## Dronen stiger en anelse med komboen. En anelse, ikke mere.
func set_drone_intensity(combo: int) -> void:
	_drone_target = 1.0 + clampf(float(combo) / 20.0, 0.0, 1.0) * 0.85


func _process(delta: float) -> void:
	_drone_level = move_toward(_drone_level, _drone_target, delta * 1.2)
	if _drone_level <= 0.001:
		if _drone.playing:
			_drone.stop()
		return
	if not _drone.playing and _drone_target > 0.0:
		_drone.play()
	_drone.volume_db = linear_to_db(clampf(_drone_level * 0.16, 0.0001, 1.0))
	_drone_filter.cutoff_hz = lerpf(240.0, 520.0, clampf(_drone_level - 1.0, 0.0, 1.0))
