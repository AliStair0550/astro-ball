class_name Cosmos
extends RefCounted

## The five universes, drawn rather than listed.
##
## A menu row with a name on it is a filing system. These are places: a
## belt of rock, a ringed world, a burning corona, a cloud, and a hole
## with a disc of light falling into it. Every one of them is procedural
## and costs a few dozen polygons, because the alternative is a texture
## atlas for five pictures nobody can edit.
##
## Shared by the universe list and the level chart, so the thing you
## pressed is the thing you are looking at afterwards.

const VOID := Color("07070C")
const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const ICE := Color("4DD8FF")
const PULSE := Color("B57BFF")
const FLARE := Color("FF9F1C")
const EMBER := Color("FF4D2E")
const SLATE := Color("888780")

## The colour each universe casts on everything around it.
const TINTS: Array[Color] = [
	Color("D6FF3D"), Color("4DD8FF"), Color("FF9F1C"), Color("B57BFF"), Color("FF4D2E"),
]


static func tint_of(index: int) -> Color:
	return TINTS[clampi(index, 0, TINTS.size() - 1)]


## A universe at a point. `lit` is how alive it is: an unreached one is
## still up there, just cold and still.
static func draw_body(ci: CanvasItem, index: int, at: Vector2, radius: float,
		lit: float, time: float) -> void:
	match index:
		0: _drift(ci, at, radius, lit, time)
		1: _rings(ci, at, radius, lit, time)
		2: _corona(ci, at, radius, lit, time)
		3: _nebula(ci, at, radius, lit, time)
		_: _hole(ci, at, radius, lit, time)


## Universe 1. A belt of rock and metal around a small dark world, seen
## edge on. It is the one the player is in, so it is the one that moves.
static func _drift(ci: CanvasItem, at: Vector2, r: float, lit: float, time: float) -> void:
	_glow(ci, at, r * 1.5, VOLT, 0.10 * lit)
	var core := Color("1C1C26").lerp(Color("2E2E22"), lit)
	ci.draw_circle(at, r * 0.42, core)
	var rim := VOLT
	rim.a = 0.30 * lit
	ci.draw_arc(at, r * 0.44, 0.0, TAU, 20, rim, 1.0, true)
	# Sixteen rocks on a flat ellipse, the near ones brighter.
	for i in 16:
		var a := time * 0.25 + TAU * float(i) / 16.0
		var p := at + Vector2(cos(a) * r, sin(a) * r * 0.30)
		var near := 0.5 + 0.5 * sin(a)
		var size := 1.4 + near * 2.0
		var c := SLATE.lerp(VOLT, 0.35 * lit)
		c.a = (0.25 + 0.65 * near) * (0.35 + 0.65 * lit)
		ci.draw_rect(Rect2(p - Vector2(size, size) * 0.5, Vector2(size, size)), c)


## Universe 2. A world with a ring plane, tilted, seen from inside it.
static func _rings(ci: CanvasItem, at: Vector2, r: float, lit: float, time: float) -> void:
	_glow(ci, at, r * 1.4, ICE, 0.10 * lit)
	for i in 3:
		var ring := ICE
		ring.a = (0.42 - float(i) * 0.11) * (0.3 + 0.7 * lit)
		_ellipse(ci, at, r * (0.95 + float(i) * 0.14), r * (0.24 + float(i) * 0.05),
			-0.22, ring, 1.0)
	var world := Color("15303C").lerp(ICE.darkened(0.4), lit)
	ci.draw_circle(at, r * 0.5, world)
	var lightside := ICE
	lightside.a = 0.5 * lit
	ci.draw_arc(at, r * 0.5, PI * 1.15, PI * 1.85, 16, lightside, 2.0, true)
	var shine := 0.6 + 0.4 * sin(time * 1.4)
	var spark := BONE
	spark.a = 0.5 * lit * shine
	ci.draw_circle(at + Vector2(-r * 0.2, -r * 0.22), 1.6, spark)


## Universe 3. A star with its corona out, and one arch standing off it.
static func _corona(ci: CanvasItem, at: Vector2, r: float, lit: float, time: float) -> void:
	_glow(ci, at, r * 1.7, FLARE, 0.13 * lit)
	var breath := 0.9 + 0.1 * sin(time * 1.1)
	for i in 3:
		var halo := FLARE.lerp(EMBER, float(i) / 3.0)
		halo.a = (0.30 - float(i) * 0.09) * (0.25 + 0.75 * lit)
		ci.draw_circle(at, r * (0.62 + float(i) * 0.22) * breath, halo)
	var disc := Color("3A2411").lerp(FLARE, 0.75 * lit)
	ci.draw_circle(at, r * 0.5, disc)
	# One prominence, always on the same side: the light comes from up
	# and to the left everywhere else in this game too.
	var arc_color := EMBER
	arc_color.a = 0.7 * lit
	ci.draw_arc(at + Vector2(-r * 0.55, -r * 0.4), r * 0.5, PI * 0.15, PI * 1.15, 14,
		arc_color, 2.0, true)


## Universe 4. Gas, and the suggestion of something inside it.
static func _nebula(ci: CanvasItem, at: Vector2, r: float, lit: float, time: float) -> void:
	_glow(ci, at, r * 1.8, PULSE, 0.12 * lit)
	var drift := sin(time * 0.4) * r * 0.08
	var blobs := [
		[Vector2(-0.34, -0.20), 0.72], [Vector2(0.30, 0.10), 0.62],
		[Vector2(-0.05, 0.34), 0.52], [Vector2(0.18, -0.34), 0.44],
	]
	for i in blobs.size():
		var offset: Vector2 = blobs[i][0]
		var size: float = blobs[i][1]
		var c := PULSE.lerp(ICE, 0.25 * float(i) / float(blobs.size()))
		c.a = (0.20 - 0.03 * float(i)) * (0.3 + 0.7 * lit)
		ci.draw_circle(at + offset * r + Vector2(drift, -drift * 0.5), r * size, c)
	# Three stars caught inside the cloud.
	for i in 3:
		var a := TAU * float(i) / 3.0 + time * 0.2
		var p := at + Vector2(cos(a), sin(a) * 0.7) * r * 0.34
		var s := BONE
		s.a = (0.5 + 0.4 * sin(time * 2.0 + float(i))) * lit
		ci.draw_circle(p, 1.5, s)


## Universe 5. Nothing, with everything falling into it.
static func _hole(ci: CanvasItem, at: Vector2, r: float, lit: float, time: float) -> void:
	_glow(ci, at, r * 1.5, EMBER, 0.10 * lit)
	for i in 3:
		var disc := EMBER.lerp(FLARE, float(i) / 3.0)
		disc.a = (0.55 - float(i) * 0.15) * (0.25 + 0.75 * lit)
		_ellipse(ci, at, r * (0.75 + float(i) * 0.16), r * (0.20 + float(i) * 0.06),
			0.18 + sin(time * 0.3) * 0.02, disc, 1.5)
	ci.draw_circle(at, r * 0.42, VOID)
	var edge := EMBER
	edge.a = 0.85 * lit
	ci.draw_arc(at, r * 0.44, 0.0, TAU, 24, edge, 1.5, true)


## A soft wash of colour, for putting a place behind a screen.
##
## Twenty steps with a squared falloff. Five with a straight one left
## visible rings, which reads as a target rather than as a cloud.
static func draw_wash(ci: CanvasItem, at: Vector2, radius: float, color: Color,
		strength: float) -> void:
	var steps := 20
	for i in steps:
		var t := float(i) / float(steps)
		var c := color
		c.a = strength * (1.0 - t) * (1.0 - t) * 0.55
		ci.draw_circle(at, radius * (0.16 + t * 0.9), c)


static func _glow(ci: CanvasItem, at: Vector2, radius: float, color: Color, strength: float) -> void:
	for i in 5:
		var t := float(i) / 5.0
		var c := color
		c.a = strength * (1.0 - t) * (1.0 - t)
		ci.draw_circle(at, radius * (0.45 + t * 0.75), c)


static func _ellipse(ci: CanvasItem, at: Vector2, rx: float, ry: float, tilt: float,
		color: Color, width: float) -> void:
	var points := PackedVector2Array()
	var steps := 40
	for i in steps + 1:
		var a := TAU * float(i) / float(steps)
		var p := Vector2(cos(a) * rx, sin(a) * ry).rotated(tilt)
		points.append(at + p)
	ci.draw_polyline(points, color, width, true)
