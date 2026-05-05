shader_type spatial;
render_mode cull_back, diffuse_burley, specular_schlick_ggx;

uniform vec3 grass_dark : source_color = vec3(0.18, 0.28, 0.12);
uniform vec3 grass_mid : source_color = vec3(0.32, 0.46, 0.22);
uniform vec3 grass_highlight : source_color = vec3(0.48, 0.62, 0.30);
uniform vec3 dirt_color : source_color = vec3(0.32, 0.24, 0.16);
uniform float roughness_value : hint_range(0.0, 1.0) = 0.92;
uniform float noise_scale : hint_range(0.5, 60.0) = 14.0;
uniform float dirt_threshold : hint_range(0.0, 1.0) = 0.08;
uniform float patch_scale : hint_range(0.5, 30.0) = 3.5;

float hash(vec2 p) {
	return fract(sin(dot(p, vec2(127.1, 311.7))) * 43758.5453);
}

float noise(vec2 p) {
	vec2 i = floor(p);
	vec2 f = fract(p);
	f = f * f * (3.0 - 2.0 * f);
	return mix(
		mix(hash(i), hash(i + vec2(1.0, 0.0)), f.x),
		mix(hash(i + vec2(0.0, 1.0)), hash(i + vec2(1.0, 1.0)), f.x),
		f.y
	);
}

float fbm(vec2 p) {
	float v = 0.0;
	float a = 0.5;
	for (int i = 0; i < 4; i++) {
		v += a * noise(p);
		p *= 2.0;
		a *= 0.5;
	}
	return v;
}

void fragment() {
	// World-space UV-ish from VERTEX (so the texture doesn't stretch with mesh size)
	vec2 wp = VERTEX.xz;
	float micro = fbm(wp * noise_scale);
	float patch = fbm(wp * patch_scale);
	float sparkle = noise(wp * noise_scale * 4.0);

	// Layered green tones
	vec3 col = mix(grass_dark, grass_mid, micro);
	col = mix(col, grass_highlight, sparkle * 0.5);

	// Dirt patches: where the larger noise dips below threshold, blend in dirt
	float dirt_mix = smoothstep(dirt_threshold, dirt_threshold + 0.06, patch * 0.6);
	col = mix(dirt_color, col, dirt_mix);

	ALBEDO = col;
	ROUGHNESS = roughness_value;
	SPECULAR = 0.15;
}
