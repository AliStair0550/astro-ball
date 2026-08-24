class_name Background
extends Node2D

## Layer 1: the background. Drawn procedurally, no image files.
##
## It has to keep being space. No objects that pull attention off the
## bricks, only stars, dust and a far wash of light
## drifting past.
##
## Three layers, each with its own parallax:
##   Back   star field and a distant wash of light, no parallax
##   Middle a slow wash of far light, 3 px
##   Front  dust and grit, 8 px
##
## The zone gives the colour. Each level in it gets its own hint of
## temperature, so the fields do not look alike, without any of them
## ceasing to be space.

const VOID := Color("07070C")
const DUST := Color("1C1C26")

const STAR_COUNT_MIN := 80
const STAR_COUNT_MAX := 120

const PARALLAX_MID := 3.0
const PARALLAX_FRONT := 8.0

const FLASH_TIME := 0.3
const SHOOTING_STAR_MIN := 40.0
const SHOOTING_STAR_MAX := 70.0

## One mood per level in the zone. Only temperature and density change.
const MOODS := [
	{"star": Color("C8C8D4"), "wash": Color("1B2A46"), "strength": 0.30, "dust": 8},
	{"star": Color("BFD4E4"), "wash": Color("15303C"), "strength": 0.34, "dust": 6},
	{"star": Color("DCCEC2"), "wash": Color("3A2018"), "strength": 0.32, "dust": 10},
]

var screen_size := Vector2(390.0, 844.0)

var _stars: Array[Dictionary] = []
var _small_star_indices: PackedInt32Array = []
var _dust: Array[Dictionary] = []

## Two twinkle slots. Never more than 2 small stars flicker at once.
var _twinkle := [
	{"index": -1, "t": 0.0, "duration": 1.0, "wait": 0.4},
	{"index": -1, "t": 0.0, "duration": 1.0, "wait": 1.9},
]

var _shooting := {"active": false, "t": 0.0, "duration": 0.7, "from": Vector2.ZERO, "to": Vector2.ZERO}
var _shooting_wait := 0.0

var _mood: Dictionary = MOODS[0]
var _focus_x := 195.0
var _time := 0.0

## The reactions from section 2.
var _dim := 0.0
var _blitz := 0.0
var _glint := 0.0
var _combo := 0


func _ready() -> void:
	_build()
	_shooting_wait = randf_range(SHOOTING_STAR_MIN, SHOOTING_STAR_MAX)


## Each level in the zone gets its own hint of temperature.
func set_level_mood(level_number: int) -> void:
	_mood = MOODS[posmod(level_number - 1, MOODS.size())]
	_build()


func _build() -> void:
	_stars.clear()
	_small_star_indices.clear()
	# The star field is rebuilt every level. The twinkle slots hold
	# indices into the old one and must let go, or they read past the
	# end of the array the next time the field gets shorter.
	for slot in _twinkle:
		slot["index"] = -1
		slot["wait"] = randf_range(0.3, 2.0)
	var star_color: Color = _mood["star"]
	var count := randi_range(STAR_COUNT_MIN, STAR_COUNT_MAX)
	for i in count:
		# Three sizes. The small ones dominate, as in a real sky.
		var roll := randf()
		var size := 1
		if roll > 0.86:
			size = 3
		elif roll > 0.58:
			size = 2
		var base := 0.30 + randf() * 0.30
		if size == 2:
			base = 0.45 + randf() * 0.30
		elif size == 3:
			base = 0.62 + randf() * 0.30
		_stars.append({
			"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y),
			"size": size,
			"base": base,
			"flash": 0.0,
			"flash_color": star_color,
			"twinkle": 0.0,
		})
		if size == 1:
			_small_star_indices.append(i)

	_dust.clear()
	for i in int(_mood["dust"]):
		_dust.append({
			"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y),
			"size": Vector2(randf_range(2.0, 5.0), randf_range(1.0, 3.0)),
		})


## The game feeds the paddle's x in, so the parallax has something to follow.
func set_focus_x(x: float) -> void:
	_focus_x = x


## On a lost ball the star field dims to 50 per cent for 800 ms.
func dim() -> void:
	_dim = 1.0


## On field cleared every star goes to full for a single frame.
func blitz() -> void:
	_blitz = 1.0


## The Pulse core sends a short glint through the distant light.
func field_glint() -> void:
	_glint = 1.0


## Combo 5+ brings more shooting stars. Combo 10+ makes the dust
## drift noticeably faster. Space notices that it is going well.
func set_intensity(combo: int) -> void:
	_combo = combo


func _drift_scale() -> float:
	return 3.2 if _combo >= 10 else 1.0


func _shooting_interval() -> float:
	if _combo >= 5:
		return 8.0
	return randf_range(SHOOTING_STAR_MIN, SHOOTING_STAR_MAX)


## The ball hit something: the nearest stars blink up for 300 ms.
func flash_near(world_pos: Vector2, count := 5, color := Color.WHITE) -> void:
	var order: Array[int] = []
	for i in _stars.size():
		order.append(i)
	order.sort_custom(func(a: int, b: int) -> bool:
		return _stars[a]["pos"].distance_squared_to(world_pos) < _stars[b]["pos"].distance_squared_to(world_pos)
	)
	for i in mini(count, order.size()):
		var star: Dictionary = _stars[order[i]]
		star["flash"] = 1.0
		star["flash_color"] = color


func _process(delta: float) -> void:
	_time += delta
	_update_twinkle(delta)
	_update_shooting_star(delta)

	for star in _stars:
		if star["flash"] > 0.0:
			star["flash"] = maxf(0.0, star["flash"] - delta / FLASH_TIME)

	if _dim > 0.0:
		_dim = maxf(0.0, _dim - delta / 0.8)
	if _blitz > 0.0:
		# One frame, not a fade. It is a flash, not a light coming on.
		_blitz = 0.0 if _blitz < 1.0 else 0.999
	if _glint > 0.0:
		_glint = maxf(0.0, _glint - delta / 0.35)

	queue_redraw()


func _update_twinkle(delta: float) -> void:
	if _small_star_indices.is_empty():
		return
	for slot in _twinkle:
		if slot["index"] < 0:
			slot["wait"] -= delta
			if slot["wait"] <= 0.0:
				slot["index"] = _small_star_indices[randi() % _small_star_indices.size()]
				slot["t"] = 0.0
				slot["duration"] = randf_range(0.6, 1.4)
			continue
		slot["t"] += delta
		if int(slot["index"]) >= _stars.size():
			slot["index"] = -1
			continue
		var f: float = slot["t"] / slot["duration"]
		var star: Dictionary = _stars[slot["index"]]
		if f >= 1.0:
			star["twinkle"] = 0.0
			slot["index"] = -1
			slot["wait"] = randf_range(0.4, 2.2)
		else:
			# Up and down again, never a hard blink.
			star["twinkle"] = sin(f * PI) * 0.45


func _update_shooting_star(delta: float) -> void:
	if _shooting["active"]:
		_shooting["t"] += delta
		if _shooting["t"] >= _shooting["duration"]:
			_shooting["active"] = false
			_shooting_wait = _shooting_interval()
		return
	_shooting_wait -= delta
	if _shooting_wait > 0.0:
		return
	# Crosses a corner, not the middle of the screen.
	var corner := randi() % 4
	var w := screen_size.x
	var h := screen_size.y
	var span := randf_range(150.0, 240.0)
	var origin := Vector2.ZERO
	var dir := Vector2.ZERO
	match corner:
		0:
			origin = Vector2(randf_range(-40.0, 60.0), randf_range(-20.0, 90.0))
			dir = Vector2(1.0, 0.75)
		1:
			origin = Vector2(w + randf_range(-60.0, 40.0), randf_range(-20.0, 90.0))
			dir = Vector2(-1.0, 0.75)
		2:
			origin = Vector2(randf_range(-40.0, 60.0), h - randf_range(-20.0, 90.0))
			dir = Vector2(1.0, -0.75)
		_:
			origin = Vector2(w + randf_range(-60.0, 40.0), h - randf_range(-20.0, 90.0))
			dir = Vector2(-1.0, -0.75)
	_shooting["from"] = origin
	_shooting["to"] = origin + dir.normalized() * span
	_shooting["t"] = 0.0
	_shooting["duration"] = randf_range(0.5, 0.9)
	_shooting["active"] = true


func _draw() -> void:
	# A little larger than the screen, so shake never reveals the edge.
	draw_rect(Rect2(-16.0, -16.0, screen_size.x + 32.0, screen_size.y + 32.0), VOID)

	_draw_wash()
	_draw_stars()
	_draw_shooting_star()

	var n := clampf((_focus_x - screen_size.x * 0.5) / (screen_size.x * 0.5), -1.0, 1.0)
	_draw_dust(Vector2(-n * PARALLAX_FRONT, 0.0))


## Distant light from the lower left. Not an object, just a hint of
## colour in the room, changing from level to level.
func _draw_wash() -> void:
	var color: Color = _mood["wash"]
	var strength := float(_mood["strength"]) * (1.0 - _dim * 0.6) + _glint * 0.25
	var bands := 22
	for i in bands:
		var f := float(i) / float(bands - 1)
		var c := color
		c.a = strength * 0.05 * (1.0 - f) * (1.0 - f)
		if c.a <= 0.002:
			continue
		var radius := 120.0 + f * 460.0
		draw_rect(Rect2(-radius * 0.55, screen_size.y - radius * 0.8, radius * 1.5, radius * 1.1), c)


func _draw_stars() -> void:
	var dim_factor := 1.0 - 0.5 * _dim
	var star_color: Color = _mood["star"]
	for star in _stars:
		var size: int = star["size"]
		var alpha: float = clampf(star["base"] + star["twinkle"], 0.0, 1.0)
		var color := star_color
		var flash: float = star["flash"]
		if flash > 0.0:
			# Section 2: the nearest stars blink up in the brick colour
			# at opacity 0.15. The room answers, it does not shout.
			color = star_color.lerp(star["flash_color"], flash)
			alpha = clampf(alpha + flash * 0.15, 0.0, 1.0)
		alpha *= dim_factor
		if _blitz > 0.0:
			color = Color.WHITE
			alpha = 1.0
		color.a = alpha
		# Square. The same language as the particles.
		draw_rect(Rect2(star["pos"].floor(), Vector2(size, size)), color)


func _draw_shooting_star() -> void:
	if not _shooting["active"]:
		return
	var f: float = _shooting["t"] / _shooting["duration"]
	var head: Vector2 = _shooting["from"].lerp(_shooting["to"], f)
	var tail_dir: Vector2 = (_shooting["from"] - _shooting["to"]).normalized()
	var fade := sin(clampf(f, 0.0, 1.0) * PI)
	for i in 8:
		var s := float(i) / 8.0
		var p := head + tail_dir * (26.0 * s)
		var c: Color = _mood["star"]
		c.a = fade * (1.0 - s) * 0.85
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), c)
	var hc := Color.WHITE
	hc.a = fade
	draw_rect(Rect2(head.floor(), Vector2(2, 2)), hc)


func _draw_dust(offset: Vector2) -> void:
	for grain in _dust:
		draw_rect(Rect2(grain["pos"] + offset, grain["size"]), DUST)
