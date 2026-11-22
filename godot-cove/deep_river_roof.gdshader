shader_type spatial;
render_mode specular_disabled;

uniform sampler2D roof_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec2 roof_metres;

void vertex() {
	roof_metres = VERTEX.xz;
}

void fragment() {
	float grain = texture(aggregate, roof_metres / 2.0).g;
	ALBEDO = texture(roof_atlas, UV).rgb * (0.64 + grain * 1.16);
	ROUGHNESS = 0.91;
}
