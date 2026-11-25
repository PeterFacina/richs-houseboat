// The source road scan covers two metres square.
uniform sampler2D gravel_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D gravel_normal : hint_normal, filter_linear_mipmap_anisotropic, repeat_enable;

vec3 gravel_color(vec2 world) {
	return texture(gravel_scan, world / 2.0).rgb;
}

vec3 road_verge(vec2 world) {
	vec3 gravel = gravel_color(world);
	float grit = dot(gravel, vec3(.23, .62, .15));
	return mix(gravel * vec3(.82, .80, .73), vec3(grit) * 1.19, .32);
}

vec3 road_gravel(vec2 world, float lateral, float half_width) {
	float wear = road_noise(world * .51);
	float track = 1.0 - smoothstep(.22, .70, abs(abs(lateral) - half_width * .32)
		+ (wear - .5) * .28);
	float shoulder = smoothstep(half_width * .59, half_width, abs(lateral));
	vec3 surface = gravel_color(world);
	vec3 compacted = mix(surface, vec3(.25, .21, .17), .16);
	return mix(surface * (1.02 + shoulder * .05), compacted, track)
		* (.89 + .22 * wear);
}

vec3 gravel_relief(vec2 world, vec3 normal, vec3 world_x, float eye) {
	float detail = 1.0 - smoothstep(10.0, 35.0, eye);
	if (detail < .001) {
		return normal;
	}
	vec2 grit = texture(gravel_normal, world / 2.0).rg * 2.0 - 1.0;
	return road_grain_normal(grit, normal, world_x, .29 * detail);
}
