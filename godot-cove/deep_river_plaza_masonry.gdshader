shader_type spatial;
render_mode specular_disabled;

uniform vec4 face_color : source_color = vec4(.59, .30, .22, 1.0);
uniform vec4 joint_color : source_color = vec4(.63, .51, .41, 1.0);
uniform vec2 block_size = vec2(.228, .079);
uniform float joint_width = .009;

float variation(vec2 p) {
	return fract(sin(dot(mod(p, 251.0), vec2(47.13, 19.19))) * 4375.71);
}

void fragment() {
	vec2 block = UV / block_size;
	block.x += .5 * mod(floor(block.y), 2.0);
	vec2 cell = floor(block);
	vec2 edge = (.5 - abs(fract(block) - .5)) * block_size;
	float seam = min(edge.x, edge.y);
	float filter_width = max(max(fwidth(UV.x), fwidth(UV.y)), .0005);
	float bevel = smoothstep(joint_width * .5 - filter_width, joint_width * .5 + filter_width, seam);
	float grain = variation(floor(UV * 275.0));
	grain = mix(grain, .5, smoothstep(.002, .013, filter_width));
	float shade = .83 + variation(cell) * .29 + (grain - .5) * .20;
	float lip = smoothstep(joint_width * .58, joint_width * .58 + .005 + filter_width, seam);
	vec3 unit = face_color.rgb * shade * mix(.78, 1.0, lip);
	ALBEDO = mix(joint_color.rgb * mix(.89, 1.09, grain), unit, bevel);
	ROUGHNESS = .97;
}
