extends Node

func _ready() -> void:
	var grids := {
		"level3": LevelLoader.load_level("res://levels/level_03.json")["data"]["grid"],
		"padded": [".VVVVVVVVVVV.", ".VVVVVVVVVVV.", ".............", "............."],
		"single": ["......V......"],
	}
	var bad := 0
	for key in grids:
		var rows: Array = grids[key]
		for anchor in [-60.0, 0.0, 37.0, 180.0]:
			var g := BrickGrid.new()
			add_child(g)
			g.build(rows, anchor)
			# every live brick must be found by the broad phase over its own rect
			for b in g.live_bricks():
				if not b.revealed: continue
				if not g.bricks_in(b.rect).has(b):
					bad += 1
					print("[probe] MISS self %s anchor %.0f col %d row %d" % [key, anchor, b.col, b.row])
			# brute force vs broad phase over a swept sample
			var rng := RandomNumberGenerator.new()
			rng.seed = 12345
			for i in 4000:
				var p := Vector2(rng.randf_range(0.0, 390.0), rng.randf_range(140.0, 844.0))
				var area := Rect2(p, Vector2.ZERO).grow(rng.randf_range(1.0, 12.0))
				var got := {}
				for b in g.bricks_in(area):
					got[b] = true
				for b in g.live_bricks():
				if not b.revealed: continue
					if b.rect.intersects(area) and not got.has(b):
						bad += 1
						print("[probe] MISS sweep %s anchor %.0f col %d row %d area %s" % [key, anchor, b.col, b.row, str(area)])
			g.queue_free()
	print("[probe] broad-phase mismatches: %d" % bad)
	get_tree().quit(0)
