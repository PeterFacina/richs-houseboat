shader_type spatial;
render_mode cull_disabled;

#include "res://river_surfaces.gdshaderinc"

varying vec2 coordinates;
uniform vec4 brockhouse_road = vec4(0.0);

void vertex() {
	coordinates = VERTEX.xz;
}

void fragment() {
	float verge = smoothstep(0.84, 1.0, abs(UV.x));
	vec3 dust = concrete_color(coordinates) * vec3(0.85, 0.82, 0.72);
	ALBEDO = mix(asphalt_color(coordinates), dust, verge * 0.44);
	if (brockhouse_road.z > 0.0) {
		vec2 axis = brockhouse_road.zw - brockhouse_road.xy;
		float along = dot(coordinates - brockhouse_road.xy, axis) / dot(axis, axis);
		float shoulder_distance = length(coordinates - brockhouse_road.xy - axis * clamp(along, 0.0, 1.0));
		float local = 1.0 - smoothstep(3.0, 6.0, shoulder_distance);
		if (local > .001) {
			float grain = material_luminance(texture(asphalt_scan, coordinates / .51).rgb);
			float edge_dust = smoothstep(.60, 1.0, abs(UV.x)) * mix(.14, .53, grain);
			float seam = abs(UV.x + sin(coordinates.y * .45) * .018);
			float worn_join = (1.0 - smoothstep(.010, .038, seam)) * (1.0 - smoothstep(22.0, 85.0, length(VERTEX)));
			vec3 wear = mix(ALBEDO * (0.90 + grain * .17), dust, edge_dust);
			ALBEDO = mix(ALBEDO, wear * (1.0 - worn_join * .20), local);
		}
	}
	float apron = marina_gravel_mask(coordinates);
	if (apron > .97) {
		discard;
	}
	if (apron > .001) {
		ALBEDO = mix(ALBEDO, marina_gravel(coordinates), apron);
	}
	ROUGHNESS = 0.95;
	SPECULAR = 0.19;
}
