shader_type spatial;
render_mode unshaded, shadows_disabled, cull_disabled;

void fragment() {
	float distance_to_eye = length(VERTEX);
	float center_fade = 1.0 - abs(UV.y * 2.0 - 1.0);
	ALBEDO = vec3(.68, .79, .86);
	ALPHA = .31 * center_fade * smoothstep(.55, 2.1, distance_to_eye);
}
