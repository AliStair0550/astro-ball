class_name Paddle
extends Node2D

## Lag 4: deflektorskjoldet.
##
## 88 x 10 px. Tre synlige segmenter: to endestykker i Bone og et
## midterstykke med et 8 px Volt-felt. Volt-feltet er sweet spot.
## Styring i fase 1 er musens x. Touch kommer i fase 4.

const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const MID := Color("9C9A90")
const SEAM := Color("232330")

const WIDTH := 88.0
const HEIGHT := 10.0
const CAP_WIDTH := 24.0
## De midterste 8 px. Lige op og 10 % fart.
const SWEET_WIDTH := 8.0

const END_LIGHT_TIME := 0.1
const TRAIL_SPEED := 180.0

var min_x := 0.0
var max_x := 390.0

var _squash := GameFeel.Squash.new()
var _scale_y := 1.0

var _left_light := 0.0
var _right_light := 0.0

var _prev_positions: Array[float] = []
var _velocity_x := 0.0


func _ready() -> void:
	_prev_positions = [position.x, position.x]


func _process(delta: float) -> void:
	_scale_y = _squash.update(delta)
	if _left_light > 0.0:
		_left_light = maxf(0.0, _left_light - delta / END_LIGHT_TIME)
	if _right_light > 0.0:
		_right_light = maxf(0.0, _right_light - delta / END_LIGHT_TIME)
	queue_redraw()


func _physics_process(delta: float) -> void:
	var target := clampf(get_global_mouse_position().x, min_x, max_x)
	_velocity_x = (target - position.x) / maxf(delta, 0.0001)
	_prev_positions.push_front(position.x)
	if _prev_positions.size() > 2:
		_prev_positions.resize(2)
	position.x = target


func half_width() -> float:
	return WIDTH * 0.5


func top_y() -> float:
	return position.y - HEIGHT * 0.5


## Boldens hvileplads, mens den er klæbet fast.
func ball_anchor(ball_radius: float) -> Vector2:
	return Vector2(position.x, top_y() - ball_radius - 1.0)


## Kollisionsrektanglen i verdenskoordinater. Bruges af boldens sweep.
func world_rect() -> Rect2:
	return Rect2(position.x - half_width(), top_y(), WIDTH, HEIGHT)


## Bolden ramte skjoldet. hit_x er kontaktpunktet i verdenskoordinater.
func on_ball_hit(hit_x: float) -> void:
	_squash.trigger()
	var offset := hit_x - position.x
	if offset <= -(half_width() - CAP_WIDTH):
		_left_light = 1.0
	elif offset >= half_width() - CAP_WIDTH:
		_right_light = 1.0


func _draw() -> void:
	_draw_motion_trail()

	var h := HEIGHT * _scale_y
	# Bunden står fast, så skjoldet presses ned mod sin egen linje.
	var top := HEIGHT * 0.5 - h
	var hw := half_width()

	# Midterstykke.
	draw_rect(Rect2(-hw + CAP_WIDTH, top, WIDTH - CAP_WIDTH * 2.0, h), MID)

	# Endestykker.
	var left := BONE
	var right := BONE
	if _left_light > 0.0:
		left = BONE.lerp(Color.WHITE, _left_light)
	if _right_light > 0.0:
		right = BONE.lerp(Color.WHITE, _right_light)
	draw_rect(Rect2(-hw, top, CAP_WIDTH, h), left)
	draw_rect(Rect2(hw - CAP_WIDTH, top, CAP_WIDTH, h), right)

	# Samlinger, så de tre segmenter kan læses.
	draw_rect(Rect2(-hw + CAP_WIDTH, top, 1.0, h), SEAM)
	draw_rect(Rect2(hw - CAP_WIDTH - 1.0, top, 1.0, h), SEAM)

	# Sweet spot.
	draw_rect(Rect2(-SWEET_WIDTH * 0.5, top, SWEET_WIDTH, h), VOLT)

	# Endestykkernes glød lige efter kontakt.
	if _left_light > 0.0:
		var gl := Color.WHITE
		gl.a = _left_light * 0.35
		draw_rect(Rect2(-hw - 2.0, top - 2.0, CAP_WIDTH + 4.0, h + 4.0), gl)
	if _right_light > 0.0:
		var gr := Color.WHITE
		gr.a = _right_light * 0.35
		draw_rect(Rect2(hw - CAP_WIDTH - 2.0, top - 2.0, CAP_WIDTH + 4.0, h + 4.0), gr)


func _draw_motion_trail() -> void:
	if absf(_velocity_x) < TRAIL_SPEED or _prev_positions.size() < 2:
		return
	var hw := half_width()
	for i in _prev_positions.size():
		var dx: float = _prev_positions[i] - position.x
		var c := BONE
		c.a = 0.10 - 0.045 * float(i)
		if c.a <= 0.0:
			continue
		draw_rect(Rect2(-hw + dx, -HEIGHT * 0.5, WIDTH, HEIGHT), c)
