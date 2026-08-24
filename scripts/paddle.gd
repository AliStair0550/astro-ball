class_name Paddle
extends Node2D

## Lag 4: deflektorskjoldet.
##
## Standard 88 x 10 px med tre synlige segmenter: to endestykker i Bone og
## et midterstykke med et 8 px Volt-felt. Volt-feltet er sweet spot.
## Bred bliver til fem segmenter med to sweet spots, Smal til ét segment
## uden sweet spot. Bredden er ikke bare et tal, den er en anden paddle.
##
## Styring i fase 1 og 2 er musens x. Touch kommer i fase 4.

signal laser_fired(from: Vector2)

const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const EMBER := Color("FF4D2E")
const MID := Color("9C9A90")
const SEAM := Color("232330")

const HEIGHT := 10.0
const CAP_WIDTH := 24.0
const SWEET_WIDTH := 8.0
const SWEET_HALF := 4.0

const WIDTH_NORMAL := 88.0
const WIDTH_WIDE := 132.0
const WIDTH_NARROW := 56.0

const END_LIGHT_TIME := 0.1
const TRAIL_SPEED := 180.0

const LASER_SPEED := 760.0
const LASER_COOLDOWN := 0.22

## Ydre grænser fra arenaen. min_x og max_x udledes af bredden.
var bounds_min := 0.0
var bounds_max := 390.0
var min_x := 0.0
var max_x := 390.0

var width := WIDTH_NORMAL
var laser := false
## Bremses af Tung i senere levels. 1.0 = følger musen præcist.
var follow_speed := 1.0

var _squash := GameFeel.Squash.new()
var _scale_y := 1.0
var _left_light := 0.0
var _right_light := 0.0
var _catch_flash := 0.0
var _catch_color := VOLT
var _prev_positions: Array[float] = []
var _velocity_x := 0.0
var _laser_cooldown := 0.0
var _bolts: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	_prev_positions = [position.x, position.x]
	_apply_bounds()


func set_bounds(low: float, high: float) -> void:
	bounds_min = low
	bounds_max = high
	_apply_bounds()


func set_width(new_width: float) -> void:
	width = new_width
	_apply_bounds()


func _apply_bounds() -> void:
	min_x = bounds_min + half_width()
	max_x = bounds_max - half_width()
	position.x = clampf(position.x, min_x, max_x)


func half_width() -> float:
	return width * 0.5


func top_y() -> float:
	return position.y - HEIGHT * 0.5


func ball_anchor(ball_radius: float) -> Vector2:
	return Vector2(position.x, top_y() - ball_radius - 1.0)


func world_rect() -> Rect2:
	return Rect2(position.x - half_width(), top_y(), width, HEIGHT)


## Antal synlige segmenter: 1 ved Smal, 3 ved Normal, 5 ved Bred.
func segment_count() -> int:
	if width <= WIDTH_NARROW + 0.01:
		return 1
	if width >= WIDTH_WIDE - 0.01:
		return 5
	return 3


## Sweet spot-centre i lokale koordinater. Smal har ingen.
func sweet_offsets() -> Array[float]:
	match segment_count():
		1:
			return []
		5:
			var mid_span := (width - CAP_WIDTH * 2.0) / 3.0
			return [-mid_span, mid_span]
		_:
			return [0.0]


func is_sweet(dx: float) -> bool:
	for offset in sweet_offsets():
		if absf(dx - offset) <= SWEET_HALF:
			return true
	return false


func has_sweet_spot() -> bool:
	return not sweet_offsets().is_empty()


# --- Styring -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	var target := clampf(get_global_mouse_position().x, min_x, max_x)
	if follow_speed < 1.0:
		target = lerpf(position.x, target, clampf(follow_speed * delta * 18.0, 0.0, 1.0))
	_velocity_x = (target - position.x) / maxf(delta, 0.0001)
	_prev_positions.push_front(position.x)
	if _prev_positions.size() > 2:
		_prev_positions.resize(2)
	position.x = target


func _unhandled_input(event: InputEvent) -> void:
	if not laser:
		return
	var tap := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	if tap:
		fire_laser()


func fire_laser() -> void:
	if not laser or _laser_cooldown > 0.0:
		return
	_laser_cooldown = LASER_COOLDOWN
	var hw := half_width()
	for side: float in [-1.0, 1.0]:
		var muzzle := Vector2(position.x + side * (hw - CAP_WIDTH * 0.5), top_y())
		_bolts.append({"pos": muzzle, "alive": true})
		laser_fired.emit(muzzle)


## Aktive laserstråler i verdenskoordinater. Spillet tester dem mod gridet.
func laser_bolts() -> Array[Dictionary]:
	return _bolts


func clear_bolts() -> void:
	_bolts.clear()


# --- Reaktioner --------------------------------------------------------

func on_ball_hit(hit_x: float) -> void:
	_squash.trigger()
	var offset := hit_x - position.x
	if offset <= -(half_width() - CAP_WIDTH):
		_left_light = 1.0
	elif offset >= half_width() - CAP_WIDTH:
		_right_light = 1.0


## Kapslen imploderer til paddlen, og paddlen blinker i kapslens farve.
func on_powerup_caught(color: Color) -> void:
	_catch_flash = 1.0
	_catch_color = color
	_squash.trigger()


func _process(delta: float) -> void:
	_time += delta
	_scale_y = _squash.update(delta)
	if _left_light > 0.0:
		_left_light = maxf(0.0, _left_light - delta / END_LIGHT_TIME)
	if _right_light > 0.0:
		_right_light = maxf(0.0, _right_light - delta / END_LIGHT_TIME)
	if _catch_flash > 0.0:
		_catch_flash = maxf(0.0, _catch_flash - delta * 4.0)
	if _laser_cooldown > 0.0:
		_laser_cooldown = maxf(0.0, _laser_cooldown - delta)

	var i := _bolts.size() - 1
	while i >= 0:
		_bolts[i]["pos"] = _bolts[i]["pos"] - Vector2(0.0, LASER_SPEED * delta)
		if not _bolts[i]["alive"] or _bolts[i]["pos"].y < 0.0:
			_bolts.remove_at(i)
		i -= 1

	queue_redraw()


# --- Tegning -----------------------------------------------------------

func _draw() -> void:
	_draw_bolts()
	_draw_motion_trail()

	var h := HEIGHT * _scale_y
	# Bunden står fast, så skjoldet presses ned mod sin egen linje.
	var top := HEIGHT * 0.5 - h
	var hw := half_width()
	var segments := segment_count()

	if segments == 1:
		# Smal: ét segment, ingen sweet spot.
		draw_rect(Rect2(-hw, top, width, h), BONE)
	else:
		draw_rect(Rect2(-hw + CAP_WIDTH, top, width - CAP_WIDTH * 2.0, h), MID)
		var left := BONE.lerp(Color.WHITE, _left_light)
		var right := BONE.lerp(Color.WHITE, _right_light)
		draw_rect(Rect2(-hw, top, CAP_WIDTH, h), left)
		draw_rect(Rect2(hw - CAP_WIDTH, top, CAP_WIDTH, h), right)
		# Samlinger, så segmenterne kan læses.
		for seam_x in _seam_positions():
			draw_rect(Rect2(seam_x - 0.5, top, 1.0, h), SEAM)
		for offset in sweet_offsets():
			draw_rect(Rect2(offset - SWEET_WIDTH * 0.5, top, SWEET_WIDTH, h), VOLT)

	if laser:
		_draw_laser_tubes(top, h, hw)

	if _left_light > 0.0:
		var gl := Color.WHITE
		gl.a = _left_light * 0.35
		draw_rect(Rect2(-hw - 2.0, top - 2.0, CAP_WIDTH + 4.0, h + 4.0), gl)
	if _right_light > 0.0:
		var gr := Color.WHITE
		gr.a = _right_light * 0.35
		draw_rect(Rect2(hw - CAP_WIDTH - 2.0, top - 2.0, CAP_WIDTH + 4.0, h + 4.0), gr)

	if _catch_flash > 0.0:
		var c := _catch_color
		c.a = _catch_flash * 0.75
		draw_rect(Rect2(-hw - 2.0, top - 2.0, width + 4.0, h + 4.0), c)


func _seam_positions() -> Array[float]:
	var hw := half_width()
	var seams: Array[float] = [-hw + CAP_WIDTH, hw - CAP_WIDTH]
	if segment_count() == 5:
		var span := (width - CAP_WIDTH * 2.0) / 3.0
		seams.append(-hw + CAP_WIDTH + span)
		seams.append(hw - CAP_WIDTH - span)
	return seams


func _draw_laser_tubes(top: float, h: float, hw: float) -> void:
	# To Ember-rør på endestykkerne.
	var ready_glow := 1.0 - clampf(_laser_cooldown / LASER_COOLDOWN, 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var x := side * (hw - CAP_WIDTH * 0.5) - 1.5
		draw_rect(Rect2(x, top - 3.0, 3.0, h + 3.0), EMBER)
		var tip := EMBER.lightened(0.5)
		tip.a = 0.4 + 0.6 * ready_glow
		draw_rect(Rect2(x, top - 3.0, 3.0, 2.0), tip)


func _draw_bolts() -> void:
	for bolt in _bolts:
		var p := to_local(bolt["pos"])
		var c := EMBER.lightened(0.3)
		draw_rect(Rect2(p.x - 1.0, p.y, 2.0, 10.0), c)
		c.a = 0.35
		draw_rect(Rect2(p.x - 2.0, p.y - 2.0, 4.0, 14.0), c)


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
		draw_rect(Rect2(-hw + dx, -HEIGHT * 0.5, width, HEIGHT), c)
