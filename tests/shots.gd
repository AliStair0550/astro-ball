extends Node

## Værktøj, ikke test. Sætter spillet i en bestemt tilstand lige før
## hver tegning og gemmer et PNG til user://, så det visuelle kan
## efterses uden at sidde og spille efter det rigtige øjeblik.

var game: Game
var frames := 0
var index := 0
var names := ["01_level1", "02_level2_skade", "03_level3", "04_effekter", "05_powerups", "06_bred_laser"]


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
	if frames < 4 or index >= names.size():
		return
	game.paddle.position.x = 195.0
	match index:
		0:
			game.score = 12400
			game._refresh_hud()
			game.hud.displayed_score = 12400.0
		1:
			if int(game.level_data.get("id", 0)) != 2:
				game._load_level(1)
				for col in range(2, 11):
					var brick := game.grid.brick_at(col, 2)
					if brick and col % 3 == 1:
						game.grid.hit(brick)
						brick.flash = 0.0
						brick.shake = 0.0
					elif brick and col % 3 == 2:
						game.grid.hit(brick)
						game.grid.hit(brick)
						brick.flash = 0.0
						brick.shake = 0.0
				game.score = 3200
				game.lives = 2
				game._refresh_hud()
				game.hud.displayed_score = 3200.0
		2:
			if int(game.level_data.get("id", 0)) != 3:
				game._load_level(2)
				game.grid.brick_at(6, 9).revealed = true
				for brick in game.grid.live_bricks():
					if brick.type == Brick.Type.BLAST:
						brick.proximity = 1.0
				game.score = 800
				game.combo = 7
				game._refresh_hud()
				game.hud.displayed_score = 800.0
		3:
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
		4:
			for child in game.powerups.get_children():
				child.queue_free()
			game.powerups._capsules.clear()
			var good := Powerup.new()
			game.powerups.add_child(good)
			good.setup("multi", Vector2(120.0, 560.0), 900.0)
			var bad := Powerup.new()
			game.powerups.add_child(bad)
			bad.setup("narrow", Vector2(250.0, 600.0), 900.0)
			game.powerups._active = {"fireball": 8.4, "laser": 11.2, "zap": 3.1}
			game._refresh_hud()
		5:
			game.paddle.set_width(Paddle.WIDTH_WIDE)
			game.paddle.laser = true
			game.paddle._bolts = [
				{"pos": Vector2(153.0, 640.0), "alive": true},
				{"pos": Vector2(237.0, 640.0), "alive": true},
			]
			if not game._balls.is_empty():
				var ball := game._balls[0]
				ball.stuck = false
				ball.fireball = true
				ball.global_position = Vector2(200.0, 540.0)
				ball.velocity = Vector2(140.0, -330.0)
				for i in ball._trail.size():
					ball._trail[i] = ball.global_position + Vector2(-2.0 * i, 5.0 * i)
	game.arena.queue_redraw()
	game.grid.queue_redraw()
	game.paddle.queue_redraw()
	game.hud.queue_redraw()
	game.background.queue_redraw()


func _capture() -> void:
	if frames < 6 or index >= names.size():
		return
	var img := get_viewport().get_texture().get_image()
	img.save_png("user://%s.png" % names[index])
	print("gemte %s" % names[index])
	index += 1
	if index >= names.size():
		get_tree().quit()
