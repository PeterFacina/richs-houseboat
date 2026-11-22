shader_type spatial;
render_mode unshaded, cull_disabled, depth_draw_never, shadows_disabled;

uniform sampler2D vapor : filter_linear, repeat_disable;

void vertex() {
	vec3 stretch = vec3(length(MODEL_MATRIX[0].xyz), length(MODEL_MATRIX[1].xyz), length(MODEL_MATRIX[2].xyz));
	MODELVIEW_MATRIX = mat4(vec4(stretch.x, 0.0, 0.0, 0.0), vec4(0.0, stretch.y, 0.0, 0.0),
		vec4(0.0, 0.0, stretch.z, 0.0), MODELVIEW_MATRIX[3]);
}

void fragment() {
	float density = texture(vapor, UV).a;
	ALBEDO = vec3(.87, .89, .88);
	ALPHA = density * COLOR.a;
}
