class_name HUD
extends Node2D

## Lag 6: HUD.
##
## Toppen er ikke en statuslinje, den er spillets ansigt. ASTRO BALL står
## i Unbounded i Pulse-lilla med en mørk forskydning bagved, så navnet
## sidder i grafitten i stedet for at flyde ovenpå. Under det ligger
## zonen og levelet, til højre scoren og livene, og nederst i panelet
## docken med aktive power-ups.
##
## Panelet er 140 px højt. Det er ikke pynt: på en skærm, der er dobbelt
## så høj som den er bred, skubber det klodserne ned i spillerens
## rækkevidde i stedet for at efterlade en halv skærm dødt rum.

const HEIGHT := 140.0
const RULE_Y := HEIGHT - 2.0

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

const BRAND_SIZE := 28
const BRAND_TRACKING := 2.0
const SCORE_SIZE := 32
const LABEL_SIZE := 9

## Docken har altid fire pladser. Tomme pladser tegnes svagt, så toppen
## ser ud som et instrument og ikke som et hul, der venter på indhold.
const DOCK_SLOTS := 4
const DOCK_Y := 108.0
const DOCK_HEIGHT := 24.0
const DOCK_GAP := 6.0
const DOCK_MARGIN := 10.0

var screen_size := Vector2(390.0, 844.0)

var score := 0
var displayed_score := 0.0
var level_number := 1
var level_name := ""
var zone_name := "THE BELT"
var lives := 3
var max_lives := 3
var combo := 0
var active: Dictionary = {}

var _time := 0.0


func _process(delta: float) -> void:
	_time += delta
	# Scoren tæller op i stedet for at hoppe. Små tal, stor forskel.
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
	_draw_level_line()
	_draw_lives()
	_draw_combo()
	_draw_dock()


## Grafit: en lodret tone fra næsten sort til lidt lysere, med en
## håndfuld svage linjer, så fladen ikke er død.
func _draw_panel() -> void:
	var bands := 16
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := GRAPHITE_TOP.lerp(GRAPHITE_BOTTOM, f * f)
		draw_rect(Rect2(0.0, HEIGHT * f, screen_size.x, HEIGHT / float(bands) + 1.0), c)

	var etch := Color("1B1B26")
	etch.a = 0.45
	for i in 6:
		draw_rect(Rect2(0.0, 16.0 + float(i) * 21.0, screen_size.x, 1.0), etch)

	# Lilla glød bag navnet, så brandet sidder i sit eget lys.
	for i in 6:
		var glow := PULSE_DEEP
		glow.a = 0.05
		draw_rect(Rect2(4.0 - float(i) * 4.0, 10.0 - float(i) * 3.0,
			280.0 + float(i) * 10.0, 38.0 + float(i) * 6.0), glow)

	# Afslutningen mod feltet.
	var rule := PULSE
	rule.a = 0.6
	draw_rect(Rect2(0.0, RULE_Y, screen_size.x, 1.0), rule)
	rule.a = 0.14
	draw_rect(Rect2(0.0, RULE_Y - 3.0, screen_size.x, 3.0), rule)
	draw_rect(Rect2(0.0, HEIGHT - 1.0, screen_size.x, 1.0), RULE)


func _draw_brand() -> void:
	var at := Vector2(14.0, 42.0)
	# Mørk forskydning bagved giver navnet dybde uden en outline.
	_tracked(FONT_BRAND, "ASTRO BALL", at + Vector2(2.0, 3.0), BRAND_SIZE, PULSE_DEEP, BRAND_TRACKING)
	_tracked(FONT_BRAND, "ASTRO BALL", at, BRAND_SIZE, PULSE, BRAND_TRACKING)


func _draw_score() -> void:
	var text := group_digits(int(round(displayed_score)))
	var width := FONT_SCORE.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCORE_SIZE).x
	var at := Vector2(screen_size.x - 15.0 - width, 80.0)
	var shadow := VOLT.darkened(0.78)
	draw_string(FONT_SCORE, at + Vector2(0.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCORE_SIZE, shadow)
	draw_string(FONT_SCORE, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, SCORE_SIZE, VOLT)


func _draw_level_line() -> void:
	var text := "%s · LEVEL %d" % [zone_name, level_number]
	if not level_name.is_empty():
		text += " · %s" % level_name.to_upper()
	_tracked(FONT_UI, text, Vector2(15.0, 64.0), LABEL_SIZE, SLATE, 1.4)


## Livene er små kometer, ikke prikker. Det er dem, du er.
func _draw_lives() -> void:
	var right := screen_size.x - 15.0
	var y := 92.0
	for i in max_lives:
		var alive := i < lives
		var c := BONE if alive else LOST_LIFE
		var x := right - float(max_lives - i) * 15.0
		var tail := c
		tail.a = 0.4 if alive else 0.2
		draw_rect(Rect2(x - 6.0, y + 1.0, 6.0, 2.0), tail)
		draw_rect(Rect2(x, y, 6.0, 6.0), c)
		if alive:
			var spark := VOLT
			spark.a = 0.8
			draw_rect(Rect2(x + 1.0, y + 1.0, 2.0, 2.0), spark)


## Kombo fra 3 og op, midt i panelet, vokser med komboen.
func _draw_combo() -> void:
	if combo < 3:
		return
	var size := int(clampf(17.0 + float(combo) * 1.1, 17.0, 32.0))
	var text := "%d" % combo
	var width := FONT_BRAND.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
	var at := Vector2(screen_size.x * 0.5 - width * 0.5, 100.0)
	var pulse := 0.75 + 0.25 * sin(_time * 9.0)
	# Blød glød: tre lag udad i stedet for én hård kasse.
	for i in 3:
		var glow := VOLT
		glow.a = 0.09 * pulse * (1.0 - float(i) * 0.28)
		var pad := 6.0 + float(i) * 7.0
		draw_rect(Rect2(at.x - pad, at.y - float(size) - pad * 0.4,
			width + pad * 2.0, float(size) + pad * 0.8), glow)
	draw_string(FONT_BRAND, at + Vector2(1.0, 2.0), text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, VOLT.darkened(0.72))
	draw_string(FONT_BRAND, at, text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, VOLT)


## Fire pladser i bunden af panelet. Aktive power-ups fylder dem forfra.
func _draw_dock() -> void:
	var total_gap := DOCK_GAP * float(DOCK_SLOTS - 1)
	var slot_w := (screen_size.x - DOCK_MARGIN * 2.0 - total_gap) / float(DOCK_SLOTS)
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


func _draw_dock_empty(box: Rect2) -> void:
	var idle := Color("1A1A25")
	draw_rect(box, idle)
	var edge := Color("232330")
	draw_rect(Rect2(box.position, Vector2(2.0, box.size.y)), edge)
	# Svage streger, som en tom måler.
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

	Powerup.draw_icon_into(self, str(info["icon"]), box.position + Vector2(15.0, 11.0), 0.8, color)
	_tracked(FONT_UI, str(info["name"]).to_upper(), box.position + Vector2(25.0, 15.0), 9,
		color.lightened(0.3), 0.6)

	var bar := clampf(left / total, 0.0, 1.0)
	var track := color
	track.a = 0.18
	draw_rect(Rect2(box.position.x, box.end.y - 2.0, box.size.x, 2.0), track)
	draw_rect(Rect2(box.position.x, box.end.y - 2.0, box.size.x * bar, 2.0), color)


## Bogstavafstand skal sættes i hånden, når man tegner direkte.
func _tracked(font: Font, text: String, at: Vector2, size: int, color: Color, tracking: float) -> void:
	var pen := at
	for i in text.length():
		var ch := text[i]
		draw_string(font, pen, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
		pen.x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
