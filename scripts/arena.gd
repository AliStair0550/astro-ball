class_name Arena
extends Node2D

## Layer 2: the containment field.
##
## The frame is 6 px of #232330 with a 1 px inner energy line in #3A3A50
## pulsing on a four second cycle. On contact a 40 px segment lights up
## in Volt for 120 ms, with a wave running 20 px out to either side.
## Two emitters in the top corners blink on every hit, so the player
## understands without being told that the frame is projected.
##
## The bottom is open. That is the edge of the field, and below it is a fall.

const VOID := Color("07070C")
const FRAME := Color("232330")
const ENERGY := Color("3A3A50")
const VOLT := Color("D6FF3D")
const EMBER := Color("FF4D2E")

const SCREEN := Vector2(390.0, 844.0)
## The HUD fills the top. On a screen twice as tall as it is wide the
## panel is not decoration: it is where the dead space goes. Every pixel
## it takes is a pixel the wall does not have to hover above.
const HUD_HEIGHT := 196.0
const WALL := 6.0

const EMITTER_SIZE := 8.0
const EMITTER_BLINK_TIME := 0.12

const HIT_TIME := 0.12
const HIT_SEGMENT := 40.0
const HIT_WAVE := 20.0

const PULSE_PERIOD := 4.0
const EMBER_WARN_DISTANCE := 100.0
const EMBER_LINE_Y := SCREEN.y - 4.0

const CELEBRATE_TIME := 0.9

## Bottom edge of the field. Below it is a fall.
var death_y := SCREEN.y

var _walls: Array[Dictionary] = []
var _hits: Array[Dictionary] = []
var _emitter_blink := 0.0
var _danger := 0.0
var _celebrate := 0.0
var _time := 0.0


func _ready() -> void:
	_build_walls()


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


func wall_segments() -> Array[Dictionary]:
	return _walls


func inner_rect() -> Rect2:
	return Rect2(WALL, HUD_HEIGHT + WALL, SCREEN.x - WALL * 2.0, SCREEN.y - HUD_HEIGHT - WALL)


## The ball hit the field. The segment lights, the emitters blink.
func register_hit(pos: Vector2) -> void:
	var index := _nearest_wall(pos)
	var wall: Dictionary = _walls[index]
	var seg_dir: Vector2 = (wall["b"] - wall["a"]).normalized()
	_hits.append({"wall": index, "s": (pos - wall["a"]).dot(seg_dir), "t": 0.0})
	_emitter_blink = 1.0


## 0 to 1. The Ember line burns harder the closer the ball is to the edge.
func set_danger(level: float) -> void:
	_danger = clampf(level, 0.0, 1.0)


## Field cleared: the frame lights all the way round.
func celebrate() -> void:
	_celebrate = CELEBRATE_TIME


func reset() -> void:
	_hits.clear()
	_emitter_blink = 0.0
	_danger = 0.0
	_celebrate = 0.0


func _process(delta: float) -> void:
	_time += delta

	if _emitter_blink > 0.0:
		_emitter_blink = maxf(0.0, _emitter_blink - delta / EMITTER_BLINK_TIME)
	if _celebrate > 0.0:
		_celebrate = maxf(0.0, _celebrate - delta)

	var i := _hits.size() - 1
	while i >= 0:
		_hits[i]["t"] = float(_hits[i]["t"]) + delta
		if _hits[i]["t"] >= HIT_TIME:
			_hits.remove_at(i)
		i -= 1

	queue_redraw()


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


# --- Drawing -----------------------------------------------------------

func _draw() -> void:
	_draw_frame()
	_draw_energy_line()
	_draw_hits()
	_draw_celebration()
	_draw_emitters()
	_draw_ember_line()


func _draw_frame() -> void:
	var h := SCREEN.y - HUD_HEIGHT
	draw_rect(Rect2(0.0, HUD_HEIGHT, SCREEN.x, WALL), FRAME)
	draw_rect(Rect2(0.0, HUD_HEIGHT, WALL, h), FRAME)
	draw_rect(Rect2(SCREEN.x - WALL, HUD_HEIGHT, WALL, h), FRAME)


func _draw_energy_line() -> void:
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
		# The wave runs outward while the core fades.
		var wave_pos := HIT_WAVE + HIT_WAVE * (1.0 - f)

		for i in range(int(HIT_SEGMENT) + 1):
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
			var size := seg_dir.abs() * 2.0 + inward.abs() * 3.0
			var corner := origin
			if inward.x < 0.0 or inward.y < 0.0:
				corner += inward * 3.0
			draw_rect(Rect2(corner, size), c)


func _draw_celebration() -> void:
	if _celebrate <= 0.0:
		return
	var f := _celebrate / CELEBRATE_TIME
	var c := VOLT
	c.a = f * 0.85
	var top := HUD_HEIGHT + WALL
	draw_rect(Rect2(WALL, top, SCREEN.x - WALL * 2.0, 3.0), c)
	draw_rect(Rect2(WALL, top, 3.0, SCREEN.y - top), c)
	draw_rect(Rect2(SCREEN.x - WALL - 3.0, top, 3.0, SCREEN.y - top), c)


func _draw_emitters() -> void:
	var y := HUD_HEIGHT + WALL + 1.0
	var rects := [
		Rect2(WALL + 1.0, y, EMITTER_SIZE, EMITTER_SIZE),
		Rect2(SCREEN.x - WALL - 1.0 - EMITTER_SIZE, y, EMITTER_SIZE, EMITTER_SIZE),
	]
	var blink := maxf(_emitter_blink, _celebrate / CELEBRATE_TIME if _celebrate > 0.0 else 0.0)
	for r: Rect2 in rects:
		var base := ENERGY
		base.a = 0.55
		draw_rect(r, base)
		if blink > 0.0:
			var c := VOLT
			c.a = blink
			draw_rect(r, c)
			var glow := VOLT
			glow.a = blink * 0.25
			draw_rect(r.grow(3.0), glow)
		var core := VOID
		core.a = 0.7
		draw_rect(Rect2(r.position + Vector2(3.0, 3.0), Vector2(2.0, 2.0)), core)


func _draw_ember_line() -> void:
	var alpha := 0.12
	if _danger > 0.0:
		# 150 ms to save it. The blink gets faster and harder.
		var blink := 0.5 + 0.5 * sin(_time * TAU * (6.0 + 8.0 * _danger))
		alpha = 0.12 + 0.88 * _danger * blink
	var c := EMBER
	c.a = alpha
	draw_rect(Rect2(WALL, EMBER_LINE_Y, SCREEN.x - WALL * 2.0, 1.0), c)
