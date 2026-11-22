shader_type sky;
render_mode use_debanding;

#include "res://river_sky.gdshaderinc"

uniform float evening = 0.0;

void sky() {
	COLOR = river_sky(EYEDIR, 1.0, evening);
	if (LIGHT0_ENABLED) {
		float warmth = pow(max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0), 32.0);
		float disc = smoothstep(0.99987, 0.99997, dot(EYEDIR, LIGHT0_DIRECTION));
		float light = has_day_sky ? smoothstep(0.08, 0.70, evening) : 1.0;
		COLOR += (mix(vec3(0.12, 0.093, 0.065), vec3(.43, .19, .07), evening) * warmth + vec3(0.7, 0.53, 0.33) * disc) * light;
	}
}
