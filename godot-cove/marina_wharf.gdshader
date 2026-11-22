shader_type spatial;

#include "res://boat_launch_surface.gdshaderinc"

uniform sampler2D concrete : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform bool launch_ramp = false;
varying vec3 coordinates;
varying vec3 outward;

void vertex() {
	coordinates = VERTEX;
	outward = NORMAL;
}

void fragment() {
	bool paving = outward.y > .37;
	vec2 p = paving ? coordinates.xz
		: vec2(coordinates.x + coordinates.z, coordinates.y);
	float sand = texture(concrete, p / 3.2).g;
	float stains = texture(concrete, p / 11.5).r;
	float seam = 1.0 - smoothstep(.008, .035, abs(fract(p.x / 4.1 + .33) - .5));
	vec3 dry = vec3(.54, .515, .470) * (.62 + .67 * sand + .25 * stains);
	if (launch_ramp) {
		ALBEDO = launch_surface(concrete, UV, 1.0 - smoothstep(-.08, .24, coordinates.y));
	} else if (paving) {
		ALBEDO = dry * (1.0 - seam * .13);
	} else {
		float splash = smoothstep(.05, .81, coordinates.y);
		vec3 damp = vec3(.22, .25, .24) * (.78 + sand * .49);
		ALBEDO = mix(damp, dry * .86, splash);
	}
	ROUGHNESS = .93;
}
