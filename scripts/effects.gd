class_name Effects
extends Node2D

## Lag 5: partikler, shockwaves, lysglimt og score-tal.
##
## Reglen fra afsnit 6: ingen effekt varer over 400 ms, og partikler er
## altid firkantede eller rektangulære, aldrig runde. Samme sprog som
## klodserne, så splinterne ser ud som stumper af det, der lige gik i stykker.

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
var _texts: Array[Dictionary] = []
var _rings: Array[Dictionary] = []
var _flashes: Array[Dictionary] = []
var _combo: Dictionary = {}
var _font: Font = FONT_SCORE


# --- Klodser -----------------------------------------------------------

## 5 til 8 splinter i klodsens farve, 40 til 90 px, roterer, falder med
## tyngde, væk efter 350 ms.
func brick_smashed(rect: Rect2, color: Color, count: int, glass := false) -> void:
	var center := rect.get_center()
	for i in count:
		var angle := randf() * TAU
		var speed := randf_range(40.0, 90.0)
		if glass:
			# Skår i vakuum: lettere, svæver længere, næsten ingen tyngde.
			speed = randf_range(30.0, 70.0)
		_bits.append({
			"kind": "splinter",
			"pos": center + Vector2(randf_range(-rect.size.x, rect.size.x), randf_range(-rect.size.y, rect.size.y)) * 0.4,
			"vel": Vector2(cos(angle), sin(angle)) * speed,
			"rot": randf() * TAU,
			"spin": randf_range(-9.0, 9.0),
			"size": Vector2(randf_range(1.0, 2.0), randf_range(3.0, 7.0)) if glass
				else Vector2(randf_range(2.0, 5.0), randf_range(2.0, 4.0)),
			"color": color,
			"gravity": 60.0 if glass else GRAVITY,
			"t": 0.0,
			"life": SHARD_LIFE if glass else SPLINTER_LIFE,
		})
	_flashes.append({"rect": rect, "color": Color.WHITE, "t": 0.0, "life": 0.017})


## Hærdet tager skade: 3 gnister, ingen splinter.
func brick_damaged(at: Vector2, color: Color) -> void:
	sparks(at, Vector2.UP, 3, color.lightened(0.4))


## Sprængklodsen: hvid flash over 3x3 felt, shockwave-ring til 80 px.
func blast(rect: Rect2, area: Rect2) -> void:
	_flashes.append({"rect": area, "color": Color.WHITE, "t": 0.0, "life": 0.034})
	shockwave(rect.get_center(), 80.0, EMBER)


func shockwave(at: Vector2, radius: float, color: Color) -> void:
	_rings.append({"pos": at, "radius": radius, "color": color, "t": 0.0, "life": SHOCKWAVE_LIFE})


func sparks(at: Vector2, dir: Vector2, count: int, color: Color) -> void:
	for i in count:
		var spread := dir.rotated(randf_range(-0.9, 0.9))
		_bits.append({
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
		})


func score_popup(at: Vector2, amount: int) -> void:
	_texts.append({
		"text": str(amount),
		"pos": at,
		"color": BONE,
		"size": 11,
		"t": 0.0,
		"life": SCORE_LIFE,
		"rise": 20.0,
	})


## Kombo 5, 10, 20: tallet stort midt på skærmen, 100 ms skalering, fader.
func combo(value: int) -> void:
	_combo = {"value": value, "t": 0.0, "life": COMBO_LIFE}


## Kometen splintrer i 20 stykker ved feltkanten og suges nedad.
func ball_lost(at: Vector2) -> void:
	for i in 20:
		var angle := randf_range(-PI, 0.0)
		_bits.append({
			"kind": "splinter",
			"pos": at + Vector2(randf_range(-4.0, 4.0), randf_range(-4.0, 4.0)),
			"vel": Vector2(cos(angle), sin(angle)) * randf_range(30.0, 110.0),
			"rot": randf() * TAU,
			"spin": randf_range(-12.0, 12.0),
			"size": Vector2(randf_range(1.0, 3.0), randf_range(1.0, 3.0)),
			"color": VOLT if i % 3 else BONE,
			# Suget nedad er kraftigere end almindelig tyngde.
			"gravity": 1500.0,
			"t": 0.0,
			"life": 0.4,
		})


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
	_bits.clear()
	_texts.clear()
	_rings.clear()
	_flashes.clear()
	_combo = {}


# --- Opdatering --------------------------------------------------------

func _process(delta: float) -> void:
	var i := _bits.size() - 1
	while i >= 0:
		var b := _bits[i]
		b["t"] += delta
		if b["t"] >= b["life"]:
			_bits.remove_at(i)
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
			# 100 ms skalering, så fader.
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
	# Firkantet ring. Runde ringe hører ikke til i det her formsprog.
	var t := 2.0
	draw_rect(Rect2(at.x - radius, at.y - radius, radius * 2.0, t), color)
	draw_rect(Rect2(at.x - radius, at.y + radius - t, radius * 2.0, t), color)
	draw_rect(Rect2(at.x - radius, at.y - radius, t, radius * 2.0), color)
	draw_rect(Rect2(at.x + radius - t, at.y - radius, t, radius * 2.0), color)
