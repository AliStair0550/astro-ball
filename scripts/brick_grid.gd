class_name BrickGrid
extends Node2D

## Lag 3: gridet af klodser.
##
## 13 kolonner, klodser på 24x16 px med 2 px afstand, som afsnit 3
## foreskriver. Hele gridet tegnes i ét _draw, og kollisionen slår kun op
## i de celler, boldens bevægelse faktisk rører. Med 140 klodser er det
## forskellen på fem opslag og fem hundrede.

signal brick_damaged(brick: Brick)
signal brick_destroyed(brick: Brick, by_chain: bool)
signal brick_revealed(brick: Brick)
signal stone_popped(brick: Brick)
signal cleared()

const COLUMNS := 13
const SPACING := 2.0
const PITCH := Vector2(Brick.SIZE.x + SPACING, Brick.SIZE.y + SPACING)
## Gridet er centreret vandret. Lodret ligger det så langt nede, som
## luften over det tillader: der skal stadig være plads til at komme op
## bag muren, for det er dér DX-Ball-øjeblikket bor.
const ORIGIN := Vector2(27.0, 230.0)

## Kæden skal kunne ses, ikke bare høres.
const CHAIN_DELAY := 0.04
const CLEAR_POP_DELAY := 0.09

## Spiral med uret fra øverste venstre hjørne. Rækkefølgen er hele
## pointen med kædereaktionen: den skal læses som en bevægelse.
const NEIGHBOUR_SPIRAL := [
	Vector2i(-1, -1), Vector2i(0, -1), Vector2i(1, -1),
	Vector2i(1, 0), Vector2i(1, 1), Vector2i(0, 1),
	Vector2i(-1, 1), Vector2i(-1, 0),
]

var rows := 0
var blind := false

var _bricks: Array = []
var _pending: Array[Dictionary] = []
var _time := 0.0
var _clear_emitted := false


func build(grid: Array) -> void:
	_bricks.clear()
	_pending.clear()
	_clear_emitted = false
	rows = grid.size()
	for row in rows:
		var line: String = str(grid[row])
		for col in COLUMNS:
			var symbol := line[col] if col < line.length() else "."
			if symbol == "." or not Brick.SYMBOLS.has(symbol):
				_bricks.append(null)
				continue
			var rect := Rect2(ORIGIN + Vector2(col * PITCH.x, row * PITCH.y), Brick.SIZE)
			_bricks.append(Brick.new(Brick.SYMBOLS[symbol], col, row, rect))
	queue_redraw()


func index_of(col: int, row: int) -> int:
	if col < 0 or col >= COLUMNS or row < 0 or row >= rows:
		return -1
	return row * COLUMNS + col


func brick_at(col: int, row: int) -> Brick:
	var i := index_of(col, row)
	if i < 0:
		return null
	return _bricks[i]


## Nederste kant af gridet. Bruges til at holde power-ups fri af klodserne.
func bottom_y() -> float:
	return ORIGIN.y + float(rows) * PITCH.y


## Klodser, hvis rektangel overlapper det givne område. Broad phase.
func bricks_in(area: Rect2) -> Array[Brick]:
	var found: Array[Brick] = []
	var first_col := int(floor((area.position.x - ORIGIN.x) / PITCH.x)) - 1
	var last_col := int(floor((area.end.x - ORIGIN.x) / PITCH.x)) + 1
	var first_row := int(floor((area.position.y - ORIGIN.y) / PITCH.y)) - 1
	var last_row := int(floor((area.end.y - ORIGIN.y) / PITCH.y)) + 1
	for row in range(maxi(first_row, 0), mini(last_row + 1, rows)):
		for col in range(maxi(first_col, 0), mini(last_col + 1, COLUMNS)):
			var brick: Brick = _bricks[row * COLUMNS + col]
			if brick != null and brick.alive and brick.revealed:
				found.append(brick)
	return found


func remaining_breakable() -> int:
	var n := 0
	for brick in _bricks:
		if brick != null and brick.alive and brick.counts_toward_clear():
			n += 1
	return n


func live_bricks() -> Array[Brick]:
	var out: Array[Brick] = []
	for brick in _bricks:
		if brick != null and brick.alive:
			out.append(brick)
	return out


# --- Skade -------------------------------------------------------------

## Slår en klods. Returnerer true, hvis den blev smadret.
func hit(brick: Brick, damage := 1, by_chain := false) -> bool:
	if brick == null or not brick.alive:
		return false
	var destroyed := brick.take_hit(damage)
	if not destroyed:
		if brick.is_breakable():
			brick_damaged.emit(brick)
		return false
	_destroy(brick, by_chain)
	return true


func _destroy(brick: Brick, by_chain: bool) -> void:
	brick.alive = false
	_reveal_neighbours(brick)
	brick_destroyed.emit(brick, by_chain)
	if brick.type == Brick.Type.BLAST:
		_queue_chain(brick)
	_check_cleared()


## Sprængklodsen tager de 8 naboer med, én ad gangen.
func _queue_chain(brick: Brick) -> void:
	var step := 0
	for offset in NEIGHBOUR_SPIRAL:
		var neighbour := brick_at(brick.col + offset.x, brick.row + offset.y)
		step += 1
		if neighbour == null or not neighbour.alive or not neighbour.is_breakable():
			continue
		_pending.append({"brick": neighbour, "delay": CHAIN_DELAY * float(step)})


## Zap smadrer klodserne ved siden af den ramte.
func zap_neighbours(brick: Brick) -> void:
	for offset in [Vector2i(-1, 0), Vector2i(1, 0)]:
		var neighbour := brick_at(brick.col + offset.x, brick.row + offset.y)
		if neighbour != null and neighbour.alive and neighbour.is_breakable():
			_pending.append({"brick": neighbour, "delay": CHAIN_DELAY})


## Skjulte klodser viser sig, når en nabo smadres.
func _reveal_neighbours(brick: Brick) -> void:
	for offset in NEIGHBOUR_SPIRAL:
		var neighbour := brick_at(brick.col + offset.x, brick.row + offset.y)
		if neighbour != null and neighbour.alive and not neighbour.revealed:
			neighbour.revealed = true
			brick_revealed.emit(neighbour)


func _check_cleared() -> void:
	if _clear_emitted:
		return
	if remaining_breakable() > 0:
		return
	_clear_emitted = true
	# Alle Sten-kerner eksploderer i rækkefølge.
	var step := 0
	for brick in _bricks:
		if brick != null and brick.alive and brick.type == Brick.Type.STONE:
			step += 1
			_pending.append({"brick": brick, "delay": CLEAR_POP_DELAY * float(step), "pop": true})
	cleared.emit()


# --- Opdatering --------------------------------------------------------

func _process(delta: float) -> void:
	_time += delta

	var i := _pending.size() - 1
	while i >= 0:
		var entry := _pending[i]
		entry["delay"] = float(entry["delay"]) - delta
		if entry["delay"] <= 0.0:
			var brick: Brick = entry["brick"]
			_pending.remove_at(i)
			if brick != null and brick.alive:
				if entry.get("pop", false):
					brick.alive = false
					stone_popped.emit(brick)
				else:
					brick.take_hit(brick.hits_left)
					_destroy(brick, true)
		i -= 1

	for brick in _bricks:
		if brick != null and brick.alive:
			brick.update(delta)

	queue_redraw()


## Sprængklodser gløder, når bolden er tæt på.
func update_proximity(ball_positions: Array[Vector2]) -> void:
	for entry in _bricks:
		var brick: Brick = entry
		if brick == null or not brick.alive or brick.type != Brick.Type.BLAST:
			continue
		var nearest := 1000.0
		var center: Vector2 = brick.rect.get_center()
		for p in ball_positions:
			nearest = minf(nearest, p.distance_to(center))
		brick.proximity = clampf(1.0 - nearest / 90.0, 0.0, 1.0)


func _draw() -> void:
	for brick in _bricks:
		if brick != null:
			brick.draw_into(self, _time, blind)
