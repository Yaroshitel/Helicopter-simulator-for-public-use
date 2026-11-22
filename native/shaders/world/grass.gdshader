shader_type spatial;
// Grass blades in a patch that follows the camera. Each instance is a fixed world grid point (the patch is moved
// in whole grid steps, so blades never swim); jitter, turn, size and density come from a hash of that point and from
// the baked ground maps. Each blade stands exactly on the terrain triangle below it, bends in the wind and is
// pressed down and outwards by the rotor downwash.
render_mode cull_disabled, diffuse_burley;

uniform sampler2D color_map : filter_linear, repeat_disable;
uniform sampler2D mask_map : filter_linear, repeat_disable;
uniform sampler2D height_map : filter_nearest, repeat_disable;
uniform sampler2D excl_map : filter_linear, repeat_disable;   // 0 where there is no grass: paving, roads, water, buildings
uniform float TS = 9000.0;
uniform float TN = 600.0;
uniform float spacing = 0.55;
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

float ground(vec2 xz) {
	float st = TS / TN;
	vec2 g = clamp((xz + TS * 0.5) / st, vec2(0.0), vec2(TN - 0.001));
	ivec2 i = ivec2(floor(g));
	vec2 f = g - vec2(i);
	float h00 = texelFetch(height_map, i, 0).r;
	float h10 = texelFetch(height_map, i + ivec2(1, 0), 0).r;
	float h01 = texelFetch(height_map, i + ivec2(0, 1), 0).r;
	float h11 = texelFetch(height_map, i + ivec2(1, 1), 0).r;
	if (f.x > f.y) return h00 + (h10 - h00) * f.x + (h11 - h10) * f.y;
	return h00 + (h11 - h01) * f.x + (h01 - h00) * f.y;
}

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	vec2 cellp = floor(org.xz / spacing + 0.5);
	float r1 = h21(cellp), r2 = h21(cellp + 13.7), r3 = h21(cellp + 29.1), r4 = h21(cellp + 41.3);
	vec2 base = org.xz + (vec2(r1, r2) - 0.5) * spacing * 1.6;
	vec2 muv = (base + TS * 0.5) / TS * (TN / (TN + 1.0)) + 0.5 / (TN + 1.0);
	vec4 m = textureLod(mask_map, muv, 0.0);
	float ex = textureLod(excl_map, (base + TS * 0.5) / TS, 0.0).r;
	float gy = ground(base);
	float st = TS / TN;
	float sl = abs(ground(base + vec2(2.0, 0.0)) - gy) + abs(ground(base + vec2(0.0, 2.0)) - gy);
	float dens = smoothstep(0.35, 0.8, ex) * (1.0 - 0.75 * m.r) * (1.0 - 0.6 * m.g) * (1.0 - smoothstep(0.1, 0.5, m.b)) * (1.0 - smoothstep(0.05, 0.3, m.a));
	dens *= 1.0 - smoothstep(0.7, 1.3, sl);
	dens *= smoothstep(-2.2, -1.2, gy);
	float cd = length(base - CAMERA_POSITION_WORLD.xz);
	float fade = 1.0 - smoothstep(radius * 0.55, radius, cd);
	float hs = (0.6 + 0.8 * r4) * step(r3, dens) * fade * (0.5 + 0.5 * dens);
	// own turn and size
	float a = r1 * 6.2832;
	vec3 v = VERTEX;
	v = vec3(v.x * cos(a) - v.z * sin(a), v.y, v.x * sin(a) + v.z * cos(a));
	v *= vec3(0.8 + 0.4 * r2, hs, 0.8 + 0.4 * r2);
	float k = UV.y * UV.y;
	// wind: slow sway plus a faster flutter
	float ph = dot(base, vec2(0.21, 0.17));
	vec2 wdir = wind_v.xz;
	float gust = 0.6 + 0.4 * sin(TIME * 0.7 + dot(base, wdir) * 0.03);
	vec2 off = wdir * 0.035 * gust * (0.6 + 0.4 * sin(TIME * 2.3 + ph)) + vec2(sin(TIME * 4.1 + ph * 3.0), cos(TIME * 3.7 + ph * 2.0)) * 0.02;
	// rotor downwash: flattens and fans the grass out from below the disc, with a strong flutter
	vec2 rd = base - rotor_pos.xz;
	float rl = max(length(rd), 0.3);
	float hgt = max(rotor_pos.y - gy, 0.0);
	float wash = rotor_k * (1.0 - smoothstep(rotor_r * 0.3, rotor_r * 2.6, rl)) * (1.0 - smoothstep(rotor_r * 0.5, rotor_r * 3.0, hgt));
	off += rd / rl * wash * (0.55 + 0.25 * sin(TIME * 13.0 + rl * 2.0 + r1 * 6.0));
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
