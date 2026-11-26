// Adapted from 2Retr0/GodotGrass, MIT copyright 2024 Ethan Truong.
// See res://third_party/godot_grass/LICENSE and PROTOTYPE.md.
shader_type spatial;
render_mode cull_disabled, diffuse_burley;

group_uniforms Blade;
uniform float blade_height : hint_range(0.1, 1.0) = 0.30;
uniform float blade_width : hint_range(0.02, 0.2) = 0.038;
uniform float wind_strength : hint_range(0.0, 2.0) = 0.38;
uniform sampler2D wind_noise : repeat_enable, filter_linear;

group_uniforms Colour;
uniform vec3 root_color : source_color = vec3(0.30, 0.38, 0.18);
uniform vec3 tip_color : source_color = vec3(0.46, 0.52, 0.25);

group_uniforms Distance;
uniform float fade_start = 74.0;
uniform float fade_end = 90.0;

varying float blade_tip;
varying float color_seed;

float blade_hash(vec2 at) {
	return fract(sin(dot(at, vec2(127.1, 311.7))) * 43758.5453);
}

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	float seed = blade_hash(origin.xz);
	float patch = texture(wind_noise, origin.xz * 0.019).r;
	float height_variation = mix(0.78, 1.18, mix(seed, patch, 0.55));
	VERTEX.x *= blade_width / 0.1 * mix(0.78, 1.12, seed);
	VERTEX.y *= blade_height / 0.75 * height_variation;
	float tip = UV.y;
	vec2 field = origin.xz * 0.024 + vec2(TIME * 0.034, TIME * 0.018);
	float gust = texture(wind_noise, field).r * 2.0 - 1.0;
	float sway = gust * wind_strength * tip * tip;
	VERTEX.xz += vec2(0.66, 0.32) * sway;
	NORMAL = normalize(NORMAL + vec3(-sway * 0.45, 0.55, -sway * 0.2));
	vec3 delta = origin - CAMERA_POSITION_WORLD;
	float fade = 1.0 - smoothstep(fade_start * fade_start, fade_end * fade_end, dot(delta, delta));
	VERTEX.y *= fade;
	blade_tip = tip;
	color_seed = seed;
}

void fragment() {
	float tip = smoothstep(0.0, 1.0, blade_tip);
	vec3 varied_tip = tip_color * mix(0.88, 1.12, color_seed);
	ALBEDO = mix(root_color, varied_tip, tip * tip);
	ALBEDO *= mix(0.68, 1.0, tip);
	BACKLIGHT = varied_tip * 0.2;
	ROUGHNESS = 0.95;
}
