shader_type spatial;
render_mode cull_disabled, diffuse_burley;

varying float leaf_color;

void vertex() {
	leaf_color = fract(UV.x * 7.0 + sin(dot(MODEL_MATRIX[3].xz, vec2(.41, .27))) * 3.2);
}

void fragment() {
	vec3 amber = vec3(.58, .32, .105);
	vec3 copper = vec3(.40, .19, .10);
	vec3 birch = vec3(.63, .49, .19);
	ALBEDO = mix(mix(amber, copper, smoothstep(.35, .8, leaf_color)), birch,
		smoothstep(.75, 1.0, leaf_color));
	ROUGHNESS = .98;
}
