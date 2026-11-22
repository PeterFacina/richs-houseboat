shader_type spatial;
render_mode cull_disabled;

uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D grit_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_uv;

void vertex() {
	world_uv = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 edge = min(UV, vec2(1.0) - UV);
	float coarse = texture(grit_scan, world_uv * .13).r;
	vec3 grit = texture(grit_scan, world_uv * 1.16).rgb;
	vec3 concrete = texture(concrete_scan, world_uv * .26).rgb;
	ALBEDO = mix(concrete, grit, .4) * mix(vec3(.89, .83, .70), vec3(1.22, 1.04, .79), coarse);
	ROUGHNESS = .93;
	ALPHA = smoothstep(.007, .076, min(edge.x, edge.y) + (coarse - .4) * .048);
}
