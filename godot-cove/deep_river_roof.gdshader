shader_type spatial;
render_mode specular_disabled;

uniform sampler2D roof_atlas : source_color, filter_linear_mipmap_anisotropic, repeat_disable;
uniform sampler2D aggregate : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec2 roof_metres;

void vertex() {
	roof_metres = VERTEX.xz;
}

void fragment() {
	float grain = texture(aggregate, roof_metres / 2.0).g;
	vec3 atlas = texture(roof_atlas, UV).rgb;
	ALBEDO = atlas * (0.64 + grain * 1.16);
	if (COLOR.r > .5) {
		float tint = COLOR.g;
		vec3 slate = mix(vec3(.100, .125, .143), vec3(.239, .194, .149), tint);
		float granules = mix(.70, 1.20, grain);
		if (COLOR.b > .75) {
			float row = floor(UV2.y / .177);
			float phase = fract(UV2.y / .177);
			float line = min(phase, 1.0 - phase) * .177;
			float aa = max(.003, fwidth(UV2.y) * .75);
			float course = 1.0 - smoothstep(.006 - aa, .009 + aa, line);
			float course_fade = 1.0 - smoothstep(.021, .105, aa);
			float tab = fract(UV2.x / .302 + mod(row, 2.0) * .50);
			float seam = (1.0 - smoothstep(.012, .033 + fwidth(UV2.x), min(tab, 1.0 - tab))) * (1.0 - phase);
			float weather = .94 + .12 * fract(sin(row * 17.91 + floor(UV2.x / .302 + mod(row, 2.0) * .50) * 10.61) * 941.91);
			ALBEDO = mix(slate * granules * mix(1.0, weather, course_fade), atlas, .11) *
				(1.0 - (course * .22 + seam * .12) * course_fade);
		} else {
			float spacing = mix(1.36, .56, step(.25, COLOR.b));
			float run = fract(UV2.x / spacing);
			float edge = min(run, 1.0 - run) * spacing;
			float aa = max(.004, fwidth(UV2.x));
			float seam = (1.0 - smoothstep(.012, .029 + aa, edge)) * (1.0 - smoothstep(.03, .23, aa));
			vec3 membrane = mix(vec3(.16, .163, .151), vec3(.23, .238, .232), tint);
			ALBEDO = mix(membrane * mix(.82, 1.14, grain), atlas, .14) * (1.0 - seam * .22);
		}
	}
	ROUGHNESS = 0.91;
}
