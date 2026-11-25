shader_type spatial;
// Grass blades in a patch that follows the camera. Each instance is a fixed world grid point (the patch is moved
// in whole grid steps, so blades never swim); jitter, turn, size and density come from a hash of that point and from
// the baked ground maps. Each blade stands exactly on the terrain triangle below it, bends in the wind and is
// pressed down and outwards by the rotor downwash.
render_mode cull_disabled;

uniform sampler2D color_map : filter_linear, repeat_disable;
uniform sampler2D mask_map : filter_linear, repeat_disable;
uniform sampler2D height_map : filter_linear, repeat_disable;
uniform sampler2D excl_map : filter_linear, repeat_disable;   // 0 where there is no grass: paving, roads, water, buildings
uniform float TS = 9000.0;
uniform float TN = 600.0;
uniform float spacing = 0.62;
uniform float radius = 40.0;
uniform vec3 wind_v = vec3(2.6, 0.0, 1.5);
uniform vec3 rotor_pos = vec3(0.0, -1000.0, 0.0);
uniform float rotor_r = 5.0;
uniform float rotor_k = 0.0;

varying vec3 gcol;
varying float tip;

float h21(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

vec2 to_muv(vec2 xz) {
	return (xz + TS * 0.5) / TS * (TN / (TN + 1.0)) + 0.5 / (TN + 1.0);
}

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	vec2 cellp = floor(org.xz / spacing + 0.5);
	float r1 = h21(cellp), r2 = h21(cellp + 13.7);
	vec2 base = org.xz + (vec2(r1, r2) - 0.5) * spacing * 1.6;
	float cd = length(base - CAMERA_POSITION_WORLD.xz);
	float ex = textureLod(excl_map, (base + TS * 0.5) / TS, 0.0).r;
	// Early-out clumps outside radius or on concrete/roads/water: collapses to degenerate triangle off-screen
	if (cd >= radius || ex <= 0.35) {
		VERTEX = vec3(0.0, -1000.0, 0.0);
		gcol = vec3(0.0);
		tip = 0.0;
		return;
	}
	float r3 = h21(cellp + 29.1), r4 = h21(cellp + 41.3);
	vec2 muv = to_muv(base);
	vec4 m = textureLod(mask_map, muv, 0.0);
	float gy = textureLod(height_map, muv, 0.0).r;
	float dstep = 2.0 / TS * (TN / (TN + 1.0));
	float sl = abs(textureLod(height_map, muv + vec2(dstep, 0.0), 0.0).r - gy) + abs(textureLod(height_map, muv + vec2(0.0, dstep), 0.0).r - gy);
	float dens = smoothstep(0.35, 0.8, ex) * (1.0 - 0.75 * m.r) * (1.0 - 0.6 * m.g) * (1.0 - smoothstep(0.1, 0.5, m.b)) * (1.0 - smoothstep(0.05, 0.3, m.a));
	dens *= 1.0 - smoothstep(0.7, 1.3, sl);
	dens *= smoothstep(-2.2, -1.2, gy);
	float fade = 1.0 - smoothstep(radius * 0.55, radius, cd);
	float hs = (0.6 + 0.8 * r4) * step(r3, dens) * fade * (0.5 + 0.5 * dens);
	if (hs <= 0.005) {
		VERTEX = vec3(0.0, -1000.0, 0.0);
		gcol = vec3(0.0);
		tip = 0.0;
		return;
	}
	// own turn and size
	float a = r1 * 6.2832;
	float ca = cos(a), sa = sin(a);
	vec3 v = VERTEX;
	v = vec3(v.x * ca - v.z * sa, v.y, v.x * sa + v.z * ca);
	float sx = 0.8 + 0.4 * r2;
	v *= vec3(sx, hs, sx);
	float k = UV.y * UV.y;
	// wind: slow sway plus a faster flutter
	float ph = dot(base, vec2(0.21, 0.17));
	vec2 wdir = wind_v.xz;
	float gust = 0.6 + 0.4 * sin(TIME * 0.7 + dot(base, wdir) * 0.03);
	vec2 off = wdir * 0.035 * gust * (0.6 + 0.4 * sin(TIME * 2.3 + ph)) + vec2(sin(TIME * 4.1 + ph * 3.0), cos(TIME * 3.7 + ph * 2.0)) * 0.02;
	// rotor downwash: flattens and fans the grass out from below the disc, with a strong flutter
	if (rotor_k > 0.01) {
		vec2 rd = base - rotor_pos.xz;
		float rl = max(length(rd), 0.3);
		float hgt = max(rotor_pos.y - gy, 0.0);
		float wash = rotor_k * (1.0 - smoothstep(rotor_r * 0.3, rotor_r * 2.6, rl)) * (1.0 - smoothstep(rotor_r * 0.5, rotor_r * 3.0, hgt));
		off += rd / rl * wash * (0.55 + 0.25 * sin(TIME * 13.0 + rl * 2.0 + r1 * 6.0));
	}
	float bend = clamp(length(off), 0.0, 0.95);
	v.xz += off * k * hs * 0.9;
	v.y *= 1.0 - bend * bend * 0.55 * k;
	VERTEX = vec3(base.x + v.x, gy + v.y, base.y + v.z) - org;
	NORMAL = normalize(mix(NORMAL, vec3(0.0, 1.0, 0.0), 0.65));
	vec3 c = textureLod(color_map, muv, 0.0).rgb;
	float bl = dot(c, vec3(0.3, 0.59, 0.11));
	c = max(mix(vec3(bl), c, 0.92), vec3(0.0)) * vec3(0.5, 0.5, 0.42);
	c *= 0.85 + 0.3 * r2;
	c = mix(c, c * vec3(1.15, 1.08, 0.8), step(0.85, r4) * 0.5);
	gcol = c;
	tip = UV.y;
}

void fragment() {
	vec3 c = gcol * mix(0.55, 1.15, tip);
	c = mix(c, c * vec3(1.08, 1.05, 0.85), smoothstep(0.8, 1.0, tip) * 0.4);
	ALBEDO = c;
	ROUGHNESS = 0.82;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.55;
	AO = mix(0.5, 1.0, tip);
	AO_LIGHT_AFFECT = 0.3;
}
