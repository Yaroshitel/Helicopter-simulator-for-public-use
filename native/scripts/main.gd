extends Node3D
## Helicopter Flying Simulator — native desktop edition. Scene wiring, input, camera, day/night, lessons, HUD.

static var aircraft := ""          # "r44" / "mi8"; survives the scene reload used to switch aircraft
static var settings := {sens = 1.0, tod = 15.5, cyc = 1.0, wind = 3.0, sas = false, quality = 1, lesson = "start"}

var sim: Sim
var heli: HeliBase
var world: Node3D
var cam: Camera3D
var env: Environment
var sky_mat: ShaderMaterial
var sun: DirectionalLight3D
var moon_l: DirectionalLight3D
var moon: MeshInstance3D
var ui: UI
var audio: SimAudio
var CTRL: Dictionary
var LES: Dictionary
var L := {k = "start", done = []}

var paused := false; var ht := 0.0; var wind_spd := 3.0
var cam_mode := 0; var look := {y = .1, p = -.13}; var FWD := {y = .1, p = -.13}; var orb := {a = .6, e = .3, d = 16.0}; var fov := 68.0
var hover := ""; var keys := {}; var drag = null
var TOD := {h = 15.5, speed = 1.0}
const SUN_MAX := 1.0; const SUN_SHADOW := .65   # peak sun energy, shadow darkness (0 = none, 1 = black)
var sun_dir := Vector3(.39, .62, -.68).normalized(); var light_dir := Vector3(); var moon_dir := Vector3()
var t_now := 0.0; var pt := 0.0; var _last_tod := -1.0; var _last_cloud_t := -1.0; var _last_cam_mode := -1; var _panels_t := 0.0
var night_lights: Array; var night_windows: Array; var traffic_cars: Array = []; var traffic_mm: Array = []
var smoke: Array = []; var cloud_col := Color.WHITE; var flood: SpotLight3D; var sock_arm: Node3D
var started := false
var grass: MultiMeshInstance3D
var star_tex: Texture2D

const LAT := 50.0 * PI / 180; const DEC := 18.0 * PI / 180

var AUTO := {}   # test hook: game args after "--", e.g.  -- --air=r44 --quick --cam=2 --tod=12 --shot=/tmp/a.png --wait=4

func _ready() -> void:
	for a in OS.get_cmdline_user_args():
		var kv: PackedStringArray = a.trim_prefix("--").split("=", true, 1)
		AUTO[kv[0]] = kv[1] if kv.size() > 1 else "1"
	if AUTO.has("air") and aircraft == "": aircraft = AUTO.air
	ui = UI.new(); ui.main = self; add_child(ui)
	if aircraft == "":
		ui.show_start()
		_build_scene("r44", true)
		return
	_build_scene(aircraft, false)

func _build_scene(a: String, preview: bool) -> void:
	var mi8 := a == "mi8"
	sim = Sim.new(mi8)
	sim.crashed.connect(func(m): if AUTO.has("autoplay"): print("CRASH: ", m, " euler ", Sim.euler_yxz(sim.q), " v ", sim.v)
	)
	sim.crashed.connect(func(m): ui.show_msg("💥 " + m + "\n[font_size=15]Backspace to reset[/font_size]"))
	if world == null:
		_env()
		world = WorldBuilder.new().build(); add_child(world)
		night_lights = world.get_meta("night_lights"); night_windows = world.get_meta("night_windows")
		flood = world.get_node("Flood"); sock_arm = world.get_node("Sock/Arm")
		_traffic(world.get_meta("traffic")); _smoke(world.get_meta("smoke"))
		grass = world.get_meta("grass") if world.has_meta("grass") else null
		cam = Camera3D.new(); cam.near = .03; cam.far = 12000; cam.fov = 68; add_child(cam); cam.current = true
	heli = Mi8.new(sim) if mi8 else R44.new(sim)
	add_child(heli)
	FWD = {y = -.06, p = -.12} if mi8 else {y = .1, p = -.13}; look = FWD.duplicate(); orb.d = 34.0 if mi8 else 16.0
	CTRL = Catalog.build(sim)
	LES = Catalog.lessons(sim, func(): return ht)
	TOD.h = settings.tod; TOD.speed = settings.cyc; wind_spd = settings.wind
	_last_tod = -1.0; _last_cam_mode = -1
	apply_quality(settings.quality)
	if preview:
		started = false; cam_mode = 2; orb = {a = .9, e = .18, d = 13.0}
		sim.quick()
		return
	started = true; cam_mode = 0
	audio = SimAudio.new(); audio.sim = sim; add_child(audio)
	ui.build_game(mi8)
	reset()
	if AUTO.size(): _auto()

func _auto() -> void:
	if AUTO.has("tod"): TOD.h = float(AUTO.tod); TOD.speed = 0
	if AUTO.has("quick"): quick()
	if AUTO.has("cam"): cam_mode = int(AUTO.cam)
	if AUTO.has("orb"):
		var o: PackedStringArray = AUTO.orb.split(","); orb = {a = float(o[0]), e = float(o[1]), d = float(o[2])}
	if AUTO.has("look"):
		var o: PackedStringArray = AUTO.look.split(","); look = {y = float(o[0]), p = float(o[1])}; FWD = look.duplicate()
	if AUTO.has("manual"): ui.toggle_manual()
	if AUTO.has("nofog"): env.fog_enabled = false
	if AUTO.has("nomoon"): moon_l.queue_free(); moon_l = DirectionalLight3D.new()
	if AUTO.has("hover"):
		sim.p.y += 6.0
	if AUTO.has("autoplay"):
		set_lesson(AUTO.get("lesson", "start")); Engine.time_scale = 1.0
		return
	if AUTO.has("tour"):
		await _tour(AUTO.tour); get_tree().quit(); return
	await get_tree().create_timer(float(AUTO.get("wait", "3"))).timeout
	if AUTO.has("shot"):
		get_viewport().get_texture().get_image().save_png(AUTO.shot)
		print("SHOT saved; fps ", Engine.get_frames_per_second(), " mem ", OS.get_static_memory_usage() / 1048576, " MB")
	get_tree().quit()

## test hook: renders a set of fixed views (no UI, paused) into dir, e.g.  -- --air=r44 --quick --tour=/tmp/shots --views=ext,air
var cam_override = null
func _tour(dir: String) -> void:
	ui.visible = false; paused = true; settings.quality = int(AUTO.get("q", "2")); apply_quality(settings.quality)
	var mi8 := sim.MI8; var d := 34.0 if mi8 else 14.0
	var V := {ext = {cam = 0 + 2, orb = {a = .9, e = .2, d = d}}, rear = {cam = 2, orb = {a = 3.6, e = .35, d = d * 1.1}},
		cock = {cam = 0, look = FWD}, cockL = {cam = 0, look = {y = .75 if not mi8 else -.7, p = -.45}}, cockD = {cam = 0, look = {y = FWD.y, p = -.5}},
		air = {pos = Vector3(110, 55, 150), at = Vector3(-10, 0, -40)}, town = {pos = Vector3(640, 140, -520), at = Vector3(1150, 0, 250)},
		low = {pos = Vector3(-14, 2.0, 70), at = Vector3(-140, 2, 230)}, hills = {pos = Vector3(-500, 160, -700), at = Vector3(-1500, 60, -1700)},
		close = {cam = 2, orb = {a = .55, e = .12, d = d * .5}}, closeL = {cam = 2, orb = {a = -1.9, e = .1, d = d * .5}}, top = {cam = 2, orb = {a = 1.2, e = .9, d = d * .7}},
		night = {cam = 2, orb = {a = .9, e = .2, d = d}, tod = 22.5}, dusk = {pos = Vector3(-60, 30, 120), at = Vector3(0, 2, -40), tod = 19.6},
		river = {pos = Vector3(560, 40, -300), at = Vector3(700, -3, 300)}, plant = {pos = Vector3(950, 90, 300), at = Vector3(1200, 20, 700)}}
	var tod0: float = TOD.h
	var names: PackedStringArray = AUTO.get("views", "ext,rear,cock,cockL,air,town,low,hills,river,plant").split(",")
	for n in names:
		var v: Dictionary = V[n]
		cam_override = [v.pos, v.at] if v.has("pos") else null
		cam_mode = v.get("cam", 0)
		if v.has("orb"): orb = v.orb.duplicate()
		if v.has("look"): look = v.look.duplicate()
		TOD.h = v.get("tod", tod0); TOD.speed = 0
		for i in int(AUTO.get("frames", "6")): await get_tree().process_frame
		get_viewport().get_texture().get_image().save_png(dir.path_join(n + ".png"))
		print("SHOT ", n, " fps ", Engine.get_frames_per_second())

func _env() -> void:
	var we := WorldEnvironment.new(); env = Environment.new()
	sky_mat = ShaderMaterial.new(); sky_mat.shader = load("res://shaders/sky.gdshader"); star_tex = _stars()
	sky_mat.set_shader_parameter("night_sky", star_tex)
	var cn := FastNoiseLite.new(); cn.seed = 5; cn.frequency = .0055; cn.fractal_octaves = 4; cn.noise_type = FastNoiseLite.TYPE_SIMPLEX_SMOOTH
	var cimg := cn.get_seamless_image(512, 512, false, false, .1, true); cimg.generate_mipmaps()
	sky_mat.set_shader_parameter("cloud_noise", ImageTexture.create_from_image(cimg))
	var cc := FastNoiseLite.new(); cc.seed = 9; cc.noise_type = FastNoiseLite.TYPE_CELLULAR; cc.frequency = .018; cc.fractal_octaves = 3
	cc.cellular_return_type = FastNoiseLite.RETURN_DISTANCE; cc.cellular_jitter = .9
	var cel := cc.get_seamless_image(512, 512, false, false, .1, true); cel.generate_mipmaps()
	sky_mat.set_shader_parameter("cloud_cell", ImageTexture.create_from_image(cel))
	var sk := Sky.new(); sk.sky_material = sky_mat; sk.radiance_size = Sky.RADIANCE_SIZE_128; sk.process_mode = Sky.PROCESS_MODE_INCREMENTAL
	env.background_mode = Environment.BG_SKY; env.sky = sk
	env.ambient_light_source = Environment.AMBIENT_SOURCE_SKY; env.ambient_light_energy = 1.2; env.ambient_light_sky_contribution = .55; env.ambient_light_color = Color("c4ccd6"); env.reflected_light_source = Environment.REFLECTION_SOURCE_SKY
	env.tonemap_mode = Environment.TONE_MAPPER_ACES; env.tonemap_exposure = 1.0; env.tonemap_white = 6.0
	env.adjustment_enabled = true; env.adjustment_saturation = 1.08; env.adjustment_contrast = 1.04
	env.fog_enabled = true; env.fog_density = .00008; env.fog_light_color = Color("b9cadb"); env.fog_sky_affect = .25; env.fog_aerial_perspective = .3
	env.glow_enabled = true; env.glow_intensity = .3; env.glow_bloom = 0.0; env.glow_hdr_threshold = 1.6; env.glow_blend_mode = Environment.GLOW_BLEND_MODE_SOFTLIGHT
	we.environment = env; add_child(we)
	# the sun is a pleasant extra, not a hazard: soft, half-transparent shadows and a filled-in shade side
	sun = DirectionalLight3D.new(); sun.shadow_enabled = true; sun.light_angular_distance = .5; sun.shadow_opacity = SUN_SHADOW; sun.shadow_blur = 1.0
	sun.directional_shadow_mode = DirectionalLight3D.SHADOW_PARALLEL_4_SPLITS; sun.directional_shadow_max_distance = 400
	sun.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_AND_SKY; add_child(sun)
	moon_l = DirectionalLight3D.new(); moon_l.light_color = Color("8ea6ff"); moon_l.light_energy = 0; moon_l.sky_mode = DirectionalLight3D.SKY_MODE_LIGHT_ONLY
	moon_l.shadow_enabled = true; moon_l.shadow_opacity = .35; moon_l.directional_shadow_max_distance = 200; add_child(moon_l)
	var mimg := Image.create(128, 128, false, Image.FORMAT_RGBA8)
	for y in 128:
		for x in 128:
			var d := Vector2(x - 64, y - 64).length() / 64.0
			var c := Color(1, 1, .97, 1) if d < .22 else Color(.78, .82, 1, .35 * (1 - (d - .22) / .78))
			if d < .22 and Vector2(x - 58, y - 60).length() < 4.5: c = Color(.75, .75, .7)
			mimg.set_pixel(x, y, c)
	var mm := StandardMaterial3D.new(); mm.albedo_texture = Gfx.tex(mimg); mm.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; mm.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	mm.billboard_mode = BaseMaterial3D.BILLBOARD_ENABLED; mm.disable_fog = true; mm.billboard_keep_scale = true; mm.albedo_color = Color(2.2, 2.2, 2.2, 1)
	var q := QuadMesh.new(); q.size = Vector2(900, 900)
	moon = MeshInstance3D.new(); moon.mesh = q; moon.material_override = mm; moon.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF; add_child(moon)

func _stars() -> ImageTexture:
	var img := Image.create(2048, 1024, false, Image.FORMAT_RGB8); img.fill(Color.BLACK)
	var rng := RandomNumberGenerator.new(); rng.seed = 3
	for i in 6000:
		var x := rng.randi() % 2048; var y := rng.randi() % 512
		var b := rng.randf_range(.25, 1.0) * (3.0 if rng.randf() < .03 else 1.0)
		img.set_pixel(x, y, Color.from_hsv(.55 + rng.randf() * .15, .3, clampf(b, 0, 1)))
	return ImageTexture.create_from_image(img)

func apply_quality(qv: int) -> void:
	settings.quality = qv
	var vp := get_viewport()
	vp.msaa_3d = [Viewport.MSAA_DISABLED, Viewport.MSAA_2X, Viewport.MSAA_2X][qv]
	vp.scaling_3d_scale = [.75, 1.0, 1.0][qv]
	vp.screen_space_aa = Viewport.SCREEN_SPACE_AA_FXAA if qv == 0 else Viewport.SCREEN_SPACE_AA_DISABLED
	vp.use_debanding = qv > 0
	sun.directional_shadow_max_distance = [150.0, 320.0, 500.0][qv]
	sun.directional_shadow_split_1 = .06; sun.directional_shadow_split_2 = .18; sun.directional_shadow_split_3 = .45
	sun.directional_shadow_blend_splits = qv > 0
	RenderingServer.directional_shadow_atlas_set_size([1024, 2048, 4096][qv], true)
	RenderingServer.directional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][qv])
	RenderingServer.positional_soft_shadow_filter_set_quality([RenderingServer.SHADOW_QUALITY_SOFT_VERY_LOW, RenderingServer.SHADOW_QUALITY_SOFT_LOW, RenderingServer.SHADOW_QUALITY_SOFT_MEDIUM][qv])
	# ambient occlusion in creases (medium+), bounced light & reflections (high, tuned for smooth frame times)
	env.ssao_enabled = qv >= 1; env.ssao_radius = 1.2; env.ssao_intensity = 1.6; env.ssao_power = 1.4; env.ssao_detail = .6; env.ssao_light_affect = .1; env.ssao_ao_channel_affect = .4
	RenderingServer.environment_set_ssao_quality([RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_VERY_LOW, RenderingServer.ENV_SSAO_QUALITY_MEDIUM][qv], true, .5, 2, 50, 300)
	env.ssil_enabled = qv == 2; env.ssil_radius = 3.5; env.ssil_intensity = .75
	env.ssr_enabled = qv == 2; env.ssr_max_steps = 24; env.ssr_fade_in = .2; env.ssr_fade_out = 2.0; env.ssr_depth_tolerance = .4
	env.glow_enabled = qv > 0
	sky_mat.set_shader_parameter("exposure", .9)
	if world and world.has_meta("terrain_mat"):
		(world.get_meta("terrain_mat") as ShaderMaterial).set_shader_parameter("detail_k", [.5, .8, 1.0][qv])
	if grass:
		var gr: float = [14.0, 24.0, 34.0][qv]
		var sp: float = (grass.material_override as ShaderMaterial).get_shader_parameter("spacing")
		var n := mini(grass.multimesh.instance_count, int(PI * gr * gr / (sp * sp)))
		grass.multimesh.visible_instance_count = n
		(grass.material_override as ShaderMaterial).set_shader_parameter("radius", gr)
	if world:
		var near_end: float = [220.0, 380.0, 520.0][qv]
		var far_end: float = [2500.0, 4500.0, 7000.0][qv]
		var tree_sh := GeometryInstance3D.SHADOW_CASTING_SETTING_ON if qv > 0 else GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
		for n in world.get_tree().get_nodes_in_group("lod_near"):
			var gi := n as GeometryInstance3D; gi.visibility_range_end = near_end; gi.cast_shadow = tree_sh
		for n in world.get_tree().get_nodes_in_group("lod_far"):
			var gi := n as GeometryInstance3D; gi.visibility_range_begin = near_end - 10.0; gi.visibility_range_end = far_end

# ------------------------------------------------------------------ dynamic world
func _traffic(lanes: Array) -> void:
	var rng := RandomNumberGenerator.new(); rng.seed = 11
	var cms := Gfx.car_meshes()
	var paint := Gfx.mat(Color.WHITE, .22, .35); paint.clearcoat_enabled = true; paint.clearcoat = .6
	for i in 22:
		var P: Array = lanes[i % 4]; var L := 0.0
		for k in range(1, P.size()): L += P[k].distance_to(P[k - 1])
		traffic_cars.append({P = P, L = L, u = rng.randf(), v = (6 + rng.randf() * 6) * (1 if rng.randf() < .5 else -1), c = WorldBuilder.CARC[rng.randi() % 9]})
	for part in [[cms[0], paint, true], [cms[1], Gfx.mat(Color("101418"), .06, .4), false], [cms[2], Gfx.mat(Color("1a1b1d"), .8, .1), false]]:
		var mm := MultiMesh.new(); mm.transform_format = MultiMesh.TRANSFORM_3D; mm.use_colors = part[2]; mm.mesh = part[0]; mm.instance_count = 22
		if part[2]:
			for i in 22: mm.set_instance_color(i, traffic_cars[i].c)
			part[1].vertex_color_use_as_albedo = true
		var o := MultiMeshInstance3D.new(); o.multimesh = mm; o.material_override = part[1]; world.add_child(o); traffic_mm.append(mm)

func _upd_traffic(dt: float) -> void:
	for i in traffic_cars.size():
		var c: Dictionary = traffic_cars[i]; var P: Array = c.P
		c.u = fposmod(c.u + c.v * dt / c.L, 1.0)
		var d: float = c.u * c.L; var k := 1
		while k < P.size() - 1 and d > P[k].distance_to(P[k - 1]):
			d -= P[k].distance_to(P[k - 1]); k += 1
		var a: Vector2 = P[k - 1]; var b: Vector2 = P[k]; var sl := maxf(a.distance_to(b), 1e-3); var t := minf(1, d / sl)
		var dir := (b - a) / sl; var sd := 1.0 if c.v > 0 else -1.0
		var x := a.x + (b.x - a.x) * t - dir.y * 2.2 * sd; var z := a.y + (b.y - a.y) * t + dir.x * 2.2 * sd
		var xf := Transform3D(Basis(Vector3.UP, atan2(dir.x * sd, dir.y * sd)), Vector3(x, maxf(U.ground_h(x, z), 1.4 if absf(x - U.river_x(z)) < 78 else -1e9) + .25, z))
		for mm in traffic_mm: mm.set_instance_transform(i, xf)

## the grass patch follows the camera in whole grid steps; the rotor downwash flattens it
func _upd_grass() -> void:
	if not grass: return
	var gm := grass.material_override as ShaderMaterial
	var sp: float = gm.get_shader_parameter("spacing")
	var c := cam.global_position
	grass.global_position = Vector3(roundf(c.x / sp) * sp, 0, roundf(c.z / sp) * sp)
	grass.visible = c.y - U.ground_h(c.x, c.z) < 260
	var rr := sim.Om / sim.Om0
	var tk := clampf(sim.T / (sim.MASS * 9.81), 0, 1.4) if sim.T else 0.0
	gm.set_shader_parameter("rotor_pos", sim.p + sim.q * Vector3(0, 2.55 if sim.MI8 else 1.97, 0))
	gm.set_shader_parameter("rotor_r", sim.R)
	gm.set_shader_parameter("rotor_k", U.sstep(.2, .9, rr) * (.35 + .65 * tk) * (1.4 if sim.MI8 else 1.0))
	gm.set_shader_parameter("wind_v", sim.wind)

func _smoke(src: Array) -> void:
	var img := Image.create(64, 64, false, Image.FORMAT_RGBA8)
	for y in 64:
		for x in 64:
			var d := Vector2(x - 32, y - 32).length() / 32.0; img.set_pixel(x, y, Color(1, 1, 1, clampf(.6 * (1 - d) * 1.2, 0, 1)))
	for s in src:
		var p := CPUParticles3D.new(); p.amount = 34; p.lifetime = 28; p.preprocess = 28; p.position = s
		var m := StandardMaterial3D.new(); m.albedo_texture = Gfx.tex(img); m.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA; m.billboard_mode = BaseMaterial3D.BILLBOARD_PARTICLES
		m.vertex_color_use_as_albedo = true; m.depth_draw_mode = BaseMaterial3D.DEPTH_DRAW_DISABLED
		var q := QuadMesh.new(); q.size = Vector2(1, 1); q.material = m; p.mesh = q
		p.direction = Vector3(0, 1, 0); p.spread = 8; p.initial_velocity_min = 2.0; p.initial_velocity_max = 3.0; p.gravity = Vector3(0, .1, 0)
		p.scale_amount_min = 6; p.scale_amount_max = 8
		var sc := Curve.new(); sc.add_point(Vector2(0, 1)); sc.add_point(Vector2(1, 10)); sc.max_value = 10; p.scale_amount_curve = sc
		var g := Gradient.new(); g.set_color(0, Color(.85, .85, .85, 0)); g.set_color(1, Color(.85, .85, .85, 0)); g.add_point(.08, Color(.85, .85, .85, .7)); g.add_point(.6, Color(.85, .85, .85, .35))
		p.color_ramp = g
		world.add_child(p); smoke.append(p)

# ------------------------------------------------------------------ day / night (latitude 50° N, early summer)
func tod_update(dt: float, t: float) -> void:
	TOD.h = fposmod(TOD.h + dt * TOD.speed / 60.0, 24.0)
	# Throttle cloud_time (~15 Hz) so Sky incremental radiance cubemap doesn't re-bake every single frame
	if t - _last_cloud_t >= .066 or _last_cloud_t < 0.0:
		_last_cloud_t = t
		sky_mat.set_shader_parameter("cloud_time", t)
	if _last_tod >= 0.0 and absf(TOD.h - _last_tod) < .002:
		moon.position = cam.global_position + moon_dir * 7000
		return
	_last_tod = TOD.h
	var H: float = (TOD.h - 12) / 12 * PI; var cd := cos(DEC); var sd := sin(DEC)
	sun_dir = Vector3(-cd * sin(H), sd * sin(LAT) + cd * cos(LAT) * cos(H), -(sd * cos(LAT) - cd * sin(LAT) * cos(H))).normalized()
	moon_dir = Vector3(-sun_dir.x * .9 + .25, absf(sun_dir.y) * .8 + .15, -sun_dir.z * .9).normalized()
	var y := sun_dir.y; var day := U.sstep(-.12, .18, y); var lowK := 1 - U.sstep(.03, .35, y); var up := U.sstep(-.03, .02, y); var night := 1 - U.sstep(-.22, -.02, y)
	sky_mat.set_shader_parameter("night_k", night)
	sky_mat.set_shader_parameter("sun_e", U.sstep(-.16, .06, y))
	sky_mat.set_shader_parameter("rayleigh", 1.3 + .7 * lowK * up); sky_mat.set_shader_parameter("mie", .004 + .003 * lowK); sky_mat.set_shader_parameter("turbidity", 3.5 + 1.5 * lowK)
	sun.basis = Basis.looking_at(-sun_dir, Vector3.UP if absf(sun_dir.y) < .99 else Vector3.FORWARD)
	sun.light_color = Color("ffc896").lerp(Color("fff4e6"), U.sstep(.03, .4, y))
	sun.light_energy = SUN_MAX * U.sstep(-.03, .15, y) * (.6 + .4 * U.sstep(.08, .45, y))
	# long low-sun shadows fade out instead of blacking out half the airfield
	sun.shadow_opacity = SUN_SHADOW * U.sstep(-.02, .14, y)
	sun.shadow_enabled = y > -.03
	moon_l.basis = Basis.looking_at(-moon_dir, Vector3.UP)
	moon_l.light_energy = .25 * night; moon_l.shadow_enabled = y <= -.03 and night > .1
	light_dir = sun_dir if y > -.03 else moon_dir
	env.ambient_light_energy = .4 + .42 * day; env.ambient_light_color = Color("1c2436").lerp(Color("c4ccd6"), day)
	env.fog_light_color = Color("070b16").lerp(Color("b9cadb"), day).lerp(Color("d8a27a"), lowK * up * .3)
	env.tonemap_exposure = 1.0 + .5 * (1 - day)
	cloud_col = Color(.05, .06, .09).lerp(Color(1, 1, 1), day).lerp(Color(1, .62, .45), lowK * up * .35)
	var sc := sun.light_color * sun.light_energy * 1.6
	sky_mat.set_shader_parameter("cloud_lit", Vector3(sc.r, sc.g, sc.b) + Vector3(.03, .04, .07) * night)
	var sh := Color(.035, .04, .06).lerp(Color(.5, .55, .64), day).lerp(Color(.55, .42, .42), lowK * up * .5)
	sky_mat.set_shader_parameter("cloud_shade", Vector3(sh.r, sh.g, sh.b))
	moon.position = cam.global_position + moon_dir * 7000; moon.visible = moon_dir.y > -.05 and day < .98
	(moon.material_override as StandardMaterial3D).albedo_color.a = 1 - day
	var nk := 1 - U.sstep(-.02, .12, y)
	for l in night_lights:
		var m: StandardMaterial3D = l[0]; m.emission_energy_multiplier = .3 + 7 * nk; m.albedo_color = (l[1] as Color) * (.3 + .7 * nk)
	for w in night_windows: (w[0] as StandardMaterial3D).emission_energy_multiplier = w[1] * nk
	flood.light_energy = 6.0 * nk
	env.glow_intensity = .3 + .5 * nk
	for s in smoke:
		var g: Gradient = s.color_ramp; var cc := Color(.82, .82, .82) * cloud_col
		for i in g.get_point_count():
			var c := g.get_color(i); g.set_color(i, Color(cc.r, cc.g, cc.b, c.a))
		s.direction = Vector3(sim.wind.x * .3, 1, sim.wind.z * .3).normalized()
	if ui and ui.has_method("tod_ui"): ui.tod_ui(TOD.h)

# ------------------------------------------------------------------ lessons
func set_lesson(k: String) -> void:
	settings.lesson = k
	L = {k = k, done = []}
	for s in LES[k]: L.done.append(false)
	if k == "shut" and not (sim.S.eng[0].running if sim.MI8 else sim.S.running):
		sim.quick()
	ui.render_steps(LES[L.k], L.done)

func lesson_tick(t: float) -> void:
	var st: Array = LES[L.k]; var i: int = L.done.find(false)
	if i < 0:
		heli.highlight("", t); return
	ui.set_live("now: ENGINE %d %% · ROTOR %d %% · grip %d %%" % [roundi(sim.We / sim.Om0 * 100), roundi(sim.Om / sim.Om0 * 100), roundi(sim.S.twist * 100)])
	if st[i][2].call():
		L.done[i] = true; ui.render_steps(st, L.done); return
	heli.highlight(st[i][0], t)

func reset() -> void:
	sim.reset(); ui.hide_msg(); set_lesson(L.k if L.k else settings.lesson)

func quick() -> void:
	sim.quick(); set_lesson(L.k)

func use_control(id: String, back: bool) -> void:
	if id == "" or not CTRL.has(id): return
	var c: Dictionary = CTRL[id]
	if id == "key":
		if sim.S.key == 3 and not back:
			sim.S.key = 4; keys["_keyhold"] = true
		else: sim.S.key = clampi(sim.S.key + (-1 if back else 1), 0, 3)
		if audio: audio.click()
	elif id == "carb" and back:
		sim.S.carb = fmod(sim.S.carb + 1, 1.5)
		if audio: audio.click()
	elif c.has("a"):
		c.a.call(back)
		if audio: audio.click()

# ------------------------------------------------------------------ input
func captured() -> bool: return Input.mouse_mode == Input.MOUSE_MODE_CAPTURED
func is_alt() -> bool: return Input.is_key_pressed(KEY_ALT)

func _unhandled_input(e: InputEvent) -> void:
	if not started: return
	if e is InputEventKey and e.pressed and not e.echo:
		match e.keycode:
			KEY_C: cam_mode = (cam_mode + 1) % 3
			KEY_V: cam_mode = 0 if cam_mode else 1
			KEY_Z: look = FWD.duplicate(); fov = 68
			KEY_P: paused = not paused
			KEY_BACKSPACE: reset()
			KEY_SPACE: sim.C.tx = 0.0; sim.C.ty = 0.0
			KEY_X: sim.C.ped = 0.0
			KEY_M: ui.toggle_manual()
			KEY_N: TOD.h = fmod(TOD.h + 1, 24.0)
			KEY_H: ui.toggle_panels()
			KEY_ESCAPE:
				if ui.manual_open(): ui.toggle_manual()
				else: Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
			KEY_F11:
				var w := get_window(); w.mode = Window.MODE_WINDOWED if w.mode == Window.MODE_FULLSCREEN else Window.MODE_FULLSCREEN
	if e is InputEventMouseButton:
		if e.pressed and (e.button_index == MOUSE_BUTTON_LEFT or e.button_index == MOUSE_BUTTON_RIGHT):
			if not captured():
				var id := pick_at(e.position)
				if id != "":
					use_control(id, e.button_index == MOUSE_BUTTON_RIGHT or e.shift_pressed)
				elif e.button_index == MOUSE_BUTTON_LEFT:
					Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
				else:
					drag = e.position
			elif is_alt():
				use_control(pick_at(get_viewport().get_visible_rect().size / 2), e.button_index == MOUSE_BUTTON_RIGHT or e.shift_pressed)
		elif not e.pressed:
			drag = null
			if keys.get("_keyhold", false):
				sim.S.key = 3; keys["_keyhold"] = false
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_UP:
			if cam_mode == 0: fov = clampf(fov - 3, 25, 90)
			else: orb.d = clampf(orb.d * .9, 5, 120)
		if e.pressed and e.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			if cam_mode == 0: fov = clampf(fov + 3, 25, 90)
			else: orb.d = clampf(orb.d * 1.1, 5, 120)
	if e is InputEventMouseMotion:
		var s: float = settings.sens
		if captured():
			if is_alt():
				var k := .003 * s
				look.y -= e.relative.x * k; look.p = clampf(look.p - e.relative.y * k, -1.35, 1.2)
				if cam_mode == 2: orb.a -= e.relative.x * k * 1.5; orb.e = clampf(orb.e + e.relative.y * k * 1.5, -.2, 1.4)
			else:
				var k := .0025 * s
				sim.C.tx = clampf(sim.C.tx + e.relative.x * k, -1, 1); sim.C.ty = clampf(sim.C.ty - e.relative.y * k, -1, 1)
		elif drag != null:
			var dx: float = e.relative.x * .004; var dy: float = e.relative.y * .004
			if cam_mode == 0: look.y += dx * 1.2; look.p = clampf(look.p + dy * 1.2, -1.3, 1.2)
			else: orb.a -= dx * 1.5; orb.e = clampf(orb.e + dy * 1.5, -.2, 1.4)
		else:
			var id := pick_at(e.position); ui.show_tip(e.position, id)

func pick_at(sp: Vector2) -> String:
	if not heli: return ""
	var o := cam.project_ray_origin(sp); var d := cam.project_ray_normal(sp)
	return heli.pick(o, d, 60.0 if cam_mode else float(sim.PHY.pick))

func input_step(dt: float) -> void:
	var C := sim.C; var S := sim.S
	var tx: float = C.tx; var ty: float = C.ty
	if Input.get_connected_joypads().size() > 0:
		var j := Input.get_connected_joypads()[0]
		var dz := func(v: float) -> float: return 0.0 if absf(v) < .08 else v
		tx += dz.call(Input.get_joy_axis(j, JOY_AXIS_RIGHT_X)); ty += -dz.call(Input.get_joy_axis(j, JOY_AXIS_RIGHT_Y))
		var lx := Input.get_joy_axis(j, JOY_AXIS_LEFT_X)
		if absf(lx) > .08: C.ped = clampf(lx, -1, 1)
		C.coll = clampf(C.coll - dz.call(Input.get_joy_axis(j, JOY_AXIS_LEFT_Y)) * .4 * dt, 0, 1)
	var rt := minf(1, dt * 6)   # the stick follows the mouse with a little weight
	C.cx += (clampf(tx, -1, 1) - C.cx) * rt; C.cy += (clampf(ty, -1, 1) - C.cy) * rt
	var K := func(k: int) -> float: return 1.0 if Input.is_physical_key_pressed(k) else 0.0
	if not ui.typing():
		C.coll = clampf(C.coll + (maxf(K.call(KEY_W), K.call(KEY_PAGEUP)) - maxf(K.call(KEY_S), K.call(KEY_PAGEDOWN))) * .3 * dt, 0, 1)
		var pk: float = K.call(KEY_D) - K.call(KEY_A)
		if pk != 0: C.ped = clampf(C.ped + pk * 1.2 * dt, -1, 1)
		elif Input.get_connected_joypads().size() == 0 or absf(Input.get_joy_axis(Input.get_connected_joypads()[0], JOY_AXIS_LEFT_X)) <= .08:
			C.ped = move_toward(C.ped, 0.0, 2.0 * dt)   # keyboard pedals spring back to centre (= hold heading)
		S.twist = clampf(S.twist + (K.call(KEY_T) - K.call(KEY_G)) * .35 * dt, 0, 1)
	var fl := captured(); var al := fl and is_alt()
	if fl and not al:
		var k := minf(1, dt * 7); look.y += (FWD.y - look.y) * k; look.p += (FWD.p - look.p) * k
	ui.set_mode(al, fl)
	S.sas = settings.sas

func _process(delta: float) -> void:
	var dt := minf(.05, delta)
	if AUTO.has("autoplay"): dt = 1.0 / 30
	t_now += dt; var t := t_now
	if not sim: return
	if started:
		input_step(dt)
		if AUTO.has("autoplay"): _autopilot(dt)
		var g := wind_spd * ((1 + .2 * sin(t * .31) * sin(t * .83)) if wind_spd > 5 else 1.0)   # slow, gentle gusts
		sim.wind = Vector3(.866 * g, 0, .5 * g)
		if not paused and not sim.is_crashed:
			var n := ceili(dt * 240)
			for i in n: sim.step(dt / n)
			if sim.S.get("running", false) and sim.S.oilP > 20: sim.S.hobbs += dt / 3600
		ht = ht + dt if (sim.agl > .3 and sim.agl < 3 and sim.v.length() < 1.2 and not sim.touch) else 0.0
	heli.position = sim.p; heli.quaternion = sim.q
	heli.animate(dt, t)
	# camera
	cam.fov += (fov - cam.fov) * .2
	if cam_mode == 0:
		cam.position = sim.q * heli.cam_seat() + sim.p
		cam.quaternion = sim.q * Quaternion.from_euler(Vector3(look.p, look.y, 0))
	else:
		var e := Sim.euler_yxz(sim.q)
		var yaw: float = e.y + (look.y - FWD.y) * 1.5 if cam_mode == 1 else orb.a
		var el: float = .3 if cam_mode == 1 else orb.e
		var dd: float = (32.0 if sim.MI8 else 17.0) if cam_mode == 1 else orb.d
		var tp := Vector3(sin(yaw) * cos(el) * dd, sin(el) * dd + 1, cos(yaw) * cos(el) * dd) + sim.p
		tp.y = maxf(tp.y, U.ground_h(tp.x, tp.z) + .5)
		cam.position = cam.position.lerp(tp, .08) if cam_mode == 1 else tp
		if cam_mode == 1:
			var fw := sim.q * Vector3(0, 0, -1); fw.y = 0; fw = fw.normalized()
			cam.look_at(Vector3(sim.p.x + fw.x * 9, sim.p.y + 1, sim.p.z + fw.z * 9))
		else:
			cam.look_at(sim.p + Vector3(0, .5, 0))
	if cam_override != null:
		cam.position = cam_override[0]; cam.look_at(cam_override[1])
	tod_update(dt, t)
	sun.global_position = sim.p
	var ws := sim.wind.length()
	sock_arm.rotation = Vector3(-PI / 2 * (1 - U.sstep(0, 7, ws)) * .85, atan2(sim.wind.x, sim.wind.z), 0)
	_upd_traffic(dt)
	_upd_grass()
	if t - _panels_t > .05 or cam_mode != _last_cam_mode:
		if cam_mode == 0 or _last_cam_mode < 0:
			_panels_t = t
			heli.redraw_panels()
		_last_cam_mode = cam_mode
	if t - pt > .033:
		pt = t
		if started:
			lesson_tick(t)
			if audio: audio.update(cam_mode == 0, cam.global_position.distance_to(sim.p))
			ui.hud(self)
			if captured():
				var id := pick_at(get_viewport().get_visible_rect().size / 2) if is_alt() else ""
				if id != hover: ui.show_tip(get_viewport().get_visible_rect().size / 2, id)
			ui.refresh_tip()

func switch_aircraft(a: String) -> void:
	aircraft = a
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	paused = false; ht = 0.0; hover = ""; keys.clear(); drag = null; fov = 68.0
	if audio:
		remove_child(audio); audio.queue_free(); audio = null
	if heli:
		remove_child(heli); heli.queue_free(); heli = null
	if ui:
		remove_child(ui); ui.queue_free()
	ui = UI.new(); ui.main = self; add_child(ui)
	if a == "":
		ui.show_start()
		_build_scene("r44", true)
	else:
		_build_scene(a, false)

# ------------------------------------------------------------------ test autopilot: flies the current lesson through the real controls
var _ap_low := 0.0; var _ap_trim := 0.0; var _ap_t := 0.0; var _ap_last := -1; var _ap_clock := 0.0; var _ap_log := 0.0
func _autopilot(dt: float) -> void:
	_ap_clock += dt; _ap_t -= dt
	var st: Array = LES[L.k]; var i: int = L.done.find(false); var S := sim.S; var C := sim.C
	if i != _ap_last:
		_ap_t = .5
		print("[%6.1fs] step %d/%d: %s" % [_ap_clock, i + 1, st.size(), "DONE" if i < 0 else st[i][1]]); _ap_last = i
	if i < 0 or _ap_clock > float(AUTO.get("tmax", "900")):
		print("AUTOPLAY ", "COMPLETE" if i < 0 else "TIMEOUT", " crashed=", sim.is_crashed)
		for k in ["twist", "thr", "gi", "frac", "ice", "carb", "carbT", "key", "mix", "clutchE", "gov", "rbrake", "fuelM"]: if S.has(k): print("   ", k, " = ", S[k])
		get_tree().quit(); return
	if sim.is_crashed: print("AUTOPLAY CRASH ", ui.msg.text if ui.msg else ""); get_tree().quit(); return
	var id: String = st[i][0]; var lab: String = st[i][1]; var re := sim.We / sim.Om0
	var click := func(cid: String):
		if _ap_t <= 0: use_control(cid, false); _ap_t = 12.0   # one click, retry only if nothing happened for 12 s
	# hover controller (used once the rotor is up to speed)
	var hold = sim.Om / sim.Om0 > .9 and (id in ["coll", "cyc"]) and L.k == "start"
	if hold:
		settings.sas = true
		var e := Sim.euler_yxz(sim.q); var vb := sim.q.inverse() * sim.v
		var tgt := 1.4
		var droop := maxf(0, (.99 if not sim.MI8 else .94) - sim.Om / sim.Om0) * 3.0
		if sim.Om / sim.Om0 < .95 and sim.agl < .3: _ap_low = 3.0
		_ap_low -= dt
		if _ap_low > 0: C.coll = clampf(C.coll - .3 * dt, 0, 1)   # LOW RPM on the ground: lower the lever, let RPM recover
		else: C.coll = clampf(C.coll + ((tgt - sim.agl) * .12 - sim.v.y * .5 - droop) * dt, 0, 1)
		C.tx = clampf(e.z * 1.2 + sim.w.z * .6 - vb.x * .35, -1, 1)
		C.ty = clampf(e.x * 1.2 + sim.w.x * .6 + vb.z * .35, -1, 1)
		var yc := 1.5 * sim.w.y + .8 * U.wrap_a(e.y)
		_ap_trim = clampf(_ap_trim + yc * dt * .5, -1, 1); C.ped = clampf(_ap_trim + yc, -1, 1)
	if _ap_log <= 0 and hold:
		_ap_log = 1.0; print("   hover: agl %.2f gs %.2f vy %.2f rotor %.0f%% coll %.2f ped %.2f" % [sim.agl, sim.v.length(), sim.v.y, sim.Om / sim.Om0 * 100, C.coll, C.ped])
	_ap_log -= dt
	if hold: return
	match id:
		"twist":
			if sim.MI8: S.twist = clampf(S.twist + (1.0 if "RIGHT" in lab else -1.0) * .35 * dt, 0, 1)
			elif "crack" in lab: S.twist = .1
			elif "50–60" in lab: S.twist = clampf(S.twist + (.58 - re) * .4 * dt, 0, 1)
			elif "close" in lab: S.twist = clampf(S.twist - .35 * dt, 0, 1)
			else: S.twist = clampf(S.twist + .35 * dt, 0, 1)
		"key":
			if L.k == "shut": click.call("key") if S.key > 0 and false else (null); S.key = 0 if S.key > 0 and _ap_t <= 0 else S.key
			elif not S.running: S.key = 4
			else: S.key = 3
		"ann", "oilp", "cat":
			if not sim.MI8 and S.clutch: S.twist = clampf(S.twist + (.6 - re) * .4 * dt, 0, 1)
		"coll":
			C.coll = clampf(C.coll - .3 * dt, 0, 1)
		"rbrake":
			if L.k == "shut" and sim.Om / sim.Om0 > (.3 if sim.MI8 else .5): pass
			elif not st[i][2].call(): click.call(id)
		"mapuS":
			if not S.apu.start and not S.apu.on: click.call(id)
		"mstart":
			if not S.eng[S.sel].start and not S.eng[S.sel].running: click.call(id)
		"mcondL":
			if "AUTO" in lab:
				if S.cond[0] < 2: click.call("mcondL")
				elif S.cond[1] < 2: click.call("mcondR")
			elif "IDLE" in lab and L.k == "shut":
				if S.cond[0] > 1: use_control("mcondL", true); use_control("mcondR", true)
			elif "STOP" in lab:
				if S.cond[0] > 0 and _ap_t <= 0: use_control("mcondL", true); use_control("mcondR", true); _ap_t = .6
			else: click.call("mcondL")
		"mfcL":
			if _ap_t <= 0:
				var want = L.k == "start"
				if S.fcock[0] != want: use_control("mfcL", false)
				if S.fcock[1] != want: use_control("mfcR", false)
				_ap_t = .6
		"mgenL":
			if _ap_t <= 0:
				var want = L.k == "start"
				if S.genL != want: use_control("mgenL", false)
				if S.genR != want: use_control("mgenR", false)
				_ap_t = .6
		"msvc":
			if L.k == "start": click.call(id) if not S.svc else null
			elif _ap_t <= 0:
				if S.svc: use_control("msvc", false)
				if S.pL or S.pR: use_control("mpL", false)
				_ap_t = .6
		"mhyd":
			if not st[i][2].call() and (S.hyd != (L.k == "start")): click.call(id)
		_:
			if CTRL.has(id) and CTRL[id].has("a") and not st[i][2].call(): click.call(id)
