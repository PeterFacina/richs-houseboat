shader_type spatial;

uniform sampler2D brick_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D wood_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying float wall_height;

void vertex() {
	wall_height = (MODEL_MATRIX * vec4(VERTEX, 1.0)).y;
}

void fragment() {
	if (COLOR.a > 0.25 && COLOR.a < 0.4) {
		float rib = smoothstep(0.04, 0.38, fract(UV.x / 0.105));
		vec3 skirt = COLOR.rgb * vec3(0.59, 0.54, 0.49);
		ALBEDO = mix(skirt, COLOR.rgb, step(0.82, UV.y)) * mix(0.70, 1.0, rib);
		ROUGHNESS = 0.72;
	} else if (COLOR.a > .60 && COLOR.a < .78) {
		// Residential cladding uses metre-scaled courses and a concrete plinth.
		float joint_aa = max(fwidth(wall_height) * .65, .002);
		float plank = fract(wall_height / .177);
		float seam = min(plank, 1.0 - plank) * .177;
		float lap = smoothstep(.007 - joint_aa, .013 + joint_aa, seam);
		float overlap = mix(1.0, lap, 1.0 - smoothstep(.020, .109, joint_aa));
		float painted_grain = dot(texture(wood_scan, UV * vec2(.54, -.79)).rgb, vec3(.22, .64, .14));
		vec3 siding = COLOR.rgb * mix(.80, 1.04, overlap) * mix(.86, 1.08, painted_grain);
		vec3 brick = texture(brick_scan, UV * vec2(.60, -.64)).rgb;
		vec3 masonry = brick * vec3(.78, .65, .60) * 1.12;
		float skirting = (1.0 - smoothstep(1.0, 1.06, UV.y)) * step(.70, COLOR.a);
		float foundation = 1.0 - smoothstep(.33 - joint_aa, .35 + joint_aa, UV.y);
		vec3 concrete = vec3(.47, .45, .40) * mix(.69, .96, painted_grain);
		ALBEDO = mix(mix(siding, masonry, skirting), concrete, foundation);
		ROUGHNESS = .84;
	} else {
		vec3 swatch;
		if (COLOR.a < 0.5) {
			swatch = texture(brick_scan, UV * vec2(0.66, -0.64)).rgb;
		} else {
			swatch = texture(wood_scan, UV * vec2(0.50, -0.84)).rgb;
		}
		float grain = dot(swatch, vec3(.22, .64, .14));
		float base = mix(.71, 1.0, smoothstep(.04, .57, UV.y));
		ALBEDO = COLOR.rgb * base * (0.58 + grain * .89);
		ROUGHNESS = mix(.95, .83, smoothstep(.15, .68, grain));
	}
}
