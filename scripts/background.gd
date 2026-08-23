class_name Background
extends Node2D

## Lag 1: baggrunden. Alt tegnes proceduralt, ingen billedfiler.
##
## Tre lag med hver sin parallax:
##   Bagerst  stjernefelt, ingen parallax
##   Midten   fjern planet og drivende asteroider, 3 px
##   Forrest  støv og småsten, 8 px
##
## Reaktion i fase 1: de nærmeste 5 stjerner blinker op, når bolden
## rammer rammen. Resten af reaktionerne kommer i fase 2.

const VOID := Color("07070C")
const STAR := Color("C8C8D4")
const PLANET := Color("1A2030")
const ATMOSPHERE := Color("2A3448")
const ASTEROID := Color("12121A")
const DUST := Color("1C1C26")

const STAR_COUNT_MIN := 80
const STAR_COUNT_MAX := 120

const PARALLAX_MID := 3.0
const PARALLAX_FRONT := 8.0

const FLASH_TIME := 0.3
const SHOOTING_STAR_MIN := 40.0
const SHOOTING_STAR_MAX := 70.0

## Sættes af arenaen, så alle lag kender skærmen.
var screen_size := Vector2(390, 844)

var _stars: Array[Dictionary] = []
var _small_star_indices: PackedInt32Array = []
var _asteroids: Array[Dictionary] = []
var _dust: Array[Dictionary] = []

## To twinkle-pladser. Aldrig mere end 2 små stjerner flimrer ad gangen.
var _twinkle := [
	{"index": -1, "t": 0.0, "duration": 1.0, "wait": 0.4},
	{"index": -1, "t": 0.0, "duration": 1.0, "wait": 1.9},
]

var _shooting := {"active": false, "t": 0.0, "duration": 0.7, "from": Vector2.ZERO, "to": Vector2.ZERO}
var _shooting_wait := 0.0

var _planet_center := Vector2.ZERO
var _planet_radius := 60.0

var _focus_x := 195.0
var _time := 0.0


func _ready() -> void:
	_build()
	_shooting_wait = randf_range(SHOOTING_STAR_MIN, SHOOTING_STAR_MAX)


func _build() -> void:
	_stars.clear()
	_small_star_indices.clear()
	var count := randi_range(STAR_COUNT_MIN, STAR_COUNT_MAX)
	for i in count:
		# Tre størrelser. De små er langt de fleste, som på en rigtig himmel.
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
			"flash_color": STAR,
			"twinkle": 0.0,
		})
		if size == 1:
			_small_star_indices.append(i)

	_planet_center = Vector2(52.0, screen_size.y - 138.0)
	_planet_radius = 60.0

	_asteroids.clear()
	for i in randi_range(2, 3):
		_asteroids.append({
			"pos": Vector2(randf_range(120.0, screen_size.x - 40.0), randf_range(160.0, screen_size.y - 260.0)),
			"rot": randf() * TAU,
			# Umærkeligt. En hel omgang tager over ti minutter.
			"rot_speed": randf_range(-0.010, 0.010),
			# 1 px per 2 sekunder.
			"drift": Vector2(randf_range(-0.5, 0.5), -0.5).normalized() * 0.5,
			"shape": _rock_shape(randf_range(9.0, 17.0)),
		})

	_dust.clear()
	for i in randi_range(6, 10):
		_dust.append({
			"pos": Vector2(randf() * screen_size.x, randf() * screen_size.y),
			"size": Vector2(randf_range(2.0, 5.0), randf_range(1.0, 3.0)),
		})


func _rock_shape(radius: float) -> PackedVector2Array:
	var points := PackedVector2Array()
	var steps := randi_range(6, 8)
	for i in steps:
		var a := TAU * float(i) / float(steps)
		var r := radius * randf_range(0.65, 1.0)
		points.append(Vector2(cos(a), sin(a)) * r)
	return points


## Arenaen fodrer baggrunden med paddlens x, så parallaxen har noget at følge.
func set_focus_x(x: float) -> void:
	_focus_x = x


## Bolden ramte rammen: de nærmeste stjerner blinker svagt op i 300 ms.
func flash_near(world_pos: Vector2, count := 5, color := STAR) -> void:
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

	for rock in _asteroids:
		rock["pos"] += rock["drift"] * delta
		rock["rot"] += rock["rot_speed"] * delta
		var p: Vector2 = rock["pos"]
		if p.y < -40.0:
			rock["pos"] = Vector2(randf_range(60.0, screen_size.x - 60.0), screen_size.y + 40.0)

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
		var f: float = slot["t"] / slot["duration"]
		var star: Dictionary = _stars[slot["index"]]
		if f >= 1.0:
			star["twinkle"] = 0.0
			slot["index"] = -1
			slot["wait"] = randf_range(0.4, 2.2)
		else:
			# Op og ned igen, aldrig et hårdt blink.
			star["twinkle"] = sin(f * PI) * 0.45


func _update_shooting_star(delta: float) -> void:
	if _shooting["active"]:
		_shooting["t"] += delta
		if _shooting["t"] >= _shooting["duration"]:
			_shooting["active"] = false
			_shooting_wait = randf_range(SHOOTING_STAR_MIN, SHOOTING_STAR_MAX)
		return
	_shooting_wait -= delta
	if _shooting_wait > 0.0:
		return
	# Krydser et hjørne, ikke midten af skærmen.
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
	# Lidt større end skærmen, så screen shake aldrig afslører kanten.
	draw_rect(Rect2(-16.0, -16.0, screen_size.x + 32.0, screen_size.y + 32.0), VOID)

	_draw_stars()
	_draw_shooting_star()

	var n := clampf((_focus_x - screen_size.x * 0.5) / (screen_size.x * 0.5), -1.0, 1.0)
	_draw_mid_layer(Vector2(-n * PARALLAX_MID, 0.0))
	_draw_front_layer(Vector2(-n * PARALLAX_FRONT, 0.0))


func _draw_stars() -> void:
	for star in _stars:
		var size: int = star["size"]
		var alpha: float = clampf(star["base"] + star["twinkle"], 0.0, 1.0)
		var color := STAR
		var flash: float = star["flash"]
		if flash > 0.0:
			color = STAR.lerp(star["flash_color"], flash)
			alpha = clampf(alpha + flash * 0.5, 0.0, 1.0)
		color.a = alpha
		# Firkantede. Samme sprog som partiklerne.
		draw_rect(Rect2(star["pos"].floor(), Vector2(size, size)), color)


func _draw_shooting_star() -> void:
	if not _shooting["active"]:
		return
	var f: float = _shooting["t"] / _shooting["duration"]
	var head: Vector2 = _shooting["from"].lerp(_shooting["to"], f)
	var tail_dir: Vector2 = (_shooting["from"] - _shooting["to"]).normalized()
	var fade := sin(clampf(f, 0.0, 1.0) * PI)
	var length := 26.0
	for i in 8:
		var s := float(i) / 8.0
		var p := head + tail_dir * (length * s)
		var c := STAR
		c.a = fade * (1.0 - s) * 0.85
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), c)
	var hc := Color.WHITE
	hc.a = fade
	draw_rect(Rect2(head.floor(), Vector2(2, 2)), hc)


func _draw_mid_layer(offset: Vector2) -> void:
	var c := _planet_center + offset
	draw_circle(c, _planet_radius, PLANET)
	# Tynd atmosfærelinje. Den slukker et øjeblik ved tab af liv i fase 2.
	draw_arc(c, _planet_radius + 1.0, 0.0, TAU, 64, ATMOSPHERE, 1.0, true)

	for rock in _asteroids:
		var pts := PackedVector2Array()
		var shape: PackedVector2Array = rock["shape"]
		var rot: float = rock["rot"]
		var pos: Vector2 = rock["pos"] + offset
		for p in shape:
			pts.append(pos + p.rotated(rot))
		draw_colored_polygon(pts, ASTEROID)


func _draw_front_layer(offset: Vector2) -> void:
	for grain in _dust:
		draw_rect(Rect2(grain["pos"] + offset, grain["size"]), DUST)
