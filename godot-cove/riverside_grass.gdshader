shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform float fade_start = 74.0;
uniform float fade_end = 90.0;

varying float blade_tip;
varying float color_seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	vec3 delta = origin - CAMERA_POSITION_WORLD;
	float fade = 1.0 - smoothstep(fade_start * fade_start, fade_end * fade_end,
		dot(delta, delta));
	VERTEX.y *= fade;
	blade_tip = UV.y;
	color_seed = fract(sin(dot(origin.xz, vec2(.153, .417))) * 43758.5453);
	vec2 p = origin.xz;
	float gust = sin(dot(p, vec2(.083, .067)) - TIME * .92)
		* sin(dot(p, vec2(-.147, .103)) + TIME * .46);
	vec2 wind = vec2(.19, .11) * gust;
	VERTEX.xz += wind * UV.y * UV.y;
}

void fragment() {
	vec3 root = vec3(.30, .38, .17);
	vec3 tip = mix(vec3(.40, .49, .21), vec3(.50, .52, .26), color_seed);
	tip = mix(tip, vec3(.51, .44, .20), smoothstep(.83, .98, color_seed) * .26);
	ALBEDO = mix(root, tip, smoothstep(.02, .92, blade_tip));
	BACKLIGHT = tip * .23;
	ROUGHNESS = .97;
}
