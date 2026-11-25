shader_type spatial;
render_mode cull_disabled;

#include "res://road_asphalt.gdshaderinc"

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float eye = length(VERTEX);
	ALBEDO = weathered_asphalt(world_xz, eye, .51);
	NORMAL = road_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, eye);
	ROUGHNESS = .96;
	SPECULAR = .15;
}
