shader_type spatial;
render_mode cull_disabled;
uniform sampler2D grit : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec2 parking_origin;
uniform vec2 parking_axis;
uniform vec4 parking_extent;
uniform float parking_depth;
varying vec2 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec2 bank = world_at - parking_origin;
	float station = dot(bank, -parking_axis);
	float across = dot(bank, vec2(parking_axis.y, -parking_axis.x));
	if (station > parking_extent.x && station < parking_extent.w && across > 0.0) {
		float widening = min((station - parking_extent.x) / (parking_extent.y - parking_extent.x),
			(parking_extent.w - station) / (parking_extent.w - parking_extent.z));
		if (across < mix(3.4, parking_depth, clamp(widening, 0.0, 1.0)) - .025) {
			discard;
		}
	}
	vec3 small_stone = texture(grit, world_at * 1.26).rgb;
	vec3 limestone = texture(concrete_scan, world_at * .53).rgb;
	vec3 gravel = mix(limestone, small_stone, .48) * vec3(.88, .86, .77);
	vec2 brick = vec2(dot(world_at, vec2(.61675, .78716)),
		dot(world_at, vec2(.78716, -.61675))) / vec2(.23, .115);
	float footprint = max(fwidth(brick.x), fwidth(brick.y));
	brick.x += mod(floor(brick.y), 2.0) * .5;
	vec2 cell = floor(brick);
	vec2 edge_to_joint = min(fract(brick), 1.0 - fract(brick)) * vec2(.23, .115);
	float joint_distance = min(edge_to_joint.x, edge_to_joint.y);
	float joints = (1.0 - smoothstep(.003, .006 + footprint * .04, joint_distance))
		* (1.0 - smoothstep(.15, .62, footprint));
	float tone = fract(sin(dot(mod(cell, 127.0), vec2(17.43, 35.71))) * 8429.14);
	tone = mix(tone, .5, smoothstep(.24, .72, footprint));
	vec3 paver = mix(vec3(.46, .385, .30), vec3(.61, .527, .415), tone);
	paver *= mix(.84, 1.16, limestone.r);
	paver = mix(paver, vec3(.275, .233, .179), joints * .79);
	ALBEDO = mix(gravel, paver, COLOR.r);
	ROUGHNESS = .92;
	float edge = abs(UV.x * 2.0 - 1.0);
	ALPHA = 1.0 - smoothstep(mix(.76, .97, COLOR.r), 1.0, edge + small_stone.r * .08 * (1.0 - COLOR.r));
}
