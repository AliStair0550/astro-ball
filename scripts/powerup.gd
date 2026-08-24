class_name Powerup
extends Node2D

## Lag 4: power-up-kapslen.
##
## 20x12 px, falder med 140 px/s. Afrundet rektangel i kapslens farve,
## hvidt roterende ikon, 6 px glød. Gode har lys kant. Dårlige har mørk
## kant og en zigzag, så man kan se på 20 px afstand, om man vil have den.
##
## Version 1 af Bæltet bruger de ni power-ups, som level 1 til 3 kalder på.
## Resten kommer i punkt 8 af byggerækkefølgen.

signal collected(id: String)

enum Kind { GOOD, BAD, NEUTRAL }

const SIZE := Vector2(20.0, 12.0)
const FALL_SPEED := 140.0

const VOLT := Color("D6FF3D")
const ICE := Color("4DD8FF")
const PULSE := Color("B57BFF")
const FLARE := Color("FF9F1C")
const EMBER := Color("FF4D2E")
const BONE := Color("F2EFE6")
const SLATE := Color("888780")

const CATALOG := {
	"wide": {
		"name": "Bred", "color": VOLT, "kind": Kind.GOOD,
		"duration": 20.0, "icon": "arrows_out",
	},
	"multi": {
		"name": "Multi", "color": PULSE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "three_dots",
	},
	"fireball": {
		"name": "Ildkugle", "color": EMBER, "kind": Kind.GOOD,
		"duration": 12.0, "icon": "flame",
	},
	"laser": {
		"name": "Laser", "color": EMBER, "kind": Kind.GOOD,
		"duration": 15.0, "icon": "beams",
	},
	"slow": {
		"name": "Langsom", "color": ICE, "kind": Kind.GOOD,
		"duration": 15.0, "icon": "turtle",
	},
	"life": {
		"name": "Liv", "color": BONE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "heart",
	},
	"zap": {
		"name": "Zap", "color": VOLT, "kind": Kind.GOOD,
		"duration": 10.0, "icon": "bolt",
	},
	"narrow": {
		"name": "Smal", "color": SLATE, "kind": Kind.BAD,
		"duration": 20.0, "icon": "arrows_in",
	},
	"fast": {
		"name": "Hurtig", "color": SLATE, "kind": Kind.BAD,
		"duration": 15.0, "icon": "arrows_up",
	},
}

var id := "wide"
var kill_y := 900.0

var _angle := 0.0
var _time := 0.0
## Sat af manageren, når kapslen er samlet op: den imploderer mod paddlen.
var _implode := 0.0
var _implode_target := Vector2.ZERO


static func info(powerup_id: String) -> Dictionary:
	return CATALOG.get(powerup_id, CATALOG["wide"])


static func is_good(powerup_id: String) -> bool:
	return info(powerup_id)["kind"] == Kind.GOOD


func setup(powerup_id: String, at: Vector2, bottom: float) -> void:
	id = powerup_id
	position = at
	kill_y = bottom + SIZE.y


func rect() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)


## Kapslen imploderer til paddlen i stedet for bare at forsvinde.
func implode_to(target: Vector2) -> void:
	_implode_target = target
	_implode = 0.0001


func _process(delta: float) -> void:
	_time += delta
	_angle += delta * 2.2
	if _implode > 0.0:
		_implode = minf(1.0, _implode + delta * 8.0)
		position = position.lerp(_implode_target, 0.45)
		if _implode >= 1.0:
			queue_free()
	else:
		position.y += FALL_SPEED * delta
		if position.y > kill_y:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var data := info(id)
	var color: Color = data["color"]
	var good: bool = data["kind"] == Kind.GOOD
	var scale_factor := 1.0 - _implode * 0.7
	var half := SIZE * 0.5 * scale_factor

	# 6 px glød.
	var glow := color
	glow.a = 0.18 * (1.0 - _implode)
	draw_rect(Rect2(-half - Vector2(6.0, 6.0), (half + Vector2(6.0, 6.0)) * 2.0), glow)
	glow.a = 0.28 * (1.0 - _implode)
	draw_rect(Rect2(-half - Vector2(3.0, 3.0), (half + Vector2(3.0, 3.0)) * 2.0), glow)

	# Afrundet rektangel: to rektangler forskudt 1 px giver hjørnet.
	var body := color
	body.a = 1.0 - _implode * 0.5
	draw_rect(Rect2(-half + Vector2(1.0, 0.0), Vector2(half.x * 2.0 - 2.0, half.y * 2.0)), body)
	draw_rect(Rect2(-half + Vector2(0.0, 1.0), Vector2(half.x * 2.0, half.y * 2.0 - 2.0)), body)

	# Kanten fortæller, om man vil have den.
	var edge := color.lightened(0.55) if good else color.darkened(0.6)
	edge.a = body.a
	draw_rect(Rect2(-half + Vector2(1.0, 0.0), Vector2(half.x * 2.0 - 2.0, 1.0)), edge)
	draw_rect(Rect2(Vector2(-half.x + 1.0, half.y - 1.0), Vector2(half.x * 2.0 - 2.0, 1.0)), edge)
	draw_rect(Rect2(Vector2(-half.x, -half.y + 1.0), Vector2(1.0, half.y * 2.0 - 2.0)), edge)
	draw_rect(Rect2(Vector2(half.x - 1.0, -half.y + 1.0), Vector2(1.0, half.y * 2.0 - 2.0)), edge)

	if not good:
		_draw_zigzag(half, edge)

	var ink := Color.WHITE
	ink.a = body.a
	draw_set_transform(Vector2.ZERO, _angle, Vector2.ONE * scale_factor)
	_draw_icon(data["icon"], ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_zigzag(half: Vector2, edge: Color) -> void:
	var points := PackedVector2Array()
	var x := -half.x + 2.0
	var up := true
	while x <= half.x - 2.0:
		points.append(Vector2(x, half.y - 2.0 if up else half.y - 4.0))
		up = not up
		x += 2.0
	if points.size() >= 2:
		draw_polyline(points, edge, 1.0)


func _draw_icon(icon: String, ink: Color) -> void:
	match icon:
		"arrows_out":
			_bar(Vector2(-1.0, -0.5), Vector2(2.0, 1.0), ink)
			_arrow(Vector2(-4.0, 0.0), Vector2(-1.0, 0.0), ink)
			_arrow(Vector2(4.0, 0.0), Vector2(1.0, 0.0), ink)
		"arrows_in":
			_bar(Vector2(-1.0, -0.5), Vector2(2.0, 1.0), ink)
			_arrow(Vector2(-2.0, 0.0), Vector2(1.0, 0.0), ink)
			_arrow(Vector2(2.0, 0.0), Vector2(-1.0, 0.0), ink)
		"arrows_up":
			_arrow(Vector2(-2.5, 1.0), Vector2(0.0, -1.0), ink)
			_arrow(Vector2(2.5, 1.0), Vector2(0.0, -1.0), ink)
		"three_dots":
			_bar(Vector2(-4.0, -1.0), Vector2(2.0, 2.0), ink)
			_bar(Vector2(-1.0, -1.0), Vector2(2.0, 2.0), ink)
			_bar(Vector2(2.0, -1.0), Vector2(2.0, 2.0), ink)
		"flame":
			_bar(Vector2(-1.0, -4.0), Vector2(2.0, 3.0), ink)
			_bar(Vector2(-2.0, -1.0), Vector2(4.0, 3.0), ink)
			_bar(Vector2(-1.0, 2.0), Vector2(2.0, 2.0), ink)
		"beams":
			_bar(Vector2(-3.0, -4.0), Vector2(2.0, 8.0), ink)
			_bar(Vector2(1.0, -4.0), Vector2(2.0, 8.0), ink)
		"turtle":
			_bar(Vector2(-4.0, -1.0), Vector2(8.0, 3.0), ink)
			_bar(Vector2(-2.0, -3.0), Vector2(4.0, 2.0), ink)
			_bar(Vector2(4.0, 0.0), Vector2(2.0, 2.0), ink)
			_bar(Vector2(-5.0, 2.0), Vector2(2.0, 1.0), ink)
			_bar(Vector2(3.0, 2.0), Vector2(2.0, 1.0), ink)
		"heart":
			_bar(Vector2(-3.0, -3.0), Vector2(2.0, 2.0), ink)
			_bar(Vector2(1.0, -3.0), Vector2(2.0, 2.0), ink)
			_bar(Vector2(-4.0, -1.0), Vector2(8.0, 2.0), ink)
			_bar(Vector2(-3.0, 1.0), Vector2(6.0, 1.0), ink)
			_bar(Vector2(-1.0, 2.0), Vector2(2.0, 2.0), ink)
		"bolt":
			draw_colored_polygon(PackedVector2Array([
				Vector2(1.0, -5.0), Vector2(-3.0, 1.0), Vector2(0.0, 1.0),
				Vector2(-1.0, 5.0), Vector2(3.0, -1.0), Vector2(0.0, -1.0),
			]), ink)
		_:
			_bar(Vector2(-2.0, -2.0), Vector2(4.0, 4.0), ink)


func _bar(at: Vector2, size: Vector2, ink: Color) -> void:
	draw_rect(Rect2(at, size), ink)


func _arrow(tip: Vector2, dir: Vector2, ink: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	draw_colored_polygon(PackedVector2Array([
		tip,
		tip - dir * 3.0 + side * 2.5,
		tip - dir * 3.0 - side * 2.5,
	]), ink)
