class_name Sim extends RefCounted
## Flight model, engines and aircraft systems. A line-by-line port of the web simulator's physics.
## Body axes: x right, y up, z aft (nose points to -z).

signal crashed(msg: String)

var MI8 := false
var PHY: Dictionary
var Om0: float; var R: float; var SIG: float; var CD0: float; var MASS: float
var Ix: float; var Iy: float; var Iz: float; var IR: float; var DIR: float; var AR: float
const CLA := 5.7
const QMAX := 4500.0
const IE := 20.0
var HUB: Vector3; var TRP: Vector3; var TAIL: Vector3

# flight state (F)
var p := Vector3(); var v := Vector3(); var q := Quaternion(); var w := Vector3()
var Om := 0.0; var We := 0.0; var li := .03; var lam := .03; var a1 := 0.0; var b1 := 0.0
var T := 0.0; var vrs := 0.0; var is_crashed := false; var touch := false; var agl := 0.0
var th := 0.0; var mu := 0.0; var Qd := 0.0; var Ttr := 0.0
var sas := {p = 0.0, r = 0.0, y = 0.0, x = 0.0, z = 0.0, d = 0.0, sc = 0.0, sp = 0.0, pc = [0.0, 0.0, 0.0]}

var S := {}                                                     # systems / switches
var C := {cx = 0.0, cy = 0.0, tx = 0.0, ty = 0.0, coll = 0.0, ped = 0.0}   # controls
var wind := Vector3()
var CPTS: Array = []
var HQ: Dictionary                 # handling qualities: max rates (pitch, roll, yaw rad/s), response lags (s), self-levelling (1/s)
var Qref := 0.0                    # slowly-following rotor torque: only torque CHANGES kick the nose round

func _init(mi8: bool) -> void:
	MI8 = mi8
	if MI8:
		PHY = {Om0 = 21.16, R = 10.645, SIG = .078, CD0 = .0095, MASS = 10500.0, Ix = 85000.0, Iy = 80000.0, Iz = 24000.0, IR = 26000.0,
			HUB = Vector3(0, 2.55, 0), TRP = Vector3(-.42, 2.7, 10.62), TAIL = Vector3(0, .9, 9.6),
			TH0 = .017, THR = .245, ST = [.7, .85], DIR = -1.0, TRK = 16000.0, TRB = .3, TRG = .7, TRC = 600.0, TRA = 12.0, TRP0 = 40000.0,
			FD = [40.0, 60.0, 4.0], FIN = 14.0, STB = 12.0, DMP = [3000.0, 5000.0, 1500.0], SAS = {wn = [1.0, 1.1, .8], A = [.2, .2, .15]},
			KH = 150000.0, b1r = .046, kc = [1.2e6, 1e5, 4e5, 4e4], y0 = 1.87, agl0 = 1.9, vyLim = -4.0, cyc = [.12, .10], pick = 3.2, lag = .12,
			cpts = [[0, -1.9, -3.6, "n"], [2.25, -1.9, .65, "w"], [-2.25, -1.9, .65, "w"], [0, -.95, 10.35, "t"]],
			HQ = {rate = [.38, .50, .42], tau = [1.0, .8, 1.1], lev = .32, tilt = .035, torq = .22}}
	else:
		PHY = {Om0 = 42.7, R = 5.03, SIG = .032, CD0 = .0095, MASS = 1100.0, Ix = 2600.0, Iy = 2500.0, Iz = 750.0, IR = 550.0,
			HUB = Vector3(0, 1.97, 0), TRP = Vector3(-.26, .55, 6.38), TAIL = Vector3(0, .45, 6.0),
			TH0 = .012, THR = .22, ST = [.6, .8], DIR = 1.0, TRK = 1500.0, TRB = .12, TRG = .88, TRC = 45.0, TRA = 1.7, TRP0 = 2500.0,
			FD = [5.5, 6.0, 1.1], FIN = 1.6, STB = 1.5, DMP = [100.0, 200.0, 60.0], SAS = {wn = [1.3, 1.6, 0.0], A = [.2, .2, 0.0]},
			KH = 0.0, b1r = 0.0, kc = [8e4, 8e3, 3e4, 3e3], y0 = 1.13, agl0 = 1.12, vyLim = -3.6, cyc = [.17, .13], pick = 2.5, lag = .07,
			cpts = [[1.1, -1.1, -1.4, ""], [-1.1, -1.1, -1.4, ""], [1.1, -1.1, 1.15, ""], [-1.1, -1.1, 1.15, ""], [0, -.33, 6.62, "t"]],
			HQ = {rate = [.62, .85, .85], tau = [.55, .45, .6], lev = .38, tilt = .045, torq = .25}}
	Om0 = PHY.Om0; R = PHY.R; SIG = PHY.SIG; CD0 = PHY.CD0; MASS = PHY.MASS; Ix = PHY.Ix; Iy = PHY.Iy; Iz = PHY.Iz; IR = PHY.IR; DIR = PHY.DIR
	AR = PI * R * R; HUB = PHY.HUB; TRP = PHY.TRP; TAIL = PHY.TAIL
	for a in PHY.cpts: CPTS.append({r = Vector3(a[0], a[1], a[2]), t = a[3], anc = null})
	HQ = PHY.HQ
	reset()

## three.js Euler 'YXZ' decomposition (x = pitch, y = yaw, z = roll)
static func euler_yxz(qq: Quaternion) -> Vector3:
	var b := Basis(qq)
	var m23 := b.z.y; var e := Vector3()
	e.x = asin(-clampf(m23, -1, 1))
	if absf(m23) < 0.9999999:
		e.y = atan2(b.z.x, b.z.z); e.z = atan2(b.x.y, b.y.y)
	else:
		e.y = atan2(-b.x.z, b.x.x); e.z = 0
	return e

func reset() -> void:
	p = Vector3(0, PHY.y0, 0); v = Vector3(); q = Quaternion(); w = Vector3()
	Om = 0; We = 0; li = .03; a1 = 0; b1 = 0; is_crashed = false
	sas.x = 0.0; sas.z = 0.0; sas.d = 0.0; Qref = 0.0; sas.sc = 1.0; sas.sp = 1.0
	S.clear(); S.merge({batt = false, alt = false, avion = false, gov = false, strobe = false, nav = false, ldg = false, clutch = false, clutchE = 0.0, key = 0, mix = false, carb = 0.0, fuelV = false, rbrake = true,
		twist = 0.0, running = false, fuelM = 24.0, fuelA = 14.0, oilT = 59.0, oilP = 0.0, cht = 59.0, ice = 0.0, batQ = 1.0, gi = 0.0, thr = 0.0, frac = 0.0, carbT = 15.0, amps = 0.0,
		starter = false, cm = false, elec = false, low = false, hb = 1.0, sas = false, vsi = 0.0, map = 0.0, hobbs = 1234.5})
	if MI8:
		S.merge({eng = [{ng = 0.0, running = false, start = false, st = 0.0, egt = 15.0, oil = 0.0, p = 0.0}, {ng = 0.0, running = false, start = false, st = 0.0, egt = 15.0, oil = 0.0, p = 0.0}],
			apu = {n = 0.0, on = false, start = false, egt = 15.0, air = 0.0}, cond = [0, 0], fcock = [false, false],
			svc = false, pL = false, pR = false, genL = false, genR = false, hyd = false, sel = 0, pbrake = true, beacon = false, fuel = 1800.0, hydP = 0.0, hydB = 0.0, mgbP = 0.0, mgbT = 15.0, volts = 0.0, apuReq = false}, true)
	C.merge({cx = 0.0, cy = 0.0, tx = 0.0, ty = 0.0, coll = 0.0, ped = 0.0}, true)
	for c in CPTS: c.anc = null

func quick() -> void:
	reset()
	if MI8:
		S.merge({batt = true, genL = true, genR = true, hyd = true, nav = true, beacon = true, svc = true, pL = true, pR = true, fcock = [true, true], cond = [2, 2], rbrake = false, pbrake = false, twist = 1.0, gi = .25}, true)
		for E in S.eng: E.merge({ng = 80.0, running = true, egt = 650.0, oil = 3.5}, true)
		Om = .95 * Om0; C.ped = 0.0
		return
	S.merge({batt = true, alt = true, avion = true, gov = true, strobe = true, nav = true, clutch = true, clutchE = 1.0, key = 3, mix = true, fuelV = true, rbrake = false, twist = .25, running = true, oilT = 180.0, oilP = 80.0, cht = 330.0}, true)
	Om = 1.02 * Om0; We = Om; C.ped = 0.0

func crash(t: String) -> void:
	if is_crashed: return
	is_crashed = true
	crashed.emit(t)

# SAS: a limited-authority attitude hold that moves the controls through series actuators (see the manual).
func sas_step(dt: float, r: float) -> Vector3:
	var A := sas; var e := euler_yxz(q); var pp := e.x; var rl := e.z; var y := e.y
	var on: bool = S.sas and r > .9 and not touch and S.elec != false
	var pc: Array = A.pc
	var mv: float = absf(C.cx - pc[0]) + absf(C.cy - pc[1]); var mp: float = absf(C.ped - pc[2]); pc[0] = C.cx; pc[1] = C.cy; pc[2] = C.ped
	var ra := Vector2(w.x, w.z).length() < .05; var ry := absf(w.y) < .05
	A.sc = A.sc - dt if (on and mv < .12 * dt and (ra or A.sc <= 0)) else .5
	A.sp = A.sp - dt if (on and mp < .05 * dt and (ry or A.sp <= 0)) else .5
	if A.sc > 0: A.p = pp; A.r = rl
	if A.sp > 0: A.y = y
	var R0: Array = HQ.rate; var lim: Array = PHY.SAS.A
	var dp := 0.0 if A.sc > 0 else (pp - A.p)
	var dr := 0.0 if A.sc > 0 else (rl - A.r)
	var ty := clampf((1.2 * dp + .5 * w.x) / R0[0], -lim[0], lim[0]) if on else 0.0
	var tx := clampf((1.2 * dr + .5 * w.z) / R0[1], -lim[1], lim[1]) if on else 0.0
	var tz := 0.0
	if on and lim[2] > 0:
		tz = clampf((.8 * (0.0 if A.sp > 0 else U.wrap_a(y - A.y)) + .5 * w.y) / R0[2], -lim[2], lim[2])
	A.d = A.d + clampf(ty - A.d, -.8 * dt, .8 * dt); A.x = A.x + clampf(tx - A.x, -.8 * dt, .8 * dt); A.z = A.z + clampf(tz - A.z, -.8 * dt, .8 * dt)
	return Vector3(A.x, A.d, A.z)   # x = roll, y = pitch, z = yaw

## stick shaping: small movements do very little, the last third of travel gives the real authority
static func shape(x: float) -> float:
	x = clampf(x, -1, 1)
	return .25 * x + .75 * x * x * x

func _ap(x: float, t: float, k: float, dt: float) -> float:
	return x + (t - x) * minf(1, k * dt)

func step(dt: float) -> void:
	var qi := q.inverse(); var rho := 1.225 * exp(-maxf(0, p.y) / 9000.0); var dr := rho / 1.225; var h5 := .5 * rho; var hb: float = S.hb
	var vb := qi * (v - wind); var r := Om / Om0; var OR := maxf(Om * R, 5.0); var u := -vb.z
	mu = Vector2(vb.x, vb.z).length() / OR
	# Handling: cyclic and pedals command a rotation rate that builds and decays with the inertia of the airframe
	# (rotor hub moment and rotor damping lumped together). The disc itself tilts only a little with the stick,
	# so the aircraft moves mostly by changing attitude - heavy and deliberate, not twitchy.
	th = PHY.TH0 + C.coll * PHY.THR
	var sv := sas_step(dt, r)
	var tilt: float = HQ.tilt * hb
	var k := minf(1, dt / PHY.lag)
	a1 += (shape(C.cy) * tilt - a1) * k; b1 += (shape(C.cx) * tilt - b1) * k
	var n := Vector3(sin(b1), cos(a1) * cos(b1), -sin(a1)); var lc := vb.dot(n) / OR
	# momentum inflow (induced-power factor 1.15) with dynamic inflow
	const KAP := 1.15
	var mu2 := mu * mu
	var le := li
	for i in 6:
		var lm := lc + le
		var ct := SIG * CLA / 2 * (th * (1.0 / 3 + mu2 / 2) - lm / 2)
		le += (KAP * maxf(ct, 0) / (2 * maxf(Vector2(mu, lm).length(), .015)) - le) * .5
	li += (le - li) * minf(1, dt * 4 * maxf(Om, 1) * maxf(Vector2(mu, lc + li).length(), .02) / .85)
	var CT := SIG * CLA / 2 * (th * (1.0 / 3 + mu2 / 2) - (lc + li) / 2); lam = lc + li
	var lh := sqrt(maxf(CT, 1e-4) / 2); var dsc := -lc / lh
	vrs = maxf(0, 1 - absf(dsc - .95) / .6) * (1 - mu / .08) if (r > .5 and mu < .08) else 0.0
	var hw := q * HUB + p; var hA := hw.y - U.ground_h(hw.x, hw.z); var ge := 1.0
	if hA < R * 1.5:
		ge = minf(1.35, 1 / (1 - pow(R / (4 * maxf(hA, R * .3)), 2))); ge = 1 + (ge - 1) * maxf(0, 1 - mu / .12)
	T = CT * (1 - .4 * vrs) * ge * U.sstep(PHY.ST[0], PHY.ST[1], r) * rho * AR * Om * Om * R * R
	var Qr := (maxf(CT, 0) * (lc + li) + SIG * CD0 / 8 * (1 + 4.6 * mu2)) * rho * AR * Om * Om * R * R * R
	# tail rotor: the thrust it needs to cancel main-rotor torque plus whatever the pedals ask for (for power, sound)
	Ttr = clampf(DIR * Qd / TRP.z - C.ped * PHY.TRK * PHY.TRG * .5 * r * r * dr, -2.5 * PHY.TRK * r * r, 2.5 * PHY.TRK * r * r) if Om > 1 else 0.0
	var Qtr: float = (absf(Ttr) * sqrt(absf(Ttr) / (2 * rho * PHY.TRA)) / .75 + PHY.TRP0 * r * r * r) / Om if Om > 1 else 0.0
	# engine & drive
	Qd = 0.0
	if MI8:
		Qd = mi8_drive(dt, Qr + Qtr, r)
	else:
		r44_drive(dt, Qr + Qtr, dr)
	# forces (body). The mast/rotor rigging cancels the tail rotor's sideways push, so it is not applied.
	var f := n * T; var m := Vector3()
	var FD: Array = PHY.FD
	f.x -= h5 * FD[0] * vb.x * absf(vb.x); f.y -= h5 * FD[1] * vb.y * absf(vb.y); f.z -= h5 * FD[2] * vb.z * absf(vb.z)
	# rotor authority needs rotor RPM, hydraulics and some thrust (no lift = little control, like a real disc)
	var lf := clampf(T / (MASS * 9.81), 0, 1.2)
	var au := U.sstep(.45, .9, r) * (.25 + .75 * minf(lf, 1)) * (1.0 if hb >= 1 else .45)
	var eu := euler_yxz(q); var RT: Array = HQ.rate; var TA: Array = HQ.tau; var lev: float = HQ.lev
	# self-levelling grows with angle, so a held stick settles at a held attitude (full stick = steep, never a flip)
	var lvx := lev * (eu.x + 1.5 * eu.x * eu.x * eu.x)
	var lvz := lev * (eu.z + 1.5 * eu.z * eu.z * eu.z)
	# commanded rates: + cyclic fwd = nose down (w.x < 0), + right = roll right (w.z < 0), + right pedal = yaw right (w.y < 0)
	var wxc: float = -RT[0] * (shape(C.cy) + sv.y) - lvx
	var wzc: float = -RT[1] * (shape(C.cx) + sv.x) - lvz
	var wyc: float = -RT[2] * (shape(C.ped) + sv.z)
	if touch: wyc *= .5
	m.x += Ix * (wxc - w.x) / TA[0] * au
	m.z += Iz * (wzc - w.z) / TA[1] * au
	# torque reaction: only a change in rotor torque swings the nose (raise collective fast -> a gentle yaw to correct)
	Qref += (Qd - Qref) * minf(1, dt / 2.5)
	m.y += Iy * (wyc - w.y) / TA[2] * au - DIR * HQ.torq * (Qd - Qref)
	# fin / stabiliser: weathervaning that grows with airspeed; only a whisper in the hover
	var vt := w.cross(TAIL) + vb; var sp := absf(u) * U.sstep(3, 20, absf(u)) + .5
	var fin := Vector3(-h5 * PHY.FIN * sp * vt.x, -h5 * PHY.STB * sp * vt.y * .3, 0); f += fin; m.y += (TAIL.cross(fin)).y
	var D: Array = PHY.DMP
	m.x -= w.x * D[0]; m.y -= w.y * D[1]; m.z -= w.z * D[2]
	# ground contact: skids/tail use a static-friction anchor; wheels roll (nose wheel castors, mains brake with the parking brake)
	var Fw := q * f; var K: Array = PHY.kc; var K0: float = K[0]; var K1: float = K[1]; var K2: float = K[2]; var K3: float = K[3]
	var gh_c := U.ground_h(p.x, p.z)
	agl = p.y - gh_c - PHY.agl0
	touch = false
	if agl < 25.0:
		for c in CPTS:
			var pw: Vector3 = q * c.r + p; var pen := U.ground_h(pw.x, pw.z) - pw.y
			if pen <= 0:
				c.anc = null; continue
			touch = true
			var vp: Vector3 = q * w.cross(c.r) + v
			var fn := maxf(0, K0 * pen - K1 * vp.y); var lim := .55 * fn; var fc: Vector3
			if c.t == "n" or (c.t == "w" and not S.get("pbrake", false)):
				c.anc = null
				var vpb := qi * vp; var fl := K3 * 4 if c.t == "w" else K3 * .08
				fc = q * Vector3(clampf(-fl * vpb.x, -lim, lim), 0, clampf(-2000 * vpb.z, -.03 * fn, .03 * fn)); fc.y = fn
			else:
				if c.anc == null: c.anc = pw
				var fx: float = -K2 * (pw.x - c.anc.x) - K3 * vp.x; var fz: float = -K2 * (pw.z - c.anc.z) - K3 * vp.z
				var ft := Vector2(fx, fz).length()
				if ft > lim:
					fx *= lim / ft; fz *= lim / ft; c.anc = pw
				fc = Vector3(fx, fn, fz)
			Fw += fc; m += c.r.cross(qi * fc)
			if vp.y < (-2.2 if c.t == "t" else PHY.vyLim):
				crash("Tail rotor / tail bumper strike" if c.t == "t" else "Hard landing (%d ft/min)" % roundi(-vp.y * 197))
			if c.t == "" and Vector2(vp.x, vp.z).length() > 13: crash("Skids caught the ground at speed — rollover")
	else:
		for c in CPTS: c.anc = null
	if touch:
		var e := euler_yxz(q)
		if absf(e.z) > .55 or e.x < -.5 or e.x > .6: crash("Dynamic rollover — blades struck the ground")
	if not MI8 and agl > 2 and T < .15 * MASS * 9.81 and r > .8 and absf(w.z) > .7: crash("Mast bumping (low-G + roll)")
	Fw.y -= MASS * 9.81; v += Fw * (dt / MASS); p += v * dt
	w.x += m.x / Ix * dt; w.y += m.y / Iy * dt; w.z += m.z / Iz * dt
	q = (q * Quaternion(w.x * dt / 2, w.y * dt / 2, w.z * dt / 2, 1)).normalized()
	if MI8:
		S.low = S.elec and r < .88 and (S.eng[0].running or S.eng[1].running)
	else:
		S.low = S.elec and r < .97 and C.coll > .03

# Lycoming O-540, belt clutch, sprag clutch, governor, carb ice, electrics
func r44_drive(dt: float, Ql0: float, dr: float) -> void:
	var re := We / Om0; var mags := 0.0 if S.key == 0 else (1.0 if S.key >= 3 else .96)
	S.elec = S.batt and S.batQ > .03
	var thr: float = S.twist + .4 * C.coll; var gv: bool = S.gov and S.elec and re > .8 and re < 1.2
	if gv:
		var e := 1.02 - re; S.gi = clampf(S.gi + e * 2 * dt, -1, 1); thr += S.gi + e * 10
	else:
		S.gi *= 1 - dt
	thr = clampf(thr, 0, 1); S.thr = thr
	S.carbT = 11 - 12 * (1 - thr) * clampf(re / .6, 0, 1) + S.carb * 32 * clampf(re / .5, 0, 1)
	if S.running:
		if S.carbT > -15 and S.carbT < 5: S.ice = minf(.6, S.ice + dt * .0005)
		elif S.carbT >= 5: S.ice = maxf(0, S.ice - dt * .03)
	var fuelOK: bool = S.fuelV and S.mix and S.fuelM > 0
	if S.running and (not fuelOK or mags == 0 or re < .05 or S.ice > .55): S.running = false
	if not S.running and fuelOK and mags > 0 and re > .08 and thr < .6: S.running = true
	S.starter = S.key == 4 and S.elec
	var Qs := maxf(0, 800 * (1 - re / .14)) if S.starter else 0.0
	S.frac = maxf(0, (.03 + .97 * pow(thr, 1.5)) * mags * (1 - S.ice) * (1 - .07 * S.carb) * minf(1, dr * 1.02) - .05 * re) * clampf(re * 2.5, 0, 1) if S.running else 0.0
	var Qn: float = QMAX * S.frac + Qs - ((30 + 320 * re * re + (0.0 if S.running else 220.0)) if We > .01 else 0.0)
	var Ql: float = Ql0 + ((30 + (1200.0 if S.rbrake else 0.0)) if Om > .01 else 0.0)
	var tgt := 1.0 if S.clutch else 0.0; S.cm = false
	if S.elec and S.clutchE != tgt:
		S.clutchE = clampf(S.clutchE + signf(tgt - S.clutchE) * dt / 9, 0, 1); S.cm = true
	if S.clutchE >= 1 and We >= Om - .3 and We <= Om + .6:
		var aE := Qn / IE; var aR := -Ql / IR; var aC := (Qn - Ql) / (IE + IR)
		if aR > aE:
			We += aE * dt; Om += aR * dt
		else:
			Om += aC * dt; We = Om; Qd = Ql + IR * aC
	else:
		var e: float = S.clutchE
		Qd = clampf(e * e * 3000 * (We - Om), 0, minf(e * e * 1500, maxf(0, Qn * .9 + (We - .35 * Om0) * 60)))
		We += (Qn - Qd) / IE * dt; Om += (Qd - Ql) / IR * dt
	We = maxf(0, We); Om = maxf(0, Om)
	if S.running:
		S.fuelM = maxf(0, S.fuelM - (2.5 + 16 * S.frac * re) / 3600 * dt)
		if S.fuelA > 0 and S.fuelM < 29:
			var t := minf(S.fuelA, dt * .004); S.fuelA -= t; S.fuelM += t
	S.oilP = _ap(S.oilP, clampf(18 + 75 * re, 0, 92) if S.running else 0.0, 1.5, dt)
	S.oilT = _ap(S.oilT, 110 + 90 * re * (.5 + .5 * S.frac) if S.running else 59.0, .012, dt)
	S.cht = _ap(S.cht, 220 + 260 * S.frac * re + 40 * re if S.running else 59.0, .05, dt)
	var chg: bool = S.alt and S.running and re > .5 and S.batt
	var load: float = ((2.0 + (6.0 if S.avion else 0.0) + (8.0 if S.ldg else 0.0) + (3.0 if S.nav else 0.0) + (2.0 if S.strobe else 0.0) + (10.0 if S.cm else 0.0)) if S.elec else 0.0) + (150.0 if S.starter else 0.0)
	S.amps = minf(60, (1 - S.batQ) * 300 + 3) if chg else -load
	S.batQ = clampf(S.batQ + ((1 - S.batQ) * .01 if chg else -load * 1.5e-5) * dt, 0, 1)

# twin TV3-117 free-turbine engines, AI-9V APU, gearbox-driven hydraulics, electrics. Returns torque delivered to the rotor.
func mi8_drive(dt: float, Ql: float, r: float) -> float:
	var A: Dictionary = S.apu; var E0: Dictionary = S.eng[0]; var E1: Dictionary = S.eng[1]
	var gen: bool = (S.genL and E0.ng > 60) or (S.genR and E1.ng > 60)
	S.elec = (S.batt and S.batQ > .05) or gen
	S.volts = 28.4 if gen else (22 + 3 * S.batQ if S.batt else 0.0)
	var drain := .0035 if A.start else (.002 if (E0.start or E1.start) else (.0002 if S.elec else 0.0))
	S.batQ = clampf(S.batQ + (.004 if gen else -drain) * dt, 0, 1)
	var fuelP: bool = S.elec and S.svc and S.fuel > 0
	if S.apuReq and S.elec and fuelP and not A.on: A.start = true
	S.apuReq = false
	if A.start:
		A.n = minf(100, A.n + dt * (3 if A.n < 30 else 8))
		if A.n >= 100: A.start = false; A.on = true
	if A.on and not fuelP: A.on = false
	if not A.on and not A.start: A.n = maxf(0, A.n - dt * 10)
	A.egt = _ap(A.egt, (640.0 if A.n > 25 else 200.0) if A.start else (520.0 if A.on else 15.0), .6 if (A.on or A.start) else .08, dt)
	A.air = 2.2 if A.on else (A.n / 100 * 1.4 if A.start else 0.0)
	# governor: pitch-gas correlator + integral trim holds the rotor at 95 %; the correction grip limits it
	if S.cond[0] == 2 or S.cond[1] == 2:
		S.gi = clampf(S.gi + (.95 - r) * 1.2 * dt, -.5, 1)
	var dem: float = clampf(S.gi + (.95 - r) * 8 + .55 * C.coll, 0, 1) * S.twist
	var gNg := maxf(66, 60 + 40 * pow(dem, .625)); var P := 0.0
	for i in 2:
		var E: Dictionary = S.eng[i]
		var fOK: bool = fuelP and S.fcock[i] and (S.pL or S.pR or S.fuel > 0) and S.cond[i] > 0
		if E.start:
			E.st += dt
			if A.air > 1.2:
				E.ng += dt * ((1.5 if E.ng < 40 else 2.2) if E.running else (1.6 if E.ng < 22 else .15))
			if not E.running and E.ng > 14 and fOK: E.running = true
			if E.ng >= 55 or E.st > 70 or not S.elec: E.start = false
		if E.running and not fOK: E.running = false
		if E.running and not E.start:
			var tg := gNg if S.cond[i] == 2 else 66.0
			if E.ng < 64: E.ng += dt * 2.2
			else: E.ng += (tg - E.ng) * dt / (1 + (1.6 if E.ng < 75 else .4))
		if not E.running and not E.start: E.ng = maxf(0, E.ng - dt * (5 if E.ng > 20 else 2.5))
		E.p = 1.45e6 * pow(maxf(0, (E.ng - 60) / 40), 1.6) if E.running else 0.0
		P += E.p
		E.egt = _ap(E.egt, ((700 - 4 * E.ng) if E.ng < 60 else 430 + 520 * clampf((E.ng - 62) / 38, 0, 1.1)) if E.running else 15.0, .8 if E.running else .05, dt)
		E.oil = _ap(E.oil, clampf(E.ng / 20, 0, 3.8) if E.running else 0.0, 1.2, dt)
	if P > 0:
		var nrun := int(E0.running) + int(E1.running)
		S.fuel = maxf(0, S.fuel - (nrun * 70 + P * 2.5e-4) / 3600 * dt)
	var Qe := minf(P / maxf(Om, .25 * Om0), 2.4e5); var Qb := (600 + (6e4 if S.rbrake else 0.0)) if Om > .01 else 0.0
	Om = maxf(0, Om + (Qe - Ql - Qb) / IR * dt)
	S.hydP = _ap(S.hydP, 65 * U.sstep(.2, .55, r), 2, dt) if S.hyd else _ap(S.hydP, 0, 1, dt)
	S.hydB = _ap(S.hydB, 48 * U.sstep(.3, .6, r), 2, dt) if (S.hydP < 30 and r > .3) else _ap(S.hydB, 0, 1, dt)
	S.hb = 1.0 if (S.hydP > 30 or S.hydB > 30) else .3
	S.mgbP = _ap(S.mgbP, 4 * U.sstep(.15, .6, r), 1, dt); S.mgbT = _ap(S.mgbT, 15 + 60 * r, .01, dt)
	return Qe
