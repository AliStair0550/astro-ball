extends SceneTree

var arena: Arena
var paddle: Paddle
var grid: BrickGrid
var ball: Ball


func _initialize() -> void:
	arena = Arena.new()
	get_root().add_child(arena)
	if arena.wall_segments().is_empty():
		arena._build_walls()
	print("walls: ", arena.wall_segments().size())

	paddle = Paddle.new()
	paddle.position = Vector2(195.0, 780.0)
	get_root().add_child(paddle)
	paddle.set_bounds(6.0, 384.0)

	grid = BrickGrid.new()
	get_root().add_child(grid)
	var level: Dictionary = LevelLoader.load_level("res://levels/level_03.json")["data"]
	grid.build(level["grid"], 0.0)

	ball = Ball.new()
	ball.arena = arena
	ball.paddle = paddle
	ball.grid = grid
	get_root().add_child(ball)
	ball.stuck = false

	_probe_glass_row()
	_probe_strand()
	_probe_stall()
	quit(0)


func _legal(label: String) -> void:
	print("   [%s] pos=%s r=%.2f overlapping=%s" % [label, str(ball.global_position), ball.radius, str(ball._is_overlapping())])


func _probe_glass_row() -> void:
	print("")
	print("=== 1. Giant caught while the ball is inside a Glass brick (level 3, row 5) ===")
	# Row 5 is ".GGEGG.GGEGG." - the ball legally passes through glass, so
	# its centre inside one of them is a normal end-of-tick state.
	var g1 := grid.brick_at(1, 5)
	var g2 := grid.brick_at(2, 5)
	var e := grid.brick_at(3, 5)
	print("  G(col1)=", g1.rect, " G(col2)=", g2.rect, " E(col3)=", e.rect)
	ball.giant = false
	ball._pending_radius = 0.0
	ball.radius = Ball.BASE_RADIUS
	# Travelling right through the glass row, centre inside the col-2 glass.
	ball.global_position = g2.rect.get_center()
	ball.velocity = Vector2(360.0, 40.0)
	_legal("before growth")
	var before := ball.global_position
	ball.giant = true
	print("  after giant=true: pos=%s moved=%.2f radius=%.2f pending=%.2f overlapping=%s"
		% [str(ball.global_position), before.distance_to(ball.global_position),
			ball.radius, ball._pending_radius, str(ball._is_overlapping())])
	for col in range(0, 7):
		var b: Brick = grid.brick_at(col, 5)
		if b != null and b.rect.has_point(ball.global_position):
			print("  -> ball CENTRE now sits inside the %s brick at col %d %s"
				% [Brick.DATA[b.type]["name"], col, str(b.rect)])
	for col in range(0, 13):
		var b6: Brick = grid.brick_at(col, 6)
		if b6 != null and b6.rect.has_point(ball.global_position):
			print("  -> ball CENTRE now sits inside the %s brick at row 6 col %d %s"
				% [Brick.DATA[b6.type]["name"], col, str(b6.rect)])


func _probe_strand() -> void:
	print("")
	print("=== 2. Giant ends while the growth is still pending ===")
	print("  state: giant=%s radius=%.2f pending=%.2f" % [str(ball.giant), ball.radius, ball._pending_radius])
	if ball._pending_radius <= 0.0:
		print("  (no growth pending - forcing the deferred state the same way the")
		print("   setter does, to show what the early return costs)")
		ball.radius = Ball.BASE_RADIUS
		ball._pending_radius = Ball.BASE_RADIUS * Ball.GIANT_SCALE
	# This is exactly what powerup_manager._apply("fireball") -> expired("giant")
	# -> game._sync_powerup_state() does one frame later.
	ball.giant = false
	ball.fireball = true
	print("  after giant=false, fireball=true: giant=%s radius=%.2f pending=%.2f"
		% [str(ball.giant), ball.radius, ball._pending_radius])
	# Put the ball somewhere with room, then run one real physics tick.
	ball.global_position = Vector2(195.0, 700.0)
	ball.velocity = Vector2(0.0, -360.0)
	ball._physics_process(1.0 / 60.0)
	print("  after one _physics_process: giant=%s fireball=%s radius=%.2f look=%s pending=%.2f"
		% [str(ball.giant), str(ball.fireball), ball.radius, str(Ball.Look.keys()[ball.look()]), ball._pending_radius])
	# And it never comes back on its own: sync sets giant=false again.
	ball.giant = false
	print("  after another giant=false (sync runs every collect/expire): radius=%.2f" % ball.radius)


func _probe_stall() -> void:
	print("")
	print("=== 3. Stall guard: giant ball between the left wall and the paddle ===")
	ball.giant = false
	ball._pending_radius = 0.0
	ball.radius = Ball.BASE_RADIUS
	ball.fireball = false
	var empty := BrickGrid.new()
	get_root().add_child(empty)
	empty.build(["............."], 0.0)
	ball.grid = empty

	# The paddle teleports to the mouse every tick, so it can close on a
	# ball that was legally beside it a frame earlier.
	paddle.position = Vector2(60.0, 780.0)  # left edge x = 16
	print("  paddle rect ", paddle.world_rect())
	ball.radius = Ball.BASE_RADIUS * Ball.GIANT_SCALE
	ball.giant = true
	ball.global_position = Vector2(11.0, 778.0)
	ball.velocity = Vector2(-300.0, 120.0)
	print("  wedged at ", ball.global_position, " r=", ball.radius,
		" overlapping=", ball._is_overlapping())
	print("  free_from_overlaps -> ", ball._free_from_overlaps(), " pos ", ball.global_position)
	ball.global_position = Vector2(11.0, 778.0)
	for tick in 4:
		var p0 := ball.global_position
		var v0 := ball.velocity
		ball._advance(1.0 / 60.0)
		print("   tick %d: pos %s moved %.4f  vel %s -> %s"
			% [tick, str(ball.global_position), p0.distance_to(ball.global_position), str(v0), str(ball.velocity)])
		ball._resolve_paddle_overlap()
		print("           after paddle resolve: pos %s vel %s" % [str(ball.global_position), str(ball.velocity)])

	print("")
	print("=== 4. paddle rescue reach for a giant ball ===")
	paddle.position = Vector2(195.0, 780.0)
	for r: float in [4.0, 8.0]:
		for gap: float in [3.0, 5.0, 7.0]:
			ball.giant = false
			ball._pending_radius = 0.0
			ball.radius = r
			var pr := paddle.world_rect()
			ball.global_position = Vector2(pr.position.x - gap, pr.position.y + 2.0)
			ball.velocity = Vector2(-40.0, 300.0)
			var p0 := ball.global_position
			ball._resolve_paddle_overlap()
			print("   r=%.0f, %.0f px clear of the paddle's left edge: pos %s -> %s, vel %s"
				% [r, gap, str(p0), str(ball.global_position), str(ball.velocity)])
