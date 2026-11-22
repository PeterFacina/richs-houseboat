shader_type spatial;

uniform sampler2D brick_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

void fragment() {
	vec3 swatch;
	if (COLOR.a < 0.5) {
		swatch = texture(brick_scan, UV * vec2(0.66, -0.64)).rgb;
	} else {
		swatch = texture(wood_scan, UV * vec2(0.50, -0.84)).rgb;
	}
	float grain = dot(swatch, vec3(.22, .64, .14));
	float base = mix(.71, 1.0, smoothstep(.04, .57, UV.y));
	ALBEDO = COLOR.rgb * base * (0.58 + grain * .89);
	ROUGHNESS = mix(.95, .83, smoothstep(.15, .68, grain));
}
