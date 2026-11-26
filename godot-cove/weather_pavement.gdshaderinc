global uniform float river_weather_wet;
global uniform float river_weather_reflection;

float rain_pool(vec2 at, float wetness) {
	// Static patches follow streets through camera and chunk boundaries.
	float basin = sin(at.x * .42 + sin(at.y * .85) * .45) * cos(at.y * .64)
		+ .27 * sin(at.x * 2.13 + at.y * 1.61);
	return smoothstep(.69, 1.16, basin) * smoothstep(.35, .95, wetness);
}
