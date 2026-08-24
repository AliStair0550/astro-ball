class_name StarMap
extends Node2D

## Section 15: the level select is a star chart, not a list.
##
## Every field in the zone is a star. The ones you have cleared are lit,
## and how brightly says how many of the three you took. The lines are
## not drawn until the whole zone is done: that is the moment the twelve
## scattered points become a constellation, and it is worth waiting for.
##
## The Drift's constellation is a comet. The tail runs from the bottom
## left, where you started, up and to the right, and ends in a head of
## three stars with a nucleus inside it. The nucleus is The Core. You are
## the comet, and the chart is the flight you made.
##
## The path never doubles back, and no line passes closer to a third
## star than a thumb is wide. Both are asserted, because a chart you can
## press the wrong field on is worse than a list.

signal chosen(index: int)
signal action(name: String)

const FONT_BRAND := preload("res://assets/fonts/Unbounded-900.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Unbounded-700.ttf")
const FONT_SCORE := preload("res://assets/fonts/SpaceGrotesk-700.ttf")
const FONT_UI := preload("res://assets/fonts/SpaceGrotesk-500.ttf")

const VOID := Color("07070C")
const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const PULSE := Color("B57BFF")
const ICE := Color("4DD8FF")
const SLATE := Color("888780")
const EDGE := Color("2A2A3A")

## Where each field sits in the sky. Twelve points, in play order: the
## tail sweeps up from the bottom left and ends in a head with The Core
## at its centre. Nothing here is generated, because a constellation
## that moves is not a constellation.
const NODES: Array[Vector2] = [
	Vector2(62.0, 640.0),
	Vector2(112.0, 612.0),
	Vector2(92.0, 552.0),
	Vector2(154.0, 570.0),
	Vector2(206.0, 534.0),
	Vector2(168.0, 478.0),
	Vector2(232.0, 462.0),
	Vector2(286.0, 428.0),
	Vector2(312.0, 372.0),
	Vector2(216.0, 330.0),
	Vector2(300.0, 250.0),
	Vector2(276.0, 320.0),
]

## The lines of the finished figure, drawn in this order. The tail first,
## then the head, then the three spokes that hang the nucleus in it.
const EDGES: Array[Vector2i] = [
	Vector2i(0, 1), Vector2i(1, 2), Vector2i(2, 3), Vector2i(3, 4),
	Vector2i(4, 5), Vector2i(5, 6), Vector2i(6, 7), Vector2i(7, 8),
	Vector2i(8, 9), Vector2i(9, 10), Vector2i(10, 8),
	Vector2i(8, 11), Vector2i(9, 11), Vector2i(10, 11),
]

## A finger is not a cursor. Nothing is closer together than 58 px, so a
## 26 px reach never lands on two fields at once.
const TOUCH_RADIUS := 26.0
const LINE_DRAW_TIME := 0.28

var screen_size := Vector2(390.0, 844.0)
var zone_slug := "baeltet"
## Filled by the game: one entry per field, in order.
var fields: Array[Dictionary] = []
## The field the caption is talking about. -1 is none.
var focus := -1
## Runs the constellation on, one line at a time, when the zone is done.
var reveal := 0.0

## The level the player is meant to press next: the first still standing.
var next_index := 0

const CHART := Rect2(18.0, 182.0, 354.0, 486.0)

var _buttons: Array[Dictionary] = []
var _time := 0.0
var _fade := 0.0
var _hover := -1
var _lines_drawn := 0
var _touch_seen := false


func _ready() -> void:
	set_process_unhandled_input(true)
	visible = false


## Called by the game every time the chart is opened.
func open(level_data: Array, start_at: int, celebrate: bool) -> void:
	fields.clear()
	for entry in level_data:
		fields.append(entry)
	next_index = clampi(start_at, 0, maxi(level_data.size() - 1, 0))
	focus = next_index
	_time = 0.0
	_fade = 0.0
	_hover = -1
	_lines_drawn = 0
	# The constellation is only ever drawn once it is whole. Coming
	# straight from the last field, it draws itself while you watch.
	reveal = 0.0 if celebrate else (1.0 if is_zone_complete() else 0.0)
	_layout()
	visible = true
	queue_redraw()


func close() -> void:
	visible = false
	queue_redraw()


func is_zone_complete() -> bool:
	if fields.is_empty():
		return false
	for entry in fields:
		if not bool(entry.get("cleared", false)):
			return false
	return true


## Section 15: a field opens when the one before it has been cleared.
## The first is always open, so a new player has somewhere to press.
static func unlocked_in(entries: Array, index: int) -> bool:
	if index <= 0:
		return true
	if index >= entries.size():
		return false
	return bool(entries[index - 1].get("cleared", false))


func unlocked(index: int) -> bool:
	return unlocked_in(fields, index)


func node_position(index: int) -> Vector2:
	if index < 0 or index >= NODES.size():
		return Vector2.ZERO
	return NODES[index]


## Which field a press at this point lands on, or -1.
func field_at(point: Vector2) -> int:
	var best := -1
	var best_distance := TOUCH_RADIUS
	for i in mini(fields.size(), NODES.size()):
		var d := point.distance_to(NODES[i])
		if d <= best_distance:
			best_distance = d
			best = i
	return best


func _layout() -> void:
	_buttons.clear()
	# The caption is a button. It names a level and sits under the thumb,
	# so pressing it has to start that level: a label that reads like a
	# choice and does nothing is worse than no label.
	_buttons.append({
		"id": "start",
		"label": Strings.text("BTN_START"),
		"rect": Rect2(24.0, 686.0, screen_size.x - 48.0, 58.0),
		"tint": VOLT,
	})
	_buttons.append({
		"id": "back",
		"label": Strings.text("BTN_BACK"),
		"rect": Rect2(screen_size.x * 0.5 - 90.0, 762.0, 180.0, 42.0),
		"tint": SLATE,
	})


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_fade = minf(1.0, _fade + delta * 6.0)

	if reveal < 1.0 and is_zone_complete():
		# A beat of stillness first, then the figure draws itself.
		if _time > 1.1:
			reveal = minf(1.0, reveal + delta / (LINE_DRAW_TIME * float(EDGES.size())))
		var drawn := int(reveal * float(EDGES.size()))
		if drawn > _lines_drawn:
			_lines_drawn = drawn
			action.emit("line_drawn")

	if not _touch_seen:
		var mouse := get_viewport().get_mouse_position()
		var was := _hover
		_hover = -1
		for i in _buttons.size():
			if Rect2(_buttons[i]["rect"]).has_point(mouse):
				_hover = i
		var over := field_at(mouse)
		if over >= 0 and over != focus:
			focus = over
			action.emit("hover")
		if _hover != was and _hover >= 0:
			action.emit("hover")
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var point := Vector2.ZERO
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
		_touch_seen = true
		_hover = -1
	else:
		return

	for button in _buttons:
		if not Rect2(button["rect"]).has_point(point):
			continue
		get_viewport().set_input_as_handled()
		if str(button["id"]) == "start":
			if unlocked(focus):
				chosen.emit(focus)
			else:
				action.emit("locked")
		else:
			action.emit(str(button["id"]))
		return

	var index := field_at(point)
	if index < 0:
		return
	get_viewport().set_input_as_handled()
	focus = index
	if unlocked(index):
		chosen.emit(index)
	else:
		action.emit("locked")


# --- Drawing ------------------------------------------------------------

func _draw() -> void:
	var curtain := VOID
	curtain.a = 0.80 * _fade
	draw_rect(Rect2(Vector2.ZERO, screen_size), curtain)

	# The universe's own colour, hanging behind its levels. Two clouds,
	# drifting at different rates, so the sky is not a flat sheet.
	var tint := Cosmos.tint_of(Strings.universe_index(zone_slug) - 1)
	Cosmos.draw_wash(self, Vector2(screen_size.x * 0.30 + sin(_time * 0.11) * 12.0, 470.0),
		250.0, tint, 0.09 * _fade)
	Cosmos.draw_wash(self, Vector2(screen_size.x * 0.72 + cos(_time * 0.08) * 10.0, 300.0),
		210.0, tint.lerp(PULSE, 0.5), 0.08 * _fade)
	_draw_chart_paper()

	_draw_header()
	_draw_route()
	_draw_edges()
	for i in mini(fields.size(), NODES.size()):
		_draw_node(i)
	_draw_caption()
	for button in _buttons:
		if str(button["id"]) != "start":
			_draw_button(button)


func _draw_header() -> void:
	# The place you pressed, still there, so the two screens are the same
	# journey rather than two menus.
	var index := Strings.universe_index(zone_slug) - 1
	Cosmos.draw_body(self, index, Vector2(56.0, 138.0), 22.0, 1.0, _time)
	_text(FONT_BRAND, Strings.zone_name(zone_slug), Vector2(screen_size.x * 0.5 + 20.0, 132.0),
		23, PULSE, true)
	_text(FONT_UI, Strings.fmt("UNIVERSE_NUMBER", [index + 1]),
		Vector2(screen_size.x * 0.5 + 20.0, 154.0), 9, SLATE, true)

	# The tally, so the chart is also the answer to "how far am I".
	var stars := 0
	var total := fields.size() * 3
	for entry in fields:
		stars += int(entry.get("stars", 0))
	_text(FONT_SCORE, "%d / %d" % [stars, total], Vector2(screen_size.x * 0.5, 182.0), 15,
		VOLT if stars >= total and total > 0 else BONE, true)
	if reveal >= 1.0 and is_zone_complete():
		var mark := ICE
		mark.a = 0.55 + 0.35 * sin(_time * 2.0)
		_text(FONT_UI, Strings.text("MAP_COMPLETE"), Vector2(screen_size.x * 0.5, 204.0), 9, mark, true)


## The paper the chart is drawn on: a grid to measure by, a frame with
## corner ticks, and a heading. It is the difference between twelve
## points floating in the dark and a chart of somewhere.
func _draw_chart_paper() -> void:
	var ink := Color("2A2A3A")
	ink.a = 0.5 * _fade
	var step := 44.0
	var x := CHART.position.x + step
	while x < CHART.end.x:
		draw_line(Vector2(x, CHART.position.y), Vector2(x, CHART.end.y), Color(ink, 0.10 * _fade), 1.0)
		x += step
	var y := CHART.position.y + step
	while y < CHART.end.y:
		draw_line(Vector2(CHART.position.x, y), Vector2(CHART.end.x, y), Color(ink, 0.10 * _fade), 1.0)
		y += step
	draw_rect(CHART, Color(ink, 0.55 * _fade), false, 1.0)
	# Corner ticks, like an instrument rather than a dialogue box.
	var mark := PULSE
	mark.a = 0.55 * _fade
	var m := 12.0
	for corner in [
			[CHART.position, Vector2(1.0, 1.0)],
			[Vector2(CHART.end.x, CHART.position.y), Vector2(-1.0, 1.0)],
			[Vector2(CHART.position.x, CHART.end.y), Vector2(1.0, -1.0)],
			[CHART.end, Vector2(-1.0, -1.0)]]:
		var at: Vector2 = corner[0]
		var dir: Vector2 = corner[1]
		draw_line(at, at + Vector2(m * dir.x, 0.0), mark, 1.0)
		draw_line(at, at + Vector2(0.0, m * dir.y), mark, 1.0)


## The route, drawn as it is flown. A line appears between two levels
## once both of them have fallen, so the chart fills in behind the
## player. The figure itself still waits for the whole universe: this is
## the flight path, not the constellation.
func _draw_route() -> void:
	if reveal >= 1.0:
		return
	# The whole way, dotted, so the destination is visible from the
	# start: the chart is a reason to keep going, not a record of where
	# you have been.
	var faint := Color("3A3A50")
	faint.a = 0.5 * _fade
	for i in range(1, mini(fields.size(), NODES.size())):
		_dashed(NODES[i - 1], NODES[i], faint)
	for i in range(1, mini(fields.size(), NODES.size())):
		if not bool(fields[i]["cleared"]) or not bool(fields[i - 1]["cleared"]):
			continue
		var line := Cosmos.tint_of(Strings.universe_index(zone_slug) - 1)
		line.a = 0.10
		draw_line(NODES[i - 1], NODES[i], line, 4.0)
		line.a = 0.32
		draw_line(NODES[i - 1], NODES[i], line, 1.0)


## Drawn straight, without building a list first: this runs eleven times
## a frame and a list per segment is eleven allocations that nobody ever
## reads twice.
func _dashed(a: Vector2, b: Vector2, color: Color) -> void:
	var length := a.distance_to(b)
	if length <= 0.01:
		return
	var dir := (b - a) / length
	var travelled := 0.0
	while travelled < length:
		var to := minf(travelled + 4.0, length)
		draw_line(a + dir * travelled, a + dir * to, color, 1.0)
		travelled = to + 5.0


func _draw_edges() -> void:
	if reveal <= 0.0:
		return
	var progress := reveal * float(EDGES.size())
	for i in EDGES.size():
		var t := clampf(progress - float(i), 0.0, 1.0)
		if t <= 0.0:
			break
		var a := NODES[EDGES[i].x]
		var b := NODES[EDGES[i].y]
		var line := PULSE
		line.a = 0.20 * t
		draw_line(a, a.lerp(b, t), line, 5.0)
		line.a = 0.75 * t
		draw_line(a, a.lerp(b, t), line, 1.0)


func _draw_node(index: int) -> void:
	var at := NODES[index]
	var entry := fields[index]
	var cleared := bool(entry.get("cleared", false))
	var stars := int(entry.get("stars", 0))
	var open := unlocked(index)
	var focused := index == focus

	if not open:
		# A star you have not reached is still up there. Faint, but not
		# so faint that the chart looks like it stops where you did: the
		# whole zone has to be visible as somewhere to go.
		var dim := SLATE
		dim.a = 0.16
		_diamond(at, 6.0, dim)
		dim.a = 0.42
		_diamond(at, 2.5, dim)
		return

	if cleared:
		# Lit, and the glow says how many of the three you took.
		var glow := VOLT if stars >= 3 else BONE
		for ring in 3:
			glow.a = (0.08 + 0.035 * float(stars)) / float(ring + 1)
			_diamond(at, 9.0 + float(ring) * 4.0 + float(stars) * 1.5, glow)
		# Three of three gets a cross of light. It is the only mark on
		# the chart that says perfect, and it should be visible from the
		# other side of the screen.
		if stars >= 3:
			var flare := VOLT
			var reach := 15.0 + 2.0 * sin(_time * 1.7 + float(index))
			flare.a = 0.5
			draw_line(at - Vector2(reach, 0.0), at + Vector2(reach, 0.0), flare, 1.0)
			draw_line(at - Vector2(0.0, reach), at + Vector2(0.0, reach), flare, 1.0)
		_diamond(at, 6.0, VOLT if stars >= 3 else BONE)
	else:
		# Reached but not taken: an outline that breathes.
		var pulse := 0.55 + 0.45 * sin(_time * 2.6 + float(index))
		var ring_color := BONE
		ring_color.a = 0.35 + 0.35 * pulse
		_diamond_outline(at, 7.0, ring_color)

	if focused:
		var mark := VOLT
		mark.a = 0.55 + 0.25 * sin(_time * 5.0)
		_diamond_outline(at, 14.0, mark)

	var label := BONE if cleared else SLATE
	label.a = 0.8
	_text(FONT_SCORE, "%02d" % (index + 1), at + Vector2(0.0, 26.0), 9, label, true)

	# The end of the road, marked from the beginning. A chart is a reason
	# to keep going, and a reason has to be visible from where you are.
	if index == fields.size() - 1 and not cleared:
		var ring := PULSE
		ring.a = 0.42
		_diamond_outline(at, 20.0, ring)
		_diamond_outline(at, 26.0, Color(ring, 0.2))
		ring.a = 0.7
		_text(FONT_UI, str(entry.get("name", "")).to_upper(), at + Vector2(0.0, -26.0), 8, ring, true)

	# The one to press. A chart with nothing marked on it is a chart you
	# have to work out before you can play.
	if index == next_index and not cleared:
		var beat := 0.5 + 0.5 * sin(_time * 3.0)
		var ring := VOLT
		ring.a = 0.35 + 0.45 * beat
		_diamond_outline(at, 18.0 + 3.0 * beat, ring)
		ring.a = 0.8
		_text(FONT_UI, Strings.text("MAP_START_HERE"), at + Vector2(0.0, -24.0), 8, ring, true)


func _draw_caption() -> void:
	if focus < 0 or focus >= fields.size():
		return
	var entry := fields[focus]
	var open := unlocked(focus)
	var box := Rect2(24.0, 686.0, screen_size.x - 48.0, 58.0)
	var panel := Color("11111A")
	panel.a = 0.9
	draw_rect(box, panel)
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), EDGE)

	var name := str(entry.get("name", ""))
	var line := Strings.fmt("MAP_FIELD", [focus + 1, name.to_upper()]) if open \
		else Strings.text("MAP_LOCKED")
	_text(FONT_DISPLAY, line, Vector2(screen_size.x * 0.5 - (12.0 if open else 0.0),
		box.position.y + 24.0), 13, BONE if open else SLATE, true)

	# It is a button, so it says so: the word and the way in.
	if open:
		var go := VOLT
		go.a = 0.9
		var tip := Vector2(box.end.x - 22.0, box.position.y + 20.0)
		draw_colored_polygon(PackedVector2Array([
			tip + Vector2(-3.0, -7.0), tip + Vector2(5.0, 0.0), tip + Vector2(-3.0, 7.0),
			tip + Vector2(-6.0, 4.0), tip + Vector2(-1.0, 0.0), tip + Vector2(-6.0, -4.0),
		]), go)
		var edge := VOLT
		edge.a = 0.35
		draw_rect(box, edge, false, 1.0)

	if not open:
		_text(FONT_UI, Strings.text("MAP_LOCKED_HINT"),
			Vector2(screen_size.x * 0.5, box.position.y + 44.0), 9, SLATE, true)
		return

	# The three stars, and the best time under them.
	var bits := int(entry.get("bits", 0))
	var start := screen_size.x * 0.5 - 34.0
	for i in 3:
		var got := bits & (1 << i)
		_diamond(Vector2(start + float(i) * 22.0, box.position.y + 40.0), 5.0,
			VOLT if got else EDGE)
	var best := float(entry.get("best_time", 0.0))
	if best > 0.0:
		_text(FONT_UI, Strings.fmt("MAP_BEST", [_clock(best)]),
			Vector2(box.end.x - 8.0, box.position.y + 44.0), 9, SLATE, false, HORIZONTAL_ALIGNMENT_RIGHT)


func _draw_button(button: Dictionary) -> void:
	var rect: Rect2 = button["rect"]
	var tint: Color = button["tint"]
	var body := Color("11111A")
	body.a = 0.92
	draw_rect(rect, body)
	var edge := tint
	edge.a = 0.55
	draw_rect(Rect2(rect.position, Vector2(rect.size.x, 1.0)), edge)
	draw_rect(Rect2(Vector2(rect.position.x, rect.end.y - 1.0), Vector2(rect.size.x, 1.0)), edge)
	_text(FONT_UI, str(button["label"]), rect.get_center() + Vector2(0.0, 4.0), 12, tint, true)


static func _clock(seconds: float) -> String:
	var whole := int(seconds)
	return "%02d:%02d" % [whole / 60, whole % 60]


func _diamond(at: Vector2, radius: float, color: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -radius), at + Vector2(radius, 0.0),
		at + Vector2(0.0, radius), at + Vector2(-radius, 0.0),
	]), color)


func _diamond_outline(at: Vector2, radius: float, color: Color) -> void:
	draw_polyline(PackedVector2Array([
		at + Vector2(0.0, -radius), at + Vector2(radius, 0.0),
		at + Vector2(0.0, radius), at + Vector2(-radius, 0.0),
		at + Vector2(0.0, -radius),
	]), color, 1.0)


func _text(font: Font, text: String, at: Vector2, size: int, color: Color, centered: bool,
		align := HORIZONTAL_ALIGNMENT_LEFT) -> void:
	var width := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var pen := at
	if centered:
		pen.x -= width * 0.5
	elif align == HORIZONTAL_ALIGNMENT_RIGHT:
		pen.x -= width
	draw_string(font, pen, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
