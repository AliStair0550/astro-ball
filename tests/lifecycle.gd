extends Node

## Spillets tilstande: liv, game over, level-progression, fartstigning.

var game: Game
var fails := 0
var checks := 0


func _ready() -> void:
	seed(11)
	var scene: Node = load("res://scenes/game.tscn").instantiate()
	add_child(scene)
	game = scene as Game
	game.paddle.set_physics_process(false)
	call_deferred("_run")


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


func about(got: float, want: float, tol: float, label: String) -> void:
	checks += 1
	if absf(got - want) > tol:
		fails += 1
		print("  FEJL: %s (fik %.2f, ville have %.2f)" % [label, got, want])


func _kill_all_balls() -> void:
	for ball in game._balls.duplicate():
		ball.global_position = Vector2(195.0, game.arena.death_y + 20.0)
		game._on_ball_lost(ball)


func _skip_pause() -> void:
	game._state_timer = 0.0
	game._advance_state()


func _run() -> void:
	_test_opening()
	_test_speed_ramp()
	_test_multiball_and_lives()
	_test_game_over()
	_test_level_progression()
	_test_level_clear_freeze()
	_test_scoring()
	_test_settings()
	_test_audio_bank()
	_test_english()

	print("--- LIVSCYKLUS: %d tjek, %d fejl ---" % [checks, fails])
	await _teardown()
	get_tree().quit(1 if fails > 0 else 0)


## Spillet aabner paa titelskaermen, ikke midt i en bane.
func _test_opening() -> void:
	eq(game.state, Game.State.TITLE, "spillet aabner paa titelskaermen")
	ok(game.screens.is_open(), "titelskaermen er synlig")
	ok(not game._balls[0].input_enabled, "bolden kan ikke affyres bag en skaerm")
	ok(not game.paddle.input_enabled, "paddlen staar stille bag en skaerm")

	game._on_screen_action("settings")
	eq(game.state, Game.State.SETTINGS, "SETTINGS aabner fra titlen")
	game._on_screen_action("back")
	eq(game.state, Game.State.TITLE, "BACK foerer tilbage til titlen")

	game._on_screen_action("play")
	eq(game.state, Game.State.LEVEL_INTRO, "PLAY foerer til level-introen")
	eq(int(game.level_data["id"]), 1, "introen viser level 1")
	eq(game.screens.level_title, "Departure", "introen viser banens navn")
	eq(game.lives, 3, "spillet starter med tre liv")
	eq(game.score, 0, "scoren starter paa nul")

	game._on_screen_action("skip")
	eq(game.state, Game.State.PLAYING, "et klik springer introen over")
	ok(game._balls[0].input_enabled, "bolden kan affyres, naar banen koerer")
	ok(game._balls[0].stuck, "bolden starter klaebet til paddlen")
	eq(game.grid.remaining_breakable(), 47, "level 1 har 47 klodser")


## Afsnit 4: hastigheden stiger 4 procent per 10 klodser, maks 520.
func _test_speed_ramp() -> void:
	var base := float(game.level_data["ballSpeed"])
	game._bricks_this_level = 0
	about(game.level_ball_speed(), base, 0.01, "farten starter på levelets egen")
	game._bricks_this_level = 9
	about(game.level_ball_speed(), base, 0.01, "ni klodser giver stadig grundfarten")
	game._bricks_this_level = 10
	about(game.level_ball_speed(), base * 1.04, 0.01, "ti klodser giver 4 procent mere")
	game._bricks_this_level = 30
	about(game.level_ball_speed(), base * pow(1.04, 3), 0.01, "tredive klodser giver tre trin")
	game._bricks_this_level = 10000
	about(game.level_ball_speed(), 520.0, 0.01, "farten stopper ved loftet på 520")

	# Bolden retter sin fart med det samme, ikke en frame senere.
	game._bricks_this_level = 0
	game._apply_ball_speed()
	var ball := game._balls[0]
	ball.launch()
	game._bricks_this_level = 50
	game._apply_ball_speed()
	about(ball.velocity.length(), ball.current_speed(), 0.01, "boldens fart følger med samme frame")
	game._bricks_this_level = 0
	game._apply_ball_speed()


func _test_multiball_and_lives() -> void:
	if game._balls[0].stuck:
		game._balls[0].launch()
	game._split_balls()
	eq(game._balls.size(), 3, "Multi gav tre bolde")
	var doomed := game._balls[2]
	doomed.global_position = Vector2(195.0, game.arena.death_y + 20.0)
	game._on_ball_lost(doomed)
	eq(game._balls.size(), 2, "den tabte bold er væk")
	eq(game.lives, 3, "et liv koster det kun, når sidste bold ryger")

	game.paddle.set_width(Paddle.WIDTH_WIDE)
	game.powerups._active["laser"] = 10.0
	game.paddle.laser = true
	_kill_all_balls()
	eq(game.lives, 2, "sidste bold koster et liv")
	eq(game.state, Game.State.BALL_LOST, "tilstand er BALL_LOST")
	eq(game._balls.size(), 0, "ingen bolde i pausen")
	eq(game.paddle.width, Paddle.WIDTH_NORMAL, "paddlen er tilbage på 88 px")
	ok(not game.paddle.laser, "laseren slukkes ved tab af liv")
	ok(game.powerups.active_effects().is_empty(), "aktive power-ups ryddes ved tab af liv")
	ok(game.powerups._next_guaranteed_good, "næste power-up er garanteret god")
	ok(Powerup.is_good(game.powerups._pick_id()), "og den er faktisk god")

	_skip_pause()
	eq(game.state, Game.State.PLAYING, "spillet fortsætter efter pausen")
	eq(game._balls.size(), 1, "en ny bold er klæbet fast")
	ok(game._balls[0].stuck, "den nye bold venter på klik")


func _test_game_over() -> void:
	game.score = 5000
	_kill_all_balls()
	eq(game.lives, 1, "andet tab")
	_skip_pause()
	_kill_all_balls()
	eq(game.lives, 0, "tredje tab")
	eq(game.state, Game.State.GAME_OVER, "tilstand er GAME_OVER")
	eq(game.screens.final_score, 5000, "game over viser den opnaaede score")
	ok(not game.paddle.input_enabled, "styringen er slaaet fra paa game over")

	game._on_screen_action("menu")
	eq(game.state, Game.State.TITLE, "MENU foerer tilbage til titlen")

	game._on_screen_action("restart")
	eq(game.state, Game.State.LEVEL_INTRO, "PLAY AGAIN starter forfra paa level 1")
	eq(game.score, 0, "scoren nulstilles")
	eq(game.lives, 3, "livene nulstilles")
	eq(int(game.level_data["id"]), 1, "og det er level 1 igen")
	eq(game.grid.remaining_breakable(), 47, "levelet er bygget op igen")
	game._begin_level()


func _test_level_progression() -> void:
	eq(int(game.level_data["id"]), 1, "tilbage på level 1")
	game._next_level()
	eq(game.state, Game.State.LEVEL_INTRO, "hvert nyt level starter med en intro")
	eq(int(game.level_data["id"]), 2, "level 2 hentes")
	eq(game.screens.level_title, "The Capsule", "introen viser level 2's navn")
	eq(game.grid.remaining_breakable(), 68, "level 2 har 68 klodser")
	eq(game.paddle.width, Paddle.WIDTH_NORMAL, "nyt level giver normal paddle")
	eq(game._bricks_this_level, 0, "fartstigningen nulstilles ved nyt level")
	game._begin_level()
	game._next_level()
	eq(int(game.level_data["id"]), 3, "level 3 hentes")
	eq(game.screens.level_title, "The Chain", "introen viser level 3's navn")
	eq(game.grid.remaining_breakable(), 53, "level 3 har 53 klodser")
	game._begin_level()
	game._next_level()
	eq(int(game.level_data["id"]), 1, "efter level 3 starter zonen forfra")
	game._begin_level()


func _test_level_clear_freeze() -> void:
	game._set_state(Game.State.PLAYING)
	game._balls[0].launch()
	var speed_before := game._balls[0].velocity.length()
	game._on_level_cleared()
	eq(game.state, Game.State.LEVEL_CLEAR, "tilstand er LEVEL_CLEAR")
	ok(game._balls[0].frozen, "bolden fryses ved level clear")
	about(game._balls[0].velocity.length(), speed_before, 0.01, "farten bevares under frysningen")


func _test_scoring() -> void:
	game.combo = 0
	eq(game._combo_multiplier(), 1, "kombo under 5 giver x1")
	game.combo = 5
	eq(game._combo_multiplier(), 2, "kombo 5 giver x2")
	game.combo = 10
	eq(game._combo_multiplier(), 3, "kombo 10 giver x3")
	game.combo = 20
	eq(game._combo_multiplier(), 4, "kombo 20 giver x4")

	eq(HUD.group_digits(0), "0", "nul vises som 0")
	eq(HUD.group_digits(999), "999", "tre cifre står alene")
	eq(HUD.group_digits(1000), "1 000", "fire cifre får mellemrum")
	eq(HUD.group_digits(1234567), "1 234 567", "syv cifre får to mellemrum")


## Indstillinger skal overleve et genstart.
func _test_settings() -> void:
	var s := get_node("/root/GameSettings")
	var was_crt: bool = s.crt
	var was_volume: float = s.volume
	s.crt = not was_crt
	s.volume = 0.42
	s.save_settings()
	s.crt = was_crt
	s.volume = was_volume
	s.load_settings()
	eq(s.crt, not was_crt, "CRT-valget bliver gemt")
	ok(absf(float(s.volume) - 0.42) < 0.001, "lydstyrken bliver gemt")
	s.crt = was_crt
	s.volume = was_volume
	s.save_settings()

	# Rekorden slaas kun, naar den faktisk slaas.
	var was_high: int = s.high_score
	s.high_score = 1000
	ok(not s.submit_score(500), "en lavere score slaar ikke rekorden")
	ok(s.submit_score(1500), "en hoejere score slaar rekorden")
	eq(s.high_score, 1500, "rekorden er opdateret")
	s.high_score = was_high
	s.save_settings()


## Hele lydbanken skal kunne indlaeses, ellers er der en tavs lyd.
func _test_audio_bank() -> void:
	for id in Audio.BANK:
		var stream: Resource = load(Audio.BANK[id])
		ok(stream != null, "lyden '%s' kan indlaeses" % str(id))
		if stream is AudioStreamWAV:
			ok(stream.get_length() > 0.01, "lyden '%s' har indhold" % str(id))
	var drone: AudioStreamWAV = load(Audio.DRONE_PATH)
	ok(drone != null and drone.get_length() > 4.0, "dronen er lang nok til at loope")


## Alt, spilleren laeser, er paa engelsk.
func _test_english() -> void:
	var danish := "æøåÆØÅ"
	for path in LevelLoader.level_paths():
		var data: Dictionary = LevelLoader.load_level(path)["data"]
		var name := str(data.get("name", ""))
		var clean := true
		for ch in danish:
			if name.contains(ch):
				clean = false
		ok(clean and not name.is_empty(), "%s har et engelsk navn (%s)" % [path, name])
	eq(game.hud.zone_name, "THE BELT", "zonen hedder THE BELT i HUD'en")


## Rydder scenen af inden exit, saa motoren ikke rapporterer objekter,
## der bare stod i traeet, da vi lukkede midt i en frame.
func _teardown() -> void:
	if is_instance_valid(game):
		# Lyd, der stadig koerer, holder paa afspilningsobjekter, naar
		# motoren lukker. Sluk foerst, ryd saa op.
		game.audio.stop_all()
		# Lydserveren slipper foerst afspilningerne efter et par ticks.
		await get_tree().create_timer(0.2).timeout
		game.free()
	# Lad motoren rydde op, inden vi lukker, ellers rapporterer den
	# noder, der bare stod i traeet, som laekager.
	await get_tree().process_frame
	await get_tree().process_frame
