class_name Paddle
extends Node2D

## Lag 4: deflektorskjoldet.
##
## Standard 88 x 10 px med tre synlige segmenter: to endestykker i Bone og
## et midterstykke med et 8 px Volt-felt. Volt-feltet er sweet spot.
## Bred bliver til fem segmenter med to sweet spots, Smal til ét segment
## uden sweet spot. Bredden er ikke bare et tal, den er en anden paddle.
##
## Styring i fase 1 og 2 er musens x. Touch kommer i fase 4.

signal laser_fired(from: Vector2)

const BONE := Color("F2EFE6")
## Endestykkernes krop er en tone mørkere end Bone, så bevelen har noget
## at lyse op fra. Et helt hvidt stykke metal har ingen form.
const CAP := Color("C4C1B7")
const VOLT := Color("D6FF3D")
const EMBER := Color("FF4D2E")
## Midterstykket er koldt metal mod Bone-endestykkerne. Kontrasten er
## det, der gør skjoldet til et stykke isenkram og ikke en streg.
const MID := Color("575C6B")
const SEAM := Color("15151E")
const ICE := Color("4DD8FF")

const HEIGHT := 10.0
const CAP_WIDTH := 24.0
const SWEET_WIDTH := 8.0
const SWEET_HALF := 4.0

const WIDTH_NORMAL := 88.0
const WIDTH_WIDE := 132.0
const WIDTH_NARROW := 56.0

const END_LIGHT_TIME := 0.1
const TRAIL_SPEED := 180.0

const LASER_SPEED := 760.0
const LASER_COOLDOWN := 0.22

## Ydre grænser fra arenaen. min_x og max_x udledes af bredden.
var bounds_min := 0.0
var bounds_max := 390.0
var min_x := 0.0
var max_x := 390.0

var width := WIDTH_NORMAL
var laser := false
## Slukkes, mens en skærm er oppe.
var input_enabled := true
## Bremses af Tung i senere levels. 1.0 = følger musen præcist.
var follow_speed := 1.0

var _squash := GameFeel.Squash.new()
var _scale_y := 1.0
var _left_light := 0.0
var _right_light := 0.0
var _catch_flash := 0.0
var _catch_color := VOLT
var _prev_positions: Array[float] = []
var _velocity_x := 0.0
var _laser_cooldown := 0.0
var _bolts: Array[Dictionary] = []
var _time := 0.0


func _ready() -> void:
	_prev_positions = [position.x, position.x]
	_apply_bounds()


func set_bounds(low: float, high: float) -> void:
	bounds_min = low
	bounds_max = high
	_apply_bounds()


func set_width(new_width: float) -> void:
	width = new_width
	_apply_bounds()


func _apply_bounds() -> void:
	min_x = bounds_min + half_width()
	max_x = bounds_max - half_width()
	position.x = clampf(position.x, min_x, max_x)


func half_width() -> float:
	return width * 0.5


func top_y() -> float:
	return position.y - HEIGHT * 0.5


func ball_anchor(ball_radius: float) -> Vector2:
	return Vector2(position.x, top_y() - ball_radius - 1.0)


func world_rect() -> Rect2:
	return Rect2(position.x - half_width(), top_y(), width, HEIGHT)


## Antal synlige segmenter: 1 ved Smal, 3 ved Normal, 5 ved Bred.
func segment_count() -> int:
	if width <= WIDTH_NARROW + 0.01:
		return 1
	if width >= WIDTH_WIDE - 0.01:
		return 5
	return 3


## Sweet spot-centre i lokale koordinater. Smal har ingen.
func sweet_offsets() -> Array[float]:
	match segment_count():
		1:
			return []
		5:
			var mid_span := (width - CAP_WIDTH * 2.0) / 3.0
			return [-mid_span, mid_span]
		_:
			return [0.0]


func is_sweet(dx: float) -> bool:
	for offset in sweet_offsets():
		if absf(dx - offset) <= SWEET_HALF:
			return true
	return false


func has_sweet_spot() -> bool:
	return not sweet_offsets().is_empty()


# --- Styring -----------------------------------------------------------

func _physics_process(delta: float) -> void:
	if not input_enabled:
		return
	var target := clampf(get_global_mouse_position().x, min_x, max_x)
	if follow_speed < 1.0:
		target = lerpf(position.x, target, clampf(follow_speed * delta * 18.0, 0.0, 1.0))
	_velocity_x = (target - position.x) / maxf(delta, 0.0001)
	_prev_positions.push_front(position.x)
	if _prev_positions.size() > 2:
		_prev_positions.resize(2)
	position.x = target


func _unhandled_input(event: InputEvent) -> void:
	if not laser or not input_enabled:
		return
	var tap := false
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		tap = true
	elif event is InputEventScreenTouch and event.pressed:
		tap = true
	if tap:
		fire_laser()


func fire_laser() -> void:
	if not laser or _laser_cooldown > 0.0:
		return
	_laser_cooldown = LASER_COOLDOWN
	var hw := half_width()
	for side: float in [-1.0, 1.0]:
		var muzzle := Vector2(position.x + side * (hw - CAP_WIDTH * 0.5), top_y())
		_bolts.append({"pos": muzzle, "alive": true})
		laser_fired.emit(muzzle)


## Aktive laserstråler i verdenskoordinater. Spillet tester dem mod gridet.
func laser_bolts() -> Array[Dictionary]:
	return _bolts


func clear_bolts() -> void:
	_bolts.clear()


# --- Reaktioner --------------------------------------------------------

func on_ball_hit(hit_x: float) -> void:
	_squash.trigger()
	var offset := hit_x - position.x
	if offset <= -(half_width() - CAP_WIDTH):
		_left_light = 1.0
	elif offset >= half_width() - CAP_WIDTH:
		_right_light = 1.0


## Kapslen imploderer til paddlen, og paddlen blinker i kapslens farve.
func on_powerup_caught(color: Color) -> void:
	_catch_flash = 1.0
	_catch_color = color
	_squash.trigger()


func _process(delta: float) -> void:
	_time += delta
	_scale_y = _squash.update(delta)
	if _left_light > 0.0:
		_left_light = maxf(0.0, _left_light - delta / END_LIGHT_TIME)
	if _right_light > 0.0:
		_right_light = maxf(0.0, _right_light - delta / END_LIGHT_TIME)
	if _catch_flash > 0.0:
		_catch_flash = maxf(0.0, _catch_flash - delta * 4.0)
	if _laser_cooldown > 0.0:
		_laser_cooldown = maxf(0.0, _laser_cooldown - delta)

	var i := _bolts.size() - 1
	while i >= 0:
		_bolts[i]["pos"] = _bolts[i]["pos"] - Vector2(0.0, LASER_SPEED * delta)
		if not _bolts[i]["alive"] or _bolts[i]["pos"].y < 0.0:
			_bolts.remove_at(i)
		i -= 1

	queue_redraw()


# --- Tegning -----------------------------------------------------------

func _draw() -> void:
	_draw_bolts()
	_draw_motion_trail()

	var h := HEIGHT * _scale_y
	# Bunden står fast, så skjoldet presses ned mod sin egen linje.
	var top := HEIGHT * 0.5 - h
	var hw := half_width()

	_draw_projection(top, h, hw)
	_draw_body(top, h, hw)

	if laser:
		_draw_laser_tubes(top, h, hw)

	_draw_end_glow(top, h, hw)

	if _catch_flash > 0.0:
		var c := _catch_color
		c.a = _catch_flash * 0.7
		draw_rect(Rect2(-hw - 2.0, top - 3.0, width + 4.0, h + 5.0), c)


func _cap_color(light: float) -> Color:
	return CAP.lerp(Color.WHITE, light)


## Skjoldet er projiceret. Feltet over kanten er det, bolden rammer,
## og den svage skygge nedenunder er det, der holder den oppe.
func _draw_projection(top: float, h: float, hw: float) -> void:
	var field := VOLT
	for i in 3:
		field.a = 0.13 - float(i) * 0.04
		draw_rect(Rect2(-hw + float(i), top - 3.0 + float(i), width - float(i) * 2.0, 3.0 - float(i) * 0.5), field)
	var shadow := Color("07070C")
	shadow.a = 0.5
	draw_rect(Rect2(-hw + 2.0, top + h, width - 4.0, 2.0), shadow)


## Skjoldet i spans: endestykker, midterstykker og sweet spots.
## De tegnes med samme skygge, så hele skjoldet er ét stykke rundt metal
## og ikke fem flade klodser ved siden af hinanden.
func _spans() -> Array[Dictionary]:
	var hw := half_width()
	var half_sweet := SWEET_WIDTH * 0.5
	var out: Array[Dictionary] = []
	match segment_count():
		1:
			out.append({"x0": -hw, "x1": hw, "color": _cap_color(maxf(_left_light, _right_light)), "sweet": false})
		5:
			var span := (width - CAP_WIDTH * 2.0) / 3.0
			var a := -hw + CAP_WIDTH
			var b := hw - CAP_WIDTH
			out.append({"x0": -hw, "x1": a, "color": _cap_color(_left_light), "sweet": false})
			out.append({"x0": a, "x1": -span - half_sweet, "color": MID, "sweet": false})
			out.append({"x0": -span - half_sweet, "x1": -span + half_sweet, "color": VOLT, "sweet": true})
			out.append({"x0": -span + half_sweet, "x1": span - half_sweet, "color": MID, "sweet": false})
			out.append({"x0": span - half_sweet, "x1": span + half_sweet, "color": VOLT, "sweet": true})
			out.append({"x0": span + half_sweet, "x1": b, "color": MID, "sweet": false})
			out.append({"x0": b, "x1": hw, "color": _cap_color(_right_light), "sweet": false})
		_:
			out.append({"x0": -hw, "x1": -hw + CAP_WIDTH, "color": _cap_color(_left_light), "sweet": false})
			out.append({"x0": -hw + CAP_WIDTH, "x1": -half_sweet, "color": MID, "sweet": false})
			out.append({"x0": -half_sweet, "x1": half_sweet, "color": VOLT, "sweet": true})
			out.append({"x0": half_sweet, "x1": hw - CAP_WIDTH, "color": MID, "sweet": false})
			out.append({"x0": hw - CAP_WIDTH, "x1": hw, "color": _cap_color(_right_light), "sweet": false})
	return out


## Hjørnerne rundes ved at trække rækkerne ind i toppen og bunden.
static func _row_inset(row: int, rows: int) -> float:
	if row == 0 or row == rows - 1:
		return 2.0
	if row == 1 or row == rows - 2:
		return 1.0
	return 0.0


## Cylinderens lys: lysest lidt over midten, mørkest i bunden. Det er
## den kurve, der gør en flad stribe til et rundt stykke metal.
static func _shade_at(t: float) -> float:
	return cos((t - 0.30) * PI * 1.08)


func _draw_body(top: float, h: float, hw: float) -> void:
	var rows := maxi(int(round(h)), 5)
	var row_h := h / float(rows)
	var spans := _spans()

	# Glød omkring sweet spots, under kroppen så den ikke vasker den ud.
	for span in spans:
		if not span["sweet"]:
			continue
		# Gløden skal hugge om feltet, ikke ligge som en firkant bagved.
		var glow := VOLT
		for i in 3:
			glow.a = 0.16 - float(i) * 0.05
			var pad := 1.5 + float(i) * 1.8
			draw_rect(Rect2(float(span["x0"]) - pad, top - pad * 0.35,
				float(span["x1"]) - float(span["x0"]) + pad * 2.0, h + pad * 0.7), glow)

	# Mørk kontur hele vejen rundt om silhuetten.
	var outline := Color("0A0A12")
	for r in rows:
		var inset := _row_inset(r, rows)
		draw_rect(Rect2(-hw - 1.0 + inset, top + float(r) * row_h, width + 2.0 - inset * 2.0, row_h + 0.5), outline)

	# Kroppen, række for række.
	for r in rows:
		var t := (float(r) + 0.5) / float(rows)
		var shade := _shade_at(t)
		var inset := _row_inset(r, rows)
		var y := top + float(r) * row_h
		for i in spans.size():
			var span := spans[i]
			var x0: float = float(span["x0"]) + (inset if i == 0 else 0.0)
			var x1: float = float(span["x1"]) - (inset if i == spans.size() - 1 else 0.0)
			if x1 <= x0:
				continue
			var base: Color = span["color"]
			var c := base.lightened(shade * 0.6) if shade > 0.0 else base.darkened(-shade * 0.62)
			draw_rect(Rect2(x0, y, x1 - x0, row_h + 0.5), c)

	# Glansstriben. Ét smalt bånd højt oppe, som lyset i et rør.
	var spec_row := maxi(int(float(rows) * 0.18), 1)
	var spec := Color.WHITE
	spec.a = 0.30
	draw_rect(Rect2(-hw + 2.0, top + float(spec_row) * row_h, width - 4.0, maxf(row_h, 1.0)), spec)
	spec.a = 0.12
	draw_rect(Rect2(-hw + 2.0, top + float(spec_row + 1) * row_h, width - 4.0, maxf(row_h, 1.0)), spec)

	# Samlinger mellem segmenterne.
	for seam_x in _seam_positions():
		var seam := SEAM
		seam.a = 0.9
		draw_rect(Rect2(seam_x - 1.0, top + 1.0, 1.0, h - 2.0), seam)
		var chrome := Color.WHITE
		chrome.a = 0.20
		draw_rect(Rect2(seam_x, top + 1.0, 1.0, h - 2.0), chrome)

	# Vandrende lys i sweet spottet, så feltet ser ladet ud.
	for span in spans:
		if not span["sweet"]:
			continue
		var x0: float = float(span["x0"])
		var w: float = float(span["x1"]) - x0
		var travel := fposmod(_time * 26.0, w + 6.0) - 3.0
		var sparkle := Color.WHITE
		sparkle.a = 0.6
		draw_rect(Rect2(clampf(x0 + travel, x0, x0 + w - 1.0), top + 1.0, 1.0, maxf(h - 2.0, 1.0)), sparkle)


## Endestykkerne lyser op i 100 ms, når bolden rammer dem.
func _draw_end_glow(top: float, h: float, hw: float) -> void:
	if _left_light > 0.0:
		var gl := Color.WHITE
		gl.a = _left_light * 0.30
		draw_rect(Rect2(-hw - 3.0, top - 3.0, CAP_WIDTH + 6.0, h + 6.0), gl)
	if _right_light > 0.0:
		var gr := Color.WHITE
		gr.a = _right_light * 0.30
		draw_rect(Rect2(hw - CAP_WIDTH - 3.0, top - 3.0, CAP_WIDTH + 6.0, h + 6.0), gr)


func _draw_motion_trail() -> void:
	if absf(_velocity_x) < TRAIL_SPEED or _prev_positions.size() < 2:
		return
	var hw := half_width()
	for i in _prev_positions.size():
		var dx: float = _prev_positions[i] - position.x
		var c := BONE
		c.a = 0.10 - 0.045 * float(i)
		if c.a <= 0.0:
			continue
		draw_rect(Rect2(-hw + dx, -HEIGHT * 0.5, width, HEIGHT), c)


func _seam_positions() -> Array[float]:
	var hw := half_width()
	if segment_count() == 1:
		return []
	var seams: Array[float] = [-hw + CAP_WIDTH, hw - CAP_WIDTH]
	if segment_count() == 5:
		var span := (width - CAP_WIDTH * 2.0) / 3.0
		seams.append(-hw + CAP_WIDTH + span)
		seams.append(hw - CAP_WIDTH - span)
	return seams


func _draw_laser_tubes(top: float, h: float, hw: float) -> void:
	# To Ember-rør på endestykkerne. Mundingen gløder, når de er ladet.
	var ready_glow := 1.0 - clampf(_laser_cooldown / LASER_COOLDOWN, 0.0, 1.0)
	for side: float in [-1.0, 1.0]:
		var x := side * (hw - CAP_WIDTH * 0.5) - 2.0
		draw_rect(Rect2(x, top - 5.0, 4.0, h + 4.0), EMBER.darkened(0.45))
		draw_rect(Rect2(x, top - 5.0, 1.0, h + 4.0), EMBER.lightened(0.3))
		draw_rect(Rect2(x + 1.0, top - 5.0, 2.0, h + 4.0), EMBER)
		var tip := EMBER.lightened(0.55)
		tip.a = 0.35 + 0.65 * ready_glow
		draw_rect(Rect2(x, top - 5.0, 4.0, 2.0), tip)
		var halo := EMBER
		halo.a = 0.22 * ready_glow
		draw_rect(Rect2(x - 3.0, top - 8.0, 10.0, 8.0), halo)


func _draw_bolts() -> void:
	for bolt in _bolts:
		var p := to_local(bolt["pos"])
		var core := EMBER.lightened(0.45)
		draw_rect(Rect2(p.x - 1.0, p.y, 2.0, 11.0), core)
		var glow := EMBER
		glow.a = 0.35
		draw_rect(Rect2(p.x - 2.5, p.y - 2.0, 5.0, 15.0), glow)
		glow.a = 0.14
		draw_rect(Rect2(p.x - 4.0, p.y - 4.0, 8.0, 19.0), glow)
