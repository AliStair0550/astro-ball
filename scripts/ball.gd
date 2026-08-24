class_name Ball
extends CharacterBody2D

## Lag 4: kometen.
##
## Egen kollision. Ingen RigidBody, ingen move_and_slide. Hver fysik-tick
## sveeper en cirkel mod rammens tre inderflader, paddlens tre yderflader
## og de klodser, bevægelsen faktisk rører. Refleksionen er manuel, så
## farten kan holdes konstant.
##
## Udgangsvinklen fra paddlen bestemmes af rammepunktet:
##   yderste kant 25 grader fra vandret, midte 80 grader, lineært imellem.
## De midterste 8 px er sweet spot: 88 grader og 10 % fart, der aftager
## over 2 sekunder. Bolden går aldrig under 20 grader fra vandret,
## heller ikke efter en vægrefleksion.

signal wall_hit(pos: Vector2, normal: Vector2)
signal paddle_hit(pos: Vector2, exit_angle_deg: float, sweet: bool)
signal brick_hit(brick: Brick, damage: int, pos: Vector2, passed_through: bool)
signal lost(ball: Ball)

enum Look { NORMAL, FIREBALL, SLOW, FAST, ZAP }

const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const ICE := Color("4DD8FF")
const EMBER := Color("FF4D2E")
const FLARE := Color("FF9F1C")

const RADIUS := 4.0
const BASE_SPEED := 320.0

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

var arena: Arena
var paddle: Paddle
var grid: BrickGrid
var game_feel: GameFeel
var effects: Effects

var stuck := true
## Frosset ved level clear: bolden holder sin retning og fart, men
## bevæger sig ikke. Så er tilstanden stadig sand, når HUD og debug
## kigger på den.
var frozen := false
var speed_base := BASE_SPEED
## Langsom sætter den til 0.7, Hurtig til 1.4. Farten rettes med det
## samme, så bolden aldrig hænger en frame bagud efter en power-up.
var speed_scale := 1.0:
	set(value):
		speed_scale = value
		if velocity.length() > 0.0001:
			velocity = velocity.normalized() * current_speed()
var fireball := false
var zap := false
var last_exit_angle := 0.0

var _bonus_left := 0.0
var _trail: Array[Vector2] = []
var _spark_drip := 0.0


func _ready() -> void:
	_fill_trail()


func current_speed() -> float:
	var bonus := SWEET_BONUS * (_bonus_left / SWEET_BONUS_TIME)
	return speed_base * speed_scale * (1.0 + maxf(bonus, 0.0))


func look() -> Look:
	if fireball:
		return Look.FIREBALL
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
		global_position = paddle.ball_anchor(RADIUS)
	_fill_trail()


func _fill_trail() -> void:
	_trail.clear()
	for i in TRAIL_LENGTH:
		_trail.append(global_position)


func _unhandled_input(event: InputEvent) -> void:
	if not stuck:
		return
	var fire := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		fire = true
	elif event is InputEventScreenTouch and event.pressed:
		fire = true
	if fire:
		launch()


func launch() -> void:
	if not stuck:
		return
	stuck = false
	var angle := LAUNCH_ANGLE_DEG + randf_range(-LAUNCH_SPREAD_DEG, LAUNCH_SPREAD_DEG)
	var dir_x := 1.0 if randf() < 0.5 else -1.0
	var a := deg_to_rad(angle)
	velocity = Vector2(cos(a) * dir_x, -sin(a)) * current_speed()


## Bruges af Multi: en ny bold sendes ud i en ny retning med samme fart.
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
			global_position = paddle.ball_anchor(RADIUS)
		_fill_trail()
		queue_redraw()
		return

	if velocity.length() > 0.0001:
		velocity = velocity.normalized() * current_speed()

	_advance(delta)
	_resolve_paddle_overlap()

	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)

	if arena and global_position.y - RADIUS > arena.death_y:
		lost.emit(self)
		return

	queue_redraw()


func _advance(delta: float) -> void:
	var remaining := delta
	var guard := 0
	while remaining > 0.00001 and guard < MAX_SUBSTEPS:
		guard += 1
		var motion := velocity * remaining
		var best_t := 1.0
		var best_normal := Vector2.ZERO
		var best_kind := ""
		var best_brick: Brick = null

		if arena:
			for seg in arena.wall_segments():
				var hit := _sweep_circle_segment(global_position, motion, RADIUS, seg["a"], seg["b"])
				if hit["hit"] and hit["t"] < best_t:
					best_t = hit["t"]
					best_normal = hit["normal"]
					best_kind = "wall"
					best_brick = null

		if paddle:
			var r := paddle.world_rect()
			var top_left := r.position
			var top_right := Vector2(r.end.x, r.position.y)
			var faces := [
				[top_left, top_right, "paddle_top"],
				[top_left, Vector2(r.position.x, r.end.y), "paddle_side"],
				[top_right, r.end, "paddle_side"],
			]
			for face in faces:
				var hit := _sweep_circle_segment(global_position, motion, RADIUS, face[0], face[1])
				if hit["hit"] and hit["t"] < best_t:
					best_t = hit["t"]
					best_normal = hit["normal"]
					best_kind = face[2]
					best_brick = null

		if grid:
			var swept := Rect2(global_position, Vector2.ZERO)
			swept = swept.expand(global_position + motion).grow(RADIUS + 1.0)
			for brick in grid.bricks_in(swept):
				var hit := _sweep_circle_rect(global_position, motion, RADIUS, brick.rect)
				if hit["hit"] and hit["t"] < best_t:
					best_t = hit["t"]
					best_normal = hit["normal"]
					best_kind = "brick"
					best_brick = brick

		if best_kind == "":
			global_position += motion
			return

		var pass_through := false
		var damage := 1
		if best_kind == "brick":
			if fireball and best_brick.is_breakable():
				pass_through = true
				damage = best_brick.hits_left
			elif best_brick.lets_ball_pass():
				pass_through = true

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


## Aldrig fladere end 20 grader. En bold, der triller vandret langs
## rammen, er den eneste måde at gøre spillet kedeligt på.
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
	var r := paddle.world_rect().grow(RADIUS)
	if not r.has_point(global_position):
		return
	if global_position.y > paddle.global_position.y:
		return
	global_position.y = paddle.top_y() - RADIUS - SKIN
	if velocity.y > 0.0:
		_bounce_off_paddle()


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


## Cirkel med radius r flyttes fra p0 med vektoren d mod segmentet a-b.
## Returnerer {"hit": bool, "t": float, "normal": Vector2}, hvor t er
## andelen af d frem til kontakt.
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


# --- Tegning -----------------------------------------------------------

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
			_draw_tail(10, EMBER, FLARE, 3.6, 0.55)
			draw_circle(Vector2.ZERO, RADIUS, FLARE)
			draw_circle(Vector2.ZERO, RADIUS - 2.0, EMBER)
		Look.SLOW:
			_draw_tail(4, ICE, ICE, 4.2, 0.5)
			# Svag frostring.
			draw_arc(Vector2.ZERO, RADIUS + 2.5, 0.0, TAU, 20, Color(ICE, 0.35), 1.0, true)
			draw_circle(Vector2.ZERO, RADIUS, ICE)
			draw_circle(Vector2.ZERO, RADIUS - 2.0, BONE)
		Look.FAST:
			_draw_streak(12, VOLT)
			draw_circle(Vector2.ZERO, RADIUS, VOLT)
			draw_circle(Vector2.ZERO, RADIUS - 2.0, BONE)
		Look.ZAP:
			_draw_tail(3, Color.WHITE, Color.WHITE, 3.0, 0.6)
			draw_circle(Vector2.ZERO, RADIUS, Color.WHITE)
			draw_circle(Vector2.ZERO, RADIUS - 2.0, VOLT)
		_:
			_draw_tail(6, VOLT, VOLT, 3.4, 0.45)
			draw_circle(Vector2.ZERO, RADIUS, VOLT)
			draw_circle(Vector2.ZERO, RADIUS - 2.0, BONE)


func _draw_tail(links: int, near: Color, far: Color, start_size: float, start_alpha: float) -> void:
	var count := mini(links, _trail.size() - 1)
	for i in range(count, 0, -1):
		var f := float(i) / float(maxi(links - 1, 1))
		var c := near.lerp(far, f)
		c.a = lerpf(start_alpha, 0.03, f)
		draw_circle(to_local(_trail[i]), lerpf(start_size, 0.8, f), c)


## Hurtig tegner en streg i stedet for cirkler.
func _draw_streak(links: int, color: Color) -> void:
	var count := mini(links, _trail.size() - 1)
	if count < 2:
		return
	for i in range(count, 0, -1):
		var f := float(i) / float(maxi(links - 1, 1))
		var c := color
		c.a = lerpf(0.4, 0.02, f)
		draw_line(to_local(_trail[i]), to_local(_trail[i - 1]), c, lerpf(2.4, 0.6, f))
