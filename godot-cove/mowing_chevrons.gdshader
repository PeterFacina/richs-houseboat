shader_type spatial;
render_mode unshaded, cull_disabled, shadows_disabled;

uniform float progress;
uniform vec4 teal : source_color = vec4(0.32, 0.88, 0.80, 0.9);

void fragment() {
	float ahead = UV.x - progress;
	ALBEDO = teal.rgb;
	ALPHA = teal.a * smoothstep(0.0, 5.0, ahead)
		* (1.0 - smoothstep(55.0, 85.0, ahead));
}
