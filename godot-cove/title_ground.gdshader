shader_type spatial;

uniform sampler2D grass_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D sand_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;
uniform sampler2D pine_litter_texture : source_color, filter_linear_mipmap_anisotropic, repeat_enable;

varying vec2 ground;

void vertex() {
	ground = VERTEX.xz;
}

void fragment() {
	float growth = sin(ground.x * 1.47 + cos(ground.y * 1.19) * 1.5) * sin(ground.y * .98 - ground.x * .54);
	vec3 grass = texture(grass_texture, ground * .66).rgb;
	grass *= mix(vec3(.49, .75, .57), vec3(.78, .97, .66), growth * .5 + .5);
	vec3 sand = texture(sand_texture, ground * .93).rgb * vec3(.70, .63, .48);
	vec3 earth = texture(pine_litter_texture, ground * 1.27).rgb * vec3(.86, .64, .48);
	ALBEDO = mix(mix(grass, sand, COLOR.g), earth, COLOR.r);
	ROUGHNESS = .94;
}
