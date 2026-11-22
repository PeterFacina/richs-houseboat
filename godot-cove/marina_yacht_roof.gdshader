shader_type spatial;
render_mode specular_disabled;

uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	float grit = texture(aggregate, UV * 1.75).g;
	float course = UV.y / .15;
	float lap = smoothstep(.84, .99, fract(course));
	lap *= 1.0 - smoothstep(.18, .72, fwidth(course));
	ALBEDO = COLOR.rgb * (mix(.83, 1.06, grit) - .085 * lap);
	ROUGHNESS = .94;
}
