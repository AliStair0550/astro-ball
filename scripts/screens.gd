class_name Screens
extends Node2D

## Alt, spilleren ser, som ikke er selve spillet: titel, indstillinger,
## level-intro, level clear og game over.
##
## Skærmene ejer ikke spillets tilstand. De tegner, tager imod klik og
## siger til med et signal. Spillet bestemmer, hvad der så sker.

signal action(name: String)

enum Screen { NONE, TITLE, SETTINGS, LEVEL_INTRO, LEVEL_CLEAR, GAME_OVER }

const FONT_BRAND := preload("res://assets/fonts/Unbounded-900.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Unbounded-700.ttf")
const FONT_SCORE := preload("res://assets/fonts/SpaceGrotesk-700.ttf")
const FONT_UI := preload("res://assets/fonts/SpaceGrotesk-500.ttf")

const VOID := Color("07070C")
const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const PULSE := Color("B57BFF")
const PULSE_DEEP := Color("3D2168")
const EMBER := Color("FF4D2E")
const SLATE := Color("888780")
const PANEL := Color("11111A")
const EDGE := Color("2A2A3A")

var screen_size := Vector2(390.0, 844.0)
var current := Screen.NONE

var level_number := 1
var level_title := ""
var final_score := 0
var high_score := 0
var new_record := false

var _buttons: Array[Dictionary] = []
var _hover := -1
var _time := 0.0
var _fade := 0.0


func _ready() -> void:
	set_process_unhandled_input(true)


func show_screen(which: Screen) -> void:
	if current == which:
		return
	current = which
	_time = 0.0
	_fade = 0.0
	_hover = -1
	_layout()
	visible = which != Screen.NONE
	queue_redraw()


func is_open() -> bool:
	return current != Screen.NONE


func _settings() -> Node:
	return get_node_or_null("/root/GameSettings")


# --- Knapper -----------------------------------------------------------

func _layout() -> void:
	_buttons.clear()
	var cx := screen_size.x * 0.5
	match current:
		Screen.TITLE:
			_add_button("play", "PLAY", Vector2(cx, 520.0), Vector2(220.0, 52.0), VOLT)
			_add_button("settings", "SETTINGS", Vector2(cx, 586.0), Vector2(220.0, 44.0), PULSE)
		Screen.SETTINGS:
			var s := _settings()
			var y := 300.0
			_add_button("toggle_sound", "SOUND", Vector2(cx, y), Vector2(280.0, 46.0), VOLT,
				"ON" if s and s.sound_on else "OFF")
			_add_button("volume_down", "−", Vector2(cx - 92.0, y + 62.0), Vector2(46.0, 46.0), PULSE)
			_add_button("volume_up", "+", Vector2(cx + 92.0, y + 62.0), Vector2(46.0, 46.0), PULSE)
			_add_button("toggle_crt", "CRT MODE", Vector2(cx, y + 124.0), Vector2(280.0, 46.0), VOLT,
				"ON" if s and s.crt else "OFF")
			_add_button("toggle_shake", "SCREEN SHAKE", Vector2(cx, y + 186.0), Vector2(280.0, 46.0), VOLT,
				"ON" if s and s.screen_shake else "OFF")
			_add_button("back", "BACK", Vector2(cx, y + 268.0), Vector2(180.0, 44.0), SLATE)
		Screen.GAME_OVER:
			_add_button("restart", "PLAY AGAIN", Vector2(cx, 540.0), Vector2(230.0, 52.0), VOLT)
			_add_button("menu", "MENU", Vector2(cx, 606.0), Vector2(180.0, 44.0), SLATE)


func _add_button(id: String, label: String, center: Vector2, size: Vector2, tint: Color, value := "") -> void:
	_buttons.append({
		"id": id,
		"label": label,
		"value": value,
		"rect": Rect2(center - size * 0.5, size),
		"tint": tint,
	})


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_fade = minf(1.0, _fade + delta * 4.0)

	var mouse := get_viewport().get_mouse_position()
	var was := _hover
	_hover = -1
	for i in _buttons.size():
		if Rect2(_buttons[i]["rect"]).has_point(mouse):
			_hover = i
			break
	if _hover != was and _hover >= 0:
		action.emit("hover")
	queue_redraw()


func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var pressed := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		pressed = true
	elif event is InputEventScreenTouch and event.pressed:
		pressed = true
	if not pressed:
		return

	if current == Screen.LEVEL_INTRO or current == Screen.LEVEL_CLEAR:
		action.emit("skip")
		get_viewport().set_input_as_handled()
		return

	if _hover >= 0:
		action.emit(str(_buttons[_hover]["id"]))
		get_viewport().set_input_as_handled()
		_layout()


# --- Tegning -----------------------------------------------------------

func _draw() -> void:
	match current:
		Screen.TITLE:
			_draw_curtain(0.82)
			_draw_title()
		Screen.SETTINGS:
			_draw_curtain(0.9)
			_draw_settings()
		Screen.LEVEL_INTRO:
			_draw_curtain(0.62)
			_draw_level_intro()
		Screen.LEVEL_CLEAR:
			_draw_curtain(0.5)
			_draw_level_clear()
		Screen.GAME_OVER:
			_draw_curtain(0.88)
			_draw_game_over()
	for i in _buttons.size():
		_draw_button(_buttons[i], i == _hover)


## Feltet bag skærmen dæmpes, men slukkes aldrig helt. Rummet er der
## stadig, mens man vælger.
func _draw_curtain(strength: float) -> void:
	var c := VOID
	c.a = strength * _fade
	draw_rect(Rect2(-20.0, -20.0, screen_size.x + 40.0, screen_size.y + 40.0), c)


func _draw_title() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, "ASTRO", cx, 268.0, 52, PULSE, 3.0, true)
	_centered(FONT_BRAND, "BALL", cx, 326.0, 52, PULSE, 3.0, true)
	_rule(cx, 348.0, 150.0, PULSE, 0.55)
	_centered(FONT_UI, "BREAK THROUGH THE BELT", cx, 378.0, 11, SLATE, 2.4, false)

	var s := _settings()
	if s and s.high_score > 0:
		_centered(FONT_UI, "BEST", cx, 664.0, 9, SLATE, 2.0, false)
		_centered(FONT_SCORE, HUD.group_digits(s.high_score), cx, 692.0, 20, VOLT, 0.0, false)

	var blink := 0.55 + 0.45 * sin(_time * 3.0)
	var hint := SLATE
	hint.a = blink * 0.8
	_centered(FONT_UI, "CLICK TO AIM · MOVE TO STEER", cx, 760.0, 9, hint, 1.8, false)


func _draw_settings() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, "SETTINGS", cx, 232.0, 28, PULSE, 2.4, true)
	_rule(cx, 252.0, 120.0, PULSE, 0.45)

	var s := _settings()
	var vol := int(round((s.volume if s else 0.8) * 100.0))
	_centered(FONT_UI, "VOLUME", cx, 352.0, 9, SLATE, 2.0, false)
	_centered(FONT_SCORE, "%d" % vol, cx, 376.0, 22, VOLT, 0.0, false)
	# Bjælken viser, hvor meget der er skruet op.
	var bar := Rect2(cx - 60.0, 386.0, 120.0, 3.0)
	var track := VOLT
	track.a = 0.2
	draw_rect(bar, track)
	draw_rect(Rect2(bar.position, Vector2(bar.size.x * (float(vol) / 100.0), bar.size.y)), VOLT)

	_centered(FONT_UI, "CRT MODE ADDS SCANLINES AND VIGNETTE", cx, 640.0, 8, SLATE, 1.4, false)


func _draw_level_intro() -> void:
	var cx := screen_size.x * 0.5
	# "LEVEL" med stort, derefter banens navn.
	var rise := (1.0 - ease(minf(_time / 0.35, 1.0), 0.35)) * 14.0
	_centered(FONT_BRAND, "LEVEL %d" % level_number, cx, 392.0 - rise, 40, BONE, 3.0, true)
	_rule(cx, 414.0, 110.0, VOLT, 0.7)
	_centered(FONT_DISPLAY, level_title.to_upper(), cx, 456.0 + rise * 0.5, 22, VOLT, 3.0, true)

	var blink := 0.4 + 0.6 * sin(_time * 4.0)
	var hint := SLATE
	hint.a = blink * 0.7
	_centered(FONT_UI, "CLICK TO BEGIN", cx, 540.0, 9, hint, 2.0, false)


func _draw_level_clear() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, "FIELD CLEARED", cx, 400.0, 26, VOLT, 2.6, true)
	_rule(cx, 420.0, 130.0, VOLT, 0.6)
	_centered(FONT_UI, "LEVEL %d · %s" % [level_number, level_title.to_upper()], cx, 448.0, 10, SLATE, 2.0, false)
	_centered(FONT_SCORE, HUD.group_digits(final_score), cx, 496.0, 26, BONE, 0.0, false)


func _draw_game_over() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, "GAME OVER", cx, 320.0, 40, EMBER, 3.0, true)
	_rule(cx, 342.0, 140.0, EMBER, 0.6)

	_centered(FONT_UI, "SCORE", cx, 396.0, 9, SLATE, 2.2, false)
	_centered(FONT_SCORE, HUD.group_digits(final_score), cx, 436.0, 34, VOLT, 0.0, false)

	if new_record:
		var glow := 0.6 + 0.4 * sin(_time * 5.0)
		var c := PULSE
		c.a = glow
		_centered(FONT_DISPLAY, "NEW RECORD", cx, 470.0, 14, c, 2.4, false)
	elif high_score > 0:
		_centered(FONT_UI, "BEST  %s" % HUD.group_digits(high_score), cx, 468.0, 9, SLATE, 1.8, false)


func _draw_button(button: Dictionary, hovered: bool) -> void:
	var rect := Rect2(button["rect"])
	var tint: Color = button["tint"]
	var label := str(button["label"])
	var value := str(button["value"])

	var bg := PANEL
	bg.a = 0.95
	draw_rect(rect, bg)

	if hovered:
		var glow := tint
		for i in 3:
			glow.a = 0.10 - float(i) * 0.028
			draw_rect(rect.grow(2.0 + float(i) * 3.0), glow)
		var fill := tint
		fill.a = 0.16
		draw_rect(rect, fill)

	var edge := tint if hovered else EDGE
	# Kant med hjørnemarkeringer, som et instrument.
	draw_rect(rect, edge, false, 1.0)
	var mark := tint
	mark.a = 1.0 if hovered else 0.6
	var m := 7.0
	for corner in [rect.position, Vector2(rect.end.x - m, rect.position.y),
			Vector2(rect.position.x, rect.end.y - 2.0), Vector2(rect.end.x - m, rect.end.y - 2.0)]:
		draw_rect(Rect2(corner, Vector2(m, 2.0)), mark)

	var text_color := tint if hovered else BONE
	var baseline := rect.get_center().y + 5.0
	if value.is_empty():
		_centered(FONT_DISPLAY, label, rect.get_center().x, baseline, 15, text_color, 2.2, false)
	else:
		_tracked(FONT_DISPLAY, label, Vector2(rect.position.x + 16.0, baseline), 13, text_color, 2.0)
		var vw := _tracked_width(FONT_DISPLAY, value, 13, 2.0)
		_tracked(FONT_DISPLAY, value, Vector2(rect.end.x - 16.0 - vw, baseline), 13,
			VOLT if value == "ON" else SLATE, 2.0)


# --- Tekst -------------------------------------------------------------

func _rule(cx: float, y: float, half_width: float, color: Color, alpha: float) -> void:
	var c := color
	c.a = alpha
	draw_rect(Rect2(cx - half_width, y, half_width * 2.0, 1.0), c)


func _centered(font: Font, text: String, cx: float, baseline: float, size: int,
		color: Color, tracking: float, shadow: bool) -> void:
	var width := _tracked_width(font, text, size, tracking)
	var at := Vector2(cx - width * 0.5, baseline)
	if shadow:
		_tracked(font, text, at + Vector2(2.0, 3.0), size, color.darkened(0.72), tracking)
	_tracked(font, text, at, size, color, tracking)


func _tracked_width(font: Font, text: String, size: int, tracking: float) -> float:
	var w := 0.0
	for i in text.length():
		w += font.get_string_size(text[i], HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
	return maxf(w - tracking, 0.0)


func _tracked(font: Font, text: String, at: Vector2, size: int, color: Color, tracking: float) -> void:
	var pen := at
	for i in text.length():
		var ch := text[i]
		draw_string(font, pen, ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size, color)
		pen.x += font.get_string_size(ch, HORIZONTAL_ALIGNMENT_LEFT, -1.0, size).x + tracking
