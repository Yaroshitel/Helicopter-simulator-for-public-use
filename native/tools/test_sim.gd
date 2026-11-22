extends SceneTree
## Headless checks of the ported flight model: godot --headless -s tools/test_sim.gd
const SimC := preload("res://scripts/sim.gd")

func run(s, secs: float, f := Callable()) -> void:
	var dt := 1.0 / 240.0
	for i in int(secs * 240):
		if f.is_valid(): f.call(i * dt)
		s.step(dt)

func _init():
	var fails := 0
	# 1. R44 quick start → raise collective to a hover
	var s = SimC.new(false); s.quick(); s.S.twist = .25
	run(s, 2.0)
	print("R44 idle on pad: rotor %.0f%% eng %.0f%% y=%.2f" % [s.Om / s.Om0 * 100, s.We / s.Om0 * 100, s.p.y])
	var hov := func(t: float):
		s.C.coll = clampf(s.C.coll + .3 / 240.0, 0, .58)
		s.C.ped = -.25
	run(s, 6.0, hov)
	print("R44 after collective up: agl %.2f m  vy %.2f  rotor %.0f%%  yaw-rate %.2f  crashed %s" % [s.agl, s.v.y, s.Om / s.Om0 * 100, s.w.y, s.is_crashed])
	if s.agl < .3: print("  FAIL: R44 did not lift off"); fails += 1
	# 2. R44 cold start per lesson
	s = SimC.new(false)
	s.S.rbrake = false; s.S.fuelV = true; s.S.batt = true; s.S.strobe = true; s.S.mix = true; s.S.twist = .1; s.S.key = 4
	run(s, 4.0)
	s.S.key = 3
	run(s, 3.0)
	print("R44 cold start: running %s eng %.0f%% oilP %.0f" % [s.S.running, s.We / s.Om0 * 100, s.S.oilP])
	if not s.S.running: print("  FAIL: R44 engine did not start"); fails += 1
	s.S.alt = true; s.S.clutch = true
	# hold engine 50-70 % like the lesson
	run(s, 30.0, func(t): s.S.twist = clampf(s.S.twist + (.6 - s.We / s.Om0) * .5 / 240.0, 0, 1))
	s.S.gov = true
	run(s, 15.0, func(t): s.S.twist = minf(1, s.S.twist + .1 / 240.0))
	print("R44 after clutch+gov: clutchE %.2f rotor %.0f%% eng %.0f%%" % [s.S.clutchE, s.Om / s.Om0 * 100, s.We / s.Om0 * 100])
	if s.Om / s.Om0 < .99: print("  FAIL: governor did not bring rotor to 101-102 %"); fails += 1
	# 3. Mi-8 cold start per lesson
	var m = SimC.new(true)
	m.S.rbrake = false; m.S.batt = true; m.S.beacon = true; m.S.svc = true; m.S.pL = true; m.S.pR = true; m.S.fcock = [true, true]; m.S.apuReq = true
	run(m, 25.0)
	print("Mi-8 APU: on %s air %.1f" % [m.S.apu.on, m.S.apu.air])
	m.S.cond[0] = 1; m.S.sel = 0; m.S.eng[0].merge({start = true, st = 0.0}, true)
	run(m, 50.0)
	m.S.cond[1] = 1; m.S.sel = 1; m.S.eng[1].merge({start = true, st = 0.0}, true)
	run(m, 50.0)
	print("Mi-8 engines: Ng %.0f / %.0f  EGT %.0f  rotor %.0f%%" % [m.S.eng[0].ng, m.S.eng[1].ng, m.S.eng[0].egt, m.Om / m.Om0 * 100])
	m.S.genL = true; m.S.genR = true; m.S.apu.on = false; m.S.hyd = true; m.S.cond = [2, 2]; m.S.twist = 1.0; m.S.pbrake = false
	run(m, 40.0)
	print("Mi-8 AUTO: rotor %.0f%%  hydP %.0f  Ng %.0f" % [m.Om / m.Om0 * 100, m.S.hydP, m.S.eng[0].ng])
	if m.Om / m.Om0 < .93: print("  FAIL: Mi-8 rotor not at 95 %"); fails += 1
	run(m, 10.0, func(t): m.C.coll = clampf(m.C.coll + .2 / 240.0, 0, .62); m.C.ped = .25)
	print("Mi-8 lift: agl %.2f vy %.2f crashed %s" % [m.agl, m.v.y, m.is_crashed])
	if m.agl < .3: print("  FAIL: Mi-8 did not lift off"); fails += 1
	# euler convention check: pure yaw of +0.5 rad about +Y
	var e: Vector3 = SimC.euler_yxz(Quaternion(Vector3.UP, .5) * Quaternion(Vector3.RIGHT, .2))
	print("euler yxz of yaw .5 pitch .2 -> ", e)
	print("FAILS: ", fails)
	quit(fails)
