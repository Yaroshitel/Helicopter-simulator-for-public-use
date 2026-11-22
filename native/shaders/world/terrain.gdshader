shader_type spatial;
// Valley ground. Everything is computed per pixel from four small baked maps (biome colour, material mask, height)
// plus two tiling noise textures, so there are no overlapping ground planes and nothing can flicker:
//  - smooth per-pixel normals from the height map (no 15 m terrain facets)
//  - grass with three scales of variation, dry patches and clumps; anti-tiling by mixing rotated, rescaled samples
//  - rock with strata on steep slopes (tri-planar), forest floor, gravel banks, snow
//  - fields with furrows in each field's own direction and grassy margins / farm tracks between fields
//  - fine detail fades with distance so the far ground stays calm instead of shimmering
render_mode cull_back;

uniform sampler2D color_map : filter_linear, repeat_disable;
uniform sampler2D mask_map : filter_linear, repeat_disable;     // R field, G forest floor, B gravel bank, A snow
uniform sampler2D height_map : filter_linear, repeat_disable;   // metres (RF)
uniform sampler2D noise_a : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_b : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D detail_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float TS = 9000.0;
uniform float TN = 600.0;
uniform float detail_k = 1.0;   // graphics quality: 0.6 low … 1 high

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

vec2 muv(vec2 xz) {
	return (xz + TS * 0.5) / TS * (TN / (TN + 1.0)) + 0.5 / (TN + 1.0);
}

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

// two rotated, differently scaled samples blended by a slow noise: hides the texture repeat
float nmix(sampler2D t, vec2 p, float sc, float macro) {
	const mat2 R = mat2(vec2(0.8, 0.6), vec2(-0.6, 0.8));
	float a = texture(t, p / sc).r;
	float b = texture(t, R * p / (sc * 1.37) + 0.37).r;
	return mix(a, b, smoothstep(0.3, 0.7, macro));
}

void fragment() {
	vec2 uv = muv(wpos.xz);
	float tx = 1.0 / (TN + 1.0);
	float st = TS / TN;
	float hL = texture(height_map, uv - vec2(tx, 0.0)).r;
	float hR = texture(height_map, uv + vec2(tx, 0.0)).r;
	float hD = texture(height_map, uv - vec2(0.0, tx)).r;
	float hU = texture(height_map, uv + vec2(0.0, tx)).r;
	vec3 N = normalize(vec3(hL - hR, 2.0 * st, hD - hU));
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float near_k = (1.0 - smoothstep(60.0, 900.0, dist)) * detail_k;
	float mid_k = 1.0 - smoothstep(900.0, 4500.0, dist);

	vec3 base = texture(color_map, uv).rgb;
	float bl = dot(base, vec3(0.3, 0.59, 0.11));
	base = max(mix(vec3(bl), base, 0.92), vec3(0.0)) * vec3(0.5, 0.5, 0.42);   // natural olive greens rather than lime
	vec4 m = texture(mask_map, uv);
	vec2 p = wpos.xz;

	float macro = texture(noise_b, p / 410.0).r;
	float big = texture(noise_b, p / 97.0 + 0.21).r;
	float mid = nmix(noise_a, p, 9.0, macro);
	float fine = nmix(noise_a, p, 1.7, big);
	float micro = texture(noise_b, p / 0.45).r;

	// ---- grass / meadow
	vec3 g = base;
	g *= mix(1.0, 0.82 + 0.36 * big, mid_k);
	g *= mix(1.0, 0.8 + 0.4 * mid, mid_k * 0.9);
	g = mix(g, g * vec3(1.14, 1.04, 0.78), smoothstep(0.55, 0.8, macro) * 0.4 * mid_k);   // dry, yellowed patches
	g = mix(g, g * vec3(0.78, 0.9, 0.8), smoothstep(0.55, 0.8, mid) * 0.5);               // lush darker clumps
	g *= mix(1.0, 0.78 + 0.44 * fine, near_k);
	g *= mix(1.0, 0.88 + 0.24 * micro, near_k * (1.0 - smoothstep(8.0, 60.0, dist)));
	float rough = 0.93;

	// ---- fields: furrows along each field's own direction, grassy margins and farm tracks between fields
	float fw = m.r;
	if (fw > 0.01) {
		vec2 fu = vec2((p.x + p.y * 0.3) / 90.0, (p.y - p.x * 0.2) / 130.0);
		vec2 cell = floor(fu);
		float hh = h21(cell);
		float ang = hh * 3.1416 + (h21(cell + 7.1) > 0.5 ? 0.0 : 1.5708);
		vec2 dir = vec2(cos(ang), sin(ang));
		float row = dot(p, dir) / (1.4 + hh * 0.8);
		float fadeF = 1.0 - smoothstep(0.0, 1.0, fwidth(row) * 1.5);
		float fur = sin(row * 6.2832);
		vec3 fc = g * (1.0 + fur * 0.14 * fadeF);
		fc = mix(fc, fc * vec3(1.06, 0.95, 0.85), smoothstep(0.4, 0.9, fur) * fadeF * 0.4 * float(hh > 0.6));
		vec2 e = min(fract(fu), 1.0 - fract(fu)) * vec2(90.0, 130.0);
		float edge = min(e.x, e.y);
		float marg = 1.0 - smoothstep(1.2, 3.2, edge);
		vec3 margc = mix(vec3(0.14, 0.2, 0.07), vec3(0.3, 0.26, 0.17), step(0.72, h21(cell + 3.3)));   // hedge or dirt track
		fc = mix(fc, margc * (0.8 + 0.4 * mid), marg * 0.85);
		g = mix(g, fc, fw);
	}

	// ---- forest floor: darker, brown leaf litter and needles
	vec3 forest = mix(vec3(0.075, 0.08, 0.04), vec3(0.13, 0.1, 0.06), smoothstep(0.35, 0.7, mid)) * (0.75 + 0.5 * fine);
	g = mix(g, forest, m.g * 0.65);

	// ---- gravel / sand banks along the river and the lake
	vec3 sand = vec3(0.46, 0.42, 0.34) * (0.82 + 0.3 * fine) * (0.9 + 0.2 * micro);
	sand = mix(sand, vec3(0.3, 0.29, 0.27) * (0.7 + 0.6 * micro), smoothstep(0.55, 0.75, mid) * 0.6);   // pebbles
	float sw = smoothstep(0.15, 0.7, m.b);
	g = mix(g, sand, sw);
	float wet = 1.0 - smoothstep(-2.6, -1.2, wpos.y);
	g *= 1.0 - wet * 0.35;
	rough = mix(rough, 0.55, wet);

	// ---- exposed rock on steep slopes (tri-planar, layered)
	float slope = 1.0 - N.y;
	vec3 bw = pow(abs(N), vec3(4.0)); bw /= (bw.x + bw.y + bw.z);
	float rn = texture(noise_a, wpos.zy / 6.0).r * bw.x + texture(noise_a, wpos.xz / 6.0).r * bw.y + texture(noise_a, wpos.xy / 6.0).r * bw.z;
	float strata = sin(wpos.y * 1.3 + rn * 5.0) * 0.5 + 0.5;
	vec3 rock = mix(vec3(0.27, 0.26, 0.24), vec3(0.4, 0.37, 0.32), rn) * (0.82 + 0.25 * strata);
	float rk = smoothstep(0.2, 0.34, slope + (mid - 0.5) * 0.12);
	g = mix(g, rock, rk * (1.0 - m.a));
	rough = mix(rough, 0.82, rk);

	// ---- snow on the high tops
	vec3 snow = vec3(0.86, 0.88, 0.92) * (0.93 + 0.1 * fine);
	float sn = smoothstep(0.2, 0.6, m.a + (mid - 0.5) * 0.3);
	g = mix(g, snow, sn);
	rough = mix(rough, 0.45, sn);

	// ---- detail normal (bumps, clods, stones) blended onto the smooth terrain normal
	vec3 d1 = texture(detail_n, p / 2.3).rgb * 2.0 - 1.0;
	vec3 d2 = texture(detail_n, p / 11.0 + 0.5).rgb * 2.0 - 1.0;
	float ds = near_k * (0.5 + rk * 0.9 + sw * 0.4) * (1.0 - sn * 0.6);
	vec3 nw = normalize(vec3(N.x + (d1.x * 0.6 + d2.x * 0.5) * ds, N.y, N.z + (d1.y * 0.6 + d2.y * 0.5) * ds));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	ALBEDO = g;
	ROUGHNESS = rough;
	SPECULAR = 0.35;
	// cavities between clumps get a touch of ambient occlusion
	AO = mix(1.0, 0.65 + 0.35 * fine, near_k * (1.0 - sn));
	AO_LIGHT_AFFECT = 0.25;
}
