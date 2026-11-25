class_name R44 extends HeliBase
## Robinson R44 model, cockpit, instrument panel and controls catalogue.

var cyc: Node3D; var col: Node3D; var grip: Node3D; var peds: Array = []; var swash: Node3D; var swR: Node3D
var rTilt: Node3D; var rSpin: Node3D; var trSpin: Node3D; var blades: Array = []; var blur: MeshInstance3D
var SW := {}; var keyB: Node3D; var mixK: Node3D; var carbK: Node3D; var fuelL: Node3D; var rbL: Node3D
var navL: Array = []; var strobeL: MeshInstance3D; var ldg: SpotLight3D; var ldg_lens: StandardMaterial3D
var panel_vp: SubViewport; var ped_vp: SubViewport; var pdraw: Gauges
var ang := 0.0; var tra := 0.0

const SWX := [["clutch", -.345], ["batt", -.25], ["alt", -.19], ["avion", -.13], ["gov", -.07], ["strobe", -.01], ["nav", .05], ["ldg", .11]]
const CAB_K := [[-2.38, .01, 1.02, .99], [-2.3, .30, 1.22, .78], [-2.1, .50, 1.45, .62], [-1.8, .60, 1.66, .54], [-1.4, .65, 1.84, .50], [-.9, .66, 1.95, .49], [-.4, .65, 1.98, .50], [0, .58, 1.96, .56], [.15, .42, 1.90, .70], [.24, .02, 1.75, .95]]
const COWL_K := [[-.6, .02, 1.97, 1.9], [-.35, .30, 2.2, 1.86], [0, .36, 2.3, 1.82], [.5, .38, 2.2, 1.38], [1.0, .33, 1.95, 1.25], [1.5, .27, 1.72, 1.16]]
const COWL_O := {nx = 2.4, nt = 2.4, nb = 2.4, cf = .3}

var GA: Array

func _init(s: Sim) -> void:
	sim = s; _init_mats(); name = "R44"
	model = Node3D.new(); model.position.y = -1.15; add_child(model)
	_gauges(); _body(); _rotor(); _tail(); _cockpit(); _details()

func _gauges() -> void:
	var fu := func(v: float) -> String: return ("½" if v < 1 else "F") if v else "E"
	GA = [
		{id = "tach", x = -.3, y = .085, r = .046, o = {min = 0, max = 110, a0 = .75 * PI, a1 = 2.25 * PI, maj = 10, mn = 2, lab = [0, 20, 40, 60, 80, 100], arcs = [[90, 108, "#2bb24c", .76], [101, 102, "#2bb24c", .9], [108, 110, "#dd2222", .86], [0, 90, "#cc3333", .76]], t = "RPM %", t2 = "ENG  ROTOR"}},
		{id = "asi", x = -.19, y = .085, r = .046, o = {min = 0, max = 150, a0 = -.5 * PI + .25, a1 = 1.5 * PI - .25, maj = 10, mn = 5, lab = [0, 20, 40, 60, 80, 100, 120, 140], arcs = [[129, 131, "#dd2222", .86]], t = "KNOTS", t2 = "AIRSPEED"}},
		{id = "ai", x = -.08, y = .085, r = .046},
		{id = "alt", x = .03, y = .085, r = .046, o = {min = 0, max = 10, a0 = -.5 * PI, a1 = 1.5 * PI, maj = 1, mn = .2, lab = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], t = "ALT", t2 = "100 FT"}},
		{id = "map", x = -.3, y = -.03, r = .046, o = {min = 10, max = 30, a0 = .75 * PI, a1 = 2.25 * PI, maj = 5, mn = 1, lab = [10, 15, 20, 25, 30], arcs = [[15, 25.6, "#2bb24c"], [25.6, 26.2, "#dd2222"]], t = "MAN PRESS", t2 = "IN HG"}},
		{id = "vsi", x = -.19, y = -.03, r = .046, o = {min = -2, max = 2, a0 = .1 * PI, a1 = 1.9 * PI, maj = .5, mn = .1, lab = [-2, -1, 0, 1, 2], fmt = func(v): return str(absi(int(v))), t = "VERT SPEED", t2 = "×1000 FPM"}},
		{id = "dg", x = -.08, y = -.03, r = .046},
		{id = "clk", x = .03, y = -.03, r = .046},
		{id = "oilt", x = .145, y = .095, r = .027, o = {min = 50, max = 250, a0 = .75 * PI, a1 = 2.25 * PI, maj = 50, mn = 25, lab = [50, 150, 250], arcs = [[75, 245, "#2bb24c"], [245, 250, "#dd2222"]], t = "OIL °F"}},
		{id = "oilp", x = .215, y = .095, r = .027, o = {min = 0, max = 100, a0 = .75 * PI, a1 = 2.25 * PI, maj = 25, mn = 5, lab = [0, 50, 100], arcs = [[0, 25, "#dd2222"], [25, 95, "#2bb24c"], [95, 100, "#dd2222"]], t = "OIL PSI"}},
		{id = "cht", x = .285, y = .095, r = .027, o = {min = 200, max = 500, a0 = .75 * PI, a1 = 2.25 * PI, maj = 100, mn = 50, lab = [200, 300, 400, 500], arcs = [[200, 495, "#2bb24c"], [495, 500, "#dd2222"]], t = "CHT °F"}},
		{id = "cat", x = .355, y = .095, r = .027, o = {min = -30, max = 30, a0 = .75 * PI, a1 = 2.25 * PI, maj = 10, mn = 5, lab = [-30, 0, 30], arcs = [[-15, 5, "#e0b000"]], t = "CARB °C"}},
		{id = "fuelm", x = .145, y = .025, r = .027, o = {min = 0, max = 1, a0 = .75 * PI, a1 = 2.25 * PI, maj = .5, mn = .25, lab = [0, .5, 1], fmt = fu, arcs = [[0, .1, "#dd2222"]], t = "MAIN"}},
		{id = "fuela", x = .215, y = .025, r = .027, o = {min = 0, max = 1, a0 = .75 * PI, a1 = 2.25 * PI, maj = .5, mn = .25, lab = [0, .5, 1], fmt = fu, t = "AUX"}},
		{id = "amm", x = .285, y = .025, r = .027, o = {min = -60, max = 60, a0 = .75 * PI, a1 = 2.25 * PI, maj = 30, mn = 10, lab = [-60, 0, 60], t = "AMPS"}},
		{id = "hobbs", x = .355, y = .025, r = .027}]

## painted skin texture for a loft: u along the length (cosine-spaced stations), v around (theta / TAU)
func _uv_of(K: Array, z: float, th: float, W: int, H: int) -> Vector2:
	var z0: float = K[0][0]; var z1: float = K[-1][0]
	var t := acos(clampf(1.0 - 2.0 * (z - z0) / (z1 - z0), -1, 1)) / PI
	return Vector2(t * W, fposmod(th, TAU) / TAU * H)

func _livery(K: Array, tail: bool) -> StandardMaterial3D:
	var W := 2048; var H := 1024
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8); img.fill(Color(.93, .93, .915))
	var rng := RandomNumberGenerator.new(); rng.seed = 44 if not tail else 45
	var band := func(th0: float, th1: float, col: Color, z0: float, z1: float):
		for sd in [1, -1]:
			var a: float = th0 if sd > 0 else PI - th1; var b: float = th1 if sd > 0 else PI - th0
			var p0 := _uv_of(K, z0, a, W, H); var p1 := _uv_of(K, z1, b, W, H)
			img.fill_rect(Rect2i(int(minf(p0.x, p1.x)), int(minf(p0.y, p1.y)), int(absf(p1.x - p0.x)) + 1, int(absf(p1.y - p0.y)) + 1), col)
	var seam := func(z: float, th0: float, th1: float, both := true):
		for sd in ([1, -1] if both else [1]):
			var a: float = th0 if sd > 0 else PI - th1; var b: float = th1 if sd > 0 else PI - th0
			var p0 := _uv_of(K, z, a, W, H); var p1 := _uv_of(K, z, b, W, H)
			img.fill_rect(Rect2i(int(p0.x), int(minf(p0.y, p1.y)), 2, int(absf(p1.y - p0.y))), Color(.62, .63, .64))
			var y := minf(p0.y, p1.y)
			while y < maxf(p0.y, p1.y):
				img.fill_rect(Rect2i(int(p0.x) + 5, int(y), 2, 2), Color(.8, .8, .8)); y += 9
	var ring := func(th: float, z0: float, z1: float):
		for sd in [1, -1]:
			var a: float = th if sd > 0 else PI - th
			var p0 := _uv_of(K, z0, a, W, H); var p1 := _uv_of(K, z1, a, W, H)
			img.fill_rect(Rect2i(int(minf(p0.x, p1.x)), int(p0.y), int(absf(p1.x - p0.x)), 2), Color(.62, .63, .64))
	if not tail:
		# navy cheat-line with a thin red pinstripe below the windows, nose to tail
		band.call(-.36, -.2, Color("1e2c5a"), -2.3, .24); band.call(-.17, -.135, Color("a3121b"), -2.25, .24)
		for z in [-1.16, -.27, .05]: seam.call(z, -.55, -.06)
		ring.call(-.98, -2.2, .2); seam.call(-1.75, -1.3, -.4)
	else:
		band.call(-.36, -.2, Color("1e2c5a"), 1.25, 6.5); band.call(-.17, -.135, Color("a3121b"), 1.25, 6.5)
		var z := 1.6
		while z < 6.4:
			var p0 := _uv_of(K, z, 0, W, H)
			img.fill_rect(Rect2i(int(p0.x), 0, 2, H), Color(.66, .67, .68))
			var y := 0
			while y < H:
				img.fill_rect(Rect2i(int(p0.x) + 5, y, 2, 2), Color(.78, .78, .78)); y += 10
			z += .55
		img.fill_rect(Rect2i(0, int(H * .75), W, 2), Color(.66, .67, .68))
	# faint weathering: exhaust soot on the belly behind the engine, dust low down
	var nz := Gfx.noise_img(256, .03, 49, 4)
	nz.resize(W, H)
	for y in range(0, H, 4):
		var th := float(y) / H * TAU; var low := clampf(-sin(th), 0, 1)
		var a := low * low * .1
		if a > .005:
			for x in range(0, W, 4):
				var c := img.get_pixel(x, y).darkened(a * (.5 + nz.get_pixel(x, y).r))
				img.fill_rect(Rect2i(x, y, 4, 4), c)
	var m := StandardMaterial3D.new(); m.albedo_texture = Gfx.tex(img); m.roughness = .22; m.clearcoat_enabled = true; m.clearcoat = 1; m.clearcoat_roughness = .03
	m.normal_enabled = true; m.normal_texture = Gfx.nmap(img, 1.2); m.normal_scale = .6
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	return m

func _body() -> void:
	var cab_mask := func(z: float, th: float) -> int:
		var s := sin(th); var c := cos(th)
		if z < -1.2 and z > -2.34 and s > -.42 and absf(th - PI / 2) > .02: return 1
		if absf(c) > .42 and s > -.05 and s < .8 and ((z > -1.12 and z < -.30) or (z > -.24 and z < .02)): return 1
		return 0
	var cab := loft(CAB_K, 160, 128, {}, cab_mask)
	var o := mk(cab, null); o.set_surface_override_material(0, _livery(CAB_K, false)); o.set_surface_override_material(1, M.glass)
	var inn := mk(cab, null, 0, 0, 0, null, false); inn.set_surface_override_material(0, M.inner); inn.set_surface_override_material(1, _hide())
	# window / door frames following the cabin surface
	var fr := func(pts: PackedVector3Array): mk(Gfx.tube(pts, .011, 6), M.dark)
	var along := func(z0: float, z1: float, th: float) -> PackedVector3Array:
		var a := PackedVector3Array()
		for i in 25: a.append(sec_pt(CAB_K, z0 + (z1 - z0) * i / 24.0, th))
		return a
	var around := func(z: float, t0: float, t1: float, n := 24) -> PackedVector3Array:
		var a := PackedVector3Array()
		for i in n + 1: a.append(sec_pt(CAB_K, z, t0 + (t1 - t0) * i / float(n)))
		return a
	for z in [-1.16, -.27, .05]:
		fr.call(around.call(z, -.06, .93)); fr.call(around.call(z, PI - .93, PI + .06))
	for th in [-.05, .92, PI - .92, PI + .05]: fr.call(along.call(-1.16, .05, th))
	fr.call(around.call(-1.2, -.44, PI + .44, 48)); fr.call(along.call(-2.33, -1.2, PI / 2)); fr.call(along.call(-2.33, -1.2, -.44)); fr.call(along.call(-2.33, -1.2, PI + .44))
	# mast fairing / upper cowl, tail cone with registration
	mk(loft(COWL_K, 90, 72, COWL_O), M.paint)
	mk(loft([[1.25, .30, 1.74, 1.10], [6.5, .085, 1.71, 1.54]], 120, 48, {nx = 2, nt = 2, nb = 2, cf = .5}), _livery([[1.25, .30, 1.74, 1.10], [6.5, .085, 1.71, 1.54]], true))
	for sd in [-1, 1]:
		var lb := Label3D.new(); lb.text = "N744HF"; lb.font_size = 64; lb.pixel_size = .0042; lb.modulate = Color("1d2a5a"); lb.outline_size = 0
		lb.position = Vector3(sd * .215, 1.6, 3.45); lb.rotation = Vector3(0, sd * PI / 2, 0); lb.shaded = true; lb.double_sided = false
		model.add_child(lb)
		var band := Gfx.mat(Color("a3121b"), .3); band.clearcoat_enabled = true
		mk(Gfx.box(.012, .035, 1.6), band, sd * .3, 1.73, 2.1)
	mk(Gfx.sphere(.13, 16, 8, true), M.paint, .34, 1.55, .85).scale = Vector3(.35, .6, 1.1)
	mk(Gfx.sphere(.13, 16, 8, true), M.paint, -.34, 1.55, .85).scale = Vector3(.35, .6, 1.1)
	mk(Gfx.torus(.29, .012, 48, 8), M.steel, 0, 1.42, 1.27).rotation.x = PI / 2
	# engine: crankcase, 6 finned cylinders, exhausts, fan scroll
	var e := grp(model, 0, .98, .66)
	mk(Gfx.box(.34, .26, .78), M.eng, 0, 0, 0, e)
	for sd in [-1, 1]:
		for k in 3:
			var z = -.24 + k * .22 + sd * .05
			var c := mk(Gfx.cyl(.08, .08, .21, 16), M.eng, sd * .26, .02, z, e); c.rotation.z = PI / 2
			for f in 6: mk(Gfx.cyl(.095, .095, .006, 16), M.eng, sd * (.17 + f * .032), .02, z, e).rotation.z = PI / 2
			mk(Gfx.box(.1, .13, .12), M.eng, sd * .42, .02, z, e)
			mk(Gfx.tube(PackedVector3Array([Vector3(sd * .42, -.06, z), Vector3(sd * .4, -.2, z + .05), Vector3(sd * .3, -.28, .32), Vector3(sd * .2, -.3, .6)]), .022, 8), M.exh, 0, 0, 0, e)
	mk(Gfx.cyl(.34, .34, .18, 48), M.dark, 0, .05, -.48, e).rotation.x = PI / 2
	mk(Gfx.torus(.3, .09, 48, 12), M.eng, 0, 1.03, .13).rotation.x = PI / 2
	mk(Gfx.capsule(.11, .34), M.exh, 0, .58, 1.18).rotation.z = PI / 2
	# steel-tube frame
	var T := func(a: Vector3, b: Vector3, r := .022): mk(Gfx.line_tube(a, b, r, 8), M.steel)
	for s in [-1, 1]:
		T.call(Vector3(s * .5, 1.62, .2), Vector3(s * .22, 1.5, 1.25)); T.call(Vector3(s * .5, .72, .2), Vector3(s * .22, 1.25, 1.25)); T.call(Vector3(s * .5, 1.62, .2), Vector3(s * .5, .72, .2))
		T.call(Vector3(s * .5, 1.62, .2), Vector3(s * .08, 2.05, .05), .025); T.call(Vector3(s * .5, 1.62, .2), Vector3(s * .08, 2.05, -.35), .025)
	mk(Gfx.box(.95, .06, 1.2), M.paint, 0, .6, -.45)
	# skids and cross tubes
	for x in [-1.1, 1.1]:
		mk(Gfx.tube(PackedVector3Array([Vector3(x, .3, -2.0), Vector3(x, .14, -1.86), Vector3(x, .055, -1.6), Vector3(x, .05, -1), Vector3(x, .05, .4), Vector3(x, .05, 1.2), Vector3(x, .08, 1.33)]), .042, 12), M.steel)
		mk(Gfx.box(.04, .015, 2.3), M.dark, x, .01, -.2)
	for z in [-1.05, .55]:
		var pts := PackedVector3Array()
		for p in [[-1.1, .05], [-1.08, .3], [-.95, .55], [-.55, .62], [0, .63], [.55, .62], [.95, .55], [1.08, .3], [1.1, .05]]: pts.append(Vector3(p[0], p[1], z))
		mk(Gfx.tube(pts, .04, 12), M.steel)
	for x in [-.78, .78]: mk(Gfx.box(.32, .025, .16), M.dark, x, .6, -1.05)
	# lights
	var lt := func(c: Color, x: float, y: float, z: float) -> MeshInstance3D: return mk(Gfx.sphere(.02, 10, 6), Gfx.unshaded(c, 6), x, y, z, null, false)
	navL = [lt.call(Color(1, .13, .13), -.66, 1.2, -.9), lt.call(Color(.13, 1, .25), .66, 1.2, -.9), lt.call(Color.WHITE, 0, 1.62, 6.55)]
	strobeL = lt.call(Color(1, .06, .06), 0, 2.52, 6.4)
	ldg = SpotLight3D.new(); ldg.light_color = Color("fff4e0"); ldg.light_energy = 0; ldg.spot_range = 250; ldg.spot_angle = 20; ldg.position = Vector3(0, .75, -2.2)
	model.add_child(ldg); ldg.look_at_from_position(ldg.position, Vector3(0, -2, -12))
	mk(Gfx.cyl(.004, .008, .35, 6), M.black, 0, 2.12, -.9).rotation.x = -.5

func _hide() -> StandardMaterial3D:
	var m := StandardMaterial3D.new(); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.albedo_color = Color(0, 0, 0, 0); return m

func _rotor() -> void:
	mk(Gfx.cyl(.05, .058, 1.45, 24), M.chrome, 0, 2.4, 0)
	mk(Gfx.cyl(.098, .33, .47, 32), M.white, 0, 2.33, 0)
	mk(Gfx.torus(.098, .01, 32, 6), M.dark, 0, 2.57, 0)
	swash = grp(model, 0, 2.64, 0)
	mk(Gfx.cyl(.17, .175, .035, 40), M.steel, 0, 0, 0, swash); mk(Gfx.cyl(.085, .085, .07, 24), M.eng, 0, 0, 0, swash)
	for i in 3:
		var a := i * 2.09 + .5
		mk(Gfx.cyl(.011, .011, .42, 8), M.steel, cos(a) * .17, -.22, sin(a) * .17, swash)
	swR = grp(swash, 0, .035, 0)
	mk(Gfx.cyl(.15, .155, .03, 40), M.chrome, 0, 0, 0, swR)
	for s in [-1, 1]:
		mk(Gfx.box(.2, .03, .05), M.steel, s * .22, 0, -s * .11, swR).rotation.y = atan2(-s * .11, s * .22) * -1
		mk(Gfx.sphere(.018, 10, 6), M.chrome, s * .3, .02, -s * .15, swR)
	mk(Gfx.cyl(.075, .075, .06, 24), M.steel, 0, 2.94, 0)
	rTilt = grp(model, 0, 3.12, 0); rSpin = grp(rTilt)
	mk(Gfx.box(.16, .15, .2), M.steel, 0, 0, 0, rSpin)
	mk(Gfx.cyl(.045, .055, .07, 6), M.steel, 0, .105, 0, rSpin); mk(Gfx.sphere(.035, 12, 6, true), M.chrome, 0, .14, 0, rSpin)
	for s in [-1, 1]:
		mk(Gfx.box(.2, .07, .15), M.steel, s * .17, 0, 0, rSpin)
		mk(Gfx.box(.03, .13, .03), M.steel, s * .05, -.12, s * .09, rSpin)
	var bg := blade_geo(.24, 4.76, .254, .12, 90, 24, true, -.14)
	for k in 2:
		var az := grp(rSpin); az.rotation.y = k * PI
		var cone := grp(az, .27); var pit := grp(cone)
		mk(Gfx.cyl(.05, .055, .26, 16), M.steel, .13, 0, 0, pit).rotation.z = PI / 2
		mk(Gfx.box(.08, .05, .09), M.steel, .02, 0, 0, pit)
		mk(Gfx.box(.05, .025, .15), M.steel, .03, -.03, -.09, pit)
		for y in [-.028, .028]: mk(Gfx.box(.34, .012, .2), M.steel, .4, y, 0, pit)
		mk(bg, M.blade, 0, 0, 0, pit)
		blades.append({cone = cone, pit = pit})
		rod(.011, M.chrome, swR, Vector3(-.3 if k else .3, .02, .15 if k else -.15), pit, Vector3(.03, -.03, -.15))
	for s in [-1, 1]: rod(.012, M.steel, rSpin, Vector3(s * .05, -.18, s * .09), swR, Vector3(s * .09, .05, s * .1))
	blur = blur_disk(5.03, rTilt)

func _tail() -> void:
	mk(ext([[0, .04], [.42, 0], [.66, .84], [.44, .88]], .03), M.paint, 0, 1.6, 5.9)
	mk(ext([[.06, -.02], [.42, -.02], [.52, -.66], [.32, -.7]], .03), M.paint, 0, 1.6, 5.9)
	var pts := []
	var naca := func(x: float) -> float: return .6 * (.2969 * sqrt(x) - .126 * x - .3516 * x * x + .2843 * x * x * x - .1036 * x * x * x * x)
	for i in 25:
		var x := 1 - i / 24.0; pts.append([x * .34, naca.call(x) * .34])
	for i in range(1, 24):
		var x := i / 24.0; pts.append([x * .34, -naca.call(x) * .34])
	var stab := mk(ext(pts, .72), M.paint, .05, 1.48, 5.5)
	mk(Gfx.sphere(.1, 16, 10), M.paint, -.03, 1.64, 6.38).scale = Vector3(1, 1, 1.4)
	mk(Gfx.tube(PackedVector3Array([Vector3(0, .95, 6.05), Vector3(0, .82, 6.3), Vector3(0, .9, 6.62)]), .02, 8), M.steel)
	var trHub := grp(model, -.26, 1.70, 6.38); trSpin = grp(trHub)
	var tg := blade_geo(.1, .735, .1, .12, 32, 16, true, -.1)
	for s in [1, -1]:
		var b := mk(tg, M.blade, 0, 0, 0, trSpin); b.rotation.z = s * PI / 2
		mk(Gfx.box(.025, .16, .075), M.steel, 0, s * .13, 0, trSpin)
	mk(Gfx.box(.05, .12, .06), M.steel, 0, 0, 0, trSpin)
	mk(Gfx.cyl(.03, .04, .1, 12), M.steel, .07, 0, 0, trHub).rotation.z = PI / 2
	mk(Gfx.cyl(.075, .085, .17, 24), M.eng, -.1, 1.70, 6.38).rotation.z = PI / 2
	mk(Gfx.cyl(.045, .06, .2, 16), M.eng, -.02, 1.70, 6.22).rotation.x = PI / 2

func _cockpit() -> void:
	mk(Gfx.box(1.15, .04, 1.9), M.carpet, 0, .56, -.95, null, false)
	# seats: leather cushions with stitched tufts, 4-point harness with buckle
	var belt := Gfx.mat(Color("2a3140"), .85); var buckle: Material = M.chrome
	for x in [-.33, .33]:
		mk(Gfx.box(.5, .1, .5), M.dark, x, .63, -.5)
		mk(rbox(.47, .1, .45, .04), M.leather, x, .73, -.48)
		var bk := grp(model, x, 1.06, -.2); bk.rotation.x = -.12
		mk(rbox(.47, .6, .1, .04), M.leather, 0, 0, 0, bk)
		for yy in [-.15, .05, .2]: mk(Gfx.box(.4, .006, .012), M.black, 0, yy, .05, bk)
		mk(rbox(.3, .17, .08, .035), M.leather, 0, .38, .01, bk)
		for sd in [-1, 1]:
			var a := Vector3(x + sd * .11, 1.34, -.15); var b := Vector3(x + sd * .05, .84, -.55)
			mk(Gfx.line_tube(a, b, .022, 4), belt).scale = Vector3(1, 1, .25)
			mk(Gfx.line_tube(Vector3(x + sd * .22, .78, -.3), Vector3(x + sd * .04, .82, -.56), .022, 4), belt)
		mk(Gfx.cyl(.045, .045, .015, 16), buckle, x, .83, -.57).rotation.x = PI / 2
	mk(rbox(.34, .42, .6, .03), M.crinkle, 0, .78, -.7)
	# circuit breakers on the console top
	for i in 7:
		for j in 2:
			mk(Gfx.cyl(.007, .007, .014, 10), M.black, -.12 + i * .04, 1.0, -.88 + j * .05)
	var cbl := Label3D.new(); cbl.text = "CIRCUIT BREAKERS"; cbl.font_size = 24; cbl.pixel_size = .0007; cbl.position = Vector3(0, .995, -.94); cbl.rotation.x = -PI / 2; cbl.modulate = Color("cccccc"); cbl.outline_size = 0
	model.add_child(cbl)
	# cyclic T-bar
	cyc = grp(model, 0, .6, -.98)
	mk(Gfx.cyl(.022, .028, .44, 12), M.black, 0, .22, 0, cyc)
	mk(Gfx.cyl(.018, .018, .62, 12), M.black, .03, .44, 0, cyc).rotation.z = PI / 2
	for x in [-.27, .33]:
		mk(Gfx.cyl(.024, .022, .13, 16), M.rubber, x, .5, 0, cyc)
		mk(Gfx.sphere(.024, 12, 6, true), M.rubber, x, .565, 0, cyc)
		mk(Gfx.cyl(.007, .007, .012, 8), M.red, x + .012, .555, -.02, cyc).rotation.x = PI / 2
	mk(Gfx.cyl(.06, .03, .1, 16), M.rubber, 0, .03, 0, cyc)
	hit("cyc", Vector3(.12, .2, .12), .33, .48, 0, cyc)
	# collective + twist grip
	col = grp(model, .08, .66, -.18)
	mk(Gfx.cyl(.018, .022, .6, 12), M.black, 0, 0, -.3, col).rotation.x = PI / 2
	grip = grp(col, 0, 0, -.62)
	mk(Gfx.cyl(.027, .027, .13, 20), M.rubber, 0, 0, 0, grip).rotation.x = PI / 2
	for k in 5: mk(Gfx.torus(.027, .003, 20, 4), M.dark, 0, 0, -.05 + k * .025, grip)
	mk(rbox(.05, .04, .05, .01), M.anod, 0, .02, -.08, grip)
	mk(Gfx.box(.012, .02, .13), M.red, 0, .026, 0, grip)
	hit("coll", Vector3(.08, .08, .36), 0, 0, -.32, col); hit("twist", Vector3(.08, .08, .14), 0, 0, -.62, col)
	for x in [.24, .43]:
		var p := mk(rbox(.085, .13, .025, .008), M.rubber, x, .66, -1.5); p.rotation.x = -.5; peds.append(p)
		mk(Gfx.cyl(.012, .012, .12, 8), M.steel, x, .6, -1.47)
	for x in [-.24, -.43]:
		mk(rbox(.085, .13, .025, .008), M.rubber, x, .66, -1.5).rotation.x = -.5
		mk(Gfx.cyl(.012, .012, .12, 8), M.steel, x, .6, -1.47)
	hit("ped", Vector3(.3, .15, .1), .335, .66, -1.5, model)
	# instrument panel
	var panel := grp(model, 0, 1.2, -1.42); panel.rotation.x = -.27
	pdraw = R44Panel.new(); pdraw.heli = self; pdraw.PS = 1400
	panel_vp = panel_quad(.8, .42, 1400, panel, pdraw)
	mk(rbox(.86, .48, .2, .025), M.crinkle, 0, 0, -.101, panel)
	var hood := mk(rbox(.92, .035, .26, .016), M.crinkle, 0, .24, .04, panel); hood.rotation.x = .12
	for sx in [-.405, .405]:
		for sy in [-.2, .2]: screw(sx, sy, .002, panel, .0045)
	# magnetic compass on the glare shield
	var cmp := grp(panel, .0, .3, .03)
	mk(rbox(.07, .05, .05, .01), M.black, 0, 0, 0, cmp)
	mk(Gfx.box(.04, .022, .002), Gfx.mat(Color("d8d2c0"), .5), 0, 0, .026, cmp)
	mk(Gfx.box(.002, .022, .003), M.red, 0, 0, .027, cmp)
	var ped := grp(model, 0, .8, -1.36); ped.rotation.x = -.5
	var pd := R44Pedestal.new(); pd.heli = self; pd.PS = 1400
	ped_vp = panel_quad(.3, .4, 1400, ped, pd)
	mk(rbox(.33, .43, .3, .02), M.crinkle, 0, 0, -.151, ped)
	# switches
	for sw in SWX:
		var id: String = sw[0]; var p := grp(panel, sw[1], -.145, 0)
		mk(Gfx.cyl(.009, .009, .008, 16), M.chrome, 0, 0, .004, p).rotation.x = PI / 2
		var lev := grp(p, 0, 0, .008)
		mk(Gfx.cyl(.003, .0035, .024, 8), M.chrome, 0, 0, .012, lev).rotation.x = PI / 2
		mk(Gfx.sphere(.0045, 8, 4), M.chrome, 0, 0, .024, lev)
		SW[id] = lev
		if id == "clutch":
			mk(Gfx.box(.004, .03, .03), M.red, -.014, 0, .015, p); mk(Gfx.box(.004, .03, .03), M.red, .014, 0, .015, p)
		hit(id, Vector3(.045, .05, .04), 0, 0, .02, p)
	for g in GA:
		var rim := mk(Gfx.torus(g.r + .002, .0045, 48, 8), M.anod, g.x, g.y, .004, panel); rim.rotation.x = PI / 2
		gauge_glass(g.r, g.x, g.y, panel)
		hit(g.id, Vector3(g.r * 1.8, g.r * 1.8, .01), g.x, g.y, .009, panel)
	hit("ann", Vector3(.77, .036, .01), 0, .18, .006, panel)
	var keyG := grp(panel, .27, -.14, .005)
	mk(Gfx.cyl(.017, .019, .012, 20), M.chrome, 0, 0, 0, keyG).rotation.x = PI / 2
	keyB = grp(keyG); mk(Gfx.box(.012, .034, .008), M.chrome, 0, .004, .012, keyB)
	hit("key", Vector3(.06, .06, .04), 0, 0, .01, keyG)
	var knob := func(x: float, y: float, m: Material, id: String) -> Node3D:
		var g := grp(ped, x, y, 0)
		mk(Gfx.cyl(.004, .004, .06, 8), M.chrome, 0, 0, 0, g).rotation.x = PI / 2
		var k := grp(g, 0, 0, .012); mk(Gfx.cyl(.015, .015, .02, 16), m, 0, 0, 0, k).rotation.x = PI / 2
		hit(id, Vector3(.06, .06, .06), 0, 0, .02, g)
		return k
	mixK = knob.call(-.08, -.1, M.red, "mix"); carbK = knob.call(.08, -.1, M.black, "carb")
	fuelL = grp(ped, -.08, -.165, .01); mk(Gfx.box(.014, .05, .014), M.red, 0, .018, 0, fuelL); hit("fuelV", Vector3(.06, .06, .04), 0, 0, .01, fuelL)
	rbL = grp(ped, .08, -.165, .01); mk(Gfx.cyl(.006, .006, .04, 8), M.chrome, 0, 0, .02, rbL).rotation.x = PI / 2
	mk(Gfx.box(.05, .012, .012), M.red, 0, 0, .04, rbL); hit("rbrake", Vector3(.06, .06, .06), 0, 0, .02, rbL)

## small exterior parts: landing lights, door handles, hinges, antennas, cowling louvres, fuel cap, step plates
func _details() -> void:
	var nrm := func(z: float, th: float) -> Vector3:
		var p := sec_pt(CAB_K, z, th); var a := sec_pt(CAB_K, z + .02, th) - sec_pt(CAB_K, z - .02, th); var b := sec_pt(CAB_K, z, th + .02) - sec_pt(CAB_K, z, th - .02)
		var n := b.cross(a).normalized()
		return n if n.dot(p - Vector3(0, 1.2, p.z + .5)) > 0 else -n
	var place := func(mesh: Mesh, m: Material, z: float, th: float, out := 0.0) -> MeshInstance3D:
		var p := sec_pt(CAB_K, z, th); var n: Vector3 = nrm.call(z, th)
		var o := mk(mesh, m, p.x + n.x * out, p.y + n.y * out, p.z + n.z * out)
		o.look_at_from_position(o.position, o.position + n, Vector3.UP if absf(n.y) < .95 else Vector3.FORWARD)
		return o
	# twin landing lights in the nose
	var lens := Gfx.mat(Color("dfe6ee"), .05, .2); lens.emission_enabled = true; lens.emission = Color("fff4e0"); lens.emission_energy_multiplier = .2
	ldg_lens = lens
	for th in [-1.25, PI + 1.25]:
		var l: MeshInstance3D = place.call(Gfx.cyl(.045, .05, .02, 24), M.chrome, -2.31, th, .004); l.rotate_object_local(Vector3.RIGHT, PI / 2)
		var g: MeshInstance3D = place.call(Gfx.cyl(.038, .038, .012, 24), lens, -2.31, th, .012); g.rotate_object_local(Vector3.RIGHT, PI / 2)
	# door handles and hinges, both sides
	for th in [-.18, PI + .18]:
		for z in [-.42, .0]:
			place.call(rbox(.012, .02, .1, .005), M.chrome, z - .06, th, .012)
		for z in [-1.1, -.24]:
			for dy in [.25, -.05]:
				place.call(Gfx.cyl(.008, .008, .05, 8), M.steel, z + .04, th + dy, .004)
	# whip antenna on the tail cone, blade antenna under the belly, OAT probe
	mk(Gfx.cyl(.002, .005, .7, 6), M.black, 0, 2.08, 3.2).rotation.x = .35
	mk(rbox(.012, .14, .16, .005), M.dark, 0, .44, -1.0)
	mk(Gfx.cyl(.004, .004, .05, 6), M.chrome, .12, 1.95, -1.7).rotation.x = PI / 2
	# louvres on the mast fairing, fuel cap
	for sd in [-1, 1]:
		for k in 6:
			var lv := mk(rbox(.012, .1, .025, .005), M.black, sd * .37, 1.62, .55 + k * .07); lv.rotation.z = sd * .2
	mk(Gfx.cyl(.035, .035, .012, 20), M.chrome, -.3, 1.95, .2).rotation.z = .55
	# skid step plates (non-slip), skid shoes
	for x in [-1.1, 1.1]:
		mk(rbox(.12, .012, .22, .004), M.tread if M.has("tread") else M.steel, x * .95, .6, -1.05)
	# position lights on the stabiliser end plates
	mk(Gfx.box(.03, .12, .16), M.paint, .41, 1.48, 5.55)

## per-frame animation of rotors, controls and lights
func animate(dt: float, t: float) -> void:
	var F := sim; var S := sim.S; var C := sim.C
	var rr := F.Om / F.Om0
	ang += F.Om * dt; tra += F.Om * 5.95 * dt
	rSpin.rotation.y = ang; trSpin.rotation.x = tra; rTilt.rotation = Vector3(-F.a1, 0, -F.b1)
	(blur.material_override as StandardMaterial3D).albedo_color.a = U.sstep(.25, .9, rr) * .55
	for k in 2:
		var b: Dictionary = blades[k]; var ps := ang + k * PI
		b.cone.rotation.z = clampf(F.T / (F.MASS * 9.81), -.3, 1.5) * .035
		b.pit.rotation.x = (F.th if F.th else .012) + (C.cy * .1) * sin(ps) - (C.cx * .08) * cos(ps)
	swash.rotation = Vector3(-C.cy * .12, 0, -C.cx * .1); swash.position.y = 2.6 + C.coll * .06; swR.rotation.y = ang
	upd_rods()
	cyc.rotation = Vector3(-C.cy * .22, 0, -C.cx * .18); col.rotation.x = C.coll * .32 - .08; grip.rotation.z = S.thr * 1.2
	peds[0].position.z = -1.5 + C.ped * .07; peds[1].position.z = -1.5 - C.ped * .07
	for sw in SWX: SW[sw[0]].rotation.x = -.6 if S[sw[0]] else .6
	keyB.rotation.z = -(S.key - 2) * .5; mixK.position.z = .012 if S.mix else .045; carbK.position.z = .012 + S.carb * .035
	fuelL.rotation.z = 0.0 if S.fuelV else -PI / 2; rbL.position.z = .03 if S.rbrake else .01
	var el: bool = S.elec
	for l in navL: l.visible = el and S.nav
	strobeL.visible = el and S.strobe and fmod(t * 1.2, 1.0) < .08
	ldg.light_energy = 6.0 if (el and S.ldg) else 0.0
	if ldg_lens: ldg_lens.emission_energy_multiplier = 8.0 if (el and S.ldg) else .2

var _ped_on := -1
func redraw_panels() -> void:
	panel_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	pdraw.queue_redraw()
	var on := 1 if (sim.S.avion and sim.S.elec) else 0
	if on != _ped_on:
		_ped_on = on
		ped_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
		var pd: Control = ped_vp.get_child(0); pd.queue_redraw()

func cam_seat() -> Vector3: return Vector3(.33, .5, -.55)

# ---------------------------------------------------------------- panels
class R44Panel extends Gauges:
	func _draw() -> void:
		var h: R44 = heli; var F: Sim = h.sim; var S: Dictionary = F.S; var el: bool = S.elec
		draw_rect(Rect2(Vector2.ZERO, size), Color("24272b"))
		for g in h.GA: dial(g)
		var sw_lab := {avion = "AVIONICS", ldg = "LDG LT", nav = "NAV LT"}
		for sw in R44.SWX:
			txt(sw_lab.get(sw[0], sw[0].to_upper()), P2(sw[1], -.108), 15, Color("dddddd"))
		var k := P2(.27, -.14)
		var kl := ["OFF", "R", "L", "BOTH", "START"]
		for i in 5:
			var a := -PI / 2 + (i - 2) * .5; txt(kl[i], k + Vector2(cos(a), sin(a)) * 48, 13, Color("dddddd"))
		txt("IGNITION", k + Vector2(0, 48), 13, Color("dddddd"))
		draw_rect(Rect2(P2(-.385, .198), Vector2(.77 * PS, .036 * PS)), Color("555555"), false, 2)
		var e := Sim.euler_yxz(F.q); var hdg := fposmod(-rad_to_deg(e.y), 360.0); var vb := F.q.inverse() * (F.v - F.wind); var ias := maxf(0, -vb.z * 1.944)
		var G := {}
		for g in h.GA: G[g.id] = g
		var re := clampf(F.We / F.Om0, 0, 1)
		needle(G.tach, A(G.tach, clampf(F.We / F.Om0 * 100, 0, 110) if el else 0.0))
		needle(G.tach, A(G.tach, clampf(F.Om / F.Om0 * 100, 0, 110) if el else 0.0), .66, .07, Color("ffd166"))
		needle(G.asi, A(G.asi, 0.0 if ias < 15 else minf(150, ias)))
		var alt := F.p.y * 3.281
		needle(G.alt, A(G.alt, fmod(alt, 1000.0) / 100), .84, .04); needle(G.alt, A(G.alt, fmod(alt, 10000.0) / 1000), .52, .08)
		S.vsi += (F.v.y * 196.85 / 1000 - S.vsi) * .08; needle(G.vsi, A(G.vsi, clampf(S.vsi, -2, 2)))
		var amb := 29.92 * exp(-F.p.y / 8400); S.map = amb - (amb - amb * (.25 + .68 * S.frac)) * clampf(re * 2, 0, 1)
		needle(G.map, A(G.map, clampf(S.map, 10, 30)))
		needle(G.oilt, A(G.oilt, clampf(S.oilT, 50, 250) if el else 50.0)); needle(G.oilp, A(G.oilp, S.oilP if el else 0.0))
		needle(G.cht, A(G.cht, clampf(S.cht, 200, 500) if el else 200.0)); needle(G.cat, A(G.cat, clampf(S.carbT, -30, 30) if el else -30.0))
		needle(G.fuelm, A(G.fuelm, S.fuelM / 30 if el else 0.0)); needle(G.fuela, A(G.fuela, S.fuelA / 17 if el else 0.0)); needle(G.amm, A(G.amm, clampf(S.amps, -60, 60) if el else 0.0))
		attitude_w(G.ai, e.x if el else 0.0, -e.z if el else 0.0, el)
		compass(G.dg, hdg, el)
		var tm := Time.get_time_dict_from_system()
		digital(G.clk, ["OAT 15°C", "%02d:%02d" % [tm.hour, tm.minute], "%.1f V" % (14.1 if S.amps > 0 else 12.4 * minf(1, S.batQ + .6))], el)
		digital(G.hobbs, ["%.1f" % S.hobbs], el)
		var ANN := [["CLUTCH", "#ffb000", S.cm], ["ALT", "#ff3030", not (S.alt and S.running and F.We / F.Om0 > .5)], ["OIL", "#ff3030", S.oilP < 25], ["LOW FUEL", "#ff3030", S.fuelM < 3],
			["LOW RPM", "#ff3030", S.low], ["STARTER ON", "#ffb000", S.starter], ["GOV OFF", "#ffb000", not S.gov], ["ROTOR BRAKE", "#ffb000", S.rbrake], ["MR CHIP", "#ff3030", false], ["TR CHIP", "#ff3030", false]]
		for i in ANN.size():
			ann(-.381 + i * .0766, .194, .07, .028, ANN[i][0], Color(ANN[i][1]), el and ANN[i][2])

class R44Pedestal extends Gauges:
	func _draw() -> void:
		var h: R44 = heli; var S: Dictionary = h.sim.S; var on: bool = S.avion and S.elec
		draw_rect(Rect2(Vector2.ZERO, size), Color("1d1f22"))
		var sx := size.x / 420.0; var sy := size.y / 560.0
		var unit := func(y: float, hh: float, t: String, tx: String):
			draw_rect(Rect2(Vector2(14 * sx, y * sy), Vector2(392 * sx, hh * sy)), Color("0d0e10"))
			draw_rect(Rect2(Vector2(14 * sx, y * sy), Vector2(392 * sx, hh * sy)), Color("444444"), false)
			txt(t, Vector2(22 * sx, (y + 12) * sy), 12, Color("999999"), HORIZONTAL_ALIGNMENT_LEFT)
			if on: txt(tx, Vector2(90 * sx, (y + hh / 2) * sy), 26, Color("ffb347"), HORIZONTAL_ALIGNMENT_LEFT)
			draw_circle(Vector2(370 * sx, (y + hh / 2) * sy), 14, Color("2a2c30"))
		unit.call(14, 70, "COM/NAV", "122.850 ⇄ 121.500"); unit.call(94, 60, "XPDR", "1200   ALT"); unit.call(164, 46, "AUDIO", ""); unit.call(220, 120, "GPS", "")
		if on:
			draw_rect(Rect2(Vector2(70 * sx, 240 * sy), Vector2(280 * sx, 90 * sy)), Color("103018"))
			txt("GS 0 kt  TRK ---", Vector2(100 * sx, 262 * sy), 14, Color("44ff88"), HORIZONTAL_ALIGNMENT_LEFT)
		for l in [["MIXTURE", 98, 392], ["CARB HEAT", 322, 392], ["FUEL VALVE", 98, 482], ["ROTOR BRAKE", 322, 482]]: txt(l[0], Vector2(l[1] * sx, l[2] * sy), 14, Color("dddddd"))
		txt("PULL = CUT-OFF", Vector2(98 * sx, 452 * sy), 11, Color("ee4444")); txt("PULL = HOT", Vector2(322 * sx, 452 * sy), 11, Color("aaaaaa"))
		txt("ON ↑   OFF →", Vector2(98 * sx, 545 * sy), 11, Color("aaaaaa")); txt("PULL = ON", Vector2(322 * sx, 545 * sy), 11, Color("aaaaaa"))
