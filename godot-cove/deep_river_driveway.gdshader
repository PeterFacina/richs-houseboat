shader_type spatial;
render_mode specular_disabled;

uniform sampler2D asphalt_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 metres;

void vertex() {
	metres = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float luminance(vec3 sample_color) {
	return dot(sample_color, vec3(.21, .69, .10));
}

void fragment() {
	float fine = luminance(texture(asphalt_scan, metres * .44).rgb);
	float aggregate = luminance(texture(concrete_scan, metres * .67).rgb);
	float concrete = step(.48, COLOR.r);
	float grain = mix(fine, aggregate, concrete);
	float verge = smoothstep(.76, 1., abs(UV.x));
	float worn = smoothstep(.35, .61, abs(UV.x)) - smoothstep(.60, .78, abs(UV.x));
	float mottling = luminance(texture(concrete_scan, metres * .083).rgb);
	float seam_dist = abs(fract(UV.y / 3.05 + .5) - .5) * 3.05;
	float seam = (1. - smoothstep(.006, .019 + fwidth(UV.y), seam_dist)) * concrete;
	ALBEDO = COLOR.rgb * mix(mix(.41, .71, grain), mix(.70, .88, grain), concrete) *
		(1. + mottling * .17 - worn * .065 - seam * .12);
	ALBEDO = mix(ALBEDO, vec3(.24, .21, .16) * (.68 + aggregate * .27), verge * .21);
	ROUGHNESS = .93;
}
