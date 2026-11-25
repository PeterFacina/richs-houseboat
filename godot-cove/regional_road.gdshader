shader_type spatial;
render_mode cull_disabled;

#include "res://river_surfaces.gdshaderinc"
#include "res://road_asphalt.gdshaderinc"
#include "res://road_gravel.gdshaderinc"

uniform bool gravel = true;
uniform float half_width = 3.2;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float eye = length(VERTEX);
	if (gravel) {
		ALBEDO = road_gravel(world_xz, UV.x, half_width);
		NORMAL = gravel_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, eye);
		ROUGHNESS = .99;
	} else {
		ALBEDO = weathered_asphalt(world_xz, eye, .78);
		NORMAL = road_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, eye);
		ROUGHNESS = .96;
	}
	SPECULAR = .15;
}
