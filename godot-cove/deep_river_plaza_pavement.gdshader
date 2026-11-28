shader_type spatial;
#include "res://weather_pavement.gdshaderinc"

#include "res://river_surfaces.gdshaderinc"

uniform vec4 base_color : source_color = vec4(.30, .29, .27, 1.0);
void fragment() {
	vec3 scan = texture(asphalt_scan, UV * .94).rgb;
	float grain = material_luminance(scan);
	float weathering = texture(asphalt_scan, UV * .17).r;
	float seam = 1.0 - smoothstep(.01, .047, abs(fract(UV.x / 1.23) - .5));
	ALBEDO = base_color.rgb * (.83 + grain * .48 + weathering * .16) * (1.0 - seam * .13);
	ALBEDO *= 1.0 - river_weather_wet * .22;
	ROUGHNESS = mix(.98, .50, river_weather_wet);
	SPECULAR = .19 + river_weather_wet * .25 * river_weather_reflection;
}
