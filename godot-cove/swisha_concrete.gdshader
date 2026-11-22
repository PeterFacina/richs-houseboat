shader_type spatial;
render_mode specular_disabled;

uniform vec3 cement : source_color = vec3(0.55, 0.56, 0.53);
uniform float stain = 1.0;
varying vec3 world;

float grit(vec2 p) {
	vec2 i = floor(p);
	vec2 f = smoothstep(vec2(0.0), vec2(1.0), fract(p));
	vec4 h = fract(sin(dot(i, vec2(79.7, 132.3)) + vec4(0.0, 79.7, 132.3, 212.0)) * 23315.71);
	return mix(mix(h.x, h.y, f.x), mix(h.z, h.w, f.x), f.y);
}

void vertex() {
	world = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
}

void fragment() {
	vec2 stone = vec2(dot(world.xz, vec2(0.43, -0.88)), world.y);
	float specks = grit(stone * vec2(44.0, 37.0) + world.z * 3.3);
	float patch = grit(stone * vec2(7.4, 5.1) + 3.5);
	float runoff = grit(stone * vec2(18.4, 1.22)) * grit(stone * vec2(3.1, 0.72) + 17.6);
	float joint = smoothstep(0.463, 0.498, abs(fract(world.y * 1.16 + 0.1) - 0.5));
	joint *= 1.0 - smoothstep(0.07, 0.38, fwidth(world.y) * 1.16);
	float damp = (1.0 - smoothstep(0.02, 0.62, world.y)) * (0.55 + 0.45 * patch);
	vec3 dust = mix(cement, vec3(0.24, 0.245, 0.20), runoff * 0.30 * stain);
	ALBEDO = dust * (0.83 + specks * 0.13 + patch * 0.17 - joint * 0.17 - damp * 0.25 * stain);
	ROUGHNESS = 0.93;
}
