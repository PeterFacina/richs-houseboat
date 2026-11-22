shader_type spatial;

uniform sampler2D grit : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform float base_y;
varying vec3 world_at;
varying vec3 box_normal;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	box_normal = NORMAL;
}

void fragment() {
	vec2 plane = vec2(dot(world_at.xz, vec2(.734, .679)), world_at.y - base_y);
	if (abs(box_normal.x) > .5) {
		plane.x = dot(world_at.xz, vec2(-.679, .734));
	}
	vec2 brick = plane / vec2(.405, .195);
	brick.x += mod(floor(brick.y), 2.0) * .5;
	vec2 face = fract(brick);
	float edge = min(min(face.x, 1.0 - face.x) * .405, min(face.y, 1.0 - face.y) * .195);
	float seam = smoothstep(.002, .011 + fwidth(edge), edge);
	float raw = texture(grit, plane * .81).r;
	float mottled = texture(grit, plane * .21).r;
	float dirty = (1.0 - smoothstep(.15, 1.65, plane.y)) * smoothstep(.46, .85, mottled + raw * .34);
	vec3 whitewash = mix(vec3(.79, .79, .755), vec3(.94, .93, .87), raw);
	ALBEDO = mix(vec3(.54, .55, .525), whitewash, seam) * mix(1.0, .63, dirty);
	ROUGHNESS = .92;
}
