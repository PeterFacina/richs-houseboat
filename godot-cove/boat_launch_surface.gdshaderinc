vec3 launch_surface(sampler2D concrete, vec2 metres, float wetness) {
	float grain = texture(concrete, metres / 3.9).g;
	float weather = texture(concrete, metres / 9.8).r;
	float cuts = (metres.y + abs(metres.x) * .31) * 6.7;
	float footprint = fwidth(cuts);
	float softness = max(.045, footprint * .46);
	float grooves = 1.0 - smoothstep(.115 - softness, .115 + softness, abs(fract(cuts) - .5));
	grooves *= 1.0 - smoothstep(.09, .29, footprint);
	float seam = 1.0 - smoothstep(.014, .061, abs(metres.x));
	float finish = (.71 + .45 * grain + .18 * weather) * (1.0 - grooves * .21 - seam * .15);
	return mix(vec3(.615, .584, .524), vec3(.405, .435, .394), wetness) * finish;
}
