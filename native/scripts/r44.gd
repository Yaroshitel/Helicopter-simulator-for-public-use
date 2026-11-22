class_name R44 extends HeliBase
## Robinson R44 model, cockpit, instrument panel and controls catalogue.

var cyc: Node3D; var col: Node3D; var grip: Node3D; var peds: Array = []; var swash: Node3D; var swR: Node3D
var rTilt: Node3D; var rSpin: Node3D; var trSpin: Node3D; var blades: Array = []; var blur: MeshInstance3D
var SW := {}; var keyB: Node3D; var mixK: Node3D; var carbK: Node3D; var fuelL: Node3D; var rbL: Node3D
var navL: Array = []; var strobeL: MeshInstance3D; var ldg: SpotLight3D
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
	_gauges(); _body(); _rotor(); _tail(); _cockpit()

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

func _body() -> void:
	var cab_mask := func(z: float, th: float) -> int:
		var s := sin(th); var c := cos(th)
		if z < -1.2 and z > -2.34 and s > -.42 and absf(th - PI / 2) > .02: return 1
		if absf(c) > .42 and s > -.05 and s < .8 and ((z > -1.12 and z < -.30) or (z > -.24 and z < .02)): return 1
		return 0
	var cab := loft(CAB_K, 160, 128, {}, cab_mask)
	var o := mk(cab, null); o.set_surface_override_material(0, M.paint); o.set_surface_override_material(1, M.glass)
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
	mk(loft([[1.25, .30, 1.74, 1.10], [6.5, .085, 1.71, 1.54]], 120, 48, {nx = 2, nt = 2, nb = 2, cf = .5}), M.paint)
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
	mk(Gfx.box(1.15, .04, 1.9), M.dark, 0, .56, -.95, null, false)
	for x in [-.33, .33]:
		mk(Gfx.box(.48, .12, .46), M.seat, x, .74, -.48)
		mk(Gfx.box(.48, .62, .12), M.seat, x, 1.08, -.2).rotation.x = -.12
	mk(Gfx.box(.34, .42, .6), M.dark, 0, .78, -.7)
	# cyclic T-bar
	cyc = grp(model, 0, .6, -.98)
	mk(Gfx.cyl(.022, .028, .44, 12), M.black, 0, .22, 0, cyc)
	mk(Gfx.cyl(.018, .018, .62, 12), M.black, .03, .44, 0, cyc).rotation.z = PI / 2
	for x in [-.27, .33]: mk(Gfx.cyl(.022, .02, .13, 12), M.black, x, .5, 0, cyc)
	hit("cyc", Vector3(.12, .2, .12), .33, .48, 0, cyc)
	# collective + twist grip
	col = grp(model, .08, .66, -.18)
	mk(Gfx.cyl(.018, .022, .6, 12), M.black, 0, 0, -.3, col).rotation.x = PI / 2
	grip = grp(col, 0, 0, -.62)
	mk(Gfx.cyl(.026, .026, .13, 16), M.dark, 0, 0, 0, grip).rotation.x = PI / 2
	mk(Gfx.box(.012, .02, .13), M.red, 0, .026, 0, grip)
	hit("coll", Vector3(.08, .08, .36), 0, 0, -.32, col); hit("twist", Vector3(.08, .08, .14), 0, 0, -.62, col)
	for x in [.24, .43]:
		var p := mk(Gfx.box(.08, .12, .03), M.dark, x, .66, -1.5); p.rotation.x = -.5; peds.append(p)
	hit("ped", Vector3(.3, .15, .1), .335, .66, -1.5, model)
	# instrument panel
	var panel := grp(model, 0, 1.2, -1.42); panel.rotation.x = -.27
	pdraw = R44Panel.new(); pdraw.heli = self; pdraw.PS = 1400
	panel_vp = panel_quad(.8, .42, 1400, panel, pdraw)
	mk(Gfx.box(.84, .46, .2), M.dark, 0, 0, -.101, panel)
	mk(Gfx.box(.88, .03, .2), M.black, 0, .23, .04, panel).rotation.x = .12
	var ped := grp(model, 0, .8, -1.36); ped.rotation.x = -.5
	var pd := R44Pedestal.new(); pd.heli = self; pd.PS = 1400
	ped_vp = panel_quad(.3, .4, 1400, ped, pd)
	mk(Gfx.box(.32, .42, .3), M.dark, 0, 0, -.151, ped)
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
		var rim := mk(Gfx.torus(g.r + .002, .0045, 48, 6), M.black, g.x, g.y, .004, panel); rim.rotation.x = PI / 2
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

func redraw_panels() -> void:
	pdraw.queue_redraw()
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
