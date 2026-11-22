shader_type spatial;
render_mode cull_disabled;

void fragment() {
	vec2 weave = UV * vec2(94.0, 96.0);
	float blur = max(fwidth(weave.x), fwidth(weave.y));
	vec2 strands = abs(fract(weave + vec2(0.0, .48)) - .5);
	float fibres = 1.0 - smoothstep(.055, .24, min(strands.x, strands.y));
	fibres *= 1.0 - smoothstep(.32, .76, blur);
	float guide = 1.0 - smoothstep(.012, .032, abs(abs(UV.x) - .548));
	float joint = 1.0 - smoothstep(.015, .048, abs(fract(UV.y / 5.57 + .5) - .5) * 5.57);
	vec3 blue = mix(vec3(.105, .301, .432), vec3(.276, .549, .663), guide * .82);
	ALBEDO = blue * (.86 + .19 * fibres - .19 * joint);
	ROUGHNESS = .84;
}
