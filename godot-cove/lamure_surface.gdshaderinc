uniform sampler2D lamure_surface : filter_linear, repeat_disable;
uniform sampler2D lamure_sand : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform vec4 lamure_paint_bounds = vec4(0.0);

vec4 lamure_coverage(vec2 point) {
	if (lamure_paint_bounds.z <= 0.0) {
		return vec4(0.0);
	}
	vec2 uv = (point - lamure_paint_bounds.xy) / lamure_paint_bounds.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return vec4(0.0);
	}
	return texture(lamure_surface, uv);
}

vec3 beach_sand(vec2 point, float damp) {
	float grains = texture(lamure_sand, point / 1.8).g;
	float weather = texture(lamure_sand, point / 11.3).g;
	vec3 dry = vec3(.675, .621, .521) * (.62 + .75 * grains + .27 * weather);
	vec3 wet = dry * vec3(.70, .68, .61) + vec3(.011, .016, .012);
	return mix(dry, wet, damp);
}
