class_name TouchInput
extends Node

## Touch, and only touch. The mouse keeps its own path so the desktop
## build and the feel lab behave exactly as they always did.
##
## The paddle moves by the finger's horizontal DELTA, never to the
## finger's absolute position. That is the whole idea: you put your thumb
## wherever it is comfortable, low and to the side, and steer without
## your hand sitting on top of the thing you are trying to watch.
##
## A tap and a drag are told apart by time and distance, not by order.
## A drag never launches the ball, however short it is, because a launch
## that fires when you meant to steer is the worst thing this control
## scheme could do.

signal steered(delta_x: float)
signal tapped()

## A touch shorter than this and stiller than that is a tap.
const TAP_MAX_MS := 150.0
const TAP_MAX_DISTANCE := 8.0

## 1 px of finger is 1 px of paddle. Tuned on device.
const SENSITIVITY := 1.0

## Fast flicks travel a little further so the paddle can cross the field
## in one throw. Slow, precise drags stay exactly 1:1, because that is
## where you are lining up an angle and a lie would cost you the ball.
const ACCEL_MAX := 1.2
const ACCEL_FROM := 900.0
const ACCEL_TO := 2600.0

## Off while a screen is up, so a tap on a button does not also steer.
var enabled := true
## Presses that begin inside the panel are not steering and are not a
## launch. The panel holds the pause control, and a thumb that reaches
## for it must not fire the ball on the way.
var dead_zone_top := 0.0
## True once the device has produced a real touch. The paddle stops
## following the mouse from that moment.
var seen_touch := false

var _steer_finger := -1
var _fingers: Dictionary = {}


## How much further a flick carries than the finger moved. 1.0 up to
## ACCEL_FROM, then a straight ramp to ACCEL_MAX at ACCEL_TO.
static func acceleration(finger_speed: float) -> float:
	var speed := absf(finger_speed)
	if speed <= ACCEL_FROM:
		return 1.0
	if speed >= ACCEL_TO:
		return ACCEL_MAX
	return lerpf(1.0, ACCEL_MAX, (speed - ACCEL_FROM) / (ACCEL_TO - ACCEL_FROM))


## Both conditions, not either: 149 ms over 9 px is a drag, and so is
## 151 ms over 7 px.
static func is_tap(duration_ms: float, travelled: float) -> bool:
	return duration_ms < TAP_MAX_MS and travelled < TAP_MAX_DISTANCE


func _input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		seen_touch = true
		if event.pressed:
			_press(event.index, event.position)
		else:
			_release(event.index)
	elif event is InputEventScreenDrag:
		seen_touch = true
		_drag(event.index, event.relative, event.velocity)


func _press(index: int, at: Vector2) -> void:
	if at.y < dead_zone_top:
		return
	_fingers[index] = {
		"start": at,
		"started_ms": float(Time.get_ticks_msec()),
		"travelled": 0.0,
	}
	# The first finger down steers. Later fingers are along for the ride,
	# but they can still tap.
	if _steer_finger < 0:
		_steer_finger = index


func _drag(index: int, relative: Vector2, velocity: Vector2) -> void:
	if not _fingers.has(index):
		# A drag without a press: the touch began before we were
		# listening. Adopt it rather than dropping the input.
		_press(index, Vector2.ZERO)
	var finger: Dictionary = _fingers[index]
	finger["travelled"] = float(finger["travelled"]) + relative.length()
	if not enabled or index != _steer_finger:
		return
	steered.emit(relative.x * SENSITIVITY * acceleration(velocity.x))


func _release(index: int) -> void:
	if not _fingers.has(index):
		return
	var finger: Dictionary = _fingers[index]
	var duration := float(Time.get_ticks_msec()) - float(finger["started_ms"])
	var travelled := float(finger["travelled"])
	_fingers.erase(index)
	if index == _steer_finger:
		# Hand steering to whichever finger is still down, so lifting the
		# thumb mid-drag does not freeze the paddle.
		_steer_finger = -1
		for other in _fingers:
			_steer_finger = int(other)
			break
	if enabled and is_tap(duration, travelled):
		tapped.emit()


## Forgets every finger. Used when a screen opens mid-drag, so the touch
## that dismissed it cannot also steer or launch.
func reset() -> void:
	_fingers.clear()
	_steer_finger = -1
