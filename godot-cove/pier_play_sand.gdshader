shader_type spatial;
render_mode cull_disabled;

uniform sampler2D sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 coordinates;

void vertex() {
	coordinates = VERTEX.xz;
}

void fragment() {
	float border = length(UV * 2.0 - 1.0);
	float irregular_edge = sin(coordinates.x * 3.1) * cos(coordinates.y * 3.7);
	if (border + irregular_edge * .042 > 1.0) {
		discard;
	}
	float grit = texture(sand, coordinates / 1.45).g;
	ALBEDO = vec3(.66, .59, .45) * (.73 + grit * .43);
	ROUGHNESS = .96;
}
