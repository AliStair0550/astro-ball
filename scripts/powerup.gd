class_name Powerup
extends Node2D

## Layer 4: the power-up capsule.
##
## 34x22 px, falling at 140 px/s. A rounded rectangle in the capsule's
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

## Bigger than the document's 20x12. On a phone a capsule has to say
## what it is from across the field, not once it is already caught.
const SIZE := Vector2(34.0, 22.0)
const ICON_SCALE := 1.45
const FALL_SPEED := 140.0

const LABEL_FONT := preload("res://assets/fonts/SpaceGrotesk-700.ttf")
const LABEL_SIZE := 9

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
	# Section 20. Doubles the ball and breaks Hardened in one hit.
	# Cannot run alongside Fireball: the last one caught wins.
	"giant": {
		"name": "Giant", "color": BONE, "kind": Kind.GOOD,
		"duration": 15.0, "icon": "big_circle",
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

	# A glow, wider than before because the capsule is.
	var glow := color
	glow.a = 0.16 * (1.0 - _implode)
	draw_rect(Rect2(-half - Vector2(8.0, 8.0), (half + Vector2(8.0, 8.0)) * 2.0), glow)
	glow.a = 0.26 * (1.0 - _implode)
	draw_rect(Rect2(-half - Vector2(4.0, 4.0), (half + Vector2(4.0, 4.0)) * 2.0), glow)

	# Rounded rectangle: two rects offset by 2 px make the corner.
	var body := color
	body.a = 1.0 - _implode * 0.5
	draw_rect(Rect2(-half + Vector2(2.0, 0.0), Vector2(half.x * 2.0 - 4.0, half.y * 2.0)), body)
	draw_rect(Rect2(-half + Vector2(0.0, 2.0), Vector2(half.x * 2.0, half.y * 2.0 - 4.0)), body)
	# A darker well behind the icon, so a white shape always has contrast
	# to sit against whatever colour the capsule is.
	var well := color.darkened(0.55)
	well.a = body.a
	draw_rect(Rect2(-half + Vector2(3.0, 3.0), (half - Vector2(3.0, 3.0)) * 2.0), well)

	# The edge tells you whether you want it.
	var edge := color.lightened(0.55) if good else color.darkened(0.6)
	edge.a = body.a
	var thickness := 2.0 if good else 1.0
	draw_rect(Rect2(-half + Vector2(2.0, 0.0), Vector2(half.x * 2.0 - 4.0, thickness)), edge)
	draw_rect(Rect2(Vector2(-half.x + 2.0, half.y - thickness), Vector2(half.x * 2.0 - 4.0, thickness)), edge)
	draw_rect(Rect2(Vector2(-half.x, -half.y + 2.0), Vector2(thickness, half.y * 2.0 - 4.0)), edge)
	draw_rect(Rect2(Vector2(half.x - thickness, -half.y + 2.0), Vector2(thickness, half.y * 2.0 - 4.0)), edge)

	if not good:
		_draw_zigzag(half, edge)

	var ink := Color.WHITE
	ink.a = body.a
	draw_set_transform(Vector2.ZERO, _angle, Vector2.ONE * scale_factor * ICON_SCALE)
	_icon_shapes(self, str(data["icon"]), ink)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)

	_draw_label(color, body.a)


## The name under the capsule. An icon says what kind of thing it is; the
## word says which one, and there is no learning it by trial at 140 px/s.
func _draw_label(color: Color, alpha: float) -> void:
	if _implode > 0.0:
		return
	var text := Strings.powerup_name(id)
	var width := 0.0
	for i in text.length():
		width += LABEL_FONT.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE).x + 0.8
	var at := Vector2(-width * 0.5, SIZE.y * 0.5 + 12.0)
	var shadow := Color("07070C")
	shadow.a = alpha * 0.8
	var ink := color.lightened(0.45)
	ink.a = alpha
	for pass_index in 2:
		var pen := at + (Vector2(1.0, 1.0) if pass_index == 0 else Vector2.ZERO)
		for i in text.length():
			var ch := text[i]
			draw_string(LABEL_FONT, pen, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE,
				shadow if pass_index == 0 else ink)
			pen.x += LABEL_FONT.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, LABEL_SIZE).x + 0.8


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
		"big_circle":
			# A ring, not a disc: a filled circle at this size reads as a
			# blob, and the icon has to survive being 10 px wide.
			ci.draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 24, ink, 2.0, true)
			ci.draw_arc(Vector2.ZERO, 1.5, 0.0, TAU, 12, ink, 1.5, true)
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
