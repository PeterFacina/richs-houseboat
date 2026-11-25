shader_type spatial;

#include "res://river_surfaces.gdshaderinc"
#include "res://road_asphalt.gdshaderinc"
#include "res://road_gravel.gdshaderinc"

uniform sampler2D town_paving : filter_linear, repeat_disable;
uniform vec4 paving_bounds;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 verge = road_verge(world_xz);
	float edge = road_noise(world_xz * 2.1) * .23 + road_noise(world_xz * .58) * .36;
	vec2 town_uv = (world_xz - paving_bounds.xy) / paving_bounds.zw;
	float soil = 1.0;
	if (all(greaterThanEqual(town_uv, vec2(0.0))) && all(lessThan(town_uv, vec2(1.0)))) {
		vec2 paving = texture(town_paving, town_uv).rg;
		soil = 1.0 - smoothstep(.08, .65, max(paving.r, paving.g));
	}
	ALBEDO = verge;
	ALPHA = (1.0 - smoothstep(-.12, .62 + edge * .52, UV2.x)) * COLOR.b * .82 * soil;
	ROUGHNESS = 1.0;
	SPECULAR = .13;
}
