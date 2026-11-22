shader_type spatial;
render_mode unshaded, cull_disabled;

#include "res://river_sky.gdshaderinc"

uniform vec2 propeller = vec2(0.0, 4.0);
uniform vec2 wash_direction = vec2(0.0, 1.0);
varying vec3 world;

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 p = world.xz;
	float t = TIME;
	float a = dot(p, vec2(2.37, 3.48)) - t * 1.52;
	float b = dot(p, vec2(-5.4, 1.9)) - t * 1.93;
	float c = dot(p, vec2(7.12, 6.33)) + t * 1.88;
	vec3 normal = normalize(vec3(.026 * cos(a) - .031 * cos(b) + .011 * cos(c), 1.0,
		.039 * cos(a) + .012 * cos(b) + .011 * cos(c)));
	vec3 view = normalize(CAMERA_POSITION_WORLD - world);
	vec3 sky = river_sky(reflect(-view, normal), .33, 0.0);
	float fresnel = pow(1.0 - max(0.0, dot(normal, view)), 3.0);
	float edge = -1.30 + .28 * sin(p.x * .49) + 1.17 * exp(-pow((p.x + 5.5) / 3.4, 2.0)) - .21 * max(p.x - 8.0, 0.0);
	float deep = smoothstep(0.0, 9.0, p.y - edge);
	vec3 river = mix(vec3(.28, .44, .39), vec3(.12, .32, .40), deep);
	vec3 water_color = mix(river, sky * vec3(.74, .84, .86), .13 + .65 * fresnel);
	float glint = pow(max(0.0, dot(normal, normalize(view + normalize(vec3(-.48, .65, .57))))), 140.0);
	water_color += glint * vec3(.26, .20, .11);

	vec2 wake = p - propeller;
	float aft = dot(wake, wash_direction);
	float across = dot(wake, vec2(wash_direction.y, -wash_direction.x));
	vec2 drift = vec2(across * 15.0 + sin(t * 3.5 + aft * 8.0) * .35, (aft - t * .84) * 12.0);
	float turbulence = sky_grain(drift) * .62 + sky_grain(drift * 2.4 + 4.1) * .38;
	float shape = smoothstep(-.08, .21, aft) * (1.0 - smoothstep(.73, 1.75, aft))
		* (1.0 - smoothstep(.12, .32 + aft * .16, abs(across)));
	float bubbles = smoothstep(.34, .69, turbulence) * shape;
	float foam = clamp(bubbles * .97 + shape * .23, 0.0, .92);
	ALBEDO = mix(water_color, vec3(.94, .97, .91), foam);
	float clear_prop = 1.0 - smoothstep(.16, .86, length(wake));
	ALPHA = clamp(mix(.60, .97, max(deep, fresnel)) - clear_prop * .24 + foam * .22, 0.0, 1.0);
}
