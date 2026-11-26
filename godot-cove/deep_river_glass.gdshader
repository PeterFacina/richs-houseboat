shader_type spatial;
render_mode specular_disabled;

#include "res://river_sky.gdshaderinc"

uniform float evening = 0.0;

void fragment() {
	vec3 ray = normalize(mat3(INV_VIEW_MATRIX) * reflect(-VIEW, NORMAL));
	float fresnel = pow(1.0 - clamp(dot(NORMAL, VIEW), 0.0, 1.0), 3.0);
	vec2 frame = min(UV, 1.0 - UV);
	float inset = mix(.66, 1.0, smoothstep(0.0, .10, min(frame.x, frame.y)));
	vec3 reflected = timed_river_sky(ray, .38);
	vec3 below_horizon = mix(vec3(.25, .30, .20), vec3(.15, .19, .24), evening);
	reflected = mix(below_horizon, reflected, smoothstep(-.28, .15, ray.y));
	ALBEDO = COLOR.rgb * .36 * inset;
	EMISSION = reflected * mix(.27, .57, fresnel) * inset * mix(1.0, .69, evening);
	ROUGHNESS = .38;
}
