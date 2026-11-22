shader_type spatial;
render_mode blend_mix, depth_draw_never, cull_disabled, unshaded, shadows_disabled;

uniform vec4 glass_tint : source_color = vec4(.36, .58, .68, 1.0);
uniform float smoke = .0;

void fragment() {
	vec3 eye = normalize(VIEW);
	vec3 face = normalize(NORMAL);
	float grazing = pow(1.0 - abs(dot(face, eye)), 3.0);
	vec3 reflected = (INV_VIEW_MATRIX * vec4(reflect(-eye, face), 0.0)).xyz;
	float sky = smoothstep(-.35, .58, reflected.y);
	float top_tint = smoothstep(.56, 1.0, UV.y);
	ALBEDO = mix(glass_tint.rgb, vec3(.67, .81, .88), sky * .68);
	ALPHA = .11 + smoke + grazing * .22 + top_tint * .068;
}
