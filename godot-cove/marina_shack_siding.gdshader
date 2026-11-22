shader_type spatial;

varying vec3 local;

void vertex() {
	local = VERTEX;
}

void fragment() {
	float board = fract(local.y * 5.7);
	float joint = 1.0 - smoothstep(.035, .123, board);
	float run = sin(dot(local, vec3(6.4, 43.0, 8.9))) * .017;
	float weather = mix(.83, 1.0, smoothstep(-1.23, .39, local.y));
	ALBEDO = vec3(.79, .817, .80) * weather * (1.0 - .14 * joint + run);
	ROUGHNESS = .9;
}
