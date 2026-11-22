shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

void fragment() {
	vec2 weave = vec2(UV.x + UV.y, UV.x - UV.y) / 0.115;
	vec2 distance_to_wire = abs(fract(weave + 0.5) - 0.5);
	float wire = min(distance_to_wire.x, distance_to_wire.y);
	ALBEDO = vec3(0.42, 0.45, 0.43);
	METALLIC = 0.61;
	ROUGHNESS = 0.56;
	ALPHA = 1.0;
	ALPHA_SCISSOR_THRESHOLD = 0.5;
	if (wire > 0.048) {
		ALPHA = 0.0;
	}
}
