class_name Audio
extends Node

## The sound.
##
## Section 12: every sound carries a short, dark reverb, as if the field
## were a large chamber. The samples themselves are dry. The reverb sits
## on a bus, so everything shares one room instead of baking its own.
## It is the cheapest way to feel inside space rather than in front of
## a screen.
##
## There is no music during play, only a deep, nearly inaudible drone
## that rises a little with the combo.

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
## The brick click rises with the combo, one octave at most.
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
		player.bus = "Space"
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
	# Space: the chamber every sound sits in. A large metal room, dark
	# and short. The samples themselves are dry.
	_sfx_bus = AudioServer.bus_count
	AudioServer.add_bus(_sfx_bus)
	AudioServer.set_bus_name(_sfx_bus, "Space")
	AudioServer.set_bus_send(_sfx_bus, "Master")
	var reverb := AudioEffectReverb.new()
	reverb.room_size = 0.62
	reverb.damping = 0.28
	reverb.spread = 0.8
	reverb.predelay_msec = 12.0
	reverb.predelay_feedback = 0.2
	# 0.15 wet. More than that and the chamber turns into a bathroom.
	reverb.wet = 0.15
	reverb.dry = 1.0
	AudioServer.add_bus_effect(_sfx_bus, reverb)

	# The drone: same room, but behind a filter so it sits under everything.
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
	var sound := true
	var music := true
	if s:
		sound = bool(s.sound)
		music = bool(s.music)
	AudioServer.set_bus_mute(_sfx_bus, not sound)
	AudioServer.set_bus_mute(_drone_bus, not music)
	AudioServer.set_bus_volume_db(_sfx_bus, 0.0)
	AudioServer.set_bus_volume_db(_drone_bus, -4.0)


## Spiller en lyd. pitch er en faktor, ikke halvtoner.
func play(id: String, pitch := 1.0, volume_db := 0.0) -> void:
	if not _streams.has(id):
		return
	var player := _pick_voice()
	player.stream = _streams[id]
	player.pitch_scale = clampf(pitch, 0.2, 4.0)
	player.volume_db = volume_db
	player.play()


## One semitone per combo step, capped at an octave. Kept separate from
## playback so the cap can be checked without listening to it.
static func combo_pitch(combo: int) -> float:
	var semitones := minf(float(maxi(combo - 1, 0)), MAX_COMBO_SEMITONES)
	return pow(2.0, semitones / 12.0)


## The brick click rises in pitch with the combo and resets when the ball
## touches the paddle. It is the cheapest way to make a long run up
## behind the wall into something you can hear.
func play_brick(combo: int, id := "brick", volume_db := 0.0) -> void:
	play(id, combo_pitch(combo), volume_db)


func _pick_voice() -> AudioStreamPlayer:
	for i in VOICES:
		var index := (_next_voice + i) % VOICES
		if not _voices[index].playing:
			_next_voice = (index + 1) % VOICES
			return _voices[index]
	var fallback := _voices[_next_voice]
	_next_voice = (_next_voice + 1) % VOICES
	return fallback


## Stops everything at once. Used at shutdown and by the tests, so the
## engine never closes on top of a sound that is still running.
func stop_all() -> void:
	for voice in _voices:
		voice.stop()
		# Dropping the stream releases the playback the audio server is
		# still holding. Stopping alone does not.
		voice.stream = null
	if _drone:
		_drone.stop()
		_drone.stream = null
	_drone_level = 0.0
	_drone_target = 0.0


func start_drone() -> void:
	if not _drone.playing:
		_drone.play()
	_drone_target = 1.0


func stop_drone() -> void:
	_drone_target = 0.0


## The drone rises a little with the combo. A little, no more.
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
