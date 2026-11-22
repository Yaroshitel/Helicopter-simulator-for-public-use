extends SceneTree
## Bakes the valley terrain (heights + ground colours) into res://baked/. Run once:
##   godot --headless -s tools/bake_terrain.gd
const U := preload("res://scripts/util.gd")

func lerpc(a: Color, b: Color, t: float) -> Color:
	return a.lerp(b, clampf(t, 0, 1))

func _init():
	var t0 := Time.get_ticks_msec()
	var n := U.TN + 1; var step := U.TS / U.TN
	var H := PackedFloat32Array(); H.resize(n * n)
	for j in n:
		for i in n:
			H[j * n + i] = U.ground_exact(-U.TS / 2 + i * step, -U.TS / 2 + j * step)
	print("heights ", Time.get_ticks_msec() - t0, " ms")
	var col := PackedByteArray(); col.resize(n * n * 3)
	var msk := PackedByteArray(); msk.resize(n * n * 4)   # R field, G forest floor, B sand / gravel bank, A snow
	for j in n:
		for i in n:
			var x := -U.TS / 2 + i * step; var z := -U.TS / 2 + j * step; var y := H[j * n + i]
			var hx := H[j * n + mini(i + 1, n - 1)] - H[j * n + maxi(i - 1, 0)]
			var hz := H[mini(j + 1, n - 1) * n + i] - H[maxi(j - 1, 0) * n + i]
			var nrm := Vector3(-hx, 2 * step, -hz).normalized(); var sl := 1.0 - nrm.y
			var m := U.fbm(x * .01, z * .01, 3)
			var c := Color(.16 + .12 * m, .24 + .1 * m, .08 + .04 * m)
			c = lerpc(c, Color(.36, .33, .2), U.sstep(.4, .7, U.fbm(x * .003, z * .003, 3)))
			c = lerpc(c, Color(.33, .31, .29), U.sstep(.12, .3, sl))
			var mf := 0.0; var mw := 0.0; var ms := 0.0; var mn := 0.0
			var hk := U.hill_k(x, z); var dr := absf(x - U.river_x(z)); var te := U.town_e(x, z); var d := Vector2(x, z).length()
			if hk < .4 and d > 470 and te > 1.08 and dr > 55:
				var cx := floorf((x + z * .3) / 90); var cz := floorf((z - x * .2) / 130); var hh := U.hash2(cx, cz)
				var F := [Color(.42, .4, .18), Color(.24, .36, .1), Color(.36, .27, .17), Color(.3, .4, .16), Color(.5, .46, .26)][int(hh * 5) % 5] as Color
				c = lerpc(c, F * (.9 + .2 * m), .9 * (1 - hk / .4)); mf = .9 * (1 - hk / .4)
			if hk > .3 and (U.fbm(x * .0035 + 5, z * .0035, 3) > .45 or U.fbm(x * .004, z * .004, 3) > .47):
				c = lerpc(c, Color(.07, .13, .05) * (.85 + .3 * m), .75 * U.sstep(.3, .5, hk) * U.sstep(.4, .2, sl)); mw = U.sstep(.3, .5, hk) * U.sstep(.4, .2, sl)
			if te < 1.05: c = lerpc(c, Color(.3, .31, .22) * (.9 + .2 * m), .6)
			if x > -1000 and x < -600 and z > 200 and z < 700: c = lerpc(c, Color(.36, .3, .2), .55)
			c = lerpc(c, Color(.5, .46, .36), (1 - U.sstep(36, 58, dr)) * .8)
			c = lerpc(c, Color(.62, .55, .4), 1 - U.sstep(140, 175, Vector2(x - U.LAKE.x, z - U.LAKE.z).length()))
			ms = maxf(1 - U.sstep(36, 58, dr), 1 - U.sstep(140, 175, Vector2(x - U.LAKE.x, z - U.LAKE.z).length()))
			mn = U.sstep(230, 300, y + m * 40) * U.sstep(.4, .2, sl)
			c = lerpc(c, Color(.92, .93, .96), mn)
			var k := (j * n + i) * 3
			var k4 := (j * n + i) * 4
			msk[k4] = int(clampf(mf, 0, 1) * 255); msk[k4 + 1] = int(clampf(mw, 0, 1) * 255); msk[k4 + 2] = int(clampf(ms, 0, 1) * 255); msk[k4 + 3] = int(clampf(mn, 0, 1) * 255)
			col[k] = int(clampf(c.r, 0, 1) * 255); col[k + 1] = int(clampf(c.g, 0, 1) * 255); col[k + 2] = int(clampf(c.b, 0, 1) * 255)
	DirAccess.make_dir_recursive_absolute("res://baked")
	var f := FileAccess.open("res://baked/height.bin", FileAccess.WRITE); f.store_buffer(H.to_byte_array()); f.close()
	f = FileAccess.open("res://baked/color.bin", FileAccess.WRITE); f.store_buffer(col); f.close()
	f = FileAccess.open("res://baked/mask.bin", FileAccess.WRITE); f.store_buffer(msk); f.close()
	print("baked in ", Time.get_ticks_msec() - t0, " ms")
	quit()
