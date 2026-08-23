class_name Ball
extends CharacterBody2D

## Lag 4: kometen.
##
## Egen kollision. Ingen RigidBody, ingen move_and_slide. Bolden er en
## swept circle mod linjesegmenter: rammens tre inderflader og paddlens
## tre yderflader. Farten er konstant, refleksionen er manuel.
##
## Udgangsvinklen fra paddlen bestemmes af rammepunktet:
##   yderste kant 25 grader fra vandret, midte 80 grader, lineært imellem.
## De midterste 8 px er sweet spot: 88 grader og 10 % fart, der aftager
## over 2 sekunder. Bolden går aldrig under 20 grader fra vandret,
## heller ikke efter en vægrefleksion.

signal wall_hit(pos: Vector2, normal: Vector2)
signal paddle_hit(pos: Vector2, exit_angle_deg: float, sweet: bool)
signal lost()

const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")

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

const TRAIL_LENGTH := 6
const SKIN := 0.01
const MAX_SUBSTEPS := 8

var arena: Arena
var paddle: Paddle
var game_feel: GameFeel

var stuck := true
var speed_base := BASE_SPEED
var last_exit_angle := 0.0

var _bonus_left := 0.0
var _trail: Array[Vector2] = []
var _segments: Array[Dictionary] = []


func _ready() -> void:
	for i in TRAIL_LENGTH:
		_trail.append(global_position)


## Den fart, bolden faktisk har lige nu, inklusive sweet spot-bonus.
func current_speed() -> float:
	var bonus := SWEET_BONUS * (_bonus_left / SWEET_BONUS_TIME)
	return speed_base * (1.0 + maxf(bonus, 0.0))


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


func _physics_process(delta: float) -> void:
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

	# Konstant fart. Retningen bærer al information, længden er styret.
	if velocity.length() > 0.0001:
		velocity = velocity.normalized() * current_speed()

	_rebuild_segments()
	_advance(delta)
	_resolve_paddle_overlap()

	_trail.push_front(global_position)
	if _trail.size() > TRAIL_LENGTH:
		_trail.resize(TRAIL_LENGTH)

	if arena and global_position.y - RADIUS > arena.death_y:
		lost.emit()
		stick_to_paddle()

	queue_redraw()


func _rebuild_segments() -> void:
	_segments.clear()
	if arena:
		for seg in arena.wall_segments():
			_segments.append(seg)
	if paddle:
		var r := paddle.world_rect()
		var top_left := r.position
		var top_right := Vector2(r.end.x, r.position.y)
		_segments.append({"a": top_left, "b": top_right, "kind": "paddle_top"})
		_segments.append({"a": top_left, "b": Vector2(r.position.x, r.end.y), "kind": "paddle_side"})
		_segments.append({"a": top_right, "b": r.end, "kind": "paddle_side"})


func _advance(delta: float) -> void:
	var remaining := delta
	var guard := 0
	while remaining > 0.00001 and guard < MAX_SUBSTEPS:
		guard += 1
		var motion := velocity * remaining
		var best_t := 1.0
		var best_normal := Vector2.ZERO
		var best_kind := ""
		for seg in _segments:
			var hit := _sweep_circle_segment(global_position, motion, RADIUS, seg["a"], seg["b"])
			if hit["hit"] and hit["t"] < best_t:
				best_t = hit["t"]
				best_normal = hit["normal"]
				best_kind = seg["kind"]

		if best_kind == "":
			global_position += motion
			return

		global_position += motion * best_t + best_normal * SKIN
		remaining *= (1.0 - best_t)

		if best_kind == "paddle_top" and best_normal.y < -0.5:
			_bounce_off_paddle()
		else:
			velocity = velocity - 2.0 * best_normal * velocity.dot(best_normal)
			velocity = _enforce_min_angle(velocity)
			if best_kind == "wall":
				wall_hit.emit(global_position, best_normal)
			else:
				paddle.on_ball_hit(global_position.x)


func _bounce_off_paddle() -> void:
	var half := paddle.half_width()
	var dx := global_position.x - paddle.global_position.x
	var offset := clampf(dx / half, -1.0, 1.0)
	var sweet := absf(dx) <= SWEET_HALF_WIDTH

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


## Paddlen kan bevæge sig ind over bolden, hurtigere end bolden kan
## flygte. Så skubber vi den fri i stedet for at lade den sidde fast.
func _resolve_paddle_overlap() -> void:
	if paddle == null:
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
		# Starter allerede inde i fladen. Kun gyldigt, hvis vi trænger dybere ind.
		if approach < 0.0:
			t = 0.0
	elif approach < 0.0:
		t = (dist - r) / -approach

	if t >= 0.0 and t <= 1.0:
		var contact := p0 + d * t - normal * r
		var along := (contact - a).dot(seg_dir)
		if along >= 0.0 and along <= seg_len:
			return {"hit": true, "t": t, "normal": normal}

	# Uden for fladen: prøv de to endepunkter som cirkler.
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

func _draw() -> void:
	# Komethalen: de sidste 6 positioner, faldende størrelse og opacity.
	for i in range(_trail.size() - 1, 0, -1):
		var f := float(i) / float(TRAIL_LENGTH - 1)
		var c := VOLT
		c.a = lerpf(0.45, 0.04, f)
		draw_circle(to_local(_trail[i]), lerpf(3.4, 1.0, f), c)

	draw_circle(Vector2.ZERO, RADIUS, VOLT)
	draw_circle(Vector2.ZERO, RADIUS - 2.0, BONE)
