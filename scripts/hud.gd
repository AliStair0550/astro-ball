class_name HUD
extends Node2D

## Lag 6: HUD.
##
## Layoutet følger afsnit 8. Typografien gør ikke: Unbounded og Space
## Grotesk hører til punkt 7 i byggerækkefølgen sammen med lyd, så indtil
## da tegnes teksten med motorens egen skrift. Alt andet, placering,
## farver, tidsbjælker og livsprikker, er som beskrevet.

const HEIGHT := 44.0
const VOID := Color("07070C")
const RULE := Color("232330")
const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const SLATE := Color("888780")
const LOST_LIFE := Color("444441")

const MAX_ACTIVE_ICONS := 4

var screen_size := Vector2(390.0, 844.0)

var score := 0
var displayed_score := 0.0
var level_number := 1
var level_name := ""
var lives := 3
var max_lives := 3
var combo := 0
var active: Dictionary = {}

var _font: Font


func _ready() -> void:
	_font = ThemeDB.fallback_font


func _process(delta: float) -> void:
	# Scoren tæller op i stedet for at hoppe. Små tal, stor forskel.
	displayed_score = move_toward(displayed_score, float(score), maxf(240.0, absf(score - displayed_score) * 6.0) * delta)
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
	draw_rect(Rect2(0.0, 0.0, screen_size.x, HEIGHT), VOID)
	draw_rect(Rect2(0.0, HEIGHT - 1.0, screen_size.x, 1.0), RULE)

	if _font == null:
		return

	# Venstre: titel og level.
	_draw_tracked("ASTRO BALL", Vector2(10.0, 20.0), 13, BONE, 2.0)
	var label := "LEVEL %d" % level_number
	if not level_name.is_empty():
		label += "  ·  %s" % level_name.to_upper()
	draw_string(_font, Vector2(10.0, 34.0), label, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 9, SLATE)

	# Højre: score og liv.
	var score_text := group_digits(int(round(displayed_score)))
	var width := _font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14).x
	draw_string(_font, Vector2(screen_size.x - 10.0 - width, 21.0), score_text,
		HORIZONTAL_ALIGNMENT_LEFT, -1.0, 14, VOLT)
	for i in max_lives:
		var c := BONE if i < lives else LOST_LIFE
		var x := screen_size.x - 10.0 - float(max_lives - i) * 9.0
		draw_rect(Rect2(x, 28.0, 5.0, 5.0), c)

	# Midt: kombo fra 3 og op, vokser med komboen.
	if combo >= 3:
		var size := int(clampf(13.0 + float(combo) * 0.9, 13.0, 26.0))
		var text := "x%d" % combo
		var w := _font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x
		draw_string(_font, Vector2(screen_size.x * 0.5 - w * 0.5, 28.0), text,
			HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, VOLT)

	_draw_active()


## Aktive power-ups som små ikoner under HUD med tidsbjælke. Maks 4.
func _draw_active() -> void:
	var x := 10.0
	var shown := 0
	for id in active:
		if shown >= MAX_ACTIVE_ICONS:
			break
		var info := Powerup.info(str(id))
		var color: Color = info["color"]
		var left := float(active[id])
		var total := maxf(float(info["duration"]), 0.001)
		var box := Rect2(x, HEIGHT + 4.0, 26.0, 12.0)
		var bg := color
		bg.a = 0.22
		draw_rect(box, bg)
		draw_rect(box, color, false, 1.0)
		if _font:
			var short := str(info["name"]).substr(0, 3).to_upper()
			draw_string(_font, box.position + Vector2(3.0, 9.0), short,
				HORIZONTAL_ALIGNMENT_LEFT, -1.0, 8, color)
		# Tidsbjælke.
		var bar := clampf(left / total, 0.0, 1.0)
		draw_rect(Rect2(box.position.x, box.end.y + 1.0, box.size.x * bar, 2.0), color)
		x += 30.0
		shown += 1


## Bogstavafstand skal sættes i hånden, når man tegner direkte.
func _draw_tracked(text: String, at: Vector2, size: int, color: Color, tracking: float) -> void:
	var pen := at
	for i in text.length():
		var ch := text[i]
		draw_string(_font, pen, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
		pen.x += _font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
