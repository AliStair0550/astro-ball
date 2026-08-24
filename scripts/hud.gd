class_name HUD
extends Node2D

## Layer 6: the HUD.
##
## The top is not a status bar, it is the game's face. ASTRO BALL sits
## in Unbounded in Pulse violet with a dark offset behind it, so the
## name sits in the graphite instead of floating on top. Below it the
## zone and the level, to the right the score and the lives, and along
## the bottom the dock of active power-ups.
##
## The panel is 140 px tall. That is not decoration: on a screen twice
## as tall as it is wide it pushes the bricks down into reach instead
## of leaving half a screen of dead room.

const HEIGHT := Arena.HUD_BASE_HEIGHT
## The camera owns the top of the screen. Nothing readable goes above this.
const TOP := Arena.CONTENT_TOP


const VOID := Color("07070C")
const GRAPHITE_TOP := Color("13131C")
const GRAPHITE_BOTTOM := Color("09090F")
const RULE := Color("232330")
const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const PULSE := Color("B57BFF")
const PULSE_DEEP := Color("3D2168")
const SLATE := Color("888780")
const LOST_LIFE := Color("444441")

const FONT_BRAND := preload("res://assets/fonts/Unbounded-900.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Unbounded-700.ttf")
const FONT_SCORE := preload("res://assets/fonts/SpaceGrotesk-700.ttf")
const FONT_UI := preload("res://assets/fonts/SpaceGrotesk-500.ttf")

const BRAND_SIZE := 26
const BRAND_TRACKING := 2.0
const SCORE_SIZE := 28
const LABEL_SIZE := 9

## The dock always has four slots. Empty ones are drawn faintly, so the
## top reads as an instrument and not as a hole waiting to be filled.
const DOCK_SLOTS := 4
const DOCK_Y := 116.0
const DOCK_HEIGHT := 26.0
const DOCK_GAP := 6.0
const DOCK_MARGIN := 10.0
## The dock row ends in a control rather than a slot. A phone has no
## other way out of a field, and a button that lives in the panel with
## the score and the lives is a button the player can find.
const PAUSE_W := 34.0
## A finger is wider than the glyph. The reach goes up into the panel,
## where there is nothing else to press.
const PAUSE_TOUCH := 46.0

var screen_size := Vector2(390.0, 844.0)

var score := 0
var displayed_score := 0.0
var level_number := 1
var level_name := ""
var zone_slug := "baeltet"
var lives := 3
var max_lives := 3
var combo := 0
var active: Dictionary = {}
## Section 15. Three bits: cleared, under par, no ball lost.
var stars := 0
var best_score := 0

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	# The score counts up instead of jumping. Small thing, big difference.
	var gap := absf(float(score) - displayed_score)
	displayed_score = move_toward(displayed_score, float(score), maxf(300.0, gap * 7.0) * delta)
	queue_redraw()


static func group_digits(value: int) -> String:
	var digits := str(absi(value))
	var out := ""
	var count := 0
	for i in range(digits.length() - 1, -1, -1):
		out = digits[i] + out
		count += 1
		if count % 3 == 0 and i > 0:
			out = " " + out
	return ("-" if value < 0 else "") + out


func _draw() -> void:
	_draw_panel()
	_draw_brand()
	_draw_score()
	_draw_status_row()
	_draw_dock()


## Graphite, and nothing at the bottom edge. The frame's top bar below is
## the ceiling; a second line two pixels above it read as two.
func _draw_panel() -> void:
	var bands := 18
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := GRAPHITE_TOP.lerp(GRAPHITE_BOTTOM, f * f)
		draw_rect(Rect2(0.0, HEIGHT * f, screen_size.x, HEIGHT / float(bands) + 1.0), c)

	var etch := Color("1B1B26")
	etch.a = 0.4
	for i in 4:
		draw_rect(Rect2(0.0, TOP + 6.0 + float(i) * 26.0, screen_size.x, 1.0), etch)

	# A violet glow behind the name, so the brand sits in its own light.
	for i in 6:
		var glow := PULSE_DEEP
		glow.a = 0.05
		draw_rect(Rect2(4.0 - float(i) * 4.0, TOP - float(i) * 3.0,
			270.0 + float(i) * 10.0, 36.0 + float(i) * 6.0), glow)


func _draw_brand() -> void:
	var at := Vector2(14.0, TOP + 28.0)
	var brand := Strings.text("BRAND")
	_tracked(FONT_BRAND, brand, at + Vector2(2.0, 3.0), BRAND_SIZE, PULSE_DEEP, BRAND_TRACKING)
	_tracked(FONT_BRAND, brand, at, BRAND_SIZE, PULSE, BRAND_TRACKING)


func _draw_score() -> void:
	var text := group_digits(int(round(displayed_score)))
	var width := FONT_SCORE.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCORE_SIZE).x
	var at := Vector2(screen_size.x - 15.0 - width, TOP + 28.0)
	draw_string(FONT_SCORE, at + Vector2(0.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		SCORE_SIZE, VOLT.darkened(0.78))
	draw_string(FONT_SCORE, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCORE_SIZE, VOLT)


## One row under the brand: where you are on the left, what you have on
## the right. A running combo takes the middle, and the left shortens to
## make room, because a combo is urgent and a level name is not.
func _draw_status_row() -> void:
	var y := TOP + 46.0
	var running := combo >= 3

	var text := Strings.fmt("LEVEL_AND_NAME", [level_number, level_name.to_upper()])
	if running:
		text = Strings.fmt("LEVEL_NUMBER", [level_number])
	else:
		text = "%s · %s" % [Strings.universe_short(zone_slug), text]
	_tracked(FONT_UI, text, Vector2(15.0, y), 9, SLATE, 1.4)

	if running:
		_draw_combo(y)

	var right := screen_size.x - 15.0
	for i in 3:
		_draw_star_mark(Vector2(right - 8.0 - float(2 - i) * 15.0, y - 4.0),
			(stars & (1 << i)) != 0)
	var lives_right := right - 3.0 * 15.0 - 10.0
	for i in max_lives:
		var alive := i < lives
		var c := BONE if alive else LOST_LIFE
		var x := lives_right - float(max_lives - i) * 13.0
		var tail := c
		tail.a = 0.4 if alive else 0.2
		draw_rect(Rect2(x - 5.0, y - 5.0, 5.0, 2.0), tail)
		draw_rect(Rect2(x, y - 6.0, 5.0, 5.0), c)


## A diamond: a square turned forty-five degrees, so it stays in the same
## language as the bricks and the shards.
func _draw_star_mark(at: Vector2, earned: bool) -> void:
	var size := 5.0 if earned else 3.5
	var color := VOLT if earned else Color("2E2E3C")
	if earned:
		var glow := VOLT
		glow.a = 0.18
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(0.0, -size - 3.0), at + Vector2(size + 3.0, 0.0),
			at + Vector2(0.0, size + 3.0), at + Vector2(-size - 3.0, 0.0),
		]), glow)
	draw_colored_polygon(PackedVector2Array([
		at + Vector2(0.0, -size), at + Vector2(size, 0.0),
		at + Vector2(0.0, size), at + Vector2(-size, 0.0),
	]), color)


func _draw_combo(y: float) -> void:
	var size := int(clampf(15.0 + float(combo) * 0.9, 15.0, 26.0))
	var text := "%d" % combo
	var width := FONT_BRAND.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var at := Vector2(screen_size.x * 0.5 - width * 0.5, y + 3.0)
	var pulse := 0.75 + 0.25 * sin(_time * 9.0)
	for i in 3:
		var glow := VOLT
		glow.a = 0.06 * pulse * (1.0 - float(i) * 0.28)
		var pad := 3.0 + float(i) * 4.0
		draw_rect(Rect2(at.x - pad, at.y - float(size) - pad * 0.3,
			width + pad * 2.0, float(size) + pad * 0.6), glow)
	draw_string(FONT_BRAND, at + Vector2(1.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0,
		size, VOLT.darkened(0.72))
	draw_string(FONT_BRAND, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, VOLT)


## Four slots along the bottom. Active power-ups fill them from the left.
## Where the pause control is drawn.
func pause_rect() -> Rect2:
	return Rect2(screen_size.x - DOCK_MARGIN - PAUSE_W, DOCK_Y, PAUSE_W, DOCK_HEIGHT)


## Where a thumb may land on it.
func pause_touch_rect() -> Rect2:
	var box := pause_rect()
	var grow_y := maxf(PAUSE_TOUCH - box.size.y, 0.0)
	var grow_x := maxf(PAUSE_TOUCH - box.size.x, 0.0) * 0.5
	# Downward would reach into the field, so the extra height goes up.
	return Rect2(box.position - Vector2(grow_x, grow_y), box.size + Vector2(grow_x * 2.0, grow_y))


func _draw_dock() -> void:
	var total_gap := DOCK_GAP * float(DOCK_SLOTS - 1)
	var slot_w := (screen_size.x - DOCK_MARGIN * 2.0 - total_gap - PAUSE_W - DOCK_GAP) / float(DOCK_SLOTS)
	var ids: Array[String] = []
	for id in active:
		if ids.size() < DOCK_SLOTS:
			ids.append(str(id))
	for i in DOCK_SLOTS:
		var box := Rect2(DOCK_MARGIN + float(i) * (slot_w + DOCK_GAP), DOCK_Y, slot_w, DOCK_HEIGHT)
		if i < ids.size():
			_draw_dock_chip(box, ids[i])
		else:
			_draw_dock_empty(box)
	_draw_pause()


func _draw_pause() -> void:
	var box := pause_rect()
	var body := Color("15151F")
	body.a = 0.9
	draw_rect(box, body)
	var edge := SLATE
	edge.a = 0.45
	draw_rect(Rect2(box.position, Vector2(box.size.x, 1.0)), edge)
	draw_rect(Rect2(Vector2(box.position.x, box.end.y - 1.0), Vector2(box.size.x, 1.0)), edge)
	var bar := BONE
	bar.a = 0.75
	var mid := box.get_center()
	draw_rect(Rect2(mid + Vector2(-5.0, -6.0), Vector2(3.0, 12.0)), bar)
	draw_rect(Rect2(mid + Vector2(2.0, -6.0), Vector2(3.0, 12.0)), bar)


func _draw_dock_empty(box: Rect2) -> void:
	draw_rect(box, Color("1A1A25"))
	var edge := Color("232330")
	draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), edge)
	edge.a = 0.6
	for i in 3:
		draw_rect(Rect2(box.position.x + 10.0 + float(i) * 7.0, box.get_center().y - 1.0, 3.0, 2.0), edge)


func _draw_dock_chip(box: Rect2, id: String) -> void:
	var info := Powerup.info(id)
	var color: Color = info["color"]
	var left := float(active.get(id, 0.0))
	var total := maxf(float(info["duration"]), 0.001)

	var bg := color
	bg.a = 0.16
	draw_rect(box, bg)
	bg.a = 0.65
	draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), bg)

	Powerup.draw_icon_into(self, str(info["icon"]), box.position + Vector2(15.0, 12.0), 0.85, color)
	_tracked(FONT_UI, Strings.powerup_name(id), box.position + Vector2(26.0, 16.0), 9,
		color.lightened(0.3), 0.6)

	var bar := clampf(left / total, 0.0, 1.0)
	var track := color
	track.a = 0.18
	draw_rect(Rect2(box.position.x, box.end.y - 2.0, box.size.x, 2.0), track)
	draw_rect(Rect2(box.position.x, box.end.y - 2.0, box.size.x * bar, 2.0), color)


func _tracked_width(font: Font, text: String, size: int, tracking: float) -> float:
	var w := 0.0
	for i in text.length():
		w += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
	return maxf(w - tracking, 0.0)


## Letter spacing has to be done by hand when drawing text directly.
func _tracked(font: Font, text: String, at: Vector2, size: int, color: Color, tracking: float) -> void:
	var pen := at
	for i in text.length():
		var ch := text[i]
		draw_string(font, pen, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
		pen.x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
