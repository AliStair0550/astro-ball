class_name Ball
extends CharacterBody2D

## Layer 4: the comet.
##
## Its own collision. No RigidBody, no move_and_slide. Every physics tick
## sweeps a circle against the frame's three inner faces, the paddle's
## three outer faces and the bricks the motion actually touches. The
## reflection is manual, which is what keeps the speed constant.
##
## The exit angle off the paddle comes from where it was struck:
##   outer edge 25 degrees from horizontal, middle 80, linear between.
## The middle 8 px are the sweet spot: 88 degrees and 10 per cent speed,
## decaying over 2 seconds. The ball never goes below 20 degrees from
## horizontal, not even after a wall bounce.

signal wall_hit(pos: Vector2, normal: Vector2)
signal paddle_hit(pos: Vector2, exit_angle_deg: float, sweet: bool)
signal brick_hit(brick: Brick, damage: int, pos: Vector2, passed_through: bool)
signal launched()
signal lost(ball: Ball)

enum Look { NORMAL, FIREBALL, GIANT, SLOW, FAST, ZAP }

const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const ICE := Color("4DD8FF")
const EMBER := Color("FF4D2E")
const FLARE := Color("FF9F1C")

## The resting radius. Giant doubles it, so the live value is the
## instance variable below, not this constant.
const BASE_RADIUS := 4.0
const GIANT_SCALE := 2.0
## How many times the depenetration pass will push before giving up.
const FREE_PASSES := 6
const BASE_SPEED := 320.0
## Speed rises 4 per cent per 10 bricks and stops here.
const MAX_SPEED := 520.0
const SPEED_STEP := 1.04
const SPEED_STEP_BRICKS := 10

const MIN_ANGLE_DEG := 20.0
const EDGE_ANGLE_DEG := 25.0
const CENTER_ANGLE_DEG := 80.0
const SWEET_ANGLE_DEG := 88.0
const LAUNCH_ANGLE_DEG := 80.0
const LAUNCH_SPREAD_DEG := 4.0

const SWEET_HALF_WIDTH := 4.0
const SWEET_BONUS := 0.10
const SWEET_BONUS_TIME := 2.0

const TRAIL_LENGTH := 12
const SKIN := 0.01
const MAX_SUBSTEPS := 16

## The live radius. Assigning it never embeds the ball: growth that
## would put the ball inside the frame, the paddle or a brick is held
## until there is room. A frame or two of delay is invisible. A ball
## stuck inside four bricks is not.
var radius := BASE_RADIUS:
	set(value):
		if is_equal_approx(value, radius):
			# Retire any growth that was waiting. Otherwise switching
			# Giant off while it waits leaves the request armed, and the
			# ball grows after the power-up is gone.
			_pending_radius = 0.0
			return
		var previous := radius
		radius = value
		if value > previous and not _free_from_overlaps():
			radius = previous
			_pending_radius = value
		else:
			_pending_radius = 0.0

var _pending_radius := 0.0

var arena: Arena
var paddle: Paddle
var grid: BrickGrid
var game_feel: GameFeel
var effects: Effects

var stuck := true
## Off while a screen is up, so a click on a button does not also
## launch the ball.
var input_enabled := true
## Frozen on field cleared: the ball keeps its direction and speed but
## does not move, so its state is still true when the HUD and the debug
## overlay read it.
var frozen := false
## Rises 4 per cent per 10 bricks, driven by the game.
var speed_base := BASE_SPEED:
	set(value):
		speed_base = value
		_renormalize()
## Slow sets it to 0.7, Fast to 1.4. The speed is corrected at once, so
## the ball never lags a frame behind a power-up.
var speed_scale := 1.0:
	set(value):
		speed_scale = value
		_renormalize()
var fireball := false
## Section 20: 200 per cent ball, breaks Hardened in one hit.
var giant := false:
	set(value):
		giant = value
		radius = BASE_RADIUS * (GIANT_SCALE if value else 1.0)
var zap := false
var last_exit_angle := 0.0

var _bonus_left := 0.0
var _trail: Array[Vector2] = []
## Reused every substep. Building this array inside the sweep loop meant
## up to sixteen allocations per ball per tick, for a shape that never
## changes.
var _paddle_faces: Array = [
	[Vector2.ZERO, Vector2.ZERO, "paddle_top"],
	[Vector2.ZERO, Vector2.ZERO, "paddle_side"],
	[Vector2.ZERO, Vector2.ZERO, "paddle_side"],
]
var _spark_drip := 0.0


func _ready() -> void:
	_fill_trail()


## Corrects the speed without touching the direction.
func _renormalize() -> void:
	if velocity.length() > 0.0001:
		velocity = velocity.normalized() * current_speed()


func current_speed() -> float:
	var bonus := SWEET_BONUS * (_bonus_left / SWEET_BONUS_TIME)
	return speed_base * speed_scale * (1.0 + maxf(bonus, 0.0))


func look() -> Look:
	if fireball:
		return Look.FIREBALL
	if giant:
		return Look.GIANT
	if zap:
		return Look.ZAP
	if speed_scale < 1.0:
		return Look.SLOW
	if speed_scale > 1.0:
		return Look.FAST
	return Look.NORMAL


func stick_to_paddle() -> void:
	stuck = true
	velocity = Vector2.ZERO
	_bonus_left = 0.0
	if paddle:
		global_position = paddle.ball_anchor(radius)
	_fill_trail()


func _fill_trail() -> void:
	_trail.clear()
	for i in TRAIL_LENGTH:
		_trail.append(global_position)


## Mouse only. A touch is a tap or a drag, and only TouchInput can tell
## them apart. A drag must never launch the ball.
func _unhandled_input(event: InputEvent) -> void:
	if not stuck or not input_enabled or frozen:
		return
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		launch()


func launch() -> void:
	if not stuck:
		return
	stuck = false
	var angle := LAUNCH_ANGLE_DEG + randf_range(-LAUNCH_SPREAD_DEG, LAUNCH_SPREAD_DEG)
	var dir_x := 1.0 if randf() < 0.5 else -1.0
	var a := deg_to_rad(angle)
	velocity = Vector2(cos(a) * dir_x, -sin(a)) * current_speed()
	launched.emit()


## Used by Multi: a new ball leaves in a new direction at the same speed.
func launch_at(angle_deg: float) -> void:
	stuck = false
	var a := deg_to_rad(angle_deg)
	velocity = Vector2(cos(a), -sin(a)) * current_speed()
	velocity = _enforce_min_angle(velocity)


func _physics_process(delta: float) -> void:
	if frozen:
		return
	if game_feel and game_feel.is_frozen():
		return

	if _bonus_left > 0.0:
		_bonus_left = maxf(0.0, _bonus_left - delta)

	if stuck:
		if paddle:
			global_position = paddle.ball_anchor(radius)
		_fill_trail()
		queue_redraw()
		return

	if velocity.length() > 0.0001:
		velocity = velocity.normalized() * current_speed()

	# Growth that had no room last tick tries again now, but only while
	# the power-up that asked for it is still on.
	if _pending_radius > 0.0:
		if giant:
			radius = _pending_radius
		else:
			_pending_radius = 0.0

	_advance(delta)
	_resolve_paddle_overlap()

	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)

	if arena and global_position.y - radius > arena.death_y:
		lost.emit(self)
		return

	queue_redraw()


func _advance(delta: float) -> void:
	var remaining := delta
	var guard := 0
	var stalls := 0
	while remaining > 0.00001 and guard < MAX_SUBSTEPS:
		guard += 1
		var motion := velocity * remaining
		var best_t := 1.0
		var best_normal := Vector2.ZERO
		var best_kind := ""
		var best_brick: Brick = null

		if arena:
			for seg in arena.wall_segments():
				var hit := _sweep_circle_segment(global_position, motion, radius, seg["a"], seg["b"])
				if hit["hit"] and hit["t"] < best_t:
					best_t = hit["t"]
					best_normal = hit["normal"]
					best_kind = "wall"
					best_brick = null

		if paddle:
			var r := paddle.world_rect()
			var top_left := r.position
			var top_right := Vector2(r.end.x, r.position.y)
			_paddle_faces[0][0] = top_left
			_paddle_faces[0][1] = top_right
			_paddle_faces[1][0] = top_left
			_paddle_faces[1][1] = Vector2(r.position.x, r.end.y)
			_paddle_faces[2][0] = top_right
			_paddle_faces[2][1] = r.end
			for face in _paddle_faces:
				var hit := _sweep_circle_segment(global_position, motion, radius, face[0], face[1])
				if hit["hit"] and hit["t"] < best_t:
					best_t = hit["t"]
					best_normal = hit["normal"]
					best_kind = face[2]
					best_brick = null

		if grid:
			var swept := Rect2(global_position, Vector2.ZERO)
			swept = swept.expand(global_position + motion).grow(radius + 1.0)
			for brick in grid.bricks_in(swept):
				var hit := _sweep_circle_rect(global_position, motion, radius, brick.rect)
				if hit["hit"] and hit["t"] < best_t:
					best_t = hit["t"]
					best_normal = hit["normal"]
					best_kind = "brick"
					best_brick = brick

		if best_kind == "":
			global_position += motion
			return

		# A contact at t == 0 moves the ball nowhere. Three of those in a
		# row means it is wedged, and burning the remaining substeps
		# reflecting in place leaves the tick with a garbage velocity.
		if best_t <= 0.0:
			stalls += 1
			if stalls >= 3:
				_free_from_overlaps()
				return
		else:
			stalls = 0

		var pass_through := false
		var damage := 1
		if best_kind == "brick":
			if fireball and best_brick.is_breakable():
				pass_through = true
				damage = best_brick.hits_left
			elif best_brick.lets_ball_pass():
				# Glass lets any ball through, giant or not. That is the
				# brick's own rule, not a power-up's.
				pass_through = true
				if giant:
					damage = best_brick.hits_left
			elif giant and best_brick.is_breakable():
				# Section 20: Giant breaks Hardened in one hit, but it
				# does not go through. It is heavy, not a ghost.
				damage = best_brick.hits_left

		global_position += motion * best_t
		if not pass_through:
			global_position += best_normal * SKIN
		remaining *= (1.0 - best_t)

		match best_kind:
			"wall":
				_reflect(best_normal)
				wall_hit.emit(global_position, best_normal)
			"paddle_top":
				if best_normal.y < -0.5:
					_bounce_off_paddle()
				else:
					_reflect(best_normal)
					paddle.on_ball_hit(global_position.x)
			"paddle_side":
				_reflect(best_normal)
				paddle.on_ball_hit(global_position.x)
			"brick":
				if not pass_through:
					_reflect(best_normal)
				brick_hit.emit(best_brick, damage, global_position, pass_through)


func _reflect(normal: Vector2) -> void:
	velocity = velocity - 2.0 * normal * velocity.dot(normal)
	velocity = _enforce_min_angle(velocity)


func _bounce_off_paddle() -> void:
	var half := paddle.half_width()
	var dx := global_position.x - paddle.global_position.x
	var offset := clampf(dx / half, -1.0, 1.0)
	var sweet := paddle.is_sweet(dx)

	var angle_deg := SWEET_ANGLE_DEG if sweet else lerpf(CENTER_ANGLE_DEG, EDGE_ANGLE_DEG, absf(offset))
	var dir_x := signf(offset)
	if dir_x == 0.0:
		dir_x = 1.0 if randf() < 0.5 else -1.0

	if sweet:
		_bonus_left = SWEET_BONUS_TIME

	var a := deg_to_rad(angle_deg)
	velocity = Vector2(cos(a) * dir_x, -sin(a)) * current_speed()
	last_exit_angle = angle_deg

	paddle.on_ball_hit(global_position.x)
	paddle_hit.emit(global_position, angle_deg, sweet)


## Never flatter than 20 degrees. A ball rolling sideways along the
## frame is the one way to make this game boring.
func _enforce_min_angle(v: Vector2) -> Vector2:
	var speed := v.length()
	if speed < 0.0001:
		return v
	var angle := atan2(absf(v.y), absf(v.x))
	var minimum := deg_to_rad(MIN_ANGLE_DEG)
	if angle >= minimum:
		return v
	var sx := signf(v.x)
	if sx == 0.0:
		sx = 1.0
	var sy := signf(v.y)
	if sy == 0.0:
		sy = -1.0
	return Vector2(cos(minimum) * sx, sin(minimum) * sy) * speed


func _resolve_paddle_overlap() -> void:
	if paddle == null or stuck:
		return
	# A real circle against the rectangle. Detecting the overlap is not
	# enough: resolving every one of them upward turns a ball passing
	# beside the paddle into a save, because it gets lifted onto the
	# deck. Only an overlap that is mostly from above is a save. The rest
	# get pushed out the way they came in.
	var rect := paddle.world_rect()
	var push := _rect_push(rect)
	if push == Vector2.ZERO:
		return
	var from_above := push.y < 0.0 and absf(push.y) >= absf(push.x) \
		and global_position.y <= rect.get_center().y
	if not from_above:
		global_position += push
		return
	global_position.y = paddle.top_y() - radius - SKIN
	if velocity.y > 0.0:
		_bounce_off_paddle()


## Pushes the ball out of anything it is currently inside. Returns true
## when it ends up free. Growth calls this, and so does a sweep that has
## stalled, because both leave the ball somewhere it cannot legally be.
func _free_from_overlaps() -> bool:
	for pass_index in FREE_PASSES:
		var push := Vector2.ZERO
		var deepest := 0.0

		if arena:
			for seg in arena.wall_segments():
				var closest := _closest_point_on_segment(global_position, seg["a"], seg["b"])
				var away := global_position - closest
				var distance := away.length()
				if distance < radius:
					var normal: Vector2 = seg["inward"]
					if distance > 0.001 and away.dot(normal) > 0.0:
						normal = away / distance
					var depth := radius - distance
					if depth > deepest:
						deepest = depth
					push += normal * depth

		if paddle:
			var overlap := _rect_push(paddle.world_rect())
			if overlap != Vector2.ZERO:
				deepest = maxf(deepest, overlap.length())
				push += overlap

		if grid:
			var area := Rect2(global_position, Vector2.ZERO).grow(radius + 1.0)
			for brick in grid.bricks_in(area):
				var overlap_brick := _rect_push(brick.rect)
				if overlap_brick != Vector2.ZERO:
					deepest = maxf(deepest, overlap_brick.length())
					push += overlap_brick

		if deepest <= 0.001:
			return true
		if push.length() < 0.0001:
			return false
		global_position += push.normalized() * (deepest + SKIN)
	return not _is_overlapping()


func _is_overlapping() -> bool:
	if arena:
		for seg in arena.wall_segments():
			if global_position.distance_to(_closest_point_on_segment(global_position, seg["a"], seg["b"])) < radius - 0.01:
				return true
	if paddle and _rect_push(paddle.world_rect()) != Vector2.ZERO:
		return true
	if grid:
		for brick in grid.bricks_in(Rect2(global_position, Vector2.ZERO).grow(radius + 1.0)):
			if _rect_push(brick.rect) != Vector2.ZERO:
				return true
	return false


## The vector that would free the ball from one rectangle, or zero if it
## is already clear of it.
func _rect_push(rect: Rect2) -> Vector2:
	var closest := Vector2(
		clampf(global_position.x, rect.position.x, rect.end.x),
		clampf(global_position.y, rect.position.y, rect.end.y))
	var away := global_position - closest
	var distance := away.length()
	if distance >= radius:
		return Vector2.ZERO
	if distance > 0.001:
		return (away / distance) * (radius - distance)
	# Dead centre inside the rect: leave along the shortest way out.
	var left := global_position.x - rect.position.x
	var right := rect.end.x - global_position.x
	var up := global_position.y - rect.position.y
	var down := rect.end.y - global_position.y
	var least := minf(minf(left, right), minf(up, down))
	if least == left:
		return Vector2(-(left + radius), 0.0)
	if least == right:
		return Vector2(right + radius, 0.0)
	if least == up:
		return Vector2(0.0, -(up + radius))
	return Vector2(0.0, down + radius)


static func _closest_point_on_segment(p: Vector2, a: Vector2, b: Vector2) -> Vector2:
	var ab := b - a
	var length_sq := ab.length_squared()
	if length_sq < 0.0001:
		return a
	return a + ab * clampf((p - a).dot(ab) / length_sq, 0.0, 1.0)


# --- Swept circle ------------------------------------------------------

static func _sweep_circle_rect(p0: Vector2, d: Vector2, r: float, rect: Rect2) -> Dictionary:
	var best := {"hit": false, "t": 1.0, "normal": Vector2.ZERO}
	var tl := rect.position
	var tr := Vector2(rect.end.x, rect.position.y)
	var br := rect.end
	var bl := Vector2(rect.position.x, rect.end.y)
	for face in [[tl, tr], [tr, br], [br, bl], [bl, tl]]:
		var hit := _sweep_circle_segment(p0, d, r, face[0], face[1])
		if hit["hit"] and hit["t"] < best["t"]:
			best = hit
	return best


## A circle of radius r moves from p0 along d against the segment a-b.
## Returns {"hit": bool, "t": float, "normal": Vector2}, where t is the
## fraction of d travelled before contact.
static func _sweep_circle_segment(p0: Vector2, d: Vector2, r: float, a: Vector2, b: Vector2) -> Dictionary:
	var seg := b - a
	var seg_len := seg.length()
	if seg_len < 0.0001:
		return _sweep_circle_point(p0, d, r, a)

	var seg_dir := seg / seg_len
	var normal := Vector2(-seg_dir.y, seg_dir.x)
	var dist := (p0 - a).dot(normal)
	if dist < 0.0:
		normal = -normal
		dist = -dist

	var approach := d.dot(normal)
	var t := -1.0
	if dist <= r:
		if approach < 0.0:
			t = 0.0
	elif approach < 0.0:
		t = (dist - r) / -approach

	if t >= 0.0 and t <= 1.0:
		var contact := p0 + d * t - normal * r
		var along := (contact - a).dot(seg_dir)
		if along >= 0.0 and along <= seg_len:
			return {"hit": true, "t": t, "normal": normal}

	var hit_a := _sweep_circle_point(p0, d, r, a)
	var hit_b := _sweep_circle_point(p0, d, r, b)
	if hit_a["hit"] and hit_b["hit"]:
		return hit_a if hit_a["t"] <= hit_b["t"] else hit_b
	if hit_a["hit"]:
		return hit_a
	if hit_b["hit"]:
		return hit_b
	return {"hit": false, "t": 1.0, "normal": Vector2.ZERO}


static func _sweep_circle_point(p0: Vector2, d: Vector2, r: float, c: Vector2) -> Dictionary:
	var miss := {"hit": false, "t": 1.0, "normal": Vector2.ZERO}
	var m := p0 - c
	var qa := d.dot(d)
	if qa < 0.000001:
		return miss
	var qb := 2.0 * m.dot(d)
	var qc := m.dot(m) - r * r
	if qc < 0.0:
		if qb < 0.0:
			var n := m.normalized() if m.length() > 0.0001 else -d.normalized()
			return {"hit": true, "t": 0.0, "normal": n}
		return miss
	var disc := qb * qb - 4.0 * qa * qc
	if disc < 0.0:
		return miss
	var t := (-qb - sqrt(disc)) / (2.0 * qa)
	if t < 0.0 or t > 1.0:
		return miss
	return {"hit": true, "t": t, "normal": (p0 + d * t - c).normalized()}


# --- Drawing -----------------------------------------------------------

func _process(delta: float) -> void:
	if look() == Look.FIREBALL and not stuck:
		_spark_drip -= delta
		if _spark_drip <= 0.0:
			_spark_drip = 0.04
			if effects:
				effects.sparks(global_position, Vector2.DOWN, 1, FLARE)
	queue_redraw()


func _draw() -> void:
	match look():
		Look.FIREBALL:
			_draw_tail(10, EMBER, FLARE, 3.6 * _scale(), 0.55)
			draw_circle(Vector2.ZERO, radius, FLARE)
			draw_circle(Vector2.ZERO, radius * 0.5, EMBER)
		Look.SLOW:
			_draw_tail(4, ICE, ICE, 4.2 * _scale(), 0.5)
			# A faint ring of frost.
			draw_arc(Vector2.ZERO, radius + 2.5, 0.0, TAU, 20, Color(ICE, 0.35), 1.0, true)
			draw_circle(Vector2.ZERO, radius, ICE)
			draw_circle(Vector2.ZERO, radius * 0.5, BONE)
		Look.FAST:
			_draw_streak(12, VOLT)
			draw_circle(Vector2.ZERO, radius, VOLT)
			draw_circle(Vector2.ZERO, radius * 0.5, BONE)
		Look.ZAP:
			_draw_tail(3, Color.WHITE, Color.WHITE, 3.0 * _scale(), 0.6)
			draw_circle(Vector2.ZERO, radius, Color.WHITE)
			draw_circle(Vector2.ZERO, radius * 0.5, VOLT)
		Look.GIANT:
			# The comet grows with the ball, tail and all.
			_draw_tail(8, BONE, VOLT, 3.4 * _scale(), 0.5)
			draw_circle(Vector2.ZERO, radius, BONE)
			draw_circle(Vector2.ZERO, radius * 0.68, VOLT)
			draw_circle(Vector2.ZERO, radius * 0.3, BONE)
		_:
			_draw_tail(6, VOLT, VOLT, 3.4 * _scale(), 0.45)
			draw_circle(Vector2.ZERO, radius, VOLT)
			draw_circle(Vector2.ZERO, radius * 0.5, BONE)


## How far the ball is from its resting size. The tail scales with it,
## so a giant comet does not trail a thread behind a boulder.
func _scale() -> float:
	return radius / BASE_RADIUS


func _draw_tail(links: int, near: Color, far: Color, start_size: float, start_alpha: float) -> void:
	var count := mini(links, _trail.size() - 1)
	for i in range(count, 0, -1):
		var f := float(i) / float(maxi(links - 1, 1))
		var c := near.lerp(far, f)
		c.a = lerpf(start_alpha, 0.03, f)
		draw_circle(to_local(_trail[i]), lerpf(start_size, 0.8, f), c)


## Fast draws a streak instead of circles.
func _draw_streak(links: int, color: Color) -> void:
	var count := mini(links, _trail.size() - 1)
	if count < 2:
		return
	for i in range(count, 0, -1):
		var f := float(i) / float(maxi(links - 1, 1))
		var c := color
		c.a = lerpf(0.4, 0.02, f)
		draw_line(to_local(_trail[i]), to_local(_trail[i - 1]), c, lerpf(2.4, 0.6, f))
