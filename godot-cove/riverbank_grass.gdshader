shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grass_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
#include "res://river_surfaces.gdshaderinc"
#include "res://riverbank_grass.gdshaderinc"
varying vec2 world_at;
void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}
void fragment() {
	ALBEDO = park_grass_color(grass_scan, world_at);
	NORMAL = normalize((VIEW_MATRIX * vec4(0.0, 1.0, 0.0, 0.0)).xyz);
	ROUGHNESS = .92;
}
