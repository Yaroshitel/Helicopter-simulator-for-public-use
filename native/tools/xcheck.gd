extends SceneTree
## Same scripted scenario as the web version's physics run in Node (tools reference): prints state every 2 s.
const SimC := preload("res://scripts/sim.gd")
func _init():
	var mi8 := OS.get_cmdline_user_args().has("mi8")
	var s = SimC.new(mi8); s.quick()
	var dt := 1.0 / 240
	for i in 240 * 12 + 1:
		var t := i * dt
		s.C.coll = minf(.6 if mi8 else .55, s.C.coll + .3 * dt); s.C.ped = .25 if mi8 else -.2; s.C.cx = .05 * sin(t); s.C.cy = .03 * cos(t * .7); s.S.sas = t > 6
		if i % 480 == 0:
			print("%.1f %.3f %.3f %.3f %.3f %.2f %.4f %.4f %.4f" % [t, s.p.x, s.p.y, s.p.z, s.v.y, s.Om / s.Om0 * 100, s.a1, s.b1, s.q.y])
		s.step(dt)
	print("crash ", s.is_crashed)
	quit()
