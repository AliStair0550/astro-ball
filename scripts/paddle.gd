class_name Paddle
extends Node2D

## Layer 4: the deflector shield.
##
## 88 x 10 px with three visible segments: two Bone end caps and a middle
## piece holding an 8 px Volt field. That field is the sweet spot.
## Wide becomes five segments with two sweet spots, Narrow one segment
## with none. The width is not a number, it is a different paddle.
##
## Control is the mouse x for now. Touch arrives in phase 4.

signal laser_fired(from: Vector2)

const BONE := Color("F2EFE6")
## The end caps sit a shade below Bone so the bevel has something to
## light up from. A pure white piece of metal has no shape.
const CAP := Color("C4C1B7")
const VOLT := Color("D6FF3D")
const EMBER := Color("FF4D2E")
## The middle is cold metal against Bone caps. That contrast is what
## makes the shield a piece of hardware and not a line.
const MID := Color("575C6B")
const SEAM := Color("15151E")
const ICE := Color("4DD8FF")

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

## Outer bounds from the arena. min_x and max_x follow the width.
var bounds_min := 0.0
var bounds_max := 390.0
var min_x := 0.0
var max_x := 390.0

var width := WIDTH_NORMAL
var laser := false
## Off while a screen is up.
var input_enabled := true
## The mouse steers by absolute position. Touch steers by delta, and the
## moment a real touch arrives the mouse stops driving, so a trackpad on
## a hybrid device cannot fight the thumb.
var follow_mouse := true
## Slowed by Heavy in later levels. 1.0 tracks the mouse exactly.
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


## Relative steering. The paddle moves BY the delta, never TO a position.
func nudge(delta_x: float) -> void:
	if not input_enabled:
		return
	position.x = clampf(position.x + delta_x, min_x, max_x)


func half_width() -> float:
	return width * 0.5


func top_y() -> float:
	return position.y - HEIGHT * 0.5


func ball_anchor(ball_radius: float) -> Vector2:
	return Vector2(position.x, top_y() - ball_radius - 1.0)


func world_rect() -> Rect2:
	return Rect2(position.x - half_width(), top_y(), width, HEIGHT)


## Visible segments: 1 when Narrow, 3 when normal, 5 when Wide.
func segment_count() -> int:
	if width <= WIDTH_NARROW + 0.01:
		return 1
	if width >= WIDTH_WIDE - 0.01:
		return 5
	return 3


## Sweet spot centres in local coordinates. Narrow has none.
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


# --- Control -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	if not follow_mouse:
		# Touch has the wheel. nudge() moves us; all that is left here is
		# to keep the velocity readings the motion trail depends on.
		_velocity_x = (position.x - _prev_positions[0]) / maxf(delta, 0.0001)
		_prev_positions.push_front(position.x)
		if _prev_positions.size() > 2:
			_prev_positions.resize(2)
		return
	var target := clampf(get_global_mouse_position().x, min_x, max_x)
	if follow_speed < 1.0:
		target = lerpf(position.x, target, clampf(follow_speed * delta * 18.0, 0.0, 1.0))
	_velocity_x = (target - position.x) / maxf(delta, 0.0001)
	_prev_positions.push_front(position.x)
	if _prev_positions.size() > 2:
		_prev_positions.resize(2)
	position.x = target


## Mouse only. Touch goes through TouchInput, which knows the difference
## between a tap and a drag; a raw touch event does not.
func _unhandled_input(event: InputEvent) -> void:
	if not laser or not input_enabled:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
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


## Live laser bolts in world coordinates. The game tests them against the grid.
func laser_bolts() -> Array[Dictionary]:
	return _bolts


func clear_bolts() -> void:
	_bolts.clear()


# --- Reactions ---------------------------------------------------------

func on_ball_hit(hit_x: float) -> void:
	_squash.trigger()
	var offset := hit_x - position.x
	if offset <= -(half_width() - CAP_WIDTH):
		_left_light = 1.0
	elif offset >= half_width() - CAP_WIDTH:
		_right_light = 1.0


## The capsule implodes into the paddle, which blinks in its colour.
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


# --- Drawing -----------------------------------------------------------

func _draw() -> void:
	_draw_bolts()
	_draw_motion_trail()

	var h := HEIGHT * _scale_y
	# The bottom stays put, so the shield presses down onto its own line.
	var top := HEIGHT * 0.5 - h
	var hw := half_width()

	_draw_projection(top, h, hw)
	_draw_body(top, h, hw)

	if laser:
		_draw_laser_tubes(top, h, hw)

	_draw_end_glow(top, h, hw)

	if _catch_flash > 0.0:
		var c := _catch_color
		c.a = _catch_flash * 0.7
		draw_rect(Rect2(-hw - 2.0, top - 3.0, width + 4.0, h + 5.0), c)


func _cap_color(light: float) -> Color:
	return CAP.lerp(Color.WHITE, light)


## The shield is projected. The field above the edge is what the ball
## strikes, and the faint shadow below is what holds it up.
func _draw_projection(top: float, h: float, hw: float) -> void:
	var field := VOLT
	for i in 3:
		field.a = 0.13 - float(i) * 0.04
		draw_rect(Rect2(-hw + float(i), top - 3.0 + float(i), width - float(i) * 2.0, 3.0 - float(i) * 0.5), field)
	var shadow := Color("07070C")
	shadow.a = 0.5
	draw_rect(Rect2(-hw + 2.0, top + h, width - 4.0, 2.0), shadow)


## The shield in spans: caps, middles and sweet spots. They share one
## shading curve, so the whole thing reads as a single round piece of
## metal and not five flat blocks in a row.
func _spans() -> Array[Dictionary]:
	var hw := half_width()
	var half_sweet := SWEET_WIDTH * 0.5
	var out: Array[Dictionary] = []
	match segment_count():
		1:
			out.append({"x0": -hw, "x1": hw, "color": _cap_color(maxf(_left_light, _right_light)), "sweet": false})
		5:
			var span := (width - CAP_WIDTH * 2.0) / 3.0
			var a := -hw + CAP_WIDTH
			var b := hw - CAP_WIDTH
			out.append({"x0": -hw, "x1": a, "color": _cap_color(_left_light), "sweet": false})
			out.append({"x0": a, "x1": -span - half_sweet, "color": MID, "sweet": false})
			out.append({"x0": -span - half_sweet, "x1": -span + half_sweet, "color": VOLT, "sweet": true})
			out.append({"x0": -span + half_sweet, "x1": span - half_sweet, "color": MID, "sweet": false})
			out.append({"x0": span - half_sweet, "x1": span + half_sweet, "color": VOLT, "sweet": true})
			out.append({"x0": span + half_sweet, "x1": b, "color": MID, "sweet": false})
			out.append({"x0": b, "x1": hw, "color": _cap_color(_right_light), "sweet": false})
		_:
			out.append({"x0": -hw, "x1": -hw + CAP_WIDTH, "color": _cap_color(_left_light), "sweet": false})
			out.append({"x0": -hw + CAP_WIDTH, "x1": -half_sweet, "color": MID, "sweet": false})
			out.append({"x0": -half_sweet, "x1": half_sweet, "color": VOLT, "sweet": true})
			out.append({"x0": half_sweet, "x1": hw - CAP_WIDTH, "color": MID, "sweet": false})
			out.append({"x0": hw - CAP_WIDTH, "x1": hw, "color": _cap_color(_right_light), "sweet": false})
	return out


## Corners are rounded by pulling the top and bottom rows inward.
static func _row_inset(row: int, rows: int) -> float:
	if row == 0 or row == rows - 1:
		return 3.0
	if row == 1 or row == rows - 2:
		return 1.0
	return 0.0


## The cylinder's light: brightest just above centre, darkest at the
## bottom. That curve is what turns a flat strip into a tube.
static func _shade_at(t: float) -> float:
	return cos((t - 0.30) * PI * 1.08)


func _draw_body(top: float, h: float, hw: float) -> void:
	var rows := maxi(int(round(h)), 5)
	var row_h := h / float(rows)
	var spans := _spans()

	# Glow around the sweet spots, under the body so it does not wash it out.
	for span in spans:
		if not span["sweet"]:
			continue
		# The glow hugs the field instead of sitting behind it as a box.
		var glow := VOLT
		for i in 3:
			glow.a = 0.16 - float(i) * 0.05
			var pad := 1.5 + float(i) * 1.8
			draw_rect(Rect2(float(span["x0"]) - pad, top - pad * 0.35,
				float(span["x1"]) - float(span["x0"]) + pad * 2.0, h + pad * 0.7), glow)

	# A dark outline all the way round the silhouette.
	var outline := Color("0A0A12")
	for r in rows:
		var inset := _row_inset(r, rows)
		draw_rect(Rect2(-hw - 1.0 + inset, top + float(r) * row_h, width + 2.0 - inset * 2.0, row_h + 0.5), outline)

	# The body, row by row.
	for r in rows:
		var t := (float(r) + 0.5) / float(rows)
		var shade := _shade_at(t)
		var inset := _row_inset(r, rows)
		var y := top + float(r) * row_h
		for i in spans.size():
			var span := spans[i]
			var x0: float = float(span["x0"]) + (inset if i == 0 else 0.0)
			var x1: float = float(span["x1"]) - (inset if i == spans.size() - 1 else 0.0)
			if x1 <= x0:
				continue
			var base: Color = span["color"]
			var c := base.lightened(shade * 0.6) if shade > 0.0 else base.darkened(-shade * 0.62)
			draw_rect(Rect2(x0, y, x1 - x0, row_h + 0.5), c)

	# The specular. DX-Ball's paddle reads as chrome because the highlight
	# is a hard bright line, not a soft wash: one bright row with a
	# dimmer one under it, and nothing above.
	var spec_row := maxi(int(float(rows) * 0.16), 1)
	var spec := Color.WHITE
	spec.a = 0.46
	draw_rect(Rect2(-hw + 3.0, top + float(spec_row) * row_h, width - 6.0, maxf(row_h, 1.0)), spec)
	spec.a = 0.18
	draw_rect(Rect2(-hw + 3.0, top + float(spec_row + 1) * row_h, width - 6.0, maxf(row_h, 1.0)), spec)
	# And a dark line right at the bottom, which is what makes the tube
	# look like it turns away from you rather than stopping flat.
	var underside := Color("07070C")
	underside.a = 0.5
	draw_rect(Rect2(-hw + 3.0, top + h - 1.0, width - 6.0, 1.0), underside)

	# Seams between the segments.
	for seam_x in _seam_positions():
		var seam := SEAM
		seam.a = 0.9
		draw_rect(Rect2(seam_x - 1.0, top + 1.0, 1.0, h - 2.0), seam)
		var chrome := Color.WHITE
		chrome.a = 0.20
		draw_rect(Rect2(seam_x, top + 1.0, 1.0, h - 2.0), chrome)

	# A travelling light in the sweet spot, so the field looks charged.
	for span in spans:
		if not span["sweet"]:
			continue
		var x0: float = float(span["x0"])
		var w: float = float(span["x1"]) - x0
		var travel := fposmod(_time * 26.0, w + 6.0) - 3.0
		var sparkle := Color.WHITE
		sparkle.a = 0.6
		draw_rect(Rect2(clampf(x0 + travel, x0, x0 + w - 1.0), top + 1.0, 1.0, maxf(h - 2.0, 1.0)), sparkle)


## The end caps light up for 100 ms when the ball strikes them.
func _draw_end_glow(top: float, h: float, hw: float) -> void:
	if _left_light > 0.0:
		var gl := Color.WHITE
		gl.a = _left_light * 0.30
		draw_rect(Rect2(-hw - 3.0, top - 3.0, CAP_WIDTH + 6.0, h + 6.0), gl)
	if _right_light > 0.0:
		var gr := Color.WHITE
		gr.a = _right_light * 0.30
		draw_rect(Rect2(hw - CAP_WIDTH - 3.0, top - 3.0, CAP_WIDTH + 6.0, h + 6.0), gr)


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


func _seam_positions() -> Array[float]:
	var hw := half_width()
	if segment_count() == 1:
		return []
	var seams: Array[float] = [-hw + CAP_WIDTH, hw - CAP_WIDTH]
	if segment_count() == 5:
		var span := (width - CAP_WIDTH * 2.0) / 3.0
		seams.append(-hw + CAP_WIDTH + span)
		seams.append(hw - CAP_WIDTH - span)
	return seams


func _draw_laser_tubes(top: float, h: float, hw: float) -> void:
	# Two Ember tubes on the caps. The muzzle glows when they are charged.
	var ready_glow := 1.0 - clampf(_laser_cooldown / LASER_COOLDOWN, 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var x := side * (hw - CAP_WIDTH * 0.5) - 2.0
		draw_rect(Rect2(x, top - 5.0, 4.0, h + 4.0), EMBER.darkened(0.45))
		draw_rect(Rect2(x, top - 5.0, 1.0, h + 4.0), EMBER.lightened(0.3))
		draw_rect(Rect2(x + 1.0, top - 5.0, 2.0, h + 4.0), EMBER)
		var tip := EMBER.lightened(0.55)
		tip.a = 0.35 + 0.65 * ready_glow
		draw_rect(Rect2(x, top - 5.0, 4.0, 2.0), tip)
		var halo := EMBER
		halo.a = 0.22 * ready_glow
		draw_rect(Rect2(x - 3.0, top - 8.0, 10.0, 8.0), halo)


func _draw_bolts() -> void:
	for bolt in _bolts:
		var p := to_local(bolt["pos"])
		var core := EMBER.lightened(0.45)
		draw_rect(Rect2(p.x - 1.0, p.y, 2.0, 11.0), core)
		var glow := EMBER
		glow.a = 0.35
		draw_rect(Rect2(p.x - 2.5, p.y - 2.0, 5.0, 15.0), glow)
		glow.a = 0.14
		draw_rect(Rect2(p.x - 4.0, p.y - 4.0, 8.0, 19.0), glow)
