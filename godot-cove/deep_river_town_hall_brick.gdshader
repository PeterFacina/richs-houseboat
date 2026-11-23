shader_type spatial;

uniform vec4 brick : source_color = vec4(.59, .34, .24, 1.);
uniform vec4 mortar : source_color = vec4(.52, .49, .45, 1.);
varying vec2 courses;

void vertex() {
	vec3 at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xyz;
	vec2 along = normalize(MODEL_MATRIX[0].xz);
	courses = vec2(dot(at.xz, along), at.y);
}

float grain(vec2 tile) {
	return fract(sin(dot(mod(tile, 721.0), vec2(16.613, 65.037))) * 48631.77);
}

void fragment() {
	vec2 grid = courses / vec2(.212, .073);
	grid.x += mod(floor(grid.y), 2.) * .5;
	vec2 brick_uv = fract(grid);
	float across = min(brick_uv.x, 1. - brick_uv.x) * .212;
	float height = min(brick_uv.y, 1. - brick_uv.y) * .073;
	float joint = min(across, height);
	float pixel = fwidth(joint) * .75;
	float face = smoothstep(.003 - pixel, .005 + pixel, joint);
	float shade = mix(.78, 1.19, grain(floor(grid)));
	float texture_grain = mix(.95, 1.06, grain(floor(courses * 700.)));
	float bevel = mix(.82, 1., smoothstep(.003, .012, joint));
	ALBEDO = mix(mortar.rgb, brick.rgb * shade * texture_grain * bevel, face);
	ROUGHNESS = .86;
}
