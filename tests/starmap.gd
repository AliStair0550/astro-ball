extends Node

## Section 15: the star chart. The layout has to survive a thumb, the
## figure has to be a figure, and the zone has to end on it.

const SaveGuard := preload("res://tests/save_guard.gd")

var game: Game
var fails := 0
var checks := 0


func _ready() -> void:
	seed(1509)
	SaveGuard.stash()
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game
	game.paddle.set_physics_process(false)
	call_deferred("_run")


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


func _run() -> void:
	_test_layout()
	_test_figure()
	_test_unlocking()
	_test_strings()
	await _test_flow()

	SaveGuard.restore()
	print("--- STAR MAP: %d checks, %d failures ---" % [checks, fails])
	game.audio.stop_all()
	await get_tree().create_timer(0.4).timeout
	game.free()
	await get_tree().process_frame
	get_tree().quit(1 if fails > 0 else 0)


func _test_layout() -> void:
	eq(StarMap.NODES.size(), 12, "one star per field in The Drift")
	eq(StarMap.NODES.size(), LevelLoader.level_paths().size(), "and the zone is that long")

	# Every star sits in the sky, clear of the header and the caption.
	for i in StarMap.NODES.size():
		var at: Vector2 = StarMap.NODES[i]
		ok(at.x > 30.0 and at.x < 360.0, "field %d is inside the screen in x" % [i + 1])
		ok(at.y > 200.0 and at.y < 670.0, "field %d is clear of the header and caption" % [i + 1])

	# A thumb is 45 px wide. Nothing may be close enough that one press
	# could be two fields.
	var closest := INF
	for i in StarMap.NODES.size():
		for j in range(i + 1, StarMap.NODES.size()):
			closest = minf(closest, StarMap.NODES[i].distance_to(StarMap.NODES[j]))
	ok(closest >= StarMap.TOUCH_RADIUS * 2.0,
		"no two stars are within a press of each other (%.0f px apart)" % closest)

	# And a press lands where it looks like it lands.
	var map := game.star_map
	var entries: Array[Dictionary] = []
	for i in 12:
		entries.append({"name": "F%d" % i, "bits": 0, "stars": 0, "cleared": false, "best_time": 0.0})
	map.open(entries, 0, false)
	for i in StarMap.NODES.size():
		eq(map.field_at(StarMap.NODES[i]), i, "a press on star %d chooses field %d" % [i + 1, i + 1])
	# Halfway along a line of the figure belongs to neither end. In a
	# chart this dense that matters more than a fixed distance does:
	# stars sit above and below each other, and the press has to go to
	# the one under the thumb.
	for edge in StarMap.EDGES:
		var middle: Vector2 = StarMap.NODES[edge.x].lerp(StarMap.NODES[edge.y], 0.5)
		eq(map.field_at(middle), -1,
			"a press between fields %d and %d chooses neither" % [edge.x + 1, edge.y + 1])
	eq(map.field_at(Vector2(20.0, 800.0)), -1, "a press on empty sky chooses nothing")


func _test_figure() -> void:
	# The lines have to describe the twelve stars that exist, and every
	# star has to be part of the figure. An orphan reads as a mistake.
	var touched := {}
	for edge in StarMap.EDGES:
		ok(edge.x >= 0 and edge.x < StarMap.NODES.size(), "a line starts at a real star")
		ok(edge.y >= 0 and edge.y < StarMap.NODES.size(), "and ends at one")
		ok(edge.x != edge.y, "and is not a star joined to itself")
		touched[edge.x] = true
		touched[edge.y] = true
	eq(touched.size(), StarMap.NODES.size(), "every field is part of the constellation")


func _test_unlocking() -> void:
	var entries: Array = []
	for i in 12:
		entries.append({"cleared": false})
	ok(StarMap.unlocked_in(entries, 0), "the first field is always open")
	ok(not StarMap.unlocked_in(entries, 1), "the second is not, until the first falls")
	entries[0]["cleared"] = true
	ok(StarMap.unlocked_in(entries, 1), "and then it is")
	ok(not StarMap.unlocked_in(entries, 2), "but only the next one")
	ok(not StarMap.unlocked_in(entries, 99), "and nothing past the end of the zone")

	var map := game.star_map
	var typed: Array[Dictionary] = []
	for i in 12:
		typed.append({"name": "F", "bits": 0, "stars": 0, "cleared": true, "best_time": 0.0})
	map.open(typed, 0, false)
	ok(map.is_zone_complete(), "twelve cleared fields is a finished zone")
	ok(map.reveal >= 1.0, "so the constellation is already drawn when you look at it")
	typed[7]["cleared"] = false
	map.open(typed, 7, false)
	ok(not map.is_zone_complete(), "one field standing and it is not")
	ok(map.reveal <= 0.0, "and there is no figure yet")
	# Straight from the last field, the figure draws itself while you watch.
	typed[7]["cleared"] = true
	map.open(typed, 11, true)
	ok(map.reveal <= 0.0, "the celebration starts with a blank sky")
	for i in 400:
		map._process(1.0 / 60.0)
	ok(map.reveal >= 1.0, "and ends with the constellation whole")


func _test_strings() -> void:
	for key in ["MAP_FIELD", "MAP_LOCKED", "MAP_LOCKED_HINT", "MAP_BEST",
			"BTN_LEVELS", "UNIVERSE_SELECT", "UNIVERSE_CLEARED", "UNIVERSE_SOON"]:
		ok(Strings.has(key), "the chart's '%s' is written down" % key)
	ok(Strings.fmt("MAP_FIELD", [7, "OFF AXIS"]).contains("OFF AXIS"), "and the caption fills in")


func _test_flow() -> void:
	var progress := get_node("/root/GameProgress")
	progress.reset()

	# The title asks one question: start, or change how it behaves.
	game._set_state(Game.State.SETTINGS)
	game._set_state(Game.State.TITLE)
	var ids := []
	for button in game.screens._buttons:
		ids.append(str(button["id"]))
	eq(ids.size(), 2, "the title offers two choices and no more")
	ok(ids.has("play") and ids.has("settings"), "start, or settings")
	eq(game._first_unfinished(), 0, "and a new save starts at level one")

	# Start asks the next question: which universe.
	game._on_screen_action("play")
	eq(game.state, Game.State.UNIVERSES, "start leads to the universe list")
	eq(game.screens.universes.size(), 5, "all five are on it")
	ok(bool(game.screens.universes[0]["open"]), "The Drift is open")
	eq(str(game.screens.universes[0]["name"]), "THE DRIFT", "and named, not numbered")
	for i in range(1, 5):
		ok(not bool(game.screens.universes[i]["open"]),
			"universe %d is not built yet" % [i + 1])
	game._on_screen_action("universe_3")
	eq(game.state, Game.State.UNIVERSES, "and pressing one of those goes nowhere")

	progress.record_clear(1, GameProgress.STAR_CLEARED, 44.0)
	eq(game._first_unfinished(), 1, "a cleared level moves the mark on")

	# The universe opens its own list of levels.
	game._on_screen_action("universe_1")
	eq(game.state, Game.State.STAR_MAP, "the chart opens")
	ok(game.star_map.visible, "and is on screen")
	ok(not game.grid.visible, "with the field put away behind it")
	eq(game.star_map.fields.size(), 12, "it charts the whole universe")
	ok(bool(game.star_map.fields[0]["cleared"]), "level one is lit")
	ok(not bool(game.star_map.fields[1]["cleared"]), "level two is not")
	ok(game.star_map.unlocked(1), "but it is open")
	ok(not game.star_map.unlocked(2), "and level three is not")

	# Choosing a field starts it.
	game._on_field_chosen(1)
	eq(game.state, Game.State.LEVEL_INTRO, "choosing a level starts it")
	eq(int(game.level_data["id"]), 2, "the one that was chosen")
	ok(not game.star_map.visible, "and the list steps out of the way")

	# And back from the levels is the universe list, not the title.
	game._open_chart(false)
	game._on_map_action("back")
	eq(game.state, Game.State.UNIVERSES, "back goes where the player came from")

	# The zone ends on the chart rather than wrapping round to field one.
	game._load_level(11)
	game._begin_level()
	game._next_level()
	eq(game.state, Game.State.STAR_MAP, "the field after the last one is the chart")
	ok(game.star_map.visible, "which is where the zone ends")

	progress.reset()
	await get_tree().process_frame
