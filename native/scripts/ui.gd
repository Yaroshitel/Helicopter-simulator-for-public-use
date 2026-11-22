class_name UI extends CanvasLayer
## All 2D interface: start screen, help, lesson panel, HUD, tooltips, messages, pilot's manual, licences.

var main  # Main node
var root: Control
var start_box: Control
var help: PanelContainer; var panel: PanelContainer; var hud_l: Label; var tip: PanelContainer; var tip_l: RichTextLabel
var mode_l: RichTextLabel; var msg: RichTextLabel; var steps: RichTextLabel; var live := ""; var xh: Control
var stick: Panel; var sdot: Panel; var man: PanelContainer; var man_t: RichTextLabel; var lic: PanelContainer
var tod_s: HSlider; var tod_l: Label; var tip_id := ""
var cur_steps: Array = []; var cur_done: Array = []
var font_mono: SystemFont
const GOLD := Color("ffd166")

func _ready() -> void:
	root = Control.new(); root.set_anchors_preset(Control.PRESET_FULL_RECT); root.mouse_filter = Control.MOUSE_FILTER_IGNORE; add_child(root)
	font_mono = SystemFont.new(); font_mono.font_names = PackedStringArray(["Consolas", "Menlo", "DejaVu Sans Mono", "monospace"])
	var th := Theme.new(); th.default_font_size = 13; root.theme = th

func sbox(alpha := .82) -> StyleBoxFlat:
	var s := StyleBoxFlat.new(); s.bg_color = Color(.04, .055, .08, alpha); s.border_color = Color("2c3a4a"); s.set_border_width_all(1); s.set_corner_radius_all(10)
	s.content_margin_left = 12; s.content_margin_right = 12; s.content_margin_top = 10; s.content_margin_bottom = 10
	return s

func box(parent: Control, alpha := .82) -> PanelContainer:
	var p := PanelContainer.new(); p.add_theme_stylebox_override("panel", sbox(alpha)); parent.add_child(p); return p

func rtl(parent: Control, txt := "", fit := true) -> RichTextLabel:
	var r := RichTextLabel.new(); r.bbcode_enabled = true; r.fit_content = fit; r.text = txt; r.scroll_active = not fit
	r.mouse_filter = Control.MOUSE_FILTER_PASS; parent.add_child(r); return r

func button(parent: Control, txt: String, cb: Callable) -> Button:
	var b := Button.new(); b.text = txt; b.pressed.connect(cb); b.focus_mode = Control.FOCUS_NONE; parent.add_child(b); return b

# ------------------------------------------------------------------ start screen
func show_start() -> void:
	start_box = ColorRect.new(); start_box.color = Color(0, 0, 0, .65); start_box.set_anchors_preset(Control.PRESET_FULL_RECT); root.add_child(start_box)
	var v := VBoxContainer.new(); v.set_anchors_preset(Control.PRESET_CENTER); v.alignment = BoxContainer.ALIGNMENT_CENTER; v.add_theme_constant_override("separation", 14)
	v.grow_horizontal = Control.GROW_DIRECTION_BOTH; v.grow_vertical = Control.GROW_DIRECTION_BOTH
	start_box.add_child(v)
	var t := Label.new(); t.text = "Helicopter Flying Simulator"; t.add_theme_font_size_override("font_size", 34); t.add_theme_color_override("font_color", GOLD); t.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; v.add_child(t)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_CENTER; h.add_theme_constant_override("separation", 14); v.add_child(h)
	for a in [["r44", "Robinson R44", "light · piston engine · 1 t · 2 blades"], ["mi8", "Mil Mi-8", "heavy · twin turbine · 10.5 t · 5 blades"]]:
		var b := Button.new(); b.text = a[1] + "\n" + a[2]; b.custom_minimum_size = Vector2(260, 84); b.add_theme_font_size_override("font_size", 17); b.focus_mode = Control.FOCUS_NONE
		var sb := sbox(.9); sb.bg_color = Color("152030"); sb.border_color = Color("3a4a5c"); sb.set_border_width_all(2); b.add_theme_stylebox_override("normal", sb)
		var sh := sb.duplicate(); sh.border_color = GOLD; b.add_theme_stylebox_override("hover", sh); b.add_theme_stylebox_override("pressed", sh)
		b.pressed.connect(func(): main.switch_aircraft(a[0])); h.add_child(b)
	var l := Label.new(); l.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	l.text = "Choose a helicopter to take the controls\nMouse = cyclic · W/S collective · A/D pedals · hold Alt to look around and use switches — aim at any switch or gauge to learn what it does."
	v.add_child(l)
	var hb := HBoxContainer.new(); hb.alignment = BoxContainer.ALIGNMENT_CENTER; hb.add_theme_constant_override("separation", 10); v.add_child(hb)
	var q := OptionButton.new(); q.focus_mode = Control.FOCUS_NONE
	for s in ["Graphics: Low (light on RAM / older PCs)", "Graphics: Medium", "Graphics: High"]: q.add_item(s)
	q.selected = main.settings.quality; q.item_selected.connect(func(i): main.apply_quality(i)); hb.add_child(q)
	button(hb, "Licences & credits", show_licences)
	button(hb, "Quit", func(): main.get_tree().quit())
	var note := Label.new(); note.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER; note.modulate = Color(1, 1, 1, .6)
	note.text = "For learning and entertainment only — not an approved training device. Not affiliated with Robinson Helicopter Company or Mil."
	note.add_theme_font_size_override("font_size", 11); v.add_child(note)

# ------------------------------------------------------------------ in-game UI
func build_game(mi8: bool) -> void:
	help = box(root); help.position = Vector2(12, 12); help.custom_minimum_size.x = 330
	rtl(help, "[color=#ffd166][b]Controls[/b][/color] [font_size=11](H hides panels)[/font_size]\nClick the view to take the controls ([b]Esc[/b] releases the mouse)\n" +
		"Mouse left/right = roll · forward/back = pitch (cyclic) · [b]Space[/b] centre cyclic\n[b]Hold Alt[/b] = free look: the cyclic stays put, aim the centre dot at a switch and click (right-click = turn back, hold on key BOTH = START)\n" +
		"Collective [b]W[/b] up / [b]S[/b] down\nYaw pedals [b]A[/b] left / [b]D[/b] right · [b]X[/b] centre\nThrottle twist (R44) / correction grip (Mi-8) [b]T[/b] open / [b]G[/b] close\n" +
		"[b]V[/b] 1st ⇄ 3rd person · [b]C[/b] cycle cockpit/chase/orbit · wheel zoom · [b]Z[/b] reset view\n[b]N[/b] +1 hour · Pause [b]P[/b] · Reset [b]Backspace[/b] · [b]Manual M[/b] · [b]F11[/b] full screen · Gamepad supported\n" +
		"Without capturing the mouse you can also click switches directly and drag with the right button to look.")
	var mb := box(root); mb.anchor_left = .5; mb.anchor_right = .5; mb.offset_top = 12; mb.grow_horizontal = Control.GROW_DIRECTION_BOTH
	mode_l = rtl(mb, ""); mode_l.autowrap_mode = TextServer.AUTOWRAP_OFF
	panel = box(root); panel.anchor_left = 1; panel.anchor_right = 1; panel.anchor_bottom = 1; panel.offset_left = -326; panel.offset_right = -12; panel.offset_top = 12; panel.offset_bottom = -110
	panel.grow_horizontal = Control.GROW_DIRECTION_BEGIN
	var sc := ScrollContainer.new(); sc.custom_minimum_size = Vector2(290, 0); sc.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED; panel.add_child(sc)
	var v := VBoxContainer.new(); v.size_flags_horizontal = Control.SIZE_EXPAND_FILL; sc.add_child(v)
	var row := func(lbl: String, c: Control):
		var h := HBoxContainer.new(); var l := Label.new(); l.text = lbl; h.add_child(l); c.size_flags_horizontal = Control.SIZE_EXPAND_FILL; h.add_child(c); v.add_child(h)
	var air := OptionButton.new(); air.add_item("Robinson R44"); air.add_item("Mil Mi-8"); air.selected = 1 if mi8 else 0; air.focus_mode = Control.FOCUS_NONE
	air.item_selected.connect(func(i): main.switch_aircraft(["r44", "mi8"][i])); row.call("Aircraft ", air)
	var h3 := Label.new(); h3.text = "Lesson"; h3.add_theme_color_override("font_color", GOLD); h3.add_theme_font_size_override("font_size", 15); v.add_child(h3)
	var les := OptionButton.new(); les.focus_mode = Control.FOCUS_NONE
	for s in ["1 · Cold start → first hover", "2 · Shutdown", "3 · Free flight"]: les.add_item(s)
	les.selected = ["start", "shut", "free"].find(main.settings.lesson); les.item_selected.connect(func(i): main.set_lesson(["start", "shut", "free"][i])); v.add_child(les)
	steps = rtl(v, ""); steps.custom_minimum_size.x = 280
	var r := HBoxContainer.new(); v.add_child(r)
	button(r, "Quick start", func(): main.quick()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(r, "Reset", func(): main.reset()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(v, "📖 Pilot's manual (M)", toggle_manual)
	var sas := CheckBox.new(); sas.text = "SAS / attitude hold (limited authority)"; sas.button_pressed = main.settings.sas; sas.focus_mode = Control.FOCUS_NONE
	sas.tooltip_text = "Limited-authority attitude hold that works through the rotor controls, like a HeliSAS (R44) or the AP-34 autopilot (Mi-8). Off = bare airframe."
	sas.toggled.connect(func(b): main.settings.sas = b); v.add_child(sas)
	var sens := HSlider.new(); sens.min_value = .3; sens.max_value = 3; sens.step = .1; sens.value = main.settings.sens; sens.focus_mode = Control.FOCUS_NONE
	sens.value_changed.connect(func(x): main.settings.sens = x); row.call("Mouse sensitivity ", sens)
	tod_s = HSlider.new(); tod_s.min_value = 0; tod_s.max_value = 24; tod_s.step = .05; tod_s.value = main.TOD.h; tod_s.focus_mode = Control.FOCUS_NONE
	tod_s.value_changed.connect(func(x): if tod_s.has_focus() or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): main.TOD.h = x; main.settings.tod = x)
	var th := HBoxContainer.new(); var tl := Label.new(); tl.text = "Time of day "; th.add_child(tl); tod_s.size_flags_horizontal = Control.SIZE_EXPAND_FILL; th.add_child(tod_s); tod_l = Label.new(); th.add_child(tod_l); v.add_child(th)
	var cyc := OptionButton.new(); cyc.focus_mode = Control.FOCUS_NONE
	var cv := [0.0, 1.0, 6.0, 60.0]
	for s in ["Paused", "1 day = 24 min", "1 day = 4 min", "1 day = 24 s (demo)"]: cyc.add_item(s)
	cyc.selected = cv.find(main.settings.cyc); cyc.item_selected.connect(func(i): main.TOD.speed = cv[i]; main.settings.cyc = cv[i]); row.call("Day/night cycle ", cyc)
	var wind := OptionButton.new(); wind.focus_mode = Control.FOCUS_NONE
	var wv := [0.0, 4.0, 9.0]
	for s in ["Calm", "8 kt from 300°", "18 kt gusty"]: wind.add_item(s)
	wind.selected = wv.find(main.settings.wind); wind.item_selected.connect(func(i): main.wind_spd = wv[i]; main.settings.wind = wv[i]); row.call("Wind ", wind)
	var q := OptionButton.new(); q.focus_mode = Control.FOCUS_NONE
	for s in ["Low", "Medium", "High"]: q.add_item(s)
	q.selected = main.settings.quality; q.item_selected.connect(func(i): main.apply_quality(i)); row.call("Graphics ", q)
	var r2 := HBoxContainer.new(); v.add_child(r2)
	button(r2, "Licences", show_licences).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(r2, "Main menu", func(): main.switch_aircraft("")).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	button(r2, "Quit", func(): main.get_tree().quit()).size_flags_horizontal = Control.SIZE_EXPAND_FILL
	var hb := box(root); hb.anchor_top = 1; hb.anchor_bottom = 1; hb.offset_left = 12; hb.offset_bottom = -12; hb.grow_vertical = Control.GROW_DIRECTION_BEGIN
	hud_l = Label.new(); hud_l.add_theme_font_override("font", font_mono); hud_l.add_theme_font_size_override("font_size", 12); hb.add_child(hud_l)
	stick = Panel.new(); stick.add_theme_stylebox_override("panel", sbox()); root.add_child(stick)
	stick.anchor_left = 1; stick.anchor_right = 1; stick.anchor_top = 1; stick.anchor_bottom = 1; stick.offset_left = -102; stick.offset_right = -12; stick.offset_top = -102; stick.offset_bottom = -12
	var cl1 := ColorRect.new(); cl1.color = Color("445566"); cl1.position = Vector2(45, 0); cl1.size = Vector2(1, 90); stick.add_child(cl1)
	var cl2 := ColorRect.new(); cl2.color = Color("445566"); cl2.position = Vector2(0, 45); cl2.size = Vector2(90, 1); stick.add_child(cl2)
	sdot = Panel.new(); var ds := StyleBoxFlat.new(); ds.bg_color = GOLD; ds.set_corner_radius_all(5); sdot.add_theme_stylebox_override("panel", ds); sdot.size = Vector2(10, 10); stick.add_child(sdot)
	tip = box(root); tip.visible = false; tip.custom_minimum_size.x = 340; tip.mouse_filter = Control.MOUSE_FILTER_IGNORE; tip.z_index = 5
	tip_l = rtl(tip, ""); tip_l.custom_minimum_size.x = 320; tip_l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	xh = Control.new(); xh.visible = false; root.add_child(xh); xh.anchor_left = .5; xh.anchor_right = .5; xh.anchor_top = .5; xh.anchor_bottom = .5
	xh.draw.connect(func(): xh.draw_arc(Vector2.ZERO, 7, 0, TAU, 24, Color.BLACK, 4); xh.draw_arc(Vector2.ZERO, 7, 0, TAU, 24, GOLD, 2))
	msg = RichTextLabel.new(); msg.bbcode_enabled = true; msg.fit_content = true
	msg.anchor_left = .5; msg.anchor_right = .5; msg.anchor_top = .38; msg.anchor_bottom = .38; msg.offset_left = -350; msg.offset_right = 350; msg.offset_top = -60; msg.add_theme_font_size_override("normal_font_size", 26); msg.add_theme_color_override("font_shadow_color", Color.BLACK)
	msg.add_theme_constant_override("shadow_offset_y", 2); msg.visible = false; msg.mouse_filter = Control.MOUSE_FILTER_IGNORE; root.add_child(msg)

func render_steps(st: Array, done: Array) -> void:
	cur_steps = st; cur_done = done; _draw_steps()

func _draw_steps() -> void:
	if not steps: return
	var cur := cur_done.find(false); var s := ""
	for i in cur_steps.size():
		if cur_done[i]: s += "[color=#6fdc8c]✓ " + cur_steps[i][1] + "[/color]\n"
		elif i == cur: s += "[color=#ffd166]▶[/color] [b]" + cur_steps[i][1] + "[/b]\n[color=#8fd3ff][font_size=11]" + live + "[/font_size][/color]\n"
		else: s += "[color=#8795a6]○ " + cur_steps[i][1] + "[/color]\n"
	if cur < 0: s += "[color=#6fdc8c][b]Lesson complete ✔[/b][/color]"
	steps.text = s

func set_live(t: String) -> void:
	if t != live:
		live = t; _draw_steps()

func set_mode(al: bool, fl: bool) -> void:
	if not mode_l: return
	xh.visible = al; xh.queue_redraw()
	mode_l.text = "👁 FREE LOOK — aim the dot at a control · click = use · right-click = back" if al else ("✈ Flying — mouse = cyclic · hold [b]Alt[/b] to look around and use switches · [b]Esc[/b] releases mouse" if fl else "Click the view to take the controls · or point at switches and click them")
	var C: Dictionary = main.sim.C
	sdot.position = Vector2(45 + C.cx * 40 - 5, 45 - C.cy * 40 - 5)

func tod_ui(h: float) -> void:
	if not tod_s: return
	if not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT): tod_s.set_value_no_signal(h)
	var hh := int(h); tod_l.text = "%02d:%02d" % [hh, int((h - hh) * 60)]

func typing() -> bool: return false

func show_tip(p: Vector2, id: String) -> void:
	if not tip: return
	main.hover = id; tip_id = id
	if id == "" or not main.CTRL.has(id):
		tip.visible = false; return
	tip.visible = true; refresh_tip()
	var vs := root.get_viewport_rect().size
	tip.position = Vector2(minf(p.x + 18, vs.x - 360), minf(p.y + 14, vs.y - tip.size.y - 10))

func refresh_tip() -> void:
	if not tip or not tip.visible or tip_id == "": return
	var c: Dictionary = main.CTRL[tip_id]
	tip_l.text = "[color=#ffd166][font_size=14][b]%s[/b][/font_size][/color]\n%s%s" % [c.n, c.d, ("\n[color=#8fd3ff]Now: " + str(c.g.call()) + "[/color]") if c.has("g") else ""]

func show_msg(t: String) -> void:
	if msg: msg.text = "[center]" + t + "[/center]"; msg.visible = true
func hide_msg() -> void:
	if msg: msg.visible = false

func toggle_panels() -> void:
	help.visible = not help.visible; panel.visible = help.visible

func hud(m) -> void:
	var F: Sim = m.sim; var S := F.S; var e := Sim.euler_yxz(F.q); var vb := F.q.inverse() * (F.v - F.wind); var rr := F.Om / F.Om0
	var s := "IAS %3d kt   GS %3d kt   HDG %03d°\nAGL %4d ft   VS %5d fpm\n" % [roundi(maxf(0, -vb.z * 1.944)), roundi(Vector2(F.v.x, F.v.z).length() * 1.944), roundi(fposmod(-rad_to_deg(e.y), 360.0)) % 360, roundi(F.agl * 3.281), roundi(F.v.y * 196.85)]
	if F.MI8:
		s += "ROTOR %3d %%   Ng %d/%d %%   EGT %d/%d °C   APU %s\n" % [roundi(rr * 100), roundi(S.eng[0].ng), roundi(S.eng[1].ng), roundi(S.eng[0].egt), roundi(S.eng[1].egt), "ON" if S.apu.on else ("START" if S.apu.start else "off")]
		s += "COLL %3d %%   PEDAL %4d %%   CORR %3d %%   IAS %d km/h   RALT %.1f m\n" % [roundi(F.C.coll * 100), roundi(F.C.ped * 100), roundi(S.twist * 100), roundi(maxf(0, -vb.z * 3.6)), maxf(0, F.agl)]
	else:
		s += "ROTOR %3d %%   ENG %3d %%   MAP %.1f\"\n" % [roundi(rr * 100), roundi(F.We / F.Om0 * 100), S.map]
		s += "COLL %3d %%   PEDAL %4d %%   THR %3d %%\n" % [roundi(F.C.coll * 100), roundi(F.C.ped * 100), roundi(S.thr * 100)]
	s += ("⚠ VORTEX RING STATE " if F.vrs > .3 else "") + ("⚠ CARB ICE " if S.ice > .1 else "") + ("⚠ LOW ROTOR RPM " if S.low else "") + ("⏸ PAUSED " if m.paused else "") + ["COCKPIT", "CHASE", "ORBIT"][m.cam_mode] + " view"
	hud_l.text = s

# ------------------------------------------------------------------ manual
func manual_open() -> bool: return man != null and man.visible

func toggle_manual() -> void:
	if man == null: _build_manual()
	elif man.visible:
		man.visible = false; return
	else: _fill_manual()
	man.visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func _build_manual() -> void:
	man = box(root, .97); man.set_anchors_preset(Control.PRESET_FULL_RECT); man.z_index = 8
	man.offset_left = 80; man.offset_right = -80; man.offset_top = 40; man.offset_bottom = -40
	var v := VBoxContainer.new(); man.add_child(v)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; v.add_child(h)
	button(h, "Close (M)", toggle_manual)
	man_t = rtl(v, "", false); man_t.size_flags_vertical = Control.SIZE_EXPAND_FILL; man_t.add_theme_font_size_override("normal_font_size", 14)
	man_t.selection_enabled = true
	_fill_manual()

func _fill_manual() -> void:
	var T := Catalog.text(); var mi8: bool = main.sim.MI8
	var src: String = T.man8 if mi8 else T.man
	man_t.clear()
	var re := RegEx.new(); re.compile("\\[(diagram|photo):(\\w+)\\]|\\[gguide\\]|\\[mref\\]")
	var pos := 0
	for m in re.search_all(src):
		man_t.append_text(src.substr(pos, m.get_start() - pos)); pos = m.get_end()
		var tok := m.get_string()
		if tok == "[gguide]": _gauge_guide(mi8)
		elif tok == "[mref]":
			var C: Dictionary = main.CTRL
			for id in C:
				if id.ends_with("2"): continue
				man_t.append_text("[b]" + C[id].n + "[/b]\n    " + C[id].d + "\n")
		elif m.get_string(1) == "diagram": man_t.append_text(_diagram(m.get_string(2), mi8))
		else: pass   # photos of the 3D model are shown live in the cockpit instead
	man_t.append_text(src.substr(pos))

func _gauge_guide(mi8: bool) -> void:
	var T := Catalog.text(); var h = main.heli
	var vp: SubViewport = h.pn8_vp if mi8 else h.panel_vp
	var list: Array = h.G8 if mi8 else h.GA
	var PS: float = 1000.0 if mi8 else 1400.0
	for g in list:
		if g.get("dup", false): continue
		var at := AtlasTexture.new(); at.atlas = vp.get_texture()
		var c := Vector2(vp.size) / 2 + Vector2(g.x, -g.y) * PS; var r: float = g.r * PS * 1.15
		at.region = Rect2(c - Vector2(r, r), Vector2(2 * r, 2 * r))
		man_t.add_image(at, 110, 110)
		var name: String = main.CTRL[g.id].n if main.CTRL.has(g.id) else g.id
		var desc: String = (T.guide8 if mi8 else T.guide).get(g.id, main.CTRL[g.id].d if main.CTRL.has(g.id) else "")
		man_t.append_text("  [b]" + name + "[/b]\n" + desc + "\n\n")

func _diagram(id: String, mi8: bool) -> String:
	var D := {
		drive = "[code]Engine ─► lower sheave ─(V-belts)─► upper sheave + clutch actuator ─► sprag clutch ─► main gearbox ─► MAIN ROTOR (408 rpm)\n                                                                                  └─(drive shaft)─► tail gearbox ─► TAIL ROTOR (~2426 rpm)[/code]",
		engine = "[code]   cyl 2 ═╡        ╞═ cyl 1\n   cyl 4 ═╡crankcase╞═ cyl 3     cooling fan at the front · starter · alternator · 2 magnetos\n   cyl 6 ═╡        ╞═ cyl 5     carburetor + oil sump underneath[/code]",
		gov = "[code]Collective ─► correlator (mechanical) ─► throttle valve ─► engine + rotor RPM\n                       ▲                                         │ RPM sensor\n                       └──────── governor (motor nudges throttle) ◄┘   holds 101–102 %[/code]",
		carb = "[code]outside air +15 °C ─► venturi −5 °C (ice forms on the throttle plate) ─► to cylinders\n                       ▲ fuel nozzle          carb heat: hot air from the exhaust shroud melts the ice[/code]",
		turb = "[code]air ─► compressor (12 stages) ─► combustor ─► gas-generator turbine ═╗  ─► free turbine ─► exhaust\n        └────────── gas-generator spool: speed = Ng ═══════════╝          └─ power shaft: speed ∝ Nr ─► rotor[/code]"}
	if mi8 and id == "drive":
		return "[code]Engine 1 ─► freewheel 1 ─┐                ┌─► MAIN ROTOR (5 blades · 192 rpm)\n                          ├─► VR-14 gearbox ┤\nEngine 2 ─► freewheel 2 ─┘ (15,000→192 rpm) └─► tail shaft ─► TAIL ROTOR (3 blades · 1,124 rpm)\n                              └─► accessories: hydraulic pumps · generators · fan[/code]\n"
	return D.get(id, "") + "\n"

# ------------------------------------------------------------------ licences
func show_licences() -> void:
	if lic:
		lic.visible = not lic.visible; return
	lic = box(root, .97); lic.set_anchors_preset(Control.PRESET_FULL_RECT); lic.z_index = 9
	lic.offset_left = 80; lic.offset_right = -80; lic.offset_top = 40; lic.offset_bottom = -40
	var v := VBoxContainer.new(); lic.add_child(v)
	var h := HBoxContainer.new(); h.alignment = BoxContainer.ALIGNMENT_END; v.add_child(h)
	button(h, "Close", func(): lic.visible = false)
	var t := rtl(v, "", false); t.size_flags_vertical = Control.SIZE_EXPAND_FILL; t.selection_enabled = true
	var own := FileAccess.get_file_as_string("res://LICENSE.txt")
	var s := "[color=#ffd166][b]Helicopter Flying Simulator[/b][/color]\n\n" + own.replace("[", "[lb]") + "\n\n"
	s += "[color=#ffd166][b]Trademarks[/b][/color]\nRobinson and R44 are trademarks of Robinson Helicopter Company; Mil and Mi-8 are trademarks of their respective owners. This simulator is an independent educational project and is not affiliated with, endorsed by or sponsored by them. All 3D models, textures and sounds are generated procedurally by the program.\n\n"
	s += "[color=#ffd166][b]This game uses the Godot Engine[/b][/color]\n" + Engine.get_license_text().replace("[", "[lb]") + "\n\n"
	s += "[color=#ffd166][b]Third-party components inside the Godot Engine[/b][/color]\n"
	var info := Engine.get_copyright_info()
	for comp in info:
		s += "[b]" + str(comp.name) + "[/b]\n"
		for part in comp.parts:
			for c in part.copyright: s += "  © " + str(c).replace("[", "[lb]") + "\n"
			s += "  License: " + str(part.license) + "\n"
	s += "\n[color=#ffd166][b]Licence texts[/b][/color]\n"
	var li := Engine.get_license_info()
	for k in li: s += "\n[b]" + str(k) + "[/b]\n" + str(li[k]).replace("[", "[lb]") + "\n"
	t.text = s
