shader_type spatial;

#include "res://river_surfaces.gdshaderinc"

varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 stone = concrete_color(world_xz * 1.7);
	float grit = texture(asphalt_scan, world_xz / .72).r;
	ALBEDO = stone * vec3(.73, .69, .59) * (.82 + grit * .32);
	ALPHA = (1.0 - smoothstep(.16 + grit * .18, .96, UV2.x)) * COLOR.b;
	ROUGHNESS = 1.0;
	SPECULAR = .13;
}
