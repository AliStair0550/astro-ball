class_name Strings
extends RefCounted

## Section 14: every string the player reads lives here.
##
## Nothing else in the project may hold player-facing text. The point is
## not translation, there is only English. The point is that a rename is
## one edit in one file: section 14 says a zone rename never touches
## code, only this table.
##
## Tone: short, dry, technical, telemetry from a vessel. No exclamation
## marks. "Ball lost", not "Oh no". "Field cleared", not "Level complete".
##
## Developer text does not belong here: the F1 debug overlay, push_error
## messages, the feel test readout and the test suites are all read by us,
## not by a player.

const MISSING := "??"

## Which universe a zone is. Section 14: the player never hears "zone".
const UNIVERSE_OF := {
	"baeltet": 1,
	"isringen": 2,
	"solvinden": 3,
	"taagen": 4,
	"hullet": 5,
}

const TABLE := {
	# --- Brand and title -----------------------------------------------
	"BRAND": "ASTRO BALL",
	"BRAND_LINE_1": "ASTRO",
	"BRAND_LINE_2": "BALL",
	"TAGLINE": "BREAK THROUGH THE DRIFT",
	"HINT_TITLE": "CLICK TO AIM · MOVE TO STEER",
	# Phase 9. Shown once per install, in a test build only, and it
	# links nowhere: feedback goes through TestFlight's own button.
	"TEST_BUILD_NOTICE": "TEST BUILD. BREAK THINGS. REPORT.",
	"BEST": "BEST",
	"BEST_VALUE": "BEST  %s",

	# --- Universes -------------------------------------------------------
	# Section 14: player-facing, a zone is always a universe. The slug in
	# the level data stays what it has always been.
	"UNIVERSE_NUMBER": "UNIVERSE %d",
	"UNIVERSE_FULL": "UNIVERSE %d · %s",
	"UNIVERSE_NAMED": "%s",
	"ZONE_baeltet": "THE DRIFT",
	"ZONE_isringen": "THE ICE RINGS",
	"ZONE_solvinden": "THE SOLAR WIND",
	"ZONE_taagen": "THE NEBULA",
	"ZONE_hullet": "THE CORE",

	# --- Buttons ---------------------------------------------------------
	"BTN_PLAY": "START GAME",
	"BTN_SETTINGS": "SETTINGS",
	"BTN_BACK": "BACK",
	"BTN_RESUME": "RESUME",
	"BTN_LEVELS": "SELECT LEVEL",
	"BTN_MENU": "MAIN MENU",
	"BTN_START": "START",
	# Was RE-ENTRY. A word the player has to learn first is a word in
	# the way, and this is the screen where they are already losing.
	"BTN_RE_ENTRY": "CONTINUE",
	"BTN_RE_ENTRY_AD": "CONTINUE · WATCH AD",
	"BTN_RESTART_FIELD": "RESTART LEVEL",

	# --- Settings, section 17 --------------------------------------------
	"SETTINGS_TITLE": "SETTINGS",
	"SET_SOUND": "SOUND",
	"SET_MUSIC": "MUSIC",
	"SET_HAPTICS": "HAPTICS",
	"SET_CRT": "CRT MODE",
	"SET_LEFT_HANDED": "LEFT-HANDED UI",
	"SET_RESET": "RESET PROGRESS",
	"SET_RESET_ARMED": "CONFIRM RESET",
	"ON": "ON",
	"OFF": "OFF",
	"NOTE_CRT": "CRT MODE ADDS SCANLINES AND VIGNETTE",
	"NOTE_RESET": "PRESS AGAIN TO ERASE ALL PROGRESS",

	# --- Level intro -----------------------------------------------------
	"LEVEL_NUMBER": "LEVEL %d",
	"HINT_BEGIN": "CLICK TO BEGIN",
	"HINT_CONTINUE": "CLICK TO CONTINUE",

	# --- Paused ----------------------------------------------------------
	"PAUSED": "PAUSED",

	# --- Universe select -------------------------------------------------
	"UNIVERSE_SELECT": "CHOOSE A UNIVERSE",
	"UNIVERSE_LEVELS": "%d LEVELS",
	"UNIVERSE_CLEARED": "%d OF %d CLEARED",
	"UNIVERSE_LOCKED": "LOCKED",
	"UNIVERSE_LOCKED_HINT": "FINISH THE UNIVERSE BEFORE IT",
	"UNIVERSE_SOON": "COMING SOON",

	# --- Level select, section 15 ----------------------------------------
	"MAP_FIELD": "LEVEL %02d · %s",
	"MAP_LOCKED": "LOCKED",
	"MAP_LOCKED_HINT": "CLEAR THE LEVEL BEFORE IT",
	"MAP_BEST": "BEST %s",
	"MAP_COMPLETE": "ALL LEVELS CLEARED",
	"MAP_START_HERE": "START HERE",
	"MAP_DESTINATION": "THE WAY IN",

	# --- Level cleared ---------------------------------------------------
	"FIELD_CLEARED": "LEVEL CLEARED",
	"STAR_CLEARED": "CLEARED",
	"STAR_UNDER_PAR": "UNDER PAR",
	"STAR_NO_LOSS": "NO BALL LOST",
	"LEVEL_OF": "LEVEL %d OF %d",
	"PAR_TIME": "PAR %s",
	"LEVEL_AND_NAME": "LEVEL %d · %s",

	# --- Game over, section 16 -------------------------------------------
	# Was SIGNAL LOST. It is the one screen where nobody should have to
	# work out what has happened to them.
	"SIGNAL_LOST": "GAME OVER",
	"STAT_BRICKS": "BRICKS CLEARED",
	"STAT_COMBO": "BEST COMBO",
	"STAT_TIME": "TIME",
	"STAT_SCORE": "SCORE",
	"NEW_RECORD": "NEW RECORD",

	# --- HUD -------------------------------------------------------------
	"HUD_COMBO": "COMBO",
	"HUD_STARS": "STARS",
	"HUD_LEVEL_LINE": "%s · LEVEL %d",

	# --- Power-up names, section 7 ---------------------------------------
	# The design document's Danish names are in the section 7 table.
	"PU_WIDE": "WIDE",
	"PU_MULTI": "MULTI",
	"PU_FIREBALL": "FIREBALL",
	"PU_LASER": "LASER",
	"PU_SLOW": "SLOW",
	"PU_LIFE": "LIFE",
	"PU_ZAP": "ZAP",
	"PU_GIANT": "GIANT",
	"PU_NARROW": "NARROW",
	"PU_FAST": "FAST",
	"PU_MAGNET": "MAGNET",
	"PU_SHIELD": "SHIELD",
	"PU_SPLINTER": "SPLINTER",
	"PU_BLIND": "BLIND",
	"PU_INVERT": "INVERT",
	"PU_HEAVY": "HEAVY",
	"PU_DEATH": "DEATH",
	"PU_SWAP": "SWAP",
	"PU_LOTTERY": "LOTTERY",
	"PU_BOMB": "BOMB",
	"PU_BONUS": "BONUS",
	"PU_SHRINK": "SHRINK",
	"PU_WOBBLE": "WOBBLE",
}


static func has(key: String) -> bool:
	return TABLE.has(key)


## Look up a string. An unknown key returns the key itself wrapped in
## question marks, so a missing entry is loud on screen instead of an
## empty label nobody notices.
static func text(key: String) -> String:
	if not TABLE.has(key):
		push_error("Strings: no entry for '%s'" % key)
		return "%s%s%s" % [MISSING, key, MISSING]
	return str(TABLE[key])


## Look up a format template and fill it.
static func fmt(key: String, args: Array) -> String:
	var template := text(key)
	if not TABLE.has(key):
		return template
	return template % args


## The player-facing name of a zone, from the slug in the level data.
static func zone_name(slug: String) -> String:
	var key := "ZONE_%s" % slug
	if not TABLE.has(key):
		return text("ZONE_baeltet")
	return text(key)


static func universe_index(slug: String) -> int:
	return int(UNIVERSE_OF.get(slug, 1))


## "UNIVERSE 1 · THE DRIFT". Section 14: zones are universes to the player.
static func universe_line(slug: String) -> String:
	return fmt("UNIVERSE_FULL", [universe_index(slug), zone_name(slug)])


## "THE DRIFT". The player knows where they are by the name of the place,
## not by its number: the number is filing, and filing is not a feeling.
static func universe_short(slug: String) -> String:
	return zone_name(slug)


## The slug of a universe by its number, 1 to 5.
static func slug_of_universe(number: int) -> String:
	for slug in UNIVERSE_OF:
		if int(UNIVERSE_OF[slug]) == number:
			return str(slug)
	return "baeltet"


## The display name of a power-up, from its catalog id.
static func powerup_name(id: String) -> String:
	var key := "PU_%s" % id.to_upper()
	if not TABLE.has(key):
		return id.to_upper()
	return text(key)


## Every key, for the test that asserts nothing player-facing is missing.
static func keys() -> Array:
	return TABLE.keys()
