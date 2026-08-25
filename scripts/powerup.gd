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
## Section 7: a bad capsule zigzags on the way down. It is not decoration
## on the capsule, it is the difference between a punishment you have to
## take and one you can step out of the way of.
const ZIGZAG_WIDTH := 26.0
const ZIGZAG_PERIOD := 0.85

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
	"magnet": {
		"name": "Magnet", "color": ICE, "kind": Kind.GOOD,
		"duration": 20.0, "icon": "magnet",
	},
	# No clock: it lasts until it saves you.
	"shield": {
		"name": "Shield", "color": VOLT, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "shield_line",
	},
	"splinter": {
		"name": "Splinter", "color": FLARE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "star",
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
	"blind": {
		"name": "Blind", "color": SLATE, "kind": Kind.BAD,
		"duration": 10.0, "icon": "closed_eye",
	},
	"invert": {
		"name": "Invert", "color": SLATE, "kind": Kind.BAD,
		"duration": 8.0, "icon": "mirror",
	},
	"heavy": {
		"name": "Heavy", "color": SLATE, "kind": Kind.BAD,
		"duration": 12.0, "icon": "anchor",
	},
	# Death is the one capsule that looks like nothing else: Ember with a
	# black edge. Section 7 keeps it out of the first five levels.
	"death": {
		"name": "Death", "color": EMBER, "kind": Kind.BAD,
		"duration": 0.0, "icon": "skull", "edge": Color("07070C"),
	},
	# Neutral: a grey edge, and no promise either way.
	"swap": {
		"name": "Swap", "color": PULSE, "kind": Kind.NEUTRAL,
		"duration": 0.0, "icon": "swap_arrows",
	},
	"lottery": {
		"name": "Lottery", "color": FLARE, "kind": Kind.NEUTRAL,
		"duration": 0.0, "icon": "question",
	},
	# The next brick the ball touches goes off like a blast brick. One
	# shot, aimed by hand, and the only power-up in the game that lets a
	# player put an explosion where they want one.
	# Flare, not Ember: the pulsing red glow belongs to the punishments
	# now, and a gift wearing the alarm colour undoes the whole signal.
	"bomb": {
		"name": "Bomb", "color": FLARE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "bomb",
	},
	# Points, straight up. Not everything has to change how the game
	# plays; some things are just worth catching.
	"bonus": {
		"name": "Bonus", "color": BONE, "kind": Kind.GOOD,
		"duration": 0.0, "icon": "coin",
	},
	# A smaller ball is a smaller target for the shield and a smaller
	# hammer for the wall.
	"shrink": {
		"name": "Shrink", "color": SLATE, "kind": Kind.BAD,
		"duration": 15.0, "icon": "small_circle",
	},
	# The ball leaves the shield within twelve degrees of where it
	# should. Not fast, not blind: unreliable.
	"wobble": {
		"name": "Wobble", "color": SLATE, "kind": Kind.BAD,
		"duration": 12.0, "icon": "wave",
	},
}

var id := "wide"
var kill_y := 900.0
## Where the capsule would be falling if it fell straight.
var _lane_x := 0.0

var _angle := 0.0
var _time := 0.0
## The snap. Within twelve pixels the capsule is caught rather than
## collided with: it is pulled into the paddle over forty milliseconds,
## which is the difference between a pickup and a hit test.
const SNAP_REACH := 12.0
const SNAP_TIME := 0.04

var _snap_from := Vector2.ZERO
var _snap_to := Vector2.ZERO
var _snap_t := -1.0

## Set by the manager on pickup: the capsule implodes into the paddle.
var _implode := 0.0
var _implode_target := Vector2.ZERO


static func info(powerup_id: String) -> Dictionary:
	return CATALOG.get(powerup_id, CATALOG["wide"])


static func is_good(powerup_id: String) -> bool:
	return info(powerup_id)["kind"] == Kind.GOOD


## Not the same question as "is it good". A neutral is neither, and the
## spawn rules have to be able to tell the difference: "never two bad in
## a row" must not be tripped by a coin flip.
static func is_bad(powerup_id: String) -> bool:
	return info(powerup_id)["kind"] == Kind.BAD


static func is_neutral(powerup_id: String) -> bool:
	return info(powerup_id)["kind"] == Kind.NEUTRAL


func setup(powerup_id: String, at: Vector2, bottom: float) -> void:
	id = powerup_id
	position = at
	_lane_x = at.x
	kill_y = bottom + SIZE.y


func rect() -> Rect2:
	return Rect2(position - SIZE * 0.5, SIZE)


## True once the capsule is being pulled in, so nothing else acts on it.
func is_snapping() -> bool:
	return _snap_t >= 0.0


## Begins the pull. Returns false if it was already being pulled, so a
## capsule cannot be caught twice.
func snap_to(target: Vector2) -> bool:
	if _snap_t >= 0.0:
		return false
	_snap_from = position
	_snap_to = target
	_snap_t = 0.0
	return true


## True when the pull has arrived.
func snap_done() -> bool:
	return _snap_t >= SNAP_TIME


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
		if _snap_t >= 0.0:
			_snap_t += delta
			position = _snap_from.lerp(_snap_to, ease(clampf(_snap_t / SNAP_TIME, 0.0, 1.0), 0.4))
			queue_redraw()
			return
		position.y += FALL_SPEED * delta
		if is_bad(id):
			# Kept inside the field: a capsule that swings off the edge
			# is one the paddle can never reach.
			var swing := sin(_time * TAU / ZIGZAG_PERIOD) * ZIGZAG_WIDTH
			position.x = clampf(_lane_x + swing, SIZE.x * 0.5 + 8.0, 390.0 - SIZE.x * 0.5 - 8.0)
		if position.y > kill_y:
			queue_free()
	queue_redraw()


func _draw() -> void:
	var data := info(id)
	var color: Color = data["color"]
	var kind: Kind = data["kind"]
	var good: bool = kind == Kind.GOOD
	var scale_factor := 1.0 - _implode * 0.7
	var half := SIZE * 0.5 * scale_factor

	# A glow, wider than before because the capsule is. A punishment's is
	# warm and beats: a light that flashes at you is a light that means
	# something is wrong, in every language.
	var glow := color
	var beat := 1.0
	if kind == Kind.BAD:
		glow = EMBER
		beat = 0.55 + 0.45 * sin(_time * 7.0)
	glow.a = 0.16 * (1.0 - _implode) * beat
	draw_rect(Rect2(-half - Vector2(8.0, 8.0), (half + Vector2(8.0, 8.0)) * 2.0), glow)
	glow.a = 0.26 * (1.0 - _implode) * beat
	draw_rect(Rect2(-half - Vector2(4.0, 4.0), (half + Vector2(4.0, 4.0)) * 2.0), glow)

	# The shape says which kind it is, before the colour or the icon does.
	# A gift is a rounded capsule; a punishment is cut off at the corners
	# like a hazard plate; a coin flip is a hexagon. On a phone, at
	# speed, silhouette is the only thing that reads in time.
	var body := color
	body.a = 1.0 - _implode * 0.5
	if kind == Kind.BAD:
		# Corners chamfered hard, and a red cast over the grey so it is
		# warm rather than neutral: this one is coming for you.
		var warn := color.lerp(EMBER, 0.42)
		warn.a = body.a
		draw_colored_polygon(PackedVector2Array([
			Vector2(-half.x + 6.0, -half.y), Vector2(half.x - 6.0, -half.y),
			Vector2(half.x, -half.y + 5.0), Vector2(half.x, half.y - 5.0),
			Vector2(half.x - 6.0, half.y), Vector2(-half.x + 6.0, half.y),
			Vector2(-half.x, half.y - 5.0), Vector2(-half.x, -half.y + 5.0),
		]), warn)
	elif kind == Kind.NEUTRAL:
		draw_colored_polygon(PackedVector2Array([
			Vector2(-half.x + 7.0, -half.y), Vector2(half.x - 7.0, -half.y),
			Vector2(half.x, 0.0), Vector2(half.x - 7.0, half.y),
			Vector2(-half.x + 7.0, half.y), Vector2(-half.x, 0.0),
		]), body)
	else:
		draw_rect(Rect2(-half + Vector2(2.0, 0.0), Vector2(half.x * 2.0 - 4.0, half.y * 2.0)), body)
		draw_rect(Rect2(-half + Vector2(0.0, 2.0), Vector2(half.x * 2.0, half.y * 2.0 - 4.0)), body)
	# A darker well behind the icon, so a white shape always has contrast
	# to sit against whatever colour the capsule is.
	var well := color.darkened(0.55)
	well.a = body.a
	draw_rect(Rect2(-half + Vector2(3.0, 3.0), (half - Vector2(3.0, 3.0)) * 2.0), well)

	# The edge tells you whether you want it. Three answers, not two:
	# light means yes, dark and jagged means no, grey means find out.
	var edge: Color = color.lightened(0.55)
	if kind == Kind.BAD:
		edge = color.darkened(0.6)
	elif kind == Kind.NEUTRAL:
		edge = SLATE
	if data.has("edge"):
		edge = data["edge"]
	edge.a = body.a
	var thickness := 2.0 if good else 1.0
	draw_rect(Rect2(-half + Vector2(2.0, 0.0), Vector2(half.x * 2.0 - 4.0, thickness)), edge)
	draw_rect(Rect2(Vector2(-half.x + 2.0, half.y - thickness), Vector2(half.x * 2.0 - 4.0, thickness)), edge)
	draw_rect(Rect2(Vector2(-half.x, -half.y + 2.0), Vector2(thickness, half.y * 2.0 - 4.0)), edge)
	draw_rect(Rect2(Vector2(half.x - thickness, -half.y + 2.0), Vector2(thickness, half.y * 2.0 - 4.0)), edge)

	if kind == Kind.BAD:
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
		"closed_eye":
			# A shut lid with three lashes. An open eye would read as
			# the opposite of what it does.
			ci.draw_line(Vector2(-5.0, 0.0), Vector2(5.0, 0.0), ink, 1.6)
			for x in [-3.0, 0.0, 3.0]:
				ci.draw_line(Vector2(x, 1.0), Vector2(x * 1.3, 4.0), ink, 1.2)
		"mirror":
			# Two arrows past each other, with the line they cross.
			_bar(ci, Vector2(-0.5, -5.0), Vector2(1.0, 10.0), ink)
			_arrow(ci, Vector2(-5.0, -2.5), Vector2(-1.0, 0.0), ink)
			_arrow(ci, Vector2(5.0, 2.5), Vector2(1.0, 0.0), ink)
		"anchor":
			_bar(ci, Vector2(-0.8, -4.0), Vector2(1.6, 8.0), ink)
			_bar(ci, Vector2(-3.0, -2.5), Vector2(6.0, 1.4), ink)
			ci.draw_arc(Vector2(0.0, 2.0), 4.0, 0.15 * PI, 0.85 * PI, 16, ink, 1.6, true)
		"big_circle":
			# A ring, not a disc: a filled circle at this size reads as a
			# blob, and the icon has to survive being 10 px wide.
			ci.draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 24, ink, 2.0, true)
			ci.draw_arc(Vector2.ZERO, 1.5, 0.0, TAU, 12, ink, 1.5, true)
		"magnet":
			# A horseshoe, open end down. The gap is the whole point.
			ci.draw_arc(Vector2(0.0, 1.0), 4.0, PI, TAU, 18, ink, 2.0, true)
			_bar(ci, Vector2(-5.0, 1.0), Vector2(2.0, 4.0), ink)
			_bar(ci, Vector2(3.0, 1.0), Vector2(2.0, 4.0), ink)
		"shield_line":
			# The line it puts under you, with the dome it makes.
			_bar(ci, Vector2(-5.0, 2.6), Vector2(10.0, 1.8), ink)
			ci.draw_arc(Vector2(0.0, 2.6), 4.6, PI, TAU, 18, ink, 1.6, true)
		"star":
			ci.draw_colored_polygon(PackedVector2Array([
				Vector2(0.0, -5.5), Vector2(1.5, -1.5), Vector2(5.5, 0.0),
				Vector2(1.5, 1.5), Vector2(0.0, 5.5), Vector2(-1.5, 1.5),
				Vector2(-5.5, 0.0), Vector2(-1.5, -1.5),
			]), ink)
		"skull":
			# The eyes are the gaps. One ink colour, so anything dark has
			# to be something the shape leaves out.
			_bar(ci, Vector2(-3.0, -5.0), Vector2(6.0, 2.0), ink)
			_bar(ci, Vector2(-4.0, -3.0), Vector2(8.0, 2.0), ink)
			_bar(ci, Vector2(-4.0, -1.0), Vector2(1.6, 2.0), ink)
			_bar(ci, Vector2(-1.0, -1.0), Vector2(2.0, 2.0), ink)
			_bar(ci, Vector2(2.4, -1.0), Vector2(1.6, 2.0), ink)
			_bar(ci, Vector2(-4.0, 1.0), Vector2(8.0, 1.6), ink)
			for x in [-2.5, -0.7, 1.1]:
				_bar(ci, Vector2(x, 2.6), Vector2(1.4, 2.0), ink)
		"swap_arrows":
			_bar(ci, Vector2(-3.0, -3.2), Vector2(6.0, 1.4), ink)
			_arrow(ci, Vector2(4.6, -2.5), Vector2(1.0, 0.0), ink)
			_bar(ci, Vector2(-3.0, 1.8), Vector2(6.0, 1.4), ink)
			_arrow(ci, Vector2(-4.6, 2.5), Vector2(-1.0, 0.0), ink)
		"question":
			ci.draw_arc(Vector2(0.0, -2.0), 3.0, PI, 2.3 * PI, 20, ink, 1.8, true)
			ci.draw_line(Vector2(1.4, 0.4), Vector2(0.2, 1.2), ink, 1.8)
			_bar(ci, Vector2(-0.9, 1.0), Vector2(1.8, 1.8), ink)
			_bar(ci, Vector2(-0.9, 3.6), Vector2(1.8, 1.8), ink)
		"bomb":
			ci.draw_arc(Vector2(0.0, 1.5), 4.2, 0.0, TAU, 20, ink, 2.0, true)
			_bar(ci, Vector2(-1.0, -5.0), Vector2(2.0, 2.0), ink)
			ci.draw_line(Vector2(0.0, -5.0), Vector2(3.5, -7.5), ink, 1.4)
			_bar(ci, Vector2(3.0, -8.5), Vector2(1.6, 1.6), ink)
		"coin":
			ci.draw_arc(Vector2.ZERO, 5.0, 0.0, TAU, 22, ink, 2.0, true)
			_bar(ci, Vector2(-0.8, -3.0), Vector2(1.6, 6.0), ink)
			_bar(ci, Vector2(-2.6, -1.6), Vector2(5.2, 1.4), ink)
		"small_circle":
			# A ring with a much smaller one inside: the same thing, less
			# of it, which is exactly what it does.
			ci.draw_arc(Vector2.ZERO, 5.5, 0.0, TAU, 22, ink, 1.2, true)
			ci.draw_circle(Vector2.ZERO, 2.0, ink)
		"wave":
			var points := PackedVector2Array()
			for i in 13:
				var t := -5.0 + float(i)
				points.append(Vector2(t, sin(t * 0.9) * 3.4))
			ci.draw_polyline(points, ink, 1.8)
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
