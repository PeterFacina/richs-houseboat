shader_type spatial;
render_mode cull_disabled, diffuse_burley;

uniform sampler2D foliage : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform vec4 tint : source_color = vec4(1.0);
uniform vec4 palette : source_color = vec4(1.0);
uniform float recolor = 0.0;
varying float crown_height;

void vertex() {
	vec3 origin = MODEL_MATRIX[3].xyz;
	crown_height = VERTEX.y;
	vec3 world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	float gust = sin(dot(world.xz, vec2(.064, .049)) - TIME * .82)
		* sin(dot(world.xz, vec2(-.096, .073)) + TIME * .43);
	VERTEX.xz += vec2(.041, .027) * gust * smoothstep(1.5, 7.0, VERTEX.y);
}

void fragment() {
	vec4 leaf = texture(foliage, UV) * tint;
	ALPHA = leaf.a;
	ALPHA_SCISSOR_THRESHOLD = .27;
	float leaf_detail = dot(leaf.rgb, vec3(.24, .64, .12));
	vec3 dyed = palette.rgb * mix(.55, 1.10, leaf_detail);
	ALBEDO = mix(leaf.rgb, dyed, recolor * .78)
		* mix(.82, 1.13, clamp(crown_height / 7.0, 0.0, 1.0));
	ROUGHNESS = .93;
}
