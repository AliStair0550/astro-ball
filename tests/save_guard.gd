extends RefCounted

## Test-only. The suites share one user:// with the game, and several of
## them clear progress, record stars or beat the high score on purpose.
## Run once, and whatever the player had on this machine is gone: not a
## crash, not a failed check, just a save file quietly replaced by test
## data. The autopilot alone finishes twelve fields every run.
##
## stash() before a suite touches progress, restore() as it leaves.
##
## stash() also clears the save, because a suite has to start from a
## known state. Otherwise a machine where somebody has played reports
## different results from a fresh one, which is worse than no test.

const PATH := "user://progress.json"
const STASH := "user://progress.stashed_by_tests.json"


static func stash() -> void:
	var text := ""
	if FileAccess.file_exists(PATH):
		text = FileAccess.get_file_as_string(PATH)
	var file := FileAccess.open(STASH, FileAccess.WRITE)
	if file == null:
		push_error("save_guard: could not stash %s" % PATH)
		return
	# An empty stash means there was no save, and restore takes the file
	# away again rather than leaving test progress behind.
	file.store_string(text)
	file.close()
	# From here the suite runs on an empty save, whoever has been playing.
	if FileAccess.file_exists(PATH):
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	_reload()


static func restore() -> void:
	if not FileAccess.file_exists(STASH):
		return
	var text := FileAccess.get_file_as_string(STASH)
	if text.is_empty():
		DirAccess.remove_absolute(ProjectSettings.globalize_path(PATH))
	else:
		var file := FileAccess.open(PATH, FileAccess.WRITE)
		if file != null:
			file.store_string(text)
			file.close()
	DirAccess.remove_absolute(ProjectSettings.globalize_path(STASH))
	_reload()


static func _reload() -> void:
	var loop := Engine.get_main_loop()
	if not (loop is SceneTree):
		return
	var progress: Node = (loop as SceneTree).root.get_node_or_null("/root/GameProgress")
	if progress == null:
		return
	progress.high_score = 0
	progress.levels = {}
	progress.load_progress()
