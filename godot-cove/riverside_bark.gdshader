shader_type spatial;

varying vec3 trunk_point;

void vertex() {
	trunk_point = VERTEX;
}

void fragment() {
	float bands = sin(trunk_point.y * 17.0 + trunk_point.x * 9.0 + trunk_point.z * 6.0);
	float scar = smoothstep(.78, .96, bands) * (.35 + .65 * sin(trunk_point.y * 3.7 + trunk_point.z * 18.0));
	vec3 cream = mix(vec3(.65, .67, .61), vec3(.82, .81, .72), smoothstep(-.5, .8, trunk_point.y / 7.0));
	ALBEDO = mix(cream, vec3(.31, .34, .31), scar * .42);
	ROUGHNESS = .96;
}
