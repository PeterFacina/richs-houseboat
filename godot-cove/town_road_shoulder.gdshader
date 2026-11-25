shader_type spatial;

#include "res://river_surfaces.gdshaderinc"
#include "res://road_asphalt.gdshaderinc"
#include "res://road_gravel.gdshaderinc"

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 gravel = gravel_color(world_xz);
	float grit = material_luminance(gravel);
	ALBEDO = gravel * vec3(.99, .95, .88);
	ALPHA = (1.0 - smoothstep(.16 + grit * .18, .96, UV2.x)) * COLOR.b;
	ROUGHNESS = 1.0;
	SPECULAR = .13;
}
