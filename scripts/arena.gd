class_name Arena
extends Node2D

## Lag 2: containment-feltet, og samtidig scenens lille dirigent.
##
## Rammen er 6 px i #232330 med en indre energilinje på 1 px i #3A3A50,
## der pulserer i en 4-sekunders cyklus. Ved boldkontakt lyser et 40 px
## segment op i Volt i 120 ms med en bølge, der løber 20 px til hver side.
## To emittere i de øverste hjørner blinker, hver gang feltet rammes.
## Bunden er åben. En Ember-linje blinker, når bolden er tæt på at falde ud.
##
## Arenaen ejer også ledningsføringen: den kobler bold, paddle, baggrund
## og game feel sammen, så ingen af dem behøver kende hinanden på forhånd.

const VOID := Color("07070C")
const FRAME := Color("232330")
const ENERGY := Color("3A3A50")
const VOLT := Color("D6FF3D")
const EMBER := Color("FF4D2E")
const BONE := Color("F2EFE6")
const SLATE := Color("888780")

const SCREEN := Vector2(390.0, 844.0)
## Reserveret til HUD i senere faser. Rammen starter under den.
const HUD_HEIGHT := 44.0
const WALL := 6.0

const EMITTER_SIZE := 8.0
const EMITTER_BLINK_TIME := 0.12

const HIT_TIME := 0.12
const HIT_SEGMENT := 40.0
const HIT_WAVE := 20.0

const PULSE_PERIOD := 4.0

const EMBER_WARN_DISTANCE := 100.0
const EMBER_LINE_Y := SCREEN.y - 4.0

const SHAKE_WALL_AMPLITUDE := 2.0
const SHAKE_WALL_TIME := 0.06
## Hitstop er 0 i fase 1. Sprængklodser tænder den i fase 2.
const HITSTOP_WALL := 0.0

@onready var background: Background = $Background
@onready var paddle: Paddle = $Paddle
@onready var ball: Ball = $Ball
@onready var game_feel: GameFeel = $GameFeel
@onready var _debug_layer: CanvasLayer = $DebugOverlay
@onready var _debug_label: Label = $DebugOverlay/Label

## Nederste kant af feltet. Under den er der frit fald.
var death_y := SCREEN.y

var _walls: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _emitter_blink := 0.0
var _time := 0.0


func _ready() -> void:
	_build_walls()

	background.screen_size = SCREEN

	paddle.min_x = inner_rect().position.x + paddle.half_width()
	paddle.max_x = inner_rect().end.x - paddle.half_width()
	paddle.position = Vector2(SCREEN.x * 0.5, SCREEN.y - 64.0)

	ball.arena = self
	ball.paddle = paddle
	ball.game_feel = game_feel
	ball.stick_to_paddle()

	ball.wall_hit.connect(_on_wall_hit)
	ball.paddle_hit.connect(_on_paddle_hit)
	ball.lost.connect(_on_ball_lost)

	_debug_layer.visible = false


func _build_walls() -> void:
	var left := WALL
	var right := SCREEN.x - WALL
	var top := HUD_HEIGHT + WALL
	_walls = [
		{
			"a": Vector2(left, HUD_HEIGHT), "b": Vector2(left, SCREEN.y),
			"inward": Vector2(1.0, 0.0), "kind": "wall",
		},
		{
			"a": Vector2(right, HUD_HEIGHT), "b": Vector2(right, SCREEN.y),
			"inward": Vector2(-1.0, 0.0), "kind": "wall",
		},
		{
			"a": Vector2(left, top), "b": Vector2(right, top),
			"inward": Vector2(0.0, 1.0), "kind": "wall",
		},
	]


## Rammens tre inderflader som segmenter. Bolden sveeper mod dem.
func wall_segments() -> Array[Dictionary]:
	return _walls


## Spillefeltet inden for rammen. Bunden er åben.
func inner_rect() -> Rect2:
	return Rect2(WALL, HUD_HEIGHT + WALL, SCREEN.x - WALL * 2.0, SCREEN.y - HUD_HEIGHT - WALL)


func _process(delta: float) -> void:
	_time += delta

	background.set_focus_x(paddle.position.x)

	if _emitter_blink > 0.0:
		_emitter_blink = maxf(0.0, _emitter_blink - delta / EMITTER_BLINK_TIME)

	var i := _hits.size() - 1
	while i >= 0:
		_hits[i]["t"] += delta
		if _hits[i]["t"] >= HIT_TIME:
			_hits.remove_at(i)
		i -= 1

	if _debug_layer.visible:
		_update_debug()

	queue_redraw()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F1:
		_debug_layer.visible = not _debug_layer.visible


func _update_debug() -> void:
	var state := "klæbet" if ball.stuck else "i spil"
	_debug_label.text = "\n".join([
		"FPS        %d" % Engine.get_frames_per_second(),
		"BOLD       %s" % state,
		"FART       %.0f px/s" % ball.current_speed(),
		"UDGANG     %.1f grader" % ball.last_exit_angle,
		"VINKEL NU  %.1f grader" % _current_angle_deg(),
		"F1 skjuler",
	])


func _current_angle_deg() -> float:
	if ball.velocity.length() < 0.0001:
		return 0.0
	return rad_to_deg(atan2(absf(ball.velocity.y), absf(ball.velocity.x)))


# --- Reaktioner --------------------------------------------------------

func _on_wall_hit(pos: Vector2, _normal: Vector2) -> void:
	var index := _nearest_wall(pos)
	var wall: Dictionary = _walls[index]
	var seg_dir: Vector2 = (wall["b"] - wall["a"]).normalized()
	_hits.append({
		"wall": index,
		"s": (pos - wall["a"]).dot(seg_dir),
		"t": 0.0,
	})
	_emitter_blink = 1.0
	game_feel.shake(SHAKE_WALL_AMPLITUDE, SHAKE_WALL_TIME)
	game_feel.hitstop(HITSTOP_WALL)
	background.flash_near(pos, 5, VOLT)


func _on_paddle_hit(_pos: Vector2, _angle: float, _sweet: bool) -> void:
	# Squash og endestykkernes lys håndteres af paddlen selv.
	# Gnister og lyd kommer i fase 2.
	pass


func _on_ball_lost() -> void:
	# Liv-systemet kommer senere. Nu klæber bolden bare fast igen.
	pass


func _nearest_wall(pos: Vector2) -> int:
	var best := 0
	var best_dist := INF
	for i in _walls.size():
		var wall: Dictionary = _walls[i]
		var d := _distance_to_segment(pos, wall["a"], wall["b"])
		if d < best_dist:
			best_dist = d
			best = i
	return best


static func _distance_to_segment(p: Vector2, a: Vector2, b: Vector2) -> float:
	var ab := b - a
	var len_sq := ab.length_squared()
	if len_sq < 0.0001:
		return p.distance_to(a)
	var t := clampf((p - a).dot(ab) / len_sq, 0.0, 1.0)
	return p.distance_to(a + ab * t)


# --- Tegning -----------------------------------------------------------

func _draw() -> void:
	_draw_frame()
	_draw_energy_line()
	_draw_hits()
	_draw_emitters()
	_draw_ember_line()


func _draw_frame() -> void:
	var h := SCREEN.y - HUD_HEIGHT
	draw_rect(Rect2(0.0, HUD_HEIGHT, SCREEN.x, WALL), FRAME)
	draw_rect(Rect2(0.0, HUD_HEIGHT, WALL, h), FRAME)
	draw_rect(Rect2(SCREEN.x - WALL, HUD_HEIGHT, WALL, h), FRAME)


func _draw_energy_line() -> void:
	# Fire sekunders cyklus, knapt synligt. Feltet er energi, ikke metal.
	var pulse := 0.46 + 0.14 * sin(TAU * _time / PULSE_PERIOD)
	var c := ENERGY
	c.a = pulse
	var top := HUD_HEIGHT + WALL
	draw_rect(Rect2(WALL, top, SCREEN.x - WALL * 2.0, 1.0), c)
	draw_rect(Rect2(WALL, top, 1.0, SCREEN.y - top), c)
	draw_rect(Rect2(SCREEN.x - WALL - 1.0, top, 1.0, SCREEN.y - top), c)


func _draw_hits() -> void:
	for hit in _hits:
		var wall: Dictionary = _walls[hit["wall"]]
		var a: Vector2 = wall["a"]
		var b: Vector2 = wall["b"]
		var seg := b - a
		var seg_len := seg.length()
		var seg_dir := seg / seg_len
		var inward: Vector2 = wall["inward"]
		var f := 1.0 - float(hit["t"]) / HIT_TIME
		var s: float = hit["s"]
		# Bølgen løber udad, mens kernen fader.
		var wave_pos := HIT_WAVE + HIT_WAVE * (1.0 - f)

		var steps := int(HIT_SEGMENT)  # 2 px per skridt, fra -40 til +40
		for i in range(steps + 1):
			var u := -HIT_SEGMENT + float(i) * 2.0
			var au := absf(u)
			var alpha := 0.0
			if au <= HIT_SEGMENT * 0.5:
				alpha = f * (1.0 - au / (HIT_SEGMENT * 0.7))
			var dw := absf(au - wave_pos)
			alpha += f * 0.7 * exp(-(dw * dw) / 18.0)
			if alpha <= 0.02:
				continue
			var along := s + u
			if along < 0.0 or along > seg_len:
				continue
			var c := VOLT
			c.a = minf(alpha, 1.0)
			var origin := a + seg_dir * along
			# 2 px langs væggen, 3 px indad i feltet.
			var size := seg_dir.abs() * 2.0 + inward.abs() * 3.0
			var corner := origin
			if inward.x < 0.0 or inward.y < 0.0:
				corner += inward * 3.0
			draw_rect(Rect2(corner, size), c)


func _draw_emitters() -> void:
	var y := HUD_HEIGHT + WALL + 1.0
	var rects := [
		Rect2(WALL + 1.0, y, EMITTER_SIZE, EMITTER_SIZE),
		Rect2(SCREEN.x - WALL - 1.0 - EMITTER_SIZE, y, EMITTER_SIZE, EMITTER_SIZE),
	]
	for r: Rect2 in rects:
		var base := ENERGY
		base.a = 0.55
		draw_rect(r, base)
		if _emitter_blink > 0.0:
			var c := VOLT
			c.a = _emitter_blink
			draw_rect(r, c)
			var glow := VOLT
			glow.a = _emitter_blink * 0.25
			draw_rect(r.grow(3.0), glow)
		# Lille kerne, så emitteren ikke bare er en firkant.
		var core := VOID
		core.a = 0.7
		draw_rect(Rect2(r.position + Vector2(3.0, 3.0), Vector2(2.0, 2.0)), core)


func _draw_ember_line() -> void:
	var distance := death_y - ball.global_position.y
	var alpha := 0.12
	if not ball.stuck and distance < EMBER_WARN_DISTANCE:
		var closeness := 1.0 - clampf(distance / EMBER_WARN_DISTANCE, 0.0, 1.0)
		# 150 ms til at redde den. Blinket bliver hurtigere og hårdere.
		var blink := 0.5 + 0.5 * sin(_time * TAU * (6.0 + 8.0 * closeness))
		alpha = 0.12 + 0.88 * closeness * blink
	var c := EMBER
	c.a = alpha
	draw_rect(Rect2(WALL, EMBER_LINE_Y, SCREEN.x - WALL * 2.0, 1.0), c)
