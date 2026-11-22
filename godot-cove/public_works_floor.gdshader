shader_type spatial;

uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_at;

void vertex() {
	world_at = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

void fragment() {
	vec3 slab = texture(concrete_scan, world_at * .72).rgb;
	float grime = texture(concrete_scan, world_at * .32).r;
	float scuff = texture(concrete_scan, world_at * vec2(.92, .17)).r;
	vec2 cell = world_at * .53;
	vec2 offset = fract(sin(floor(cell) * vec2(37.4, 71.5)) * 478.8) * .53 + .21;
	float density = fract(sin(dot(floor(cell), vec2(115.4, 71.5))) * 1274.8);
	float stain = (1.0 - smoothstep(.09, .31, length(fract(cell) - offset) + .12 * scuff))
		* step(.61, density);
	ALBEDO = slab * mix(vec3(.43, .418, .38), vec3(.65, .63, .57), grime) * (1.0 - stain * .69);
	ROUGHNESS = mix(.91, .63, stain);
}
