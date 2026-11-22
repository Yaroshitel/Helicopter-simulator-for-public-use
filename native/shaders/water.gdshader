shader_type spatial;
// Lake and river: two scrolling normal maps, fresnel sky reflection, sun glints.
uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap, repeat_enable;
uniform vec3 deep : source_color = vec3(0.04, 0.16, 0.2);
uniform vec3 shallow : source_color = vec3(0.1, 0.28, 0.3);
void fragment() {
	vec2 uv = UV * 2.5;
	vec3 n1 = texture(normal_tex, uv + TIME * vec2(0.012, 0.007)).rgb;
	vec3 n2 = texture(normal_tex, uv * 0.37 - TIME * vec2(0.006, 0.011)).rgb;
	NORMAL_MAP = normalize(mix(n1, n2, 0.5));
	NORMAL_MAP_DEPTH = 0.6;
	float fres = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 4.0);
	ALBEDO = mix(deep, shallow, 0.3) * (1.0 - fres * 0.6);
	METALLIC = 0.0;
	SPECULAR = 0.9;
	ROUGHNESS = 0.04;
}
