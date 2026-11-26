shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying float blade_tip;
varying float color_seed;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	blade_tip = UV.y;
	color_seed = fract(sin(dot(origin.xz, vec2(.153, .417))) * 43758.5453);
	vec2 p = origin.xz + VERTEX.xz;
	float gust = sin(dot(p, vec2(.083, .067)) - TIME * .92)
		* sin(dot(p, vec2(-.147, .103)) + TIME * .46);
	vec2 wind = vec2(.19, .11) * gust + vec2(.028, -.023) * sin(TIME * 1.6 + p.x * .22);
	VERTEX.xz += wind * UV.y * UV.y;
}

void fragment() {
	vec3 root = vec3(.18, .25, .115);
	vec3 tip = mix(vec3(.37, .47, .21), vec3(.47, .51, .25), color_seed);
	ALBEDO = mix(root, tip, smoothstep(.02, .92, blade_tip));
	ROUGHNESS = .97;
}
