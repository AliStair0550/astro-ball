class_name Screens
extends Node2D

## Everything the player sees that is not the game itself: title,
## settings, level intro, field cleared and signal lost.
##
## The screens do not own game state. They draw, take clicks and say so
## with a signal. The game decides what happens next.

signal action(name: String)

enum Screen { NONE, TITLE, UNIVERSES, SETTINGS, PAUSED, LEVEL_INTRO, LEVEL_CLEAR, SIGNAL_LOST }

const FONT_BRAND := preload("res://assets/fonts/Unbounded-900.ttf")
const FONT_DISPLAY := preload("res://assets/fonts/Unbounded-700.ttf")
const FONT_SCORE := preload("res://assets/fonts/SpaceGrotesk-700.ttf")
const FONT_UI := preload("res://assets/fonts/SpaceGrotesk-500.ttf")

const VOID := Color("07070C")
const BONE := Color("F2EFE6")
const VOLT := Color("D6FF3D")
const PULSE := Color("B57BFF")
const PULSE_DEEP := Color("3D2168")
const ICE := Color("4DD8FF")
const EMBER := Color("FF4D2E")
const SLATE := Color("888780")
const PANEL := Color("11111A")
const EDGE := Color("2A2A3A")

var screen_size := Vector2(390.0, 844.0)
var current := Screen.NONE

var level_number := 1
var level_title := ""
var zone_slug := "baeltet"
var final_score := 0
var high_score := 0
var new_record := false
## Telemetry for the SIGNAL LOST readout.
## Section 15. Which stars this run earned, and which the level has in
## total once merged. Shown on FIELD CLEARED, one at a time, because
## earning three at once and being told so in a single frame is not the
## same feeling as watching the third one land.
var stars_earned := 0
var stars_total := 0
var level_time := 0.0
var par_time := 0.0

var bricks_cleared := 0
var best_combo := 0
var run_time := 0.0
var can_re_enter := true
## What a re-entry costs right now, from ContinueGate. Only changes the
## label; the gate decides whether it is offered at all.
var re_entry_costs_ad := false

## One entry per universe, filled by the game before the screen opens:
## {"name", "note", "open", "levels", "cleared"}.
var universes: Array[Dictionary] = []
var _reset_armed := false
## Once a finger has touched the screen, the mouse is a fiction Godot
## keeps up for us, and following it lights up buttons nobody is over.
var _touch_seen := false

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


func _progress() -> Node:
	return get_node_or_null("/root/GameProgress")


## Has this save anything in it yet. Asked at layout time rather than
## pushed in, so RESET PROGRESS cannot leave a CONTINUE button behind.
func has_progress() -> bool:
	var p := _progress()
	if p == null:
		return false
	for key in p.levels:
		var entry: Dictionary = p.levels[key]
		if int(entry.get("stars", 0)) & p.STAR_CLEARED:
			return true
	return false


# --- Buttons -----------------------------------------------------------

func _layout() -> void:
	_buttons.clear()
	var cx := screen_size.x * 0.5
	match current:
		Screen.TITLE:
			# Two choices. Start, or change how it behaves. Where to start
			# is the next screen's question, not this one's.
			_add_button("play", Strings.text("BTN_PLAY"),
				Vector2(cx, 516.0), Vector2(240.0, 54.0), VOLT)
			_add_button("settings", Strings.text("BTN_SETTINGS"),
				Vector2(cx, 582.0), Vector2(240.0, 46.0), PULSE)
		Screen.UNIVERSES:
			# One place per universe, down the path that runs inward
			# through the system. The open one is a button; the rest are
			# there to be seen, not pressed.
			var y := 286.0
			for i in universes.size():
				var entry: Dictionary = universes[i]
				var open := bool(entry.get("open", false))
				var value := str(entry.get("note", ""))
				_add_button("universe_%d" % (i + 1), str(entry.get("name", "")),
					Vector2(cx, y + float(i) * 76.0), Vector2(320.0, 66.0),
					Cosmos.tint_of(i),
					"%s · %s" % [Strings.fmt("UNIVERSE_NUMBER", [i + 1]), value], open)
			_add_button("back", Strings.text("BTN_BACK"),
				Vector2(cx, y + float(universes.size()) * 76.0 + 6.0), Vector2(180.0, 42.0), SLATE)
		Screen.SETTINGS:
			var s := _settings()
			var y := 262.0
			var step := 50.0
			var w := Vector2(300.0, 42.0)
			_add_button("toggle_sound", Strings.text("SET_SOUND"), Vector2(cx, y), w, VOLT,
				_on_off(s and s.sound), s != null and bool(s.sound))
			_add_button("toggle_music", Strings.text("SET_MUSIC"), Vector2(cx, y + step), w, VOLT,
				_on_off(s and s.music), s != null and bool(s.music))
			_add_button("toggle_haptics", Strings.text("SET_HAPTICS"), Vector2(cx, y + step * 2.0), w, VOLT,
				_on_off(s and s.haptics), s != null and bool(s.haptics))
			_add_button("toggle_crt", Strings.text("SET_CRT"), Vector2(cx, y + step * 3.0), w, VOLT,
				_on_off(s and s.crt), s != null and bool(s.crt))
			_add_button("toggle_handed", Strings.text("SET_LEFT_HANDED"), Vector2(cx, y + step * 4.0), w, VOLT,
				_on_off(s and s.left_handed), s != null and bool(s.left_handed))
			_add_button("reset_progress",
				Strings.text("SET_RESET_ARMED") if _reset_armed else Strings.text("SET_RESET"),
				Vector2(cx, y + step * 5.0), w, EMBER if _reset_armed else SLATE)
			_add_button("back", Strings.text("BTN_BACK"), Vector2(cx, y + step * 6.4), Vector2(180.0, 42.0), SLATE)
		Screen.PAUSED:
			# The first is always the way back in: a pause is not a menu
			# you meant to open. Settings is not here, because a held
			# field is not where anybody goes to change the haptics.
			_add_button("resume", Strings.text("BTN_RESUME"), Vector2(cx, 476.0), Vector2(240.0, 54.0), VOLT)
			_add_button("restart", Strings.text("BTN_RESTART_FIELD"), Vector2(cx, 542.0), Vector2(240.0, 44.0), SLATE)
			_add_button("chart", Strings.text("BTN_LEVELS"), Vector2(cx, 596.0), Vector2(240.0, 44.0), ICE)
		Screen.SIGNAL_LOST:
			# Two ways on. There is no way back to a main menu from here.
			var order := ["re_entry", "restart"]
			if _settings() and _settings().left_handed:
				order.reverse()
			var labels := {
				"re_entry": Strings.text("BTN_RE_ENTRY_AD" if re_entry_costs_ad else "BTN_RE_ENTRY"),
				"restart": Strings.text("BTN_RESTART_FIELD"),
			}
			var tints := {"re_entry": VOLT, "restart": SLATE}
			for i in order.size():
				var id: String = order[i]
				if id == "re_entry" and not can_re_enter:
					continue
				_add_button(id, str(labels[id]), Vector2(cx, 592.0 + float(i) * 62.0),
					Vector2(260.0, 50.0), tints[id])


static func _on_off(value: bool) -> String:
	return Strings.text("ON") if value else Strings.text("OFF")


func _add_button(id: String, label: String, center: Vector2, size: Vector2, tint: Color,
		value := "", value_on := false) -> void:
	_buttons.append({
		"id": id,
		"label": label,
		"value": value,
		# Carried, not re-derived from the text. Comparing the rendered
		# word against a literal would break the moment that word is
		# renamed in the strings file, which is the one file a rename is
		# supposed to touch.
		"value_on": value_on,
		"rect": Rect2(center - size * 0.5, size),
		"tint": tint,
	})


func _process(delta: float) -> void:
	if not visible:
		return
	_time += delta
	_fade = minf(1.0, _fade + delta * 7.0)

	if not _touch_seen:
		var mouse := get_viewport().get_mouse_position()
		var was := _hover
		_hover = button_at(mouse)
		if _hover != was and _hover >= 0:
			action.emit("hover")
	queue_redraw()


## Which button is under a point, or -1.
func button_at(point: Vector2) -> int:
	for i in _buttons.size():
		if Rect2(_buttons[i]["rect"]).has_point(point):
			return i
	return -1


## The press acts on where the finger landed, never on _hover.
##
## _hover is worked out once a frame from the mouse position, and on a
## touch screen there is no mouse until a finger arrives. So the first
## press of a screen found _hover still -1 and did nothing, and the
## second one worked: every button needed pressing twice. Worse, after
## coming back from settings _hover still held the button that had been
## under the last press, so pressing START GAME opened settings again.
func _unhandled_input(event: InputEvent) -> void:
	if not visible:
		return
	var point := Vector2.INF
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		point = event.position
	elif event is InputEventScreenTouch and event.pressed:
		point = event.position
		_touch_seen = true
		_hover = -1
	if point == Vector2.INF:
		return

	if current == Screen.LEVEL_INTRO or current == Screen.LEVEL_CLEAR:
		action.emit("skip")
		get_viewport().set_input_as_handled()
		return

	var index := button_at(point)
	if index >= 0:
		_hover = index
		var id := str(_buttons[index]["id"])
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
		# The layout that follows belongs to a screen the finger has
		# never been near, so nothing is under it until it moves again.
		_hover = -1


# --- Drawing -----------------------------------------------------------

func _draw() -> void:
	match current:
		Screen.TITLE:
			_draw_curtain_in(0.82)
			_draw_title()
		Screen.UNIVERSES:
			_draw_curtain(0.78)
			_draw_universes()
		Screen.SETTINGS:
			_draw_curtain(0.9)
			_draw_settings()
		Screen.PAUSED:
			# Lighter than the settings curtain. The field is still
			# yours, and it should still be there behind the words.
			_draw_curtain(0.7)
			_draw_paused()
		Screen.LEVEL_INTRO:
			_draw_curtain(0.62)
			_draw_level_intro()
		Screen.LEVEL_CLEAR:
			# Heavier than it was. The readout is the point here, and a
			# thin curtain let the field argue with it.
			_draw_curtain(0.78)
			_draw_level_clear()
		Screen.SIGNAL_LOST:
			# Section 16: the star field drops to 20 per cent behind it.
			_draw_curtain(0.8)
			_draw_signal_lost()
	for i in _buttons.size():
		if str(_buttons[i]["id"]).begins_with("universe_"):
			_draw_universe_tile(_buttons[i], i == _hover)
		else:
			_draw_button(_buttons[i], i == _hover)


## The field behind dims but never goes out. Space is still there while
## you choose.
func _draw_curtain(strength: float) -> void:
	var c := VOID
	c.a = strength * _fade
	draw_rect(Rect2(-20.0, -20.0, screen_size.x + 40.0, screen_size.y + 40.0), c)


## The title comes the other way: solid at first, settling to its normal
## weight. The app opens on the same void the boot screen is painted in,
## so there is no seam between the two, and the sky arrives rather than
## being caught mid-dim.
func _draw_curtain_in(strength: float) -> void:
	var c := VOID
	c.a = curtain_alpha(strength)
	draw_rect(Rect2(-20.0, -20.0, screen_size.x + 40.0, screen_size.y + 40.0), c)


func curtain_alpha(strength: float) -> float:
	return lerpf(1.0, strength, _fade)


## The name arrives rather than simply being there. Two lines rising a
## beat apart, then the rule drawing itself, then the tagline. Under a
## second in total, and it is the difference between a screen and an
## opening.
func _draw_title() -> void:
	var cx := screen_size.x * 0.5

	# The reveal takes the first quarter second. Nothing arrives during
	# it, because nothing can be seen through a solid screen.
	var t := _time - 0.22
	var line_1 := ease(clampf(t / 0.35, 0.0, 1.0), 0.35)
	var line_2 := ease(clampf((t - 0.12) / 0.35, 0.0, 1.0), 0.35)
	var rule_in := ease(clampf((t - 0.34) / 0.30, 0.0, 1.0), 0.4)
	var tag_in := ease(clampf((t - 0.50) / 0.35, 0.0, 1.0), 0.4)

	_centered(FONT_BRAND, Strings.text("BRAND_LINE_1"), cx,
		268.0 + (1.0 - line_1) * 22.0, 52, Color(PULSE, line_1), 3.0, true)
	_centered(FONT_BRAND, Strings.text("BRAND_LINE_2"), cx,
		326.0 + (1.0 - line_2) * 22.0, 52, Color(PULSE, line_2), 3.0, true)
	_rule(cx, 348.0, 150.0 * rule_in, PULSE, 0.55 * rule_in)
	_centered(FONT_UI, Strings.text("TAGLINE"), cx, 378.0, 11, Color(SLATE, tag_in), 2.4, false)

	var p := _progress()
	if p and int(p.high_score) > 0:
		_centered(FONT_UI, Strings.text("BEST"), cx, 664.0, 9, SLATE, 2.0, false)
		_centered(FONT_SCORE, HUD.group_digits(int(p.high_score)), cx, 692.0, 20, VOLT, 0.0, false)

	var blink := 0.55 + 0.45 * sin(_time * 3.0)
	var hint := SLATE
	hint.a = blink * 0.8
	_centered(FONT_UI, Strings.text("HINT_TITLE"), cx, 760.0, 9, hint, 1.8, false)


func _draw_universes() -> void:
	var cx := screen_size.x * 0.5
	# The wash of whichever place the finger is over, so the screen takes
	# a temperature from what you are about to enter.
	var focus := _hover
	if focus >= 0 and focus < universes.size():
		Cosmos.draw_wash(self, Vector2(cx, 200.0 + float(focus) * 76.0), 260.0,
			Cosmos.tint_of(focus), 0.10)
	_centered(FONT_BRAND, Strings.text("UNIVERSE_SELECT"), cx, 232.0, 19, PULSE, 2.2, true)
	_rule(cx, 250.0, 130.0, PULSE, 0.45)

	# The path inward. Section 1: you break through, zone by zone, toward
	# the centre of the system, and the line says so before the names do.
	var tiles: Array[Rect2] = []
	for button in _buttons:
		if str(button["id"]).begins_with("universe_"):
			tiles.append(Rect2(button["rect"]))
	if tiles.size() >= 2:
		var x := tiles[0].position.x + 42.0
		var top := tiles[0].get_center().y
		var bottom := tiles[tiles.size() - 1].get_center().y
		var path := Color("2A2A3A")
		draw_line(Vector2(x, top), Vector2(x, bottom), path, 1.0)


## A universe is a place with a name and a line about where you are in
## it. The name gets the row; the line sits under it. Nothing shares a
## line with anything else, which is what went wrong when this borrowed
## the settings row and the two texts met in the middle.
## A universe is a place. It gets its own sky, its own light, and a name
## beside it. A row with a label on it is a filing system.
func _draw_universe_tile(button: Dictionary, hovered: bool) -> void:
	var rect := Rect2(button["rect"])
	var tint: Color = button["tint"]
	var open := bool(button.get("value_on", false))
	var index := int(str(button["id"]).get_slice("_", 1)) - 1
	var lit := 1.0 if open else 0.30

	var bg := PANEL
	bg.a = 0.88 if open else 0.55
	draw_rect(rect, bg)
	if open:
		var wash := tint
		wash.a = 0.05 + (0.05 if hovered else 0.0)
		draw_rect(rect, wash)
	if hovered and open:
		var glow := tint
		for i in 3:
			glow.a = 0.09 - float(i) * 0.026
			draw_rect(rect.grow(2.0 + float(i) * 3.0), glow)
	draw_rect(rect, tint if hovered and open else EDGE, false, 1.0)

	var body_at := Vector2(rect.position.x + 42.0, rect.get_center().y)
	Cosmos.draw_body(self, index, body_at, 24.0, lit, _time + float(index) * 3.0)

	var text_x := rect.position.x + 82.0
	_tracked(FONT_DISPLAY, str(button["label"]),
		Vector2(text_x, rect.get_center().y - 1.0), 15, BONE if open else SLATE, 2.0)
	_tracked(FONT_UI, str(button["value"]),
		Vector2(text_x, rect.get_center().y + 16.0), 8,
		tint if open else Color("4A4A58"), 1.8)

	# The way in, drawn rather than written.
	if open:
		var arrow := tint
		arrow.a = 0.9 if hovered else 0.6
		var at := Vector2(rect.end.x - 20.0, rect.get_center().y)
		var nudge := 2.0 * (1.0 if hovered else 0.0)
		draw_colored_polygon(PackedVector2Array([
			at + Vector2(-3.0 + nudge, -7.0), at + Vector2(5.0 + nudge, 0.0),
			at + Vector2(-3.0 + nudge, 7.0), at + Vector2(-6.0 + nudge, 4.0),
			at + Vector2(-1.0 + nudge, 0.0), at + Vector2(-6.0 + nudge, -4.0),
		]), arrow)


func _draw_settings() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, Strings.text("SETTINGS_TITLE"), cx, 208.0, 28, PULSE, 2.4, true)
	_rule(cx, 228.0, 120.0, PULSE, 0.45)

	var note := Strings.text("NOTE_CRT")
	if _reset_armed:
		note = Strings.text("NOTE_RESET")
	_centered(FONT_UI, note, cx, 640.0, 8, EMBER if _reset_armed else SLATE, 1.4, false)


## One word and the way out. The score and the level were repeated here
## from the panel two inches above, and a pause screen that has to be
## read is a pause screen in the way.
func _draw_paused() -> void:
	var cx := screen_size.x * 0.5
	# A band under the word, fading out at both edges. The field is meant
	# to stay visible, but a white word on a wall of bricks is a word you
	# have to hunt for.
	for i in 4:
		var band := VOID
		band.a = (0.62 - float(i) * 0.14) * _fade
		draw_rect(Rect2(0.0, 376.0 - float(i) * 5.0, screen_size.x, 56.0 + float(i) * 10.0), band)
	_centered(FONT_BRAND, Strings.text("PAUSED"), cx, 404.0, 26, BONE, 3.2, true)
	_rule(cx, 424.0, 90.0, VOLT, 0.5)


func _draw_level_intro() -> void:
	var cx := screen_size.x * 0.5
	# "LEVEL" large, then the field's name.
	var rise := (1.0 - ease(minf(_time / 0.35, 1.0), 0.35)) * 14.0
	_centered(FONT_UI, Strings.universe_line(zone_slug), cx, 344.0, 10, SLATE, 2.2, false)
	_centered(FONT_BRAND, Strings.fmt("LEVEL_NUMBER", [level_number]), cx, 392.0 - rise, 40, BONE, 3.0, true)
	_rule(cx, 414.0, 110.0, VOLT, 0.7)
	_centered(FONT_DISPLAY, level_title.to_upper(), cx, 456.0 + rise * 0.5, 22, VOLT, 3.0, true)

	var blink := 0.4 + 0.6 * sin(_time * 4.0)
	var hint := SLATE
	hint.a = blink * 0.7
	_centered(FONT_UI, Strings.text("HINT_BEGIN"), cx, 540.0, 9, hint, 2.0, false)


func _draw_level_clear() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, Strings.text("FIELD_CLEARED"), cx, 330.0, 26, VOLT, 2.6, true)
	_rule(cx, 350.0, 130.0, VOLT, 0.6)
	_centered(FONT_UI, Strings.fmt("LEVEL_AND_NAME", [level_number, level_title.to_upper()]),
		cx, 376.0, 10, SLATE, 2.0, false)

	# The score climbs rather than appearing. A number that arrives all
	# at once is information; a number that climbs is a reward.
	var climb := ease(clampf(_time / 0.9, 0.0, 1.0), 0.4)
	_centered(FONT_SCORE, HUD.group_digits(int(round(float(final_score) * climb))),
		cx, 424.0, 28, BONE, 0.0, false)

	# The three stars land one at a time, half a second apart.
	var rows := [
		[GameProgressBits.CLEARED, "STAR_CLEARED", ""],
		[GameProgressBits.UNDER_PAR, "STAR_UNDER_PAR", Strings.fmt("PAR_TIME", [format_time(par_time)])],
		[GameProgressBits.NO_LOSS, "STAR_NO_LOSS", ""],
	]
	var y := 486.0
	for i in rows.size():
		var bit: int = rows[i][0]
		var earned := (stars_earned & bit) != 0
		var had := (stars_total & bit) != 0 and not earned
		var landed := _time > 0.55 + float(i) * 0.34
		var pop := clampf((_time - (0.55 + float(i) * 0.34)) / 0.25, 0.0, 1.0)

		var mark := Vector2(cx - 92.0, y + float(i) * 34.0)
		_draw_star(mark, earned and landed, had, pop)

		var label_color := SLATE
		if earned and landed:
			label_color = VOLT
		elif had:
			label_color = Color("55545C")
		_tracked(FONT_UI, Strings.text(str(rows[i][1])),
			Vector2(cx - 72.0, y + float(i) * 34.0 + 4.0), 10, label_color, 1.6)
		if not str(rows[i][2]).is_empty():
			var note_w := _tracked_width(FONT_UI, str(rows[i][2]), 8, 1.2)
			_tracked(FONT_UI, str(rows[i][2]),
				Vector2(cx + 92.0 - note_w, y + float(i) * 34.0 + 4.0), 8, Color("55545C"), 1.2)

	if _time > 2.3:
		_centered(FONT_UI, Strings.text("HINT_CONTINUE"), cx, 640.0, 9,
			Color(SLATE, 0.4 + 0.6 * sin(_time * 4.0)), 2.0, false)


## A diamond, the same shape the HUD uses. Earned lands with a flash,
## already-had sits quietly, unearned is an empty outline.
func _draw_star(at: Vector2, earned: bool, had: bool, pop: float) -> void:
	var size := 9.0
	if earned:
		size = lerpf(20.0, 9.0, ease(pop, 0.3))
		var glow := VOLT
		for i in 3:
			glow.a = (0.30 - float(i) * 0.08) * (1.0 - pop * 0.6)
			var pad := size + 4.0 + float(i) * 5.0
			draw_colored_polygon(_diamond(at, pad), glow)
	elif had:
		size = 8.0
	var color := VOLT if earned else (Color("4A4A58") if had else Color("22222C"))
	draw_colored_polygon(_diamond(at, size), color)
	if not earned and not had:
		draw_polyline(_diamond(at, size) + PackedVector2Array([at + Vector2(0.0, -size)]),
			Color("35354200"), 1.0)


static func _diamond(at: Vector2, size: float) -> PackedVector2Array:
	return PackedVector2Array([
		at + Vector2(0.0, -size), at + Vector2(size, 0.0),
		at + Vector2(0.0, size), at + Vector2(-size, 0.0),
	])


## The star bits, mirrored so the screens do not need the autoload.
class GameProgressBits:
	const CLEARED := 1
	const UNDER_PAR := 2
	const NO_LOSS := 4


## Section 16. A readout, not a verdict. Telemetry from a vessel that
## stopped transmitting, and two ways to get it back.
func _draw_signal_lost() -> void:
	var cx := screen_size.x * 0.5
	_centered(FONT_BRAND, Strings.text("SIGNAL_LOST"), cx, 296.0, 33, EMBER, 3.0, true)
	_rule(cx, 318.0, 150.0, EMBER, 0.6)

	# Each line arrives in turn, and the two counters climb to their
	# figure. A readout that lands all at once is a receipt.
	var reveal := func(index: int) -> float:
		return ease(clampf((_time - 0.25 - float(index) * 0.18) / 0.4, 0.0, 1.0), 0.4)
	var rows := [
		[Strings.text("STAT_BRICKS"), str(int(round(float(bricks_cleared) * reveal.call(0)))), reveal.call(0)],
		[Strings.text("STAT_COMBO"), str(best_combo), reveal.call(1)],
		[Strings.text("STAT_TIME"), format_time(run_time), reveal.call(2)],
		[Strings.text("STAT_SCORE"), HUD.group_digits(int(round(float(final_score) * reveal.call(3)))), reveal.call(3)],
	]
	var left := cx - 120.0
	var right := cx + 120.0
	var y := 374.0
	for row in rows:
		var fade := float(row[2])
		if fade <= 0.01:
			y += 30.0
			continue
		_tracked(FONT_UI, str(row[0]), Vector2(left, y), 10, Color(SLATE, fade), 1.8)
		var value := str(row[1])
		var vw := _tracked_width(FONT_SCORE, value, 14, 0.0)
		_tracked(FONT_SCORE, value, Vector2(right - vw, y), 14, Color(BONE, fade), 0.0)
		var line := EDGE
		line.a = 0.5 * fade
		draw_rect(Rect2(left, y + 6.0, (right - left) * fade, 1.0), line)
		y += 30.0

	# The ghost line. Your own best, sitting quietly next to this run.
	if new_record:
		var glow := 0.6 + 0.4 * sin(_time * 5.0)
		var c := PULSE
		c.a = glow
		_centered(FONT_DISPLAY, Strings.text("NEW_RECORD"), cx, y + 24.0, 15, c, 2.4, false)
	elif high_score > 0:
		_centered(FONT_UI, Strings.fmt("BEST_VALUE", [HUD.group_digits(high_score)]), cx, y + 22.0, 10, SLATE, 1.8, false)


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
		var value_color := VOLT if bool(button.get("value_on", false)) else SLATE
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
