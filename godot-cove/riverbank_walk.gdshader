shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grit : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 small_stone = texture(grit, world_at * 1.26).rgb;
	vec3 limestone = texture(concrete_scan, world_at * .53).rgb;
	ALBEDO = mix(limestone, small_stone, .48) * vec3(.88, .86, .77);
	ROUGHNESS = .92;
	float edge = abs(UV.x * 2.0 - 1.0);
	ALPHA = 1.0 - smoothstep(.76, 1.0, edge + small_stone.r * .08);
}
