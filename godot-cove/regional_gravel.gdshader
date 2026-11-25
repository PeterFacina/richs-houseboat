shader_type spatial;
render_mode cull_disabled, depth_prepass_alpha;

#include "res://road_asphalt.gdshaderinc"
#include "res://road_gravel.gdshaderinc"

uniform float half_width = 3.2;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	float verge = smoothstep(half_width - .49, half_width - .12, abs(UV.x));
	float edge = half_width - .30 - road_noise(world_xz * 1.65) * .22;
	ALBEDO = mix(road_gravel(world_xz, UV.x, half_width), road_verge(world_xz), verge);
	NORMAL = gravel_relief(world_xz, NORMAL, VIEW_MATRIX[0].xyz, length(VERTEX));
	ROUGHNESS = .99;
	SPECULAR = .15;
	ALPHA = 1.0 - smoothstep(edge, half_width - .025, abs(UV.x));
}
