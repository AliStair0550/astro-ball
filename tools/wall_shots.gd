extends Node

## Renders every wall in the zone to docs/walls/ for review.
##
## A tool, not a test. It uses the recording mode from section 18 to take
## the panel away, loads each level in turn, and captures one frame of
## each. The point is judging the mosaic rule at a glance: twelve walls
## side by side on a desk say things about a palette that no amount of
## looking at one of them can.
##
##   godot --path . tools/wall_shots.tscn

const OUT_DIR := "res://docs/walls"

var game: Game
var index := 0
var frames := 0


func _ready() -> void:
	seed(4)
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(OUT_DIR))
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game
	game.paddle.set_physics_process(false)
	game.recording = true
	process_priority = 300
	RenderingServer.frame_post_draw.connect(_capture)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 5 or index >= game.level_paths.size():
		return
	game._load_level(index)
	game._set_state(Game.State.PLAYING)
	# Blast bricks lit, so the wall is photographed the way it is played.
	for brick in game.grid.live_bricks():
		if brick.type == Brick.Type.BLAST:
			brick.proximity = 0.7
		if brick.type == Brick.Type.HIDDEN:
			brick.revealed = true
	game.grid.blind = false
	game.grid.queue_redraw()
	game.background.queue_redraw()
	game.arena.queue_redraw()


func _capture() -> void:
	if frames < 7 or index >= game.level_paths.size():
		return
	var name := str(game.level_data.get("name", "level")).to_lower().replace(" ", "_")
	var path := "%s/%02d_%s.png" % [OUT_DIR, index + 1, name]
	get_viewport().get_texture().get_image().save_png(ProjectSettings.globalize_path(path))
	print("saved %s" % path)
	index += 1
	if index >= game.level_paths.size():
		game.audio.stop_all()
		get_tree().quit()
