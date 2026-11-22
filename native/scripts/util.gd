class_name U
## Shared maths and the valley layout (north = -z, east = +x). Ported 1:1 from the web version.

const WATER_Y := -3.2
const LAKE := Vector3(230, -3.2, 265)   # x, y, z ; radius below
const LAKE_R := 185.0
const TOWN_X := 1120.0
const TOWN_Z := 0.0
const TOWN_RX := 580.0
const TOWN_RZ := 1150.0

# terrain bake grid (shared by the bake tool, the mesh and the physics)
const TS := 9000.0
const TN := 600

static var _h: PackedFloat32Array
static var _loaded := false

static func clampf2(x: float, a: float, b: float) -> float:
	return a if x < a else (b if x > b else x)

static func sstep(a: float, b: float, x: float) -> float:
	x = clampf((x - a) / (b - a), 0.0, 1.0)
	return x * x * (3.0 - 2.0 * x)

static func hash2(x: float, y: float) -> float:
	var h := sin(x * 127.1 + y * 311.7) * 43758.5453
	return h - floorf(h)

static func vn(x: float, y: float) -> float:
	var xi := floorf(x); var yi := floorf(y); var xf := x - xi; var yf := y - yi
	var u := xf * xf * (3.0 - 2.0 * xf); var v := yf * yf * (3.0 - 2.0 * yf)
	var a := hash2(xi, yi); var b := hash2(xi + 1, yi); var c := hash2(xi, yi + 1); var d := hash2(xi + 1, yi + 1)
	return a + (b - a) * u + (c - a) * v + (a - b - c + d) * u * v

static func fbm(x: float, y: float, o: int = 6) -> float:
	var s := 0.0; var a := 0.5; var f := 1.0
	for i in o:
		s += a * vn(x * f, y * f); a *= 0.5; f *= 2.03
	return s

static func river_x(z: float) -> float:
	return 640.0 + 90.0 * sin(z * 0.0021) + 40.0 * sin(z * 0.0057 + 1.0)

static func town_e(x: float, z: float) -> float:
	return pow((x - TOWN_X) / TOWN_RX, 2) + pow((z - TOWN_Z) / TOWN_RZ, 2)

static func rail_x(z: float) -> float:
	return 1490.0 + (river_x(z) + 150.0 - 1490.0) * sstep(560, 1300, absf(z))

static func hill_k(x: float, z: float) -> float:
	return minf(minf(sstep(420, 1000, Vector2(x, z).length()), sstep(1, 2.3, town_e(x, z))),
		minf(sstep(90, 420, absf(x - river_x(z))), sstep(25, 170, absf(x - rail_x(z)))))

## analytic terrain height (used only by the bake tool and for placing objects at load)
static func ground_exact(x: float, z: float) -> float:
	var k := hill_k(x, z); var d := Vector2(x, z).length(); var dr := absf(x - river_x(z))
	var base := 0.0
	if k > 0:
		base = k * ((fbm(x * .0018 + 3, z * .0018 + 7) - .48) * 110.0 + pow(fbm(x * .0006 + 9, z * .0006), 2.2) * 420.0)
	var fl := (1.0 - k) * (fbm(x * .004 + 1, z * .004 + 2, 3) - .5) * 4.0 * sstep(380, 520, d) * sstep(.9, 1.3, town_e(x, z)) * sstep(20, 60, absf(x - rail_x(z)))
	var carve := minf(-6.5 * (1.0 - sstep(110, 195, Vector2(x - LAKE.x, z - LAKE.z).length())), -7.0 * (1.0 - sstep(20, 50, dr)))
	return base + fl + carve

static func load_height() -> void:
	if _loaded: return
	_loaded = true
	var f := FileAccess.open("res://baked/height.bin", FileAccess.READ)
	if f == null:
		push_error("baked terrain missing"); return
	_h = f.get_buffer(f.get_length()).to_float32_array()

## terrain height as rendered (triangle-interpolated from the baked grid)
static func ground_h(x: float, z: float) -> float:
	if _h.is_empty(): load_height()
	var step := TS / TN
	var gx := clampf((x + TS / 2) / step, 0, TN - 1e-3); var gz := clampf((z + TS / 2) / step, 0, TN - 1e-3)
	var i := int(gx); var j := int(gz); var fx := gx - i; var fz := gz - j
	var n := TN + 1
	var h00 := _h[j * n + i]; var h10 := _h[j * n + i + 1]; var h01 := _h[(j + 1) * n + i]; var h11 := _h[(j + 1) * n + i + 1]
	# same diagonal split as the mesh (00-11)
	if fx > fz:
		return h00 + (h10 - h00) * fx + (h11 - h10) * fz
	return h00 + (h11 - h01) * fx + (h01 - h00) * fz

static func wrap_a(a: float) -> float:
	return atan2(sin(a), cos(a))
