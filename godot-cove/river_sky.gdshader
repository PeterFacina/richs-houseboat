shader_type sky;
render_mode use_debanding;

#include "res://river_sky.gdshaderinc"

uniform bool use_day_cycle = false;

void sky() {
	if (use_day_cycle) {
		COLOR = timed_river_sky(EYEDIR, 1.0);
	} else {
		COLOR = river_sky(EYEDIR, 1.0, 0.0);
		if (LIGHT0_ENABLED) {
			float towards_light = max(dot(EYEDIR, LIGHT0_DIRECTION), 0.0);
			float warmth = pow(towards_light, 32.0);
			float disc = smoothstep(0.99987, 0.99997, towards_light);
			COLOR += vec3(0.12, 0.093, 0.065) * warmth + vec3(0.7, 0.53, 0.33) * disc;
		}
	}
}
