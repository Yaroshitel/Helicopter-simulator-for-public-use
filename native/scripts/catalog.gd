class_name Catalog
## Every switch / control / gauge: name, description (from data/text.json), live value and click action; plus the lessons.

static var TEXT: Dictionary

static func text() -> Dictionary:
	if TEXT.is_empty():
		TEXT = JSON.parse_string(FileAccess.get_file_as_string("res://data/text.json"))
	return TEXT

static func OO(b) -> String: return "ON" if b else "OFF"

static func build(sim: Sim) -> Dictionary:
	var T := text(); var S := sim.S; var C := sim.C
	var out := {}
	if not sim.MI8:
		var src: Dictionary = T.ctrl
		for id in src: out[id] = {n = src[id].n, d = src[id].d}
		for id in T.ga: if not out.has(id): out[id] = {n = T.ga[id].n, d = T.ga[id].d}
		var tg := func(k: String): return func(_b := false): S[k] = not S[k]
		for k in ["batt", "alt", "avion", "gov", "strobe", "nav", "ldg", "clutch", "mix", "fuelV", "rbrake"]: out[k].a = tg.call(k)
		out.carb.a = func(_b := false): S.carb = fmod(S.carb + .5, 1.5)
		var g := {batt = func(): return OO(sim.S.batt), alt = func(): return OO(sim.S.alt), avion = func(): return OO(sim.S.avion), gov = func(): return OO(sim.S.gov),
			strobe = func(): return OO(sim.S.strobe), nav = func(): return OO(sim.S.nav), ldg = func(): return OO(sim.S.ldg),
			clutch = func(): return "ENGAGE" if sim.S.clutch else "DISENGAGE", key = func(): return ["OFF", "R", "L", "BOTH", "START"][sim.S.key],
			mix = func(): return "RICH" if sim.S.mix else "CUT-OFF", carb = func(): return ["COLD", "HALF", "FULL HOT"][int(sim.S.carb * 2)],
			fuelV = func(): return OO(sim.S.fuelV), rbrake = func(): return "APPLIED" if sim.S.rbrake else "RELEASED",
			coll = func(): return "%d %%" % roundi(sim.C.coll * 100),
			twist = func(): return "grip %d %% open (with correlator/governor %d %%) → ENGINE RPM %d %%" % [roundi(sim.S.twist * 100), roundi(sim.S.thr * 100), roundi(sim.We / sim.Om0 * 100)],
			cyc = func(): return "fwd %d %%, right %d %%" % [roundi(sim.C.cy * 100), roundi(sim.C.cx * 100)], ped = func(): return "%d %% (− = left)" % roundi(sim.C.ped * 100),
			ann = func(): return "powered" if sim.S.elec else "no power"}
		for k in g: out[k].g = g[k]
	else:
		var src: Dictionary = T.ctrl8
		for id in src: out[id] = {n = src[id].n, d = src[id].d}
		for id in T.g8names:
			var base: String = id.trim_suffix("2")
			if not out.has(id): out[id] = {n = T.g8names[id], d = T.guide8.get(base, "")}
		var tg := func(k: String): return func(_b := false): S[k] = not S[k]
		for k in ["batt", "nav", "ldg", "rbrake"]: out[k].a = tg.call(k)
		out.mgenL.a = tg.call("genL"); out.mgenR.a = tg.call("genR"); out.mhyd.a = tg.call("hyd"); out.mbeacon.a = tg.call("beacon"); out.msvc.a = tg.call("svc"); out.mpbrake.a = tg.call("pbrake")
		out.mpL.a = func(_b := false): var v: bool = not (S.pL and S.pR); S.pL = v; S.pR = v
		out.mfcL.a = func(_b := false): S.fcock[0] = not S.fcock[0]
		out.mfcR.a = func(_b := false): S.fcock[1] = not S.fcock[1]
		out.mapuS.a = func(_b := false): if S.batt: S.apuReq = true
		out.mapuX.a = func(_b := false): S.apu.on = false; S.apu.start = false
		out.msel.a = func(_b := false): S.sel = S.sel ^ 1
		out.mstart.a = func(_b := false):
			var E: Dictionary = S.eng[S.sel]
			if S.elec and not E.running: E.start = true; E.st = 0.0
		out.mabort.a = func(_b := false): for E in S.eng: E.start = false
		out.mcondL.a = func(b := false): S.cond[0] = clampi(S.cond[0] + (-1 if b else 1), 0, 2)
		out.mcondR.a = func(b := false): S.cond[1] = clampi(S.cond[1] + (-1 if b else 1), 0, 2)
		var cn := ["STOP", "IDLE", "AUTO"]
		var g := {batt = func(): return OO(sim.S.batt), mgenL = func(): return OO(sim.S.genL), mgenR = func(): return OO(sim.S.genR),
			mhyd = func(): return "%s · main %d / backup %d kgf/cm²" % [OO(sim.S.hyd), int(sim.S.hydP), int(sim.S.hydB)], nav = func(): return OO(sim.S.nav),
			mbeacon = func(): return OO(sim.S.beacon), ldg = func(): return OO(sim.S.ldg), msvc = func(): return OO(sim.S.svc), mpL = func(): return OO(sim.S.pL and sim.S.pR),
			mfcL = func(): return "OPEN" if sim.S.fcock[0] else "CLOSED", mfcR = func(): return "OPEN" if sim.S.fcock[1] else "CLOSED",
			mapuS = func(): return "APU running" if sim.S.apu.on else ("starting… %d %%" % int(sim.S.apu.n) if sim.S.apu.start else "off"),
			mapuX = func(): return "running" if sim.S.apu.on else "off", msel = func(): return "engine %d" % (sim.S.sel + 1),
			mstart = func(): return "starting engine %d" % (sim.S.sel + 1) if sim.S.eng[sim.S.sel].start else "ready", mabort = func(): return "",
			mcondL = func(): return cn[sim.S.cond[0]], mcondR = func(): return cn[sim.S.cond[1]], rbrake = func(): return "APPLIED" if sim.S.rbrake else "RELEASED",
			mpbrake = func(): return "ON" if sim.S.pbrake else "OFF", coll = func(): return "%d %% · blade pitch %.1f°" % [roundi(sim.C.coll * 100), sim.th * 57.3],
			twist = func(): return "%d %% right" % roundi(sim.S.twist * 100), cyc = func(): return "fwd %d %%, right %d %%" % [roundi(sim.C.cy * 100), roundi(sim.C.cx * 100)],
			ped = func(): return "%d %% (+ = right)" % roundi(sim.C.ped * 100), mAnn = func(): return "powered" if sim.S.elec else "no power"}
		for k in g: out[k].g = g[k]
	return out

static func lessons(sim: Sim, ht: Callable) -> Dictionary:
	var S := sim.S; var C := sim.C
	var re := func() -> float: return sim.We / sim.Om0
	if sim.MI8:
		return {start = [
			["rbrake", "Rotor brake — RELEASE (red lever, overhead)", func(): return not S.rbrake], ["batt", "Batteries — ON (overhead)", func(): return S.batt], ["mbeacon", "Beacon — ON (overhead)", func(): return S.beacon],
			["msvc", "Service tank pump — ON (console)", func(): return S.svc], ["mpL", "Tank pumps — ON", func(): return S.pL and S.pR], ["mfcL", "Fire cocks 1 and 2 — OPEN (guarded)", func(): return S.fcock[0] and S.fcock[1]],
			["mapuS", "APU — press START; wait for APU ON and air pressure ~2", func(): return S.apu.on and S.apu.air > 1.5], ["mcondL", "Engine 1 condition lever — IDLE (overhead)", func(): return S.cond[0] >= 1], ["msel", "Start selector — 1", func(): return S.sel == 0],
			["mstart", "ENGINE START — engine 1 to ground idle (Ng ~66 %, EGT below 750 °C)", func(): return S.eng[0].running and S.eng[0].ng > 64], ["mcondR", "Engine 2 condition lever — IDLE", func(): return S.cond[1] >= 1], ["msel", "Start selector — 2", func(): return S.sel == 1],
			["mstart", "ENGINE START — engine 2 to ground idle", func(): return S.eng[1].running and S.eng[1].ng > 64], ["mgenL", "Generators 1 and 2 — ON (overhead)", func(): return S.genL and S.genR], ["mapuX", "APU — STOP", func(): return not S.apu.on and not S.apu.start],
			["mhyd", "Hydraulics MAIN — ON (pressure 45–65)", func(): return S.hyd and S.hydP > 40], ["mcondL", "Both condition levers — AUTO", func(): return S.cond[0] == 2 and S.cond[1] == 2], ["twist", "Correction grip — fully RIGHT (T): rotor rises to 95 %", func(): return sim.Om / sim.Om0 > .93],
			["mpbrake", "Parking brake — OFF (console)", func(): return not S.pbrake], ["coll", "Collective — raise slowly (W) to a 1–3 m hover; tap A/D to hold the heading", func(): return sim.agl > .6 and sim.agl < 3.5], ["cyc", "Hold a stable hover for 5 s", func(): return ht.call() > 5]],
			shut = [["coll", "Collective — full down", func(): return C.coll < .02], ["twist", "Correction grip — fully LEFT (G)", func(): return S.twist < .05], ["mcondL", "Condition levers — IDLE (cool down)", func(): return S.cond[0] == 1 and S.cond[1] == 1], ["mpbrake", "Parking brake — ON", func(): return S.pbrake],
			["mcondL", "Condition levers — STOP", func(): return S.cond[0] == 0 and S.cond[1] == 0], ["rbrake", "Rotor brake — apply below 30 % rotor RPM", func(): return S.rbrake and sim.Om / sim.Om0 < .3], ["mfcL", "Fire cocks — CLOSE", func(): return not S.fcock[0] and not S.fcock[1]],
			["msvc", "Service pump OFF; tank pumps OFF", func(): return not S.svc and not S.pL and not S.pR], ["mgenL", "Generators — OFF", func(): return not S.genL and not S.genR], ["mhyd", "Hydraulics — OFF", func(): return not S.hyd], ["batt", "Batteries — OFF", func(): return not S.batt]],
			free = [["cyc", "Free flight — hover-taxi, take off at 100 km/h, and feel how much slower the 10-tonne Mi-8 answers than the R44", func(): return false]]}
	return {start = [
		["rbrake", "Rotor brake — RELEASE", func(): return not S.rbrake], ["fuelV", "Fuel shut-off valve — ON", func(): return S.fuelV], ["batt", "Battery — ON", func(): return S.batt], ["strobe", "Strobe — ON", func(): return S.strobe],
		["clutch", "Clutch switch — confirm DISENGAGED", func(): return not S.clutch], ["mix", "Mixture — RICH (push in)", func(): return S.mix], ["twist", "Throttle grip — crack open ~10 % (T open / G close)", func(): return S.twist > .04 and S.twist < .3],
		["key", "Key — hold START; release to BOTH when engine fires", func(): return S.running and S.key == 3], ["oilp", "Oil pressure — green within 30 s", func(): return S.oilP > 25], ["alt", "Alternator — ON", func(): return S.alt], ["avion", "Avionics — ON", func(): return S.avion],
		["twist", "Throttle — adjust (T / G) until ENGINE RPM (white tach needle) reads 50–60 %", func(): return re.call() > .48 and re.call() < .68], ["clutch", "Clutch — ENGAGE (rotor must turn within 5 s)", func(): return S.clutch and sim.Om > .3], ["ann", "Wait — CLUTCH light OUT (keep engine 50–70 %)", func(): return S.clutchE >= 1],
		["cat", "Carb heat — keep CAT out of the yellow arc", func(): return S.carbT > 5 or S.carbT < -15], ["gov", "Governor — ON", func(): return S.gov], ["twist", "Throttle — open (T) until ENGINE RPM passes ~85 %; governor then holds 101–102 %", func(): return sim.Om / sim.Om0 > .99],
		["coll", "Collective — W: raise slowly to a 3-ft hover (click the view to fly, tap A/D to hold the heading)", func(): return sim.agl > .6 and sim.agl < 2.5], ["cyc", "Hold a stable hover for 5 s", func(): return ht.call() > 5]],
		shut = [["coll", "Collective — full down", func(): return C.coll < .02], ["gov", "Governor — OFF", func(): return not S.gov], ["twist", "Throttle — close (G) until ENGINE RPM is below 70 %", func(): return re.call() < .7], ["clutch", "Clutch — DISENGAGE", func(): return not S.clutch],
		["ann", "Wait — CLUTCH light OUT", func(): return S.clutchE <= 0], ["mix", "Mixture — CUT-OFF (pull)", func(): return not S.mix], ["key", "Key — OFF", func(): return S.key == 0], ["rbrake", "Rotor brake — apply below 50 % rotor RPM", func(): return S.rbrake and sim.Om / sim.Om0 < .5],
		["avion", "Avionics — OFF", func(): return not S.avion], ["alt", "Alternator — OFF", func(): return not S.alt], ["strobe", "Strobe — OFF", func(): return not S.strobe], ["batt", "Battery — OFF", func(): return not S.batt], ["fuelV", "Fuel valve — OFF", func(): return not S.fuelV]],
		free = [["cyc", "Free flight — try: 3-ft hover, hover-taxi to the runway, take-off at 60 kt, autorotation (throttle closed, collective down, right pedal)", func(): return false]]}
