class_name SafeArea
extends RefCounted

## The notch, the Dynamic Island and the home indicator, expressed in the
## game's own 390x844 logical pixels.
##
## The viewport is letterboxed inside the window with aspect `keep`, so a
## screen inset has to be converted twice: subtract the letterbox margin,
## then divide by the scale. Getting that wrong puts the score under the
## Dynamic Island on exactly the devices nobody tests on.
##
## Zero everywhere that has no notch, which is every desktop, so the
## layout and the whole test suite are unchanged there.

const LOGICAL := Vector2(390.0, 844.0)


## Insets in logical pixels as (top, bottom).
static func insets() -> Vector2:
	if not OS.has_feature("mobile"):
		return Vector2.ZERO
	var window := DisplayServer.window_get_size()
	if window.x <= 0 or window.y <= 0:
		return Vector2.ZERO
	var safe := DisplayServer.get_display_safe_area()
	if safe.size.x <= 0 or safe.size.y <= 0:
		return Vector2.ZERO
	return insets_from(window, safe)


## The arithmetic on its own, so it can be checked without a phone.
static func insets_from(window: Vector2i, safe: Rect2i) -> Vector2:
	var scale := minf(float(window.x) / LOGICAL.x, float(window.y) / LOGICAL.y)
	if scale <= 0.0:
		return Vector2.ZERO
	# The letterbox bar above and below the content, in screen pixels.
	var margin := (float(window.y) - LOGICAL.y * scale) * 0.5
	var top := maxf(float(safe.position.y) - margin, 0.0)
	var bottom := maxf(float(window.y) - float(safe.end.y) - margin, 0.0)
	return Vector2(top / scale, bottom / scale)
