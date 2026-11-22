class_name SimAudio extends Node
## Procedural engine, turbine, rotor and tail-rotor sound. Each voice is a looped buffer whose playback rate follows
## the real RPM (so blade slap, Lycoming firing pulses and tail-rotor buzz change pitch exactly with RPM).

const SR := 22050
var sim: Sim
var V := {}          # name -> {p: AudioStreamPlayer, bus: int, g: float, r: float}
var out_bus := -1
var rng := RandomNumberGenerator.new()

func _ready() -> void:
	rng.seed = 5
	var mi8 := sim.MI8
	out_bus = _bus("HeliOut", "Master")
	var lp := AudioEffectLowPassFilter.new(); lp.cutoff_hz = 3000; AudioServer.add_bus_effect(out_bus, lp)
	var cp := AudioEffectCompressor.new(); AudioServer.add_bus_effect(out_bus, cp)
	AudioServer.set_bus_volume_db(out_bus, linear_to_db(.9))
	var rnd := func() -> float: return rng.randf() * 2 - 1
	# main rotor: 2 blades × 408 rpm = 13.6 Hz "whop" (Mi-8: 5 × 192 rpm = 16 Hz)
	var f_rot := 16.0 if mi8 else 13.6; var hz := 30.0 if mi8 else 48.0; var dk := 16.0 if mi8 else 28.0
	_voice("rot", _loop(f_rot, 20, func(t, k): return sin(TAU * hz * t) * exp(-t * dk) * .9 + sin(TAU * 95 * t) * exp(-t * 45) * .5 + rnd.call() * exp(-t * 160) * .55,
		func(k): return .85 + rng.randf() * .3, func(t, u): return rnd.call() * .06 * (.6 + .4 * cos(TAU * u * 20))), "low", 900)
	_voice("slap", _loop(f_rot, 20, func(t, k): return rnd.call() * exp(-t * 420) + sin(TAU * 260 * t) * exp(-t * 120) * .6), "high", 300)
	# Lycoming O-540: 6 cylinders at 2718 rpm → 136 firings/s, uneven per cylinder for the piston growl
	var cylA := [1.0, .86, .95, .78, 1.05, .9]
	_voice("eng", _loop(136, 48, func(t, k): return (sin(TAU * 70 * t) * .7 + rnd.call() * .8) * exp(-t * 230) + sin(TAU * 230 * t) * exp(-t * 400) * .3,
		func(k): return cylA[k % 6] * (.9 + rng.randf() * .2), func(t, u): return sin(TAU * 22.6 * t) * .25), "low", 600)
	_voice("tr", _loop(56.2 if mi8 else 80.9, 40, func(t, k): return rnd.call() * exp(-t * 900) + sin(TAU * 240 * t) * exp(-t * 300) * .5), "band", 400, .5)
	var noise := _noise()
	_voice("xh", noise, "band", 90, .6)
	_voice("wind", noise, "low", 300)
	_voice("go", _tone("tri", 900), "", 0); _voice("go2", _tone("sin", 1350), "", 0)
	_voice("st", _tone("saw", 120), "low", 1200)
	_voice("cl", _tone("sq", 180), "low", 800)
	_voice("horn", _tone("sq", 750), "band", 1500, 1.0)
	if mi8:
		for i in 2:
			_voice("w1_%d" % i, _tone("sin", 3000), "", 0); _voice("w2_%d" % i, _tone("sin", 5200), "", 0); _voice("tn_%d" % i, noise, "band", 600, .6)
		_voice("apu", _tone("sin", 6000), "", 0); _voice("apun", noise, "band", 1800, .8); _voice("hiss", noise, "high", 2500)
	for k in V: V[k].p.play()

func _exit_tree() -> void:
	for k in V: AudioServer.remove_bus(AudioServer.get_bus_index("H_" + k))
	if out_bus >= 0: AudioServer.remove_bus(AudioServer.get_bus_index("HeliOut"))

func _bus(n: String, send: String) -> int:
	var i := AudioServer.get_bus_index(n)
	if i >= 0: AudioServer.remove_bus(i)
	AudioServer.add_bus(); i = AudioServer.bus_count - 1
	AudioServer.set_bus_name(i, n); AudioServer.set_bus_send(i, send)
	return i

func _voice(n: String, s: AudioStreamWAV, ft: String, f: float, q := .7) -> void:
	var b := _bus("H_" + n, "HeliOut")
	if ft != "":
		var e: AudioEffectFilter = {"low": AudioEffectLowPassFilter, "high": AudioEffectHighPassFilter, "band": AudioEffectBandPassFilter}[ft].new()
		e.cutoff_hz = f; e.resonance = clampf(q, .1, 1); AudioServer.add_bus_effect(b, e)
	var p := AudioStreamPlayer.new(); p.stream = s; p.bus = "H_" + n; p.volume_db = -80; p.pitch_scale = .01; add_child(p)
	V[n] = {p = p, bus = b, g = 0.0, r = .01, base = s.get_meta("f", 1.0)}

func _wav(d: PackedFloat32Array) -> AudioStreamWAV:
	var m := 0.0
	for x in d: m = maxf(m, absf(x))
	var b := PackedByteArray(); b.resize(d.size() * 2)
	for i in d.size(): b.encode_s16(i * 2, int(clampf(d[i] / maxf(m, 1e-6), -1, 1) * 32000))
	var w := AudioStreamWAV.new(); w.format = AudioStreamWAV.FORMAT_16_BITS; w.mix_rate = SR; w.data = b
	w.loop_mode = AudioStreamWAV.LOOP_FORWARD; w.loop_begin = 0; w.loop_end = d.size()
	return w

## a looping buffer holding `cyc` pulse cycles at frequency f (pulse(t, k) for t in seconds after each pulse)
func _loop(f: float, cyc: int, pulse: Callable, amp := Callable(), extra := Callable()) -> AudioStreamWAV:
	var n := roundi(SR * cyc / f); var d := PackedFloat32Array(); d.resize(n)
	var span := mini(n, int(.25 * SR))
	for k in cyc:
		var s0 := roundi(k * n / float(cyc)); var a: float = amp.call(k) if amp.is_valid() else 1.0
		for j in span:
			d[(s0 + j) % n] += a * pulse.call(float(j) / SR, k)
	if extra.is_valid():
		for i in n: d[i] += extra.call(float(i) / SR, float(i) / n)
	return _wav(d)

func _noise() -> AudioStreamWAV:
	var d := PackedFloat32Array(); d.resize(SR * 2)
	for i in d.size(): d[i] = rng.randf() * 2 - 1
	return _wav(d)

## one second of an oscillator at its base frequency; playback rate sets the frequency
func _tone(kind: String, f: float) -> AudioStreamWAV:
	var d := PackedFloat32Array(); d.resize(SR)
	for i in SR:
		var ph := fmod(f * i / SR, 1.0)
		match kind:
			"sin": d[i] = sin(TAU * ph)
			"tri": d[i] = 1 - 4 * absf(ph - .5)
			"saw": d[i] = 2 * ph - 1
			"sq": d[i] = 1.0 if ph < .5 else -1.0
	var w := _wav(d); w.set_meta("f", f)
	return w

func _sv(n: String, gain: float, rate := -1.0, k := .25) -> void:
	var v: Dictionary = V[n]
	v.g += (gain - v.g) * k
	(v.p as AudioStreamPlayer).volume_db = linear_to_db(maxf(v.g, 1e-5))
	if rate >= 0:
		v.r += (rate - v.r) * k
		(v.p as AudioStreamPlayer).pitch_scale = maxf(.01, v.r)

func _cut(n: String, f: float) -> void:
	var e := AudioServer.get_bus_effect(V[n].bus, 0) as AudioEffectFilter
	if e: e.cutoff_hz = f

func click() -> void:
	var d := PackedFloat32Array(); d.resize(300)
	for i in 300: d[i] = (rng.randf() * 2 - 1) * exp(-i / 30.0)
	var w := _wav(d); w.loop_mode = AudioStreamWAV.LOOP_DISABLED
	var p := AudioStreamPlayer.new(); p.stream = w; p.volume_db = linear_to_db(.35); add_child(p); p.play()
	p.finished.connect(p.queue_free)

func update(inside: bool, dist: float) -> void:
	var F := sim; var S := sim.S
	var re := F.We / F.Om0; var rr := F.Om / F.Om0
	var att := 1.0 if inside else 1.0 / maxf(1, dist / 8)
	var ias := (F.v - F.wind).length(); var load := clampf(absf(F.T) / (F.MASS * 9.81), 0, 1.6); var desc := clampf(-F.v.y / 4, 0, 1) * clampf(ias / 25, 0, 1)
	_sv("rot", att * .55 * U.sstep(.02, .4, rr) * (.35 + .65 * load), rr)
	_sv("slap", att * .35 * rr * rr * (desc + .15 * load * U.sstep(.9, 1, rr)), rr)
	var run: bool = S.get("running", false)
	_sv("eng", ((.22 + .3 * S.frac) if run else (.15 if re > .02 else 0.0)) * (1.0 if inside else att * .8), re); _cut("eng", 250 + 900 * S.frac + 400 * re)
	_sv("xh", (.05 + .12 * S.frac) * (.6 if inside else att) if run else 0.0, 1.0)
	_sv("tr", (.05 if inside else att * .25) * rr * rr * (.5 + absf(F.Ttr) / 1200), rr)
	_cut("wind", 150 + ias * 25); _sv("wind", pow(clampf(ias / 60, 0, 1), 2) * (.25 if inside else .15), 1.0)
	_sv("go", (.018 if inside else .004 * att) * rr, (30 + 870 * rr) / 900); _sv("go2", (.018 if inside else .004 * att) * rr, (45 + 1305 * rr) / 1350)
	_sv("st", .12 if S.starter else 0.0, (80 + 500 * re) / 120, .6); _sv("cl", .03 if (S.cm and S.elec) else 0.0, 1.0, .6)
	_sv("horn", .07 if (S.low and rr > .1) else 0.0, 1.0, .8)
	var lp := AudioServer.get_bus_effect(out_bus, 0) as AudioEffectLowPassFilter
	lp.cutoff_hz += ((2600.0 if inside else 16000.0) - lp.cutoff_hz) * .15
	if F.MI8:
		var k := 1.0 if inside else att
		for i in 2:
			var E: Dictionary = S.eng[i]; var n: float = E.ng / 100
			var wg := (.01 + .03 * n * n if E.ng > 3 else 0.0) * k
			_sv("w1_%d" % i, wg, (60 + 3200 * n) / 3000); _sv("w2_%d" % i, wg, (90 + 5400 * n) / 5200)
			_cut("tn_%d" % i, 200 + 700 * n); _sv("tn_%d" % i, ((.05 + .25 * E.p / 1.45e6) if E.running else (.03 * n if E.ng > 3 else 0.0)) * k, 1.0)
		var a: float = S.apu.n / 100
		_sv("apu", .02 * k if a > .02 else 0.0, (200 + 6500 * a) / 6000); _sv("apun", a * .08 * k, 1.0)
		_sv("hiss", .06 * k if (S.eng[0].start or S.eng[1].start) else 0.0, 1.0)
