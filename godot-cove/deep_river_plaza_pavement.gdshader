shader_type spatial;

#include "res://river_surfaces.gdshaderinc"

uniform vec4 base_color : source_color = vec4(.30, .29, .27, 1.0);
uniform bool road_paint = false;
uniform bool roof = false;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 scan = texture(asphalt_scan, UV * .94).rgb;
	float grain = material_luminance(scan);
	float weathering = texture(asphalt_scan, UV * .17).r;
	vec3 asphalt = asphalt_color(world_xz);
	if (road_paint) {
		float worn = smoothstep(.21, .53, grain + weathering * .28);
		ALBEDO = mix(asphalt, vec3(.87, .85, .80), .41 + worn * .54);
	} else if (roof) {
		float seam = 1.0 - smoothstep(.01, .047, abs(fract(UV.x / 1.23) - .5));
		ALBEDO = base_color.rgb * (.83 + grain * .48 + weathering * .16) * (1.0 - seam * .13);
	} else {
		ALBEDO = asphalt;
	}
	ROUGHNESS = .98;
	SPECULAR = .19;
}
