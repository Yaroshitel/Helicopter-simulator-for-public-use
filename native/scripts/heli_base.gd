class_name HeliBase extends Node3D
## Shared helicopter-model helpers: superellipse lofts, NACA blades, clickable control hit boxes, live rods.

var model: Node3D          # all geometry, offset so the CG sits at the node origin
var hits: Array = []       # {id, node, size, off, hl}
var M := {}                # materials
var sim: Sim
var HL_MAT: StandardMaterial3D

func _init_mats() -> void:
	var paint := StandardMaterial3D.new(); paint.albedo_color = Color("f4f4f2"); paint.roughness = .2; paint.clearcoat_enabled = true; paint.clearcoat = 1; paint.clearcoat_roughness = .02
	M.paint = paint
	M.inner = StandardMaterial3D.new(); M.inner.albedo_color = Color("97938b"); M.inner.roughness = .95; M.inner.cull_mode = BaseMaterial3D.CULL_FRONT
	M.inner.normal_enabled = true; M.inner.normal_texture = Gfx.nmap(Gfx.noise_img(256, .8, 31, 2), 2.0); M.inner.uv1_scale = Vector3(30, 60, 1)
	var glass := StandardMaterial3D.new(); glass.albedo_color = Color(.66, .75, .8, .14); glass.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	glass.roughness = .03; glass.cull_mode = BaseMaterial3D.CULL_DISABLED; glass.metallic_specular = 1.0
	M.glass = glass
	M.chrome = Gfx.mat(Color("e0e0e0"), .14, 1); M.steel = Gfx.mat(Color("8a8f96"), .5, .85); M.dark = Gfx.mat(Color("1c1e21"), .55, .3)
	M.black = Gfx.mat(Color("0c0c0d"), .4, .2); M.eng = Gfx.mat(Color("50555c"), .6, .7); M.exh = Gfx.mat(Color("8a7563"), .45, .85)
	var blade := StandardMaterial3D.new(); blade.vertex_color_use_as_albedo = true; blade.roughness = .25; blade.metallic = .45; blade.cull_mode = BaseMaterial3D.CULL_DISABLED
	M.blade = blade
	M.seat = Gfx.mat(Color("6a4f38"), .85); M.red = Gfx.mat(Color("b01818"), .4, .2); M.gold = Gfx.mat(Color("b08a3a"), .35, .8)
	M.white = paint
	# cockpit material kit: textures are small, seamless and generated once
	var fine := Gfx.noise_img(256, .22, 21, 3)
	var lth := StandardMaterial3D.new(); lth.albedo_color = Color("5a4434"); lth.roughness = .5; lth.normal_enabled = true; lth.normal_texture = Gfx.nmap(fine, 1.6)
	lth.uv1_scale = Vector3(3, 3, 3); lth.uv1_triplanar = true; lth.clearcoat_enabled = true; lth.clearcoat = .25; lth.clearcoat_roughness = .45
	M.leather = lth
	var crk := Gfx.noise_img(256, .6, 23, 2)
	var cr := StandardMaterial3D.new(); cr.albedo_color = Color("2b2d30"); cr.roughness = .62; cr.normal_enabled = true; cr.normal_texture = Gfx.nmap(crk, 3.0)
	cr.uv1_scale = Vector3(14, 14, 14); cr.uv1_triplanar = true
	M.crinkle = cr
	var cp := StandardMaterial3D.new(); cp.albedo_texture = Gfx.tex(Gfx.noise_img(256, .5, 25, 3, .12, .2)); cp.roughness = 1.0; cp.normal_enabled = true
	cp.normal_texture = Gfx.nmap(Gfx.noise_img(256, .9, 27, 2), 4.0); cp.uv1_scale = Vector3(6, 6, 6); cp.uv1_triplanar = true
	M.carpet = cp
	var rb := StandardMaterial3D.new(); rb.albedo_color = Color("141516"); rb.roughness = .9; rb.normal_enabled = true; rb.normal_texture = Gfx.nmap(crk, 2.0)
	rb.uv1_scale = Vector3(20, 20, 20); rb.uv1_triplanar = true
	M.rubber = rb
	var fb := StandardMaterial3D.new(); fb.albedo_color = Color("7b7a76"); fb.roughness = .95; fb.normal_enabled = true; fb.normal_texture = Gfx.nmap(Gfx.noise_img(256, .8, 29, 2), 2.0)
	fb.uv1_scale = Vector3(8, 8, 8); fb.uv1_triplanar = true
	M.fabric = fb
	var gg := StandardMaterial3D.new(); gg.albedo_color = Color(.8, .85, .9, .07); gg.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; gg.roughness = .02; gg.metallic_specular = 1.0
	M.gglass = gg
	M.anod = Gfx.mat(Color("1d1f22"), .35, .6)
	HL_MAT = StandardMaterial3D.new(); HL_MAT.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; HL_MAT.albedo_color = Color(1, .82, .4, 0)
	HL_MAT.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; HL_MAT.no_depth_test = true; HL_MAT.render_priority = 10

## rounded box (Minkowski sum of a box and a sphere): size w × h × d, edge radius r, centred; box-projected UVs
static func rbox(w: float, h: float, d: float, r: float, seg := 24, rings := 12) -> ArrayMesh:
	var sp := SphereMesh.new(); sp.radius = 1; sp.height = 2; sp.radial_segments = seg; sp.rings = rings
	var arr := sp.get_mesh_arrays()
	var V: PackedVector3Array = arr[Mesh.ARRAY_VERTEX]; var N: PackedVector3Array = arr[Mesh.ARRAY_NORMAL]; var UV: PackedVector2Array = arr[Mesh.ARRAY_TEX_UV]
	var inner := Vector3(maxf(w / 2 - r, 0), maxf(h / 2 - r, 0), maxf(d / 2 - r, 0))
	var sg := func(v: float) -> float: return 0.0 if absf(v) < 1e-4 else signf(v)
	for i in V.size():
		var n := V[i].normalized()
		var q := Vector3(sg.call(n.x) * inner.x, sg.call(n.y) * inner.y, sg.call(n.z) * inner.z)
		var p := q + n * r; V[i] = p; N[i] = n
		var a := n.abs()
		UV[i] = Vector2(p.z, p.y) if a.x >= a.y and a.x >= a.z else (Vector2(p.x, p.z) if a.y >= a.z else Vector2(p.x, p.y))
	arr[Mesh.ARRAY_VERTEX] = V; arr[Mesh.ARRAY_NORMAL] = N; arr[Mesh.ARRAY_TEX_UV] = UV; arr[Mesh.ARRAY_TANGENT] = null
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	var st := SurfaceTool.new(); st.create_from(am, 0); st.generate_tangents()
	return st.commit()

## texture position of (z, theta) on a loft made by loft(K, …): u along the length (cosine-spaced stations), v around
static func uv_of(K: Array, z: float, th: float, W: int, H: int) -> Vector2:
	var z0: float = K[0][0]; var z1: float = K[-1][0]
	var t := acos(clampf(1.0 - 2.0 * (z - z0) / (z1 - z0), -1, 1)) / PI
	return Vector2(t * W, fposmod(th, TAU) / TAU * H)

## glass cover and screws for a round instrument at (x, y) on panel node p (panel faces +z)
func gauge_glass(r: float, x: float, y: float, p: Node3D, screws := 0) -> void:
	mk(Gfx.cyl(r, r, .002, 32), M.gglass, x, y, .007, p, false).rotation.x = PI / 2
	for i in screws:
		var a := PI / 4 + i * PI / 2 * (4.0 / screws) * .5
		screw(x + cos(a) * r * 1.32, y + sin(a) * r * 1.32, .003, p, r * .1)

func screw(x: float, y: float, z: float, p: Node3D, r := .004) -> void:
	var s := mk(Gfx.cyl(r, r, r * .6, 10), M.chrome, x, y, z, p, false); s.rotation.x = PI / 2
	mk(Gfx.box(r * 1.6, r * .3, r * .3), M.black, x, y, z + r * .35, p, false).rotation.z = randf() * PI

func mk(mesh: Mesh, m: Material, x := 0.0, y := 0.0, z := 0.0, p: Node3D = null, shadow := true) -> MeshInstance3D:
	return Gfx.mi(p if p else model, mesh, m, Vector3(x, y, z), Vector3.ZERO, shadow)

func grp(p: Node3D, x := 0.0, y := 0.0, z := 0.0) -> Node3D:
	var g := Node3D.new(); g.position = Vector3(x, y, z); p.add_child(g); return g

## a clickable control: an invisible box (size) at local offset on node p; it glows when the lesson points at it
func hit(id: String, size: Vector3, x: float, y: float, z: float, p: Node3D) -> void:
	var hl := MeshInstance3D.new(); hl.mesh = Gfx.box(size.x, size.y, maxf(size.z, .004)); hl.position = Vector3(x, y, z)
	var m := HL_MAT.duplicate(); hl.material_override = m; hl.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	p.add_child(hl)
	hits.append({id = id, node = hl, size = size, mat = m})

## ray against the hit boxes; returns the nearest id within maxd or ""
func pick(o: Vector3, d: Vector3, maxd: float) -> String:
	var best := ""; var bd := maxd
	for h in hits:
		var n: Node3D = h.node
		if not n.is_visible_in_tree(): continue
		var inv := n.global_transform.affine_inverse()
		var lo := inv * o; var ld := inv.basis * d
		var half: Vector3 = h.size / 2; var t0 := -1e9; var t1 := 1e9; var ok := true
		for ax in 3:
			if absf(ld[ax]) < 1e-9:
				if absf(lo[ax]) > half[ax]: ok = false; break
			else:
				var a := (-half[ax] - lo[ax]) / ld[ax]; var b := (half[ax] - lo[ax]) / ld[ax]
				t0 = maxf(t0, minf(a, b)); t1 = minf(t1, maxf(a, b))
		if ok and t1 >= t0 and t0 > 0:
			var dist := (n.global_transform * (lo + ld * t0) - o).length()
			if dist < bd: bd = dist; best = h.id
	return best

func highlight(id: String, t: float) -> void:
	for h in hits:
		h.mat.albedo_color.a = (.16 + .14 * sin(t * 6)) if h.id == id else 0.0

# ---------- lofted fuselage ----------
## cubic Hermite interpolation of keyframe column k at station z (keys [z, halfwidth, ytop, ybottom])
static func cr(K: Array, z: float, k: int) -> float:
	var i := 0
	while i < K.size() - 2 and z > K[i + 1][0]: i += 1
	var pk := func(j: int) -> Array: return K[clampi(j, 0, K.size() - 1)]
	var z0: float = pk.call(i)[0]; var h: float = pk.call(i + 1)[0] - z0; var t := clampf((z - z0) / h, 0, 1)
	var m := func(j: int) -> float:
		var a: Array = pk.call(j - 1); var b: Array = pk.call(j + 1)
		var dz: float = b[0] - a[0]
		return (b[k] - a[k]) / (dz if dz != 0 else 1.0) * h
	var y0: float = pk.call(i)[k]; var y1: float = pk.call(i + 1)[k]; var m0: float = m.call(i); var m1: float = m.call(i + 1); var t2 := t * t; var t3 := t2 * t
	return (2 * t3 - 3 * t2 + 1) * y0 + (t3 - 2 * t2 + t) * m0 + (-2 * t3 + 3 * t2) * y1 + (t3 - t2) * m1

static func sec_pt(K: Array, z: float, th: float, o := {}) -> Vector3:
	var nx: float = o.get("nx", 2.6); var nt: float = o.get("nt", 2.2); var nb: float = o.get("nb", 3.2); var cf: float = o.get("cf", .42)
	var hw := maxf(cr(K, z, 1), .002); var yt := cr(K, z, 2); var yb := cr(K, z, 3); var yc := yb + cf * (yt - yb); var c := cos(th); var s := sin(th)
	return Vector3(hw * signf(c) * pow(absf(c), 2 / nx), yc + (yt - yc) * pow(s, 2 / nt) if s >= 0 else yc - (yc - yb) * pow(-s, 2 / nb), z)

## superellipse loft; mask(z, theta) → 0/1 splits faces into two surfaces (e.g. skin / glazing)
static func loft(K: Array, N: int, Mn: int, o := {}, mask := Callable()) -> ArrayMesh:
	var z0: float = K[0][0]; var z1: float = K[-1][0]
	var P := PackedVector3Array(); var UV := PackedVector2Array(); var zs := []
	for i in N + 1:
		var t := float(i) / N; var z := z0 + (z1 - z0) * (.5 - .5 * cos(PI * t)); zs.append(z)
		for j in Mn + 1:
			P.append(sec_pt(K, z, float(j) / Mn * TAU, o)); UV.append(Vector2(t, float(j) / Mn))
	# smooth normals from the grid (seam averaged)
	var Nn := PackedVector3Array(); Nn.resize(P.size())
	var W := Mn + 1
	for i in N + 1:
		for j in Mn + 1:
			var a := P[mini(i + 1, N) * W + j] - P[maxi(i - 1, 0) * W + j]
			var jj := j
			var b := P[i * W + ((jj + 1) % Mn)] - P[i * W + ((jj - 1 + Mn) % Mn)]
			var n := b.cross(a)
			if n.length() < 1e-9: n = Vector3(0, 0, -1 if i == 0 else 1)
			Nn[i * W + j] = n.normalized()
	var G := [PackedInt32Array(), PackedInt32Array()]
	for i in N:
		for j in Mn:
			var a := i * W + j; var b := a + W
			var g := 0
			if mask.is_valid(): g = mask.call((zs[i] + zs[i + 1]) / 2, (j + .5) / Mn * TAU)
			G[g].append_array([a, b, a + 1, b, b + 1, a + 1])
	var am := ArrayMesh.new()
	for g in 2:
		if G[g].is_empty():
			G[g] = PackedInt32Array([0, 0, 0])
		var arr := []; arr.resize(Mesh.ARRAY_MAX)
		arr[Mesh.ARRAY_VERTEX] = P; arr[Mesh.ARRAY_NORMAL] = Nn; arr[Mesh.ARRAY_TEX_UV] = UV; arr[Mesh.ARRAY_INDEX] = G[g]
		am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	return am

## NACA-00xx blade from r0 to r1, chord c, thickness tk, twist tw; painted tip stripes
static func blade_geo(r0: float, r1: float, c: float, tk: float, ns: int, nc: int, tip: bool, tw: float, base := Color(.2, .21, .23)) -> ArrayMesh:
	var P := PackedVector3Array(); var Cl := PackedColorArray(); var I := PackedInt32Array()
	var naca := func(x: float) -> float: return 5 * tk * (.2969 * sqrt(x) - .126 * x - .3516 * x * x + .2843 * x * x * x - .1036 * x * x * x * x)
	for i in ns + 1:
		var s := float(i) / ns; var r := r0 + (r1 - r0) * s; var a := tw * (s - .7); var ca := cos(a); var sa := sin(a)
		var col := base
		if tip and s > .93: col = Color(.8, .08, .06) if int(floorf((s - .93) / .0234)) % 2 else Color(.92, .92, .92)
		for j in nc:
			var ph := float(j) / nc * TAU; var x := (1 + cos(ph)) / 2; var y = signf(sin(ph)) * naca.call(x) * c; var z := (x - .25) * c
			P.append(Vector3(r, y * ca - z * sa, y * sa + z * ca)); Cl.append(col)
	for i in ns:
		for j in nc:
			var a := i * nc + j; var b := a + nc; var a1 := i * nc + (j + 1) % nc; var b1 := a1 + nc
			I.append_array([a, a1, b, b, a1, b1])
	var c0 := P.size(); P.append(Vector3(r0, 0, 0)); P.append(Vector3(r1, 0, 0)); Cl.append(base); Cl.append(base)
	for j in nc:
		var j1 := (j + 1) % nc
		I.append_array([c0, j1, j, c0 + 1, ns * nc + j, ns * nc + j1])
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var arr := []; arr.resize(Mesh.ARRAY_MAX); arr[Mesh.ARRAY_VERTEX] = P; arr[Mesh.ARRAY_COLOR] = Cl; arr[Mesh.ARRAY_INDEX] = I
	var am := ArrayMesh.new(); am.add_surface_from_arrays(Mesh.PRIMITIVE_TRIANGLES, arr)
	st.create_from(am, 0); st.generate_normals()
	return st.commit()

## extruded 2D outline (in the y-z plane, thickness d along x) — fins and stabilisers
static func ext(pts: Array, d: float) -> ArrayMesh:
	var poly := PackedVector2Array()
	for p in pts: poly.append(Vector2(p[0], p[1]))
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		poly.reverse(); tri = Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for s in [-1, 1]:
		for k in range(0, tri.size(), 3):
			var idx := [tri[k], tri[k + 1], tri[k + 2]] if s > 0 else [tri[k], tri[k + 2], tri[k + 1]]
			for ii in idx: st.add_vertex(Vector3(s * d / 2, poly[ii].y, poly[ii].x))
	for i in poly.size():
		var a := poly[i]; var b := poly[(i + 1) % poly.size()]
		var q := [Vector3(-d / 2, a.y, a.x), Vector3(d / 2, a.y, a.x), Vector3(d / 2, b.y, b.x), Vector3(-d / 2, b.y, b.x)]
		for ii in [0, 1, 2, 0, 2, 3]: st.add_vertex(q[ii])
		for ii in [0, 2, 1, 0, 3, 2]: st.add_vertex(q[ii])
	st.generate_normals()
	return st.commit()

## live rods (pitch links / scissors) re-aimed every frame between two attachment points
var rods: Array = []
func rod(r: float, m: Material, A: Node3D, a: Vector3, B: Node3D, b: Vector3) -> void:
	var o := MeshInstance3D.new(); o.mesh = Gfx.merge([[Gfx.cyl(r, r, 1, 8), Gfx.xf(Vector3(0, .5, 0))]]); o.material_override = m
	model.add_child(o); rods.append({m = o, A = A, a = a, B = B, b = b})

func upd_rods() -> void:
	var inv := model.global_transform.affine_inverse()
	for r in rods:
		var pa: Vector3 = inv * (r.A.global_transform * r.a); var pb: Vector3 = inv * (r.B.global_transform * r.b)
		var d := pb - pa; var l := d.length()
		var o: MeshInstance3D = r.m
		o.position = pa
		if l > 1e-5:
			var y := d / l; var x := y.cross(Vector3.FORWARD)
			if x.length() < 1e-3: x = y.cross(Vector3.RIGHT)
			x = x.normalized(); var z := x.cross(y)
			o.basis = Basis(x, y * l, z)

func _blur_tex() -> ImageTexture:
	var img := Image.create(256, 256, false, Image.FORMAT_RGBA8)
	for y in 256:
		for x in 256:
			var d := Vector2(x - 128, y - 128).length() / 128.0
			var a := 0.0; var c := Color(.12, .12, .12)
			if d < .12: a = lerpf(0, .5, d / .12)
			elif d < .9: a = lerpf(.5, .35, (d - .12) / .78)
			elif d < .97: a = lerpf(.35, .5, (d - .9) / .07); c = c.lerp(Color(.78, .16, .12), (d - .9) / .07)
			elif d < 1: a = lerpf(.5, 0, (d - .97) / .03); c = Color(.78, .16, .12)
			c.a = a; img.set_pixel(x, y, c)
	return Gfx.tex(img)

func blur_disk(r: float, p: Node3D) -> MeshInstance3D:
	var m := StandardMaterial3D.new(); m.albedo_texture = _blur_tex(); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED; m.cull_mode = BaseMaterial3D.CULL_DISABLED; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
	m.albedo_color = Color(1, 1, 1, 0)
	var q := PlaneMesh.new(); q.size = Vector2(2 * r, 2 * r)
	return mk(q, m, 0, 0, 0, p, false)

## an instrument panel rendered by a 2D Control into a texture on a quad
func panel_quad(w: float, h: float, ps: float, p: Node3D, drawer: Control) -> SubViewport:
	# drawn at 1.5× resolution with 4× MSAA: crisp, smooth dial markings even when you lean in
	var vp := SubViewport.new(); vp.size = Vector2i(int(w * ps * 1.5), int(h * ps * 1.5)); vp.transparent_bg = false
	vp.size_2d_override = Vector2i(int(w * ps), int(h * ps)); vp.size_2d_override_stretch = true; vp.msaa_2d = Viewport.MSAA_4X
	vp.render_target_update_mode = SubViewport.UPDATE_ALWAYS; vp.disable_3d = true
	drawer.size = Vector2(vp.size_2d_override); vp.add_child(drawer); add_child(vp)
	var m := StandardMaterial3D.new(); m.albedo_texture = vp.get_texture(); m.roughness = .55
	m.emission_enabled = true; m.emission_texture = vp.get_texture(); m.emission_energy_multiplier = .32
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	var q := QuadMesh.new(); q.size = Vector2(w, h)
	mk(q, m, 0, 0, 0, p, false)
	return vp
