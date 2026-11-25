shader_type spatial;
render_mode specular_disabled;

uniform sampler2D concrete_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D asphalt_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
varying vec2 world_xz;

void vertex() {
	world_xz = (MODEL_MATRIX * vec4(VERTEX, 1.0)).xz;
}

float joint(float coordinate, float spacing, float width) {
	float distance_to_joint = abs(fract(coordinate / spacing + .5) - .5) * spacing;
	float aa = max(.001, fwidth(coordinate));
	return (1.0 - smoothstep(width - aa, width + aa, distance_to_joint)) *
		(1.0 - smoothstep(.035, .15, aa));
}

void fragment() {
	float grit = texture(concrete_scan, UV * .67).g;
	float field = texture(concrete_scan, UV * .22 + vec2(.4, .1)).r;
	float slab = max(joint(UV.y, 1.55, .008), joint(UV.x - 1.47, 4.0, .007) * .72);
	vec3 stone = vec3(.47, .435, .382) * (.87 + .13 * grit + .14 * field - .18 * slab);
	float courses = floor((UV.x - .17) / .125);
	float brick = max(joint(UV.x - .17, .125, .004), joint(UV.y + mod(courses, 2.) * .108, .216, .005));
	vec3 paver = vec3(.365, .237, .172) * (.89 + .21 * grit + .20 * field);
	paver = mix(paver, vec3(.26, .226, .19), brick * .61);
	ALBEDO = mix(stone, paver, COLOR.r);
	if (COLOR.g > .5) {
		float grain = texture(asphalt_scan, world_xz / 1.7).r;
		float patches = texture(concrete_scan, world_xz / 7.2).r;
		ALBEDO = vec3(.35, .324, .294) * (.69 + .29 * grain + .26 * patches);
	}
	vec3 fresh = vec3(.68, .65, .59) * (.93 + .12 * grit + .10 * field - .20 * slab);
	ALBEDO = mix(ALBEDO, fresh, COLOR.b);
	ROUGHNESS = .93;
}
