class_name PowerupManager
extends Node2D

## Spawn-reglerne fra afsnit 7 og regnskabet over aktive power-ups.
##
##   Maks 2 kapsler på skærmen.
##   Aldrig Død i de første 5 levels.
##   Aldrig to dårlige i træk.
##   Efter tab af liv er næste power-up garanteret god.
##
## Reglerne er der, fordi tilfældighed uden hegn føles som uretfærdighed.

signal collected(id: String)
signal expired(id: String)

const MAX_ON_SCREEN := 2
## Død og de andre hårde straffe holdes ude af de første fem levels.
const HARSH := ["death"]
const HARSH_SAFE_LEVELS := 5

var table: Dictionary = {}
var forced_first := ""
var level_number := 1
var paddle: Paddle
var kill_y := 844.0

var _capsules: Array[Powerup] = []
var _active: Dictionary = {}
var _last_was_bad := false
var _next_guaranteed_good := false
var _first_spawned := false


func configure(level_data: Dictionary) -> void:
	table = level_data.get("powerups", {})
	var forced: Variant = level_data.get("forcedFirstPowerup", null)
	forced_first = "" if forced == null else str(forced)
	level_number = int(level_data.get("id", 1))
	_first_spawned = false
	_last_was_bad = false


func reset_level() -> void:
	for capsule in _capsules:
		if is_instance_valid(capsule):
			capsule.queue_free()
	_capsules.clear()
	for id in _active.keys():
		expired.emit(id)
	_active.clear()
	_next_guaranteed_good = false


## Efter tab af liv er næste power-up garanteret god.
func guarantee_good() -> void:
	_next_guaranteed_good = true


## Klodsens egen chance afgør, om der overhovedet falder noget.
func roll_for(at: Vector2, chance: float) -> void:
	if chance <= 0.0 or randf() > chance:
		return
	spawn(at)


func spawn(at: Vector2) -> void:
	if _capsules.size() >= MAX_ON_SCREEN:
		return
	var id := _pick_id()
	if id.is_empty():
		return
	var capsule := Powerup.new()
	add_child(capsule)
	capsule.setup(id, at, kill_y)
	_capsules.append(capsule)
	_last_was_bad = not Powerup.is_good(id)
	if not Powerup.is_good(id):
		_next_guaranteed_good = false
	_first_spawned = true


func _pick_id() -> String:
	if table.is_empty():
		return ""
	if not _first_spawned and not forced_first.is_empty():
		return forced_first

	var must_be_good := _next_guaranteed_good or _last_was_bad
	var candidates: Array[String] = []
	var weights: Array[float] = []
	var total := 0.0
	for id in table:
		var name := str(id)
		if not Powerup.CATALOG.has(name):
			continue
		if level_number <= HARSH_SAFE_LEVELS and name in HARSH:
			continue
		if must_be_good and not Powerup.is_good(name):
			continue
		candidates.append(name)
		var w := float(table[id])
		weights.append(w)
		total += w

	if candidates.is_empty():
		return ""
	var pick := randf() * total
	for i in candidates.size():
		pick -= weights[i]
		if pick <= 0.0:
			return candidates[i]
	return candidates[candidates.size() - 1]


func active_effects() -> Dictionary:
	return _active


func is_active(id: String) -> bool:
	return _active.has(id)


func _process(delta: float) -> void:
	var i := _capsules.size() - 1
	while i >= 0:
		var capsule := _capsules[i]
		if not is_instance_valid(capsule):
			_capsules.remove_at(i)
		elif paddle and capsule.rect().intersects(paddle.world_rect()):
			var id := capsule.id
			capsule.implode_to(paddle.global_position)
			_capsules.remove_at(i)
			_apply(id)
		i -= 1

	for id in _active.keys():
		_active[id] = float(_active[id]) - delta
		if _active[id] <= 0.0:
			_active.erase(id)
			expired.emit(id)


func _apply(id: String) -> void:
	var duration := float(Powerup.info(id)["duration"])
	if duration > 0.0:
		# Samler man den samme op igen, starter uret forfra.
		_active[id] = duration
	if Powerup.is_good(id):
		_next_guaranteed_good = false
	collected.emit(id)
