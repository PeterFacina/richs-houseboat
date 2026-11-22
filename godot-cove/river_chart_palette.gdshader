shader_type canvas_item;
render_mode unshaded;

void fragment() {
	vec4 source = texture(TEXTURE, UV);
	// In the baked chart only water is bluer than it is green.
	float water = smoothstep(-0.006, 0.022, source.b - source.g);
	float relief = clamp((source.g - 0.22) / 0.28, 0.0, 1.0);
	float shallows = clamp((source.g - 0.24) / 0.20, 0.0, 1.0);
	vec3 land = mix(vec3(0.71, 0.77, 0.63), vec3(0.91, 0.91, 0.76), relief);
	vec3 river = mix(vec3(0.25, 0.61, 0.74), vec3(0.46, 0.77, 0.82), shallows);
	COLOR = vec4(mix(land, river, water), source.a);
}
