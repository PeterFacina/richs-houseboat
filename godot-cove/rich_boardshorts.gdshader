shader_type spatial;
render_mode diffuse_burley, shadows_disabled;

void fragment() {
	vec2 print_uv = vec2(UV.x * 6.0, UV.y * 12.0);
	print_uv.x += .5 * mod(floor(print_uv.y), 2.0);
	vec2 p = fract(print_uv) - .5;
	float angle = atan(p.y, p.x);
	float flower = 1.0 - smoothstep(.24, .28, length(p) /
		(.76 + .24 * cos(5.0 * angle + .24)));
	float centre = 1.0 - smoothstep(.047, .070, length(p));
	vec2 leaf = fract(print_uv + vec2(.42, .38)) - .5;
	float blade = 1.0 - smoothstep(.17, .20,
		length(vec2((leaf.x + leaf.y) * .8, (leaf.y - leaf.x) * 2.4)));
	vec3 base = vec3(.035, .22, .25);
	vec3 coral = vec3(.85, .31, .22);
	ALBEDO = mix(mix(base, vec3(.17, .45, .35), blade), coral, flower);
	ALBEDO = mix(ALBEDO, vec3(.91, .69, .30), centre);
	ALBEDO *= mix(.84, 1.0, smoothstep(.025, .10, UV2.y));
	ROUGHNESS = .88;
	SPECULAR = .22;
}
