class_name Gauges extends Control
## 2D instrument-panel painter (drawn into a SubViewport that textures the 3D panel). Ports the canvas dials.

var PS := 1400.0
var font: Font
var heli: Node   # owner model (gives access to sim + data)
var bg := Color("24272b")

func _init() -> void:
	font = ThemeDB.fallback_font

func P2(x: float, y: float) -> Vector2:
	return Vector2(size.x / 2 + x * PS, size.y / 2 - y * PS)

func txt(t: String, p: Vector2, sz: float, col := Color("f2f2f2"), align := HORIZONTAL_ALIGNMENT_CENTER) -> void:
	var w := font.get_string_size(t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz)).x
	var x := p.x - (w / 2 if align == HORIZONTAL_ALIGNMENT_CENTER else 0.0)
	draw_string(font, Vector2(x, p.y + sz * .35), t, HORIZONTAL_ALIGNMENT_LEFT, -1, int(sz), col)

func A(g: Dictionary, v: float) -> float:
	var o: Dictionary = g.o
	return o.a0 + (v - o.min) / (o.max - o.min) * (o.a1 - o.a0)

## dial face: arcs, ticks, numbers, titles
func dial(g: Dictionary) -> void:
	var c := P2(g.x, g.y); var Rr: float = g.r * PS
	draw_circle(c, Rr + 3, Color("0a0b0c")); draw_circle(c, Rr, Color("0b0c0d"))
	draw_circle(c + Vector2(0, -Rr * .15), Rr * .7, Color(1, 1, 1, .02))
	if not g.has("o") or g.o is not Dictionary: return
	var o: Dictionary = g.o
	for ar in o.get("arcs", []):
		var rr: float = ar[3] if ar.size() > 3 else .86
		draw_arc(c, Rr * rr, A(g, ar[0]), A(g, ar[1]), 24, Color(ar[2]), Rr * .1)
	var v: float = o.min
	while v <= o.max + 1e-6:
		var q = (v - o.min) / o.maj; var big := absf(q - roundf(q)) < 1e-3; var a := A(g, v)
		var d := Vector2(cos(a), sin(a))
		draw_line(c + d * Rr * .95, c + d * Rr * (.76 if big else .85), Color("eeeeee"), Rr * (.045 if big else .025))
		v += o.mn
	var small: bool = g.r <= .03
	for lv in o.lab:
		var a := A(g, lv); var s: String = o.fmt.call(lv) if o.has("fmt") else _num(lv)
		txt(s, c + Vector2(cos(a), sin(a)) * Rr * .6, Rr * (.24 if small else .17))
	txt(o.t, c + Vector2(0, Rr * .3), Rr * (.16 if small else .11), Color("bbbbbb"))
	if o.has("t2"): txt(o.t2, c + Vector2(0, Rr * .45), Rr * (.16 if small else .11), Color("bbbbbb"))

func _num(v: float) -> String:
	return str(int(v)) if absf(v - roundf(v)) < 1e-6 else str(v)

func needle(g: Dictionary, a: float, len := .82, w := .05, col := Color("f4f4f4")) -> void:
	var c := P2(g.x, g.y); var Rr: float = g.r * PS
	draw_set_transform(c, a, Vector2.ONE)
	var pts := PackedVector2Array([Vector2(-Rr * .18, -Rr * w), Vector2(Rr * len, -Rr * w * .3), Vector2(Rr * len, Rr * w * .3), Vector2(-Rr * .18, Rr * w)])
	draw_colored_polygon(pts.duplicate(), Color(0, 0, 0, .45), PackedVector2Array(), null)
	for i in pts.size(): pts[i] -= Vector2(0, 0)
	draw_colored_polygon(pts, col)
	draw_circle(Vector2.ZERO, Rr * .09, Color("222222"))
	draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)

## "ROTOR %" style annunciator block
func ann(x: float, y: float, w: float, h: float, t: String, col: Color, on: bool, fsz := 13.0) -> void:
	var r := Rect2(P2(x, y), Vector2(w * PS, h * PS))
	if on: draw_rect(r.grow(4), Color(col, .35))
	draw_rect(r, col if on else Color("191a1b"))
	txt(t, r.get_center(), fsz, Color("1a0a00") if on else Color("4a3a2a"))

## pitch / bank attitude ball (western style: horizon rolls)
func attitude_w(g: Dictionary, pit: float, rol: float, el: bool) -> void:
	var c := P2(g.x, g.y); var Rr: float = g.r * PS * .94
	var n := Vector2(-sin(rol), -cos(rol))   # screen "up" after the roll
	var off := pit * Rr * 2.2
	draw_circle(c, Rr, Color("7a4a24"))
	_fill_half(c, Rr, n, off, Color("2f78c4"))
	var t := Vector2(n.y, -n.x)
	var hc := c - n * off
	draw_line(hc - t * Rr, hc + t * Rr, Color.WHITE, 2)
	for pp in [-20, -15, -10, -5, 5, 10, 15, 20]:
		var y = hc + n * (pp * PI / 180 * Rr * 2.2); var hw := Rr * (.15 if pp % 10 else .3)
		if (y - c).length() < Rr * .9: draw_line(y - t * hw, y + t * hw, Color.WHITE, 2)
	for b in [-60, -30, -20, -10, 0, 10, 20, 30, 60]:
		var a := -PI / 2 + deg_to_rad(b)
		draw_line(c + Vector2(cos(a), sin(a)) * Rr * .85, c + Vector2(cos(a), sin(a)) * Rr * (.93 if b % 30 else .97), Color.WHITE, 2)
	var o := Color("ff9b1a")
	draw_polyline(PackedVector2Array([c + Vector2(-Rr * .55, 0), c + Vector2(-Rr * .18, 0), c + Vector2(0, Rr * .1), c + Vector2(Rr * .18, 0), c + Vector2(Rr * .55, 0)]), o, 4)
	if not el:
		draw_rect(Rect2(c + Vector2(-Rr * .5, Rr * .35), Vector2(Rr * .4, Rr * .22)), Color("dd2222"))
		txt("OFF", c + Vector2(-Rr * .3, Rr * .46), Rr * .17)

## fills the part of the disc on the +n side of the line at distance -off along n (sky)
func _fill_half(c: Vector2, Rr: float, n: Vector2, off: float, col: Color) -> void:
	# line: points p with (p).dot(n) = -off  (in disc coords, centred). Sky is p.dot(n) > -off
	var d := -off
	if d <= -Rr:
		draw_circle(c, Rr, col); return
	if d >= Rr: return
	var t := Vector2(n.y, -n.x); var h := sqrt(Rr * Rr - d * d)
	var a0 := (n * d + t * h).angle(); var a1 := (n * d - t * h).angle()
	var pts := PackedVector2Array()
	# arc from a0 to a1 passing through n direction
	var an := n.angle()
	var da := wrapf(a1 - a0, -PI, PI)
	# choose direction that passes near n
	var mid := a0 + da / 2
	if absf(wrapf(mid - an, -PI, PI)) > PI / 2: da = da - signf(da) * TAU
	for i in 33:
		var a := a0 + da * i / 32; pts.append(c + Vector2(cos(a), sin(a)) * Rr)
	draw_colored_polygon(pts, col)

func compass(g: Dictionary, hdg: float, el: bool, fs := .18) -> void:
	var c := P2(g.x, g.y); var Rr: float = g.r * PS * .94
	var rot := -deg_to_rad(hdg if el else 0.0)
	for d in range(0, 360, 5):
		var a := rot + deg_to_rad(d) - PI / 2; var u := Vector2(cos(a), sin(a))
		draw_line(c + u * Rr * .95, c + u * Rr * (.88 if d % 10 else .8), Color("eeeeee"), 1 if d % 10 else 2)
		if d % 30 == 0:
			var lab: String = {0: "N", 90: "E", 180: "S", 270: "W"}.get(d, str(d / 10))
			draw_set_transform(c + u * Rr * .64, a + PI / 2, Vector2.ONE)
			txt(lab, Vector2.ZERO, Rr * fs, Color("eeeeee"))
			draw_set_transform(Vector2.ZERO, 0, Vector2.ONE)
	var o := Color("ff9b1a")
	draw_line(c + Vector2(0, -Rr * .98), c + Vector2(0, -Rr * .75), o, 3); draw_line(c + Vector2(0, -Rr * .35), c + Vector2(0, Rr * .35), o, 3)
	draw_line(c + Vector2(-Rr * .25, 0), c + Vector2(Rr * .25, 0), o, 3); draw_line(c + Vector2(-Rr * .1, Rr * .3), c + Vector2(Rr * .1, Rr * .3), o, 3)

func digital(g: Dictionary, lines: Array, el: bool) -> void:
	var c := P2(g.x, g.y); var Rr: float = g.r * PS
	draw_rect(Rect2(c - Vector2(Rr * .8, Rr * .6), Vector2(Rr * 1.6, Rr * 1.2)), Color("0b120c"))
	if not el: return
	var fs := Rr * (.26 if g.r > .03 else .3)
	for i in lines.size():
		txt(lines[i], c + Vector2(0, (i - (lines.size() - 1) / 2.0) * Rr * .36), fs, Color("7dff9a"))
