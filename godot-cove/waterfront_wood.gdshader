shader_type spatial;

uniform sampler2D planks : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 finish : source_color = vec3(0.58, 0.50, 0.40);
uniform bool decking = true;

varying vec3 local_position;
varying vec3 local_normal;

void vertex() {
	local_position = VERTEX;
	local_normal = NORMAL;
}

void fragment() {
	vec2 grain = abs(local_normal.y) > .7
		? local_position.xz * vec2(.30, .85)
		: vec2(local_position.x + local_position.z, local_position.y) * vec2(.35, .85);
	if (!decking) {
		grain = vec2(local_position.y * .72, (local_position.x + local_position.z) * .19 + .13);
	}
	vec3 board = texture(planks, grain).rgb;
	float weathered = dot(board, vec3(.22, .65, .13));
	ALBEDO = finish * mix(1.0, .44 + weathered * 1.21, decking ? 1.0 : .55);
	ROUGHNESS = .91;
}
