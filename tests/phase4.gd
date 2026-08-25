extends Node

## Phase 4: touch control, safe areas and haptics.
##
## None of this can be felt without a phone, so the parts that can be
## checked without one are checked hard: the tap and drag boundary, the
## acceleration curve, the delta arithmetic and its clamping, the safe
## area conversion, and that the haptics flag is honoured.

var fails := 0
var checks := 0


func _ready() -> void:
	seed(4242)
	_test_tap_or_drag()
	_test_acceleration()
	_test_relative_steering()
	_test_touch_events()
	_test_safe_area()
	_test_haptics()
	_test_launch()
	print("--- PHASE 4: %d checks, %d failures ---" % [checks, fails])
	for child in get_children():
		child.free()
	await get_tree().create_timer(0.3).timeout
	get_tree().quit(1 if fails > 0 else 0)


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("  FAIL: %s" % label)


func eq(got: Variant, want: Variant, label: String) -> void:
	checks += 1
	if got != want:
		fails += 1
		print("  FAIL: %s (got %s, wanted %s)" % [label, str(got), str(want)])


func about(got: float, want: float, tol: float, label: String) -> void:
	checks += 1
	if absf(got - want) > tol:
		fails += 1
		print("  FAIL: %s (got %.3f, wanted %.3f)" % [label, got, want])


# --- Tap or drag ---------------------------------------------------------

func _test_tap_or_drag() -> void:
	# Both conditions have to hold, not either. A launch that fires when
	# you meant to steer is the worst thing this scheme could do.
	ok(TouchInput.is_tap(149.0, 7.0), "149 ms over 7 px is a tap")
	ok(not TouchInput.is_tap(151.0, 9.0), "151 ms over 9 px is a drag")
	ok(not TouchInput.is_tap(149.0, 9.0), "long enough travel makes it a drag whatever the time")
	ok(not TouchInput.is_tap(151.0, 7.0), "long enough time makes it a drag whatever the travel")
	ok(TouchInput.is_tap(0.0, 0.0), "an instant still touch is a tap")
	ok(not TouchInput.is_tap(150.0, 0.0), "exactly the time limit is already a drag")
	ok(not TouchInput.is_tap(0.0, 8.0), "exactly the distance limit is already a drag")
	eq(TouchInput.TAP_MAX_MS, 150.0, "the tap window is 150 ms")
	eq(TouchInput.TAP_MAX_DISTANCE, 8.0, "and 8 px")


func _test_acceleration() -> void:
	about(TouchInput.acceleration(0.0), 1.0, 0.001, "a still finger is 1:1")
	about(TouchInput.acceleration(500.0), 1.0, 0.001, "a slow drag is 1:1")
	about(TouchInput.acceleration(TouchInput.ACCEL_FROM), 1.0, 0.001,
		"right at the threshold it is still 1:1")
	about(TouchInput.acceleration(TouchInput.ACCEL_TO), TouchInput.ACCEL_MAX, 0.001,
		"a full flick carries the most")
	about(TouchInput.acceleration(99999.0), TouchInput.ACCEL_MAX, 0.001,
		"and it never carries more than that")
	var midpoint := (TouchInput.ACCEL_FROM + TouchInput.ACCEL_TO) * 0.5
	about(TouchInput.acceleration(midpoint), (1.0 + TouchInput.ACCEL_MAX) * 0.5, 0.001,
		"the ramp between is straight")
	# Direction must not matter: a leftward flick accelerates too.
	about(TouchInput.acceleration(-TouchInput.ACCEL_TO), TouchInput.ACCEL_MAX, 0.001,
		"a leftward flick accelerates the same")
	# Monotonic, so the paddle never slows down as the finger speeds up.
	var previous := 0.0
	for i in 40:
		var value := TouchInput.acceleration(float(i) * 100.0)
		ok(value >= previous - 0.0001, "the curve never dips at %d px/s" % (i * 100))
		previous = value


# --- Relative steering ---------------------------------------------------

func _test_relative_steering() -> void:
	var paddle := Paddle.new()
	add_child(paddle)
	paddle.position = Vector2(195.0, 780.0)
	paddle.set_bounds(6.0, 384.0)
	paddle.set_width(Paddle.WIDTH_NORMAL)

	var start := paddle.position.x
	paddle.nudge(40.0)
	about(paddle.position.x, start + 40.0, 0.01, "the paddle moves BY the delta")
	paddle.nudge(-40.0)
	about(paddle.position.x, start, 0.01, "and back again")

	# The finger's absolute position is irrelevant: the same delta from
	# anywhere moves the paddle the same amount.
	paddle.position.x = 100.0
	paddle.nudge(25.0)
	about(paddle.position.x, 125.0, 0.01, "the delta is the same wherever the finger is")

	# Clamped at both edges, and a huge flick does not overshoot.
	paddle.nudge(-9999.0)
	about(paddle.position.x, paddle.min_x, 0.01, "clamped at the left edge")
	paddle.nudge(9999.0)
	about(paddle.position.x, paddle.max_x, 0.01, "clamped at the right edge")
	ok(paddle.world_rect().position.x >= Arena.WALL - 0.01,
		"and the paddle stays inside the field")
	ok(paddle.world_rect().end.x <= Arena.SCREEN.x - Arena.WALL + 0.01,
		"on both sides")

	# A wide paddle clamps to its own width, not the normal one.
	paddle.set_width(Paddle.WIDTH_WIDE)
	paddle.nudge(9999.0)
	ok(paddle.world_rect().end.x <= Arena.SCREEN.x - Arena.WALL + 0.01,
		"a wide paddle still stays inside the field")

	# Steering is off while a screen is up.
	paddle.set_width(Paddle.WIDTH_NORMAL)
	paddle.position.x = 195.0
	paddle.input_enabled = false
	paddle.nudge(50.0)
	about(paddle.position.x, 195.0, 0.01, "a disabled paddle ignores the finger")
	paddle.queue_free()


# --- The event flow ------------------------------------------------------

func _press(touch: TouchInput, index: int, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = true
	event.position = at
	touch._input(event)


func _release(touch: TouchInput, index: int, at: Vector2) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.pressed = false
	event.position = at
	touch._input(event)


func _drag(touch: TouchInput, index: int, relative: Vector2, speed := 0.0) -> void:
	var event := InputEventScreenDrag.new()
	event.index = index
	event.relative = relative
	event.velocity = Vector2(speed, 0.0)
	touch._input(event)


func _test_touch_events() -> void:
	var touch := TouchInput.new()
	add_child(touch)
	var log := {"steer": 0.0, "taps": 0}
	touch.steered.connect(func(dx: float): log["steer"] += dx)
	touch.tapped.connect(func(): log["taps"] += 1)

	# A slow drag steers 1:1 and never taps.
	_press(touch, 0, Vector2(200.0, 700.0))
	_drag(touch, 0, Vector2(30.0, 0.0), 100.0)
	about(float(log["steer"]), 30.0, 0.01, "a slow drag steers one for one")
	_release(touch, 0, Vector2(230.0, 700.0))
	eq(log["taps"], 0, "and travelling 30 px is never a tap")

	# Vertical movement does not steer, but it does count as travel, so
	# a vertical swipe is a drag and not a tap.
	log["steer"] = 0.0
	_press(touch, 0, Vector2(200.0, 700.0))
	_drag(touch, 0, Vector2(0.0, 40.0), 100.0)
	about(float(log["steer"]), 0.0, 0.01, "vertical movement does not steer")
	_release(touch, 0, Vector2(200.0, 740.0))
	eq(log["taps"], 0, "and a vertical swipe is not a tap")

	# A fast flick carries further than the finger moved.
	log["steer"] = 0.0
	_press(touch, 0, Vector2(200.0, 700.0))
	_drag(touch, 0, Vector2(30.0, 0.0), TouchInput.ACCEL_TO)
	about(float(log["steer"]), 30.0 * TouchInput.ACCEL_MAX, 0.01, "a flick carries further")
	_release(touch, 0, Vector2(230.0, 700.0))

	# A still touch taps.
	log["taps"] = 0
	_press(touch, 0, Vector2(200.0, 700.0))
	_release(touch, 0, Vector2(200.0, 700.0))
	eq(log["taps"], 1, "a still touch taps")

	# Multi-touch: the first finger steers, the second does not, but the
	# second can still tap while the first is dragging.
	log["steer"] = 0.0
	log["taps"] = 0
	_press(touch, 0, Vector2(120.0, 700.0))
	_drag(touch, 0, Vector2(20.0, 0.0), 100.0)
	_press(touch, 1, Vector2(300.0, 500.0))
	_drag(touch, 1, Vector2(60.0, 0.0), 100.0)
	about(float(log["steer"]), 20.0, 0.01, "the second finger does not steer")
	_release(touch, 1, Vector2(300.0, 500.0))
	eq(log["taps"], 0, "a second finger that travelled 60 px is not a tap either")
	_press(touch, 2, Vector2(320.0, 520.0))
	_release(touch, 2, Vector2(320.0, 520.0))
	eq(log["taps"], 1, "but a still second finger taps while the first drags")
	_drag(touch, 0, Vector2(10.0, 0.0), 100.0)
	about(float(log["steer"]), 30.0, 0.01, "and the first finger keeps steering")

	# Lifting the steering finger hands the wheel to one still down.
	_press(touch, 3, Vector2(80.0, 760.0))
	_release(touch, 0, Vector2(150.0, 700.0))
	log["steer"] = 0.0
	_drag(touch, 3, Vector2(15.0, 0.0), 100.0)
	about(float(log["steer"]), 15.0, 0.01, "the remaining finger takes over steering")
	_release(touch, 3, Vector2(95.0, 760.0))

	# Disabled: a screen is up. Nothing steers, nothing taps.
	touch.enabled = false
	log["steer"] = 0.0
	log["taps"] = 0
	_press(touch, 0, Vector2(200.0, 700.0))
	_drag(touch, 0, Vector2(50.0, 0.0), 100.0)
	_release(touch, 0, Vector2(200.0, 700.0))
	about(float(log["steer"]), 0.0, 0.01, "a disabled surface does not steer")
	eq(log["taps"], 0, "and does not tap")
	touch.enabled = true

	# reset() forgets a finger mid-drag, so the touch that dismissed a
	# screen cannot go on to steer.
	_press(touch, 0, Vector2(200.0, 700.0))
	touch.reset()
	log["steer"] = 0.0
	_drag(touch, 0, Vector2(50.0, 0.0), 100.0)
	# The drag is adopted as a fresh finger, so it steers from here on,
	# but the tap that would have fired on release is gone.
	log["taps"] = 0
	_release(touch, 0, Vector2(250.0, 700.0))
	eq(log["taps"], 0, "a forgotten finger cannot tap on release")

	ok(touch.seen_touch, "the game knows this device has a touch screen")
	touch.queue_free()


# --- Safe area -----------------------------------------------------------

func _test_safe_area() -> void:
	# A window exactly the logical size and no insets.
	about(SafeArea.insets_from(Vector2i(390, 844), Rect2i(0, 0, 390, 844)).x, 0.0, 0.01,
		"no notch means no top inset")

	# An iPhone-shaped window at 3x with a Dynamic Island and a home
	# indicator. 390x844 logical maps 1:1 at scale 3, no letterbox.
	var insets := SafeArea.insets_from(Vector2i(1170, 2532), Rect2i(0, 177, 1170, 2253))
	about(insets.x, 59.0, 0.5, "the Dynamic Island converts to 59 logical px")
	about(insets.y, 34.0, 0.5, "and the home indicator to 34")

	# A taller window letterboxes: the bar absorbs part of the inset.
	var letterboxed := SafeArea.insets_from(Vector2i(1170, 2700), Rect2i(0, 177, 1170, 2400))
	ok(letterboxed.x < insets.x,
		"a letterbox bar absorbs part of the inset (%.1f < %.1f)" % [letterboxed.x, insets.x])
	ok(letterboxed.x >= 0.0, "and it never goes negative")

	# Degenerate input must not produce nonsense.
	about(SafeArea.insets_from(Vector2i(0, 0), Rect2i(0, 0, 0, 0)).x, 0.0, 0.01,
		"a zero window is zero insets")

	# The panel and the warning line move with it, and the whole layout
	# follows because the sky is measured from the frame.
	eq(Arena.HUD_HEIGHT, Arena.HUD_BASE_HEIGHT, "on desktop the panel is its designed height")
	# A 59 px island is already inside the panel's own content margin, so
	# it must not move the layout. Only something bigger should.
	ok(Arena.CONTENT_TOP >= 59.0, "the content margin already clears a Dynamic Island")
	about(Arena.ember_line_y(), Arena.EMBER_LINE_BASE, 0.01,
		"and the warning line sits where it was drawn")


# --- Haptics -------------------------------------------------------------

func _test_haptics() -> void:
	var feel := GameFeel.new()
	add_child(feel)
	var settings := get_node("/root/GameSettings")
	var was: bool = settings.haptics

	settings.haptics = true
	ok(feel.pulse(GameFeel.HAPTIC_BRICK), "a brick pulses when haptics are on")
	ok(not feel.pulse(0), "and a zero length pulse does nothing")

	settings.haptics = false
	ok(not feel.pulse(GameFeel.HAPTIC_BRICK), "nothing pulses when haptics are off")
	ok(not feel.pulse(GameFeel.HAPTIC_BLAST), "not even an explosion")

	settings.haptics = true

	# Section 17 lengths: you should feel the difference between a brick
	# and an explosion without looking.
	eq(GameFeel.HAPTIC_BRICK, 10, "a brick is 10 ms")
	eq(GameFeel.HAPTIC_PADDLE, 8, "the paddle is 8 ms")
	eq(GameFeel.HAPTIC_BLAST, 30, "an explosion is 30 ms")
	eq(GameFeel.HAPTIC_BALL_LOST, 50, "a lost ball is 50 ms")
	eq(GameFeel.HAPTIC_POWERUP, 15, "a power-up is 15 ms")
	ok(GameFeel.HAPTIC_BLAST > GameFeel.HAPTIC_BRICK,
		"and an explosion is longer than a brick")

	# The flag survives a restart.
	settings.haptics = false
	settings.save_settings()
	settings.haptics = true
	settings.load_settings()
	eq(settings.haptics, false, "the haptics flag survives a restart")
	settings.haptics = was
	settings.save_settings()
	feel.queue_free()


## The way in. The engine's own boot screen is a grey card with a logo on
## it, and it sits between the home screen and the game. These settings
## paint it in the game's own void instead, and the title screen opens
## out of that same darkness. The values are asserted because the Godot
## editor rewrites project.godot from memory when it closes, and a
## silently restored logo would only show up on a device.
func _test_launch() -> void:
	var void_color := Color("07070C")
	ok(not bool(ProjectSettings.get_setting("application/boot_splash/show_image", true)),
		"no engine logo on the way in")
	var splash: Color = ProjectSettings.get_setting("application/boot_splash/bg_color", Color.BLACK)
	ok(splash.is_equal_approx(void_color),
		"the boot screen is the game's own void (%s)" % splash.to_html(false))
	var clear: Color = ProjectSettings.get_setting("rendering/environment/defaults/default_clear_color", Color.BLACK)
	ok(clear.is_equal_approx(void_color), "and so is the first thing the renderer paints")
	ok(int(ProjectSettings.get_setting("application/boot_splash/minimum_display_time", 0)) == 0,
		"nothing is held on screen on purpose")

	# iOS shows its own launch screen before Godot gets a frame. It is
	# generated at export time from the preset, so the preset has to
	# agree with the two settings above or there is a seam.
	var cfg := ConfigFile.new()
	ok(cfg.load("res://export_presets.cfg") == OK, "the iOS preset is readable")
	ok(bool(cfg.get_value("preset.0.options", "storyboard/use_custom_bg_color", false)),
		"the iOS launch screen sets its own colour")
	var story: Color = cfg.get_value("preset.0.options", "storyboard/custom_bg_color", Color.BLACK)
	ok(story.is_equal_approx(void_color),
		"and it is the same void as the rest (%s)" % story.to_html(false))
	# And nothing on it. An empty image field does not mean no image: the
	# exporter falls back to the engine's own splash, which is how the
	# Godot robot kept turning up on the phone long after the boot screen
	# had been switched off. The blank is a transparent 8x8.
	for key in ["storyboard/custom_image@2x", "storyboard/custom_image@3x"]:
		var image := str(cfg.get_value("preset.0.options", key, ""))
		ok(image.ends_with("launch_blank.png"), "%s is the blank, not the engine's logo" % key)
		ok(ResourceLoader.exists(image) or FileAccess.file_exists(image),
			"and the blank is in the project")
	# Read as bytes rather than through the resource loader: loading a
	# PNG as an image file warns that it will not work on export, and it
	# is not being loaded for the game, only inspected.
	# Export compliance, answered once in the build rather than by hand on
	# every upload. Without it App Store Connect holds each build as
	# "Missing Compliance" and it cannot be given to a tester.
	var plist := str(cfg.get_value("preset.0.options", "application/additional_plist_content", ""))
	ok(plist.contains("ITSAppUsesNonExemptEncryption"),
		"the build answers the encryption question itself")
	ok(plist.contains("<false/>"), "and the answer is no")

	var blank := Image.new()
	var bytes := FileAccess.get_file_as_bytes("res://assets/icons/launch_blank.png")
	ok(blank.load_png_from_buffer(bytes) == OK, "the blank loads")
	if blank.get_width() > 0:
		var opaque := false
		for y in blank.get_height():
			for x in blank.get_width():
				if blank.get_pixel(x, y).a > 0.0:
					opaque = true
		ok(not opaque, "and there is nothing in it")

	# And the first frame the player actually sees is that same darkness:
	# the title's curtain starts solid and settles, rather than catching
	# the sky at full brightness and dimming it.
	var screens := Screens.new()
	add_child(screens)
	screens.show_screen(Screens.Screen.TITLE)
	screens._fade = 0.0
	ok(screens.curtain_alpha(0.82) >= 0.999, "the title opens solid")
	screens._fade = 1.0
	ok(absf(screens.curtain_alpha(0.82) - 0.82) < 0.001, "and settles to its normal weight")
	screens.queue_free()
