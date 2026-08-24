extends Node

## Mekanik uden tidsforbrug: gridet, klodserne, level-validering,
## power-up-reglerne og boldens sweep. Tiden drives i hånden.

var fails := 0
var checks := 0


func _ready() -> void:
	seed(4242)
	_test_level_validation()
	_test_broken_levels()
	_test_geometry()
	_test_grid_counts()
	_test_hardened()
	_test_blast_chain()
	_test_hidden_reveal()
	_test_glass_and_stone()
	_test_zap()
	_test_clear_pops_stones()
	_test_sweep_vs_brick()
	_test_powerup_rules()
	_test_paddle_states()
	print("--- MEKANIK: %d tjek, %d fejl ---" % [checks, fails])
	get_tree().quit(1 if fails > 0 else 0)


func ok(condition: bool, label: String) -> void:
	checks += 1
	if not condition:
		fails += 1
		print("  FEJL: %s" % label)


func eq(got: Variant, want: Variant, label: String) -> void:
	checks += 1
	if got != want:
		fails += 1
		print("  FEJL: %s (fik %s, ville have %s)" % [label, str(got), str(want)])


func _test_level_validation() -> void:
	var paths := LevelLoader.level_paths()
	eq(paths.size(), 3, "tre levelfiler findes")
	for path in paths:
		var result := LevelLoader.load_level(path)
		ok(result["ok"], "%s validerer: %s" % [path, ", ".join(result["errors"])])
	var one: Dictionary = LevelLoader.load_level("res://levels/01_afgang.json")["data"]
	eq(LevelLoader.breakable_count(one["grid"]), 47, "level 1 har 47 klodser")
	eq(str(one["forcedFirstPowerup"]), "wide", "level 1 tvinger Bred først")
	# Langsom hører til, når det bliver svært, ikke i de første baner.
	for path in paths:
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		ok(not data.get("powerups", {}).has("slow"), "%s har ingen Langsom" % path)


func _test_broken_levels() -> void:
	var base := {
		"grid": [".VVVVVVVVVVV.", ".VVVVVVVVVVV."],
		"powerups": {"wide": 100},
	}
	ok(LevelLoader.validate(base).is_empty(), "gyldigt testlevel giver ingen fejl")

	var short_row := base.duplicate(true)
	short_row["grid"][0] = ".VVVVVVVVVV."
	ok(not LevelLoader.validate(short_row).is_empty(), "12 tegn i en række afvises")

	var too_tall := base.duplicate(true)
	too_tall["grid"] = []
	for i in 13:
		too_tall["grid"].append(".VVVVVVVVVVV.")
	ok(not LevelLoader.validate(too_tall).is_empty(), "13 rækker afvises")

	var stone_bottom := base.duplicate(true)
	stone_bottom["grid"][1] = ".VVVVVSVVVVV."
	ok(not LevelLoader.validate(stone_bottom).is_empty(), "Sten i nederste række afvises")

	var too_few := base.duplicate(true)
	too_few["grid"] = [".VVVVV.......", "............."]
	ok(not LevelLoader.validate(too_few).is_empty(), "under 20 klodser afvises")

	var bad_sum := base.duplicate(true)
	bad_sum["powerups"] = {"wide": 40, "multi": 40}
	ok(not LevelLoader.validate(bad_sum).is_empty(), "power-up-sum under 100 afvises")

	var bad_symbol := base.duplicate(true)
	bad_symbol["grid"][0] = ".VVVVZVVVVVV."
	ok(not LevelLoader.validate(bad_symbol).is_empty(), "ukendt tegn afvises")

	var bad_powerup := base.duplicate(true)
	bad_powerup["powerups"] = {"tidsmaskine": 100}
	ok(not LevelLoader.validate(bad_powerup).is_empty(), "ukendt power-up afvises")


func _test_geometry() -> void:
	var left := BrickGrid.ORIGIN.x
	var right := BrickGrid.ORIGIN.x + 12.0 * BrickGrid.PITCH.x + Brick.SIZE.x
	var inner := Rect2(Arena.WALL, Arena.HUD_HEIGHT + Arena.WALL,
		Arena.SCREEN.x - Arena.WALL * 2.0, Arena.SCREEN.y - Arena.HUD_HEIGHT - Arena.WALL)
	ok(left > inner.position.x, "gridet starter inde i feltet (%.1f > %.1f)" % [left, inner.position.x])
	ok(right < inner.end.x, "gridet slutter inde i feltet (%.1f < %.1f)" % [right, inner.end.x])
	eq(Brick.SIZE, Vector2(24.0, 16.0), "klodsen er 24x16")
	eq(BrickGrid.SPACING, 2.0, "2 px mellem klodser")
	ok(BrickGrid.ORIGIN.y > Arena.HUD_HEIGHT + Arena.WALL, "gridet starter under rammen")

	# Selv et level med alle 12 rækker skal holde afstand til paddlen.
	var deepest := BrickGrid.ORIGIN.y + 12.0 * BrickGrid.PITCH.y
	var paddle_top := Arena.SCREEN.y - 64.0 - Paddle.HEIGHT * 0.5
	ok(paddle_top - deepest > 300.0,
		"12 rækker efterlader mindst 300 px til paddlen (%.0f)" % (paddle_top - deepest))
	# Og HUD'en skal fylde nok til, at klodserne ikke sidder i toppen.
	ok(Arena.HUD_HEIGHT >= 120.0, "HUD'en fylder toppen (%.0f px)" % Arena.HUD_HEIGHT)


func _make_grid(rows: Array) -> BrickGrid:
	var g := BrickGrid.new()
	add_child(g)
	g.build(rows)
	return g


func _pump(g: BrickGrid, seconds: float) -> void:
	var step := 1.0 / 60.0
	var t := 0.0
	while t < seconds:
		g._process(step)
		t += step


func _test_grid_counts() -> void:
	var data: Dictionary = LevelLoader.load_level("res://levels/02_kapslen.json")["data"]
	var g := _make_grid(data["grid"])
	eq(g.rows, 10, "level 2 har 10 rækker")
	eq(g.remaining_breakable(), 68, "level 2 har 68 smadrelige klodser")
	ok(g.brick_at(1, 0) != null and g.brick_at(1, 0).type == Brick.Type.STONE, "Sten i hjørnet")
	ok(not g.brick_at(1, 0).counts_toward_clear(), "Sten tæller ikke mod level clear")
	g.queue_free()


func _test_hardened() -> void:
	var g := _make_grid([".HHHHHHHHHHH.", ".VVVVVVVVVVV."])
	var h := g.brick_at(1, 0)
	eq(h.hits_left, 3, "Hærdet har 3 slag")
	eq(h.damage_stage(), 0, "uskadt Hærdet er stadie 0")
	ok(not g.hit(h), "første slag smadrer ikke")
	eq(h.damage_stage(), 1, "efter ét slag er stadie 1")
	ok(not g.hit(h), "andet slag smadrer ikke")
	eq(h.damage_stage(), 2, "efter to slag er stadie 2")
	ok(g.hit(h), "tredje slag smadrer")
	ok(not h.alive, "Hærdet er væk")
	eq(h.score_value(), 300, "Hærdet giver triple point")
	g.queue_free()


func _test_blast_chain() -> void:
	var g := _make_grid([".VVV.........", ".VEV.........", ".VVV........."])
	eq(g.remaining_breakable(), 9, "ni klodser før")
	var blast := g.brick_at(2, 1)
	eq(blast.type, Brick.Type.BLAST, "midterklodsen er en sprængklods")
	ok(g.hit(blast), "sprængklodsen smadres")
	_pump(g, 0.05)
	ok(g.remaining_breakable() > 0, "kæden er ikke færdig efter 50 ms")
	_pump(g, 0.5)
	eq(g.remaining_breakable(), 0, "alle 8 naboer er taget af kæden")
	g.queue_free()

	# En sprængklods to felter væk er ikke nabo og skal IKKE gå af.
	var g_far := _make_grid([".VVVVV.......", ".VEVEV.......", ".VVVVV......."])
	ok(g_far.hit(g_far.brick_at(2, 1)), "sprængklodsen smadres")
	_pump(g_far, 1.0)
	ok(g_far.brick_at(4, 1).alive, "sprængklods to felter væk går ikke af")
	eq(g_far.remaining_breakable(), 6, "kun de 8 naboer røg")
	g_far.queue_free()

	# Kædereaktion: nabo-sprængklods udløser sin egen ring.
	var g2 := _make_grid([".VVVV........", ".VEEV........", ".VVVV........"])
	eq(g2.remaining_breakable(), 12, "tolv klodser før kæden")
	ok(g2.hit(g2.brick_at(2, 1)), "første sprængklods smadres")
	_pump(g2, 1.5)
	eq(g2.remaining_breakable(), 0, "kæden fortsatte gennem nabo-sprængklodsen")
	g2.queue_free()


func _test_hidden_reveal() -> void:
	var g := _make_grid([".V?..........", ".VV.........."])
	var hidden := g.brick_at(2, 0)
	eq(hidden.type, Brick.Type.HIDDEN, "skjult klods indlæst")
	ok(not hidden.revealed, "skjult klods er skjult fra start")
	ok(not g.bricks_in(hidden.rect.grow(2.0)).has(hidden), "skjult klods rammes ikke af bolden")
	g.hit(g.brick_at(1, 0))
	ok(hidden.revealed, "skjult klods viser sig, når naboen smadres")
	ok(g.bricks_in(hidden.rect.grow(2.0)).has(hidden), "afsløret klods kan nu rammes")
	g.queue_free()


func _test_glass_and_stone() -> void:
	var g := _make_grid([".GS..........", ".VV.........."])
	var glass := g.brick_at(1, 0)
	var stone := g.brick_at(2, 0)
	ok(glass.lets_ball_pass(), "Glas lader bolden gå igennem")
	eq(glass.shard_count(), 12, "Glas splintrer i 12 skår")
	ok(g.hit(glass), "Glas smadres alligevel")
	ok(not stone.is_breakable(), "Sten kan ikke smadres")
	ok(not g.hit(stone), "slag mod Sten gør intet")
	ok(stone.alive, "Sten står stadig")
	g.queue_free()


func _test_zap() -> void:
	var g := _make_grid([".VVVVV.......", ".VVVVV......."])
	g.zap_neighbours(g.brick_at(3, 0))
	_pump(g, 0.2)
	ok(not g.brick_at(2, 0).alive, "Zap tog naboen til venstre")
	ok(not g.brick_at(4, 0).alive, "Zap tog naboen til højre")
	ok(g.brick_at(3, 1).alive, "Zap tog ikke klodsen nedenunder")
	g.queue_free()


func _test_clear_pops_stones() -> void:
	var g := _make_grid([".S.V.......S.", "............."])
	var cleared := [false]
	g.cleared.connect(func(): cleared[0] = true)
	var popped := [0]
	g.stone_popped.connect(func(_b): popped[0] += 1)
	g.hit(g.brick_at(3, 0))
	ok(cleared[0], "level clear udløses, når de smadrelige er væk")
	_pump(g, 1.0)
	eq(popped[0], 2, "begge Sten-kerner eksploderer i rækkefølge")
	g.queue_free()


func _test_sweep_vs_brick() -> void:
	var rect := Rect2(100.0, 100.0, 24.0, 16.0)
	var from_below := Ball._sweep_circle_rect(Vector2(112.0, 130.0), Vector2(0.0, -20.0), 4.0, rect)
	ok(from_below["hit"], "sweep rammer undersiden")
	ok(from_below["normal"].is_equal_approx(Vector2(0.0, 1.0)), "normal peger nedad")
	ok(absf(float(from_below["t"]) - 0.5) < 0.01, "kontakt halvvejs (t=%.3f)" % from_below["t"])
	var from_side := Ball._sweep_circle_rect(Vector2(80.0, 108.0), Vector2(30.0, 0.0), 4.0, rect)
	ok(from_side["hit"], "sweep rammer venstre side")
	ok(from_side["normal"].is_equal_approx(Vector2(-1.0, 0.0)), "normal peger til venstre")
	var miss := Ball._sweep_circle_rect(Vector2(200.0, 108.0), Vector2(0.0, 30.0), 4.0, rect)
	ok(not miss["hit"], "sweep forbi klodsen rammer ikke")


func _test_powerup_rules() -> void:
	var pm := PowerupManager.new()
	add_child(pm)
	var paddle := Paddle.new()
	paddle.position = Vector2(195.0, 780.0)
	add_child(paddle)
	pm.paddle = paddle
	pm.configure(LevelLoader.load_level("res://levels/01_afgang.json")["data"])

	eq(pm._pick_id(), "wide", "level 1 tvinger Bred som første power-up")
	pm.spawn(Vector2(195.0, 300.0))
	pm.spawn(Vector2(180.0, 300.0))
	pm.spawn(Vector2(160.0, 300.0))
	eq(pm._capsules.size(), 2, "maks 2 kapsler på skærmen")

	pm.configure(LevelLoader.load_level("res://levels/03_kaeden.json")["data"])
	var bad_in_a_row := 0
	var worst := 0
	for i in 400:
		pm.reset_level()
		pm._last_was_bad = true
		if not Powerup.is_good(pm._pick_id()):
			bad_in_a_row += 1
	eq(bad_in_a_row, 0, "efter en dårlig kommer aldrig en dårlig")

	for i in 200:
		pm.reset_level()
		pm.guarantee_good()
		if not Powerup.is_good(pm._pick_id()):
			worst += 1
	eq(worst, 0, "efter tab af liv er næste power-up god")

	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		for id in data.get("powerups", {}):
			ok(Powerup.CATALOG.has(str(id)), "%s kender power-up '%s'" % [path, str(id)])

	eq(Brick.DATA[Brick.Type.SPARK]["powerup"], 1.0, "Gnist giver garanteret power-up")

	# Fordelingen skal følge tabellen, ellers er en power-up de facto død.
	pm.configure(LevelLoader.load_level("res://levels/01_afgang.json")["data"])
	var counts := {}
	for i in 4000:
		pm.reset_level()
		pm._first_spawned = true
		var id := pm._pick_id()
		counts[id] = int(counts.get(id, 0)) + 1
	for id in ["multi", "fireball", "laser", "wide"]:
		var share := 100.0 * float(counts.get(id, 0)) / 4000.0
		var want := float(pm.table[id])
		ok(absf(share - want) < 3.0,
			"level 1 trækker %s %.1f %% mod tabellens %.0f %%" % [id, share, want])
	pm.queue_free()
	paddle.queue_free()


func _test_paddle_states() -> void:
	var p := Paddle.new()
	add_child(p)
	p.position = Vector2(195.0, 780.0)
	p.set_bounds(6.0, 384.0)

	p.set_width(Paddle.WIDTH_NORMAL)
	eq(p.segment_count(), 3, "normal paddle har tre segmenter")
	eq(p.sweet_offsets().size(), 1, "normal paddle har ét sweet spot")
	ok(p.is_sweet(0.0) and p.is_sweet(3.9) and not p.is_sweet(5.0), "sweet spot er 8 px bredt")

	p.set_width(Paddle.WIDTH_WIDE)
	eq(p.segment_count(), 5, "bred paddle har fem segmenter")
	eq(p.sweet_offsets().size(), 2, "bred paddle har to sweet spots")
	eq(p.width, 132.0, "bred paddle er 132 px")
	eq(p._seam_positions().size(), 4, "fem segmenter giver fire samlinger")

	p.set_width(Paddle.WIDTH_NARROW)
	eq(p.segment_count(), 1, "smal paddle har ét segment")
	ok(not p.has_sweet_spot(), "smal paddle har ingen sweet spot")
	ok(not p.is_sweet(0.0), "smal paddle giver aldrig sweet spot")
	eq(p._seam_positions().size(), 0, "ét segment har ingen samlinger")

	p.set_width(Paddle.WIDTH_WIDE)
	ok(p.min_x >= 6.0 + 66.0 - 0.01 and p.max_x <= 384.0 - 66.0 + 0.01, "bred paddle holdes inde i feltet")
	p.queue_free()
