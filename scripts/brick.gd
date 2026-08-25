class_name Brick
extends RefCounted

## Layer 3: one brick.
##
## A brick is data, not a node. The whole grid is drawn by brick_grid.gd
## in a single _draw, so 140 bricks do not become 140 nodes.
##
## The anatomy from section 3 has five elements, and all five are always
## present:
##   1 top line, 1 px, +20 per cent luminance
##   2 base, the material colour, flat
##   3 inner texture, 2 to 3 px, opacity 0.12
##   4 core light, 6x3 px, top left
##   5 bottom line, 1 px, -30 per cent luminance
##
## The core light is the fiction's light: the distant sun strikes the
## field from above and to the left. Same direction in all five zones.

enum Type { VOLT, ICE, PULSE, FLARE, HARDENED, STONE, BLAST, GLASS, SPARK, HIDDEN }

## Version 2 of the anatomy, replacing section 3's five elements. The
## brick sits back at 86 per cent so the bevel has room to go both ways,
## and the bevel is four mitred trapezoids: light on the top and left,
## dark on the right and bottom, joining at the corners like tiles.
const BASE_LUM := 0.86
const BEVEL := 2.0
## top, left, right, bottom.
const NORMAL_BEVEL := [1.45, 1.25, 0.60, 0.50]
## Stone keeps 40 per cent of the lift and 70 per cent of the drop: a
## shallow bevel with almost no light in it, which is what dead looks
## like next to eleven bricks that are lit.
const STONE_BEVEL := [1.18, 1.10, 0.72, 0.65]
const GLOSS_WIDTH := 0.55
## The pressure wave. Sixty milliseconds of Flare before the brick goes.
const WASH_TIME := 0.06

const SIZE := Vector2(24.0, 16.0)

const SYMBOLS := {
	"V": Type.VOLT,
	"I": Type.ICE,
	"P": Type.PULSE,
	"F": Type.FLARE,
	"H": Type.HARDENED,
	"S": Type.STONE,
	"E": Type.BLAST,
	"G": Type.GLASS,
	"X": Type.SPARK,
	"?": Type.HIDDEN,
}

## hits = -1 means unbreakable. The Danish names from section 3 are kept
const DATA := {
	Type.VOLT: {
		"name": "Volt", "color": Color("D6FF3D"), "hits": 1, "score": 100,
		"powerup": 0.15, "shards": 6,
	},
	Type.ICE: {
		"name": "Ice", "color": Color("4DD8FF"), "hits": 1, "score": 100,
		"powerup": 0.10, "shards": 6,
	},
	Type.PULSE: {
		"name": "Pulse", "color": Color("B57BFF"), "hits": 1, "score": 200,
		"powerup": 0.0, "shards": 7,
	},
	Type.FLARE: {
		"name": "Flare", "color": Color("FF9F1C"), "hits": 1, "score": 100,
		"powerup": 0.20, "shards": 6,
	},
	Type.HARDENED: {
		"name": "Hardened", "color": Color("888780"), "hits": 3, "score": 300,
		"powerup": 0.0, "shards": 8,
	},
	Type.STONE: {
		"name": "Sten", "color": Color("F2EFE6"), "hits": -1, "score": 0,
		"powerup": 0.0, "shards": 0,
	},
	Type.BLAST: {
		"name": "Blast", "color": Color("FF4D2E"), "hits": 1, "score": 100,
		"powerup": 0.0, "shards": 8,
	},
	Type.GLASS: {
		"name": "Glas", "color": Color("4DD8FF"), "hits": 1, "score": 100,
		"powerup": 0.0, "shards": 12,
	},
	Type.SPARK: {
		"name": "Gnist", "color": Color("D6FF3D"), "hits": 1, "score": 100,
		"powerup": 1.0, "shards": 7,
	},
	Type.HIDDEN: {
		"name": "Hidden", "color": Color("F2EFE6"), "hits": 1, "score": 100,
		"powerup": 0.0, "shards": 6,
	},
}

var type: Type = Type.VOLT
var col := 0
var row := 0
var rect := Rect2()

var hits_left := 1
var alive := true
## Hidden bricks are invisible until a neighbour breaks.
var revealed := true

## A short white flash on contact, one frame.
var flash := 0.0
## Hardened shakes 2 px when it takes damage.
var shake := 0.0
## The blast brick glows when the ball is near.
var proximity := 0.0
## Phase: the pressure wave. A brick queued into a chain washes orange
## for 60 ms before it goes, so the cascade reads as something eating
## through the wall rather than a set of bricks vanishing in order.
var wash := 0.0
## Where the chain that is coming for this brick started. INF when the
## brick was not taken by one.
var chain_from := Vector2.INF
## Fixed per brick, so cracks and texture do not flicker between frames.
var seed_value := 0


func _init(brick_type: Type, at_col: int, at_row: int, at_rect: Rect2) -> void:
	type = brick_type
	col = at_col
	row = at_row
	rect = at_rect
	hits_left = DATA[type]["hits"]
	revealed = type != Type.HIDDEN
	seed_value = at_col * 73856093 + at_row * 19349663


func color() -> Color:
	return DATA[type]["color"]


func score_value() -> int:
	return DATA[type]["score"]


func powerup_chance() -> float:
	return DATA[type]["powerup"]


func shard_count() -> int:
	return DATA[type]["shards"]


func is_breakable() -> bool:
	return DATA[type]["hits"] > 0


## Glass lets the ball through. The brick breaks all the same.
func lets_ball_pass() -> bool:
	return type == Type.GLASS


func counts_toward_clear() -> bool:
	return is_breakable()


## Returns true if this hit broke the brick.
func take_hit(damage := 1) -> bool:
	flash = 1.0
	if not is_breakable():
		return false
	hits_left -= damage
	if hits_left <= 0:
		alive = false
		return true
	shake = 1.0
	return false


## 0 = untouched, 1 = hit once, 2 = hit twice.
func damage_stage() -> int:
	var total: int = DATA[type]["hits"]
	if total <= 1:
		return 0
	return total - hits_left


func _rand(salt: int) -> float:
	# Deterministic noise per brick. The same cracks every frame.
	var n := (seed_value + salt * 374761393) & 0x7FFFFFFF
	n = (n ^ (n >> 13)) * 1274126177
	return float((n ^ (n >> 16)) & 0xFFFF) / 65535.0


# --- Drawing -----------------------------------------------------------

func draw_into(ci: CanvasItem, time: float, blind := false, flat := false) -> void:
	if not alive:
		return

	var base := color()
	var r := rect

	if type == Type.HIDDEN and not revealed:
		# A faint silhouette at 5 per cent, flickering every 4 seconds.
		var ghost := base
		var blink := 1.0 if fposmod(time + _rand(3) * 4.0, 4.0) > 3.85 else 0.0
		ghost.a = 0.05 + blink * 0.10
		ci.draw_rect(r, ghost)
		return

	if shake > 0.0:
		r.position.x += (_rand(11) - 0.5) * 4.0 * shake

	if blind:
		# Blind mode in later levels shows only the edges.
		var edge := base
		edge.a = 0.55
		ci.draw_rect(r, edge, false, 1.0)
		return

	var stage := damage_stage()

	# 1. Base, sat back from the full colour so the bevel has somewhere
	#    to go in both directions.
	var body := _lum(base, BASE_LUM)
	if type == Type.GLASS:
		body.a = 0.4
	ci.draw_rect(r, body)

	# 2. Inner texture, on the base and under everything else.
	_draw_texture(ci, r, base, time)

	if flat:
		# Version one, for the feel lab's side by side: a light line on
		# top and a dark one underneath, and nothing else.
		if type != Type.STONE:
			ci.draw_rect(Rect2(r.position, Vector2(r.size.x, 1.0)), base.lightened(0.2))
		ci.draw_rect(Rect2(r.position + Vector2(0.0, r.size.y - 1.0),
			Vector2(r.size.x, 1.0)), base.darkened(0.3))
	else:
		# 3. The bevel. Four mitred trapezoids, so a wall of them joins
		#    at the corners the way tiles do rather than crossing.
		_draw_bevel(ci, r, base, stage)

		# 4. Gloss. Not on Stone, which has to keep reading as dead.
		if type != Type.STONE and not (type == Type.GLASS and stage > 0):
			_draw_gloss(ci, r)

	# 5. Core light. It goes out the moment the brick takes damage.
	if stage == 0 and type != Type.STONE:
		_draw_core_light(ci, r, base, time)

	_draw_signature(ci, r, base, time)

	if stage >= 1:
		_draw_cracks(ci, r, stage)
	if stage >= 2:
		_draw_missing_pieces(ci, r)
		# Flickers once a second.
		if fposmod(time + _rand(7), 1.0) > 0.92:
			var f := Color.WHITE
			f.a = 0.18
			ci.draw_rect(r, f)

	if wash > 0.0:
		# The pressure wave arriving, a breath before the brick goes.
		var heat := Color("FF9F1C")
		heat.a = 0.62 * wash
		ci.draw_rect(r, heat)

	if flash > 0.0:
		var white := Color.WHITE
		white.a = flash
		ci.draw_rect(r, white)


## The bevel, as four mitred trapezoids. Each edge tapers 45 degrees at
## both ends, so the light top meets the light left along the diagonal
## and the dark right meets the dark bottom along the other one. Drawn
## as polygons rather than rectangles for exactly that reason: stacked
## rectangles cross at the corners and read as a picture frame.
func _draw_bevel(ci: CanvasItem, r: Rect2, base: Color, stage: int) -> void:
	var b := BEVEL
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	var mult := STONE_BEVEL if type == Type.STONE else NORMAL_BEVEL
	var alpha := 1.0 if type != Type.GLASS else 0.55

	# Stage 2 takes the corners off, so the mitres stop short.
	var chip := 0.0 if stage < 2 else 3.0

	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x + chip, y), Vector2(x + w - chip, y),
		Vector2(x + w - b, y + b), Vector2(x + b, y + b),
	]), _edge(base, float(mult[0]), alpha))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x, y + chip), Vector2(x + b, y + b),
		Vector2(x + b, y + h - b), Vector2(x, y + h - chip),
	]), _edge(base, float(mult[1]), alpha))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x + w, y + chip), Vector2(x + w, y + h - chip),
		Vector2(x + w - b, y + h - b), Vector2(x + w - b, y + b),
	]), _edge(base, float(mult[2]), alpha))
	ci.draw_colored_polygon(PackedVector2Array([
		Vector2(x + chip, y + h), Vector2(x + b, y + h - b),
		Vector2(x + w - b, y + h - b), Vector2(x + w - chip, y + h),
	]), _edge(base, float(mult[3]), alpha))


## The trapezoid for one edge, so a test can check the mitre without
## reading pixels. 0 top, 1 left, 2 right, 3 bottom.
static func bevel_polygon(r: Rect2, edge: int, chip := 0.0) -> PackedVector2Array:
	var b := BEVEL
	var x := r.position.x
	var y := r.position.y
	var w := r.size.x
	var h := r.size.y
	match edge:
		0:
			return PackedVector2Array([Vector2(x + chip, y), Vector2(x + w - chip, y),
				Vector2(x + w - b, y + b), Vector2(x + b, y + b)])
		1:
			return PackedVector2Array([Vector2(x, y + chip), Vector2(x + b, y + b),
				Vector2(x + b, y + h - b), Vector2(x, y + h - chip)])
		2:
			return PackedVector2Array([Vector2(x + w, y + chip), Vector2(x + w, y + h - chip),
				Vector2(x + w - b, y + h - b), Vector2(x + w - b, y + b)])
		_:
			return PackedVector2Array([Vector2(x + chip, y + h), Vector2(x + b, y + h - b),
				Vector2(x + w - b, y + h - b), Vector2(x + w - chip, y + h)])


## A rounded stripe of light in the upper left, and a fainter one under
## it. It is what makes a flat rectangle look like something with a
## surface, and it is the whole difference between this and version one.
func _draw_gloss(ci: CanvasItem, r: Rect2) -> void:
	var white := Color.WHITE
	var x := r.position.x + BEVEL + 1.0
	var top := r.position.y + BEVEL + 1.0
	var width := (r.size.x - BEVEL * 2.0 - 2.0) * GLOSS_WIDTH
	white.a = 0.5
	_stripe(ci, Vector2(x, top), width, 2.0, white)
	white.a = 0.25
	_stripe(ci, Vector2(x + 1.0, top + 3.0), width * 0.72, 1.0, white)


## A stripe with its ends taken off, so it reads as rounded at this size
## without costing an arc.
static func _stripe(ci: CanvasItem, at: Vector2, width: float, height: float, color: Color) -> void:
	if width <= 2.0:
		return
	ci.draw_rect(Rect2(at + Vector2(1.0, 0.0), Vector2(width - 2.0, height)), color)
	var faded := color
	faded.a = color.a * 0.55
	ci.draw_rect(Rect2(at, Vector2(1.0, height)), faded)
	ci.draw_rect(Rect2(at + Vector2(width - 1.0, 0.0), Vector2(1.0, height)), faded)


## A luminance multiplier on a colour: over one lightens, under one
## darkens, and the alpha is left alone.
static func _lum(c: Color, factor: float) -> Color:
	return Color(minf(c.r * factor, 1.0), minf(c.g * factor, 1.0), minf(c.b * factor, 1.0), c.a)


func _edge(base: Color, factor: float, alpha: float) -> Color:
	var c := _lum(base, factor)
	c.a = alpha
	return c


func _draw_texture(ci: CanvasItem, r: Rect2, base: Color, time := 0.0) -> void:
	var grain := base.darkened(0.55)
	grain.a = 0.12
	match type:
		Type.ICE, Type.GLASS:
			# A faint diagonal frost.
			for i in 5:
				var x := r.position.x + 2.0 + float(i) * 5.0
				ci.draw_line(Vector2(x, r.end.y - 2.0), Vector2(x + 5.0, r.position.y + 2.0), grain, 1.0)
		Type.FLARE:
			# A warm little spark texture.
			for i in 6:
				var p := r.position + Vector2(2.0 + _rand(20 + i) * 20.0, 2.0 + _rand(40 + i) * 12.0)
				ci.draw_rect(Rect2(p.floor(), Vector2(2.0, 2.0)), grain)
		Type.HARDENED:
			# Dark rock with metal rivets in the corners.
			for i in 7:
				var p := r.position + Vector2(2.0 + _rand(60 + i) * 20.0, 3.0 + _rand(80 + i) * 10.0)
				ci.draw_rect(Rect2(p.floor(), Vector2(3.0, 2.0)), grain)
			var rivet := base.lightened(0.35)
			for corner in [Vector2(2.0, 2.0), Vector2(r.size.x - 4.0, 2.0),
					Vector2(2.0, r.size.y - 4.0), Vector2(r.size.x - 4.0, r.size.y - 4.0)]:
				ci.draw_rect(Rect2(r.position + corner, Vector2(2.0, 2.0)), rivet)
		Type.STONE:
			# Asteroid core. Matte, heavy, lifeless.
			var pit := base.darkened(0.45)
			pit.a = 0.35
			for i in 8:
				var p := r.position + Vector2(1.0 + _rand(100 + i) * 21.0, 1.0 + _rand(120 + i) * 13.0)
				ci.draw_rect(Rect2(p.floor(), Vector2(3.0, 2.0)), pit)
		Type.BLAST:
			# Lit, always. DX-Ball's explosive brick is the one you can
			# pick out of a full wall without looking for it, and a dark
			# core that only wakes when the ball is near cannot do that:
			# the brick has to say what it does before you aim at it.
			var middle := r.position + r.size * 0.5
			var breath := 0.62 + 0.38 * (0.5 + 0.5 * sin(time * 3.4 + _rand(5) * TAU))
			var heat := 0.55 + 0.45 * proximity

			# A hot wash over the whole face, so it reads orange rather
			# than red at arm's length.
			var wash_c := Color("FF9F1C")
			wash_c.a = 0.30 * breath * heat
			ci.draw_rect(r.grow(-2.0), wash_c)

			# The burst: four spokes out of the middle. It is the mark
			# that says this one takes the others with it.
			var spoke := Color("FFC65C")
			spoke.a = (0.5 + 0.4 * proximity) * breath
			ci.draw_rect(Rect2(middle - Vector2(8.0, 1.0), Vector2(16.0, 2.0)), spoke)
			ci.draw_rect(Rect2(middle - Vector2(1.0, 5.0), Vector2(2.0, 10.0)), spoke)
			spoke.a *= 0.7
			for corner in [Vector2(-1.0, -1.0), Vector2(1.0, -1.0),
					Vector2(-1.0, 1.0), Vector2(1.0, 1.0)]:
				for step in 3:
					var at: Vector2 = middle + corner * (3.0 + float(step) * 2.0)
					ci.draw_rect(Rect2(at - Vector2(1.0, 1.0), Vector2(2.0, 2.0)), spoke)

			# And the core, white hot, brighter the closer the ball is.
			var core := Color("FFE7C2")
			core.a = (0.55 + 0.45 * proximity) * breath
			ci.draw_rect(Rect2(middle - Vector2(3.0, 2.0), Vector2(6.0, 4.0)), core)
		_:
			for i in 5:
				var p := r.position + Vector2(2.0 + _rand(140 + i) * 20.0, 2.0 + _rand(160 + i) * 12.0)
				ci.draw_rect(Rect2(p.floor(), Vector2(3.0, 2.0)), grain)


func _draw_core_light(ci: CanvasItem, r: Rect2, base: Color, time: float) -> void:
	var light := base.lightened(0.45)
	light.a = 0.9
	if type == Type.PULSE:
		# The core light pulses slowly.
		light.a = 0.45 + 0.45 * (0.5 + 0.5 * sin(time * 2.2 + _rand(9) * TAU))
	ci.draw_rect(Rect2(r.position + Vector2(2.0, 2.0), Vector2(6.0, 3.0)), light)


func _draw_signature(ci: CanvasItem, r: Rect2, _base: Color, time: float) -> void:
	if type != Type.SPARK:
		return
	# A white edge rotating around the brick.
	var perimeter := 2.0 * (r.size.x + r.size.y)
	var head := fposmod(time * 46.0, perimeter)
	var white := Color.WHITE
	for i in 12:
		var d := fposmod(head - float(i) * 2.0, perimeter)
		var p := _perimeter_point(r, d)
		white.a = 0.95 - float(i) * 0.07
		ci.draw_rect(Rect2(p.floor(), Vector2(2.0, 1.0) if d < r.size.x or (d >= r.size.x + r.size.y and d < 2.0 * r.size.x + r.size.y) else Vector2(1.0, 2.0)), white)


static func _perimeter_point(r: Rect2, d: float) -> Vector2:
	var w := r.size.x
	var h := r.size.y
	if d < w:
		return r.position + Vector2(d, 0.0)
	d -= w
	if d < h:
		return r.position + Vector2(w - 1.0, d)
	d -= h
	if d < w:
		return r.position + Vector2(w - d, h - 1.0)
	d -= w
	return r.position + Vector2(0.0, h - d)


## Cracks run out through the bevel and off the edge of the brick, so a
## damaged one looks broken rather than decorated. They are drawn after
## the bevel for exactly that reason.
func _draw_cracks(ci: CanvasItem, r: Rect2, stage: int) -> void:
	var dark := Color("07070C")
	dark.a = 0.85
	# Stage 1: two cracks from the edge. Stage 2: they cross the middle.
	var reach := 0.45 if stage == 1 else 1.0
	var mid := r.position + r.size * 0.5
	for i in 2:
		var start := r.position + Vector2(
			_rand(200 + i) * r.size.x,
			0.0 if i == 0 else r.size.y - 1.0)
		var target := mid + Vector2((_rand(220 + i) - 0.5) * 10.0, 0.0)
		var end_point := start.lerp(target, reach) if stage == 1 else start + (target - start) * 1.9
		var bend := start.lerp(end_point, 0.5) + Vector2((_rand(240 + i) - 0.5) * 6.0, 0.0)
		ci.draw_line(start, bend, dark, 1.0)
		ci.draw_line(bend, end_point, dark, 1.0)


func _draw_missing_pieces(ci: CanvasItem, r: Rect2) -> void:
	# Three small pieces missing from the edge.
	var hole := Color("07070C")
	for i in 3:
		var along := _rand(260 + i)
		var p: Vector2
		if i == 0:
			p = Vector2(r.position.x + along * (r.size.x - 3.0), r.position.y)
		elif i == 1:
			p = Vector2(r.position.x + along * (r.size.x - 3.0), r.end.y - 3.0)
		else:
			p = Vector2(r.position.x if along < 0.5 else r.end.x - 3.0,
				r.position.y + _rand(280) * (r.size.y - 3.0))
		ci.draw_rect(Rect2(p.floor(), Vector2(3.0, 3.0)), hole)


func update(delta: float) -> void:
	if flash > 0.0:
		flash = maxf(0.0, flash - delta * 20.0)
	if shake > 0.0:
		shake = maxf(0.0, shake - delta * 8.0)
	if wash > 0.0:
		wash = maxf(0.0, wash - delta / WASH_TIME)
