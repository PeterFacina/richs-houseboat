shader_type spatial;
render_mode unshaded, blend_add, cull_disabled, depth_draw_never;

void fragment() {
	vec2 uv = vec2((UV.x - .5) * 2.0, 1.0 - UV.y);
	float crest = .71 + .12 * sin(TIME * 10.7) + .09 * sin(TIME * 18.4);
	float tilt = (sin(TIME * 6.5 + uv.y * 2.8) * .20 + sin(uv.y * 9.0 - TIME * 16.4) * .071) * uv.y;
	float width = (.72 - .64 * uv.y) * (1.0 - .19 * sin(TIME * 14.5));
	float flame = (1.0 - smoothstep(width * .63, width, abs(uv.x - tilt)))
		* smoothstep(0.0, .17, uv.y) * (1.0 - smoothstep(crest - .13, crest + .09, uv.y));
	vec3 hot = mix(vec3(1.0, .70, .26), vec3(.90, .235, .027), smoothstep(.05, .75, uv.y));
	ALBEDO = hot;
	ALPHA = flame * .49;
}
