extends SceneTree
## Draws the app icon (a helicopter silhouette on a round badge) into res://icon.png
func _init():
	var S := 512; var img := Image.create(S, S, false, Image.FORMAT_RGBA8); img.fill(Color(0, 0, 0, 0))
	var c := Vector2(S / 2.0, S / 2.0)
	for y in S:
		for x in S:
			var d := Vector2(x, y).distance_to(c)
			if d < 240: img.set_pixel(x, y, Color("152030").lerp(Color("2a4a6a"), 1 - y / float(S)))
			elif d < 252: img.set_pixel(x, y, Color("ffd166"))
	var gold := Color("ffd166")
	var ell := func(cx: float, cy: float, rx: float, ry: float):
		for y in range(int(cy - ry), int(cy + ry) + 1):
			for x in range(int(cx - rx), int(cx + rx) + 1):
				if pow((x - cx) / rx, 2) + pow((y - cy) / ry, 2) <= 1: img.set_pixel(x, y, gold)
	ell.call(230, 290, 95, 62)                      # cabin
	img.fill_rect(Rect2i(300, 272, 150, 22), gold)  # tail boom
	ell.call(445, 262, 14, 40)                       # tail rotor disc
	img.fill_rect(Rect2i(222, 200, 16, 40), gold)   # mast
	img.fill_rect(Rect2i(70, 192, 330, 12), gold)   # main rotor
	img.fill_rect(Rect2i(160, 360, 160, 10), gold)  # skid
	img.fill_rect(Rect2i(190, 340, 10, 22), gold); img.fill_rect(Rect2i(280, 340, 10, 22), gold)
	ell.call(190, 280, 45, 35)
	for y in range(250, 310):
		for x in range(150, 225):
			if pow((x - 190) / 45.0, 2) + pow((y - 280) / 35.0, 2) <= 1 and x < 215 and y < 300: img.set_pixel(x, y, Color("8fd3ff"))
	img.save_png("res://icon.png")
	quit()
