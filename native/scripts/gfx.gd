class_name Gfx
## Small mesh / material / texture helpers shared by the world and helicopter builders.

static func mat(c: Color, rough := .8, metal := 0.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c; m.roughness = rough; m.metallic = metal
	return m

static func hexc(h: int) -> Color:
	return Color8((h >> 16) & 255, (h >> 8) & 255, h & 255)

static func unshaded(c: Color, energy := 1.0) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	m.albedo_color = c
	m.emission_enabled = true; m.emission = c; m.emission_energy_multiplier = energy
	return m

static func mi(parent: Node, mesh: Mesh, m: Material, pos := Vector3.ZERO, rot := Vector3.ZERO, shadow := true) -> MeshInstance3D:
	var o := MeshInstance3D.new(); o.mesh = mesh
	if m: o.material_override = m
	o.position = pos; o.rotation = rot
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(o)
	return o

static func box(w: float, h: float, d: float) -> BoxMesh:
	var b := BoxMesh.new(); b.size = Vector3(w, h, d); return b

static func cyl(rt: float, rb: float, h: float, seg := 16, open := false) -> CylinderMesh:
	var c := CylinderMesh.new(); c.top_radius = rt; c.bottom_radius = rb; c.height = h; c.radial_segments = seg; c.rings = 1
	if open: c.cap_top = false; c.cap_bottom = false
	return c

static func sphere(r: float, seg := 16, rings := 8, hemi := false) -> SphereMesh:
	var s := SphereMesh.new(); s.radius = r; s.height = r * 2; s.radial_segments = seg; s.rings = rings; s.is_hemisphere = hemi
	return s

static func cone(r: float, h: float, seg := 12) -> CylinderMesh:
	return cyl(0.0, r, h, seg)

static func torus(r: float, tube: float, seg := 32, rings := 8) -> TorusMesh:
	var t := TorusMesh.new(); t.inner_radius = r - tube; t.outer_radius = r + tube; t.rings = seg; t.ring_segments = rings
	return t

static func capsule(r: float, len: float) -> CapsuleMesh:
	var c := CapsuleMesh.new(); c.radius = r; c.height = len + 2 * r; return c

## box with UVs in world units (tu × tv metres per tile), base at y = 0. surface 0 = walls, surface 1 = top/bottom
static func ubox(w: float, h: float, d: float, tu: float, tv: float) -> ArrayMesh:
	var am := ArrayMesh.new()
	var walls := SurfaceTool.new(); walls.begin(Mesh.PRIMITIVE_TRIANGLES)
	var caps := SurfaceTool.new(); caps.begin(Mesh.PRIMITIVE_TRIANGLES)
	var hw := w / 2; var hd := d / 2
	# faces: normal, origin corner, u axis, v axis, size u, size v
	var F := [[Vector3(1, 0, 0), Vector3(hw, 0, hd), Vector3(0, 0, -1), d], [Vector3(-1, 0, 0), Vector3(-hw, 0, -hd), Vector3(0, 0, 1), d],
		[Vector3(0, 0, 1), Vector3(-hw, 0, hd), Vector3(1, 0, 0), w], [Vector3(0, 0, -1), Vector3(hw, 0, -hd), Vector3(-1, 0, 0), w]]
	for f in F:
		var n: Vector3 = f[0]; var o: Vector3 = f[1]; var ua: Vector3 = f[2]; var L: float = f[3]
		var P := [o, o + ua * L, o + ua * L + Vector3(0, h, 0), o + Vector3(0, h, 0)]
		var UV := [Vector2(0, h / tv), Vector2(L / tu, h / tv), Vector2(L / tu, 0), Vector2(0, 0)]
		for k in [0, 2, 1, 0, 3, 2]:
			walls.set_normal(n); walls.set_uv(UV[k]); walls.add_vertex(P[k])
	for s in [1, -1]:
		var y := h if s > 0 else 0.0
		var P := [Vector3(-hw, y, -hd), Vector3(hw, y, -hd), Vector3(hw, y, hd), Vector3(-hw, y, hd)]
		var idx := [0, 1, 2, 0, 2, 3] if s < 0 else [0, 2, 1, 0, 3, 2]
		for k in idx:
			caps.set_normal(Vector3(0, s, 0)); caps.set_uv(Vector2(P[k].x / 4, P[k].z / 4)); caps.add_vertex(P[k])
	walls.generate_tangents(); caps.generate_tangents()
	walls.commit(am); caps.commit(am)
	return am

## horizontal plane (y up) of w × d centred at origin with uv repeat
static func plane(w: float, d: float, rep := Vector2.ONE) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var P := [Vector3(-w / 2, 0, -d / 2), Vector3(w / 2, 0, -d / 2), Vector3(w / 2, 0, d / 2), Vector3(-w / 2, 0, d / 2)]
	var UV := [Vector2(0, 0), Vector2(rep.x, 0), Vector2(rep.x, rep.y), Vector2(0, rep.y)]
	for k in [0, 1, 2, 0, 2, 3]:
		st.set_normal(Vector3.UP); st.set_uv(UV[k]); st.add_vertex(P[k])
	st.generate_tangents()
	return st.commit()

## seamless grey noise image (C++ side, fast)
static func noise_img(sz: int, freq: float, seed_ := 1, oct := 5, lo := 0.0, hi := 1.0) -> Image:
	var n := FastNoiseLite.new(); n.seed = seed_; n.frequency = freq; n.fractal_octaves = oct
	n.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var img := n.get_seamless_image(sz, sz, false, false, 0.1, true)
	img.convert(Image.FORMAT_RGBA8)
	if lo != 0.0 or hi != 1.0:
		img.adjust_bcs(1.0, hi - lo, 1.0)
	return img

static func tex(img: Image, mip := true) -> ImageTexture:
	if mip and not img.has_mipmaps(): img.generate_mipmaps()
	return ImageTexture.create_from_image(img)

static func nmap(img: Image, strength := 4.0) -> ImageTexture:
	var b := img.duplicate() as Image
	if b.has_mipmaps(): b.clear_mipmaps()
	b.convert(Image.FORMAT_RGBA8)
	b.bump_map_to_normal_map(strength)
	b.generate_mipmaps()
	return ImageTexture.create_from_image(b)

static func textured(img: Image, rough := .85, nstr := 0.0, tint := Color.WHITE) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_texture = tex(img); m.albedo_color = tint; m.roughness = rough
	m.texture_filter = BaseMaterial3D.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS_ANISOTROPIC
	if nstr > 0:
		m.normal_enabled = true; m.normal_texture = nmap(img, nstr)
	return m

## a MultiMesh of `mesh` placed at L = [{x,y,z,ry,sx,sy,sz,c}]
static func multi(parent: Node, mesh: Mesh, m: Material, L: Array, shadow := true) -> MultiMeshInstance3D:
	if L.is_empty(): return null
	var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D
	var has_c: bool = L[0].has("c")
	mm.use_colors = has_c; mm.mesh = mesh; mm.instance_count = L.size()
	for i in L.size():
		var q: Dictionary = L[i]
		var b := Basis(Vector3.UP, q.get("ry", 0.0)).scaled(Vector3(q.get("sx", 1.0), q.get("sy", 1.0), q.get("sz", 1.0)))
		mm.set_instance_transform(i, Transform3D(b, Vector3(q.x, q.y, q.z)))
		if has_c: mm.set_instance_color(i, q.c)
	var o := MultiMeshInstance3D.new(); o.multimesh = mm
	if m:
		if has_c and m is StandardMaterial3D: (m as StandardMaterial3D).vertex_color_use_as_albedo = true
		o.material_override = m
	o.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_ON if shadow else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(o)
	return o

## merge primitive meshes (each with its own transform) into one ArrayMesh surface
static func merge(parts: Array) -> ArrayMesh:
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	for p in parts:
		var mesh: Mesh = p[0]; var xf: Transform3D = p[1]
		for s in mesh.get_surface_count():
			st.append_from(mesh, s, xf)
	st.generate_normals()
	return st.commit()

static func xf(pos: Vector3, rot := Vector3.ZERO, scl := Vector3.ONE) -> Transform3D:
	return Transform3D(Basis.from_euler(rot).scaled(scl), pos)

## tube along a Catmull-Rom curve through pts
static func tube(pts: PackedVector3Array, r: float, seg := 8, closed := false, n := 0) -> ArrayMesh:
	var c := Curve3D.new()
	var N := pts.size()
	for i in N: c.add_point(pts[i])
	if closed: c.add_point(pts[0])
	# catmull-rom handles
	var M := c.point_count
	for i in M:
		var a := c.get_point_position(maxi(i - 1, 0) if not closed else (i - 1 + M - 1) % (M - 1))
		var b := c.get_point_position(mini(i + 1, M - 1) if not closed else (i + 1) % (M - 1))
		var tng := (b - a) / 6.0
		c.set_point_in(i, -tng); c.set_point_out(i, tng)
	var L := c.get_baked_length()
	var steps := n if n > 0 else maxi(4, int(L / maxf(r * 2, .05)))
	steps = mini(steps, 400)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var prev := Vector3.UP
	var rings: Array = []
	for i in steps + 1:
		var t := L * i / steps
		var p := c.sample_baked(t, true)
		var p2 := c.sample_baked(minf(L, t + L * .002), true); var p0 := c.sample_baked(maxf(0, t - L * .002), true)
		var tg := (p2 - p0).normalized()
		if tg == Vector3.ZERO: tg = Vector3.FORWARD
		var nn := prev - tg * prev.dot(tg)
		if nn.length() < 1e-3:
			nn = Vector3.RIGHT - tg * Vector3.RIGHT.dot(tg)
		nn = nn.normalized(); prev = nn
		var bn := tg.cross(nn)
		var ring := []
		for k in seg + 1:
			var a := TAU * k / seg
			var d := nn * cos(a) + bn * sin(a)
			ring.append([p + d * r, d])
		rings.append(ring)
	for i in steps:
		for k in seg:
			var A = rings[i][k]; var B = rings[i + 1][k]; var Cc = rings[i + 1][k + 1]; var D = rings[i][k + 1]
			for vv in [A, B, Cc, A, Cc, D]:
				st.set_normal(vv[1]); st.add_vertex(vv[0])
	return st.commit()

static func line_tube(a: Vector3, b: Vector3, r: float, seg := 8) -> ArrayMesh:
	var c := cyl(r, r, a.distance_to(b), seg)
	var mid := (a + b) / 2; var dir := (b - a).normalized()
	var basis := Basis()
	if absf(dir.dot(Vector3.UP)) < .999:
		var ax := Vector3.UP.cross(dir).normalized(); basis = Basis(ax, Vector3.UP.angle_to(dir))
	elif dir.y < 0:
		basis = Basis(Vector3.RIGHT, PI)
	return merge([[c, Transform3D(basis, mid)]])

## extruded 2D outline: pts are [z, y] pairs, thickness d along x (centred)
static func extrude(pts: Array, d: float, x0 := 0.0) -> ArrayMesh:
	var poly := PackedVector2Array()
	for p in pts: poly.append(Vector2(p[0], p[1]))
	var tri := Geometry2D.triangulate_polygon(poly)
	if tri.is_empty():
		poly.reverse(); tri = Geometry2D.triangulate_polygon(poly)
	var st := SurfaceTool.new(); st.begin(Mesh.PRIMITIVE_TRIANGLES)
	var ccw := 0.0
	for i in poly.size(): ccw += poly[i].x * poly[(i + 1) % poly.size()].y - poly[(i + 1) % poly.size()].x * poly[i].y
	for s in [-1, 1]:
		for k in range(0, tri.size(), 3):
			var idx := [tri[k], tri[k + 1], tri[k + 2]] if (s > 0) == (ccw > 0) else [tri[k], tri[k + 2], tri[k + 1]]
			for ii in idx:
				st.set_uv(poly[ii] / 2.0); st.add_vertex(Vector3(x0 + s * d / 2, poly[ii].y, poly[ii].x))
	for i in poly.size():
		var a := poly[i]; var b := poly[(i + 1) % poly.size()]
		var q := [Vector3(x0 - d / 2, a.y, a.x), Vector3(x0 + d / 2, a.y, a.x), Vector3(x0 + d / 2, b.y, b.x), Vector3(x0 - d / 2, b.y, b.x)]
		var ids := [0, 2, 1, 0, 3, 2] if ccw > 0 else [0, 1, 2, 0, 2, 3]
		for ii in ids:
			st.set_uv(Vector2(q[ii].x, q[ii].z)); st.add_vertex(q[ii])
	st.generate_normals()
	return st.commit()

## a passenger car (front = +z): [painted body, glass, tyres + trim]
static func car_meshes() -> Array:
	var body := merge([[extrude([[-2.22, .34], [-2.27, .72], [-2.08, .97], [-1.5, 1.03], [.95, 1.03], [2.0, .9], [2.27, .68], [2.22, .34], [1.65, .3], [1.38, .58], [1.1, .3], [-1.1, .3], [-1.38, .58], [-1.65, .3]], 1.78), Transform3D()],
		[box(1.48, .05, 1.32), xf(Vector3(0, 1.43, -.37))]])
	var glass := merge([[extrude([[-1.5, 1.0], [-1.08, 1.41], [.32, 1.43], [.93, 1.0]], 1.6), Transform3D()],
		[box(.32, .1, .04), xf(Vector3(-.62, .78, 2.25))], [box(.32, .1, .04), xf(Vector3(.62, .78, 2.25))]])
	var trim := []
	for z in [-1.38, 1.38]:
		for x in [-.8, .8]:
			trim.append([cyl(.33, .33, .22, 14), xf(Vector3(x, .33, z), Vector3(0, 0, PI / 2))])
	trim.append([box(1.8, .16, .12), xf(Vector3(0, .42, 2.24))]); trim.append([box(1.8, .16, .12), xf(Vector3(0, .42, -2.24))])
	trim.append([box(1.5, .1, .04), xf(Vector3(0, .8, -2.25))])
	return [body, glass, merge(trim)]
