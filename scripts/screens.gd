class_name Screens
extends Node2D

## Everything the player sees that is not the game itself: title,
## settings, level intro, field cleared and signal lost.
##
## The screens do not own game state. They draw, take clicks and say so
## with a signal. The game decides what happens next.

signal action(name: String)

enum Screen { NONE, TITLE, SETTINGS, LEVEL_INTRO, LEVEL_CLEAR, SIGNAL_LOST }

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
## Telemetry for the SIGNAL LOST readout.
var bricks_cleared := 0
var best_combo := 0
var run_time := 0.0
var can_re_enter := true

var _reset_armed := false

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
	_reset_armed = false
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


# --- Buttons -----------------------------------------------------------

func _layout() -> void:
	_buttons.clear()
	var cx := screen_size.x * 0.5
	match current:
		Screen.TITLE:
			_add_button("play", "PLAY", Vector2(cx, 520.0), Vector2(220.0, 52.0), VOLT)
			_add_button("settings", "SETTINGS", Vector2(cx, 586.0), Vector2(220.0, 44.0), PULSE)
		Screen.SETTINGS:
			var s := _settings()
			var y := 262.0
			var step := 50.0
			var w := Vector2(300.0, 42.0)
			_add_button("toggle_sound", "SOUND", Vector2(cx, y), w, VOLT,
				_on_off(s and s.sound))
			_add_button("toggle_music", "MUSIC", Vector2(cx, y + step), w, VOLT,
				_on_off(s and s.music))
			_add_button("toggle_haptics", "HAPTICS", Vector2(cx, y + step * 2.0), w, VOLT,
				_on_off(s and s.haptics))
			_add_button("toggle_crt", "CRT MODE", Vector2(cx, y + step * 3.0), w, VOLT,
				_on_off(s and s.crt))
			_add_button("toggle_handed", "LEFT-HANDED UI", Vector2(cx, y + step * 4.0), w, VOLT,
				_on_off(s and s.left_handed))
			_add_button("reset_progress",
				"CONFIRM RESET" if _reset_armed else "RESET PROGRESS",
				Vector2(cx, y + step * 5.0), w, EMBER if _reset_armed else SLATE)
			_add_button("back", "BACK", Vector2(cx, y + step * 6.4), Vector2(180.0, 42.0), SLATE)
		Screen.SIGNAL_LOST:
			# Two ways on. There is no way back to a main menu from here.
			var order := ["re_entry", "restart"]
			if _settings() and _settings().left_handed:
				order.reverse()
			var labels := {"re_entry": "RE-ENTRY", "restart": "RESTART FIELD"}
			var tints := {"re_entry": VOLT, "restart": SLATE}
			for i in order.size():
				var id: String = order[i]
				if id == "re_entry" and not can_re_enter:
					continue
				_add_button(id, str(labels[id]), Vector2(cx, 592.0 + float(i) * 62.0),
					Vector2(240.0, 50.0), tints[id])


static func _on_off(value: bool) -> String:
	return "ON" if value else "OFF"


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
		var id := str(_buttons[_hover]["id"])
		if id == "reset_progress" and not _reset_armed:
			# Two presses. Erasing progress is not a thing you do by
			# brushing past a button.
			_reset_armed = true
			action.emit("arm_reset")
			get_viewport().set_input_as_handled()
			_layout()
			return
		if id != "reset_progress":
			_reset_armed = false
		action.emit(id)
		get_viewport().set_input_as_handled()
		_layout()


# --- Drawing -----------------------------------------------------------

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
		Screen.SIGNAL_LOST:
			# Section 16: the star field drops to 20 per cent behind it.
			_draw_curtain(0.8)
			_draw_signal_lost()
	for i in _buttons.size():
		_draw_button(_buttons[i], i == _hover)


## The field behind dims but never goes out. Space is still there while
## you choose.
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
	_centered(FONT_BRAND, "SETTINGS", cx, 208.0, 28, PULSE, 2.4, true)
	_rule(cx, 228.0, 120.0, PULSE, 0.45)

	var note := "CRT MODE ADDS SCANLINES AND VIGNETTE"
	if _reset_armed:
		note = "PRESS AGAIN TO ERASE ALL PROGRESS"
	_centered(FONT_UI, note, cx, 640.0, 8, EMBER if _reset_armed else SLATE, 1.4, false)


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


## Section 16. A readout, not a verdict. Telemetry from a vessel that
## stopped transmitting, and two ways to get it back.
func _draw_signal_lost() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, "SIGNAL LOST", cx, 296.0, 33, EMBER, 3.0, true)
	_rule(cx, 318.0, 150.0, EMBER, 0.6)

	var rows := [
		["BRICKS CLEARED", str(bricks_cleared)],
		["BEST COMBO", str(best_combo)],
		["TIME", format_time(run_time)],
		["SCORE", HUD.group_digits(final_score)],
	]
	var left := cx - 120.0
	var right := cx + 120.0
	var y := 374.0
	for row in rows:
		_tracked(FONT_UI, str(row[0]), Vector2(left, y), 10, SLATE, 1.8)
		var value := str(row[1])
		var vw := _tracked_width(FONT_SCORE, value, 14, 0.0)
		_tracked(FONT_SCORE, value, Vector2(right - vw, y), 14, BONE, 0.0)
		var line := EDGE
		line.a = 0.5
		draw_rect(Rect2(left, y + 6.0, right - left, 1.0), line)
		y += 30.0

	# The ghost line. Your own best, sitting quietly next to this run.
	if new_record:
		var glow := 0.6 + 0.4 * sin(_time * 5.0)
		var c := PULSE
		c.a = glow
		_centered(FONT_DISPLAY, "NEW RECORD", cx, y + 24.0, 15, c, 2.4, false)
	elif high_score > 0:
		_centered(FONT_UI, "BEST  %s" % HUD.group_digits(high_score), cx, y + 22.0, 10, SLATE, 1.8, false)


static func format_time(seconds: float) -> String:
	var total := int(maxf(seconds, 0.0))
	return "%02d:%02d" % [total / 60, total % 60]


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
	# An edge with corner marks, like an instrument.
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
		var value_color := VOLT if value == "ON" else SLATE
		var vw := _tracked_width(FONT_DISPLAY, value, 13, 2.0)
		var mirrored: bool = _settings() != null and bool(_settings().left_handed)
		if mirrored:
			_tracked(FONT_DISPLAY, value, Vector2(rect.position.x + 16.0, baseline), 13, value_color, 2.0)
			var lw := _tracked_width(FONT_DISPLAY, label, 13, 2.0)
			_tracked(FONT_DISPLAY, label, Vector2(rect.end.x - 16.0 - lw, baseline), 13, text_color, 2.0)
		else:
			_tracked(FONT_DISPLAY, label, Vector2(rect.position.x + 16.0, baseline), 13, text_color, 2.0)
			_tracked(FONT_DISPLAY, value, Vector2(rect.end.x - 16.0 - vw, baseline), 13, value_color, 2.0)


# --- Text --------------------------------------------------------------

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
