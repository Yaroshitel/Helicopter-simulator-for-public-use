extends SceneTree
## Handling characterisation: godot --headless -s tools/feel.gd [-- mi8]
## Trims a hover with a height-hold on the collective only, then measures responses to small inputs.
const SimC := preload("res://scripts/sim.gd")
var s
var dt := 1.0 / 240.0

func hover_hold(tgt := 6.0) -> void:
	s.C.coll = clampf(s.C.coll + ((tgt - s.agl) * .15 - s.v.y * .6) * dt, 0, 1)

func lift(mi8: bool, wind := Vector3()) -> void:
	s = SimC.new(mi8); s.quick(); s.wind = Vector3(); s.crashed.connect(func(m): print("   CRASH: ", m, " agl ", s.agl, " p ", s.p))
	for i in int(240 * 3): s.step(dt)
	# climb to 6 m with the game's own lesson autopilot laws, then hand the controls back
	var trim := 0.0
	for i in int(240 * 30):
		hover_hold()
		var e: Vector3 = SimC.euler_yxz(s.q); var vb: Vector3 = s.q.inverse() * s.v
		var tx := clampf(e.z * 1.2 + s.w.z * .6 - vb.x * .35, -1, 1); var ty := clampf(e.x * 1.2 + s.w.x * .6 + vb.z * .35, -1, 1)
		s.C.cx += (tx - s.C.cx) * dt * 12; s.C.cy += (ty - s.C.cy) * dt * 12
		var yc: float = 1.5 * s.w.y + .8 * U.wrap_a(e.y)
		trim = clampf(trim + yc * dt * .5, -1, 1); s.C.ped = clampf(trim + yc, -1, 1)
		s.wind = wind * minf(1, i / 2400.0)
		s.step(dt)

func report(tag: String, secs: float, f: Callable) -> void:
	var p0: Vector3 = s.p; var e0: Vector3 = SimC.euler_yxz(s.q)
	var out := tag + ":"
	for i in int(240 * secs):
		hover_hold(); f.call(i * dt); s.step(dt)
		if (i + 1) % 120 == 0 and (i + 1) <= 480:
			var e: Vector3 = SimC.euler_yxz(s.q) - e0
			out += "  t%.1f[p%+.0f r%+.0f y%+.0f° wx%+.0f wz%+.0f°/s]" % [(i + 1) * dt, rad_to_deg(e.x), rad_to_deg(e.z), rad_to_deg(e.y), rad_to_deg(s.w.x), rad_to_deg(s.w.z)]
	var d: Vector3 = s.p - p0
	out += "  drift after %.0fs: %.1f m (x%+.1f z%+.1f) crashed %s" % [secs, Vector2(d.x, d.z).length(), d.x, d.z, s.is_crashed]
	print(out)

func _init():
	var mi8 := OS.get_cmdline_user_args().has("mi8")
	print("== ", "Mi-8" if mi8 else "R44")
	var cx0: float; var cy0: float; var pd0: float
	lift(mi8); cx0 = s.C.cx; cy0 = s.C.cy; pd0 = s.C.ped
	print("trim: coll %.2f cx %.3f cy %.3f ped %.2f yawrate %.1f°/s" % [s.C.coll, cx0, cy0, pd0, rad_to_deg(s.w.y)])
	report("hands-off (trim held)", 8, func(t): pass)
	lift(mi8); var c0: float = s.C.cy
	report("+10% fwd cyclic 1s", 4, func(t): s.C.cy = c0 + (.1 if t < 1 else 0.0))
	lift(mi8); c0 = s.C.cx
	report("+10% right cyclic 1s", 4, func(t): s.C.cx = c0 + (.1 if t < 1 else 0.0))
	lift(mi8); c0 = s.C.ped
	report("+20% pedal 1s", 4, func(t): s.C.ped = c0 + (.2 if t < 1 else 0.0))
	lift(mi8); c0 = s.C.ped
	var cl: float = s.C.coll
	report("collective +10% (pedals fixed)", 4, func(t): s.C.coll = cl + .1)
	print("   yaw rate after collective step: %.1f°/s" % rad_to_deg(s.w.y))
	lift(mi8); c0 = s.C.cy
	report("+50% fwd cyclic 1s", 4, func(t): s.C.cy = c0 + (.5 if t < 1 else 0.0))
	lift(mi8); c0 = s.C.cx
	report("+100% right cyclic 1s", 4, func(t): s.C.cx = c0 + (1.0 if t < 1 else 0.0))
	lift(mi8); c0 = s.C.ped
	report("+100% pedal 2s", 4, func(t): s.C.ped = c0 + (1.0 if t < 2 else 0.0))
	lift(mi8); c0 = s.C.cy
	var spd := []
	report("cruise: 40% fwd held, 40s", 40, func(t):
		s.C.cy = c0 + .4
		if int(t * 240) % (240 * 4) == 0: spd.append("%.0fkt/%.0f° agl%.0f" % [-(s.q.inverse() * s.v).z * 1.944, rad_to_deg(SimC.euler_yxz(s.q).x), s.agl]))
	print("   speed/pitch every 5 s: ", spd)
	lift(mi8, Vector3(.866 * 9, 0, .5 * 9))
	report("18 kt wind, hands-off", 8, func(t): pass)
	quit()
