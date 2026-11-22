float park_grass_mask(vec2 point) {
	vec2 offset = point - vec2(18183.65, 13100.0);
	float depth = dot(offset, vec2(.78716, -.61675));
	float across = abs(dot(offset, vec2(.61675, .78716)));
	return smoothstep(3.65, 5.6, depth) * (1.0 - smoothstep(28.0, 35.0, depth))
		* (1.0 - smoothstep(13.5, 20.0, across));
}

vec3 park_grass_color(sampler2D scan, vec2 point) {
	float grain = material_luminance(texture(scan, point / 1.85).rgb);
	float tint = .50 + .20 * sin(point.x * .074 + point.y * .031)
		+ .16 * sin(point.y * .116 - point.x * .026);
	return mix(vec3(.263, .350, .170), vec3(.324, .402, .205), tint) * (.88 + .34 * grain);
}
