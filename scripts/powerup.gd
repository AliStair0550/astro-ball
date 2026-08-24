class_name Powerup
extends Node2D

## Layer 4: the power-up capsule.
##
## 20x12 px, falling at 140 px/s. A rounded rectangle in the capsule's
## colour, a white rotating icon, a 6 px glow. Good ones have a light
## edge. Bad ones a dark edge and a zigzag, readable at 20 px.
##
## Version 1 of The Belt uses the nine power-ups levels 1 to 3 call for.
## The rest arrive at point 8 of the build order.
##
## These names are what the player reads in the dock and above the
## paddle. The design document's Danish names live in section 7.

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
		"name": "Wide", "color": VOLT, "kind": Kind.GOOD,
		"duration": 20.0, "icon": "arrows_out",
	},
	"multi": {
		"name": "Multi", "color": PULSE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "three_dots",
	},
	"fireball": {
		"name": "Fireball", "color": EMBER, "kind": Kind.GOOD,
		"duration": 12.0, "icon": "flame",
	},
	"laser": {
		"name": "Laser", "color": EMBER, "kind": Kind.GOOD,
		"duration": 15.0, "icon": "beams",
	},
	"slow": {
		"name": "Slow", "color": ICE, "kind": Kind.GOOD,
		"duration": 15.0, "icon": "turtle",
	},
	"life": {
		"name": "Life", "color": BONE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "heart",
	},
	"zap": {
		"name": "Zap", "color": VOLT, "kind": Kind.GOOD,
		"duration": 10.0, "icon": "bolt",
	},
	"narrow": {
		"name": "Narrow", "color": SLATE, "kind": Kind.BAD,
		"duration": 20.0, "icon": "arrows_in",
	},
	"fast": {
		"name": "Fast", "color": SLATE, "kind": Kind.BAD,
		"duration": 15.0, "icon": "arrows_up",
	},
}

var id := "wide"
var kill_y := 900.0

var _angle := 0.0
var _time := 0.0
## Set by the manager on pickup: the capsule implodes into the paddle.
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


## The capsule implodes into the paddle instead of simply vanishing.
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

	# A 6 px glow.
	var glow := color
	glow.a = 0.18 * (1.0 - _implode)
	draw_rect(Rect2(-half - Vector2(6.0, 6.0), (half + Vector2(6.0, 6.0)) * 2.0), glow)
	glow.a = 0.28 * (1.0 - _implode)
	draw_rect(Rect2(-half - Vector2(3.0, 3.0), (half + Vector2(3.0, 3.0)) * 2.0), glow)

	# Rounded rectangle: two rects offset by 1 px make the corner.
	var body := color
	body.a = 1.0 - _implode * 0.5
	draw_rect(Rect2(-half + Vector2(1.0, 0.0), Vector2(half.x * 2.0 - 2.0, half.y * 2.0)), body)
	draw_rect(Rect2(-half + Vector2(0.0, 1.0), Vector2(half.x * 2.0, half.y * 2.0 - 2.0)), body)

	# The edge tells you whether you want it.
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
	_icon_shapes(self, str(data["icon"]), ink)
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


## Draws the icon onto any canvas. The HUD dock uses the same drawing
## as the capsule, so an icon always means the same thing.
static func draw_icon_into(ci: CanvasItem, icon: String, at: Vector2, icon_scale: float, ink: Color) -> void:
	ci.draw_set_transform(at, 0.0, Vector2.ONE * icon_scale)
	_icon_shapes(ci, icon, ink)
	ci.draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


static func _icon_shapes(ci: CanvasItem, icon: String, ink: Color) -> void:
	match icon:
		"arrows_out":
			_bar(ci, Vector2(-1.0, -0.5), Vector2(2.0, 1.0), ink)
			_arrow(ci, Vector2(-4.0, 0.0), Vector2(-1.0, 0.0), ink)
			_arrow(ci, Vector2(4.0, 0.0), Vector2(1.0, 0.0), ink)
		"arrows_in":
			_bar(ci, Vector2(-1.0, -0.5), Vector2(2.0, 1.0), ink)
			_arrow(ci, Vector2(-2.0, 0.0), Vector2(1.0, 0.0), ink)
			_arrow(ci, Vector2(2.0, 0.0), Vector2(-1.0, 0.0), ink)
		"arrows_up":
			_arrow(ci, Vector2(-2.5, 1.0), Vector2(0.0, -1.0), ink)
			_arrow(ci, Vector2(2.5, 1.0), Vector2(0.0, -1.0), ink)
		"three_dots":
			_bar(ci, Vector2(-4.0, -1.0), Vector2(2.0, 2.0), ink)
			_bar(ci, Vector2(-1.0, -1.0), Vector2(2.0, 2.0), ink)
			_bar(ci, Vector2(2.0, -1.0), Vector2(2.0, 2.0), ink)
		"flame":
			_bar(ci, Vector2(-1.0, -4.0), Vector2(2.0, 3.0), ink)
			_bar(ci, Vector2(-2.0, -1.0), Vector2(4.0, 3.0), ink)
			_bar(ci, Vector2(-1.0, 2.0), Vector2(2.0, 2.0), ink)
		"beams":
			_bar(ci, Vector2(-3.0, -4.0), Vector2(2.0, 8.0), ink)
			_bar(ci, Vector2(1.0, -4.0), Vector2(2.0, 8.0), ink)
		"turtle":
			_bar(ci, Vector2(-4.0, -1.0), Vector2(8.0, 3.0), ink)
			_bar(ci, Vector2(-2.0, -3.0), Vector2(4.0, 2.0), ink)
			_bar(ci, Vector2(4.0, 0.0), Vector2(2.0, 2.0), ink)
			_bar(ci, Vector2(-5.0, 2.0), Vector2(2.0, 1.0), ink)
			_bar(ci, Vector2(3.0, 2.0), Vector2(2.0, 1.0), ink)
		"heart":
			_bar(ci, Vector2(-3.0, -3.0), Vector2(2.0, 2.0), ink)
			_bar(ci, Vector2(1.0, -3.0), Vector2(2.0, 2.0), ink)
			_bar(ci, Vector2(-4.0, -1.0), Vector2(8.0, 2.0), ink)
			_bar(ci, Vector2(-3.0, 1.0), Vector2(6.0, 1.0), ink)
			_bar(ci, Vector2(-1.0, 2.0), Vector2(2.0, 2.0), ink)
		"bolt":
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(1.0, -5.0), Vector2(-3.0, 1.0), Vector2(0.0, 1.0),
				Vector2(-1.0, 5.0), Vector2(3.0, -1.0), Vector2(0.0, -1.0),
			]), ink)
		_:
			_bar(ci, Vector2(-2.0, -2.0), Vector2(4.0, 4.0), ink)


static func _bar(ci: CanvasItem, at: Vector2, size: Vector2, ink: Color) -> void:
	ci.draw_rect(Rect2(at, size), ink)


static func _arrow(ci: CanvasItem, tip: Vector2, dir: Vector2, ink: Color) -> void:
	var side := Vector2(-dir.y, dir.x)
	ci.draw_colored_polygon(PackedVector2Array([
		tip,
		tip - dir * 3.0 + side * 2.5,
		tip - dir * 3.0 - side * 2.5,
	]), ink)
