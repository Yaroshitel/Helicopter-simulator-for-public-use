shader_type sky;
// Sky: Rayleigh/Mie scattering (the same model as Godot's PhysicalSkyMaterial), a sun disk with limb darkening,
// a drifting layer of cumulus that is lit by the sun (self-shadowed, bright silver edges towards the sun,
// warm at sunrise/sunset, dark at night), and the star field at night.


uniform float rayleigh = 1.3;
uniform vec4 rayleigh_color : source_color = vec4(0.3, 0.405, 0.6, 1.0);
uniform float mie = 0.004;
uniform float mie_eccentricity = 0.85;
uniform vec4 mie_color : source_color = vec4(0.69, 0.729, 0.812, 1.0);
uniform float turbidity = 3.5;
uniform float sun_disk_scale = 1.0;
uniform vec4 ground_color : source_color = vec4(0.12, 0.12, 0.11, 1.0);
uniform float exposure = 0.9;
uniform sampler2D night_sky : filter_linear, source_color, hint_default_black;
uniform float night_k = 0.0;

uniform sampler2D cloud_noise : filter_linear_mipmap, repeat_enable;
uniform sampler2D cloud_cell : filter_linear_mipmap, repeat_enable;   // cellular: round, billowy cumulus heads
uniform float sun_e = 1.0;    // sky brightness from the sun; stays up through twilight while the sunlight itself fades
uniform float coverage = 0.42;
uniform float cloud_h = 1800.0;
uniform vec2 wind = vec2(5.0, 2.5);
uniform vec3 cloud_lit = vec3(1.0);       // direct light on the clouds (sun colour × energy, set by the game)
uniform vec3 cloud_shade = vec3(0.45, 0.5, 0.6);   // ambient sky light in the shadowed parts
uniform float cloud_time = 0.0;

const vec3 UP = vec3(0.0, 1.0, 0.0);
const float rayleigh_zenith_size = 8.4e3;
const float mie_zenith_size = 1.25e3;

float hg(float c, float g) {
	return 0.0795774715459 * (1.0 - g * g) / pow(1.0 + g * g - 2.0 * g * c, 1.5);
}

float cdens(vec2 p, int oct) {
	float n = texture(cloud_noise, p * 0.00005).r * 0.55;
	n += (1.0 - texture(cloud_cell, p * 0.00016 + vec2(0.31, 0.17)).r) * 0.3;
	if (oct > 2) {
		n += (1.0 - texture(cloud_cell, p * 0.00055 + vec2(0.71, 0.43)).r) * 0.1;
		n += texture(cloud_noise, p * 0.0016 + vec2(0.13, 0.91)).r * 0.05;
	} else {
		n += 0.075;
	}
	float c0 = 1.0 - coverage;
	return smoothstep(c0, c0 + 0.2, n);
}

void sky() {
	vec3 sd = normalize(LIGHT0_DIRECTION);
	float cos_theta = dot(EYEDIR, sd);
	vec3 color = vec3(0.0);
	float sun_energy = 0.0;
	vec3 extinction = vec3(1.0);
	if (LIGHT0_ENABLED) {
		float zenith_angle = clamp(dot(UP, sd), -1.0, 1.0);
		sun_energy = max(0.0, 1.0 - exp(-((PI * 0.5) - acos(max(zenith_angle, 0.0)) + 0.12))) * sun_e;
		float sun_fade = 1.0 - clamp(1.0 - exp(sd.y), 0.0, 1.0);
		float rc = rayleigh - (1.0 - sun_fade);
		vec3 rb = rc * rayleigh_color.rgb * 0.0001;
		vec3 mb = turbidity * mie * mie_color.rgb * 0.000434;
		float zenith = acos(max(0.0, dot(UP, EYEDIR)));
		float om = 1.0 / (cos(zenith) + 0.15 * pow(93.885 - degrees(zenith), -1.253));
		extinction = exp(-(rb * rayleigh_zenith_size * om + mb * mie_zenith_size * om));
		float rp = (3.0 / (16.0 * PI)) * (1.0 + pow(cos_theta * 0.5 + 0.5, 2.0));
		vec3 brt = rb * rp;
		vec3 bmt = mb * hg(cos_theta, mie_eccentricity);
		vec3 lin = pow(sun_energy * ((brt + bmt) / (rb + mb)) * (1.0 - extinction), vec3(1.5));
		lin *= mix(vec3(1.0), pow(sun_energy * ((brt + bmt) / (rb + mb)) * extinction, vec3(0.5)), clamp(pow(1.0 - zenith_angle, 5.0), 0.0, 1.0));
		lin *= mix(ground_color.rgb, vec3(1.0), smoothstep(-0.1, 0.1, EYEDIR.y));
		// sun disk with limb darkening
		float ca = cos(LIGHT0_SIZE * sun_disk_scale);
		float r = clamp((1.0 - cos_theta) / max(1.0 - ca, 1e-6), 0.0, 1.0);
		float disk = (1.0 - smoothstep(0.85, 1.0, r)) * (0.6 + 0.4 * sqrt(max(0.0, 1.0 - r * r)));
		// the disk only in the visible sky: the sun already lights the scene as a light, so it must not also
		// be baked into the reflection / ambient cubemap (that made rough surfaces glow)
		vec3 l0 = AT_CUBEMAP_PASS ? vec3(0.0) : sun_energy * extinction * disk * LIGHT0_COLOR * 18.0;
		color = pow(lin, vec3(1.0 / (1.2 + 1.2 * sun_fade))) + l0;
	}
	vec3 stars = texture(night_sky, SKY_COORDS).rgb * night_k * smoothstep(-0.02, 0.1, EYEDIR.y);
	color += stars;

	// cloud layer
	if (EYEDIR.y > 0.004) {
		vec2 p = EYEDIR.xz / EYEDIR.y * cloud_h + wind * cloud_time;
		int oct = (AT_CUBEMAP_PASS || EYEDIR.y < 0.12) ? 2 : 4;
		float d = cdens(p, oct);
		if (d > 0.001) {
			vec2 so = sd.xz / max(sd.y, 0.08);
			so = normalize(so + 1e-5) * min(length(so), 3.0) * 140.0;
			float d1 = cdens(p + so * 0.5, 2);
			float d2 = (AT_CUBEMAP_PASS || d < 0.15) ? d1 : cdens(p + so, 2);
			float lt = exp(-(d1 + d2) * 1.6);                 // light that gets through the cloud towards the sun
			float ph = 0.55 + 2.2 * hg(cos_theta, 0.62) + 0.35 * hg(cos_theta, -0.2);
			float edge = 1.0 - smoothstep(0.0, 0.6, d);        // thin edges glow when back-lit
			vec3 c = cloud_shade * (0.75 + 0.35 * (1.0 - d)) + cloud_lit * (lt * 0.9 + edge * 0.35) * ph * 0.55;
			float far = EYEDIR.y;
			float fade = smoothstep(0.0, 0.16, far);
			c = mix(color, c, 0.35 + 0.65 * smoothstep(0.0, 0.25, far));   // distant clouds take on the haze colour
			float a = clamp(d * 1.25, 0.0, 1.0) * fade;
			color = mix(color, c, a);
		}
	}
	COLOR = color * exposure;
}
