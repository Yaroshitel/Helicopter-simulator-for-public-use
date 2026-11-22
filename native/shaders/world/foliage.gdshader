shader_type spatial;
// Tree crowns and conifer foliage: leaf-clump detail from tri-planar noise (colour, bumps, self-shadowing in the
// gaps), darker undersides and inner parts, light shining through thin edges, and a gentle wind sway that grows
// towards the top of the tree. Each tree's tint comes from its MultiMesh instance colour.
render_mode cull_back, diffuse_burley;

uniform sampler2D noise_t : filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D noise_n : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float clump = 0.9;      // size of leaf clumps (m)
uniform float sway = 1.0;
uniform float sway_h = 3.0;     // height above which the crown moves
uniform float needle = 0.0;     // 1 = conifer: finer, darker, bluish texture

varying vec3 wp;
varying vec3 wn;

vec3 tri_w(vec3 n) {
	vec3 w = pow(abs(n), vec3(3.0));
	return w / (w.x + w.y + w.z);
}

void vertex() {
	vec3 org = MODEL_MATRIX[3].xyz;
	float ph = dot(org.xz, vec2(0.13, 0.17));
	float k = max(VERTEX.y - sway_h, 0.0) * 0.1;
	k *= k;
	VERTEX.x += (sin(TIME * 1.1 + ph) * 0.6 + sin(TIME * 2.9 + ph * 2.1) * 0.25) * 0.12 * k * sway;
	VERTEX.z += (cos(TIME * 0.9 + ph * 1.3) * 0.6 + sin(TIME * 3.3 + ph) * 0.2) * 0.1 * k * sway;
	wp = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	wn = normalize((MODEL_MATRIX * vec4(NORMAL, 0.0)).xyz);
}

void fragment() {
	vec3 w = tri_w(wn);
	float sc = mix(clump, clump * 0.35, needle);
	vec3 p = wp / sc;
	float n = texture(noise_t, p.zy).r * w.x + texture(noise_t, p.xz).r * w.y + texture(noise_t, p.xy).r * w.z;
	vec3 q = wp / (sc * 3.7);
	float n2 = texture(noise_t, q.zy + 0.3).r * w.x + texture(noise_t, q.xz + 0.3).r * w.y + texture(noise_t, q.xy + 0.3).r * w.z;
	vec3 c = COLOR.rgb * COLOR.rgb * 1.5;   // instance tint is given in display (sRGB-like) values
	c *= 0.62 + 0.75 * n;
	c *= 0.85 + 0.3 * n2;
	c = mix(c, c * vec3(1.18, 1.12, 0.78), smoothstep(0.62, 0.85, n2) * 0.35 * (1.0 - needle));   // sun-bleached leaves
	c = mix(c, c * vec3(0.85, 0.95, 1.08), needle * 0.4);
	float up = wn.y * 0.5 + 0.5;
	c *= mix(0.55, 1.08, up);
	// gaps between clumps are deep and dark
	float gap = smoothstep(0.42, 0.2, n);
	ALBEDO = c * (1.0 - gap * 0.45);
	vec3 tn = texture(noise_n, p.xz * 0.7).rgb * 2.0 - 1.0;
	vec3 nw = normalize(wn + vec3(tn.x, 0.0, tn.y) * 0.9 + (vec3(n, n2, n) - 0.5) * 0.6);
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);
	ROUGHNESS = 0.78;
	SPECULAR = 0.3;
	BACKLIGHT = c * 0.5;
	AO = mix(0.35, 1.0, (1.0 - gap) * (0.55 + 0.45 * up));
	AO_LIGHT_AFFECT = 0.45;
}
