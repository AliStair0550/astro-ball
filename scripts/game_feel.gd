class_name GameFeel
extends Node

## The reusable game feel toolbox.
##
## Screen shake is 2 px over 60 ms on a wall hit. Hitstop is 16 ms on a
## brick and 60 ms on a blast: long enough to feel, short enough that
## nobody notices it as a pause.
##
## Squash is a small helper the paddle uses now and bricks and capsules
## can reuse later.

## Haptics, section 17. Short and specific: you should feel the
## difference between a brick and an explosion without looking.
const HAPTIC_BRICK := 10
const HAPTIC_HARDENED := 6
const HAPTIC_PADDLE := 8
const HAPTIC_BLAST := 30
const HAPTIC_BALL_LOST := 50
const HAPTIC_POWERUP := 15
## One tick per star as it lands, a double knock when the level falls,
## and one long buzz when the run ends.
const HAPTIC_STAR := 12
const HAPTIC_LEVEL_CLEAR := 26
const HAPTIC_SIGNAL_LOST := 140

## The camera the shake offsets. Wired from the scene.
@export var camera_path: NodePath

var _camera: Camera2D

var _shake_amplitude := 0.0
var _shake_duration := 0.0
var _shake_left := 0.0

var _hitstop_left := 0.0


func _ready() -> void:
	_camera = get_node_or_null(camera_path) as Camera2D
	# Run after everything else, so the offset is fresh in the same frame.
	process_priority = 100


## A short pulse, if the player wants them and the device has a motor.
## The wall gets none on purpose: it is the most frequent contact in the
## game and buzzing on every one of them turns into noise.
## Returns whether it actually fired, so the flag can be tested without
## a phone in your hand.
func pulse(milliseconds: int) -> bool:
	if milliseconds <= 0:
		return false
	var settings := get_node_or_null("/root/GameSettings")
	if settings != null and not bool(settings.haptics):
		return false
	Input.vibrate_handheld(milliseconds)
	return true


## A rhythm rather than a single knock. The gaps are in milliseconds and
## the whole thing respects the Haptics setting, because the first pulse
## is the one that asks.
func pulse_pattern(pattern: Array) -> void:
	var when := 0.0
	for i in pattern.size():
		var step: Array = pattern[i]
		var ms := int(step[0])
		var gap := float(step[1]) / 1000.0
		if when <= 0.0:
			pulse(ms)
		else:
			var timer := get_tree().create_timer(when, false)
			timer.timeout.connect(pulse.bind(ms), CONNECT_ONE_SHOT)
		when += gap


## True while the game is frozen. The ball and paddle skip their update
## while it is.
func is_frozen() -> bool:
	return _hitstop_left > 0.0


## Freeze the game for N seconds.
func hitstop(seconds: float) -> void:
	if seconds <= 0.0:
		return
	_hitstop_left = maxf(_hitstop_left, seconds)


## Shake the camera. Amplitude in px, duration in seconds.
## A stronger shake overrides a weaker one. A weaker one does not extend it.
func shake(amplitude: float, seconds: float) -> void:
	if amplitude <= 0.0 or seconds <= 0.0:
		return
	if amplitude >= _shake_amplitude * (_shake_left / maxf(_shake_duration, 0.0001)):
		_shake_amplitude = amplitude
		_shake_duration = seconds
		_shake_left = seconds


func _process(delta: float) -> void:
	if _hitstop_left > 0.0:
		_hitstop_left = maxf(0.0, _hitstop_left - delta)

	if _camera == null:
		return

	if _shake_left > 0.0:
		_shake_left = maxf(0.0, _shake_left - delta)
		var falloff := _shake_left / maxf(_shake_duration, 0.0001)
		var a := _shake_amplitude * falloff
		_camera.offset = Vector2(randf_range(-a, a), randf_range(-a, a))
		if _shake_left <= 0.0:
			_shake_amplitude = 0.0
			_camera.offset = Vector2.ZERO
	elif _camera.offset != Vector2.ZERO:
		_camera.offset = Vector2.ZERO


## Squash and stretch as a small state machine.
##
## Call trigger() on contact and multiply the height by update(delta)
## in _process. Returns 1.0 at rest.
class Squash extends RefCounted:
	## How far it compresses. 0.9 is 90 per cent height.
	var squash_to := 0.9
	## Time going in.
	var squash_time := 0.08
	## Time back to rest, overshoot included.
	var release_time := 0.16
	## How far it overshoots 1.0 on the way back.
	var overshoot := 1.06

	var _t := -1.0

	func trigger() -> void:
		_t = 0.0

	func is_active() -> bool:
		return _t >= 0.0

	func update(delta: float) -> float:
		if _t < 0.0:
			return 1.0
		_t += delta
		if _t < squash_time:
			# Fast in.
			return lerpf(1.0, squash_to, ease(_t / squash_time, 0.35))
		var r := (_t - squash_time) / release_time
		if r >= 1.0:
			_t = -1.0
			return 1.0
		# Back out with a small overshoot halfway.
		return lerpf(squash_to, 1.0, r) + sin(r * PI) * (overshoot - 1.0)
