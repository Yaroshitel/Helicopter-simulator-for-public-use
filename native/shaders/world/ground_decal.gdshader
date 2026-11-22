shader_type spatial;
// Flat things lying on the ground: apron, helipad, runway, roads, railway ballast, plant yard.
// They are drawn a fraction of the camera distance closer to the eye, straight along the view ray. That does not
// move them on screen, but it keeps them cleanly in front of the terrain at any distance and with any depth buffer,
// so they never z-fight ("flicker" or "mix") with the ground or with each other. `layer` orders overlapping decals.
render_mode cull_back;

uniform sampler2D albedo_tex : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_tex : filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec2 uv_scale = vec2(1.0);
uniform float rough = 0.85;
uniform float normal_depth = 1.0;
uniform float grime = 0.3;       // weathering stains from world-space noise
uniform float layer = 1.0;

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec4 v = MODELVIEW_MATRIX * vec4(VERTEX, 1.0);
	v.xyz *= 1.0 - 0.00045 * layer;
	POSITION = PROJECTION_MATRIX * v;
}

void fragment() {
	vec2 uv = UV * uv_scale;
	vec3 a = texture(albedo_tex, uv).rgb * tint.rgb;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float nk = 1.0 - smoothstep(80.0, 700.0, dist);
	float n1 = texture(noise_tex, wpos.xz / 2.7).r;
	float n2 = texture(noise_tex, wpos.xz / 19.0 + 0.3).r;
	float n3 = texture(noise_tex, wpos.xz / 0.6 + 0.7).r;
	a *= mix(1.0, 0.88 + 0.24 * n1, grime * nk);
	a *= 1.0 - smoothstep(0.58, 0.85, n2) * grime * 0.7;          // oil, water and tyre stains
	a = mix(a, a * vec3(0.95, 1.0, 0.9), smoothstep(0.7, 0.9, n2) * grime * 0.5);
	a *= mix(1.0, 0.9 + 0.2 * n3, nk * (1.0 - smoothstep(10.0, 80.0, dist)));
	ALBEDO = a;
	ROUGHNESS = clamp(rough + (n1 - 0.5) * 0.2 - smoothstep(0.6, 0.85, n2) * grime * 0.3, 0.05, 1.0);
	SPECULAR = 0.4;
	NORMAL_MAP = texture(normal_tex, uv).rgb;
	NORMAL_MAP_DEPTH = normal_depth;
}
