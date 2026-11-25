class_name Mi8 extends HeliBase
## Mil Mi-8MTV model, cockpit (main panel, centre console, overhead) and animation.

const K8 := [[-7.62, .05, 1.55, 1.32], [-7.52, .46, 1.95, .95], [-7.28, .83, 2.3, .72], [-6.88, 1.08, 2.6, .58], [-6.3, 1.21, 2.83, .52], [-5.6, 1.25, 2.94, .5], [-5.0, 1.26, 2.96, .5], [1.4, 1.26, 2.96, .5], [2.4, 1.22, 2.93, .6], [3.1, 1.05, 2.88, .95], [3.5, .75, 2.82, 1.6], [3.65, .5, 2.8, 2.0]]
const O8 := {nx = 3.4, nt = 2.4, nb = 4.0}
const PORTS := [-3.95, -2.75, -1.55, -.35, .85, 2.05]
const BLI := {cz = -5.8, cy = 2.18, hz = .41, hy = .45, e = 4.5, bul = .17}
const DOOR := {z0 = -4.5, z1 = -3.42, y0 = 1.0, y1 = 2.5}

## theta (left side) of the door's top and bottom edges on the fuselage section
func door_th() -> Array:
	var o := []
	for y in [DOOR.y1, DOOR.y0]:
		var a := PI / 2; var b := 1.5 * PI
		for i in 40:
			var m := (a + b) / 2
			if sec_pt(K8, (DOOR.z0 + DOOR.z1) / 2, m, O8).y > y: a = m
			else: b = m
		o.append((a + b) / 2)
	return o

var MM: Node3D; var rT: Node3D; var rS: Node3D; var bl: Array = []; var bz: MeshInstance3D; var sw: Node3D; var tS: Node3D
var sticks: Array = []; var col: Node3D; var grp_: Node3D; var pd: Array = []; var nav8: Array = []; var bcn: Array = []; var ldgs: Array = []
var cl: Array = []; var rbH: Node3D; var selK: Node3D; var apuS: StandardMaterial3D; var stB: StandardMaterial3D; var SW8: Array = []
var pn8_vp: SubViewport; var cn8_vp: SubViewport; var oh8_vp: SubViewport; var draws: Array = []
var G8: Array = []; var WIN: Array = []
var ang := 0.0; var tra := 0.0
var P8: StandardMaterial3D; var OL: StandardMaterial3D

func _init(s: Sim) -> void:
	sim = s; _init_mats(); name = "Mi8"
	model = Node3D.new(); model.position.y = -1.9; add_child(model); MM = model
	_mats(); _fuselage(); _engines(); _rotor(); _tail(); _gear(); _cockpit(); _details()

func _mats() -> void:
	var W := 2048; var H := 1024; var rng := RandomNumberGenerator.new(); rng.seed = 8
	var img := Image.create(W, H, false, Image.FORMAT_RGBA8); img.fill(Color("4f555a"))
	var ell := func(cx: float, cy: float, rx: float, ry: float, c: Color):
		for y in range(maxi(0, int(cy - ry)), mini(H, int(cy + ry) + 1)):
			var dy := (y - cy) / ry
			if absf(dy) > 1: continue
			var hw := rx * sqrt(1 - dy * dy)
			var x0 := int(cx - hw); var x1 := int(cx + hw)
			for xx in [x0, x0 + W, x0 - W]:
				var a: int = maxi(0, xx); var b: int = mini(W, xx + (x1 - x0))
				if b > a: img.fill_rect(Rect2i(a, y, b - a, 1), c)
	# plain dark-grey military finish (Mi-8MTV), very subtle tonal variation and panel seams
	for i in 60:
		var t := (rng.randf() - .5) * .035
		ell.call(rng.randf() * W, rng.randf() * H, 80 + rng.randf() * 220, 40 + rng.randf() * 120, Color("4f555a").lightened(t) if t > 0 else Color("4f555a").darkened(-t))
	for u in range(0, W, 96):
		img.fill_rect(Rect2i(u, 0, 1, H), Color("3f4448"))
		for y in range(0, H, 7): img.fill_rect(Rect2i(u + 3, y, 2, 2), Color("5c6267"))
	for v in [.1, .22, .3, .62, .7, .8, .86, .93]:
		img.fill_rect(Rect2i(0, int((1 - v) * H), W, 1), Color("3f4448"))
		for x in range(0, W, 7): img.fill_rect(Rect2i(x, int((1 - v) * H) + 3, 2, 2), Color("5c6267"))
	# left sliding door (with rails added in 3D), rear clamshell door split
	var seam := func(z0: float, th0: float, z1: float, th1: float):
		var n := 80
		for i in n + 1:
			var t := float(i) / n
			var q := uv_of(K8, lerpf(z0, z1, t), lerpf(th0, th1, t), W, H)
			img.fill_rect(Rect2i(int(q.x), int(q.y), 3, 3), Color("2c3034"))
	var tt := door_th()
	seam.call(DOOR.z0, tt[0], DOOR.z1, tt[0]); seam.call(DOOR.z0, tt[1], DOOR.z1, tt[1]); seam.call(DOOR.z0, tt[0], DOOR.z0, tt[1]); seam.call(DOOR.z1, tt[0], DOOR.z1, tt[1])
	seam.call(2.25, 1.5 * PI, 3.64, 1.5 * PI); seam.call(2.25, 1.12 * PI, 2.25, 1.88 * PI)
	# exhaust soot along the upper sides behind the engines, dusty belly
	var nz := Gfx.noise_img(256, .02, 81, 4); nz.resize(W, H)
	for y in range(0, H, 4):
		var th := float(y) / H * TAU
		for x in range(0, W, 4):
			var u := float(x) / W; var z := lerpf(-7.62, 3.65, .5 - .5 * cos(PI * u))
			var a := 0.0
			var up := sin(th)
			if z > -1.2 and up > .45 and up < .95: a = .35 * U.sstep(-1.2, .2, z) * (1 - U.sstep(2.0, 3.6, z)) * (.5 + nz.get_pixel(x, y).r)
			if up < -.5: a = maxf(a, .12 * (-up - .5) * 2 * nz.get_pixel(x, y).r)
			if a > .01: img.fill_rect(Rect2i(x, y, 4, 4), img.get_pixel(x, y).darkened(a))
	P8 = StandardMaterial3D.new(); P8.albedo_texture = Gfx.tex(img); P8.roughness = .62; P8.normal_enabled = true; P8.normal_texture = Gfx.nmap(img, 1.2); P8.normal_scale = .7
	P8.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC; P8.clearcoat_enabled = true; P8.clearcoat = .15; P8.clearcoat_roughness = .5
	OL = Gfx.mat(Color("4b5156"), .62, .05)
	M.rub = Gfx.mat(Color("141414"), .92); M.soot = Gfx.mat(Color("2e2f30"), .6, .6); M.soot.cull_mode = BaseMaterial3D.CULL_DISABLED; M.gm = Gfx.mat(Color("6d756a"), .45, .7)
	var g := StandardMaterial3D.new(); g.albedo_color = Color(.15, .24, .28, .7); g.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; g.roughness = .04; g.metallic = .55; g.cull_mode = BaseMaterial3D.CULL_BACK
	M.g8 = g
	var gi := StandardMaterial3D.new(); gi.albedo_color = Color(.62, .7, .72, .1); gi.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gi.roughness = .05; gi.cull_mode = BaseMaterial3D.CULL_FRONT
	M.g8i = gi
	M.inner8 = StandardMaterial3D.new(); M.inner8.albedo_color = Color("6c8580"); M.inner8.roughness = .9; M.inner8.cull_mode = BaseMaterial3D.CULL_FRONT
	M.inner8.normal_enabled = true; M.inner8.normal_texture = M.crinkle.normal_texture; M.inner8.uv1_scale = Vector3(60, 60, 1)
	var pc := M.crinkle.duplicate() as StandardMaterial3D; pc.albedo_color = Color("3e676a"); M.pan8 = pc
	M.wall = Gfx.mat(Color("4e6e70"), .8, .05); M.tread = Gfx.mat(Color("8f9396"), .45, .8); M.panel = Gfx.mat(Color("3e676a"), .7)

# ---------- glazing geometry helpers (ported) ----------
func sec8(z: float) -> Dictionary:
	var hw := maxf(cr(K8, z, 1), .002); var yt := cr(K8, z, 2); var yb := cr(K8, z, 3)
	return {hw = hw, yt = yt, yb = yb, yc = yb + .42 * (yt - yb)}
func nY8(s: Dictionary, y: float) -> Array:
	return [(y - s.yc) / (s.yt - s.yc), O8.nt] if y >= s.yc else [(s.yc - y) / (s.yc - s.yb), O8.nb]
func in_sec8(z: float, x: float, y: float) -> bool:
	var s := sec8(z); var ne := nY8(s, y)
	return pow(absf(x) / s.hw, O8.nx) + pow(maxf(ne[0], 0), ne[1]) < 1
func front_z(x: float, y: float) -> float:
	var a := -7.62; var b := -4.9
	for i in 30:
		var m := (a + b) / 2
		if in_sec8(m, x, y): b = m
		else: a = m
	return b
func side_x(z: float, y: float) -> float:
	var s := sec8(z); var ne := nY8(s, y)
	return s.hw * pow(maxf(0, 1 - pow(clampf(ne[0], 0, 1), ne[1])), 1 / O8.nx)
static func rpoly(pts: Array, r: float, n := 6) -> Array:
	var o := []
	for i in pts.size():
		var a: Array = pts[(i + pts.size() - 1) % pts.size()]; var p: Array = pts[i]; var b: Array = pts[(i + 1) % pts.size()]
		var u := Vector2(a[0] - p[0], a[1] - p[1]); var v := Vector2(b[0] - p[0], b[1] - p[1])
		var k := minf(r, minf(u.length() * .45, v.length() * .45))
		var A := Vector2(p[0], p[1]) + u.normalized() * k; var B := Vector2(p[0], p[1]) + v.normalized() * k; var P := Vector2(p[0], p[1])
		for j in n + 1:
			var t := float(j) / n; var q := (1 - t) * (1 - t) * A + 2 * t * (1 - t) * P + t * t * B; o.append([q.x, q.y])
	return o
static func sell(cx: float, cy: float, hx: float, hy: float, e := 4.0, n := 48, k := 1.0) -> Array:
	var o := []
	for i in n:
		var a := float(i) / n * TAU; var c := cos(a); var s := sin(a)
		o.append([cx + k * hx * signf(c) * pow(absf(c), 2 / e), cy + k * hy * signf(s) * pow(absf(s), 2 / e)])
	return o
static func in_p(P: Array, x: float, y: float) -> bool:
	var c := false; var j := P.size() - 1
	for i in P.size():
		var xi: float = P[i][0]; var yi: float = P[i][1]; var xj: float = P[j][0]; var yj: float = P[j][1]
		if (yi > y) != (yj > y) and x < (xj - xi) * (y - yi) / (yj - yi) + xi: c = not c
		j = i
	return c
func w3(w: Dictionary, sd: int, a: float, b: float) -> Vector3:
	return Vector3(sd * a, b, front_z(a, b)) if w.f else Vector3(sd * side_x(a, b), b, a)

func _fuselage() -> void:
	WIN = [{f = true, P = rpoly([[.06, 1.8], [.86, 1.8], [.97, 2.42], [.06, 2.56]], .08)}, {f = true, P = rpoly([[.09, 2.65], [.83, 2.53], [.71, 2.78], [.09, 2.84]], .05)},
		{f = false, P = rpoly([[-6.93, 1.78], [-6.31, 1.78], [-6.31, 2.46]], .06)}, {f = false, P = sell(BLI.cz, BLI.cy, BLI.hz, BLI.hy, BLI.e)}]
	var yc := []
	for j in 201: yc.append(sec_pt(K8, -2, -PI / 2 + j / 200.0 * PI, O8).y)
	var ycab := func(th: float) -> float:
		var s := asin(sin(th)); return yc[clampi(roundi((s + PI / 2) / PI * 200), 0, 200)]
	var mask := func(z: float, th: float) -> int:
		var c := cos(th)
		if z < -5.3:
			var p := sec_pt(K8, z, th, O8); var ax := absf(p.x)
			for w in WIN:
				if w.f:
					if in_p(w.P, ax, p.y) and p.z < front_z(ax, p.y) + .06: return 1
				elif in_p(w.P, p.z, p.y): return 1
			return 0
		if absf(c) > .6 and z > -4.3 and z < 2.4:
			var y: float = ycab.call(th)
			for pz in PORTS:
				if (z - pz) * (z - pz) + (y - 2.02) * (y - 2.02) < .04: return 1
		return 0
	var fus := loft(K8, 260, 160, O8, mask)
	var o := mk(fus, null); o.set_surface_override_material(0, P8); o.set_surface_override_material(1, M.g8)
	var i2 := mk(fus, null, 0, 0, 0, null, false); i2.set_surface_override_material(0, M.inner8); i2.set_surface_override_material(1, M.g8i)
	# pane frames
	for w in WIN:
		var cx := 0.0; var cy := 0.0
		for p in w.P: cx += p[0]; cy += p[1]
		cx /= w.P.size(); cy /= w.P.size()
		for sd in [1, -1]:
			var pts := PackedVector3Array()
			for p in w.P:
				var d := Vector2(p[0] - cx, p[1] - cy).length()
				pts.append(w3(w, sd, p[0] + (cx - p[0]) / d * -.012, p[1] + (cy - p[1]) / d * -.012))
			mk(Gfx.tube(pts, .034, 6, true), OL, 0, 0, 0, null, false)
	# sliding blisters
	for sd in [1, -1]:
		var NR := 8; var NA := 40; var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		var rings := []
		for i in NR + 1:
			var r := float(i) / NR; var ring := []
			for p in sell(BLI.cz, BLI.cy, BLI.hz, BLI.hy, BLI.e, NA, r):
				ring.append(Vector3(sd * (side_x(p[0], p[1]) + BLI.bul * sqrt(maxf(0, 1 - pow(r, 2.5)))), p[1], p[0]))
			rings.append(ring)
		for i in NR:
			for j in NA:
				var a: Vector3 = rings[i][j]; var b: Vector3 = rings[i][(j + 1) % NA]; var c: Vector3 = rings[i + 1][j]; var d: Vector3 = rings[i + 1][(j + 1) % NA]
				var tri := [a, c, b, b, c, d] if sd > 0 else [a, b, c, b, d, c]
				for v in tri: st.add_vertex(v)
		st.generate_normals()
		var bm := st.commit()
		mk(bm, M.g8, 0, 0, 0, null, false)
		var rim := PackedVector3Array()
		for p in sell(BLI.cz, BLI.cy, BLI.hz, BLI.hy, BLI.e, NA): rim.append(Vector3(sd * (side_x(p[0], p[1]) + .015), p[1], p[0]))
		mk(Gfx.tube(rim, .045, 6, true), OL)
	# pitot tubes and wipers
	for sd in [1, -1]:
		mk(Gfx.cyl(.012, .02, .6, 8), M.chrome, sd * .68, 1.62, front_z(.62, 1.62) - .2).rotation.x = PI / 2
		var a := w3(WIN[0], sd, .5, 1.84) + Vector3(0, .02, -.03); var b := w3(WIN[0], sd, .84, 2.06) + Vector3(0, .02, -.03)
		mk(Gfx.line_tube(a, b, .009, 6), M.black)
	# porthole rims
	var ty := 0.0
	var a0 := -1.2; var b0 := 1.4
	for i in 30:
		var m := (a0 + b0) / 2
		if sec_pt(K8, -2, m, O8).y < 2.02: a0 = m
		else: b0 = m
	ty = (a0 + b0) / 2
	for pz in PORTS:
		for sd in [1, -1]:
			var p := sec_pt(K8, pz, ty if sd > 0 else PI - ty, O8)
			var t := mk(Gfx.torus(.205, .026, 32, 8), M.dark, p.x, p.y, p.z); t.rotation.z = PI / 2

func _engines() -> void:
	var KE := [[-4.7, .05, 3.25, 3.05], [-4.5, .78, 3.68, 2.86], [-4.0, .95, 3.86, 2.86], [0, .98, 3.92, 2.86], [1.8, .92, 3.82, 2.86], [2.8, .62, 3.55, 2.88], [3.15, .04, 3.15, 2.95]]
	mk(loft(KE, 120, 80, {nx = 3, nt = 2.6, nb = 5, cf = .3}), P8)
	for sd in [-1, 1]:
		var x = sd * .42
		mk(Gfx.torus(.27, .05, 32, 8), M.steel, x, 3.32, -4.62).rotation.x = PI / 2
		var d := mk(Gfx.sphere(.42, 32, 12, true), M.gm, x, 3.32, -4.7); d.rotation.x = -PI / 2; d.scale = Vector3(1, .75, 1)
		mk(Gfx.torus(.42, .03, 32, 6), M.steel, x, 3.32, -4.68).rotation.x = PI / 2
		mk(Gfx.tube(PackedVector3Array([Vector3(sd * .7, 3.28, -1.0), Vector3(sd * 1.0, 3.3, -1.15), Vector3(sd * 1.27, 3.18, -.92), Vector3(sd * 1.4, 3.06, -.5)]), .2, 16), M.soot)
		for k in 4: mk(Gfx.box(.1, .03, .05), M.steel, sd * .93, 3.45, -3.6 + k * 1.4)
	var fan := mk(Gfx.torus(.38, .05, 32, 8), M.steel, 0, 3.62, 2.55); fan.rotation.x = -.9 + PI / 2
	var fd := mk(Gfx.cyl(.37, .37, .01, 32), M.black, 0, 3.6, 2.52); fd.rotation.x = -.9 + PI / 2
	mk(Gfx.sphere(.72, 32, 12), OL, 0, 3.86, .1).scale = Vector3(1, .45, 1.35)
	mk(Gfx.cyl(.09, .11, .3, 16), M.soot, 1.05, 3.55, 1.4).rotation.z = PI / 2

func _rotor() -> void:
	mk(Gfx.cyl(.15, .19, .75, 32), M.steel, 0, 4.12, 0)
	sw = grp(MM, 0, 4.0, 0)
	mk(Gfx.cyl(.44, .46, .05, 40), M.steel, 0, 0, 0, sw); mk(Gfx.cyl(.4, .43, .05, 40), M.dark, 0, .055, 0, sw)
	rT = grp(MM, 0, 4.45, 0); rS = grp(rT)
	# hub: forged body, lower flange, top cap
	mk(Gfx.cyl(.27, .3, .36, 32), M.steel, 0, 0, 0, rS)
	mk(Gfx.cyl(.33, .33, .05, 32), M.steel, 0, -.18, 0, rS)
	mk(Gfx.cyl(.2, .26, .08, 32), M.steel, 0, .22, 0, rS)
	mk(Gfx.sphere(.2, 24, 10, true), M.steel, 0, .26, 0, rS).scale = Vector3(1, .45, 1)
	var bg := blade_geo(.05, 9.75, .53, .12, 120, 20, true, -.09, Color(.45, .46, .48))
	for k in 5:
		var az := grp(rS); az.rotation.y = k * TAU / 5
		# arm, flapping-hinge yoke and pin
		mk(Gfx.box(.52, .15, .2), M.steel, .48, 0, 0, az)
		for z in [-.1, .1]: mk(Gfx.box(.16, .2, .04), M.steel, .8, 0, z, az)
		mk(Gfx.cyl(.03, .03, .26, 10), M.dark, .8, 0, 0, az).rotation.x = PI / 2
		# hydraulic lag damper and pitch link
		mk(Gfx.line_tube(Vector3(.3, .09, .14), Vector3(1.0, .05, .17), .035, 10), M.dark, 0, 0, 0, az)
		mk(Gfx.cyl(.018, .018, .32, 8), M.steel, .42, -.23, -.14, az)
		var cone := grp(az, .9); var pit := grp(cone)
		var b := mk(bg, M.blade, 0, 0, 0, pit); b.rotation.x = PI
		# pitch housing (axial hinge) with horn
		mk(Gfx.cyl(.09, .1, .5, 16), M.steel, .25, 0, 0, pit).rotation.z = PI / 2
		mk(Gfx.cyl(.07, .09, .12, 16), M.steel, .55, 0, 0, pit).rotation.z = PI / 2
		mk(Gfx.box(.06, .04, .16), M.steel, .12, -.04, -.14, pit)
		bl.append({cone = cone, pit = pit})
	bz = blur_disk(10.645, rT)

func _tail() -> void:
	mk(loft([[3.0, .66, 3.25, 1.9], [9.9, .31, 3.0, 2.42], [10.3, .28, 3.02, 2.48]], 120, 48, {nx = 2, nt = 2, nb = 2, cf = .5}), P8)
	mk(Gfx.line_tube(Vector3(0, 3.22, 3.1), Vector3(0, 3.03, 9.9), .1, 12), OL)
	mk(ext([[9.45, 2.6], [10.4, 2.55], [10.95, 4.7], [10.72, 4.9], [10.32, 4.85], [9.95, 3.25]], .26), P8)
	mk(Gfx.box(.42, .5, .75), OL, 0, 2.85, 9.75)
	mk(Gfx.box(.8, .09, 1.1), OL, 0, 2.06, 5.6)
	var p := []
	var na := func(x: float) -> float: return .6 * (.2969 * sqrt(x) - .126 * x - .3516 * x * x + .2843 * x * x * x - .1036 * x * x * x * x)
	for i in 33:
		var x := 1 - i / 32.0; p.append([8.6 + x * .9, 2.32 + na.call(x) * .9])
	for i in range(1, 32):
		var x := i / 32.0; p.append([8.6 + x * .9, 2.32 - na.call(x) * .9])
	mk(ext(p, 2.9), P8)
	mk(Gfx.sphere(.24, 16, 10), OL, -.1, 4.6, 10.65).scale = Vector3(1, 1, 1.3)
	var tH := grp(MM, -.42, 4.6, 10.62); tS = grp(tH)
	var tg := blade_geo(.25, 1.954, .27, .12, 32, 12, true, -.1, Color(.45, .46, .48))
	for k in 3:
		var g := grp(tS); g.rotation.x = k * TAU / 3
		var b := mk(tg, M.blade, 0, 0, 0, g); b.rotation.z = PI / 2
	mk(Gfx.cyl(.13, .13, .16, 16), M.steel, 0, 0, 0, tS).rotation.z = PI / 2
	mk(Gfx.tube(PackedVector3Array([Vector3(0, 2.35, 9.5), Vector3(0, 1.08, 9.95), Vector3(0, 1.0, 10.35), Vector3(0, 1.6, 10.62)]), .045, 8), M.steel)

func _gear() -> void:
	var tire := func(r: float, t: float, x: float, y: float, z: float):
		mk(Gfx.torus(r, t, 32, 10), M.rub, x, y, z).rotation.z = PI / 2
		mk(Gfx.cyl(r * .78, r * .78, t * 1.8, 24), M.steel, x, y, z).rotation.z = PI / 2
		mk(Gfx.cyl(r * .3, r * .3, t * 2.1, 12), M.dark, x, y, z).rotation.z = PI / 2
	for sd in [-1, 1]: tire.call(.22, .085, sd * .17, .3, -3.6)
	mk(Gfx.cyl(.06, .07, .85, 12), M.chrome, 0, .78, -3.6); mk(Gfx.cyl(.085, .085, .4, 12), OL, 0, 1.0, -3.6); mk(Gfx.box(.5, .08, .12), M.steel, 0, .3, -3.6)
	var tub := func(a: Vector3, b: Vector3, r: float, m: Material = M.steel): mk(Gfx.line_tube(a, b, r, 8), m)
	for sd in [-1, 1]:
		tire.call(.33, .12, sd * 2.25, .45, .65)
		tub.call(Vector3(sd * 2.12, .5, .65), Vector3(sd * 1.75, 1.3, .65), .06, M.chrome); tub.call(Vector3(sd * 1.75, 1.3, .65), Vector3(sd * 1.4, 1.95, .65), .085, OL)
		tub.call(Vector3(sd * 2.15, .47, .65), Vector3(sd * 1.12, .62, 1.25), .055); tub.call(Vector3(sd * 2.15, .47, .65), Vector3(sd * 1.12, .62, .05), .055)
		var tk := mk(Gfx.capsule(.42, 2.6), OL, sd * 1.62, 1.28, -1.2); tk.rotation.x = PI / 2; tk.scale = Vector3(.9, 1, 1)
		for z in [-2, -.4]: tub.call(Vector3(sd * 1.3, 1.5, z), Vector3(sd * 1.22, 1.75, z), .03)
	var lt := func(c: Color, x: float, y: float, z: float, r := .05) -> MeshInstance3D: return mk(Gfx.sphere(r, 10, 6), Gfx.unshaded(c, 6), x, y, z, null, false)
	nav8 = [lt.call(Color(1, .13, .13), -1.62, 1.28, -2.75), lt.call(Color(.13, 1, .25), 1.62, 1.28, -2.75), lt.call(Color.WHITE, 0, 2.6, 10.3)]
	bcn = [lt.call(Color(1, .06, .06), 0, 3.12, 5.0, .09), lt.call(Color(1, .06, .06), 0, .46, -.6, .09)]
	for x in [-.4, .4]:
		mk(Gfx.cyl(.11, .11, .06, 16), M.chrome, x, .6, -6.3)
		var s := SpotLight3D.new(); s.light_color = Color("fff4e0"); s.light_energy = 0; s.spot_range = 300; s.spot_angle = 18; s.position = Vector3(x, .55, -6.3)
		MM.add_child(s); s.look_at_from_position(s.position, Vector3(x, -3, -20)); ldgs.append(s)

func _cockpit() -> void:
	mk(Gfx.box(2.2, .05, 2.3), M.tread, 0, .95, -5.9, null, false)
	var togm := Gfx.merge([[Gfx.cyl(.008, .008, .006, 10), Gfx.xf(Vector3(0, .003, 0))], [Gfx.cyl(.0025, .003, .022, 6), Gfx.xf(Vector3(0, .014, 0), Vector3(.5, 0, 0))], [Gfx.sphere(.004, 8, 4), Gfx.xf(Vector3(0, .024, .006))]])
	var knob := Gfx.merge([[Gfx.cyl(.012, .014, .016, 14), Gfx.xf(Vector3(0, .008, 0))], [Gfx.box(.004, .004, .02), Gfx.xf(Vector3(0, .017, 0))]])
	for sd in [-1, 1]:
		mk(rbox(.32, .34, 1.2, .03), M.pan8, sd * 1.0, 1.26, -5.65)
		var T := []; var Kn := []
		for i in 9:
			for j in 3:
				var q := {x = sd * 1.0 + (j - 1) * .08, y = 1.43, z = -6.15 + i * .11}
				if (i + j) % 4 == 3: Kn.append(q)
				else: T.append(q)
		Gfx.multi(MM, togm, M.chrome, T, false); Gfx.multi(MM, knob, M.black, Kn, false)
	var armor := Gfx.mat(Color("4a5a50"), .6, .5)
	for x in [-.55, .55]:
		mk(rbox(.56, .1, .52, .04), M.dark, x, 1.27, -5.25)
		mk(rbox(.52, .12, .48, .05), M.leather, x, 1.36, -5.25)
		var bk := grp(MM, x, 1.8, -4.97); bk.rotation.x = -.1
		mk(rbox(.52, .76, .1, .05), M.leather, 0, 0, 0, bk)
		for yy in [-.2, 0, .2]: mk(Gfx.box(.44, .008, .012), M.black, 0, yy, .05, bk)
		mk(rbox(.6, 1.0, .03, .012), armor, 0, .1, -.08, bk)
		mk(rbox(.3, .18, .09, .04), M.leather, x, 2.32, -4.94)
		for sd in [-1, 1]:
			mk(Gfx.line_tube(Vector3(x + sd * .12, 2.2, -4.98), Vector3(x + sd * .06, 1.45, -5.45), .025, 4), Gfx.mat(Color("3a4a3c"), .85)).scale = Vector3(1, 1, .3)
	# cockpit rear bulkhead: follows the fuselage section, with a doorway to the cabin
	var zb := -4.55; var outl := []
	for i in 64:
		var q := sec_pt(K8, zb, i / 64.0 * TAU, O8); outl.append(Vector2(q.x * .96, 1.0 + (q.y - 1.0) * .96))
	for sd in [1, -1]:
		var half := []
		for q in outl:
			if sd * q.x > 0 and q.y > .95: half.append(q)
		half.sort_custom(func(a, b): return atan2(a.y - 1.9, sd * a.x) > atan2(b.y - 1.9, sd * b.x))
		var poly := PackedVector2Array([Vector2(0, 2.55)])
		for q in half: poly.append(q)
		poly.append(Vector2(sd * .45, .95)); poly.append(Vector2(sd * .45, 2.55))
		var tri := Geometry2D.triangulate_polygon(poly)
		if tri.is_empty(): poly.reverse(); tri = Geometry2D.triangulate_polygon(poly)
		var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
		for f in [.025, -.025]:
			for k in range(0, tri.size(), 3):
				var ids := [tri[k], tri[k + 1], tri[k + 2]] if (f > 0) == (sd > 0) else [tri[k], tri[k + 2], tri[k + 1]]
				for ii in ids: st.add_vertex(Vector3(poly[ii].x, poly[ii].y, zb + f))
		st.generate_normals(); mk(st.commit(), M.wall, 0, 0, 0, null, false)
	mk(Gfx.cyl(.07, .07, .45, 12), M.red, .75, 1.28, -4.72)
	# cargo cabin floor + troop seats
	mk(Gfx.box(2.3, .06, 7.0), M.tread, 0, .78, -.95, null, false)
	var seat := Gfx.mat(Color("3b4a5a"), .85, .05)
	var L := []
	for sd in [-1, 1]:
		for i in 12: L.append({x = sd * .92, y = 1.25, z = -3.75 + i * .5})
	Gfx.multi(MM, Gfx.box(.38, .04, .42), seat, L)
	var light := OmniLight3D.new(); light.light_color = Color("fff0d8"); light.light_energy = .6; light.omni_range = 9; light.position = Vector3(0, 2.6, -1); MM.add_child(light)
	# controls
	for x in [-.55, .55]:
		var g := grp(MM, x, .97, -5.85)
		mk(Gfx.cyl(.022, .03, .64, 12), M.black, 0, .32, 0, g)
		mk(rbox(.065, .16, .075, .025), M.rubber, 0, .71, 0, g)
		mk(Gfx.cyl(.008, .008, .02, 8), M.red, .0, .79, -.03, g).rotation.x = PI / 2
		mk(rbox(.022, .012, .02, .005), M.chrome, -.03, .76, -.02, g)
		mk(Gfx.cyl(.09, .05, .12, 16), M.rubber, 0, .06, 0, g)
		sticks.append(g)
	hit("cyc", Vector3(.14, .25, .14), 0, .62, 0, sticks[0])
	col = grp(MM, -.95, 1.2, -5.15)
	mk(Gfx.cyl(.025, .03, .72, 12), M.black, 0, 0, -.36, col).rotation.x = PI / 2
	grp_ = grp(col, 0, 0, -.74)
	mk(Gfx.cyl(.036, .036, .16, 16), M.dark, 0, 0, 0, grp_).rotation.x = PI / 2; mk(Gfx.box(.014, .024, .16), M.red, 0, .036, 0, grp_)
	hit("coll", Vector3(.1, .1, .4), 0, 0, -.36, col); hit("twist", Vector3(.1, .1, .17), 0, 0, -.74, col)
	for x in [-.69, -.41]:
		var p := mk(rbox(.1, .16, .03, .01), M.rubber, x, 1.06, -6.12); p.rotation.x = -.5; pd.append(p)
	for x in [.41, .69]: mk(rbox(.1, .16, .03, .01), M.rubber, x, 1.06, -6.12).rotation.x = -.5
	hit("ped", Vector3(.4, .2, .12), -.55, 1.06, -6.12, MM)
	# panels
	var mkpan := func(w: float, h: float, pos: Vector3, rx: float, d: Gauges) -> Array:
		var G := grp(MM, pos.x, pos.y, pos.z); G.rotation.x = rx
		d.heli = self; d.PS = 1000; draws.append(d)
		var vp := panel_quad(w, h, 1000, G, d)
		mk(rbox(w + .05, h + .05, .16, .02), M.pan8, 0, 0, -.081, G)
		return [G, vp]
	_g8()
	var r := mkpan.call(1.6, .5, Vector3(0, 1.78, -6.25), -.25, Mi8Main.new()); var pnG: Node3D = r[0]; pn8_vp = r[1]
	mk(rbox(1.74, .045, .3, .02), M.crinkle, 0, .275, .08, pnG)
	r = mkpan.call(.6, .46, Vector3(0, 1.28, -5.82), -1.0, Mi8Console.new()); var cnG: Node3D = r[0]; cn8_vp = r[1]
	mk(rbox(.63, .45, .6, .02), M.pan8, 0, -.04, -.32, cnG)
	r = mkpan.call(.9, .46, Vector3(0, 2.8, -5.75), PI / 2 - .5, Mi8Overhead.new()); var ohG: Node3D = r[0]; oh8_vp = r[1]
	for g in G8:
		mk(Gfx.torus(g.r + .002, .005, 40, 8), M.anod, g.x, g.y, .004, pnG).rotation.x = PI / 2
		gauge_glass(g.r, g.x, g.y, pnG)
		hit(g.id, Vector3(g.r * 1.8, g.r * 1.8, .01), g.x, g.y, .009, pnG)
	hit("mAnn", Vector3(1.5, .034, .01), 0, .205, .006, pnG)
	var tog := func(pn: Node3D, id: String, x: float, y: float, get: Callable, guard := false):
		var p := grp(pn, x, y, 0)
		mk(Gfx.cyl(.011, .011, .008, 16), M.chrome, 0, 0, .004, p).rotation.x = PI / 2
		var lv := grp(p, 0, 0, .008)
		mk(Gfx.cyl(.0035, .004, .028, 8), M.chrome, 0, 0, .014, lv).rotation.x = PI / 2; mk(Gfx.sphere(.005, 8, 4), M.chrome, 0, 0, .028, lv)
		if guard:
			for s in [-1, 1]: mk(Gfx.box(.004, .034, .034), M.red, s * .016, 0, .017, p)
		SW8.append([lv, get]); hit(id, Vector3(.05, .055, .045), x * 0, 0, .02, p)
	var btn := func(pn: Node3D, id: String, x: float, y: float, c: Color) -> StandardMaterial3D:
		var p := grp(pn, x, y, 0)
		mk(Gfx.cyl(.022, .022, .01, 16), M.black, 0, 0, .005, p).rotation.x = PI / 2
		var m := Gfx.mat(c, .4); m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = .15
		mk(Gfx.cyl(.016, .016, .014, 16), m, 0, 0, .016, p).rotation.x = PI / 2
		hit(id, Vector3(.05, .05, .04), 0, 0, .02, p)
		return m
	var S := sim.S
	apuS = btn.call(cnG, "mapuS", -.21, .12, Color("2bd24c")); btn.call(cnG, "mapuX", -.12, .12, Color("d22222"))
	selK = grp(cnG, .03, .12, .01); mk(Gfx.box(.022, .05, .016), M.black, 0, 0, 0, selK); hit("msel", Vector3(.06, .06, .04), 0, 0, .01, selK)
	stB = btn.call(cnG, "mstart", .13, .12, Color("f2f2f2")); btn.call(cnG, "mabort", .22, .12, Color("d22222"))
	for t in [["msvc", -.22, func(): return S.svc, false], ["mpL", -.13, func(): return S.pL and S.pR, false], ["mfcL", -.03, func(): return S.fcock[0], true], ["mfcR", .06, func(): return S.fcock[1], true], ["mpbrake", .18, func(): return S.pbrake, false]]:
		tog.call(cnG, t[0], t[1], -.09, t[2], t[3])
	for t in [["batt", -.36, func(): return S.batt], ["mgenL", -.26, func(): return S.genL], ["mgenR", -.16, func(): return S.genR], ["mhyd", -.04, func(): return S.hyd], ["nav", .08, func(): return S.nav], ["mbeacon", .18, func(): return S.beacon], ["ldg", .28, func(): return S.ldg]]:
		tog.call(ohG, t[0], t[1], .1, t[2])
	for i in 2:
		var x: float = [-.25, -.13][i]
		mk(Gfx.box(.018, .16, .01), M.black, x, -.1, .004, ohG)
		var h := grp(ohG, x, -.1, 0); mk(Gfx.box(.05, .025, .05), M.red if i else M.chrome, 0, 0, .03, h)
		hit("mcondR" if i else "mcondL", Vector3(.06, .06, .06), 0, 0, .03, h); cl.append(h)
	rbH = grp(ohG, .16, -.1, .01); mk(Gfx.box(.03, .15, .025), M.red, 0, -.05, .02, rbH); hit("rbrake", Vector3(.07, .18, .06), 0, -.05, .03, rbH)

func _g8() -> void:
	var P := PI
	var asiO := {min = 0, max = 350, a0 = -.5 * P + .3, a1 = 1.5 * P - .3, maj = 50, mn = 10, lab = [0, 50, 100, 150, 200, 250, 300, 350], arcs = [[250, 256, "#dd2222", .86]], t = "km/h", t2 = "AIRSPEED"}
	var altO := {min = 0, max = 10, a0 = -.5 * P, a1 = 1.5 * P, maj = 1, mn = .2, lab = [0, 1, 2, 3, 4, 5, 6, 7, 8, 9], t = "H ×100 m", t2 = "ALTIMETER"}
	var nrO := {min = 0, max = 110, a0 = .75 * P, a1 = 2.25 * P, maj = 10, mn = 2, lab = [0, 20, 40, 60, 80, 100], arcs = [[88, 92, "#e0b000"], [92, 97, "#2bb24c"], [97, 103, "#e0b000"], [103, 110, "#dd2222"]], t = "Nr %", t2 = "ROTOR"}
	var vsO := {min = -30, max = 30, a0 = .1 * P, a1 = 1.9 * P, maj = 10, mn = 2, lab = [-30, -20, -10, 0, 10, 20, 30], fmt = func(v): return str(absi(int(v))), t = "Vy m/s", t2 = "VERT SPEED"}
	var g := func(id: String, x: float, y: float, r: float, o, nd: Array, draw := "", dup := false): G8.append({id = id, x = x, y = y, r = r, o = o, nd = nd, draw = draw, dup = dup})
	var S := sim.S
	g.call("mAsi", -.70, .10, .055, asiO, [["ias"]]); g.call("mAsi2", .40, .10, .055, asiO, [["ias"]], "", true)
	g.call("mAi", -.58, .10, .062, null, [], "ai"); g.call("mAi2", .53, .10, .062, null, [], "ai", true)
	g.call("mAlt", -.46, .10, .055, altO, [["alt100", .84, .04], ["alt1000", .52, .08]]); g.call("mAlt2", .66, .10, .055, altO, [["alt100", .84, .04], ["alt1000", .52, .08]], "", true)
	g.call("mPitch", -.345, .12, .04, {min = 0, max = 16, a0 = .75 * P, a1 = 2.25 * P, maj = 2, mn = 1, lab = [2, 6, 10, 14], arcs = [[14, 16, "#dd2222"]], t = "PITCH °"}, [["pitch"]])
	g.call("mNr", -.70, -.07, .055, nrO, [["nr", .82, .05, "#ffd166"]]); g.call("mNr2", .40, -.07, .055, nrO, [["nr", .82, .05, "#ffd166"]], "", true)
	g.call("mHsi", -.58, -.07, .062, null, [], "hsi"); g.call("mHsi2", .53, -.07, .062, null, [], "hsi", true)
	g.call("mVsi", -.46, -.07, .055, vsO, [["vs"]]); g.call("mVsi2", .66, -.07, .055, vsO, [["vs"]], "", true)
	g.call("mRalt", -.345, -.06, .04, {min = 0, max = 300, a0 = -.5 * P, a1 = 1.4 * P, maj = 50, mn = 10, lab = [0, 100, 200, 300], t = "RADIO m"}, [["ralt"]])
	g.call("mNg", -.205, .10, .05, {min = 0, max = 110, a0 = .75 * P, a1 = 2.25 * P, maj = 10, mn = 2, lab = [0, 20, 40, 60, 80, 100], arcs = [[66, 98, "#2bb24c"], [98, 101, "#e0b000"], [101, 110, "#dd2222"]], t = "Ng %", t2 = "1 white · 2 yellow"}, [["ng0"], ["ng1", .64, .06, "#ffd166"]])
	g.call("mEgt", -.085, .10, .05, {min = 0, max = 1200, a0 = .75 * P, a1 = 2.25 * P, maj = 200, mn = 50, lab = [0, 400, 800, 1200], arcs = [[400, 890, "#2bb24c"], [890, 990, "#e0b000"], [990, 1200, "#dd2222"]], t = "EGT °C", t2 = "1 white · 2 yellow"}, [["egt0"], ["egt1", .64, .06, "#ffd166"]])
	g.call("mFuel", .03, .11, .042, {min = 0, max = 2500, a0 = .75 * P, a1 = 2.25 * P, maj = 500, mn = 100, lab = [0, 1000, 2000], arcs = [[0, 270, "#dd2222"]], t = "FUEL kg"}, [["fuel"]])
	g.call("mHyd", .13, .11, .042, {min = 0, max = 100, a0 = .75 * P, a1 = 2.25 * P, maj = 25, mn = 5, lab = [0, 50, 100], arcs = [[45, 75, "#2bb24c"]], t = "HYD", t2 = "main · backup"}, [["hydP"], ["hydB", .64, .06, "#ffd166"]])
	g.call("mApuT", .23, .11, .042, {min = 0, max = 900, a0 = .75 * P, a1 = 2.25 * P, maj = 300, mn = 50, lab = [0, 300, 600, 900], arcs = [[720, 900, "#dd2222"]], t = "APU °C"}, [["apuT"]])
	var sm := func(id: String, x: float, o: Dictionary, f: String):
		o.merge({a0 = .75 * P, a1 = 2.25 * P}); g.call(id, x, -.075, .036, o, [[f]])
	sm.call("mOilL", -.205, {min = 0, max = 8, maj = 2, mn = .5, lab = [0, 4, 8], arcs = [[2, 4.5, "#2bb24c"]], t = "OIL 1"}, "oil0")
	sm.call("mOilR", -.12, {min = 0, max = 8, maj = 2, mn = .5, lab = [0, 4, 8], arcs = [[2, 4.5, "#2bb24c"]], t = "OIL 2"}, "oil1")
	sm.call("mMgb", -.035, {min = 0, max = 8, maj = 2, mn = .5, lab = [0, 4, 8], arcs = [[2.5, 5, "#2bb24c"]], t = "MGB P"}, "mgbP")
	sm.call("mMgbT", .05, {min = -50, max = 150, maj = 50, mn = 10, lab = [-50, 50, 150], arcs = [[30, 90, "#2bb24c"], [90, 150, "#dd2222"]], t = "MGB °C"}, "mgbT")
	sm.call("mVolt", .135, {min = 0, max = 30, maj = 10, mn = 2, lab = [0, 10, 20, 30], arcs = [[24, 29, "#2bb24c"]], t = "DC V"}, "volts")
	sm.call("mApuP", .23, {min = 0, max = 4, maj = 1, mn = .25, lab = [0, 2, 4], arcs = [[1.5, 2.6, "#2bb24c"]], t = "APU AIR"}, "apuP")

## exterior and cockpit extras: door rails and handle, entry step, tank straps, antennas, cockpit fans, compass
func _details() -> void:
	var tt := door_th()
	for y in [DOOR.y1 + .06, DOOR.y0 - .02]:
		var pts := PackedVector3Array()
		for i in 11:
			var z := lerpf(DOOR.z0 - .05, -1.6, i / 10.0); pts.append(Vector3(-side_x(z, y) - .035, y, z))
		mk(Gfx.tube(pts, .018, 6), M.steel)
	mk(rbox(.03, .05, .16, .01), M.chrome, -side_x(DOOR.z1 - .1, 1.75) - .03, 1.75, DOOR.z1 - .1)
	mk(rbox(.3, .03, .4, .01), M.tread, -1.45, .72, (DOOR.z0 + DOOR.z1) / 2)
	for z in [DOOR.z0 + .05, DOOR.z1 - .05]: mk(Gfx.line_tube(Vector3(-1.32, .73, z), Vector3(-1.2, 1.0, z), .02, 6), M.steel)
	for sd in [-1, 1]:
		for z in [-2.05, -.35]:
			var st := mk(Gfx.torus(.43, .016, 32, 6), M.steel, sd * 1.62, 1.28, z); st.rotation.x = PI / 2; st.scale = Vector3(.9, 1, 1)
		mk(Gfx.cyl(.05, .05, .03, 12), M.chrome, sd * 1.62, 1.72, -1.6)
	for z in [6.2, 7.4]: mk(Gfx.cyl(.004, .008, .9, 6), M.black, 0, 3.55, z).rotation.x = .4
	for z in [-2.2, .9]: mk(rbox(.015, .18, .22, .006), M.dark, 0, .44, z)
	for x in [-.5, .5]: mk(Gfx.box(.06, .03, .12), M.dark, x, .43, -4.6)
	# the classic black cockpit fans in the upper corners of the windscreen
	for sd in [-1, 1]:
		var f := grp(MM, sd * .72, 2.42, -6.32); f.rotation = Vector3(-.35, sd * .45, 0)
		mk(Gfx.cyl(.03, .035, .06, 12), M.black, 0, 0, .04, f).rotation.x = PI / 2
		for k in 4:
			var b := mk(Gfx.box(.075, .002, .03), M.dark, 0, 0, -.01, f); b.rotation = Vector3(0, 0, k * PI / 2 + .3); b.position = Vector3(cos(k * PI / 2) * .04, sin(k * PI / 2) * .04, -.01)
		mk(Gfx.torus(.085, .004, 28, 4), M.black, 0, 0, -.02, f).rotation.x = PI / 2
		for k in 3: mk(Gfx.box(.17, .003, .003), M.black, 0, 0, -.025, f).rotation.z = k * PI / 3
		mk(Gfx.line_tube(Vector3(0, 0, .07), Vector3(0, .09, .14), .008, 6), M.black, 0, 0, 0, f)
	# KI-13 standby compass on the windscreen centre post
	var cg := grp(MM, .25, 2.09, -6.2)
	mk(Gfx.box(.02, .06, .02), M.black, 0, -.03, 0, cg)
	mk(Gfx.sphere(.035, 16, 8), M.black, 0, .02, 0, cg)
	mk(Gfx.cyl(.022, .022, .01, 16), Gfx.mat(Color("d8d2c0"), .5), 0, .02, .032, cg).rotation.x = PI / 2

func animate(dt: float, t: float) -> void:
	var F := sim; var S := sim.S; var C := sim.C; var rr := F.Om / F.Om0
	ang += F.Om * dt; tra += F.Om * 5.58 * dt
	rS.rotation.y = -ang; tS.rotation.x = tra; rT.rotation = Vector3(-F.a1, 0, -F.b1)
	(bz.material_override as StandardMaterial3D).albedo_color.a = U.sstep(.3, .9, rr) * .5
	var cone := -.075 + U.sstep(.25, .8, rr) * (.075 + clampf(F.T / (F.MASS * 9.81), 0, 1.5) * .05)
	for k in 5:
		var b: Dictionary = bl[k]; var ps := -ang + k * TAU / 5
		b.cone.rotation.z = cone; b.pit.rotation.x = -((F.th if F.th else .017) + C.cy * .08 * sin(ps) - C.cx * .06 * cos(ps))
	sw.rotation = Vector3(-C.cy * .1, 0, -C.cx * .08); sw.position.y = 4.0 + C.coll * .06
	for s in sticks: s.rotation = Vector3(-C.cy * .2, 0, -C.cx * .16)
	col.rotation.x = C.coll * .3 - .08; grp_.rotation.z = -S.twist * 1.2
	pd[0].position.z = -6.12 + C.ped * .07; pd[1].position.z = -6.12 - C.ped * .07
	for s in SW8: s[0].rotation.x = -.6 if s[1].call() else .6
	for i in 2: cl[i].position.y = -.17 + S.cond[i] * .07
	rbH.rotation.x = .9 if S.rbrake else 0.0; selK.rotation.z = -.6 if S.sel else .6
	apuS.emission_energy_multiplier = ((1.5 if fmod(t * 3, 1.0) < .5 else .2) if S.apu.start else (1.2 if S.apu.on else .15))
	stB.emission_energy_multiplier = 1.2 if (S.eng[0].start or S.eng[1].start) else .15
	var el: bool = S.elec
	for l in nav8: l.visible = el and S.nav
	for i in 2: bcn[i].visible = el and S.beacon and fmod(t * 1.1 + i * .5, 1.0) < .12
	for l in ldgs: l.light_energy = 8.0 if (el and S.ldg) else 0.0

func redraw_panels() -> void:
	# Only the main gauge panel changes dynamically; console and overhead are static (UPDATE_ONCE)
	pn8_vp.render_target_update_mode = SubViewport.UPDATE_ONCE
	if draws.size() > 0: draws[0].queue_redraw()

func cam_seat() -> Vector3: return Vector3(-.55, .33, -5.32)

# ---------------------------------------------------------------- panels
class Mi8Main extends Gauges:
	func _draw() -> void:
		var h: Mi8 = heli; var F: Sim = h.sim; var S: Dictionary = F.S; var el: bool = S.elec
		draw_rect(Rect2(Vector2.ZERO, size), Color("3e676a"))
		var e := Sim.euler_yxz(F.q); var vb := F.q.inverse() * (F.v - F.wind)
		var V := {ias = maxf(0, -vb.z * 3.6), alt100 = fmod(maxf(0, F.p.y), 1000.0) / 100, alt1000 = fmod(maxf(0, F.p.y), 10000.0) / 1000, vs = clampf(F.v.y, -30, 30),
			ralt = clampf(maxf(0, F.agl), 0, 300) if el else 0.0, nr = F.Om / F.Om0 * 100, pitch = F.th * 57.3, ng0 = S.eng[0].ng, ng1 = S.eng[1].ng, egt0 = S.eng[0].egt, egt1 = S.eng[1].egt,
			fuel = S.fuel if el else 0.0, hydP = S.hydP if el else 0.0, hydB = S.hydB if el else 0.0, apuT = S.apu.egt, oil0 = S.eng[0].oil if el else 0.0, oil1 = S.eng[1].oil if el else 0.0,
			mgbP = S.mgbP if el else 0.0, mgbT = S.mgbT if el else -50.0, volts = S.volts, apuP = S.apu.air}
		var hdg := fposmod(-rad_to_deg(e.y), 360.0)
		for g in h.G8:
			dial(g)
			if g.draw == "ai": _ai(g, e.x if el else 0.0, -e.z if el else 0.0, el)
			elif g.draw == "hsi": compass(g, hdg, el, .2)
			else:
				for n in g.nd:
					needle(g, A(g, clampf(V[n[0]], g.o.min, g.o.max)), n[1] if n.size() > 1 else .82, n[2] if n.size() > 2 else .05, Color(n[3]) if n.size() > 3 else Color("f4f4f4"))
		txt("COMMANDER", P2(-.52, -.2), 16, Color("ccffee")); txt("ENGINES · SYSTEMS", P2(0, -.2), 16, Color("ccffee")); txt("CO-PILOT", P2(.53, -.2), 16, Color("ccffee"))
		var ANN := [["APU START", "#ffb000", S.apu.start], ["APU ON", "#33cc33", S.apu.on], ["STARTER 1", "#ffb000", S.eng[0].start], ["STARTER 2", "#ffb000", S.eng[1].start], ["ENG 1 OUT", "#ff3030", not S.eng[0].running],
			["ENG 2 OUT", "#ff3030", not S.eng[1].running], ["GEN 1 OFF", "#ffb000", not (S.genL and S.eng[0].ng > 60)], ["GEN 2 OFF", "#ffb000", not (S.genR and S.eng[1].ng > 60)], ["HYD MAIN", "#ff3030", S.hydP < 30], ["HYD BACKUP", "#ffb000", S.hydB > 30],
			["ROTOR BRAKE", "#ffb000", S.rbrake], ["PARK BRAKE", "#ffb000", S.pbrake], ["LOW FUEL", "#ff3030", S.fuel < 270], ["Nr LOW", "#ff3030", S.low]]
		for i in ANN.size(): ann(-.75 + i * .1071, .222, .1, .032, ANN[i][0], Color(ANN[i][1]), el and ANN[i][2], 12)

	## Soviet attitude indicator: the horizon moves with pitch, the aircraft symbol rolls with bank
	func _ai(g: Dictionary, pit: float, rol: float, el: bool) -> void:
		var c := P2(g.x, g.y); var Rr: float = g.r * PS * .94
		draw_circle(c, Rr, Color("6b4426"))
		_fill_half(c, Rr, Vector2(0, -1), pit * Rr * 2.2, Color("3a7fc4"))
		var hy := c.y + pit * Rr * 2.2
		if absf(hy - c.y) < Rr: draw_line(Vector2(c.x - sqrt(Rr * Rr - pow(hy - c.y, 2)), hy), Vector2(c.x + sqrt(Rr * Rr - pow(hy - c.y, 2)), hy), Color.WHITE, 2)
		for p in [-20, -10, 10, 20]:
			var y = hy - p * PI / 180 * Rr * 2.2
			if absf(y - c.y) < Rr * .9: draw_line(Vector2(c.x - Rr * .25, y), Vector2(c.x + Rr * .25, y), Color.WHITE, 2)
		draw_set_transform(c, rol if el else 0.0, Vector2.ONE)
		var y8 := Color("ffcf33")
		draw_line(Vector2(-Rr * .7, 0), Vector2(-Rr * .12, 0), y8, 5); draw_line(Vector2(Rr * .12, 0), Vector2(Rr * .7, 0), y8, 5); draw_line(Vector2(0, -Rr * .12), Vector2(0, -Rr * .3), y8, 5)
		draw_circle(Vector2.ZERO, Rr * .07, y8)
		draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
		for b in [-60, -30, -15, 0, 15, 30, 60]:
			var a := -PI / 2 + deg_to_rad(b); draw_line(c + Vector2(cos(a), sin(a)) * Rr * .86, c + Vector2(cos(a), sin(a)) * Rr * .98, Color.WHITE, 2)
		if not el: draw_rect(Rect2(c + Vector2(Rr * .1, Rr * .35), Vector2(Rr * .5, Rr * .22)), Color("dd2222"))

class Mi8Console extends Gauges:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("3e676a"))
		var y := Color("ffd166"); var w := Color("e8eef5")
		txt("APU  AI-9V", P2(-.165, .2), 17, y); txt("ENGINE START", P2(.13, .2), 17, y); txt("FUEL", P2(-.08, .02), 17, y)
		txt("START", P2(-.21, .075), 13, w); txt("STOP", P2(-.12, .075), 13, w); txt("1      2", P2(.03, .165), 14, w); txt("SELECT", P2(.03, .075), 13, w)
		txt("START", P2(.13, .075), 13, w); txt("ABORT", P2(.22, .075), 13, w)
		for l in [[-.22, "SERVICE", "PUMP"], [-.13, "TANK", "PUMPS"], [-.03, "FIRE", "COCK 1"], [.06, "FIRE", "COCK 2"], [.18, "PARK", "BRAKE"]]:
			txt(l[1], P2(l[0], -.03), 12, w); txt(l[2], P2(l[0], -.045), 12, w)

class Mi8Overhead extends Gauges:
	func _draw() -> void:
		draw_rect(Rect2(Vector2.ZERO, size), Color("3e676a"))
		var w := Color("e8eef5")
		for l in [[-.36, "BATT"], [-.26, "GEN 1"], [-.16, "GEN 2"], [-.04, "HYD MAIN"], [.08, "NAV"], [.18, "BEACON"], [.28, "LDG LT"]]: txt(l[1], P2(l[0], .16), 14, w)
		for i in 2:
			var x: float = [-.25, -.13][i]
			txt("ENG %d" % (i + 1), P2(x, .02), 14, w); txt("AUTO", P2(x + .055, -.03), 11, w); txt("IDLE", P2(x + .055, -.1), 11, w); txt("STOP", P2(x + .055, -.17), 11, w)
		txt("ROTOR BRAKE", P2(.16, .02), 14, Color("ff8a8a"))
