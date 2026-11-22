shader_type spatial;
render_mode cull_disabled, shadows_disabled, specular_disabled, blend_mix;

uniform vec3 wire : source_color = vec3(.29, .34, .31);
uniform float pitch = .078;
uniform float strand = .0028;
uniform bool diamond = true;

float thread(float coordinate) {
	float cell = coordinate / pitch;
	float footprint = fwidth(cell);
	float aa = clamp(footprint * .5, .006, .35);
	float d = fract(cell + .5) - .5;
	float width = strand / pitch;
	float coverage = smoothstep(-aa, aa, d + width) - smoothstep(-aa, aa, d - width);
	return mix(coverage, width * 2.0, smoothstep(.35, 1.0, footprint));
}

void fragment() {
	vec2 lattice = diamond ? vec2(UV.x + UV.y, UV.x - UV.y) * .7071068 : UV;
	float a = thread(lattice.x);
	float b = thread(lattice.y);
	ALBEDO = wire;
	ALPHA = a + b - a * b;
	ROUGHNESS = .86;
}
