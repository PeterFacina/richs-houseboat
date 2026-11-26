shader_type spatial;
#include "res://weather_pavement.gdshaderinc"
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
	ALBEDO *= 1.0 - river_weather_wet * .23;
	ROUGHNESS = mix(.96, .52, river_weather_wet);
	SPECULAR = .15 + river_weather_wet * .27 * river_weather_reflection;
}
