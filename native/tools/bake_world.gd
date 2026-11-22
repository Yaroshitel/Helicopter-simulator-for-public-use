extends SceneTree
## Bakes the static world into res://baked/world.scn:  godot --headless -s tools/bake_world.gd
func _init():
	var t := Time.get_ticks_msec()
	var w = load("res://scripts/world_builder.gd").new().build()
	print("built in ", Time.get_ticks_msec() - t, " ms")
	var ps := PackedScene.new(); var err := ps.pack(w)
	if err != OK: print("pack failed ", err)
	err = ResourceSaver.save(ps, "res://baked/world.scn", ResourceSaver.FLAG_COMPRESS)
	print("saved ", err, " in ", Time.get_ticks_msec() - t, " ms")
	quit()
