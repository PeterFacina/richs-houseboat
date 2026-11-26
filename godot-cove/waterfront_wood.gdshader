shader_type spatial;

uniform sampler2D planks : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec3 finish : source_color = vec3(0.58, 0.50, 0.40);
uniform bool decking = true;
uniform bool riverside_profile = false;

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
	if (riverside_profile) {
		float division = 1.0 - smoothstep(.015, .055, min(fract(grain.y), 1.0 - fract(grain.y)));
		float grain_tone = .92 + .14 * smoothstep(.18, .79, weathered);
		vec3 warm = mix(vec3(.60, .43, .30), vec3(.74, .56, .37), weathered) * grain_tone;
		ALBEDO = mix(ALBEDO, warm * (1.0 - division * .18), .76);
	}
	ROUGHNESS = .91;
}
