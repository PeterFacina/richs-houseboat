shader_type spatial;
render_mode unshaded;

#include "res://river_sky.gdshaderinc"

uniform float evening = 0.0;
uniform float tone = 1.0;
uniform float reflection_strength = 1.0;

void fragment() {
	vec3 ray = normalize(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL));
	float azimuth = atan(ray.z, ray.x) / TAU;
	float skyline = mix(.015, .19, sky_grain(vec2(azimuth, .353) * vec2(64., 2.)));
	skyline += (sky_grain(vec2(azimuth, .162) * vec2(283., 6.)) - .5) * .092;
	float air = smoothstep(skyline - .008, skyline + .015, ray.y);
	vec3 trees = mix(vec3(.035, .060, .058), vec3(.092, .133, .117),
		sky_grain(vec2(azimuth * 240., ray.y * 80.)));
	vec3 reflected = mix(trees * (1. - .42 * evening), river_sky(ray, .75, evening), air);
	float reflectance = mix(.48, .81, pow(1. - max(0., dot(NORMAL, VIEW)), 3.));
	ALBEDO = (vec3(.038, .070, .103) + reflected * (reflectance * reflection_strength)) * tone;
}
