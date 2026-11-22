class_name WorldBuilder
## Builds the static valley world (terrain, airfield, river, town, plant, railway, forests, church, power line).
## Run by tools/bake_world.gd; the result is saved to res://baked/world.scn so the game loads it instantly.
## Night-light materials and window materials are collected in groups so the game can light them up at night.

var root: Node3D
var rng := RandomNumberGenerator.new()
var night_lights: Array = []     # [material, base colour]
var night_windows: Array = []    # [material, k]
var traffic: Array = []          # lanes for moving cars
var smoke_src: Array = []        # chimney tops

func R(a: float, b: float) -> float: return rng.randf_range(a, b)
func rnd() -> float: return rng.randf()
func pick(a: Array): return a[rng.randi() % a.size()]
func G(x: float, z: float) -> float: return U.ground_h(x, z)

func build() -> Node3D:
	rng.seed = 7
	root = Node3D.new(); root.name = "World"
	excl = Image.create(EXN, EXN, false, Image.FORMAT_L8); excl.fill(Color.WHITE)
	_terrain(); _airfield(); _water(); _town(); _grass()
	root.set_meta("night_lights", night_lights); root.set_meta("night_windows", night_windows)
	root.set_meta("traffic", traffic); root.set_meta("smoke", smoke_src)
	_own(root, root)
	return root

func _own(n: Node, owner_: Node) -> void:
	for c in n.get_children():
		c.owner = owner_; _own(c, owner_)

# ---------------- textures ----------------
var _T := {}
func conc_img() -> Image:
	if not _T.has("conc"):
		# 8 × 8 slabs, each its own tone, fine aggregate, dark joints, a few hairline cracks and patched corners
		var r := RandomNumberGenerator.new(); r.seed = 55
		var nz := Gfx.noise_img(512, .09, 5, 4)
		var nf := Gfx.noise_img(512, .45, 9, 2)
		var tone := []
		for k in 64: tone.append(r.randf_range(.86, 1.06))
		var img := Image.create(512, 512, false, Image.FORMAT_RGBA8)
		for y in 512:
			for x in 512:
				var t: float = tone[(y / 64) * 8 + x / 64]
				var v := (.58 + .16 * nz.get_pixel(x, y).r + .08 * nf.get_pixel(x, y).r) * t
				img.set_pixel(x, y, Color(v, v * .985, v * .955))
		var j := Color(.3, .29, .27)
		for i in 9:
			img.fill_rect(Rect2i(i * 64 - 1, 0, 2, 512), j); img.fill_rect(Rect2i(0, i * 64 - 1, 512, 2), j)
		for c in 14:
			var p := Vector2(r.randf() * 512, r.randf() * 512); var d := Vector2.from_angle(r.randf() * TAU)
			for k in r.randi_range(20, 70):
				d = d.rotated(r.randf_range(-.5, .5)); p += d
				var q := Vector2i(posmod(int(p.x), 512), posmod(int(p.y), 512))
				img.set_pixelv(q, img.get_pixelv(q).darkened(.35))
		for c in 5:
			var q := Vector2i(r.randi_range(0, 7) * 64 + 4, r.randi_range(0, 7) * 64 + 4); var v := r.randf_range(.45, .52)
			img.fill_rect(Rect2i(q, Vector2i(r.randi_range(14, 30), r.randi_range(10, 24))), Color(v, v, v * .97))
		_T.conc = img
	return _T.conc

func night_light(col: Color, pts: Array, r := .11) -> void:
	var m := Gfx.unshaded(col, 1.0)
	night_lights.append([m, col])
	Gfx.multi(root, Gfx.sphere(r, 10, 6), m, pts.map(func(p): return {x = p.x, y = p.y, z = p.z}), false)
	Gfx.multi(root, Gfx.cyl(.06, .08, .25, 8), Gfx.mat(Gfx.hexc(0x3a3d40), .5, .6), pts.map(func(p): return {x = p.x, y = p.y - .17, z = p.z}), false)

# ---------------- terrain ----------------
## tiling noise textures shared by the ground shaders (C++ noise, generated once)
func noise_tex(k: String) -> Texture2D:
	if not _T.has("nt_" + k):
		match k:
			"a": _T["nt_a"] = Gfx.tex(Gfx.noise_img(512, .016, 41, 5))
			"b": _T["nt_b"] = Gfx.tex(Gfx.noise_img(512, .011, 43, 4))
			"n": _T["nt_n"] = Gfx.nmap(Gfx.noise_img(512, .035, 47, 5), 5.0)
	return _T["nt_" + k]

func decal(img: Image, rough := .85, nstr := 1.0, tint := Color.WHITE, layer := 1.0, uvs := Vector2.ONE, grime := .3) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/world/ground_decal.gdshader")
	m.set_shader_parameter("albedo_tex", Gfx.tex(img)); m.set_shader_parameter("normal_tex", Gfx.nmap(img, maxf(nstr, .01) * 2.0))
	m.set_shader_parameter("noise_tex", noise_tex("b")); m.set_shader_parameter("tint", tint); m.set_shader_parameter("rough", rough)
	m.set_shader_parameter("normal_depth", 1.0 if nstr > 0 else 0.0); m.set_shader_parameter("layer", layer); m.set_shader_parameter("uv_scale", uvs)
	m.set_shader_parameter("grime", grime)
	return m

func _terrain() -> void:
	var n := U.TN + 1; var step := U.TS / U.TN
	U.load_height()
	var H := U._h
	var P := PackedVector3Array(); P.resize(n * n)
	var N := PackedVector3Array(); N.resize(n * n)
	for j in n:
		for i in n:
			var k := j * n + i
			var x := -U.TS / 2 + i * step; var z := -U.TS / 2 + j * step
			P[k] = Vector3(x, H[k], z)
			var hx := H[j * n + mini(i + 1, n - 1)] - H[j * n + maxi(i - 1, 0)]
			var hz := H[mini(j + 1, n - 1) * n + i] - H[maxi(j - 1, 0) * n + i]
			N[k] = Vector3(-hx, 2 * step, -hz).normalized()
	var I := PackedInt32Array(); I.resize(U.TN * U.TN * 6)
	var c := 0
	for j in U.TN:
		for i in U.TN:
			var a := j * n + i; var b := a + 1; var d := a + n; var e := d + 1
			I[c] = a; I[c + 1] = e; I[c + 2] = d; I[c + 3] = a; I[c + 4] = b; I[c + 5] = e; c += 6
	var arr := []; arr.resize(Mesh.ARRAY_MAX)
	arr[Mesh.ARRAY_VERTEX] = P; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_INDEX] = I
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/world/terrain.gdshader")
	var cimg := Image.create_from_data(n, n, false, Image.FORMAT_RGB8, FileAccess.get_file_as_bytes("res://baked/color.bin"))
	var mb := FileAccess.get_file_as_bytes("res://baked/mask.bin")
	if mb.size() != n * n * 4:
		mb = PackedByteArray(); mb.resize(n * n * 4)
	var mimg := Image.create_from_data(n, n, false, Image.FORMAT_RGBA8, mb)
	height_tex = ImageTexture.create_from_image(Image.create_from_data(n, n, false, Image.FORMAT_RF, H.to_byte_array()))
	m.set_shader_parameter("color_map", ImageTexture.create_from_image(cimg)); m.set_shader_parameter("mask_map", ImageTexture.create_from_image(mimg))
	m.set_shader_parameter("height_map", height_tex)
	m.set_shader_parameter("noise_a", noise_tex("a")); m.set_shader_parameter("noise_b", noise_tex("b")); m.set_shader_parameter("detail_n", noise_tex("n"))
	var t := Gfx.mi(root, am, m, Vector3.ZERO, Vector3.ZERO, false); t.name = "Terrain"
	root.set_meta("terrain_mat", m); root.set_meta("height_tex", height_tex)
var height_tex: ImageTexture

func flat(w: float, d: float, img: Image, x: float, y: float, z: float, rep := Vector2.ONE, ry := 0.0, nstr := 2.0, tint := Color.WHITE, layer := 1.0, rough := .88) -> MeshInstance3D:
	var m := decal(img, rough, nstr, tint, layer)
	return Gfx.mi(root, Gfx.plane(w, d, rep), m, Vector3(x, y, z), Vector3(0, ry, 0), false)

# ---------------- airfield ----------------
func _airfield() -> void:
	ex_rect(-46, -46, 46, 46); ex_rect(-311, -186, 311, -154); ex_rect(-64, 28, -32, 52); ex_rect(34, 40, 46, 50); ex_rect(58, 18, 66, 26); ex_rect(-25, 48, -15, 52)
	flat(90, 90, conc_img(), 0, .01, 0, Vector2(90 / 18.0, 90 / 18.0), 0, 2.0, Color(.84, .83, .8), 1.0)
	# helipad: concrete, white ring + H, yellow outer ring
	var pad := conc_img().duplicate() as Image
	pad.resize(1024, 1024)
	var ring := func(r0: float, r1: float, col: Color):
		for yy in 1024:
			var dy := yy - 512.0
			if absf(dy) > r1: continue
			var xo := sqrt(maxf(0, r1 * r1 - dy * dy)); var xi := sqrt(maxf(0, r0 * r0 - dy * dy)) if absf(dy) < r0 else 0.0
			if absf(dy) < r0:
				pad.fill_rect(Rect2i(int(512 - xo), yy, int(xo - xi), 1), col); pad.fill_rect(Rect2i(int(512 + xi), yy, int(xo - xi), 1), col)
			else:
				pad.fill_rect(Rect2i(int(512 - xo), yy, int(2 * xo), 1), col)
	var wh := Color(.94, .94, .92)
	ring.call(427.0, 453.0, wh); ring.call(463.0, 477.0, Color(.9, .76, .1))
	pad.fill_rect(Rect2i(330, 280, 70, 464), wh); pad.fill_rect(Rect2i(624, 280, 70, 464), wh); pad.fill_rect(Rect2i(400, 476, 224, 70), wh)
	flat(26, 26, pad, 0, .02, 0, Vector2.ONE, 0, 2.0, Color(.88, .87, .85), 2.0)
	# taxiway from the apron to the runway, painted lead-in lines
	flat(14, 112, conc_img(), 0, .01, -100, Vector2(14 / 18.0, 112 / 18.0), 0, 2.0, Color(.84, .83, .8), 1.0)
	ex_rect(-8, -156, 8, -44)
	var ylw := Image.create(8, 8, false, Image.FORMAT_RGBA8); ylw.fill(Color(.92, .74, .12))
	var ym := decal(ylw, .6, 0.0, Color.WHITE, 3.0, Vector2.ONE, .45)
	for L in [[Vector2(0, -14.5), Vector2(0, -150)], [Vector2(-12, 0), Vector2(-30, 0), Vector2(-48, 12), Vector2(-48, 28)]]:
		strip(L, .3, .0, ym, 2.0)
	# asphalt runway with markings
	var rw := Gfx.noise_img(256, .12, 9, 4, .18, .3)
	var rwy := Image.create(128, 1024, false, Image.FORMAT_RGBA8)
	rwy.blit_rect(rw, Rect2i(0, 0, 128, 256), Vector2i(0, 0)); rwy.blit_rect(rw, Rect2i(0, 0, 128, 256), Vector2i(0, 256))
	rwy.blit_rect(rw, Rect2i(0, 0, 128, 256), Vector2i(0, 512)); rwy.blit_rect(rw, Rect2i(0, 0, 128, 256), Vector2i(0, 768))
	var mk := Color(.9, .9, .9)
	var yy := 95
	while yy < 1024 - 95:
		rwy.fill_rect(Rect2i(62, yy, 4, 45), mk); yy += 80
	rwy.fill_rect(Rect2i(4, 0, 3, 1024), mk); rwy.fill_rect(Rect2i(121, 0, 3, 1024), mk)
	for kk in 8:
		rwy.fill_rect(Rect2i(12 + kk * 13, 8, 8, 65), mk); rwy.fill_rect(Rect2i(12 + kk * 13, 1024 - 73, 8, 65), mk)
	flat(30, 620, rwy, 0, .015, -170, Vector2.ONE, PI / 2, 1.5, Color.WHITE, 1.0, .8)
	# hangar, building, windsock
	var corr := Image.create(256, 32, false, Image.FORMAT_RGBA8)
	for x in 256:
		var v := .5 + .4 * sin(x / 256.0 * PI * 32); corr.fill_rect(Rect2i(x, 0, 1, 32), Color(v, v, v))
	var cn := Gfx.nmap(corr, 6)
	var hw := Gfx.mat(Gfx.hexc(0xb8bcc0), .55, .35); hw.normal_enabled = true; hw.normal_texture = cn; hw.uv1_scale = Vector3(8, 2, 1)
	Gfx.mi(root, Gfx.box(30, 7, 22), hw, Vector3(-48, 3.5, 40))
	var hr := Gfx.mat(Gfx.hexc(0x8d9399), .45, .6); hr.normal_enabled = true; hr.normal_texture = cn; hr.uv1_scale = Vector3(1, 20, 1)
	var roof := Gfx.cyl(11.5, 11.5, 30, 64); Gfx.mi(root, roof, hr, Vector3(-48, 7, 40), Vector3(0, 0, PI / 2)).scale = Vector3(1, 1, 1)
	Gfx.mi(root, Gfx.box(26, 6.4, .2), Gfx.mat(Gfx.hexc(0x3a4048), .5, .4), Vector3(-48, 3.2, 28.9))
	Gfx.mi(root, Gfx.box(10, 4, 8), Gfx.mat(Gfx.hexc(0xe6e2d8)), Vector3(40, 2, 45))
	Gfx.mi(root, Gfx.box(10.4, .3, 8.4), Gfx.mat(Gfx.hexc(0x7a3a2a)), Vector3(40, 4.1, 45))
	var sock := Node3D.new(); sock.name = "Sock"; sock.position = Vector3(24, 0, -16); root.add_child(sock)
	Gfx.mi(sock, Gfx.cyl(.05, .07, 6, 10), Gfx.mat(Color(.87, .87, .87), .4, .6), Vector3(0, 3, 0))
	var arm := Node3D.new(); arm.name = "Arm"; arm.position.y = 6; sock.add_child(arm)
	var sm := StandardMaterial3D.new(); sm.cull_mode = BaseMaterial3D.CULL_DISABLED; sm.roughness = .8
	var st := Image.create(256, 8, false, Image.FORMAT_RGBA8)
	for i in 5: st.fill_rect(Rect2i(i * 52, 0, 52, 8), Color(1, .35, .08) if i % 2 == 0 else Color(.96, .96, .96))
	sm.albedo_texture = Gfx.tex(st)
	var sg := Gfx.cyl(.14, .35, 3, 20, true)
	var sgm := Gfx.merge([[sg, Gfx.xf(Vector3(0, 0, 1.5), Vector3(PI / 2, 0, 0))]])
	Gfx.mi(arm, sgm, sm)
	# airfield lights: green heliport perimeter, white runway edges, green/red thresholds, apron flood light
	var ring_pts := []
	for i in 20: ring_pts.append(Vector3(cos(i / 20.0 * TAU) * 12.4, .3, sin(i / 20.0 * TAU) * 12.4))
	night_light(Color(.19, 1, .38), ring_pts)
	var ed := []
	for x in range(-300, 301, 30):
		for z in [-185.5, -154.5]: ed.append(Vector3(x, .3, z))
	night_light(Color(1, .95, .82), ed)
	var th := []; var te := []
	var z := -184.0
	while z <= -156: th.append(Vector3(-309, .3, z)); te.append(Vector3(309, .3, z)); z += 3.5
	night_light(Color(.19, 1, .38), th); night_light(Color(1, .13, .13), te)
	night_light(Color(1, .9, .69), [Vector3(-33, 6.6, 28.6), Vector3(-63, 6.6, 28.6), Vector3(35, 3.6, 40.7)], .18)
	var flood := SpotLight3D.new(); flood.name = "Flood"; flood.light_color = Color(1, .89, .69); flood.light_energy = 0; flood.spot_range = 90; flood.spot_angle = 36
	flood.position = Vector3(-30, 11, 26); root.add_child(flood); flood.look_at_from_position(flood.position, Vector3.ZERO)
	Gfx.mi(root, Gfx.cyl(.12, .16, 11, 10), Gfx.mat(Gfx.hexc(0x9aa0a6), .4, .7), Vector3(-30.6, 5.5, 26.6))
	var head := Gfx.mi(root, Gfx.box(1.2, .25, .6), Gfx.mat(Gfx.hexc(0x2a2d30), .4, .6), Vector3(-30.3, 11.1, 26.3)); head.look_at_from_position(head.position, Vector3.ZERO)
	night_light(Color(.72, .66, .56), [Vector3(-30.15, 10.95, 26.15)], .2)
	# control tower, fuel tank, staff cars
	var FH := facade(Color(.95, .94, .92), 2, 3, {door = 1, frame = Color(.96, .96, .95)})
	var tw := Gfx.mi(root, Gfx.ubox(6, 9, 6, 9, 6), null, Vector3(62, 0, 22)); tw.set_surface_override_material(0, FH); tw.set_surface_override_material(1, roof_m())
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(.62, .75, .82, .45); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; glass.roughness = .03; glass.metallic = .2
	Gfx.mi(root, Gfx.cyl(4.2, 3.6, 3.2, 8, true), glass, Vector3(62, 10.6, 22), Vector3.ZERO, false)
	Gfx.mi(root, Gfx.cyl(3.7, 3.7, .6, 8), Gfx.mat(Gfx.hexc(0xdedbd2), .6), Vector3(62, 9.2, 22))
	Gfx.mi(root, Gfx.cyl(4.8, 4.4, .5, 8), Gfx.mat(Gfx.hexc(0x3a3d40), .6, .4), Vector3(62, 12.4, 22))
	Gfx.mi(root, Gfx.box(.15, 3, .15), Gfx.mat(Color(.13, .13, .13)), Vector3(62, 14, 22))
	night_light(Color(1, .13, .06), [Vector3(62, 15.6, 22)], .2)
	Gfx.mi(root, Gfx.capsule(1.6, 7), Gfx.mat(Gfx.hexc(0xeeeeea), .3, .3), Vector3(-20, 2.1, 50), Vector3(0, 0, PI / 2))
	for x in [-23, -17]: Gfx.mi(root, Gfx.box(.4, 1, 3), Gfx.mat(Color(.33, .33, .33)), Vector3(x, .5, 50))
	var cars := []
	for q in [[52, 30, .1], [56, 30, .05], [60, 31, -.05], [48, 52, 1.6]]: cars.append({x = q[0], y = 0.0, z = q[1], ry = q[2], c = pick(CARC)})
	park(cars)

func roof_m() -> StandardMaterial3D:
	if not _T.has("roofm"):
		var m := Gfx.mat(Gfx.hexc(0x57544f), .95); _T.roofm = m
	return _T.roofm

# ---------------- water ----------------
func _water() -> void:
	var rp := []
	var zz := -4450.0
	while zz <= 4450: rp.append(Vector2(U.river_x(zz), zz)); zz += 10
	ex_line(rp, 116)
	for a in 64: ex_rect(U.LAKE.x + cos(a / 64.0 * TAU) * 95 - 95, U.LAKE.z + sin(a / 64.0 * TAU) * 95 - 95, U.LAKE.x + cos(a / 64.0 * TAU) * 95 + 95, U.LAKE.z + sin(a / 64.0 * TAU) * 95 + 95)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := []
	var z := -4450.0
	while z <= 4450:
		var xc := U.river_x(z); var cur := [Vector3(xc - 56, 0, z), Vector3(xc + 56, 0, z)]
		if prev.size():
			for vv in [prev[0], cur[1], cur[0], prev[0], prev[1], cur[1]]:
				st.set_normal(Vector3.UP); st.set_uv(Vector2(vv.x, vv.z) / 50.0); st.add_vertex(vv)
		prev = cur; z += 15
	var seg := 96
	for i in seg:
		var a0 := TAU * i / seg; var a1 := TAU * (i + 1) / seg
		for vv in [Vector3(U.LAKE.x, 0, U.LAKE.z), Vector3(U.LAKE.x + cos(a1) * U.LAKE_R, 0, U.LAKE.z + sin(a1) * U.LAKE_R), Vector3(U.LAKE.x + cos(a0) * U.LAKE_R, 0, U.LAKE.z + sin(a0) * U.LAKE_R)]:
			st.set_normal(Vector3.UP); st.set_uv(Vector2(vv.x, vv.z) / 50.0); st.add_vertex(vv)
	var sh := ShaderMaterial.new(); sh.shader = load("res://shaders/world/water.gdshader")
	var nimg := Gfx.noise_img(512, .03, 11, 4)
	sh.set_shader_parameter("normal_tex", Gfx.nmap(nimg, 6))
	sh.set_shader_parameter("foam_tex", noise_tex("a"))
	var w := Gfx.mi(root, st.commit(), sh, Vector3(0, U.WATER_Y, 0), Vector3.ZERO, false); w.name = "Water"

# ---------------- town ----------------
const CARC := [Color("e8e8e8"), Color("b8bcc0"), Color("202428"), Color("9a1c1c"), Color("1d3d7a"), Color("d8cfa8"), Color("4c5a3c"), Color("6b6f74"), Color("f2f2f0")]

## concrete-panel / plaster facade with framed windows, curtains, balconies + a matching emission map of windows lit at night
func facade(base: Color, floors: int, bays: int, o := {}) -> StandardMaterial3D:
	var bw := 64; var fh := 64; var W := bays * bw; var H := floors * fh
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8); img.fill(base)
	var em := Image.create(W, H, false, Image.FORMAT_RGBA8); em.fill(Color.BLACK)
	for f in floors:
		for b in bays:
			var tint := base.lerp(Color(rnd(), rnd(), rnd()), rnd() * .06)
			img.fill_rect(Rect2i(b * bw, f * fh, bw, fh), tint)
	var seam := base.darkened(.25)
	for f in floors + 1: img.fill_rect(Rect2i(0, f * fh - 1, W, 1), seam)
	for b in bays + 1: img.fill_rect(Rect2i(b * bw - 1, 0, 1, H), seam)
	var rimg := Image.create(W, H, false, Image.FORMAT_RGBA8); rimg.fill(Color(.88, .88, .88))
	var frame: Color = o.get("frame", Color(.92, .92, .9))
	var lit := [Color("ffc884"), Color("ffe0aa"), Color("fff2d8"), Color("b8d0ff"), Color("ffb46c")]
	for f in floors:
		for b in bays:
			var door: bool = o.has("door") and f == floors - 1 and b == o.door
			var x := b * bw + (20 if door else 14); var y := f * fh + (15 if door else 16); var ww := 24 if door else 36; var wh := 49 if door else 31
			img.fill_rect(Rect2i(x - 2, y - 2, ww + 4, wh + 4), frame)
			img.fill_rect(Rect2i(x, y, ww, wh), Color(.29, .23, .17) if door else Color(.17, .22, .27))
			img.fill_rect(Rect2i(x, y + wh / 2, ww, wh / 2), Color(.25, .2, .15) if door else Color(.3, .36, .42))
			rimg.fill_rect(Rect2i(x, y, ww, wh), Color(.45, .45, .45) if door else Color(.05, .05, .05))
			if door: continue
			img.fill_rect(Rect2i(x + ww / 2 - 1, y, 2, wh), frame); img.fill_rect(Rect2i(x, y + 10, ww, 1), frame)
			if rnd() < .45: img.fill_rect(Rect2i(x + 1, y + 12, ww / 2 - 3, wh - 13), pick([Color(.88, .8, .65), Color(.67, .24, .22), Color(.96, .96, .92), Color(.37, .49, .67)]))
			if o.has("bal") and f < floors - 1 and b % int(o.bal) == 1:
				img.fill_rect(Rect2i(x - 8, y + wh - 5, ww + 16, 15), pick([base, Color(.85, .83, .78), Color(.73, .65, .54), Color(.6, .64, .65)]))
				img.fill_rect(Rect2i(x - 8, y + wh - 5, ww + 16, 1), Color(.12, .12, .12))
			if rnd() < .4: em.fill_rect(Rect2i(x, y, ww, wh), pick(lit))
	# rain streaks + dirt at the base
	for i in W * H / 2500:
		img.fill_rect(Rect2i(rng.randi() % W, rng.randi() % H, 1 + rng.randi() % 2, 10 + rng.randi() % 50), base.darkened(.08 + rnd() * .08))
	var m := StandardMaterial3D.new(); m.albedo_texture = Gfx.tex(img); m.roughness = .85
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	m.emission_enabled = true; m.emission_texture = Gfx.tex(em); m.emission = Color.BLACK; m.emission_energy_multiplier = 0
	m.normal_enabled = true; m.normal_texture = Gfx.nmap(img, 1.5)
	m.roughness_texture = Gfx.tex(rimg); m.roughness = 1.0; m.metallic_specular = .6
	night_windows.append([m, 1.5])
	return m

func road_y(x: float, z: float) -> float:
	return maxf(G(x, z), 1.4 if absf(x - U.river_x(z)) < 78 else -1e9)

func asph(dash: bool) -> ShaderMaterial:
	var a := Gfx.noise_img(128, .1, 21 if dash else 22, 4, .18, .3)
	var img := Image.create(64, 128, false, Image.FORMAT_RGBA8); img.blit_rect(a, Rect2i(0, 0, 64, 128), Vector2i.ZERO)
	var c := Color(.85, .85, .83)
	img.fill_rect(Rect2i(2, 0, 2, 128), c); img.fill_rect(Rect2i(60, 0, 2, 128), c)
	if dash: img.fill_rect(Rect2i(31, 0, 2, 60), c)
	return decal(img, .82, 1.5, Color.WHITE, 3.0, Vector2.ONE, .35)

## ribbon draped on the ground along pts (x,z pairs)
func strip(pts: Array, width: float, y_off: float, m: Material, step := 4.0, off := 0.0, vlen := 8.0, rail := false) -> Array:
	var P := []
	for i in pts.size() - 1:
		var a: Vector2 = pts[i]; var b: Vector2 = pts[i + 1]; var n := maxi(1, ceili(a.distance_to(b) / step))
		for k in n: P.append(a.lerp(b, float(k) / n))
	P.append(pts[-1])
	ex_line(P, width + 1.5)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var acc := 0.0; var rows := []
	for i in P.size():
		var p: Vector2 = P[i]; var q: Vector2 = P[mini(i + 1, P.size() - 1)]; var r: Vector2 = P[maxi(i - 1, 0)]
		var t := (q - r).normalized(); var nn := Vector2(-t.y, t.x)
		if i: acc += p.distance_to(P[i - 1])
		var row := []
		for s in [-1, 1]:
			var xz: Vector2 = p + nn * (off + s * width / 2)
			var y := (G(xz.x, xz.y) if rail else road_y(xz.x, xz.y)) + y_off
			row.append([Vector3(xz.x, y, xz.y), Vector2(0 if s < 0 else 1, acc / vlen)])
		rows.append(row)
	for i in rows.size() - 1:
		var A = rows[i][0]; var B = rows[i][1]; var Cc = rows[i + 1][0]; var D = rows[i + 1][1]
		for vv in [A, Cc, B, B, Cc, D]:
			st.set_uv(vv[1]); st.add_vertex(vv[0])
	st.generate_normals(); st.generate_tangents()
	Gfx.mi(root, st.commit(), m, Vector3.ZERO, Vector3.ZERO, false)
	return P

func park(L: Array) -> void:
	if not _T.has("car"):
		var paint := Gfx.mat(Color.WHITE, .22, .35); paint.clearcoat_enabled = true; paint.clearcoat = .6
		var glass := Gfx.mat(Gfx.hexc(0x101418), .06, .4)
		_T.car = [Gfx.car_meshes(), paint, glass, Gfx.mat(Gfx.hexc(0x1a1b1d), .8, .1)]
	var cm: Array = _T.car[0]
	var plain := L.map(func(q): return {x = q.x, y = q.y, z = q.z, ry = q.ry})
	Gfx.multi(root, cm[0], _T.car[1], L).visibility_range_end = 1800
	Gfx.multi(root, cm[1], _T.car[2], plain).visibility_range_end = 1800
	Gfx.multi(root, cm[2], _T.car[3], plain, false).visibility_range_end = 900

func _town() -> void:
	var A1 := 1000.0; var A2 := 1260.0; var CS := [-820.0, -580.0, -340.0, -100.0, 140.0, 380.0]; var ZN := -1000.0; var ZS := 1000.0
	var riv := []
	var z := -3600.0
	while z <= 3600: riv.append(Vector2(U.river_x(z) + 82, z)); z += 40
	var acc_r := [Vector2(52, 38), Vector2(160, 52), Vector2(300, 72), Vector2(440, 112), Vector2(560, 140), Vector2(780, 140)]
	var roadM := asph(true); var streetM := asph(false)
	var ROADS := [{p = [Vector2(A1, -1150), Vector2(A1, ZS)], w = 12.0, m = roadM}, {p = [Vector2(A2, ZN), Vector2(A2, ZS)], w = 12.0, m = roadM},
		{p = riv, w = 10.0, m = roadM}, {p = acc_r, w = 10.0, m = roadM}]
	for cz in CS: ROADS.append({p = [Vector2(790, cz), Vector2(1470, cz)], w = 9.0, m = streetM, y = .03})
	for r in ROADS: r.P = strip(r.p, r.w, .1 + r.get("y", 0.0), r.m)
	# bridge
	var cm := Gfx.mat(Gfx.hexc(0xa9a69e), .85)
	var B: Array = ROADS[3].P.filter(func(pp): return absf(pp.x - U.river_x(pp.y)) < 80)
	var a: Vector2 = B[0]; var b: Vector2 = B[-1]; var L := a.distance_to(b); var ang := atan2(b.x - a.x, b.y - a.y); var c := (a + b) / 2
	var g := Node3D.new(); g.position = Vector3(c.x, 0, c.y); g.rotation.y = ang; root.add_child(g)
	Gfx.mi(g, Gfx.box(11.5, 1.2, L + 6), cm, Vector3(0, .9, 0))
	for s in [-1, 1]: Gfx.mi(g, Gfx.box(.4, 1, L + 6), cm, Vector3(s * 5.6, 2.1, 0))
	for t in [-.25, .25]: Gfx.mi(g, Gfx.cyl(1.1, 1.3, 9, 16), cm, Vector3(0, -4, t * L))
	# railway: ballast + rails, freight train by the plant
	var bal := Gfx.noise_img(128, .2, 31, 3, .4, .55)
	for y in range(4, 128, 16): bal.fill_rect(Rect2i(15, y, 98, 7), Color(.29, .23, .17))
	var balm := decal(bal, .95, 2.0, Color.WHITE, 2.0, Vector2.ONE, .2)
	var rP := []
	z = -3600.0
	while z <= 3600: rP.append(Vector2(U.rail_x(z), z)); z += 20
	strip(rP, 4.4, .12, balm, 6.0, 0.0, 4.0, true)
	var railM := Gfx.mat(Gfx.hexc(0x8a8580), .35, .9)
	for off in [-.72, .72]: strip(rP, .09, .32, railM, 6.0, off, 8.0, true)
	var wag := []; var tank := []
	z = 280.0
	for i in 16:
		var qd := {x = U.rail_x(z), y = G(U.rail_x(z), z) + .45, z = z + 7, c = pick([Gfx.hexc(0x5b3a2a), Gfx.hexc(0x6a4330), Gfx.hexc(0x4e3424), Gfx.hexc(0x5a5048)])}
		(tank if i % 5 == 4 else wag).append(qd); z += 15.5
	Gfx.multi(root, Gfx.merge([[Gfx.box(3.1, 3.3, 14), Gfx.xf(Vector3(0, 1.65, 0))]]), Gfx.mat(Color.WHITE, .8, .3), wag)
	Gfx.multi(root, Gfx.merge([[Gfx.capsule(1.45, 11), Gfx.xf(Vector3(0, 2.3, 0), Vector3(PI / 2, 0, 0))]]), Gfx.mat(Color.WHITE, .5, .5), tank)
	Gfx.mi(root, Gfx.box(3.1, 4.2, 18), Gfx.mat(Gfx.hexc(0x2f5a3a), .5, .4), Vector3(U.rail_x(258), G(U.rail_x(258), 258) + .45 + 2.6, 258))
	var under := []
	for q in wag + tank: under.append({x = q.x, y = q.y - .4, z = q.z})
	Gfx.multi(root, Gfx.merge([[Gfx.box(2.2, .5, 13.2), Gfx.xf(Vector3(0, .25, 0))]]), Gfx.mat(Gfx.hexc(0x1b1b1b), .7, .5), under)
	# ---- town blocks and private houses
	var F5 := [facade(Color("c9c2b2"), 5, 8, {bal = 2}), facade(Color("b9b6ad"), 5, 8, {bal = 3}), facade(Color("d2c4ae"), 5, 8, {bal = 2})]
	var F9 := [facade(Color("bdbab2"), 9, 8, {bal = 2}), facade(Color("cfc6b6"), 9, 8, {bal = 3})]
	var F12 := [facade(Color("c4c0b8"), 12, 6, {bal = 2})]
	var FH := facade(Color("f2f0ea"), 2, 3, {door = 1, frame = Color("f6f6f2")})
	var BT := {K5 = {w = 60.0, h = 15.0, d = 12.0, M = F5}, K5s = {w = 36.0, h = 15.0, d = 12.0, M = F5}, P9 = {w = 42.0, h = 27.0, d = 13.0, M = F9}, T12 = {w = 18.0, h = 36.0, d = 18.0, M = F12}}
	var blocks := {K5 = [], K5s = [], P9 = [], T12 = []}; var houses := []; var roofs := []; var tr := []; var parked := []; var sl := []; var lamps := []
	var clear := func(x: float, zz: float, r: float) -> bool:
		return absf(x - U.river_x(zz)) > 70 + r and absf(x - (U.river_x(zz) + 82)) > 12 + r and absf(x - U.rail_x(zz)) > 14 + r
	var OCC := []
	var free := func(x: float, zz: float, hw: float, hd: float) -> bool:
		for o in OCC:
			if absf(o[0] - x) < o[2] + hw + 9 and absf(o[1] - zz) < o[3] + hd + 9: return false
		return true
	var XS := [[790.0, A1], [A1, A2], [A2, 1470.0]]; var ZB := [[ZN, -820.0]]
	for i in CS.size() - 1: ZB.append([CS[i], CS[i + 1]])
	for xr in XS:
		for zr in ZB:
			var x0: float = xr[0]; var x1: float = xr[1]; var z0: float = zr[0]; var z1: float = zr[1]
			var pri: bool = x0 == 790 or z1 <= -580 or (x0 == A2 and z0 < -300)
			if pri:
				var x := x0 + 16
				while x < x1 - 12:
					var zz := z0 + 16
					while zz < z1 - 12:
						var hx := x + R(-3, 3); var hz := zz + R(-3, 3)
						if clear.call(hx, hz, 8.0) and rnd() >= .12:
							var ry: float = pick([0.0, PI / 2]) + R(-.08, .08); var s := R(.85, 1.25); var y := G(hx, hz) - .2; var sy: float = pick([1.0, 1.0, .55])
							houses.append({x = hx, y = y, z = hz, ry = ry, sx = s, sz = s, sy = sy, c = pick([Color("ffffff"), Color("f3e6c8"), Color("e8d6b0"), Color("f0d0c0"), Color("d8e2e8"), Color("e6e0d0")])})
							roofs.append({x = hx, y = y + 6 * sy, z = hz, ry = ry, sx = (4.5 * s + .7) / .7071, sy = R(2.4, 3.4), sz = (4 * s + .7) / .7071, c = pick([Color("8a3a24"), Color("a23a2a"), Color("7d2e22"), Color("4f6b4a"), Color("5f7288"), Color("9aa2a8"), Color("9aa2a8")])})
							for k in 2:
								var tx := hx + R(-11, 11); var tz := hz + R(-11, 11)
								if absf(tx - hx) > 6 or absf(tz - hz) > 6: tr.append({x = tx, z = tz, s = R(.45, .8)})
						zz += 24
					x += 24
			else:
				var zz := z0 + 22
				while zz < z1 - 16:
					var x := x0 + 18
					while x < x1 - 16:
						var t: String = "T12" if (rnd() < .12 and zz > -500) else ("P9" if rnd() < .35 else ("K5" if rnd() < .5 else "K5s"))
						var bt: Dictionary = BT[t]; var rot := 0.0 if t == "T12" else (PI / 2 if rnd() < .3 else 0.0)
						var lw: float = bt.d if rot else bt.w; var ld: float = bt.w if rot else bt.d
						if x + lw > x1 - 16 or zz + ld > z1 - 14:
							x += 12; continue
						var cx := x + lw / 2; var cz := zz + ld / 2
						if clear.call(cx, cz, lw / 2) and free.call(cx, cz, lw / 2, ld / 2):
							OCC.append([cx, cz, lw / 2, ld / 2])
							blocks[t].append({x = cx, y = G(cx, cz) - .3, z = cz, ry = rot})
							for k in 3: tr.append({x = cx + R(-lw / 2, lw / 2), z = cz + ld / 2 + R(5, 10), s = R(.8, 1.3)})
						x += lw + R(14, 26)
					zz += R(38, 52)
	for k in blocks:
		var Lb: Array = blocks[k]
		if Lb.is_empty(): continue
		var bt: Dictionary = BT[k]; var M: Array = bt.M
		var geo := Gfx.ubox(bt.w, bt.h, bt.d, 24.0 * (.75 if k == "T12" else 1.0), bt.h)
		for i in M.size():
			var LL := []
			for j in Lb.size():
				if j % M.size() == i: LL.append(Lb[j])
			var o := Gfx.multi(root, geo, null, LL)
			if o:
				o.multimesh.mesh = geo
				o.material_override = null
				var mm2: ArrayMesh = geo.duplicate()
				mm2.surface_set_material(0, M[i]); mm2.surface_set_material(1, roof_m()); o.multimesh.mesh = mm2
		var lr := []
		for q in Lb: lr.append({x = q.x + (rnd() - .5) * 8, y = q.y + bt.h, z = q.z, ry = q.ry})
		Gfx.multi(root, Gfx.merge([[Gfx.box(5, 2.6, 4), Gfx.xf(Vector3(0, 1.3, 0))]]), roof_m(), lr)
	var hg: ArrayMesh = Gfx.ubox(9, 6, 8, 9, 6).duplicate()
	var fhc := FH.duplicate() as StandardMaterial3D; fhc.vertex_color_use_as_albedo = true; night_windows.append([fhc, 1.5])
	hg.surface_set_material(0, fhc); hg.surface_set_material(1, roof_m())
	var ho := Gfx.multi(root, hg, null, houses)
	var rg := Gfx.cyl(0, 1, 1, 4, true)
	var rmesh := Gfx.merge([[rg, Gfx.xf(Vector3(0, .5, 0), Vector3(0, PI / 4, 0))]])
	var tiles := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var row := y % 8; var col := (x + (4 if (y / 8) % 2 else 0)) % 8
			var v := .78 + .2 * sin(row / 8.0 * PI) - (.3 if row == 7 else 0.0) - (.12 if col == 0 else 0.0) + .06 * sin(float((x / 8) * 13 + (y / 8) * 7))
			tiles.set_pixel(x, y, Color(v, v, v))
	var rm := Gfx.textured(tiles, .7, 3.0); rm.cull_mode = BaseMaterial3D.CULL_DISABLED; rm.uv1_scale = Vector3(8, 5, 1); rm.vertex_color_use_as_albedo = true
	Gfx.multi(root, rmesh, rm, roofs)
	var chim := []
	for i in houses.size():
		if i % 5 < 3:
			var hq: Dictionary = houses[i]; var o := Vector2(2.4 * hq.sx, 1.6).rotated(-hq.ry)
			chim.append({x = hq.x + o.x, y = hq.y + 6 * hq.sy, z = hq.z + o.y, ry = hq.ry})
	Gfx.multi(root, Gfx.merge([[Gfx.box(.6, 3.2, .6), Gfx.xf(Vector3(0, 1.6, 0))], [Gfx.box(.75, .15, .75), Gfx.xf(Vector3(0, 3.2, 0))]]), Gfx.mat(Color("8a5a48"), .9), chim)
	# streetlights and parked cars; moving traffic lanes
	for r in ROADS:
		var P: Array = r.P
		if r.p == riv: P = P.filter(func(pp): return absf(pp.y) < 1100)
		var acc := 0.0; var nxt := 0.0; var nextC := R(4, 10)
		for i in range(1, P.size()):
			var pa: Vector2 = P[i - 1]; var pb: Vector2 = P[i]; var d := pb - pa; var Ld := d.length()
			if Ld < 1e-3: continue
			acc += Ld
			var nrm := Vector2(-d.y, d.x) / Ld; var ry := atan2(d.x, d.y)
			if acc > nxt and r.w >= 9:
				nxt = acc + (34.0 if r.m == roadM else 40.0)
				var xz: Vector2 = pb + nrm * (r.w / 2 + 1.2); var y := road_y(xz.x, xz.y)
				var lp := Vector3(xz.x - nrm.x * 1.6, y + 8.6, xz.y - nrm.y * 1.6)
				sl.append({x = xz.x, y = y, z = xz.y, ry = atan2(lp.z - xz.y, -(lp.x - xz.x))}); lamps.append(lp)
			if acc > nextC and r.m == streetM and U.town_e(pb.x, pb.y) < 1.2:
				nextC = acc + R(6, 16)
				for s in [-1, 1]:
					if rnd() < .45:
						var xz: Vector2 = pb + s * nrm * (r.w / 2 + 1.4)
						if clear.call(xz.x, xz.y, 1.0): parked.append({x = xz.x, y = G(xz.x, xz.y) + .05, z = xz.y, ry = ry + R(-.04, .04), c = pick(CARC)})
	var poleG := Gfx.merge([[Gfx.cyl(.1, .16, 9, 8), Gfx.xf(Vector3(0, 4.5, 0))], [Gfx.box(1.8, .12, .12), Gfx.xf(Vector3(-.9, 8.8, 0))], [Gfx.box(.7, .18, .32), Gfx.xf(Vector3(-1.6, 8.7, 0))]])
	Gfx.multi(root, poleG, Gfx.mat(Gfx.hexc(0x6b6f74), .45, .7), sl)
	night_light(Color(1, .66, .31), lamps, .24)
	park(parked)
	traffic = [ROADS[0].P, ROADS[1].P, ROADS[2].P.filter(func(pp): return absf(pp.y) < 2500), ROADS[3].P]
	_plant()
	# ---- trees: round deciduous crowns in streets, gardens, river banks and hill forests (plus conifers on the hills)
	var at := 0
	while at < 50000 and tr.size() < 11000:
		at += 1
		var x := R(-2800, 3000); var zz := R(-3200, 3200); var hk := U.hill_k(x, zz); var dr := absf(x - U.river_x(zz)); var ok := false
		if hk > .3 and U.fbm(x * .0035 + 5, zz * .0035, 3) > .45:
			var y := G(x, zz); ok = y < 260 and absf(G(x + 4, zz) - y) < 3.2
		elif dr > 48 and dr < 120 and absf(dr - 82) > 9 and rnd() < .5: ok = true
		if ok and Vector2(x, zz).length() > 440 and clear.call(x, zz, -60.0) and not (x > -1000 and x < -600 and zz > 200 and zz < 700) and not (x > 850 and x < 1470 and zz > 420 and zz < 1000):
			tr.append({x = x, z = zz, s = R(.7, 1.4)})
	var TL := []
	for t in tr:
		if absf(t.x - U.river_x(t.z)) > 44:
			TL.append({x = t.x, y = G(t.x, t.z) - .2, z = t.z, ry = rnd() * 6, sx = t.s, sy = t.s * R(.85, 1.2), sz = t.s, c = Color.from_hsv(R(.19, .29), R(.4, .6), R(.22, .34))})
	var dec := [deciduous(1), deciduous(2), deciduous(3)]
	var dfar := far_tree(false)
	for v in 3:
		var LL := []
		for i in range(v, TL.size(), 3): LL.append(TL[i])
		multi_lod(dec[v], dfar, LL)
	# conifer forests on the hills
	var CF := []; at = 0
	while at < 120000 and CF.size() < 12000:
		at += 1
		var r := 430 + pow(rnd(), .9) * 2800; var thh := rnd() * TAU; var x := cos(thh) * r; var zz := sin(thh) * r
		if U.fbm(x * .004, zz * .004, 3) < .47 or U.hill_k(x, zz) < .35: continue
		var y := G(x, zz)
		if y > 230 or absf(G(x + 4, zz) - y) > 2.6: continue
		var s := .7 + rnd() * .9
		CF.append({x = x, y = y - .2, z = zz, ry = rnd() * 6, sx = s * R(.9, 1.1), sy = s * R(.9, 1.25), sz = s * R(.9, 1.1), c = Color.from_hsv(.27 + rnd() * .07, R(.4, .55), .17 + rnd() * .1)})
	var con := [conifer(1), conifer(2)]
	var cfar := far_tree(true)
	for v in 2:
		var LL := []
		for i in range(v, CF.size(), 2): LL.append(CF[i])
		multi_lod(con[v], cfar, LL)
	# vineyard rows west of the airfield
	var V2 := []; var posts := []
	z = 210.0
	while z < 690:
		var x := -990.0
		while x < -610:
			if rnd() >= .06:
				var y := G(x, z)
				if absf(G(x + 3, z) - y) <= 2:
					V2.append({x = x, y = y, z = z, ry = 0.0, sx = R(.8, 1.1), sy = R(.8, 1.15), sz = 1.0, c = Color.from_hsv(R(.2, .26), .5, R(.25, .35))})
					if V2.size() % 6 == 0: posts.append({x = x, y = y, z = z})
			x += 1.7
		z += 2.8
	var vm := Gfx.merge([[Gfx.sphere(.7, 10, 6), Gfx.xf(Vector3(0, .95, 0), Vector3.ZERO, Vector3(1, 1.1, .55))]])
	var vmi := Gfx.multi(root, vm, null, V2, false); vmi.material_override = foliage_mat(.35, 0.0, 0.0)
	vmi.visibility_range_end = 1600; vmi.visibility_range_end_margin = 200; vmi.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
	Gfx.multi(root, Gfx.merge([[Gfx.box(.07, 1.7, .07), Gfx.xf(Vector3(0, .85, 0))]]), Gfx.mat(Gfx.hexc(0x6b5a44), 1), posts, false).visibility_range_end = 900
	_church(); _powerline()


# ---------------- vegetation ----------------
func foliage_mat(clump := .9, needle := 0.0, sway := 1.0, sway_h := 3.0) -> ShaderMaterial:
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/world/foliage.gdshader")
	m.set_shader_parameter("noise_t", noise_tex("a")); m.set_shader_parameter("noise_n", noise_tex("n"))
	m.set_shader_parameter("clump", clump); m.set_shader_parameter("needle", needle); m.set_shader_parameter("sway", sway); m.set_shader_parameter("sway_h", sway_h)
	return m

func bark_mat() -> StandardMaterial3D:
	if not _T.has("bark"):
		var img := Gfx.noise_img(256, .03, 61, 4, .4, .8)
		img.resize(128, 512, Image.INTERPOLATE_BILINEAR)   # stretched: vertical bark furrows
		var m := Gfx.textured(img, .95, 4.0, Color("6a5a48")); m.uv1_scale = Vector3(2, 1, 1)
		_T.bark = m
	return _T.bark

## pushes every vertex out along its normal by 3D noise: lumpy, natural crown silhouettes
func lumpy(mesh: ArrayMesh, amp: float, freq: float, seed_: int) -> ArrayMesh:
	var n := FastNoiseLite.new(); n.seed = seed_; n.frequency = freq; n.fractal_octaves = 3
	var st := SurfaceTool.new(); st.create_from(mesh, 0)
	var arr := st.commit_to_arrays()
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var Nn: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]
	for i in V.size():
		var v := V[i]
		V[i] = v + Nn[i] * n.get_noise_3dv(v) * amp
	arr[Mesh.ARRAY_VERTEX] = V
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var s2 := SurfaceTool.new(); s2.create_from(am, 0); s2.generate_normals()
	return s2.commit()

## broad-leaved tree: forked trunk with branches into a crown of lumpy leaf clusters (two surfaces: bark, leaves)
func deciduous(v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new(); r.seed = 100 + v
	var blobs := []
	var nb := 7 + v * 2
	for i in nb:
		var a := r.randf() * TAU; var rr := r.randf_range(.4, 1.0) * (0.0 if i == 0 else 2.2)
		var c := Vector3(cos(a) * rr, 6.4 + r.randf_range(-1.3, 1.5) - rr * .25, sin(a) * rr)
		var s := r.randf_range(1.2, 1.9) * (1.35 if i == 0 else 1.0)
		blobs.append([Gfx.sphere(1, 11, 7), Gfx.xf(c, Vector3(r.randf(), r.randf() * 3, 0), Vector3(s * 1.05, s * .85, s))])
	var crown := lumpy(Gfx.merge(blobs), .38, .55, v)
	var wood := []
	wood.append([Gfx.cyl(.15, .28, 5.2, 9), Gfx.xf(Vector3(0, 2.6, 0))])
	wood.append([Gfx.cyl(.3, .4, .5, 9), Gfx.xf(Vector3(0, .2, 0))])
	for i in 4:
		var a := i * TAU / 4 + r.randf() * .8
		var top := Vector3(cos(a) * 1.6, 6.3 + r.randf(), sin(a) * 1.6)
		wood.append([Gfx.line_tube(Vector3(0, 3.6 + i * .35, 0), top, .09, 6), Transform3D()])
	var trunk := Gfx.merge(wood)
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.surface_get_arrays(0)); am.surface_set_material(0, bark_mat())
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, crown.surface_get_arrays(0)); am.surface_set_material(1, _leaf_mat(false))
	return am

func _leaf_mat(needle: bool) -> ShaderMaterial:
	var k := "leafN" if needle else "leafD"
	if not _T.has(k): _T[k] = foliage_mat(.9, 1.0 if needle else 0.0, .6 if needle else 1.0, 2.0 if needle else 3.5)
	return _T[k]

## spruce / fir: drooping, star-shaped branch tiers around a straight trunk
func conifer(v: int) -> ArrayMesh:
	var r := RandomNumberGenerator.new(); r.seed = 200 + v
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var tiers := 7; var H := 11.5; var spikes := 13
	for k in tiers:
		var t := float(k) / tiers
		var y0 := 1.8 + t * (H - 3.0); var top := y0 + 2.6 - t * .6
		var R := (2.9 - t * 2.5) * r.randf_range(.9, 1.1)
		var ring := []
		for j in spikes * 2:
			var a := TAU * j / (spikes * 2) + r.randf() * .12 + k * .4
			var rr := R * (1.0 if j % 2 == 0 else .55) * r.randf_range(.85, 1.1)
			var y := y0 - (.55 if j % 2 == 0 else .15) * (R / 2.9 + .3)
			ring.append(Vector3(cos(a) * rr, y, sin(a) * rr))
		var apex := Vector3(0, top, 0); var cen := Vector3(0, y0 + .2, 0)
		for j in ring.size():
			var a: Vector3 = ring[j]; var b: Vector3 = ring[(j + 1) % ring.size()]
			for p in [apex, b, a]: st.add_vertex(p)
			for p in [cen, a, b]: st.add_vertex(p)
	st.generate_normals()
	var fol := lumpy(st.commit(), .18, 1.2, 300 + v)
	var trunk := Gfx.merge([[Gfx.cyl(.08, .26, H, 8), Gfx.xf(Vector3(0, H / 2, 0))]])
	var am := ArrayMesh.new()
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, trunk.surface_get_arrays(0)); am.surface_set_material(0, bark_mat())
	am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, fol.surface_get_arrays(0)); am.surface_set_material(1, _leaf_mat(true))
	return am

func far_tree(con: bool) -> ArrayMesh:
	var m: ArrayMesh
	if con: m = Gfx.merge([[Gfx.cone(2.5, 10.5, 6), Gfx.xf(Vector3(0, 6.2, 0))]])
	else: m = Gfx.merge([[Gfx.sphere(1, 8, 5), Gfx.xf(Vector3(0, 6.6, 0), Vector3.ZERO, Vector3(3.2, 2.7, 3.2))], [Gfx.cyl(.2, .3, 4.5, 4, true), Gfx.xf(Vector3(0, 2.2, 0))]])
	m.surface_set_material(0, _leaf_mat(con))
	return m

## splits instances into square cells: detailed trees near the camera, simple ones further out, cross-faded
func multi_lod(near: Mesh, far: Mesh, L: Array, cell := 500.0, near_end := 750.0) -> void:
	var C := {}
	for q in L:
		var k := Vector2i(floori(q.x / cell), floori(q.z / cell))
		if not C.has(k): C[k] = []
		C[k].append(q)
	for k in C:
		var a := Gfx.multi(root, near, null, C[k], true)
		a.visibility_range_end = near_end; a.visibility_range_end_margin = 150; a.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF
		var b := Gfx.multi(root, far, null, C[k], false)
		b.visibility_range_begin = near_end; b.visibility_range_begin_margin = 150; b.visibility_range_end = 7000; b.visibility_range_end_margin = 500
		b.visibility_range_fade_mode = GeometryInstance3D.VISIBILITY_RANGE_FADE_SELF; b.add_to_group("lod_far", true)

# ---------------- grass ----------------
var excl: Image
const EXN := 2048
func ex_rect(x0: float, z0: float, x1: float, z1: float) -> void:
	if excl == null: return
	var k := EXN / U.TS
	var a := Vector2i(int((minf(x0, x1) + U.TS / 2) * k), int((minf(z0, z1) + U.TS / 2) * k)); var b := Vector2i(ceili((maxf(x0, x1) + U.TS / 2) * k), ceili((maxf(z0, z1) + U.TS / 2) * k))
	excl.fill_rect(Rect2i(a, b - a), Color.BLACK)
func ex_line(P: Array, w: float) -> void:
	for i in P.size() - 1:
		var a: Vector2 = P[i]; var b: Vector2 = P[i + 1]; var n := maxi(1, ceili(a.distance_to(b) / 2.0))
		for k in n + 1:
			var p := a.lerp(b, float(k) / n); ex_rect(p.x - w / 2, p.y - w / 2, p.x + w / 2, p.y + w / 2)

func _grass() -> void:
	# one clump: five tapered, curved blades
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var r := RandomNumberGenerator.new(); r.seed = 77
	for b in 14:
		var a := r.randf() * TAU; var dir := Vector3(cos(a), 0, sin(a)); var side := Vector3(-dir.z, 0, dir.x)
		var o := Vector3(r.randf_range(-.24, .24), 0, r.randf_range(-.24, .24)); var h := r.randf_range(.16, .42); var w := r.randf_range(.011, .02); var lean := r.randf_range(.05, .2)
		var segs := 3; var prev := []
		for sgi in segs + 1:
			var t := float(sgi) / segs
			var c := o + dir * lean * t * t + Vector3(0, h * t, 0); var ww := w * (1.0 - t * .92)
			var row := [c - side * ww, c + side * ww, t]
			if sgi > 0:
				var n := side.cross(Vector3(0, 1, 0) + dir * lean * 2 * t).normalized() * -1
				var Q := [[prev[0], prev[2]], [row[0], row[2]], [row[1], row[2]], [prev[1], prev[2]]]
				for idx in [0, 1, 2, 0, 2, 3]:
					st.set_normal(n); st.set_uv(Vector2(0 if idx < 2 else 1, Q[idx][1])); st.add_vertex(Q[idx][0])
			prev = row
	var mesh := st.commit()
	var sp := .55; var RM := 46.0
	var pts := []
	var nn := int(RM / sp)
	for j in range(-nn, nn + 1):
		for i in range(-nn, nn + 1):
			var p := Vector2(i, j) * sp
			if p.length() <= RM: pts.append(p)
	pts.sort_custom(func(a, b): return a.length_squared() < b.length_squared())
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.mesh = mesh; mm.instance_count = pts.size()
	for i in pts.size(): mm.set_instance_transform(i, Transform3D(Basis(), Vector3(pts[i].x, 0, pts[i].y)))
	var o := MultiMeshInstance3D.new(); o.name = "Grass"; o.multimesh = mm
	o.custom_aabb = AABB(Vector3(-RM - 2, -50, -RM - 2), Vector3(2 * RM + 4, 700, 2 * RM + 4))
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	var m := ShaderMaterial.new(); m.shader = load("res://shaders/world/grass.gdshader")
	var tm: ShaderMaterial = root.get_meta("terrain_mat")
	for k in ["color_map", "mask_map", "height_map"]: m.set_shader_parameter(k, tm.get_shader_parameter(k))
	m.set_shader_parameter("excl_map", ImageTexture.create_from_image(excl)); m.set_shader_parameter("spacing", sp); m.set_shader_parameter("radius", RM)
	o.material_override = m
	o.set_meta("max_r", RM); o.set_meta("counts", [pts.size()])
	root.add_child(o); root.set_meta("grass", o)

func _plant() -> void:
	ex_rect(850, 400, 1470, 1000)
	var rust := Image.create(256, 256, false, Image.FORMAT_RGBA8); rust.fill(Color("8a8478"))
	for x in range(0, 256, 4): rust.fill_rect(Rect2i(x, 0, 2, 256), Color("8a8478").lightened(.06) if x % 8 else Color("8a8478").darkened(.06))
	for i in 130: rust.fill_rect(Rect2i(rng.randi() % 256, rng.randi() % 150, 1 + rng.randi() % 4, 20 + rng.randi() % 120), Color(.47, .23, .1).lerp(Color("8a8478"), .5))
	var emi := Image.create(256, 256, false, Image.FORMAT_RGBA8); emi.fill(Color.BLACK)
	for x in range(6, 256, 32):
		rust.fill_rect(Rect2i(x, 20, 22, 35), Color(.12, .11, .1))
		if rnd() < .7: emi.fill_rect(Rect2i(x, 21, 20, 33), Color("ffb060"))
	var hm := Gfx.textured(rust, .75); hm.metallic = .35
	hm.emission_enabled = true; hm.emission_texture = Gfx.tex(emi); hm.emission = Color.BLACK; hm.emission_energy_multiplier = 0
	night_windows.append([hm, 1.2])
	var hr := Gfx.mat(Gfx.hexc(0x6f6a62), .7, .45)
	flat(620, 600, conc_img(), 1160, .18, 700, Vector2(17, 17), 0, 1.0, Color("8a867f"), 1.0)
	var hall := func(x: float, z: float, w: float, h: float, d: float, ry := 0.0):
		var g := Node3D.new(); g.position = Vector3(x, 0, z); g.rotation.y = ry; root.add_child(g)
		var mm := Gfx.mi(g, Gfx.ubox(w, h, d, 12, h), hm); mm.set_surface_override_material(1, hr)
		var pr := PrismMesh.new(); pr.size = Vector3(d + 1.2, d * .22, w + 1.2)
		Gfx.mi(g, pr, hr, Vector3(0, h + d * .11, 0), Vector3(0, PI / 2, 0))
		for i in int(w / 14): Gfx.mi(g, Gfx.box(4, 2.5, 3), hr, Vector3(-w / 2 + 7 + i * 14, h + d * .22 - 1, 0))
	hall.call(1150.0, 560.0, 160.0, 28.0, 34.0); hall.call(1130.0, 690.0, 120.0, 20.0, 26.0); hall.call(1350.0, 780.0, 90.0, 18.0, 40.0, PI / 2); hall.call(1120.0, 860.0, 80.0, 14.0, 30.0); hall.call(1330.0, 480.0, 50.0, 34.0, 24.0)
	Gfx.mi(root, Gfx.box(22, 20, 18), hm, Vector3(1180, 26, 625))
	for i in 3: Gfx.mi(root, Gfx.cyl(4, 0, 8, 4), hr, Vector3(1173 + i * 7, 12, 625), Vector3(0, PI / 4, 0))
	for p in [[1170, 617], [1190, 617], [1170, 633], [1190, 633]]: Gfx.mi(root, Gfx.box(.8, 16, .8), hr, Vector3(p[0], 8, p[1]), Vector3.ZERO, false)
	for t in [[[1180, 30, 577], [1180, 40, 596], [1180, 34, 616], 1.6], [[1120, 30, 577], [1150, 42, 600], [1172, 34, 618], 1.4], [[1188, 34, 625], [1220, 40, 612], [1238, 96, 600], 1.1], [[1100, 24, 690], [1040, 10, 700], [960, 6, 840], .6]]:
		var pts := PackedVector3Array([Vector3(t[0][0], t[0][1], t[0][2]), Vector3(t[1][0], t[1][1], t[1][2]), Vector3(t[2][0], t[2][1], t[2][2])])
		Gfx.mi(root, Gfx.tube(pts, t[3], 12, false, 24), hr)
	var band := Image.create(32, 256, false, Image.FORMAT_RGBA8)
	for i in 8: band.fill_rect(Rect2i(0, i * 32, 32, 32), Color("f2efe8") if i % 2 else Color("b8261e"))
	var bm := Gfx.textured(band, .7); bm.cull_mode = BaseMaterial3D.CULL_DISABLED
	for s in [[1240, 520, 118, 4.2], [1240, 600, 100, 3.6], [1060, 515, 82, 3]]:
		var x: float = s[0]; var z: float = s[1]; var h: float = s[2]; var r: float = s[3]
		Gfx.mi(root, Gfx.cyl(r * .72, r, h, 28, true), bm, Vector3(x, h / 2, z))
		for y in [h * .55, h - 2]: Gfx.mi(root, Gfx.box(r * 1.9 + 1, .4, r * 1.9 + 1), hr, Vector3(x, y, z), Vector3.ZERO, false)
		night_light(Color(1, .13, .06), [Vector3(x + r * .8, h - 1, z), Vector3(x - r * .8, h - 1, z), Vector3(x, h * .55 + .6, z + r)], .45)
		smoke_src.append(Vector3(x, h, z))
	var gas := Gfx.mat(Gfx.hexc(0xb7bab5), .4, .6)
	for g in [[920, 860, 11, 14], [950, 890, 9, 12], [915, 925, 9, 12], [948, 950, 7, 10]]:
		Gfx.mi(root, Gfx.cyl(g[2], g[2], g[3], 32), gas, Vector3(g[0], g[3] / 2.0, g[1]))
		var d := Gfx.mi(root, Gfx.sphere(g[2], 32, 8, true), gas, Vector3(g[0], g[3], g[1])); d.scale.y = .25
	for hp in [[1400, 905, 24, 12, "3a3634"], [1425, 950, 18, 9, "5e3a2a"], [1380, 960, 14, 7, "2d2b2a"], [890, 960, 16, 8, "6b6a66"]]:
		Gfx.mi(root, Gfx.cone(hp[2], hp[3], 24), Gfx.mat(Color(hp[4]), 1), Vector3(hp[0], hp[3] / 2.0, hp[1]))
	for ab in [[Vector3(1400, 12, 905), Vector3(1350, 26, 800)], [Vector3(1425, 9, 950), Vector3(1340, 22, 830)]]:
		var A: Vector3 = ab[0]; var Bv: Vector3 = ab[1]
		var o := Gfx.mi(root, Gfx.box(2.4, 2, A.distance_to(Bv)), hr, (A + Bv) / 2); o.look_at_from_position(o.position, Bv)
		var t := .15
		while t < 1:
			var pp := A.lerp(Bv, t); Gfx.mi(root, Gfx.box(.5, pp.y, .5), hr, Vector3(pp.x, pp.y / 2, pp.z), Vector3.ZERO, false); t += .17
	night_light(Color(1, .85, .63), [Vector3(1150, 29, 541), Vector3(1150, 29, 579), Vector3(1080, 29, 541), Vector3(1220, 29, 541), Vector3(1130, 21, 676), Vector3(1350, 19, 758), Vector3(1330, 35, 467)], .5)

func _church() -> void:
	var best := Vector3(0, -1e9, 0)
	for i in 400:
		var x := R(-1400, -650); var z := R(-1100, -450); var y := G(x, z)
		if y > best.y: best = Vector3(x, y, z)
	var st := Image.create(256, 256, false, Image.FORMAT_RGBA8); st.fill(Color("c9b38c"))
	for y in range(0, 256, 16):
		var off := 12 if (y / 16) % 2 else 0
		for x in range(off - 24, 256, 24):
			var v := (170 + rnd() * 50) / 255.0; st.fill_rect(Rect2i(maxi(x + 1, 0), y + 1, 22, 14), Color(v, v - .08, v - .2))
	var sm := Gfx.textured(st, .9, 2.0); var rm := Gfx.mat(Gfx.hexc(0x5a4a3a), .8)
	var g := Node3D.new(); g.position = best - Vector3(0, 1, 0); g.rotation.y = .3; root.add_child(g)
	var arm := func(w: float, d: float, ry: float):
		var a := Node3D.new(); a.rotation.y = ry; g.add_child(a)
		var m := Gfx.mi(a, Gfx.ubox(w, 10, d, 6, 6), sm); m.set_surface_override_material(1, sm)
		var pr := PrismMesh.new(); pr.size = Vector3(w + .8, 3.4, d + .8); Gfx.mi(a, pr, rm, Vector3(0, 11.7, 0))
	arm.call(9.0, 22.0, 0.0); arm.call(9.0, 18.0, PI / 2)
	Gfx.mi(g, Gfx.cyl(3.2, 3.2, 7, 12), sm, Vector3(0, 15.5, 0)); Gfx.mi(g, Gfx.cone(3.8, 5, 12), rm, Vector3(0, 21.5, 0))
	var gold := Gfx.mat(Gfx.hexc(0xc8a040), .3, .9)
	Gfx.mi(g, Gfx.box(.2, 1.6, .2), gold, Vector3(0, 24.8, 0)); Gfx.mi(g, Gfx.box(1, .2, .2), gold, Vector3(0, 25.1, 0))
	var bt := Gfx.mi(g, Gfx.ubox(4, 13, 4, 4, 6), sm, Vector3(14, 0, 8)); bt.set_surface_override_material(1, sm)
	Gfx.mi(g, Gfx.cyl(0, 3.2, 3.5, 4), rm, Vector3(14, 14.7, 8), Vector3(0, PI / 4, 0))
	var cyp := Gfx.mat(Gfx.hexc(0x1f3a22), .9)
	for i in 14:
		var a := i / 14.0 * TAU; var x := best.x + cos(a) * 30; var z := best.z + sin(a) * 30
		Gfx.mi(root, Gfx.cone(1.2, 9, 8), cyp, Vector3(x, G(x, z) - .3 + 4.5, z))

func _powerline() -> void:
	var A := Vector2(1160, 990); var B := Vector2(-1900, 2350); var N := 15; var pg := []
	var parts := []
	for ab in [[-1, -1], [1, -1], [-1, 1], [1, 1]]:
		parts.append([Gfx.box(.4, 30, .4), Gfx.xf(Vector3(ab[0] * 2.2 * .5 + ab[0] * 1.1, 15, ab[1] * 1.1), Vector3(-ab[1] * .07, 0, ab[0] * .07))])
	for y in [10, 18, 24]: parts.append([Gfx.box(2 * (2.2 - y * .07) + .4, .3, 2 * (2.2 - y * .07) + .4), Gfx.xf(Vector3(0, y, 0))])
	parts.append([Gfx.box(14, .5, .6), Gfx.xf(Vector3(0, 26, 0))]); parts.append([Gfx.box(9, .5, .6), Gfx.xf(Vector3(0, 31, 0))]); parts.append([Gfx.cyl(0, 1.6, 4, 4), Gfx.xf(Vector3(0, 33, 0))])
	for i in N + 1:
		var p := A.lerp(B, float(i) / N)
		if absf(p.x - U.river_x(p.y)) < 70: continue
		pg.append({x = p.x, y = G(p.x, p.y), z = p.y, ry = atan2(B.x - A.x, B.y - A.y) + PI / 2})
	Gfx.multi(root, Gfx.merge(parts), Gfx.mat(Gfx.hexc(0x8d9297), .5, .7), pg)
	var im := ImmediateMesh.new(); im.surface_begin(Mesh.PRIMITIVE_LINES)
	for i in range(1, pg.size()):
		var a: Dictionary = pg[i - 1]; var b: Dictionary = pg[i]; var ux := cos(a.ry); var uz := -sin(a.ry)
		for oh in [[-6.6, 26], [6.6, 26], [0, 31]]:
			for k in 20:
				var P := func(t: float) -> Vector3:
					return Vector3(a.x + (b.x - a.x) * t + ux * oh[0], a.y + (b.y - a.y) * t + oh[1] - 1 - 8 * sin(PI * t), a.z + (b.z - a.z) * t + uz * oh[0])
				im.surface_add_vertex(P.call(k / 20.0)); im.surface_add_vertex(P.call((k + 1) / 20.0))
	im.surface_end()
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_LINES, im.surface_get_arrays(0))
	Gfx.mi(root, am, Gfx.unshaded(Color(.13, .13, .13), 0), Vector3.ZERO, Vector3.ZERO, false)
