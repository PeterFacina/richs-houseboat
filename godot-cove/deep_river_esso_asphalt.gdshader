shader_type spatial;
render_mode specular_disabled;

uniform sampler2D asphalt_scan : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

float hash_cell(vec2 cell) {
	return fract(sin(dot(cell, vec2(71.79, 145.37))) * 43758.54);
}

void fragment() {
	vec2 p = UV * 1.13;
	// A warped grid gives the aging pavement continuous seams and smaller branches.
	vec2 warp = vec2(sin(p.y * 8.0) * .035 + sin(p.y * 21.0) * .018,
		sin(p.x * 7.0) * .048 + cos(p.x * 25.0) * .012);
	vec2 grid = p + warp;
	vec2 cell = floor(grid);
	vec2 seam = abs(fract(grid) - .5);
	float along = smoothstep(.487, .499, seam.x) * step(.40, hash_cell(vec2(cell.x, floor(p.y * .58))));
	float across = smoothstep(.484, .499, seam.y) * step(.38, hash_cell(vec2(floor(p.x * .58), cell.y + 8.0)));
	float crack = max(along, across);
	vec3 aggregate = texture(asphalt_scan, UV).rgb;
	float grit = dot(aggregate, vec3(.2126, .7152, .0722));
	float wear = .96 + .075 * sin(p.x * .75 + sin(p.y * 1.12)) + .035 * hash_cell(cell);
	ALBEDO = mix((grit * .49 + vec3(.205, .199, .185)) * wear, vec3(.101, .096, .088), crack * .65);
	ROUGHNESS = .92;
}
