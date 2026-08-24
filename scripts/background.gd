class_name Background
extends Node2D

## Lag 1: baggrunden. Alt tegnes proceduralt, ingen billedfiler.
##
## Den skal blive ved med at være rum. Ingen genstande, der stjæler
## opmærksomhed fra klodserne, kun stjerner, støv og et par
## asteroide-silhuetter, der driver forbi.
##
## Tre lag med hver sin parallax:
##   Bagerst  stjernefelt og et fjernt lysvask, ingen parallax
##   Midten   drivende asteroider, 3 px
##   Forrest  støv og småsten, 8 px
##
## Zonen giver farven. Hvert level i zonen får sin egen anelse af
## temperatur, så banerne ikke ligner hinanden, uden at nogen af dem
## holder op med at være rummet.

const VOID := Color("07070C")
const ASTEROID := Color("12121A")
const DUST := Color("1C1C26")

const STAR_COUNT_MIN := 80
const STAR_COUNT_MAX := 120

const PARALLAX_MID := 3.0
const PARALLAX_FRONT := 8.0

const FLASH_TIME := 0.3
const SHOOTING_STAR_MIN := 40.0
const SHOOTING_STAR_MAX := 70.0

## Én stemning per level i zonen. Kun temperatur og tæthed skifter.
const MOODS := [
	{"star": Color("C8C8D4"), "wash": Color("1B2A46"), "strength": 0.30, "rocks": 3, "dust": 8},
	{"star": Color("BFD4E4"), "wash": Color("15303C"), "strength": 0.34, "rocks": 2, "dust": 6},
	{"star": Color("DCCEC2"), "wash": Color("3A2018"), "strength": 0.32, "rocks": 4, "dust": 10},
]

var screen_size := Vector2(390.0, 844.0)

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

var _mood: Dictionary = MOODS[0]
var _focus_x := 195.0
var _time := 0.0

## Reaktioner fra afsnit 2.
var _dim := 0.0
var _blitz := 0.0
var _glint := 0.0
var _combo := 0


func _ready() -> void:
	_build()
	_shooting_wait = randf_range(SHOOTING_STAR_MIN, SHOOTING_STAR_MAX)


## Hvert level i zonen får sin egen anelse af temperatur.
func set_level_mood(level_number: int) -> void:
	_mood = MOODS[posmod(level_number - 1, MOODS.size())]
	_build()


func _build() -> void:
	_stars.clear()
	_small_star_indices.clear()
	# Stjernefeltet bygges om ved hvert level. Flimre-pladserne peger på
	# indekser i det gamle felt og skal slippe dem, ellers læser de uden
	# for arrayet, næste gang feltet bliver kortere.
	for slot in _twinkle:
		slot["index"] = -1
		slot["wait"] = randf_range(0.3, 2.0)
	var star_color: Color = _mood["star"]
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
			"flash_color": star_color,
			"twinkle": 0.0,
		})
		if size == 1:
			_small_star_indices.append(i)

	_asteroids.clear()
	for i in int(_mood["rocks"]):
		_asteroids.append({
			"pos": Vector2(randf_range(60.0, screen_size.x - 60.0), randf_range(200.0, screen_size.y - 120.0)),
			"rot": randf() * TAU,
			# Umærkeligt. En hel omgang tager over ti minutter.
			"rot_speed": randf_range(-0.010, 0.010),
			# 1 px per 2 sekunder.
			"drift": Vector2(randf_range(-0.5, 0.5), -0.5).normalized() * 0.5,
			"shape": _rock_shape(randf_range(6.0, 12.0)),
		})

	_dust.clear()
	for i in int(_mood["dust"]):
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


## Ved tab af liv dimmer stjernefeltet til 50 procent i 800 ms.
func dim() -> void:
	_dim = 1.0


## Ved level clear tændes alle stjerner 100 procent i ét frame.
func blitz() -> void:
	_blitz = 1.0


## Pulse-kernen sender et kort lysglimt gennem det fjerne lys.
func field_glint() -> void:
	_glint = 1.0


## Kombo 5+ giver flere stjerneskud. Kombo 10+ får asteroiderne til at
## drive mærkbart hurtigere. Rummet mærker, at det går godt.
func set_intensity(combo: int) -> void:
	_combo = combo


func _drift_scale() -> float:
	return 3.2 if _combo >= 10 else 1.0


func _shooting_interval() -> float:
	if _combo >= 5:
		return 8.0
	return randf_range(SHOOTING_STAR_MIN, SHOOTING_STAR_MAX)


## Bolden ramte noget: de nærmeste stjerner blinker svagt op i 300 ms.
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
		# Ét frame, ikke en fade. Det er en blitz, ikke et lys der tændes.
		_blitz = 0.0 if _blitz < 1.0 else 0.999
	if _glint > 0.0:
		_glint = maxf(0.0, _glint - delta / 0.35)

	var drift := _drift_scale()
	for rock in _asteroids:
		rock["pos"] += rock["drift"] * drift * delta
		rock["rot"] += rock["rot_speed"] * drift * delta
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
			# Op og ned igen, aldrig et hårdt blink.
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

	_draw_wash()
	_draw_stars()
	_draw_shooting_star()

	var n := clampf((_focus_x - screen_size.x * 0.5) / (screen_size.x * 0.5), -1.0, 1.0)
	_draw_asteroids(Vector2(-n * PARALLAX_MID, 0.0))
	_draw_dust(Vector2(-n * PARALLAX_FRONT, 0.0))


## Fjernt lys nede fra venstre. Ikke en genstand, bare en anelse farve i
## rummet, som skifter fra level til level.
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
			color = star_color.lerp(star["flash_color"], flash)
			alpha = clampf(alpha + flash * 0.5, 0.0, 1.0)
		alpha *= dim_factor
		if _blitz > 0.0:
			color = Color.WHITE
			alpha = 1.0
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
	for i in 8:
		var s := float(i) / 8.0
		var p := head + tail_dir * (26.0 * s)
		var c: Color = _mood["star"]
		c.a = fade * (1.0 - s) * 0.85
		draw_rect(Rect2(p.floor(), Vector2(1, 1)), c)
	var hc := Color.WHITE
	hc.a = fade
	draw_rect(Rect2(head.floor(), Vector2(2, 2)), hc)


func _draw_asteroids(offset: Vector2) -> void:
	for rock in _asteroids:
		var pts := PackedVector2Array()
		var shape: PackedVector2Array = rock["shape"]
		var rot: float = rock["rot"]
		var pos: Vector2 = rock["pos"] + offset
		for p in shape:
			pts.append(pos + p.rotated(rot))
		draw_colored_polygon(pts, ASTEROID)


func _draw_dust(offset: Vector2) -> void:
	for grain in _dust:
		draw_rect(Rect2(grain["pos"] + offset, grain["size"]), DUST)
