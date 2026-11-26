shader_type spatial;
global uniform float river_weather_wind;
render_mode cull_disabled;

varying float blade_height;
varying float patch_color;

void vertex() {
	vec3 base = MODEL_MATRIX[3].xyz;
	blade_height = VERTEX.y;
	patch_color = sin(base.x * 0.17 + base.z * 0.31);
	float bend = VERTEX.y * VERTEX.y;
	VERTEX.x += sin(TIME * 1.4 + base.x * 0.42 + base.z * 0.37) * bend * (0.21 + river_weather_wind * .23);
	VERTEX.z += sin(TIME * 1.9 + base.z * 0.54) * bend * (0.15 + river_weather_wind * .18);
}

void fragment() {
	ALBEDO = mix(vec3(0.16, 0.24, 0.088), vec3(0.40, 0.46, 0.20), smoothstep(0.09, 0.85, blade_height));
	ALBEDO *= 0.92 + patch_color * 0.13;
	ROUGHNESS = 0.93;
}
