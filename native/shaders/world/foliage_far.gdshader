shader_type spatial;
// Lightweight shader for distant tree LODs and vineyards: skips double tri-planar sampling,
// normal mapping, and vertex wind sway for a ~7x fragment speedup at distance.
render_mode cull_back;

uniform sampler2D noise_t : filter_linear_mipmap, repeat_enable;
uniform float clump = 2.0;
uniform float needle = 0.0;

varying vec3 wp;
varying vec3 wn;

void vertex() {
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	float sc = mix(clump, clump * 0.45, needle);
	float n = texture(noise_t, wp.xz / sc).r;
	vec3 c = COLOR.rgb * COLOR.rgb * 1.5;
	c *= 0.72 + 0.56 * n;
	c = mix(c, c * vec3(0.85, 0.95, 1.08), needle * 0.4);
	float up = wn.y * 0.5 + 0.5;
	c *= mix(0.55, 1.08, up);
	ALBEDO = c;
	ROUGHNESS = 0.85;
	SPECULAR = 0.2;
}
