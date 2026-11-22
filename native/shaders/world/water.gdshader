shader_type spatial;
// Lake and river water:
//  - ripples from three scrolling normal-map samples (the river ones drift downstream), with sun glitter
//  - Fresnel: you look into the water from above and see the sky mirrored at grazing angles
//  - depth from the depth buffer: clear, slightly refracted shallows showing the gravel bed, deep teal further out
//  - a soft foam line where the water meets the bank
render_mode cull_disabled, specular_schlick_ggx;

uniform sampler2D normal_tex : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D foam_tex : filter_linear_mipmap, repeat_enable;
uniform sampler2D screen_tex : hint_screen_texture, filter_linear_mipmap, repeat_disable;
uniform sampler2D depth_tex : hint_depth_texture, filter_linear, repeat_disable;
uniform vec3 deep : source_color = vec3(0.02, 0.09, 0.1);
uniform vec3 shallow : source_color = vec3(0.12, 0.26, 0.24);
uniform float clarity = 0.42;   // light extinction per metre of water
uniform vec2 flow = vec2(0.0, 0.35);

varying vec3 wpos;

void vertex() {
	wpos = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

float scene_depth(float d, vec2 suv, mat4 ip) {
#if CURRENT_RENDERER == RENDERER_COMPATIBILITY
	vec4 v = ip * vec4(vec3(suv, d) * 2.0 - 1.0, 1.0);
#else
	vec4 v = ip * vec4(suv * 2.0 - 1.0, d, 1.0);
#endif
	return -v.z / v.w;
}

void fragment() {
	vec2 p = wpos.xz;
	bool river = length(p - vec2(230.0, 265.0)) > 190.0;
	vec2 fl = river ? flow : vec2(0.004, 0.006);
	vec3 n1 = texture(normal_tex, p / 23.0 + fl * TIME * 0.05).rgb * 2.0 - 1.0;
	vec3 n2 = texture(normal_tex, p / 9.0 + fl * TIME * 0.11 + vec2(0.37, 0.11)).rgb * 2.0 - 1.0;
	vec3 n3 = texture(normal_tex, p / 3.1 - vec2(TIME * 0.013, -TIME * 0.009) + fl * TIME * 0.3).rgb * 2.0 - 1.0;
	float dist = length(wpos - CAMERA_POSITION_WORLD);
	float fine = 1.0 - smoothstep(60.0, 600.0, dist);
	vec2 nxz = n1.xy * 0.45 + n2.xy * 0.35 + n3.xy * 0.3 * fine;
	vec3 nw = normalize(vec3(nxz.x, 2.2, nxz.y));
	NORMAL = normalize((VIEW_MATRIX * vec4(nw, 0.0)).xyz);

	float wz = -VERTEX.z;
	float thick = max(scene_depth(texture(depth_tex, SCREEN_UV).r, SCREEN_UV, INV_PROJECTION_MATRIX) - wz, 0.0);
	vec2 off = nxz * 0.035 * clamp(thick * 0.5, 0.0, 1.0) / max(1.0, dist * 0.02);
	vec2 ruv = SCREEN_UV + off;
	float th2 = scene_depth(texture(depth_tex, ruv).r, ruv, INV_PROJECTION_MATRIX) - wz;
	if (th2 < 0.0) { ruv = SCREEN_UV; th2 = thick; }
	// view-ray path length through the water is longer at grazing angles
	float ndv = clamp(dot(NORMAL, VIEW), 0.05, 1.0);
	float path = th2 / max(ndv, 0.15);
	vec3 tr = exp(-path * clarity * vec3(1.6, 0.75, 0.62));
	vec3 refr = textureLod(screen_tex, ruv, 0.0).rgb;
	float fres = 0.02 + 0.98 * pow(1.0 - ndv, 5.0);
	vec3 body = mix(shallow, deep, 1.0 - exp(-th2 * 0.35));
	vec3 under = refr * tr + body * (1.0 - tr) * 0.6;
	// foam where the bank comes up
	float fm = texture(foam_tex, p / 2.2 + fl * TIME * 0.2).r;
	float foam = smoothstep(0.75, 0.0, thick) * smoothstep(0.35, 0.8, fm + 0.25 * sin(TIME * 1.3 + p.x * 0.7 + p.y * 0.4));
	ALBEDO = vec3(0.85) * foam;
	EMISSION = under * (1.0 - fres) * (1.0 - foam);
	ROUGHNESS = mix(0.045, 0.7, foam);
	METALLIC = 0.0;
	SPECULAR = 0.5;
}
