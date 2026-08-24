extends Node

## A tool, not a test. Puts the game into a known state just before each
## draw and saves a PNG to user://, so the visuals can be inspected
## without playing for the right moment.

var game: Game
var frames := 0
var index := 0
var names := [
	"01_title", "02_settings", "03_level_intro", "04_level1",
	"05_level3", "06_effects", "07_wide_laser", "08_signal_lost", "09_crt",
]


func _ready() -> void:
	seed(7)
	process_priority = 300
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game
	game.paddle.set_physics_process(false)
	RenderingServer.frame_post_draw.connect(_capture)


func _process(_delta: float) -> void:
	frames += 1
	if frames < 5 or index >= names.size():
		return
	game.paddle.position.x = 195.0
	match index:
		0:
			get_node("/root/GameProgress").high_score = 41200
			game._set_state(Game.State.TITLE)
		1:
			game._set_state(Game.State.SETTINGS)
			game.screens._hover = 0
		2:
			game._set_state(Game.State.LEVEL_INTRO)
			game.screens._fade = 1.0
			game.screens._time = 0.9
		3:
			game._set_state(Game.State.PLAYING)
			game.score = 12400
			game._refresh_hud()
			game.hud.displayed_score = 12400.0
		4:
			if int(game.level_data.get("id", 0)) != 3:
				game._load_level(2)
				game._set_state(Game.State.PLAYING)
				if game.grid.brick_at(6, 8): game.grid.brick_at(6, 8).revealed = true
				for brick in game.grid.live_bricks():
					if brick.type == Brick.Type.BLAST:
						brick.proximity = 1.0
				game.score = 800
				game.combo = 7
				game._refresh_hud()
				game.hud.displayed_score = 800.0
		5:
			var brick := game.grid.brick_at(5, 8)
			var blast := game.grid.brick_at(6, 7)
			if brick and brick.alive:
				game.combo = 12
				game._on_brick_destroyed(brick, false)
				brick.alive = false
			if blast and blast.alive:
				game._on_brick_destroyed(blast, false)
				blast.alive = false
			game.effects.combo(12)
			game._refresh_hud()
			game.effects._process(0.06)
			game.effects.queue_redraw()
			game.paddle._left_light = 1.0
			game.paddle._scale_y = 0.9
		6:
			for child in game.powerups.get_children():
				child.queue_free()
			game.powerups._capsules.clear()
			var cap_a := Powerup.new()
			game.powerups.add_child(cap_a)
			cap_a.setup("giant", Vector2(105.0, 590.0), 900.0)
			var cap_b := Powerup.new()
			game.powerups.add_child(cap_b)
			cap_b.setup("multi", Vector2(215.0, 660.0), 900.0)
			var cap_c := Powerup.new()
			game.powerups.add_child(cap_c)
			cap_c.setup("narrow", Vector2(310.0, 620.0), 900.0)
			game.paddle.set_width(Paddle.WIDTH_WIDE)
			game.paddle.laser = true
			game.paddle._bolts = [
				{"pos": Vector2(153.0, 640.0), "alive": true},
				{"pos": Vector2(237.0, 640.0), "alive": true},
			]
			game.powerups._active = {"fireball": 8.4, "laser": 11.2, "zap": 3.1}
			game._refresh_hud()
			if not game._balls.is_empty():
				var ball := game._balls[0]
				ball.stuck = false
				ball.frozen = false
				ball.fireball = true
				ball.global_position = Vector2(200.0, 560.0)
				ball.velocity = Vector2(140.0, -330.0)
				for i in ball._trail.size():
					ball._trail[i] = ball.global_position + Vector2(-2.0 * i, 5.0 * i)
		7:
			game.score = 45500
			game.run.run_bricks = 168
			game.run.best_combo = 14
			game.run.run_time = 252.0
			game.screens.high_score = 41200
			game._set_state(Game.State.SIGNAL_LOST)
			game.screens.new_record = true
			game.screens._fade = 1.0
		8:
			game._set_state(Game.State.PLAYING)
			get_node("/root/GameSettings").crt = true
			get_node("/root/GameSettings").changed.emit()
	game.arena.queue_redraw()
	game.grid.queue_redraw()
	game.paddle.queue_redraw()
	game.hud.queue_redraw()
	game.background.queue_redraw()
	game.screens.queue_redraw()


func _capture() -> void:
	if frames > 2400:
		push_error("shots: gave up at image %d" % index)
		get_tree().quit(1)
		return
	if frames < 7 or index >= names.size():
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % names[index])
	print("saved %s (frame %d)" % [names[index], frames])
	index += 1
	if index >= names.size():
		get_node("/root/GameSettings").crt = false
		get_node("/root/GameSettings").save_settings()
		get_tree().quit()
