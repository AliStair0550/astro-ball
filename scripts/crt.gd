class_name CRT
extends Node2D

## CRT mode from section 12. Off by default.
##
## The effect is a shader over the whole image. If the screen texture
## cannot be read on the current renderer it falls back to scanlines and
## a vignette drawn by hand, so the option never ends up doing nothing
## at all.

const SHADER := preload("res://assets/shaders/crt.gdshader")

var screen_size := Vector2(390.0, 844.0)
var fallback := false

var _copy: BackBufferCopy
var _rect: ColorRect


func _ready() -> void:
	_copy = BackBufferCopy.new()
	_copy.copy_mode = BackBufferCopy.COPY_MODE_RECT
	_copy.rect = Rect2(0.0, 0.0, screen_size.x, screen_size.y)
	add_child(_copy)

	var material := ShaderMaterial.new()
	material.shader = SHADER
	material.set_shader_parameter("resolution", screen_size)

	_rect = ColorRect.new()
	_rect.material = material
	_rect.size = screen_size
	_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_rect)

	var settings := get_node_or_null("/root/GameSettings")
	if settings:
		settings.changed.connect(_apply)
	_apply()


func _apply() -> void:
	var settings := get_node_or_null("/root/GameSettings")
	var on: bool = settings != null and bool(settings.crt)
	visible = on
	_copy.visible = on and not fallback
	_rect.visible = on and not fallback
	queue_redraw()


func _draw() -> void:
	if not fallback or not visible:
		return
	# The fallback: scanlines and vignette without reading the screen.
	var line := Color("07070C")
	line.a = 0.16
	var y := 0.0
	while y < screen_size.y:
		draw_rect(Rect2(0.0, y, screen_size.x, 1.0), line)
		y += 2.0
	var edge := Color("07070C")
	for i in 8:
		edge.a = 0.045
		var inset := float(i) * 4.0
		draw_rect(Rect2(inset, inset, screen_size.x - inset * 2.0, screen_size.y - inset * 2.0), edge, false, 4.0)
