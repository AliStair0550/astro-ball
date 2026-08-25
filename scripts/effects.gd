class_name Effects
extends Node2D

## Layer 5: particles, shockwaves, flashes and score numbers.
##
## The rule from section 6: no effect lasts longer than 400 ms, and
## particles are always square or rectangular, never round. The same
## language as the bricks, so a shard looks like a piece of what broke.

const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const EMBER := Color("FF4D2E")

const FONT_SCORE := preload("res://assets/fonts/SpaceGrotesk-700.ttf")
const FONT_COMBO := preload("res://assets/fonts/Unbounded-900.ttf")

const GRAVITY := 620.0
const SPLINTER_LIFE := 0.35
const SHARD_LIFE := 0.40
const SPARK_LIFE := 0.18
const SCORE_LIFE := 0.40
const SHOCKWAVE_LIFE := 0.22
const COMBO_LIFE := 0.40

var screen_size := Vector2(390.0, 844.0)

var _bits: Array[Dictionary] = []
## Dead shards are kept and refilled rather than thrown away. A busy
## chain reaction can retire eighty of them in a second, and the garbage
## that makes is the one allocation the game does at speed.
var _bit_pool: Array[Dictionary] = []
var _texts: Array[Dictionary] = []
## Zap's bolts. Capped, so a ball tearing through a wall cannot grow the
## list without limit, and the points array is built once per bolt.
const MAX_BOLTS := 12
const BOLT_POINTS := 5
const BOLT_LIFE := 0.18
var _bolts: Array[Dictionary] = []
var _suspense: Dictionary = {}
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _combo: Dictionary = {}
var _font: Font = FONT_SCORE


## Takes a shard from the pool, or makes one the first time.
func _take_bit() -> Dictionary:
	if _bit_pool.is_empty():
		return {}
	return _bit_pool.pop_back()


func _retire_bit(index: int) -> void:
	_bit_pool.append(_bits[index])
	_bits.remove_at(index)


## How many shards are being kept warm. The debug overlay reads it.
func pool_size() -> int:
	return _bit_pool.size()


# --- Bricks ------------------------------------------------------------

## 5 to 8 shards in the brick's colour, 40 to 90 px/s, spinning, pulled
## down by gravity, gone after 350 ms.
func brick_smashed(rect: Rect2, color: Color, count: int, glass := false,
		impact := Vector2.INF) -> void:
	var center := rect.get_center()
	# Shards fly away from where the ball actually hit. Without that they
	# spray evenly and the hit loses its direction.
	var away := Vector2.ZERO
	if impact != Vector2.INF and impact.distance_to(center) > 0.5:
		away = (center - impact).normalized()

	# Three tones of the same material: the face, the top line and the
	# bottom line. A single flat colour reads as confetti.
	var tones := [color, color.lightened(0.2), color.darkened(0.3)]

	for i in count:
		var angle := randf() * TAU
		var dir := Vector2(cos(angle), sin(angle))
		if away != Vector2.ZERO:
			dir = (dir * 0.55 + away).normalized()
		var speed := randf_range(40.0, 90.0)
		var size := Vector2(randf_range(2.0, 5.0), randf_range(2.0, 3.0))
		if glass:
			# Ice in vacuum: lighter, drifts longer, almost no gravity.
			speed = randf_range(30.0, 70.0)
			size = Vector2(randf_range(1.0, 2.0), randf_range(3.0, 7.0))
		_bits.append(_fill(_take_bit(), {
			"kind": "splinter",
			"pos": center + Vector2(randf_range(-rect.size.x, rect.size.x), randf_range(-rect.size.y, rect.size.y)) * 0.4,
			"vel": dir * speed,
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
			"size": size,
			"color": tones[i % tones.size()],
			"gravity": 60.0 if glass else GRAVITY,
			"t": 0.0,
			"life": SHARD_LIFE if glass else SPLINTER_LIFE,
		}))
	_flashes.append({"rect": rect, "color": Color.WHITE, "t": 0.0, "life": 0.017})


## Live shard count. The feel test and the debug overlay read it.
func shard_count() -> int:
	var n := 0
	for bit in _bits:
		if bit["kind"] == "splinter":
			n += 1
	return n


## Hardened takes damage: 3 sparks, no shards.
func brick_damaged(at: Vector2, color: Color) -> void:
	sparks(at, Vector2.UP, 3, color.lightened(0.4))


## The blast brick: a white flash over 3x3 cells, a ring out to 80 px.
func blast(rect: Rect2, area: Rect2) -> void:
	_flashes.append({"rect": area, "color": Color.WHITE, "t": 0.0, "life": 0.034})
	shockwave(rect.get_center(), 80.0, EMBER)


func shockwave(at: Vector2, radius: float, color: Color) -> void:
	_rings.append({"pos": at, "radius": radius, "color": color, "t": 0.0, "life": SHOCKWAVE_LIFE})


func sparks(at: Vector2, dir: Vector2, count: int, color: Color) -> void:
	for i in count:
		var spread := dir.rotated(randf_range(-0.9, 0.9))
		_bits.append(_fill(_take_bit(), {
			"kind": "spark",
			"pos": at,
			"vel": spread * randf_range(70.0, 160.0),
			"rot": 0.0,
			"spin": 0.0,
			"size": Vector2(2.0, 2.0),
			"color": color,
			"gravity": 240.0,
			"t": 0.0,
			"life": SPARK_LIFE,
		}))


## A bolt between two points. Four segments, jittered off the straight
## line, gone in 180 ms. Pre-sized on the pool like everything else.
func lightning(from: Vector2, to: Vector2, color: Color) -> void:
	if _bolts.size() >= MAX_BOLTS:
		_bolts.remove_at(0)
	var points := PackedVector2Array()
	var span := to - from
	var side := Vector2(-span.y, span.x).normalized()
	for i in BOLT_POINTS:
		var f := float(i) / float(BOLT_POINTS - 1)
		var wobble := 0.0
		if i > 0 and i < BOLT_POINTS - 1:
			wobble = randf_range(-5.0, 5.0)
		points.append(from + span * f + side * wobble)
	_bolts.append({"points": points, "color": color, "t": 0.0})


## The question mark over the paddle while a Lottery is being drawn. One
## entry, replaced rather than stacked, so a second capsule cannot leave
## two of them flickering at each other.
func suspense(at: Vector2, seconds: float, color: Color) -> void:
	_suspense = {"pos": at, "left": seconds, "total": maxf(seconds, 0.001), "color": color}


func score_popup(at: Vector2, amount: int) -> void:
	_texts.append({
		"text": "+%d" % amount,
		"pos": at,
		"color": BONE,
		"size": 11,
		"t": 0.0,
		"life": SCORE_LIFE,
		"rise": 20.0,
	})


## Combo 5, 10, 20: the number large in the middle, 100 ms of scale, fade.
func combo(value: int) -> void:
	_combo = {"value": value, "t": 0.0, "life": COMBO_LIFE}


## The comet shatters into 20 pieces at the edge and is pulled down.
func ball_lost(at: Vector2) -> void:
	for i in 20:
		var angle := randf_range(-PI, 0.0)
		_bits.append(_fill(_take_bit(), {
			"kind": "splinter",
			"pos": at + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(30.0, 110.0),
			"rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0),
			"size": Vector2(randf_range(1.0, 3.0), randf_range(1.0, 3.0)),
			"color": VOLT if i % 3 else BONE,
			# The pull down is stronger than ordinary gravity.
			"gravity": 1500.0,
			"t": 0.0,
			"life": 0.4,
		}))


func powerup_icon(at: Vector2, text: String, color: Color) -> void:
	_texts.append({
		"text": text,
		"pos": at,
		"color": color,
		"size": 12,
		"t": 0.0,
		"life": 0.6,
		"rise": 10.0,
	})


func clear_all() -> void:
	for bit in _bits:
		_bit_pool.append(bit)
	_bits.clear()
	_texts.clear()
	_rings.clear()
	_bolts.clear()
	_suspense = {}
	_flashes.clear()
	_combo = {}


# --- Update ------------------------------------------------------------

## Refills a recycled shard. Merge rather than replace, so the reused
## dictionary keeps its allocation.
static func _fill(target: Dictionary, values: Dictionary) -> Dictionary:
	for key in values:
		target[key] = values[key]
	return target


func _process(delta: float) -> void:
	var i := _bits.size() - 1
	while i >= 0:
		var b := _bits[i]
		b["t"] += delta
		if b["t"] >= b["life"]:
			_retire_bit(i)
		else:
			b["vel"] = b["vel"] + Vector2(0.0, b["gravity"]) * delta
			b["pos"] = b["pos"] + b["vel"] * delta
			b["rot"] = b["rot"] + b["spin"] * delta
		i -= 1

	i = _texts.size() - 1
	while i >= 0:
		_texts[i]["t"] += delta
		if _texts[i]["t"] >= _texts[i]["life"]:
			_texts.remove_at(i)
		i -= 1

	i = _rings.size() - 1
	while i >= 0:
		_rings[i]["t"] += delta
		if _rings[i]["t"] >= _rings[i]["life"]:
			_rings.remove_at(i)
		i -= 1

	i = _bolts.size() - 1
	while i >= 0:
		_bolts[i]["t"] += delta
		if _bolts[i]["t"] >= BOLT_LIFE:
			_bolts.remove_at(i)
		i -= 1

	if not _suspense.is_empty():
		_suspense["left"] = float(_suspense["left"]) - delta
		if float(_suspense["left"]) <= 0.0:
			_suspense = {}

	i = _flashes.size() - 1
	while i >= 0:
		_flashes[i]["t"] += delta
		if _flashes[i]["t"] >= _flashes[i]["life"]:
			_flashes.remove_at(i)
		i -= 1

	if not _combo.is_empty():
		_combo["t"] += delta
		if _combo["t"] >= _combo["life"]:
			_combo = {}

	queue_redraw()


func _draw() -> void:
	for bolt in _bolts:
		var f := float(bolt["t"]) / BOLT_LIFE
		var c: Color = bolt["color"]
		c.a = (1.0 - f) * 0.9
		draw_polyline(bolt["points"], c, 2.0)
		c.a = (1.0 - f) * 0.5
		draw_polyline(bolt["points"], Color.WHITE, 1.0)

	for f in _flashes:
		var c: Color = f["color"]
		c.a = 1.0 - float(f["t"]) / float(f["life"])
		draw_rect(f["rect"], c)

	for r in _rings:
		var f := float(r["t"]) / float(r["life"])
		var c: Color = r["color"]
		c.a = (1.0 - f) * 0.9
		var radius: float = float(r["radius"]) * ease(f, 0.4)
		_draw_square_ring(r["pos"], radius, c)

	for b in _bits:
		var f := float(b["t"]) / float(b["life"])
		var c: Color = b["color"]
		c.a = 1.0 - f * f
		if b["kind"] == "spark":
			draw_rect(Rect2(b["pos"] - Vector2(1.0, 1.0), b["size"]), c)
		else:
			_draw_rotated_rect(b["pos"], b["size"], b["rot"], c)

	if _font and not _suspense.is_empty():
		# Faster and brighter as it runs out, so the reveal is the end of
		# something rather than an interruption.
		var left := float(_suspense["left"])
		var f := 1.0 - left / float(_suspense["total"])
		var beat := sin(left * TAU * lerpf(6.0, 22.0, f))
		var c: Color = _suspense["color"]
		c.a = 0.55 + 0.45 * absf(beat)
		var size := int(lerpf(18.0, 26.0, f))
		var at: Vector2 = _suspense["pos"]
		var width := _font.get_string_size("?", HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		draw_string(_font, at - Vector2(width * 0.5, 0.0), "?",
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, c)

	if _font:
		for t in _texts:
			var f := float(t["t"]) / float(t["life"])
			var c: Color = t["color"]
			c.a = 1.0 - f * f
			var pos: Vector2 = t["pos"] - Vector2(0.0, float(t["rise"]) * ease(f, 0.4))
			var size: int = t["size"]
			var width := _font.get_string_size(t["text"], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			draw_string(_font, pos - Vector2(width * 0.5, 0.0), t["text"],
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, c)

		if not _combo.is_empty():
			var f := float(_combo["t"]) / float(_combo["life"])
			# 100 ms of scale, then it fades.
			var grow := ease(minf(f / 0.25, 1.0), 0.3)
			var size := int(lerpf(20.0, 46.0, grow))
			var c := VOLT
			c.a = 1.0 - maxf(0.0, (f - 0.25) / 0.75)
			var text := str(_combo["value"])
			var width := FONT_COMBO.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
			var at := Vector2(screen_size.x * 0.5 - width * 0.5, screen_size.y * 0.42)
			draw_string(FONT_COMBO, at + Vector2(2.0, 3.0), text,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, VOLT.darkened(0.75))
			draw_string(FONT_COMBO, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, c)


func _draw_rotated_rect(at: Vector2, size: Vector2, rotation: float, color: Color) -> void:
	var half := size * 0.5
	var pts := PackedVector2Array([
		at + Vector2(-half.x, -half.y).rotated(rotation),
		at + Vector2(half.x, -half.y).rotated(rotation),
		at + Vector2(half.x, half.y).rotated(rotation),
		at + Vector2(-half.x, half.y).rotated(rotation),
	])
	draw_colored_polygon(pts, color)


func _draw_square_ring(at: Vector2, radius: float, color: Color) -> void:
	# A square ring. Round rings do not belong in this language.
	var t := 2.0
	draw_rect(Rect2(at.x - radius, at.y - radius, radius * 2.0, t), color)
	draw_rect(Rect2(at.x - radius, at.y + radius - t, radius * 2.0, t), color)
	draw_rect(Rect2(at.x - radius, at.y - radius, t, radius * 2.0), color)
	draw_rect(Rect2(at.x + radius - t, at.y - radius, t, radius * 2.0), color)
