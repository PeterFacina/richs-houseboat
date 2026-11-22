uniform sampler2D asphalt_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D marina_paving : filter_linear, repeat_disable;
uniform vec4 marina_paving_bounds = vec4(0.0);

float material_luminance(vec3 rgb) {
	return dot(rgb, vec3(0.23, 0.62, 0.15));
}

vec3 asphalt_color(vec2 p) {
	float grain = material_luminance(texture(asphalt_scan, p / 2.6).rgb);
	float wear = material_luminance(texture(asphalt_scan, p / 30.0).rgb);
	return vec3(0.375, 0.384, 0.389) * (0.77 + grain * 0.76 + wear * 0.16);
}

vec3 concrete_color(vec2 p) {
	float grains = material_luminance(texture(concrete_scan, p / 2.4).rgb);
	return vec3(0.63, 0.609, 0.569) * (0.78 + grains * 0.51);
}

float marina_gravel_mask(vec2 p) {
	if (marina_paving_bounds.z <= 0.0) {
		return 0.0;
	}
	vec2 uv = (p - marina_paving_bounds.xy) / marina_paving_bounds.zw;
	if (any(lessThan(uv, vec2(0.0))) || any(greaterThan(uv, vec2(1.0)))) {
		return 0.0;
	}
	return texture(marina_paving, uv).r;
}

vec3 marina_gravel(vec2 p) {
	float patches = material_luminance(texture(concrete_scan, p / 8.7).rgb);
	float grit = material_luminance(texture(asphalt_scan, p / 1.3).rgb);
	return vec3(.58, .54, .454) * (.69 + .49 * patches + .33 * grit);
}
